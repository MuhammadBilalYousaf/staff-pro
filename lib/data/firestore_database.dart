import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:staffpro/core/constants/app_constants.dart';
import 'package:staffpro/core/constants/firestore_paths.dart';
import 'package:staffpro/models/enums.dart';
import 'package:staffpro/models/models.dart';

/// In-memory cache synced with Firestore collections used by [StaffProController].
class FirestoreDatabase {
  FirestoreDatabase._();
  static final FirestoreDatabase instance = FirestoreDatabase._();

  FirebaseFirestore get _fs => FirebaseFirestore.instance;

  final List<AppUser> users = [];
  final List<Business> businesses = [];
  final List<Branch> branches = [];
  final List<Shift> shifts = [];
  final List<Sale> sales = [];
  final List<Expense> expenses = [];
  final List<ExpenseCategory> expenseCategories = [];
  final List<AttendanceRecord> attendance = [];
  final List<AppNotification> notifications = [];
  final List<AuditLog> auditLogs = [];
  final List<BranchAssignment> assignments = [];
  final List<PasswordResetRequest> passwordRequests = [];
  PlatformSettings settings = PlatformSettings();

  bool _loaded = false;

  Future<void> init() async {
    if (_loaded) return;
    await ensurePlatformDocs();
    await _loadSettings();
    _loaded = true;
  }

  Future<void> ensurePlatformDocs() async {
    final settingsRef = _fs.collection(FirestorePaths.platform).doc(FirestorePaths.settingsDoc);
    final publicRef = _fs.collection(FirestorePaths.platform).doc(FirestorePaths.publicDoc);
    final bootstrapRef = _fs.collection(FirestorePaths.platform).doc(FirestorePaths.bootstrapDoc);

    try {
      final settingsSnap = await settingsRef.get();
      if (!settingsSnap.exists) {
        final defaults = PlatformSettings(secretCode: AppConstants.defaultSecretCode);
        await settingsRef.set(defaults.toJson());
        await publicRef.set({
          'secretCode': defaults.secretCode,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final data = settingsSnap.data() ?? {};
        final code = data['secretCode']?.toString() ?? AppConstants.defaultSecretCode;
        final publicSnap = await publicRef.get();
        if (!publicSnap.exists || publicSnap.data()?['secretCode'] != code) {
          await publicRef.set({
            'secretCode': code,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      final bootstrapSnap = await bootstrapRef.get();
      if (!bootstrapSnap.exists) {
        await bootstrapRef.set({'superAdminCreated': false});
      }
    } catch (_) {
      // After bootstrap closes, logged-out clients cannot read settings — safe to skip.
    }
  }

  Future<void> _loadSettings() async {
    try {
      final snap = await _fs.collection(FirestorePaths.platform).doc(FirestorePaths.settingsDoc).get();
      settings = PlatformSettings.fromJson(snap.data());
    } catch (_) {
      // Logged-out clients may be denied after bootstrap closes — keep defaults.
      settings = PlatformSettings(secretCode: AppConstants.defaultSecretCode);
    }
  }

  Future<String> readPublicSecretCode() async {
    final snap = await _fs.collection(FirestorePaths.platform).doc(FirestorePaths.publicDoc).get();
    return snap.data()?['secretCode']?.toString() ?? AppConstants.defaultSecretCode;
  }

  Future<bool> isBootstrapOpen() async {
    final snap = await _fs.collection(FirestorePaths.platform).doc(FirestorePaths.bootstrapDoc).get();
    return snap.data()?['superAdminCreated'] != true;
  }

  Future<void> markBootstrapComplete() async {
    await _fs.collection(FirestorePaths.platform).doc(FirestorePaths.bootstrapDoc).set({
      'superAdminCreated': true,
      'completedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<AppUser?> fetchUser(String uid) async {
    final snap = await _fs.collection(FirestorePaths.users).doc(uid).get();
    if (!snap.exists) return null;
    return _userFromDoc(snap);
  }

  Future<AppUser?> fetchUserByEmail(String email) async {
    final needle = email.trim().toLowerCase();
    try {
      final q = await _fs.collection(FirestorePaths.users).where('email', isEqualTo: needle).limit(1).get();
      if (q.docs.isEmpty) return null;
      return _userFromDoc(q.docs.first);
    } catch (_) {
      // Query may be denied by rules for scoped roles; Auth email uniqueness is authoritative.
      return null;
    }
  }

  /// Loads collections visible to [user] into the in-memory lists.
  Future<void> loadForUser(AppUser user) async {
    await _loadSettings();

    users
      ..clear()
      ..addAll(await _loadUsers(user));
    businesses
      ..clear()
      ..addAll(await _loadBusinesses(user));
    branches
      ..clear()
      ..addAll(await _loadBranches(user));
    shifts
      ..clear()
      ..addAll(await _loadByBusiness(FirestorePaths.shifts, user, Shift.fromJson));
    expenseCategories
      ..clear()
      ..addAll(await _loadByBusiness(FirestorePaths.expenseCategories, user, ExpenseCategory.fromJson));
    sales
      ..clear()
      ..addAll(await _loadSales(user));
    expenses
      ..clear()
      ..addAll(await _loadExpenses(user));
    attendance
      ..clear()
      ..addAll(await _loadAttendance(user));
    notifications
      ..clear()
      ..addAll(await _loadNotifications(user));
    auditLogs
      ..clear()
      ..addAll(await _loadAuditLogs(user));
    assignments
      ..clear()
      ..addAll(await _loadAssignments(user));
    passwordRequests
      ..clear()
      ..addAll(await _loadPasswordRequests(user));
  }

  Future<void> clearSessionCache() async {
    users.clear();
    businesses.clear();
    branches.clear();
    shifts.clear();
    sales.clear();
    expenses.clear();
    expenseCategories.clear();
    attendance.clear();
    notifications.clear();
    auditLogs.clear();
    assignments.clear();
    passwordRequests.clear();
  }

  /// Writes a single audit log (e.g. login/logout) without rewriting other collections.
  Future<void> upsertAuditLog(AuditLog log) async {
    await _fs.collection(FirestorePaths.auditLogs).doc(log.id).set(log.toJson(), SetOptions(merge: true));
  }

  /// Persists the in-memory snapshot, scoped to what [asRole] is allowed to write.
  ///
  /// [includePlatform] must be true only for Super Admin — platform docs are
  /// locked down in security rules.
  ///
  /// Without role scoping, login/save re-wrote every loaded doc and failed with
  /// permission-denied for Business Admin / Manager / Employee (e.g. `businesses`
  /// is not writable by managers/employees).
  Future<void> persist({
    bool includePlatform = false,
    UserRole? asRole,
    String? asUserId,
  }) async {
    final errors = <String>[];
    final role = asRole;
    final uid = asUserId;
    final isSa = role == UserRole.superAdmin;
    final isBa = role == UserRole.businessAdmin;
    final isMgr = role == UserRole.manager;
    final canWriteOrg = isSa || isBa || role == null;

    Future<void> section(String name, Future<void> Function() body) async {
      try {
        await body();
      } catch (e) {
        errors.add('$name: $e');
      }
    }

    if (includePlatform && (isSa || role == null)) {
      await section('platform', () async {
        await _fs.collection(FirestorePaths.platform).doc(FirestorePaths.settingsDoc).set(
              settings.toJson(),
              SetOptions(merge: true),
            );
        await _fs.collection(FirestorePaths.platform).doc(FirestorePaths.publicDoc).set({
          'secretCode': settings.secretCode,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    }

    // Users: elevated roles write their scoped list; others only their own profile.
    final usersToWrite = (isSa || isBa || role == null)
        ? users
        : isMgr
            ? users.where((u) => u.id == uid || u.role == UserRole.employee)
            : users.where((u) => u.id == uid);
    await section(
      'users',
      () => _upsertAll(FirestorePaths.users, usersToWrite.map((e) => MapEntry(e.id, e.toFirestore()))),
    );

    if (canWriteOrg) {
      await section(
        'businesses',
        () => _upsertAll(FirestorePaths.businesses, businesses.map((e) => MapEntry(e.id, e.toJson()))),
      );
      await section(
        'branches',
        () => _upsertAll(FirestorePaths.branches, branches.map((e) => MapEntry(e.id, e.toJson()))),
      );
      await section(
        'shifts',
        () => _upsertAll(FirestorePaths.shifts, shifts.map((e) => MapEntry(e.id, e.toJson()))),
      );
    }

    // Sales / expenses / attendance: non-elevated roles may only write own rows.
    final ownOnly = !canWriteOrg && uid != null;
    final salesToWrite = ownOnly ? sales.where((e) => e.userId == uid) : sales;
    final expensesToWrite = ownOnly ? expenses.where((e) => e.userId == uid) : expenses;
    final attendanceToWrite = ownOnly ? attendance.where((e) => e.userId == uid) : attendance;

    await section(
      'sales',
      () => _upsertAll(FirestorePaths.sales, salesToWrite.map((e) => MapEntry(e.id, e.toJson()))),
    );
    await section(
      'expenses',
      () => _upsertAll(FirestorePaths.expenses, expensesToWrite.map((e) => MapEntry(e.id, e.toJson()))),
    );

    if (canWriteOrg || isMgr) {
      await section(
        'expenseCategories',
        () => _upsertAll(
              FirestorePaths.expenseCategories,
              expenseCategories.map((e) => MapEntry(e.id, e.toJson())),
            ),
      );
    }

    await section(
      'attendance',
      () => _upsertAll(FirestorePaths.attendance, attendanceToWrite.map((e) => MapEntry(e.id, e.toJson()))),
    );
    await section(
      'notifications',
      () => _upsertAll(
            FirestorePaths.notifications,
            notifications.map((e) => MapEntry(e.id, e.toJson())),
          ),
    );
    await section(
      'auditLogs',
      () => _upsertAll(FirestorePaths.auditLogs, auditLogs.map((e) => MapEntry(e.id, e.toJson()))),
    );

    if (canWriteOrg) {
      await section(
        'assignments',
        () => _upsertAll(FirestorePaths.assignments, assignments.map((e) => MapEntry(e.id, e.toJson()))),
      );
    }

    if (canWriteOrg || isMgr || role == UserRole.employee) {
      await section(
        'passwordRequests',
        () => _upsertAll(
              FirestorePaths.passwordRequests,
              passwordRequests.map((e) => MapEntry(e.id, e.toJson())),
            ),
      );
    }

    if (errors.isNotEmpty) {
      throw StateError('Firestore persist failed → ${errors.join(' | ')}');
    }
  }

  Future<void> upsertUser(AppUser user) async {
    await _fs.collection(FirestorePaths.users).doc(user.id).set(user.toFirestore(), SetOptions(merge: true));
    final idx = users.indexWhere((u) => u.id == user.id);
    if (idx >= 0) {
      users[idx] = user;
    } else {
      users.add(user);
    }
  }

  Future<void> _upsertAll(String collection, Iterable<MapEntry<String, Map<String, dynamic>>> entries) async {
    final list = entries.toList();
    const chunk = 400;
    for (var i = 0; i < list.length; i += chunk) {
      final batch = _fs.batch();
      final slice = list.sublist(i, i + chunk > list.length ? list.length : i + chunk);
      for (final e in slice) {
        batch.set(_fs.collection(collection).doc(e.key), e.value, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  Future<List<AppUser>> _loadUsers(AppUser user) async {
    Query<Map<String, dynamic>> q = _fs.collection(FirestorePaths.users);
    if (user.role == UserRole.superAdmin) {
      // all users
    } else if (user.role == UserRole.businessAdmin) {
      q = q.where('businessId', isEqualTo: user.businessId);
    } else if (user.role == UserRole.manager) {
      q = q.where('branchId', isEqualTo: user.branchId);
    } else {
      final self = await fetchUser(user.id);
      return self == null ? <AppUser>[] : [self];
    }
    final snap = await q.get();
    final list = snap.docs.map(_userFromDoc).toList();
    if (!list.any((u) => u.id == user.id)) {
      final self = await fetchUser(user.id);
      if (self != null) list.add(self);
    }
    return list;
  }

  Future<List<Business>> _loadBusinesses(AppUser user) async {
    if (user.role == UserRole.superAdmin) {
      final snap = await _fs.collection(FirestorePaths.businesses).get();
      return snap.docs.map((d) => Business.fromJson(_normalize(d))).toList();
    }
    if (user.businessId == null) return [];
    final snap = await _fs.collection(FirestorePaths.businesses).doc(user.businessId).get();
    if (!snap.exists) return [];
    return [Business.fromJson(_normalize(snap))];
  }

  Future<List<Branch>> _loadBranches(AppUser user) async {
    Query<Map<String, dynamic>> q = _fs.collection(FirestorePaths.branches);
    if (user.role == UserRole.superAdmin) {
      // all
    } else if (user.role == UserRole.businessAdmin) {
      q = q.where('businessId', isEqualTo: user.businessId);
    } else if (user.branchId != null) {
      final snap = await _fs.collection(FirestorePaths.branches).doc(user.branchId).get();
      if (!snap.exists) return [];
      return [Branch.fromJson(_normalize(snap))];
    } else {
      return [];
    }
    final snap = await q.get();
    return snap.docs.map((d) => Branch.fromJson(_normalize(d))).toList();
  }

  Future<List<T>> _loadByBusiness<T>(
    String collection,
    AppUser user,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    Query<Map<String, dynamic>> q = _fs.collection(collection);
    if (user.role != UserRole.superAdmin) {
      if (user.businessId == null) return [];
      q = q.where('businessId', isEqualTo: user.businessId);
    }
    final snap = await q.get();
    return snap.docs.map((d) => fromJson(_normalize(d))).toList();
  }

  Future<List<Sale>> _loadSales(AppUser user) async {
    Query<Map<String, dynamic>> q = _fs.collection(FirestorePaths.sales);
    if (user.role == UserRole.superAdmin) {
      // all
    } else if (user.role == UserRole.businessAdmin) {
      q = q.where('businessId', isEqualTo: user.businessId);
    } else if (user.role == UserRole.manager) {
      q = q.where('branchId', isEqualTo: user.branchId);
    } else {
      q = q.where('userId', isEqualTo: user.id);
    }
    final snap = await q.get();
    return snap.docs.map((d) => Sale.fromJson(_normalize(d))).toList();
  }

  Future<List<Expense>> _loadExpenses(AppUser user) async {
    Query<Map<String, dynamic>> q = _fs.collection(FirestorePaths.expenses);
    if (user.role == UserRole.superAdmin) {
      // all
    } else if (user.role == UserRole.businessAdmin) {
      q = q.where('businessId', isEqualTo: user.businessId);
    } else if (user.role == UserRole.manager) {
      q = q.where('branchId', isEqualTo: user.branchId);
    } else {
      q = q.where('userId', isEqualTo: user.id);
    }
    final snap = await q.get();
    return snap.docs.map((d) => Expense.fromJson(_normalize(d))).toList();
  }

  Future<List<AttendanceRecord>> _loadAttendance(AppUser user) async {
    Query<Map<String, dynamic>> q = _fs.collection(FirestorePaths.attendance);
    if (user.role == UserRole.superAdmin) {
      // all
    } else if (user.role == UserRole.businessAdmin) {
      q = q.where('businessId', isEqualTo: user.businessId);
    } else if (user.role == UserRole.manager) {
      q = q.where('branchId', isEqualTo: user.branchId);
    } else {
      q = q.where('userId', isEqualTo: user.id);
    }
    final snap = await q.get();
    return snap.docs.map((d) => AttendanceRecord.fromJson(_normalize(d))).toList();
  }

  Future<List<AppNotification>> _loadNotifications(AppUser user) async {
    final snap = await _fs
        .collection(FirestorePaths.notifications)
        .where('recipientUserId', isEqualTo: user.id)
        .get();
    return snap.docs.map((d) => AppNotification.fromJson(_normalize(d))).toList();
  }

  Future<List<AuditLog>> _loadAuditLogs(AppUser user) async {
    if (user.role == UserRole.employee || user.role == UserRole.manager) {
      return [];
    }
    Query<Map<String, dynamic>> q = _fs.collection(FirestorePaths.auditLogs);
    if (user.role == UserRole.businessAdmin) {
      q = q.where('businessId', isEqualTo: user.businessId);
    }
    final snap = await q.get();
    return snap.docs.map((d) => AuditLog.fromJson(_normalize(d))).toList();
  }

  Future<List<BranchAssignment>> _loadAssignments(AppUser user) async {
    Query<Map<String, dynamic>> q = _fs.collection(FirestorePaths.assignments);
    if (user.role == UserRole.superAdmin) {
      // all
    } else if (user.role == UserRole.businessAdmin) {
      q = q.where('businessId', isEqualTo: user.businessId);
    } else {
      q = q.where('userId', isEqualTo: user.id);
    }
    final snap = await q.get();
    return snap.docs.map((d) => BranchAssignment.fromJson(_normalize(d))).toList();
  }

  Future<List<PasswordResetRequest>> _loadPasswordRequests(AppUser user) async {
    Query<Map<String, dynamic>> q = _fs.collection(FirestorePaths.passwordRequests);
    if (user.role == UserRole.superAdmin) {
      // all
    } else if (user.role == UserRole.businessAdmin) {
      q = q.where('businessId', isEqualTo: user.businessId);
    } else if (user.role == UserRole.manager) {
      q = q.where('branchId', isEqualTo: user.branchId);
    } else {
      q = q.where('userId', isEqualTo: user.id);
    }
    final snap = await q.get();
    return snap.docs.map((d) => PasswordResetRequest.fromJson(_normalize(d))).toList();
  }

  AppUser _userFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return AppUser.fromJson(_normalize(doc));
  }

  Map<String, dynamic> _normalize(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = Map<String, dynamic>.from(doc.data() ?? {});
    data['id'] = doc.id;
    return data.map((key, value) {
      if (value is Timestamp) {
        return MapEntry(key, value.toDate().toIso8601String());
      }
      if (value is Map) {
        return MapEntry(key, Map<String, dynamic>.from(value));
      }
      return MapEntry(key, value);
    });
  }
}
