import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:staffpro/core/constants/app_constants.dart';
import 'package:staffpro/core/constants/firestore_paths.dart';
import 'package:staffpro/core/errors/app_exception.dart';
import 'package:staffpro/models/enums.dart';
import 'package:staffpro/models/models.dart';
import 'package:staffpro/state/app_state.dart';

class QaReport {
  final List<String> passed = [];
  final List<String> failed = [];

  void ok(String name) => passed.add(name);
  void fail(String name, Object error) => failed.add('$name — $error');

  int get total => passed.length + failed.length;
  bool get success => failed.isEmpty;

  String summary() {
    final buf = StringBuffer()
      ..writeln('')
      ..writeln('========== STAFFPRO FULL QA ==========')
      ..writeln('Passed: ${passed.length} / $total')
      ..writeln('Failed: ${failed.length} / $total');
    for (final p in passed) {
      buf.writeln('  PASS  $p');
    }
    for (final f in failed) {
      buf.writeln('  FAIL  $f');
    }
    buf.writeln('======================================');
    return buf.toString();
  }
}

/// End-to-end QA against live Firebase Auth + Firestore (Spark / free).
class FullQaSuite {
  FullQaSuite(this.app, this.router);

  final StaffProController app;
  final GoRouter router;
  final QaReport report = QaReport();

  static const saEmail = 'qa.superadmin@staffpro.test';
  static const saPassword = 'Test1234!';
  static const saName = 'QA Super Admin';

  Future<QaReport> run() async {
    final stamp = DateTime.now().millisecondsSinceEpoch % 1000000;
    debugPrint('QA suite starting (stamp=$stamp)…');

    await _step('Platform docs seed', () async {
      await app.db.init();
      final secret = await app.db.readPublicSecretCode();
      if (secret.isEmpty) throw StateError('public secret missing');
    });

    await _step('Auth · Super Admin signup/login', () async {
      Object? signupError;
      try {
        await app.signupSuperAdmin(
          fullName: saName,
          email: saEmail,
          password: saPassword,
          confirm: saPassword,
          secretCode: AppConstants.defaultSecretCode,
        );
      } catch (e) {
        signupError = e;
      }
      if (app.currentUser == null) {
        await app.login(saEmail, saPassword);
      }
      if (app.currentUser?.role != UserRole.superAdmin) {
        throw StateError(
          'expected superAdmin, got ${app.currentUser?.role}; signupError=$signupError',
        );
      }
    });

    await _step('Auth · wrong password rejected', () async {
      await app.logout();
      try {
        await app.login(saEmail, 'WrongPassword!!');
        throw StateError('login should have failed');
      } on AuthException {
        // expected
      }
      await app.login(saEmail, saPassword);
    });

    await _step('Nav · Super Admin routes stay in /sa', () async {
      await _walkRoutes(const [
        '/sa',
        '/sa/businesses',
        '/sa/reports',
        '/sa/notifications',
        '/sa/more',
        '/sa/admins',
        '/sa/logs',
        '/sa/profile',
        '/sa/settings',
        '/sa/help',
        '/sa/about',
      ], prefix: '/sa');
    });

    Business? business;
    Branch? branch;
    String? adminEmail;
    String? managerEmail;
    String? employeeEmail;
    const adminPassword = 'Admin1234!';
    const managerPassword = 'Manager1234!';
    const employeePassword = 'Employee1234!';

    await _step('SA · create business + owner admin', () async {
      adminEmail = 'qa.admin$stamp@staffpro.test';
      business = await app.createBusiness(
        name: 'QA Biz $stamp',
        code: 'Q$stamp',
        phone: '03001111111',
        email: 'biz$stamp@staffpro.test',
        address: 'QA Street',
        city: 'Lahore',
        adminName: 'QA Admin $stamp',
        adminEmail: adminEmail!,
        adminPhone: '03002222222',
        adminPassword: adminPassword,
      );
      if (app.db.businesses.every((b) => b.id != business!.id)) {
        throw StateError('business not in cache');
      }
    });

    await _step('SA · create branch with GPS', () async {
      final biz = business;
      if (biz == null) throw StateError('skipped — business missing');
      branch = await app.createBranch(
        name: 'QA Branch $stamp',
        businessId: biz.id,
        code: 'B$stamp',
        phone: '03003333333',
        address: 'Branch Rd',
        city: 'Lahore',
        latitude: 31.5204,
        longitude: 74.3587,
        geofenceRadius: 200,
      );
    });

    await _step('SA · create manager + employee', () async {
      final biz = business;
      final br = branch;
      if (biz == null || br == null) throw StateError('skipped — business/branch missing');
      managerEmail = 'qa.mgr$stamp@staffpro.test';
      employeeEmail = 'qa.emp$stamp@staffpro.test';
      await app.createStaff(
        role: UserRole.manager,
        fullName: 'QA Manager $stamp',
        email: managerEmail!,
        phone: '03004444444',
        password: managerPassword,
        businessId: biz.id,
        branchId: br.id,
        employeeCode: 'M$stamp',
      );
      await app.createStaff(
        role: UserRole.employee,
        fullName: 'QA Employee $stamp',
        email: employeeEmail!,
        phone: '03005555555',
        password: employeePassword,
        businessId: biz.id,
        branchId: br.id,
        employeeCode: 'E$stamp',
        position: 'Cashier',
      );
    });

    await _step('SA · settings write/read', () async {
      await app.updateSettings(
        geofenceRadius: 220,
        blockOutsideGeofence: true,
        allowManagerCategories: true,
      );
      if (app.settings.geofenceRadius != 220) throw StateError('settings not updated');
      await app.updateSettings(
        geofenceRadius: 200,
        blockOutsideGeofence: false,
        allowManagerCategories: false,
      );
    });

    await _step('SA · deactivate / reactivate business', () async {
      final biz = business;
      if (biz == null) throw StateError('skipped — business missing');
      await app.setBusinessStatus(biz.id, EntityStatus.inactive);
      if (app.businessById(biz.id)?.status != EntityStatus.inactive) {
        throw StateError('inactive failed');
      }
      await app.setBusinessStatus(biz.id, EntityStatus.active);
    });

    await _step('Firestore · SA documents persisted', () async {
      final biz = business;
      final br = branch;
      if (biz == null || br == null) throw StateError('skipped — business/branch missing');
      final remote = await app.db.fetchUser(app.currentUser!.id);
      if (remote == null || remote.role != UserRole.superAdmin) {
        throw StateError('user doc missing/wrong role');
      }
      final bizDoc = await FirebaseFirestore.instance
          .collection(FirestorePaths.businesses)
          .doc(biz.id)
          .get();
      if (!bizDoc.exists) throw StateError('business doc missing in Firestore');
      final branchDoc = await FirebaseFirestore.instance
          .collection(FirestorePaths.branches)
          .doc(br.id)
          .get();
      if (!branchDoc.exists) throw StateError('branch doc missing');
    });

    await _step('Auth · login as Business Admin', () async {
      final email = adminEmail;
      if (email == null) throw StateError('skipped — admin email missing');
      await app.logout();
      await app.login(email, adminPassword);
      if (app.currentUser?.role != UserRole.businessAdmin) {
        throw StateError('expected businessAdmin');
      }
    });

    await _step('Nav · Business Admin routes stay in /ba', () async {
      await _walkRoutes(const [
        '/ba',
        '/ba/branches',
        '/ba/employees',
        '/ba/reports',
        '/ba/more',
        '/ba/sales',
        '/ba/expenses',
        '/ba/attendance',
        '/ba/categories',
        '/ba/shifts',
        '/ba/managers',
        '/ba/notifications',
        '/ba/profile',
      ], prefix: '/ba');
    });

    await _step('BA · cannot create another business', () async {
      try {
        await app.createBusiness(
          name: 'Hack Co',
          adminName: 'X',
          adminEmail: 'hack$stamp@staffpro.test',
          adminPhone: '1',
          adminPassword: 'Hack1234!',
        );
        throw StateError('BA should not create businesses');
      } on ForbiddenException {
        // expected
      }
    });

    await _step('BA · sale + expense + category + shift + cash', () async {
      final biz = business;
      final br = branch;
      if (biz == null || br == null) throw StateError('skipped — business/branch missing');
      await app.setSelectedBranch(br.id);
      final cats = app.categoriesFor(biz.id);
      if (cats.isEmpty) throw StateError('default categories missing');
      await app.upsertCategory(name: 'QA Misc $stamp');
      await app.addSale(
        amount: 1500,
        date: DateTime.now(),
        category: 'Retail',
        paymentMethod: 'Cash',
        description: 'QA sale',
        branchId: br.id,
      );
      await app.addExpense(
        amount: 200,
        date: DateTime.now(),
        categoryId: cats.first.id,
        paymentMethod: 'Cash',
        description: 'QA expense',
        branchId: br.id,
      );
      final shift = Shift(
        id: 'qa-shift-$stamp',
        businessId: biz.id,
        branchId: br.id,
        name: 'QA Shift',
        startTime: '09:00',
        endTime: '18:00',
        gracePeriodMinutes: 15,
      );
      await app.upsertShift(shift, creating: true);
      final now = DateTime.now();
      final cash = app.cashInHand(
        from: DateTime(now.year, now.month, now.day),
        to: now.add(const Duration(days: 1)),
        branchId: br.id,
        businessId: biz.id,
      );
      if (cash != 1300) throw StateError('cashInHand expected 1300, got $cash');
    });

    await _step('Rules · BA cannot create foreign business doc', () async {
      try {
        await FirebaseFirestore.instance.collection(FirestorePaths.businesses).doc('nope-$stamp').set({
          'id': 'nope-$stamp',
          'name': 'Forbidden',
          'status': 'active',
        });
        throw StateError('rules allowed unauthorized business create');
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
      }
    });

    await _step('Auth · login as Manager', () async {
      final email = managerEmail;
      final br = branch;
      if (email == null || br == null) throw StateError('skipped — manager/branch missing');
      await app.logout();
      await app.login(email, managerPassword);
      if (app.currentUser?.role != UserRole.manager) throw StateError('expected manager');
      if (app.currentUser?.branchId != br.id) throw StateError('manager branch mismatch');
    });

    await _step('Nav · Manager routes stay in /mg', () async {
      await _walkRoutes(const [
        '/mg',
        '/mg/employees',
        '/mg/sales',
        '/mg/attendance',
        '/mg/more',
        '/mg/expenses',
        '/mg/reports',
        '/mg/notifications',
        '/mg/profile',
      ], prefix: '/mg');
    });

    await _step('Manager · create employee + sale + attendance', () async {
      final br = branch;
      if (br == null) throw StateError('skipped — branch missing');
      await app.createStaff(
        role: UserRole.employee,
        fullName: 'QA Emp2 $stamp',
        email: 'qa.emp2$stamp@staffpro.test',
        phone: '03006666666',
        password: employeePassword,
        branchId: br.id,
        employeeCode: 'E2$stamp',
      );
      await app.addSale(
        amount: 500,
        date: DateTime.now(),
        category: 'Services',
        paymentMethod: 'Card',
        branchId: br.id,
      );
      final record = await app.checkIn();
      if (!record.locationVerified) {
        throw StateError('check-in should be inside geofence (verified=${record.locationVerified}, outside=${record.outsideGeofence})');
      }
      await app.checkOut();
      if (app.openAttendance(app.currentUser!.id) != null) {
        throw StateError('checkout left open attendance');
      }
    });

    await _step('Manager · cannot create businessAdmin', () async {
      if (app.canCreateRole(UserRole.businessAdmin)) {
        throw StateError('manager must not create admins');
      }
      try {
        await app.createStaff(
          role: UserRole.businessAdmin,
          fullName: 'Nope',
          email: 'nope.admin$stamp@staffpro.test',
          phone: '1',
          password: 'Nope1234!',
          businessId: business?.id,
        );
        throw StateError('manager created admin');
      } on ForbiddenException {
        // expected
      }
    });

    await _step('Rules · manager cannot update SA user doc', () async {
      final sa = await app.db.fetchUserByEmail(saEmail);
      if (sa == null) throw StateError('SA user missing');
      try {
        await FirebaseFirestore.instance.collection(FirestorePaths.users).doc(sa.id).update({
          'fullName': 'Hacked',
        });
        throw StateError('rules allowed manager to edit SA');
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
      }
    });

    await _step('Auth · login as Employee', () async {
      final email = employeeEmail;
      if (email == null) throw StateError('skipped — employee email missing');
      await app.logout();
      await app.login(email, employeePassword);
      if (app.currentUser?.role != UserRole.employee) throw StateError('expected employee');
    });

    await _step('Nav · Employee routes stay in /emp', () async {
      await _walkRoutes(const [
        '/emp',
        '/emp/sales',
        '/emp/expenses',
        '/emp/attendance',
        '/emp/more',
        '/emp/cash',
        '/emp/profile',
        '/emp/notifications',
      ], prefix: '/emp');
    });

    await _step('Employee · own sale/expense + scoped lists', () async {
      await app.addSale(
        amount: 100,
        date: DateTime.now(),
        category: 'Other',
        paymentMethod: 'Cash',
      );
      final cats = app.categoriesFor(app.currentUser!.businessId);
      await app.addExpense(
        amount: 25,
        date: DateTime.now(),
        categoryId: cats.first.id,
        paymentMethod: 'Cash',
      );
      final sales = app.visibleSales();
      if (sales.any((s) => s.userId != app.currentUser!.id)) {
        throw StateError('employee saw another user sale');
      }
    });

    await _step('Employee · cannot switch branch / create staff', () async {
      try {
        await app.setSelectedBranch('other');
        throw StateError('employee switched branch');
      } on ForbiddenException {
        // expected
      }
      if (app.canCreateRole(UserRole.employee)) {
        throw StateError('employee should not create staff');
      }
    });

    await _step('Rules · employee cannot read auditLogs', () async {
      try {
        await FirebaseFirestore.instance.collection(FirestorePaths.auditLogs).limit(1).get();
        throw StateError('employee read auditLogs');
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
      }
    });

    await _step('Auth · forgot password path', () async {
      final email = employeeEmail;
      if (email == null) throw StateError('skipped — employee email missing');
      await app.submitPasswordRequest(email: email, message: 'QA recovery');
    });

    await _step('Auth · re-login Super Admin + persisted data', () async {
      await app.logout();
      await app.login(saEmail, saPassword);
      await app.db.loadForUser(app.currentUser!);
      if (app.db.businesses.isEmpty) throw StateError('SA lost businesses after reload');
      if (app.db.sales.isEmpty) throw StateError('SA lost sales after reload');
      if (app.visibleLogs().isEmpty) throw StateError('audit logs empty');
    });

    await _step('Nav · role isolation (SA redirected from /ba)', () async {
      router.go('/ba');
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final loc = router.state.uri.path;
      if (!loc.startsWith('/sa')) throw StateError('SA stayed on $loc');
    });

    debugPrint(report.summary());
    return report;
  }

  Future<void> _walkRoutes(List<String> paths, {required String prefix}) async {
    for (final path in paths) {
      router.go(path);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final loc = router.state.uri.path;
      if (!loc.startsWith(prefix)) {
        throw StateError('$path redirected to $loc (expected $prefix*)');
      }
    }
  }

  Future<void> _step(String name, Future<void> Function() body) async {
    try {
      await body();
      report.ok(name);
      debugPrint('PASS · $name');
    } catch (e, st) {
      report.fail(name, e);
      debugPrint('FAIL · $name — $e');
      debugPrint('$st');
    }
  }
}
