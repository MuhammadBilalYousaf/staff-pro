import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staffpro/core/constants/app_constants.dart';
import 'package:staffpro/core/errors/app_exception.dart';
import 'package:staffpro/data/firestore_database.dart';
import 'package:staffpro/models/enums.dart';
import 'package:staffpro/models/menu_models.dart';
import 'package:staffpro/models/models.dart';
import 'package:staffpro/services/bridge_api_client.dart';
import 'package:staffpro/services/firebase_auth_service.dart';
import 'package:staffpro/services/location_service.dart';
import 'package:uuid/uuid.dart';

class PeriodFilter {
  const PeriodFilter({required this.from, required this.to, this.label = 'Custom'});
  final DateTime from;
  final DateTime to;
  final String label;

  static PeriodFilter today() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return PeriodFilter(from: start, to: start.add(const Duration(days: 1)), label: 'Today');
  }

  static PeriodFilter week() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    return PeriodFilter(from: start, to: start.add(const Duration(days: 7)), label: 'This Week');
  }

  static PeriodFilter month() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);
    return PeriodFilter(from: start, to: end, label: 'This Month');
  }

  bool contains(DateTime value) => !value.isBefore(from) && value.isBefore(to);
}

class StaffProController extends ChangeNotifier {
  StaffProController(this._db, this._location, {FirebaseAuthService? auth, BridgeApiClient? bridge})
      : _auth = auth ?? FirebaseAuthService(),
        _bridge = bridge ?? BridgeApiClient();

  final FirestoreDatabase _db;
  final LocationService _location;
  final FirebaseAuthService _auth;
  final BridgeApiClient _bridge;
  final _uuid = const Uuid();

  AppUser? currentUser;
  String? selectedBranchId;
  Map<String, dynamic>? posBridgeDashboard;
  bool bootstrapping = true;
  String? lastError;
  StreamSubscription<dynamic>? _orderAlerts;
  final Set<String> _seenOrderIds = {};

  FirestoreDatabase get db => _db;
  PlatformSettings get settings => _db.settings;

  Future<void> bootstrap() async {
    await _db.init();
    final prefs = await SharedPreferences.getInstance();
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      final user = await _db.fetchUser(firebaseUser.uid);
      if (user != null && user.isActive) {
        currentUser = user;
        await _db.loadForUser(user);
        _watchCustomerOrders(user);
        selectedBranchId = prefs.getString(AppConstants.selectedBranchKey) ?? user.branchId;
        if (currentUser!.role == UserRole.manager || currentUser!.role == UserRole.employee) {
          selectedBranchId = currentUser!.branchId;
        }
        await prefs.setString(AppConstants.sessionUserKey, user.id);
      } else {
        await _auth.signOut();
        await prefs.remove(AppConstants.sessionUserKey);
      }
    }
    _flagMissingCheckouts();
    bootstrapping = false;
    notifyListeners();
  }

  void _flagMissingCheckouts() {
    final today = _day(DateTime.now());
    for (final record in _db.attendance) {
      if (record.checkOutAt == null && _day(record.date).isBefore(today)) {
        record.status = AttendanceStatus.missingCheckout;
        record.workedMinutes = null;
      }
    }
  }

  Future<void> _save() async {
    await _db.persist(
      includePlatform: currentUser?.role == UserRole.superAdmin,
      asRole: currentUser?.role,
      asUserId: currentUser?.id,
    );
    notifyListeners();
  }

  /// Login/logout must not rewrite the whole cache — that trips security rules
  /// for roles that can read org data but cannot write every collection.
  Future<void> _persistLoginAudit() async {
    if (_db.auditLogs.isEmpty) return;
    try {
      await _db.upsertAuditLog(_db.auditLogs.last);
    } catch (_) {
      // Audit is best-effort; never block auth on rules/network.
    }
    notifyListeners();
  }

  AppUser requireUser() {
    final user = currentUser;
    if (user == null || !user.isActive) {
      throw AuthException('Please sign in to continue.');
    }
    return user;
  }

  AppUser? _userById(String id) {
    try {
      return _db.users.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  AppUser? userByEmail(String email) {
    final needle = email.trim().toLowerCase();
    try {
      return _db.users.firstWhere((e) => e.email.toLowerCase() == needle);
    } catch (_) {
      return null;
    }
  }

  Business? businessById(String? id) {
    if (id == null) return null;
    try {
      return _db.businesses.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Branch? branchById(String? id) {
    if (id == null) return null;
    try {
      return _db.branches.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  String userName(String? id) => _userById(id ?? '')?.fullName ?? 'System';
  String businessName(String? id) => businessById(id)?.name ?? '—';
  String branchName(String? id) => branchById(id)?.name ?? '—';

  void _assertActive(AppUser user) {
    if (!user.isActive) {
      throw AuthException('This account is ${statusLabel(user.status).toLowerCase()}.');
    }
  }

  void assertBusinessScope(AppUser actor, String? businessId) {
    if (actor.role == UserRole.superAdmin) return;
    if (actor.businessId == null || actor.businessId != businessId) {
      throw ForbiddenException('You cannot access another business.');
    }
  }

  void assertBranchScope(AppUser actor, String? branchId) {
    if (actor.role == UserRole.superAdmin) return;
    if (actor.role == UserRole.businessAdmin) {
      final branch = branchById(branchId);
      assertBusinessScope(actor, branch?.businessId ?? actor.businessId);
      return;
    }
    if (actor.branchId == null || actor.branchId != branchId) {
      throw ForbiddenException('You can only access your assigned branch.');
    }
  }

  void assertOwnOrElevated(AppUser actor, String userId) {
    if (actor.role == UserRole.superAdmin || actor.role == UserRole.businessAdmin) return;
    if (actor.role == UserRole.manager) return;
    if (actor.id != userId) throw ForbiddenException('You can only access your own records.');
  }

  static int roleRank(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 4;
      case UserRole.businessAdmin:
        return 3;
      case UserRole.manager:
        return 2;
      case UserRole.employee:
        return 1;
    }
  }

  bool get canManageAdmins {
    final user = currentUser;
    if (user == null) return false;
    if (user.role == UserRole.superAdmin) return true;
    return user.role == UserRole.businessAdmin && (user.isOwner || user.permissions.fullAccess);
  }

  bool get canManageEmployees {
    final user = currentUser;
    if (user == null) return false;
    if (user.role == UserRole.superAdmin) return true;
    if (user.role == UserRole.businessAdmin) {
      return user.isOwner || user.permissions.fullAccess || user.permissions.employeeManagement;
    }
    return user.role == UserRole.manager;
  }

  bool get canManageBranches {
    final user = currentUser;
    if (user == null) return false;
    if (user.role == UserRole.superAdmin) return true;
    return user.role == UserRole.businessAdmin &&
        (user.isOwner || user.permissions.fullAccess || user.permissions.branchManagement);
  }

  bool get canManageCategories {
    final user = currentUser;
    if (user == null) return false;
    if (user.role == UserRole.businessAdmin) {
      return user.isOwner || user.permissions.fullAccess || user.permissions.manageCategories;
    }
    if (user.role == UserRole.manager) return settings.allowManagerCategories;
    return false;
  }

  /// Lower roles cannot create or edit equal/higher roles.
  bool canCreateRole(UserRole role) {
    final actor = currentUser;
    if (actor == null || role == UserRole.superAdmin) return false;
    if (actor.role == UserRole.superAdmin) return true;
    if (role == UserRole.businessAdmin) return canManageAdmins;
    if (role == UserRole.manager) {
      // Only full Admin (not employee-only access) may add managers.
      return canManageAdmins;
    }
    if (role == UserRole.employee) {
      if (actor.role == UserRole.manager) return true;
      return actor.role == UserRole.businessAdmin && canManageEmployees;
    }
    return false;
  }

  bool canEditUser(AppUser target) {
    final actor = currentUser;
    if (actor == null) return false;
    if (actor.id == target.id) return true;
    if (actor.role == UserRole.superAdmin) return true;
    if (roleRank(target.role) >= roleRank(actor.role)) return false;
    if (actor.role == UserRole.businessAdmin) {
      if (target.businessId != actor.businessId) return false;
      if (target.role == UserRole.businessAdmin) return canManageAdmins;
      return canManageEmployees;
    }
    if (actor.role == UserRole.manager) {
      return target.role == UserRole.employee && target.branchId == actor.branchId;
    }
    return false;
  }

  DateTime _day(DateTime v) => DateTime(v.year, v.month, v.day);

  List<Branch> visibleBranches() {
    final user = requireUser();
    var list = _db.branches.toList();
    if (user.role != UserRole.superAdmin) {
      list = list.where((b) => b.businessId == user.businessId).toList();
    }
    if (user.role == UserRole.manager || user.role == UserRole.employee) {
      list = list.where((b) => b.id == user.branchId).toList();
    }
    return list;
  }

  List<Branch> branchesFor(String? businessId, {bool activeOnly = false}) {
    return _db.branches.where((b) {
      if (businessId != null && b.businessId != businessId) return false;
      if (activeOnly && b.status != EntityStatus.active) return false;
      return true;
    }).toList();
  }

  List<AppUser> usersWhere({
    UserRole? role,
    String? businessId,
    String? branchId,
    EntityStatus? status,
    String query = '',
  }) {
    final q = query.trim().toLowerCase();
    return _db.users.where((u) {
      if (role != null && u.role != role) return false;
      if (businessId != null && u.businessId != businessId) return false;
      if (branchId != null && u.branchId != branchId) return false;
      if (status != null && u.status != status) return false;
      if (q.isNotEmpty) {
        final hay = '${u.fullName} ${u.email} ${u.employeeCode ?? ''} ${u.phone}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  Future<void> login(String email, String password, {bool remember = true}) async {
    final cred = await _auth.signIn(email, password);
    final uid = cred.user?.uid;
    if (uid == null) throw AuthException('Invalid email or password.');
    final user = await _db.fetchUser(uid);
    if (user == null) {
      await _auth.signOut();
      throw AuthException('User profile not found. Contact your administrator.');
    }
    _assertActive(user);
    await _db.loadForUser(user);
    if (user.role != UserRole.superAdmin) {
      final biz = businessById(user.businessId);
      if (biz == null || biz.status != EntityStatus.active) {
        await _auth.signOut();
        await _db.clearSessionCache();
        throw AuthException('This business is not active.');
      }
    }
    currentUser = user;
    selectedBranchId = user.branchId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.sessionUserKey, user.id);
    if (remember) {
      await prefs.setString(AppConstants.rememberMeKey, user.email);
    } else {
      await prefs.remove(AppConstants.rememberMeKey);
    }
    if (selectedBranchId != null) {
      await prefs.setString(AppConstants.selectedBranchKey, selectedBranchId!);
    }
    _audit(AuditAction.login, 'auth', newData: user.email);
    await _persistLoginAudit();
    _watchCustomerOrders(user);
  }

  Future<String?> rememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.rememberMeKey);
  }

  Future<void> logout() async {
    await _orderAlerts?.cancel();
    _orderAlerts = null;
    _seenOrderIds.clear();
    final user = currentUser;
    if (user != null) {
      _audit(AuditAction.logout, 'auth');
      await _persistLoginAudit();
    }
    currentUser = null;
    selectedBranchId = null;
    await _db.clearSessionCache();
    try {
      await _auth.signOut();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.sessionUserKey);
    notifyListeners();
  }

  Future<void> signupSuperAdmin({
    required String fullName,
    required String email,
    required String password,
    required String confirm,
    required String secretCode,
  }) async {
    final publicSecret = await _db.readPublicSecretCode();
    if (secretCode.trim() != publicSecret && secretCode.trim() != settings.secretCode) {
      throw AuthException('Invalid secret registration code.');
    }
    if (!await _db.isBootstrapOpen()) {
      throw AuthException('Super Admin registration is closed.');
    }
    if (password != confirm) throw ValidationException('Passwords do not match.');
    final existing = await _db.fetchUserByEmail(email);
    if (existing != null) {
      throw ValidationException('An account with this email already exists.');
    }
    final cred = await _auth.signUp(email, password);
    final uid = cred.user?.uid;
    if (uid == null) throw AuthException('Failed to create account.');
    final user = AppUser(
      id: uid,
      fullName: fullName.trim(),
      email: email.trim().toLowerCase(),
      passwordHash: '',
      passwordSalt: '',
      role: UserRole.superAdmin,
    );
    await _db.upsertUser(user);
    await _db.markBootstrapComplete();
    await _db.loadForUser(user);
    _audit(AuditAction.create, 'auth', recordId: user.id, newData: user.email, actor: user);
    await _db.persist(
      includePlatform: true,
      asRole: UserRole.superAdmin,
      asUserId: user.id,
    );
    currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.sessionUserKey, user.id);
    await prefs.setString(AppConstants.rememberMeKey, user.email);
    notifyListeners();
  }

  Future<void> changePassword({
    required String current,
    required String next,
    required String confirm,
  }) async {
    final user = requireUser();
    if (next != confirm) throw ValidationException('Passwords do not match.');
    await _auth.changePassword(email: user.email, current: current, next: next);
    user.updatedAt = DateTime.now();
    _audit(AuditAction.passwordChange, 'profile');
    await _save();
  }

  Future<void> updateProfile({
    required String fullName,
    required String phone,
    String? photoPath,
  }) async {
    final user = requireUser();
    user.fullName = fullName.trim();
    user.phone = phone.trim();
    if (photoPath != null) user.photoPath = photoPath;
    user.updatedAt = DateTime.now();
    _audit(AuditAction.update, 'profile');
    await _save();
  }

  Future<void> setSelectedBranch(String? branchId) async {
    final user = requireUser();
    if (user.role == UserRole.manager || user.role == UserRole.employee) {
      throw ForbiddenException('You cannot switch branches.');
    }
    if (branchId != null) assertBranchScope(user, branchId);
    selectedBranchId = branchId;
    final prefs = await SharedPreferences.getInstance();
    if (branchId == null) {
      await prefs.remove(AppConstants.selectedBranchKey);
    } else {
      await prefs.setString(AppConstants.selectedBranchKey, branchId);
    }
    notifyListeners();
  }

  String? get effectiveBranchId {
    final user = currentUser;
    if (user == null) return null;
    if (user.role == UserRole.manager || user.role == UserRole.employee) return user.branchId;
    return selectedBranchId;
  }

  Future<Business> createBusiness({
    required String name,
    String code = '',
    String phone = '',
    String email = '',
    String address = '',
    String city = '',
    EntityStatus status = EntityStatus.active,
    required String adminName,
    required String adminEmail,
    required String adminPhone,
    required String adminPassword,
  }) async {
    final actor = requireUser();
    if (actor.role != UserRole.superAdmin) throw ForbiddenException();
    if (userByEmail(adminEmail) != null || await _db.fetchUserByEmail(adminEmail) != null) {
      throw ValidationException('Admin email is already in use.');
    }
    if (code.trim().isNotEmpty && _db.businesses.any((b) => b.code.toLowerCase() == code.trim().toLowerCase())) {
      throw ValidationException('Business code must be unique.');
    }

    final business = Business(
      id: _uuid.v4(),
      name: name.trim(),
      code: code.trim(),
      phone: phone.trim(),
      email: email.trim(),
      address: address.trim(),
      city: city.trim(),
      status: status,
      createdBy: actor.id,
    );
    final adminUid = await _auth.createAuthUser(email: adminEmail, password: adminPassword);
    final admin = AppUser(
      id: adminUid,
      fullName: adminName.trim(),
      email: adminEmail.trim().toLowerCase(),
      phone: adminPhone.trim(),
      passwordHash: '',
      passwordSalt: '',
      role: UserRole.businessAdmin,
      businessId: business.id,
      isOwner: true,
      permissions: const AdminPermissions(),
    );
    _db.businesses.add(business);
    _db.users.add(admin);
    _seedBusinessDefaults(business.id, actor.id);
    _notify(
      recipientUserId: admin.id,
      type: NotificationType.businessCreated,
      title: 'Business created',
      message: '${business.name} is ready. Sign in to set up branches and staff.',
      businessId: business.id,
    );
    _audit(AuditAction.create, 'business', businessId: business.id, recordId: business.id, newData: business.name);
    _audit(AuditAction.create, 'admin', businessId: business.id, recordId: admin.id, newData: admin.email);
    await _save();
    return business;
  }

  void _seedBusinessDefaults(String businessId, String createdBy) {
    for (final name in AppConstants.defaultExpenseCategories) {
      _db.expenseCategories.add(ExpenseCategory(
        id: _uuid.v4(),
        businessId: businessId,
        name: name,
        createdBy: createdBy,
      ));
    }
    _db.shifts.add(Shift(
      id: _uuid.v4(),
      businessId: businessId,
      name: 'Default Shift',
      startTime: AppConstants.defaultShiftStart,
      endTime: AppConstants.defaultShiftEnd,
      gracePeriodMinutes: AppConstants.defaultGracePeriodMinutes,
    ));
  }

  Future<void> updateBusiness(Business updated) async {
    final actor = requireUser();
    if (actor.role != UserRole.superAdmin &&
        !(actor.role == UserRole.businessAdmin && actor.businessId == updated.id)) {
      throw ForbiddenException();
    }
    final existing = businessById(updated.id);
    if (existing == null) throw NotFoundException('Business not found.');
    final prev = existing.name;
    existing
      ..name = updated.name.trim()
      ..code = updated.code.trim()
      ..phone = updated.phone.trim()
      ..email = updated.email.trim()
      ..address = updated.address.trim()
      ..city = updated.city.trim()
      ..status = updated.status
      ..updatedAt = DateTime.now();
    _audit(AuditAction.update, 'business', businessId: existing.id, previousData: prev, newData: existing.name);
    await _save();
  }

  Future<void> setBusinessStatus(String businessId, EntityStatus status) async {
    final actor = requireUser();
    if (actor.role != UserRole.superAdmin) throw ForbiddenException();
    final business = businessById(businessId);
    if (business == null) throw NotFoundException();
    business.status = status;
    business.updatedAt = DateTime.now();
    _audit(
      status == EntityStatus.active ? AuditAction.update : AuditAction.deactivate,
      'business',
      businessId: businessId,
      newData: status.name,
    );
    await _save();
  }

  Future<AppUser> createStaff({
    required UserRole role,
    required String fullName,
    required String email,
    required String phone,
    required String password,
    String? businessId,
    String? branchId,
    String? employeeCode,
    String? position,
    DateTime? joiningDate,
    AdminPermissions? permissions,
    bool isOwner = false,
  }) async {
    final actor = requireUser();
    if (userByEmail(email) != null || await _db.fetchUserByEmail(email) != null) {
      throw ValidationException('An account with this email already exists.');
    }
    if (!canCreateRole(role)) {
      throw ForbiddenException('You cannot add a ${roleLabel(role)}. Lower roles cannot create higher roles.');
    }
    String? bizId = businessId ?? actor.businessId;
    late final AdminPermissions resolvedPermissions;
    if (role == UserRole.businessAdmin) {
      if (actor.role == UserRole.businessAdmin) bizId = actor.businessId;
      // Admins are always full admin access — partial "emp admin" is not allowed.
      resolvedPermissions = const AdminPermissions(
        fullAccess: true,
        employeeManagement: true,
        branchManagement: true,
        manageCategories: true,
      );
    } else if (role == UserRole.manager || role == UserRole.employee) {
      if (actor.role == UserRole.manager) {
        bizId = actor.businessId;
        branchId = actor.branchId;
      }
      if (branchId == null || branchId.isEmpty) {
        throw ValidationException('Branch assignment is required.');
      }
      assertBranchScope(actor, branchId);
      // Super Admin may create managers/employees for any branch — derive business from it.
      bizId ??= branchById(branchId)?.businessId;
      if (bizId == null || bizId.isEmpty) {
        throw ValidationException('Business context is missing for this branch.');
      }
      resolvedPermissions = const AdminPermissions(
        fullAccess: false,
        employeeManagement: false,
        branchManagement: false,
        manageCategories: false,
      );
    } else {
      throw ForbiddenException();
    }
    if (employeeCode != null && employeeCode.trim().isNotEmpty) {
      final exists = _db.users.any(
        (u) => u.employeeCode?.toLowerCase() == employeeCode.trim().toLowerCase() && u.businessId == bizId,
      );
      if (exists) throw ValidationException('Employee / Manager ID must be unique.');
    }

    final uid = await _auth.createAuthUser(email: email, password: password);
    final user = AppUser(
      id: uid,
      fullName: fullName.trim(),
      email: email.trim().toLowerCase(),
      phone: phone.trim(),
      passwordHash: '',
      passwordSalt: '',
      role: role,
      businessId: bizId,
      branchId: branchId,
      employeeCode: employeeCode?.trim(),
      position: position,
      joiningDate: joiningDate,
      permissions: resolvedPermissions,
      isOwner: isOwner,
    );
    _db.users.add(user);
    if (branchId != null) {
      _db.assignments.add(BranchAssignment(
        id: _uuid.v4(),
        businessId: bizId ?? '',
        userId: user.id,
        toBranchId: branchId,
        effectiveFrom: DateTime.now(),
        changedBy: actor.id,
        reason: 'Initial assignment',
      ));
    }
    _notify(
      recipientUserId: user.id,
      type: NotificationType.userCreated,
      title: 'Account created',
      message: 'Your ${roleLabel(role)} account is ready. You can now sign in.',
      businessId: bizId,
      branchId: branchId,
    );
    _audit(AuditAction.create, role.name, businessId: bizId, branchId: branchId, recordId: user.id, newData: user.email);
    await _save();
    // Provision the same employee into the POS identity bridge (best-effort).
    try {
      await _bridge.upsertEmployee(
        email: user.email,
        displayName: user.fullName,
        staffproRole: user.role.name,
        password: password,
        phone: user.phone,
        employeeCode: user.employeeCode,
        staffproFirebaseUid: user.id,
        staffproBusinessId: user.businessId,
        staffproBranchId: user.branchId,
        posAccess: user.role == UserRole.businessAdmin ||
            user.role == UserRole.manager ||
            user.role == UserRole.employee,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Bridge employee sync skipped: $error');
      }
    }
    return user;
  }

  Future<void> updateStaff(AppUser updated) async {
    final actor = requireUser();
    final existing = _userById(updated.id);
    if (existing == null) throw NotFoundException();
    if (!canEditUser(existing)) {
      throw ForbiddenException('You cannot edit a higher or equal role.');
    }
    if (actor.role == UserRole.businessAdmin) {
      assertBusinessScope(actor, existing.businessId);
    }
    // Never allow elevating someone above what the actor can create.
    if (updated.role != existing.role && !canCreateRole(updated.role)) {
      throw ForbiddenException('You cannot change this person to ${roleLabel(updated.role)}.');
    }
    existing
      ..fullName = updated.fullName.trim()
      ..phone = updated.phone.trim()
      ..position = updated.position
      ..employeeCode = updated.employeeCode
      ..status = updated.status
      ..permissions = existing.role == UserRole.businessAdmin
          ? (actor.role == UserRole.superAdmin || canManageAdmins
              ? updated.permissions
              : existing.permissions)
          : const AdminPermissions(fullAccess: false, employeeManagement: false, branchManagement: false, manageCategories: false)
      ..joiningDate = updated.joiningDate
      ..photoPath = updated.photoPath
      ..updatedAt = DateTime.now();
    _audit(AuditAction.update, existing.role.name, businessId: existing.businessId, recordId: existing.id);
    await _save();
  }

  Future<void> setUserStatus(String userId, EntityStatus status) async {
    final actor = requireUser();
    final user = _userById(userId);
    if (user == null) throw NotFoundException();
    if (user.id == actor.id) throw ValidationException('You cannot change your own account status.');
    if (!canEditUser(user)) throw ForbiddenException('You cannot change status for a higher or equal role.');
    if (actor.role == UserRole.businessAdmin) assertBusinessScope(actor, user.businessId);
    if (actor.role == UserRole.employee) throw ForbiddenException();
    user.status = status;
    user.updatedAt = DateTime.now();
    _audit(
      status == EntityStatus.active ? AuditAction.update : AuditAction.deactivate,
      user.role.name,
      businessId: user.businessId,
      recordId: user.id,
      newData: status.name,
    );
    await _save();
    try {
      await _bridge.upsertEmployee(
        email: user.email,
        displayName: user.fullName,
        staffproRole: user.role.name,
        phone: user.phone,
        employeeCode: user.employeeCode,
        staffproFirebaseUid: user.id,
        staffproBusinessId: user.businessId,
        staffproBranchId: user.branchId,
        posAccess: status == EntityStatus.active &&
            (user.role == UserRole.businessAdmin ||
                user.role == UserRole.manager ||
                user.role == UserRole.employee),
        status: status == EntityStatus.active ? 'active' : 'disabled',
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Bridge status sync skipped: $error');
      }
    }
  }

  Future<void> refreshPosBridgeDashboard() async {
    final user = currentUser;
    if (user == null) return;
    final data = await _bridge.getDashboard(
      businessId: user.role == UserRole.superAdmin ? null : null,
      branchId: effectiveBranchId,
    );
    posBridgeDashboard = data;
    notifyListeners();
  }

  Future<String> resetAccess(String userId, String newPassword) async {
    final actor = requireUser();
    final user = _userById(userId);
    if (user == null) throw NotFoundException();
    if (actor.role == UserRole.employee) throw ForbiddenException();
    if (actor.role == UserRole.manager &&
        (user.role != UserRole.employee || user.branchId != actor.branchId)) {
      throw ForbiddenException();
    }
    if (actor.role == UserRole.businessAdmin) {
      assertBusinessScope(actor, user.businessId);
      if (roleRank(user.role) >= roleRank(actor.role) && !canManageAdmins) {
        throw ForbiddenException('You cannot reset access for an equal or higher role.');
      }
    }
    // Client SDK cannot set another user's Auth password — send Firebase reset email.
    await _auth.sendPasswordResetEmail(user.email);
    user.updatedAt = DateTime.now();
    for (final req in _db.passwordRequests.where((r) => r.userId == userId && r.status == PasswordResetStatus.pending)) {
      req.status = PasswordResetStatus.completed;
      req.resolvedBy = actor.id;
      req.updatedAt = DateTime.now();
    }
    _notify(
      recipientUserId: user.id,
      type: NotificationType.passwordResetRequest,
      title: 'Password reset',
      message: 'A password reset email was sent by ${actor.fullName}. Check your inbox.',
      businessId: user.businessId,
    );
    _audit(AuditAction.resetAccess, 'auth', businessId: user.businessId, recordId: user.id);
    await _save();
    return 'EMAIL_SENT:${user.email}';
  }

  Future<void> transferBranch({
    required String userId,
    required String toBranchId,
    String reason = '',
  }) async {
    final actor = requireUser();
    if (actor.role != UserRole.businessAdmin && actor.role != UserRole.superAdmin) {
      throw ForbiddenException();
    }
    if (actor.role == UserRole.businessAdmin && !actor.permissions.canTransfer) {
      throw ForbiddenException();
    }
    final user = _userById(userId);
    if (user == null) throw NotFoundException();
    final from = user.branchId;
    if (from == toBranchId) throw ValidationException('User is already on this branch.');
    final target = branchById(toBranchId);
    if (target == null || target.businessId != user.businessId) {
      throw ValidationException('Target branch is invalid.');
    }
    final now = DateTime.now();
    for (final a in _db.assignments.where((e) => e.userId == userId && e.effectiveTo == null)) {
      a.effectiveTo = now;
    }
    _db.assignments.add(BranchAssignment(
      id: _uuid.v4(),
      businessId: user.businessId ?? '',
      userId: user.id,
      fromBranchId: from,
      toBranchId: toBranchId,
      effectiveFrom: now,
      changedBy: actor.id,
      reason: reason,
    ));
    user.branchId = toBranchId;
    user.updatedAt = now;
    _notify(
      recipientUserId: user.id,
      type: NotificationType.branchTransfer,
      title: 'Branch transferred',
      message: 'You have been assigned to ${target.name}.',
      businessId: user.businessId,
      branchId: toBranchId,
    );
    _audit(
      AuditAction.branchTransfer,
      'users',
      businessId: user.businessId,
      branchId: toBranchId,
      recordId: user.id,
      previousData: from,
      newData: toBranchId,
      reason: reason,
    );
    await _save();
  }

  Future<Branch> createBranch({
    required String name,
    String? businessId,
    String code = '',
    String phone = '',
    String address = '',
    String city = '',
    double? latitude,
    double? longitude,
    double? geofenceRadius,
    bool? blockOutsideGeofence,
    EntityStatus status = EntityStatus.active,
  }) async {
    final actor = requireUser();
    if (!canManageBranches && actor.role != UserRole.superAdmin) throw ForbiddenException();
    final bizId = businessId ?? actor.businessId;
    if (bizId == null) throw ValidationException('Business context is missing.');
    if (actor.role != UserRole.superAdmin) assertBusinessScope(actor, bizId);
    if (code.trim().isNotEmpty &&
        _db.branches.any((b) => b.businessId == bizId && b.code.toLowerCase() == code.trim().toLowerCase())) {
      throw ValidationException('Branch code must be unique.');
    }
    if (name.trim().isEmpty) {
      throw ValidationException('Branch name is required.');
    }
    if (latitude == null || longitude == null) {
      throw ValidationException('Set the shop location on the map (or use current location).');
    }
    final branch = Branch(
      id: _uuid.v4(),
      businessId: bizId,
      name: name.trim(),
      code: code.trim(),
      phone: phone.trim(),
      address: address.trim(),
      city: city.trim(),
      latitude: latitude,
      longitude: longitude,
      geofenceRadius: geofenceRadius ?? settings.geofenceRadius,
      blockOutsideGeofence: blockOutsideGeofence ?? settings.blockOutsideGeofence,
      status: status,
    );
    _db.branches.add(branch);
    _audit(AuditAction.create, 'branch', businessId: bizId, branchId: branch.id, newData: branch.name);
    await _save();
    return branch;
  }

  Future<void> updateBranch(Branch updated) async {
    final actor = requireUser();
    if (!canManageBranches) throw ForbiddenException();
    final existing = branchById(updated.id);
    if (existing == null) throw NotFoundException();
    assertBusinessScope(actor, existing.businessId);
    existing
      ..name = updated.name.trim()
      ..code = updated.code.trim()
      ..phone = updated.phone.trim()
      ..address = updated.address.trim()
      ..city = updated.city.trim()
      ..latitude = updated.latitude
      ..longitude = updated.longitude
      ..geofenceRadius = updated.geofenceRadius
      ..blockOutsideGeofence = updated.blockOutsideGeofence
      ..status = updated.status
      ..updatedAt = DateTime.now();
    _audit(AuditAction.update, 'branch', businessId: existing.businessId, branchId: existing.id);
    await _save();
  }

  Future<Sale> addSale({
    required double amount,
    required DateTime date,
    required String category,
    required String paymentMethod,
    String description = '',
    String? branchId,
  }) async {
    final actor = requireUser();
    if (actor.role == UserRole.superAdmin) {
      throw ForbiddenException('Super Admin cannot record operational sales.');
    }
    final bId = branchId ?? effectiveBranchId ?? actor.branchId;
    if (bId == null) throw ValidationException('Select a branch first.');
    assertBranchScope(actor, bId);
    if (amount <= 0) throw ValidationException('Amount must be greater than zero.');
    final sale = Sale(
      id: _uuid.v4(),
      businessId: actor.businessId ?? branchById(bId)?.businessId ?? '',
      branchId: bId,
      userId: actor.id,
      amount: amount,
      date: date,
      category: category,
      paymentMethod: paymentMethod,
      description: description.trim(),
    );
    _db.sales.add(sale);
    _notifyAdmins(
      type: NotificationType.saleAdded,
      title: 'New sale added',
      message: '${actor.fullName} recorded ${sale.amount.toStringAsFixed(0)} ${sale.category}.',
      businessId: sale.businessId,
      branchId: sale.branchId,
    );
    _audit(AuditAction.create, 'sales', businessId: sale.businessId, branchId: sale.branchId, recordId: sale.id);
    await _save();
    return sale;
  }

  Future<Expense> addExpense({
    required double amount,
    required DateTime date,
    required String categoryId,
    String paymentMethod = 'Cash',
    String description = '',
    String? receiptPath,
    String? branchId,
  }) async {
    final actor = requireUser();
    if (actor.role == UserRole.superAdmin) throw ForbiddenException();
    final bId = branchId ?? effectiveBranchId ?? actor.branchId;
    if (bId == null) throw ValidationException('Select a branch first.');
    assertBranchScope(actor, bId);
    if (amount <= 0) throw ValidationException('Amount must be greater than zero.');
    ExpenseCategory? category;
    try {
      category = _db.expenseCategories.firstWhere((c) => c.id == categoryId);
    } catch (_) {
      throw ValidationException('Select a valid expense category.');
    }
    if (category.status != EntityStatus.active) {
      throw ValidationException('This category is inactive.');
    }
    final expense = Expense(
      id: _uuid.v4(),
      businessId: actor.businessId ?? '',
      branchId: bId,
      userId: actor.id,
      amount: amount,
      date: date,
      categoryId: category.id,
      categoryName: category.name,
      paymentMethod: paymentMethod,
      description: description.trim(),
      receiptPath: receiptPath,
    );
    _db.expenses.add(expense);
    _notifyAdmins(
      type: NotificationType.expenseAdded,
      title: 'New expense added',
      message: '${actor.fullName} recorded ${category.name} expense.',
      businessId: expense.businessId,
      branchId: expense.branchId,
    );
    _audit(AuditAction.create, 'expenses', businessId: expense.businessId, branchId: expense.branchId, recordId: expense.id);
    await _save();
    return expense;
  }

  List<ExpenseCategory> categoriesFor(String? businessId) {
    return _db.expenseCategories
        .where((c) => businessId == null || c.businessId == businessId)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> upsertCategory({String? id, required String name, EntityStatus? status}) async {
    final actor = requireUser();
    if (!canManageCategories) throw ForbiddenException();
    final bizId = actor.businessId;
    if (bizId == null) throw ValidationException('Business context is missing.');
    if (id == null) {
      _db.expenseCategories.add(ExpenseCategory(
        id: _uuid.v4(),
        businessId: bizId,
        name: name.trim(),
        createdBy: actor.id,
      ));
      _audit(AuditAction.create, 'expense_category', businessId: bizId, newData: name);
    } else {
      final cat = _db.expenseCategories.firstWhere((c) => c.id == id);
      cat.name = name.trim();
      if (status != null) cat.status = status;
      cat.updatedAt = DateTime.now();
      _audit(AuditAction.update, 'expense_category', businessId: bizId, recordId: id);
    }
    await _save();
  }

  Future<void> upsertShift(Shift shift, {bool creating = false}) async {
    final actor = requireUser();
    if (actor.role != UserRole.businessAdmin && actor.role != UserRole.superAdmin) {
      throw ForbiddenException();
    }
    if (creating) {
      _db.shifts.add(shift);
      _audit(AuditAction.create, 'shift', businessId: shift.businessId, newData: shift.name);
    } else {
      final existing = _db.shifts.firstWhere((s) => s.id == shift.id);
      existing
        ..name = shift.name
        ..startTime = shift.startTime
        ..endTime = shift.endTime
        ..gracePeriodMinutes = shift.gracePeriodMinutes
        ..branchId = shift.branchId
        ..status = shift.status
        ..updatedAt = DateTime.now();
      _audit(AuditAction.update, 'shift', businessId: shift.businessId, recordId: shift.id);
    }
    await _save();
  }

  PublicMenu? get publicMenu => _db.publicMenu;
  PublicBusiness? get publicBusiness => _db.publicBusiness;

  Future<void> savePublicBusiness(PublicBusiness profile) async {
    final actor = requireUser();
    if (!canEditMenu || actor.businessId != profile.businessId) {
      throw ForbiddenException('You cannot publish this business page.');
    }
    final slug = profile.slug.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(slug)) {
      throw ValidationException('Slug can use lowercase letters, numbers, and hyphens.');
    }
    final previous = _db.publicBusiness;
    if (previous != null && previous.slug != slug) {
      previous.status = 'inactive';
      await _db.savePublicBusiness(previous);
    }
    profile.status = 'active';
    await _db.savePublicBusiness(PublicBusiness(
      slug: slug,
      businessId: profile.businessId,
      name: profile.name.trim(),
      branchId: profile.branchId,
      paymentAccountName: profile.paymentAccountName.trim(),
      paymentAccountNumber: profile.paymentAccountNumber.trim(),
      paymentInstructions: profile.paymentInstructions.trim(),
    ));
    _audit(AuditAction.update, 'publicBusiness', businessId: profile.businessId, newData: slug);
    await _save();
  }

  bool get canEditMenu {
    final user = currentUser;
    if (user == null || user.businessId == null) return false;
    return user.role == UserRole.businessAdmin &&
        (user.isOwner || user.permissions.fullAccess);
  }

  Future<void> savePublicMenu(PublicMenu menu) async {
    final actor = requireUser();
    if (!canEditMenu || actor.businessId != menu.businessId) {
      throw ForbiddenException('You cannot edit this menu.');
    }
    await _db.savePublicMenu(menu);
    _audit(AuditAction.update, 'publicMenu', businessId: menu.businessId, newData: '${menu.categories.length} categories');
    await _save();
  }

  Shift? shiftFor({required String businessId, String? branchId}) {
    final list = _db.shifts.where((s) => s.businessId == businessId && s.status == EntityStatus.active).toList();
    final exact = list.where((s) => s.branchId == branchId);
    if (exact.isNotEmpty) return exact.first;
    final general = list.where((s) => s.branchId == null);
    if (general.isNotEmpty) return general.first;
    return list.isEmpty ? null : list.first;
  }

  AttendanceRecord? openAttendance(String userId) {
    try {
      return _db.attendance.firstWhere((a) => a.userId == userId && a.checkOutAt == null);
    } catch (_) {
      return null;
    }
  }

  Future<AttendanceRecord> checkIn() async {
    final actor = requireUser();
    if (actor.role != UserRole.manager && actor.role != UserRole.employee) {
      throw ForbiddenException('Only managers and employees can check in.');
    }
    if (openAttendance(actor.id) != null) {
      throw ValidationException('You already have an active check-in.');
    }
    final branch = branchById(actor.branchId);
    if (branch == null) throw ValidationException('No branch is assigned.');
    if (!branch.hasLocation) {
      throw ValidationException('This branch has no shop GPS pin. Ask an admin to set it on the map.');
    }
    final loc = await _location.currentPosition(precise: true);
    if (loc.permissionDenied || !loc.hasPoint) {
      throw ValidationException(loc.error ?? 'Precise location is required to check in.');
    }
    final dist = LocationService.distanceMeters(
      loc.point!,
      GeoPoint(branch.latitude!, branch.longitude!),
    );
    final outside = dist > branch.geofenceRadius;
    final verified = !outside;
    if (outside && branch.blockOutsideGeofence) {
      throw ValidationException(
        'You are ${dist.round()}m away — outside the allowed ${branch.geofenceRadius.round()}m radius for ${branch.name}.',
      );
    }
    final now = DateTime.now();
    final shift = shiftFor(businessId: actor.businessId ?? '', branchId: actor.branchId);
    var status = AttendanceStatus.present;
    if (shift != null) {
      final start = _timeOn(now, shift.startTime).add(Duration(minutes: shift.gracePeriodMinutes));
      status = now.isAfter(start) ? AttendanceStatus.late : AttendanceStatus.onTime;
    }
    final record = AttendanceRecord(
      id: _uuid.v4(),
      businessId: actor.businessId ?? '',
      branchId: actor.branchId ?? '',
      userId: actor.id,
      role: actor.role,
      date: _day(now),
      checkInAt: now,
      checkInLatitude: loc.point!.latitude,
      checkInLongitude: loc.point!.longitude,
      checkInDistanceMeters: dist,
      checkInAccuracyMeters: loc.accuracyMeters,
      shiftId: shift?.id,
      status: status,
      locationVerified: verified,
      outsideGeofence: outside,
    );
    _db.attendance.add(record);
    final type = actor.role == UserRole.manager
        ? NotificationType.managerCheckin
        : NotificationType.employeeCheckin;
    _notifyAttendance(actor, type, 'checked in', record);
    _audit(AuditAction.create, 'attendance', businessId: record.businessId, branchId: record.branchId, recordId: record.id);
    await _save();
    return record;
  }

  Future<AttendanceRecord> checkOut() async {
    final actor = requireUser();
    final open = openAttendance(actor.id);
    if (open == null) throw ValidationException('You need to check in first.');
    final loc = await _location.currentPosition(precise: true);
    if (loc.permissionDenied || !loc.hasPoint) {
      throw ValidationException(loc.error ?? 'Precise location is required to check out.');
    }
    final now = DateTime.now();
    open.checkOutAt = now;
    open.checkOutLatitude = loc.point!.latitude;
    open.checkOutLongitude = loc.point!.longitude;
    open.workedMinutes = now.difference(open.checkInAt).inMinutes;
    final shift = shiftFor(businessId: actor.businessId ?? '', branchId: actor.branchId);
    if (shift != null) {
      final end = _timeOn(now, shift.endTime);
      if (now.isBefore(end)) {
        open.status = AttendanceStatus.earlyDeparture;
      } else if (open.status == AttendanceStatus.onTime || open.status == AttendanceStatus.present) {
        open.status = AttendanceStatus.onTime;
      }
    }
    if (open.status == AttendanceStatus.present) open.status = AttendanceStatus.onTime;
    open.updatedAt = now;
    final type = actor.role == UserRole.manager
        ? NotificationType.managerCheckout
        : NotificationType.employeeCheckout;
    _notifyAttendance(actor, type, 'checked out', open);
    _audit(AuditAction.update, 'attendance', businessId: open.businessId, recordId: open.id);
    await _save();
    return open;
  }

  DateTime _timeOn(DateTime day, String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 9;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return DateTime(day.year, day.month, day.day, h, m);
  }

  void _notifyAttendance(AppUser actor, NotificationType type, String verb, AttendanceRecord record) {
    _notifyAdmins(
      type: type,
      title: '${actor.fullName} $verb',
      message: '${roleLabel(actor.role)} $verb at ${branchName(actor.branchId)}.',
      businessId: actor.businessId,
      branchId: actor.branchId,
      relatedId: record.id,
      includeManagers: actor.role == UserRole.employee,
    );
    _notify(
      recipientUserId: actor.id,
      type: type,
      title: 'Attendance $verb',
      message: 'Your $verb was recorded.',
      businessId: actor.businessId,
      branchId: actor.branchId,
      relatedId: record.id,
    );
  }

  Future<void> correctAttendance({
    required String attendanceId,
    DateTime? checkInAt,
    DateTime? checkOutAt,
    required String reason,
  }) async {
    final actor = requireUser();
    if (actor.role != UserRole.businessAdmin && actor.role != UserRole.superAdmin) {
      throw ForbiddenException();
    }
    if (actor.role == UserRole.businessAdmin && !actor.permissions.canCorrectAttendance) {
      throw ForbiddenException();
    }
    if (reason.trim().isEmpty) throw ValidationException('A correction reason is required.');
    AttendanceRecord? record;
    try {
      record = _db.attendance.firstWhere((a) => a.id == attendanceId);
    } catch (_) {
      throw NotFoundException();
    }
    final prev = '${record.checkInAt} → ${record.checkOutAt}';
    if (checkInAt != null) record.checkInAt = checkInAt;
    if (checkOutAt != null) {
      record.checkOutAt = checkOutAt;
      record.workedMinutes = checkOutAt.difference(record.checkInAt).inMinutes;
    }
    record.correctionReason = reason.trim();
    record.correctedBy = actor.id;
    record.correctedAt = DateTime.now();
    record.updatedAt = DateTime.now();
    _audit(
      AuditAction.attendanceCorrection,
      'attendance',
      businessId: record.businessId,
      recordId: record.id,
      previousData: prev,
      newData: '${record.checkInAt} → ${record.checkOutAt}',
      reason: reason,
    );
    await _save();
  }

  double salesTotal({String? businessId, String? branchId, String? userId, PeriodFilter? period}) {
    return _filterSales(businessId: businessId, branchId: branchId, userId: userId, period: period)
        .fold<double>(0, (s, e) => s + e.amount);
  }

  double expensesTotal({String? businessId, String? branchId, String? userId, PeriodFilter? period}) {
    return _filterExpenses(businessId: businessId, branchId: branchId, userId: userId, period: period)
        .fold<double>(0, (s, e) => s + e.amount);
  }

  List<Sale> _filterSales({String? businessId, String? branchId, String? userId, PeriodFilter? period}) {
    return _db.sales.where((s) {
      if (businessId != null && s.businessId != businessId) return false;
      if (branchId != null && s.branchId != branchId) return false;
      if (userId != null && s.userId != userId) return false;
      if (period != null && !period.contains(s.date)) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<Expense> _filterExpenses({String? businessId, String? branchId, String? userId, PeriodFilter? period}) {
    return _db.expenses.where((s) {
      if (businessId != null && s.businessId != businessId) return false;
      if (branchId != null && s.branchId != branchId) return false;
      if (userId != null && s.userId != userId) return false;
      if (period != null && !period.contains(s.date)) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<Sale> visibleSales({PeriodFilter? period, String? branchId, String? userId}) {
    final actor = requireUser();
    return _filterSales(
      businessId: actor.role == UserRole.superAdmin ? null : actor.businessId,
      branchId: actor.role == UserRole.employee ? actor.branchId : (branchId ?? (actor.role == UserRole.manager ? actor.branchId : effectiveBranchId)),
      userId: actor.role == UserRole.employee ? actor.id : userId,
      period: period,
    );
  }

  List<Expense> visibleExpenses({PeriodFilter? period, String? branchId, String? userId}) {
    final actor = requireUser();
    return _filterExpenses(
      businessId: actor.role == UserRole.superAdmin ? null : actor.businessId,
      branchId: actor.role == UserRole.employee ? actor.branchId : (branchId ?? (actor.role == UserRole.manager ? actor.branchId : effectiveBranchId)),
      userId: actor.role == UserRole.employee ? actor.id : userId,
      period: period,
    );
  }

  /// Cash in hand is reproducible from cash sales minus cash expenses.
  /// Opening cash is the previous closing balance (starts at 0).
  double cashInHand({
    required DateTime from,
    required DateTime to,
    String? userId,
    String? branchId,
    String? businessId,
  }) {
    final cashSales = _db.sales.where((s) {
      if (!s.isCash) return false;
      if (businessId != null && s.businessId != businessId) return false;
      if (branchId != null && s.branchId != branchId) return false;
      if (userId != null && s.userId != userId) return false;
      return !s.date.isBefore(from) && s.date.isBefore(to);
    }).fold<double>(0, (p, e) => p + e.amount);
    final cashExpenses = _db.expenses.where((s) {
      if (!s.isCash) return false;
      if (businessId != null && s.businessId != businessId) return false;
      if (branchId != null && s.branchId != branchId) return false;
      if (userId != null && s.userId != userId) return false;
      return !s.date.isBefore(from) && s.date.isBefore(to);
    }).fold<double>(0, (p, e) => p + e.amount);
    return cashSales - cashExpenses;
  }

  Map<String, int> attendanceSummary({
    required DateTime day,
    String? businessId,
    String? branchId,
  }) {
    final people = _db.users.where((u) {
      if (u.role != UserRole.employee && u.role != UserRole.manager) return false;
      if (!u.isActive) return false;
      if (businessId != null && u.businessId != businessId) return false;
      if (branchId != null && u.branchId != branchId) return false;
      return true;
    }).toList();
    final records = _db.attendance.where((a) {
      if (_day(a.date) != _day(day)) return false;
      if (businessId != null && a.businessId != businessId) return false;
      if (branchId != null && a.branchId != branchId) return false;
      return true;
    }).toList();
    var present = 0, late = 0, absent = 0;
    for (final p in people) {
      AttendanceRecord? rec;
      try {
        rec = records.firstWhere((r) => r.userId == p.id);
      } catch (_) {
        rec = null;
      }
      if (rec == null) {
        absent++;
      } else if (rec.status == AttendanceStatus.late) {
        late++;
        present++;
      } else {
        present++;
      }
    }
    return {'present': present, 'late': late, 'absent': absent, 'total': people.length};
  }

  List<AttendanceRecord> visibleAttendance({PeriodFilter? period, String? branchId, String? userId}) {
    final actor = requireUser();
    return _db.attendance.where((a) {
      if (actor.role == UserRole.employee && a.userId != actor.id) return false;
      if (actor.role == UserRole.manager && a.branchId != actor.branchId) return false;
      if (actor.role == UserRole.businessAdmin && a.businessId != actor.businessId) return false;
      if (branchId != null && a.branchId != branchId) return false;
      if (userId != null && a.userId != userId) return false;
      if (period != null && !period.contains(a.checkInAt)) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.checkInAt.compareTo(a.checkInAt));
  }

  List<AppNotification> myNotifications({bool unreadOnly = false}) {
    final actor = currentUser;
    if (actor == null) return [];
    return _db.notifications.where((n) {
      if (n.recipientUserId != actor.id) return false;
      if (unreadOnly && n.isRead) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  int get unreadCount => myNotifications(unreadOnly: true).length;

  Future<void> markNotificationRead(String id, {bool read = true}) async {
    try {
      final n = _db.notifications.firstWhere((e) => e.id == id);
      n.isRead = read;
      await _save();
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    for (final n in myNotifications(unreadOnly: true)) {
      n.isRead = true;
    }
    await _save();
  }

  Future<void> submitPasswordRequest({required String email, String message = ''}) async {
    // Firebase Auth reset email works without a session and does not leak account existence.
    try {
      await _auth.sendPasswordResetEmail(email);
    } catch (_) {
      // Ignore Auth errors for privacy when email is unknown.
    }

    // In-app request trail is only available when an admin/manager session is loaded.
    if (currentUser == null) return;

    final user = userByEmail(email) ?? await _db.fetchUserByEmail(email);
    if (user == null) return;
    final existing = _db.passwordRequests.any(
      (r) => r.userId == user.id && r.status == PasswordResetStatus.pending,
    );
    if (existing) return;
    final req = PasswordResetRequest(
      id: _uuid.v4(),
      userId: user.id,
      email: user.email,
      businessId: user.businessId,
      branchId: user.branchId,
      message: message.trim(),
    );
    _db.passwordRequests.add(req);
    final recipients = _db.users.where((u) {
      if (!u.isActive) return false;
      if (user.role == UserRole.employee) {
        return (u.role == UserRole.manager && u.branchId == user.branchId) ||
            (u.role == UserRole.businessAdmin && u.businessId == user.businessId);
      }
      if (user.role == UserRole.manager) {
        return u.role == UserRole.businessAdmin && u.businessId == user.businessId;
      }
      return u.role == UserRole.superAdmin;
    });
    for (final r in recipients) {
      _notify(
        recipientUserId: r.id,
        type: NotificationType.passwordResetRequest,
        title: 'Password recovery request',
        message: '${user.fullName} requested a password reset.',
        businessId: user.businessId,
        relatedId: req.id,
      );
    }
    _audit(AuditAction.passwordRecovery, 'auth', businessId: user.businessId, recordId: user.id, actor: user);
    await _save();
  }

  PasswordResetRequest? latestRequestFor(String userId) {
    final list = _db.passwordRequests.where((r) => r.userId == userId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.isEmpty ? null : list.first;
  }

  List<PasswordResetRequest> pendingPasswordRequests() {
    final actor = requireUser();
    return _db.passwordRequests.where((r) {
      if (r.status != PasswordResetStatus.pending) return false;
      if (actor.role == UserRole.superAdmin) return true;
      if (actor.role == UserRole.businessAdmin) {
        return r.businessId == actor.businessId;
      }
      if (actor.role == UserRole.manager) {
        return r.branchId == actor.branchId;
      }
      return false;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> rejectPasswordRequest(String requestId) async {
    final actor = requireUser();
    if (actor.role == UserRole.employee) throw ForbiddenException();
    PasswordResetRequest? req;
    try {
      req = _db.passwordRequests.firstWhere((r) => r.id == requestId);
    } catch (_) {
      throw NotFoundException('Request not found.');
    }
    if (actor.role == UserRole.businessAdmin && req.businessId != actor.businessId) {
      throw ForbiddenException();
    }
    if (actor.role == UserRole.manager && req.branchId != actor.branchId) {
      throw ForbiddenException();
    }
    req.status = PasswordResetStatus.rejected;
    req.resolvedBy = actor.id;
    req.updatedAt = DateTime.now();
    _notify(
      recipientUserId: req.userId,
      type: NotificationType.passwordResetRequest,
      title: 'Password request rejected',
      message: 'Your password recovery request was rejected. Contact your manager if you still need help.',
      businessId: req.businessId,
      relatedId: req.id,
    );
    await _save();
  }

  Future<void> updateSettings({
    String? secretCode,
    double? geofenceRadius,
    bool? blockOutsideGeofence,
    bool? allowManagerCategories,
  }) async {
    final actor = requireUser();
    if (actor.role != UserRole.superAdmin) throw ForbiddenException();
    if (secretCode != null && secretCode.trim().isNotEmpty) {
      settings.secretCode = secretCode.trim();
    }
    if (geofenceRadius != null) settings.geofenceRadius = geofenceRadius;
    if (blockOutsideGeofence != null) settings.blockOutsideGeofence = blockOutsideGeofence;
    if (allowManagerCategories != null) settings.allowManagerCategories = allowManagerCategories;
    _audit(AuditAction.update, 'settings');
    await _save();
  }

  List<AuditLog> visibleLogs() {
    final actor = requireUser();
    return _db.auditLogs.where((l) {
      if (actor.role == UserRole.superAdmin) return true;
      if (actor.role == UserRole.businessAdmin) return l.businessId == actor.businessId;
      return false;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void _watchCustomerOrders(AppUser user) {
    _orderAlerts?.cancel();
    _seenOrderIds.clear();
    final businessId = user.businessId;
    if (user.role != UserRole.businessAdmin || businessId == null || businessId.isEmpty) return;
    var firstSnapshot = true;
    _orderAlerts = _db.watchCustomerOrders(businessId).listen((snap) {
      if (firstSnapshot) {
        _seenOrderIds.addAll(snap.docs.map((doc) => doc.id));
        firstSnapshot = false;
        return;
      }
      for (final doc in snap.docs) {
        if (!_seenOrderIds.add(doc.id)) continue;
        final data = doc.data();
        _notify(
          recipientUserId: user.id,
          type: NotificationType.system,
          title: 'New customer order',
          message: 'Order ${data['orderNumber'] ?? ''} · ${data['customerName'] ?? 'Customer'} · ${data['paymentReference'] ?? ''}',
          businessId: businessId,
          branchId: data['branchId']?.toString(),
          relatedId: doc.id,
        );
        _save();
        notifyListeners();
      }
    }, onError: (_) {});
  }

  void _notify({
    required String recipientUserId,
    required NotificationType type,
    required String title,
    required String message,
    String? businessId,
    String? branchId,
    String? relatedId,
  }) {
    _db.notifications.add(AppNotification(
      id: _uuid.v4(),
      recipientUserId: recipientUserId,
      type: type,
      title: title,
      message: message,
      businessId: businessId,
      branchId: branchId,
      relatedRecordId: relatedId,
    ));
  }

  void _notifyAdmins({
    required NotificationType type,
    required String title,
    required String message,
    String? businessId,
    String? branchId,
    String? relatedId,
    bool includeManagers = true,
  }) {
    for (final u in _db.users.where((u) => u.isActive)) {
      final isAdmin = u.role == UserRole.businessAdmin && u.businessId == businessId;
      final isMgr = includeManagers && u.role == UserRole.manager && u.branchId == branchId;
      if (isAdmin || isMgr) {
        _notify(
          recipientUserId: u.id,
          type: type,
          title: title,
          message: message,
          businessId: businessId,
          branchId: branchId,
          relatedId: relatedId,
        );
      }
    }
  }

  void _audit(
    AuditAction action,
    String module, {
    String? businessId,
    String? branchId,
    String? recordId,
    String? previousData,
    String? newData,
    String? reason,
    AppUser? actor,
  }) {
    final user = actor ?? currentUser;
    _db.auditLogs.add(AuditLog(
      id: _uuid.v4(),
      performedBy: user?.id ?? 'system',
      performedByRole: user?.role ?? UserRole.superAdmin,
      action: action,
      module: module,
      businessId: businessId ?? user?.businessId,
      branchId: branchId ?? user?.branchId,
      recordId: recordId,
      previousData: previousData,
      newData: newData,
      reason: reason,
    ));
  }
}
