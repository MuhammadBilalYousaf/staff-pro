import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:staffpro/features/auth/auth_screens.dart';
import 'package:staffpro/features/operations/customer_orders_screen.dart';
import 'package:staffpro/features/operations/menu_screen.dart';
import 'package:staffpro/features/operations/role_screens.dart';
import 'package:staffpro/features/shared/shared_screens.dart';
import 'package:staffpro/features/shells/app_shell.dart';
import 'package:staffpro/features/super_admin/super_admin_screens.dart';
import 'package:staffpro/models/enums.dart';
import 'package:staffpro/state/app_state.dart';

GoRouter createRouter(StaffProController app) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: app,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final public = loc == '/login' || loc == '/signup' || loc == '/forgot-password' || loc == '/splash';
      if (app.bootstrapping) return loc == '/splash' ? null : '/splash';
      if (app.currentUser == null) return public ? null : '/login';
      final role = app.currentUser!.role;
      if (loc == '/login' || loc == '/signup' || loc == '/splash' || loc == '/forgot-password') {
        return _home(role);
      }
      // Keep each role inside its own route prefix.
      final prefix = _prefix(role);
      if (!loc.startsWith(prefix)) {
        return _home(role);
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(
          navigationShell: shell,
          items: const [
            NavItem('Home', Icons.home_rounded, '/sa'),
            NavItem('Business', Icons.apartment_outlined, '/sa/businesses'),
            NavItem('Reports', Icons.bar_chart_rounded, '/sa/reports'),
            NavItem('Alerts', Icons.notifications_none_rounded, '/sa/notifications'),
            NavItem('More', Icons.menu_rounded, '/sa/more'),
          ],
        ),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/sa', builder: (_, __) => const SuperAdminDashboard())]),
          StatefulShellBranch(routes: [GoRoute(path: '/sa/businesses', builder: (_, __) => const BusinessesScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/sa/reports', builder: (_, __) => const ReportsHubScreen(platform: true, showHeader: false))]),
          StatefulShellBranch(routes: [GoRoute(path: '/sa/notifications', builder: (_, __) => const NotificationsScreen(showHeader: false))]),
          StatefulShellBranch(routes: [GoRoute(path: '/sa/more', builder: (_, __) => const SuperAdminMoreScreen())]),
        ],
      ),
      GoRoute(path: '/sa/business/add', builder: (_, __) => const AddBusinessWizard()),
      GoRoute(path: '/sa/business/:id', builder: (_, s) => BusinessDetailsScreen(businessId: s.pathParameters['id']!)),
      GoRoute(path: '/sa/business/:id/branch/add', builder: (_, s) => BranchFormScreen(businessId: s.pathParameters['id'])),
      GoRoute(
        path: '/sa/business/:bizId/branch/:id/edit',
        builder: (_, s) => BranchFormScreen(
          businessId: s.pathParameters['bizId'],
          branchId: s.pathParameters['id'],
        ),
      ),
      GoRoute(path: '/sa/admins', builder: (_, __) => const BusinessAdminsScreen()),
      GoRoute(path: '/sa/admins/add', builder: (_, __) => const AddAdminScreen()),
      GoRoute(path: '/sa/managers', builder: (_, __) => const PeopleListScreen(role: UserRole.manager)),
      GoRoute(path: '/sa/managers/add', builder: (_, __) => const PersonFormScreen(role: UserRole.manager)),
      GoRoute(path: '/sa/managers/:id', builder: (_, s) => PersonFormScreen(role: UserRole.manager, userId: s.pathParameters['id'])),
      GoRoute(path: '/sa/logs', builder: (_, __) => const ActivityLogsScreen()),
      GoRoute(path: '/sa/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/sa/password', builder: (_, __) => const ChangePasswordScreen()),
      GoRoute(path: '/sa/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/sa/help', builder: (_, __) => const HelpScreen()),
      GoRoute(path: '/sa/about', builder: (_, __) => const AboutScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(
          navigationShell: shell,
          items: const [
            NavItem('Home', Icons.home_rounded, '/ba'),
            NavItem('Branches', Icons.storefront_outlined, '/ba/branches'),
            NavItem('Staff', Icons.groups_outlined, '/ba/employees'),
            NavItem('Reports', Icons.bar_chart_rounded, '/ba/reports'),
            NavItem('More', Icons.menu_rounded, '/ba/more'),
          ],
        ),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/ba', builder: (_, __) => const BusinessAdminDashboard())]),
          StatefulShellBranch(routes: [GoRoute(path: '/ba/branches', builder: (_, __) => const BranchesScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/ba/employees', builder: (_, __) => const PeopleListScreen(role: UserRole.employee, showHeader: false))]),
          StatefulShellBranch(routes: [GoRoute(path: '/ba/reports', builder: (_, __) => const ReportsHubScreen(showHeader: false))]),
          StatefulShellBranch(routes: [GoRoute(path: '/ba/more', builder: (_, __) => const BusinessMoreScreen())]),
        ],
      ),
      GoRoute(path: '/ba/branches/add', builder: (_, __) => const BranchFormScreen()),
      GoRoute(path: '/ba/branches/:id', builder: (_, s) => BranchDetailsScreen(branchId: s.pathParameters['id']!)),
      GoRoute(path: '/ba/branches/:id/edit', builder: (_, s) => BranchFormScreen(branchId: s.pathParameters['id'])),
      GoRoute(path: '/ba/employees/add', builder: (_, __) => const PersonFormScreen(role: UserRole.employee)),
      GoRoute(path: '/ba/employees/:id', builder: (_, s) => PersonFormScreen(role: UserRole.employee, userId: s.pathParameters['id'])),
      GoRoute(path: '/ba/managers', builder: (_, __) => const PeopleListScreen(role: UserRole.manager)),
      GoRoute(path: '/ba/admins', builder: (_, __) => const BusinessAdminsScreen()),
      GoRoute(path: '/ba/admins/add', builder: (_, __) => const AddAdminScreen()),
      GoRoute(path: '/ba/managers/add', builder: (_, __) => const PersonFormScreen(role: UserRole.manager)),
      GoRoute(path: '/ba/managers/:id', builder: (_, s) => PersonFormScreen(role: UserRole.manager, userId: s.pathParameters['id'])),
      GoRoute(path: '/ba/sales', builder: (_, __) => const SalesScreen()),
      GoRoute(path: '/ba/sales/add', builder: (_, __) => const AddSaleScreen()),
      GoRoute(path: '/ba/expenses', builder: (_, __) => const ExpensesScreen()),
      GoRoute(path: '/ba/expenses/add', builder: (_, __) => const AddExpenseScreen()),
      GoRoute(path: '/ba/attendance', builder: (_, __) => const AttendanceHistoryScreen(team: true)),
      GoRoute(path: '/ba/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/ba/categories', builder: (_, __) => const ExpenseCategoriesScreen()),
      GoRoute(path: '/ba/menu', builder: (_, __) => const MenuScreen()),
      GoRoute(path: '/ba/orders', builder: (_, __) => const CustomerOrdersScreen()),
      GoRoute(path: '/ba/shifts', builder: (_, __) => const ShiftManagementScreen()),
      GoRoute(path: '/ba/logs', builder: (_, __) => const ActivityLogsScreen()),
      GoRoute(path: '/ba/password-requests', builder: (_, __) => const PasswordRequestsScreen()),
      GoRoute(path: '/ba/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/ba/password', builder: (_, __) => const ChangePasswordScreen()),
      GoRoute(path: '/ba/business-profile', builder: (_, __) => const BusinessProfileScreen()),
      GoRoute(path: '/ba/help', builder: (_, __) => const HelpScreen()),
      GoRoute(path: '/ba/about', builder: (_, __) => const AboutScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(
          navigationShell: shell,
          items: const [
            NavItem('Home', Icons.home_rounded, '/mg'),
            NavItem('Staff', Icons.groups_outlined, '/mg/employees'),
            NavItem('Sales', Icons.point_of_sale_outlined, '/mg/sales'),
            NavItem('Attend', Icons.fact_check_outlined, '/mg/attendance'),
            NavItem('More', Icons.menu_rounded, '/mg/more'),
          ],
        ),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/mg', builder: (_, __) => const ManagerDashboard())]),
          StatefulShellBranch(routes: [GoRoute(path: '/mg/employees', builder: (_, __) => const PeopleListScreen(role: UserRole.employee, showHeader: false))]),
          StatefulShellBranch(routes: [GoRoute(path: '/mg/sales', builder: (_, __) => const SalesScreen(showHeader: false))]),
          StatefulShellBranch(routes: [GoRoute(path: '/mg/attendance', builder: (_, __) => const AttendanceActionScreen(showHeader: false))]),
          StatefulShellBranch(routes: [GoRoute(path: '/mg/more', builder: (_, __) => const ManagerMoreScreen())]),
        ],
      ),
      GoRoute(path: '/mg/employees/add', builder: (_, __) => const PersonFormScreen(role: UserRole.employee)),
      GoRoute(path: '/mg/employees/:id', builder: (_, s) => PersonFormScreen(role: UserRole.employee, userId: s.pathParameters['id'])),
      GoRoute(path: '/mg/sales/add', builder: (_, __) => const AddSaleScreen()),
      GoRoute(path: '/mg/expenses', builder: (_, __) => const ExpensesScreen()),
      GoRoute(path: '/mg/expenses/add', builder: (_, __) => const AddExpenseScreen()),
      GoRoute(path: '/mg/attendance/history', builder: (_, __) => const AttendanceHistoryScreen()),
      GoRoute(path: '/mg/attendance/team', builder: (_, __) => const AttendanceHistoryScreen(team: true)),
      GoRoute(path: '/mg/password-requests', builder: (_, __) => const PasswordRequestsScreen()),
      GoRoute(path: '/mg/reports', builder: (_, __) => const ReportsHubScreen()),
      GoRoute(path: '/mg/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/mg/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/mg/password', builder: (_, __) => const ChangePasswordScreen()),
      GoRoute(path: '/mg/help', builder: (_, __) => const HelpScreen()),
      GoRoute(path: '/mg/about', builder: (_, __) => const AboutScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(
          navigationShell: shell,
          items: const [
            NavItem('Home', Icons.home_rounded, '/emp'),
            NavItem('Sales', Icons.point_of_sale_outlined, '/emp/sales'),
            NavItem('Expenses', Icons.receipt_long_outlined, '/emp/expenses'),
            NavItem('Attend', Icons.fact_check_outlined, '/emp/attendance'),
            NavItem('More', Icons.menu_rounded, '/emp/more'),
          ],
        ),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/emp', builder: (_, __) => const EmployeeDashboard())]),
          StatefulShellBranch(routes: [GoRoute(path: '/emp/sales', builder: (_, __) => const SalesScreen(showHeader: false))]),
          StatefulShellBranch(routes: [GoRoute(path: '/emp/expenses', builder: (_, __) => const ExpensesScreen(showHeader: false))]),
          StatefulShellBranch(routes: [GoRoute(path: '/emp/attendance', builder: (_, __) => const AttendanceActionScreen(showHeader: false))]),
          StatefulShellBranch(routes: [GoRoute(path: '/emp/more', builder: (_, __) => const EmployeeMoreScreen())]),
        ],
      ),
      GoRoute(path: '/emp/sales/add', builder: (_, __) => const AddSaleScreen()),
      GoRoute(path: '/emp/expenses/add', builder: (_, __) => const AddExpenseScreen()),
      GoRoute(path: '/emp/attendance/history', builder: (_, __) => const AttendanceHistoryScreen()),
      GoRoute(path: '/emp/cash', builder: (_, __) => const CashScreen()),
      GoRoute(path: '/emp/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/emp/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/emp/password', builder: (_, __) => const ChangePasswordScreen()),
      GoRoute(path: '/emp/recovery', builder: (_, __) => const PasswordRequestStatusScreen()),
      GoRoute(path: '/emp/help', builder: (_, __) => const HelpScreen()),
      GoRoute(path: '/emp/about', builder: (_, __) => const AboutScreen()),
    ],
  );
}

String _home(UserRole role) => _prefix(role);

String _prefix(UserRole role) {
  switch (role) {
    case UserRole.superAdmin:
      return '/sa';
    case UserRole.businessAdmin:
      return '/ba';
    case UserRole.manager:
      return '/mg';
    case UserRole.employee:
      return '/emp';
  }
}
