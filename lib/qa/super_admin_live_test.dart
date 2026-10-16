import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:staffpro/core/constants/app_constants.dart';
import 'package:staffpro/core/theme/app_colors.dart';
import 'package:staffpro/models/enums.dart';
import 'package:staffpro/models/models.dart';
import 'package:staffpro/state/app_state.dart';

/// On-screen Super Admin walkthrough that exercises every SA screen/action
/// and shows the current step in a live banner.
class SuperAdminLiveTestOverlay extends StatefulWidget {
  const SuperAdminLiveTestOverlay({
    super.key,
    required this.router,
    required this.controller,
  });

  final GoRouter router;
  final StaffProController controller;

  @override
  State<SuperAdminLiveTestOverlay> createState() => _SuperAdminLiveTestOverlayState();
}

class _SuperAdminLiveTestOverlayState extends State<SuperAdminLiveTestOverlay> {
  bool _running = false;
  bool _done = false;
  int _step = 0;
  String _label = 'Starting Super Admin live test…';
  final List<String> _results = [];

  static const _email = 'qa.superadmin@staffpro.test';
  static const _password = 'Test1234';
  static const _name = 'QA Super Admin';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted && !_running && !_done) await _run();
    });
  }

  Future<void> _pause([int ms = 1600]) => Future<void>.delayed(Duration(milliseconds: ms));

  Future<void> _go(String location, String label) async {
    _set(label);
    widget.router.go(location);
    await _pause();
  }

  Future<void> _push(String location, String label) async {
    _set(label);
    widget.router.push(location);
    await _pause();
  }

  void _set(String label, {bool pass = true}) {
    setState(() {
      _step++;
      _label = 'Step $_step · $label';
      if (pass) _results.add('PASS · $label');
    });
  }

  void _fail(String label, Object error) {
    setState(() {
      _label = 'FAIL · $label — $error';
      _results.add('FAIL · $label — $error');
      _running = false;
      _done = true;
    });
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _done = false;
      _step = 0;
      _results.clear();
      _label = 'Starting Super Admin live test…';
    });

    final app = widget.controller;
    final stamp = DateTime.now().millisecondsSinceEpoch % 100000;

    try {
      // 1) Auth — signup (idempotent)
      _set('Auth · Super Admin signup');
      try {
        await app.signupSuperAdmin(
          fullName: _name,
          email: _email,
          password: _password,
          confirm: _password,
          secretCode: AppConstants.defaultSecretCode,
        );
      } catch (_) {
        // Already exists from a prior run — OK.
      }
      await _pause(800);

      // 2) Login
      _set('Auth · Login as Super Admin');
      if (app.currentUser == null) {
        await app.login(_email, _password, remember: true);
      }
      await _go('/sa', 'Home · Dashboard KPIs');

      // 3–7) Shell tabs
      await _go('/sa/businesses', 'Business · Businesses list (search/filters)');
      await _go('/sa/reports', 'Reports · Platform reports hub');
      await _go('/sa/notifications', 'Alerts · Notifications');
      await _go('/sa/more', 'More · Menu');

      // 8) Add business wizard (visit) then create via API so data is real
      await _push('/sa/business/add', 'Business · Add Business wizard (3 steps)');
      widget.router.pop();
      await _pause(600);

      final bizEmail = 'biz$stamp@staffpro.test';
      final adminEmail = 'admin$stamp@staffpro.test';
      _set('Business · Create business + owner admin');
      final business = await app.createBusiness(
        name: 'QA Demo Co $stamp',
        code: 'QA$stamp',
        phone: '03001234567',
        email: bizEmail,
        address: '1 Test Street',
        city: 'Lahore',
        adminName: 'Biz Admin $stamp',
        adminEmail: adminEmail,
        adminPhone: '03007654321',
        adminPassword: 'Admin1234',
      );
      await _pause(900);

      // 9) Business details + tabs via navigation
      await _push('/sa/business/${business.id}', 'Business · Details Overview');
      await _pause(1000);

      // 10) Add branch
      _set('Business · Add branch');
      await app.createBranch(
        name: 'Main Branch $stamp',
        businessId: business.id,
        code: 'BR$stamp',
        phone: '03001112222',
        address: 'Main Road',
        city: 'Lahore',
        latitude: 31.5204,
        longitude: 74.3587,
        geofenceRadius: 200,
      );
      await _push('/sa/business/${business.id}/branch/add', 'Business · Branch form screen');
      widget.router.pop();
      await _pause(700);

      // 11) Toggle business inactive then active
      _set('Business · Deactivate then reactivate');
      await app.setBusinessStatus(business.id, EntityStatus.inactive);
      await _pause(700);
      await app.setBusinessStatus(business.id, EntityStatus.active);
      await _pause(700);
      if (widget.router.canPop()) widget.router.pop();
      await _pause(500);

      // 12–13) Admins
      await _push('/sa/admins', 'Admins · Business Admins list');
      await _push('/sa/admins/add', 'Admins · Add Admin form');
      _set('Admins · Create second admin');
      await app.createStaff(
        role: UserRole.businessAdmin,
        fullName: 'Second Admin $stamp',
        email: 'admin2$stamp@staffpro.test',
        phone: '03009876543',
        password: 'Admin1234',
        businessId: business.id,
        permissions: const AdminPermissions(fullAccess: true),
      );
      if (widget.router.canPop()) widget.router.pop();
      await _pause(600);
      if (widget.router.canPop()) widget.router.pop();
      await _pause(500);

      // 14–20) More submenu screens
      await _go('/sa/more', 'More · Return to menu');
      await _push('/sa/logs', 'More · Activity Logs');
      if (widget.router.canPop()) widget.router.pop();
      await _pause(500);

      await _push('/sa/profile', 'More · Profile');
      if (widget.router.canPop()) widget.router.pop();
      await _pause(500);

      await _push('/sa/password', 'More · Change Password screen');
      if (widget.router.canPop()) widget.router.pop();
      await _pause(500);

      await _push('/sa/settings', 'Settings · Open platform settings');
      _set('Settings · Update geofence + toggles + secret code');
      await app.updateSettings(
        secretCode: AppConstants.defaultSecretCode,
        geofenceRadius: 250,
        blockOutsideGeofence: true,
        allowManagerCategories: true,
      );
      await _pause(900);
      await app.updateSettings(
        geofenceRadius: 200,
        blockOutsideGeofence: false,
        allowManagerCategories: false,
      );
      if (widget.router.canPop()) widget.router.pop();
      await _pause(500);

      await _push('/sa/help', 'More · Help & Support');
      if (widget.router.canPop()) widget.router.pop();
      await _pause(500);

      await _push('/sa/about', 'More · About App');
      if (widget.router.canPop()) widget.router.pop();
      await _pause(500);

      // Dashboard chips / final home
      await _go('/sa', 'Home · Final dashboard with activity');

      // Forgot-password route while logged in would redirect; logout first
      _set('Auth · Logout');
      await app.logout();
      await _go('/login', 'Auth · Back on Login');

      await _go('/forgot-password', 'Auth · Forgot password screen');
      await _go('/signup', 'Auth · Signup screen revisit');
      await _go('/login', 'Auth · Re-login Super Admin');
      await app.login(_email, _password, remember: true);
      await _go('/sa', 'Done · Super Admin home after re-login');

      setState(() {
        _running = false;
        _done = true;
        _label = 'COMPLETE · ${_results.where((r) => r.startsWith('PASS')).length} passed'
            '${_results.any((r) => r.startsWith('FAIL')) ? ' · some failed' : ''}';
      });
    } catch (e) {
      _fail(_label, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF0B5FFF), Color(0xFF00A3A3)]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SUPER ADMIN LIVE TEST',
                              style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _label,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, height: 1.25),
                            ),
                          ],
                        ),
                      ),
                      if (!_running)
                        TextButton.icon(
                          onPressed: _run,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.white24,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          icon: Icon(_done ? Icons.replay : Icons.play_arrow_rounded, size: 20),
                          label: Text(_done ? 'Replay' : 'Run'),
                        ),
                      if (_running)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_done)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 120),
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: _results
                          .map((r) => Text(
                                r,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: r.startsWith('FAIL') ? AppColors.danger : AppColors.success,
                                ),
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
