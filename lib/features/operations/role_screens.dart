import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:staffpro/core/theme/app_colors.dart';
import 'package:staffpro/core/utils/formatters.dart';
import 'package:staffpro/core/widgets/ui_kit.dart';
import 'package:staffpro/features/shells/app_shell.dart';
import 'package:staffpro/models/enums.dart';
import 'package:staffpro/models/menu_models.dart';
import 'package:staffpro/models/models.dart';
import 'package:staffpro/features/shared/map_location_picker.dart';
import 'package:staffpro/services/location_service.dart';
import 'package:staffpro/state/app_state.dart';
import 'package:uuid/uuid.dart';

class BusinessAdminDashboard extends StatelessWidget {
  const BusinessAdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final user = app.currentUser!;
    final biz = app.businessById(user.businessId);
    final today = PeriodFilter.today();
    final yesterday = PeriodFilter(from: today.from.subtract(const Duration(days: 1)), to: today.from);
    final branchId = app.effectiveBranchId;
    final sales = app.salesTotal(businessId: user.businessId, branchId: branchId, period: today);
    final expenses = app.expensesTotal(businessId: user.businessId, branchId: branchId, period: today);
    final ySales = app.salesTotal(businessId: user.businessId, branchId: branchId, period: yesterday);
    final yExp = app.expensesTotal(businessId: user.businessId, branchId: branchId, period: yesterday);
    final cash = app.cashInHand(from: today.from, to: today.to, businessId: user.businessId, branchId: branchId);
    final att = app.attendanceSummary(day: DateTime.now(), businessId: user.businessId, branchId: branchId);
    final logs = app.visibleLogs().take(6).toList();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text('${Formatters.greeting()}, ${user.firstName}!', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ),
            const BranchSelectorBar(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.25,
                children: [
                  KpiCard(label: "Today's Sales", value: Formatters.money(sales), trend: Formatters.trend(sales, ySales), trendUp: sales >= ySales, icon: Icons.trending_up, iconColor: AppColors.success),
                  KpiCard(label: "Today's Expenses", value: Formatters.money(expenses), trend: Formatters.trend(expenses, yExp), trendUp: false, icon: Icons.trending_down, iconColor: AppColors.danger),
                  KpiCard(label: 'Cash in Hand', value: Formatters.money(cash), icon: Icons.account_balance_wallet_outlined),
                  KpiCard(label: 'Present Today', value: '${att['present']} / ${att['total']}', icon: Icons.groups_outlined, iconColor: AppColors.teal),
                ],
              ).animate().fadeIn(),
            ),
            const _PosBridgeDashboardCard(),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text('Branch Performance', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppCard(
                child: Column(
                  children: app.branchesFor(user.businessId).map((b) {
                    final val = app.salesTotal(businessId: user.businessId, branchId: b.id, period: today);
                    final max = app.salesTotal(businessId: user.businessId, period: today).clamp(1, double.infinity);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [Expanded(child: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w600))), Text(Formatters.money(val))]),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(value: val / max, minHeight: 8, color: AppColors.primary, backgroundColor: AppColors.wash),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(avatar: const Icon(Icons.add, size: 16), label: const Text('Add Sale'), onPressed: () => context.push('/ba/sales/add')),
                  ActionChip(avatar: const Icon(Icons.add, size: 16), label: const Text('Add Expense'), onPressed: () => context.push('/ba/expenses/add')),
                  ActionChip(label: const Text('Sales'), onPressed: () => context.push('/ba/sales')),
                  ActionChip(label: const Text('Expenses'), onPressed: () => context.push('/ba/expenses')),
                  ActionChip(label: const Text('Attendance'), onPressed: () => context.push('/ba/attendance')),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text('Recent Activity', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            if (logs.isEmpty)
              const Padding(padding: EdgeInsets.all(20), child: EmptyView(title: 'No recent activity'))
            else
              ...logs.map((l) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: AppCard(child: Text('${l.action.name} ${l.module} · ${Formatters.relative(l.createdAt)}')),
                  )),
          ],
        ),
      ),
    );
  }
}

class BranchesScreen extends StatelessWidget {
  const BranchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final branches = app.visibleBranches();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (app.canManageBranches)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: AppButton(label: 'Add Branch', icon: Icons.add, onPressed: () => context.push('/ba/branches/add')),
              ),
            Expanded(
              child: branches.isEmpty
                  ? const EmptyView(title: 'No branches yet', subtitle: 'Create your first branch.')
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: branches.length,
                      itemBuilder: (context, i) {
                        final b = branches[i];
                        final managers = app.usersWhere(role: UserRole.manager, branchId: b.id).length;
                        final employees = app.usersWhere(role: UserRole.employee, branchId: b.id).length;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            onTap: () => context.push('/ba/branches/${b.id}'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [Expanded(child: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w800))), StatusBadge.active(b.status == EntityStatus.active)]),
                                Text(b.address.isEmpty ? b.city : b.address, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                                const SizedBox(height: 6),
                                Text('$managers managers · $employees employees', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class BranchFormScreen extends StatefulWidget {
  const BranchFormScreen({super.key, this.branchId, this.businessId});
  final String? branchId;
  final String? businessId;

  @override
  State<BranchFormScreen> createState() => _BranchFormScreenState();
}

class _BranchFormScreenState extends State<BranchFormScreen> {
  final name = TextEditingController();
  final code = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final city = TextEditingController();
  final radius = TextEditingController(text: '200');
  EntityStatus status = EntityStatus.active;
  double? lat;
  double? lng;
  bool blockOutside = false;
  bool loading = false;
  bool locating = false;
  Branch? existing;

  @override
  void initState() {
    super.initState();
    final app = context.read<StaffProController>();
    radius.text = app.settings.geofenceRadius.toStringAsFixed(0);
    blockOutside = app.settings.blockOutsideGeofence;
    if (widget.branchId != null) {
      existing = app.branchById(widget.branchId);
      if (existing != null) {
        name.text = existing!.name;
        code.text = existing!.code;
        phone.text = existing!.phone;
        address.text = existing!.address;
        city.text = existing!.city;
        status = existing!.status;
        lat = existing!.latitude;
        lng = existing!.longitude;
        radius.text = existing!.geofenceRadius.toStringAsFixed(0);
        blockOutside = existing!.blockOutsideGeofence;
      }
    }
  }

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    phone.dispose();
    address.dispose();
    city.dispose();
    radius.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => locating = true);
    final loc = await LocationService().currentPosition(precise: true);
    if (!mounted) return;
    setState(() => locating = false);
    if (loc.hasPoint) {
      setState(() {
        lat = loc.point!.latitude;
        lng = loc.point!.longitude;
      });
      showToast(context, 'Current GPS location set');
    } else {
      showToast(context, loc.error ?? 'Location unavailable', error: true);
    }
  }

  Future<void> _pickOnMap() async {
    final picked = await MapLocationPickerScreen.open(
      context,
      initialLatitude: lat,
      initialLongitude: lng,
      geofenceRadiusMeters: double.tryParse(radius.text) ?? 200,
      title: 'Pin shop location',
    );
    if (picked != null && mounted) {
      setState(() {
        lat = picked.latitude;
        lng = picked.longitude;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    return Scaffold(
      appBar: AppBar(title: Text(existing == null ? 'Add Branch' : 'Edit Branch')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppTextField(label: 'Branch Name', controller: name, hint: 'Enter branch name', prefix: Icons.storefront_outlined),
          const SizedBox(height: 14),
          AppTextField(label: 'Branch Code (optional)', controller: code, hint: 'Unique code', prefix: Icons.tag),
          const SizedBox(height: 14),
          AppTextField(label: 'Phone Number', controller: phone, hint: 'Enter phone', prefix: Icons.phone_outlined, keyboardType: TextInputType.phone),
          const SizedBox(height: 14),
          AppTextField(label: 'Address', controller: address, hint: 'Enter address', prefix: Icons.location_on_outlined),
          const SizedBox(height: 14),
          AppTextField(label: 'City', controller: city, hint: 'Enter city', prefix: Icons.map_outlined),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Shop location (precise)', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  lat == null
                      ? 'Required — pick on the map or use your current GPS.'
                      : '${lat!.toStringAsFixed(6)}, ${lng!.toStringAsFixed(6)}',
                  style: TextStyle(color: lat == null ? AppColors.danger : AppColors.muted, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                AppButton(
                  label: locating ? 'Getting GPS…' : 'Use my current location',
                  outlined: true,
                  icon: Icons.my_location,
                  onPressed: locating ? null : _useCurrentLocation,
                ),
                const SizedBox(height: 8),
                AppButton(
                  label: 'Open map to select anywhere',
                  icon: Icons.map_outlined,
                  onPressed: _pickOnMap,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Attendance range (meters)',
                  controller: radius,
                  hint: 'e.g. 200',
                  prefix: Icons.radar,
                  keyboardType: TextInputType.number,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: blockOutside,
                  onChanged: (v) => setState(() => blockOutside = v),
                  title: const Text('Block check-in outside this range'),
                  subtitle: const Text('Off = allow check-in but flag as out of range'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text('Status', style: TextStyle(fontWeight: FontWeight.w700)),
          Row(children: [
            Radio<EntityStatus>(value: EntityStatus.active, groupValue: status, onChanged: (v) => setState(() => status = v!)),
            const Text('Active'),
            Radio<EntityStatus>(value: EntityStatus.inactive, groupValue: status, onChanged: (v) => setState(() => status = v!)),
            const Text('Inactive'),
          ]),
          const SizedBox(height: 16),
          AppButton(
            label: existing == null ? 'Create Branch' : 'Save Changes',
            loading: loading,
            onPressed: () async {
              if (name.text.trim().isEmpty) {
                showToast(context, 'Branch name is required', error: true);
                return;
              }
              if (lat == null || lng == null) {
                showToast(context, 'Set shop location on the map or use current GPS', error: true);
                return;
              }
              setState(() => loading = true);
              try {
                final geoRadius = double.tryParse(radius.text) ?? app.settings.geofenceRadius;
                if (existing == null) {
                  await app.createBranch(
                    name: name.text,
                    businessId: widget.businessId ?? app.currentUser?.businessId,
                    code: code.text,
                    phone: phone.text,
                    address: address.text,
                    city: city.text,
                    latitude: lat,
                    longitude: lng,
                    geofenceRadius: geoRadius,
                    blockOutsideGeofence: blockOutside,
                    status: status,
                  );
                } else {
                  existing!
                    ..name = name.text
                    ..code = code.text
                    ..phone = phone.text
                    ..address = address.text
                    ..city = city.text
                    ..latitude = lat
                    ..longitude = lng
                    ..geofenceRadius = geoRadius
                    ..blockOutsideGeofence = blockOutside
                    ..status = status;
                  await app.updateBranch(existing!);
                }
                if (context.mounted) {
                  showToast(context, 'Branch saved');
                  context.pop();
                }
              } catch (e) {
                if (context.mounted) showToast(context, e.toString(), error: true);
              } finally {
                if (mounted) setState(() => loading = false);
              }
            },
          ),
        ],
      ),
    );
  }
}

class BranchDetailsScreen extends StatelessWidget {
  const BranchDetailsScreen({super.key, required this.branchId});
  final String branchId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final b = app.branchById(branchId);
    if (b == null) return const Scaffold(body: EmptyView(title: 'Branch not found'));
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(b.name),
          actions: [
            if (app.canManageBranches)
              IconButton(onPressed: () => context.push('/ba/branches/${b.id}/edit'), icon: const Icon(Icons.edit_outlined)),
          ],
          bottom: const TabBar(tabs: [Tab(text: 'Overview'), Tab(text: 'Managers'), Tab(text: 'Employees'), Tab(text: 'Sales')]),
        ),
        body: TabBarView(children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.address.isEmpty ? 'No address' : b.address),
                Text(b.phone.isEmpty ? 'No phone' : b.phone),
                Text('Status: ${statusLabel(b.status)}'),
                if (b.hasLocation)
                  Text('GPS: ${b.latitude!.toStringAsFixed(6)}, ${b.longitude!.toStringAsFixed(6)} · ${b.geofenceRadius.round()}m range')
                else
                  const Text('Shop GPS: not set — edit branch to pin on map', style: TextStyle(color: AppColors.danger)),
              ])),
            ],
          ),
          _list(app.usersWhere(role: UserRole.manager, branchId: b.id)),
          _list(app.usersWhere(role: UserRole.employee, branchId: b.id)),
          _listSales(app, b.id),
        ]),
      ),
    );
  }

  Widget _list(List<AppUser> people) {
    if (people.isEmpty) return const EmptyView(title: 'Nothing here yet');
    return ListView(padding: const EdgeInsets.all(20), children: people.map((p) => AppCard(child: ListTile(title: Text(p.fullName), subtitle: Text(p.email)))).toList());
  }

  Widget _listSales(StaffProController app, String id) {
    final sales = app.visibleSales(branchId: id, period: PeriodFilter.month());
    if (sales.isEmpty) return const EmptyView(title: 'No sales this month');
    return ListView(padding: const EdgeInsets.all(20), children: sales.map((s) => ListTile(title: Text(Formatters.money(s.amount)), subtitle: Text(Formatters.dateTime(s.date)))).toList());
  }
}

class ExpenseCategoriesScreen extends StatelessWidget {
  const ExpenseCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final cats = app.categoriesFor(app.currentUser?.businessId);
    return Scaffold(
      appBar: AppBar(title: const Text('Expense Categories')),
      floatingActionButton: app.canManageCategories
          ? FloatingActionButton(
              onPressed: () => _edit(context, app, null),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: cats
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    onTap: app.canManageCategories ? () => _edit(context, app, c) : null,
                    child: Row(
                      children: [
                        Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                        StatusBadge.active(c.status == EntityStatus.active),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Future<void> _edit(BuildContext context, StaffProController app, ExpenseCategory? cat) async {
    final name = TextEditingController(text: cat?.name ?? '');
    EntityStatus status = cat?.status ?? EntityStatus.active;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(cat == null ? 'Add category' : 'Edit category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              if (cat != null)
                SwitchListTile(value: status == EntityStatus.active, onChanged: (v) => setSt(() => status = v ? EntityStatus.active : EntityStatus.inactive), title: const Text('Active')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok == true) {
      await app.upsertCategory(id: cat?.id, name: name.text, status: status);
    }
  }
}

class ShiftManagementScreen extends StatelessWidget {
  const ShiftManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final shifts = app.db.shifts.where((s) => s.businessId == app.currentUser?.businessId).toList();
    final canEdit = app.canManageAdmins || app.canManageBranches;
    return Scaffold(
      appBar: AppBar(title: const Text('Shift Management')),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: () => _edit(context, app, null),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: shifts
            .map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    onTap: canEdit ? () => _edit(context, app, s) : null,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.name),
                      subtitle: Text('${s.startTime} - ${s.endTime} · grace ${s.gracePeriodMinutes}m'),
                      trailing: StatusBadge.active(s.status == EntityStatus.active),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Future<void> _edit(BuildContext context, StaffProController app, Shift? shift) async {
    final name = TextEditingController(text: shift?.name ?? 'Morning');
    final start = TextEditingController(text: shift?.startTime ?? '09:00');
    final end = TextEditingController(text: shift?.endTime ?? '18:00');
    final grace = TextEditingController(text: '${shift?.gracePeriodMinutes ?? 15}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(shift == null ? 'Add shift' : 'Edit shift'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: start, decoration: const InputDecoration(labelText: 'Start HH:mm')),
            TextField(controller: end, decoration: const InputDecoration(labelText: 'End HH:mm')),
            TextField(controller: grace, decoration: const InputDecoration(labelText: 'Grace minutes'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      final s = Shift(
        id: shift?.id ?? const Uuid().v4(),
        businessId: app.currentUser!.businessId!,
        name: name.text,
        startTime: start.text,
        endTime: end.text,
        gracePeriodMinutes: int.tryParse(grace.text) ?? 15,
      );
      await app.upsertShift(s, creating: shift == null);
    }
  }
}

class BusinessMoreScreen extends StatelessWidget {
  const BusinessMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AppCard(
              child: Column(
                children: [
                  if (app.canCreateRole(UserRole.manager))
                    MenuTile(icon: Icons.manage_accounts_outlined, label: 'Managers', onTap: () => context.push('/ba/managers')),
                  if (app.canManageAdmins)
                    MenuTile(icon: Icons.admin_panel_settings_outlined, label: 'Manage Admins', onTap: () => context.push('/ba/admins')),
                  MenuTile(icon: Icons.point_of_sale, label: 'Sales', onTap: () => context.push('/ba/sales')),
                  MenuTile(icon: Icons.shopping_bag_outlined, label: 'Customer orders', onTap: () => context.push('/ba/orders')),
                  MenuTile(icon: Icons.receipt_long_outlined, label: 'Expenses', onTap: () => context.push('/ba/expenses')),
                  MenuTile(icon: Icons.fact_check_outlined, label: 'Attendance', onTap: () => context.push('/ba/attendance')),
                  MenuTile(icon: Icons.lock_reset, label: 'Password Requests', onTap: () => context.push('/ba/password-requests')),
                  MenuTile(icon: Icons.notifications_none, label: 'Notifications', onTap: () => context.push('/ba/notifications')),
                  MenuTile(icon: Icons.apartment_outlined, label: 'Business Profile', onTap: () => context.push('/ba/business-profile')),
                  if (app.canEditMenu)
                    MenuTile(icon: Icons.restaurant_menu, label: 'Menu', onTap: () => context.push('/ba/menu')),
                  if (app.canManageCategories)
                    MenuTile(icon: Icons.category_outlined, label: 'Expense Categories', onTap: () => context.push('/ba/categories')),
                  if (app.canManageAdmins || app.canManageBranches)
                    MenuTile(icon: Icons.schedule_outlined, label: 'Shift Management', onTap: () => context.push('/ba/shifts')),
                  MenuTile(icon: Icons.history, label: 'Activity Logs', onTap: () => context.push('/ba/logs')),
                  MenuTile(icon: Icons.person_outline, label: 'Profile', onTap: () => context.push('/ba/profile')),
                  MenuTile(icon: Icons.lock_outline, label: 'Change Password', onTap: () => context.push('/ba/password')),
                  MenuTile(icon: Icons.help_outline, label: 'Help & Support', onTap: () => context.push('/ba/help')),
                  MenuTile(icon: Icons.info_outline, label: 'About App', onTap: () => context.push('/ba/about')),
                  MenuTile(
                    icon: Icons.logout,
                    label: 'Logout',
                    color: AppColors.danger,
                    onTap: () async {
                      final ok = await confirmAction(context, title: 'Logout?', message: 'Sign out?', confirmLabel: 'Logout', destructive: true);
                      if (ok && context.mounted) {
                        await app.logout();
                        if (context.mounted) context.go('/login');
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BusinessProfileScreen extends StatelessWidget {
  const BusinessProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final b = app.businessById(app.currentUser?.businessId);
    if (b == null) return const Scaffold(body: EmptyView(title: 'No business'));
    return Scaffold(
      appBar: AppBar(title: const Text('Business Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(b.email),
            Text(b.phone),
            Text(b.address),
            Text('Status: ${statusLabel(b.status)}'),
          ])),
          const SizedBox(height: 12),
          if (app.canEditMenu) _PublicPageCard(business: b, profile: app.publicBusiness),
        ],
      ),
    );
  }
}

class _PublicPageCard extends StatefulWidget {
  const _PublicPageCard({required this.business, required this.profile});
  final Business business;
  final PublicBusiness? profile;

  @override
  State<_PublicPageCard> createState() => _PublicPageCardState();
}

class _PublicPageCardState extends State<_PublicPageCard> {
  late final TextEditingController _slug;
  late final TextEditingController _name;
  late final TextEditingController _accountName;
  late final TextEditingController _accountNumber;
  late final TextEditingController _instructions;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _slug = TextEditingController(text: profile?.slug.isNotEmpty == true ? profile!.slug : _slugFromName(widget.business.name));
    _name = TextEditingController(text: profile?.name.isNotEmpty == true ? profile!.name : widget.business.name);
    _accountName = TextEditingController(text: profile?.paymentAccountName ?? '');
    _accountNumber = TextEditingController(text: profile?.paymentAccountNumber ?? '');
    _instructions = TextEditingController(text: profile?.paymentInstructions ?? '');
  }

  @override
  void dispose() {
    _slug.dispose();
    _name.dispose();
    _accountName.dispose();
    _accountNumber.dispose();
    _instructions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Customer ordering page', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Public link: /b/${_slug.text.trim().toLowerCase()}', style: const TextStyle(color: AppColors.muted)),
          TextField(controller: _slug, decoration: const InputDecoration(labelText: 'Public slug'), onChanged: (_) => setState(() {})),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Display name')),
          TextField(controller: _accountName, decoration: const InputDecoration(labelText: 'Account name')),
          TextField(controller: _accountNumber, decoration: const InputDecoration(labelText: 'EasyPaisa / JazzCash number')),
          TextField(controller: _instructions, decoration: const InputDecoration(labelText: 'Payment instructions')),
          const SizedBox(height: 12),
          AppButton(
            label: _saving ? 'Saving...' : 'Publish page',
            expand: true,
            onPressed: _saving ? null : _publish,
          ),
        ],
      ),
    );
  }

  String _slugFromName(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  }

  Future<void> _publish() async {
    setState(() => _saving = true);
    try {
      await context.read<StaffProController>().savePublicBusiness(PublicBusiness(
            slug: _slug.text,
            businessId: widget.business.id,
            name: _name.text,
            paymentAccountName: _accountName.text,
            paymentAccountNumber: _accountNumber.text,
            paymentInstructions: _instructions.text,
          ));
      if (mounted) showToast(context, 'Customer page published');
    } catch (error) {
      if (mounted) showToast(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class EmployeeDashboard extends StatelessWidget {
  const EmployeeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final user = app.currentUser!;
    final today = PeriodFilter.today();
    final month = PeriodFilter.month();
    final sales = app.salesTotal(userId: user.id, period: today);
    final expenses = app.expensesTotal(userId: user.id, period: today);
    final cash = app.cashInHand(from: today.from, to: today.to, userId: user.id, branchId: user.branchId, businessId: user.businessId);
    final monthSales = app.salesTotal(userId: user.id, period: month);
    final open = app.openAttendance(user.id);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text('${Formatters.greeting()}, ${user.firstName}!', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppCard(
                color: AppColors.wash,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(open == null ? 'Not checked in' : 'Checked In', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          Text(open == null ? "Today's shift" : Formatters.time(open.checkInAt), style: const TextStyle(color: AppColors.muted)),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: AppButton(
                        label: open == null ? 'Check In' : 'Check Out',
                        expand: true,
                        onPressed: () async {
                          try {
                            if (open == null) {
                              await app.checkIn();
                            } else {
                              await app.checkOut();
                            }
                          } catch (e) {
                            if (context.mounted) showToast(context, e.toString(), error: true);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.3,
                children: [
                  KpiCard(label: "Today's Sales", value: Formatters.money(sales), icon: Icons.trending_up, iconColor: AppColors.success),
                  KpiCard(label: "Today's Expenses", value: Formatters.money(expenses), icon: Icons.receipt_long, iconColor: AppColors.orange),
                  KpiCard(label: 'Cash in Hand', value: Formatters.money(cash), icon: Icons.account_balance_wallet_outlined),
                  KpiCard(label: 'This Month', value: Formatters.money(monthSales), icon: Icons.calendar_month, iconColor: AppColors.teal),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _qa(context, Icons.add_card, 'Add Sale', '/emp/sales/add'),
                  _qa(context, Icons.receipt_long, 'Add Expense', '/emp/expenses/add'),
                  _qa(context, Icons.account_balance_wallet_outlined, 'View Cash', '/emp/cash'),
                  _qa(context, Icons.fact_check_outlined, 'Attendance', '/emp/attendance'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qa(BuildContext context, IconData icon, String label, String route) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: AppCard(
          onTap: () => context.push(route),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class ManagerDashboard extends StatelessWidget {
  const ManagerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final user = app.currentUser!;
    final today = PeriodFilter.today();
    final sales = app.salesTotal(businessId: user.businessId, branchId: user.branchId, period: today);
    final expenses = app.expensesTotal(businessId: user.businessId, branchId: user.branchId, period: today);
    final att = app.attendanceSummary(day: DateTime.now(), businessId: user.businessId, branchId: user.branchId);
    final open = app.openAttendance(user.id);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text('${Formatters.greeting()}, ${user.firstName}!', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppCard(
                child: Row(
                  children: [
                    Expanded(child: Text(open == null ? 'You are not checked in' : 'Checked in at ${Formatters.time(open.checkInAt)}', style: const TextStyle(fontWeight: FontWeight.w700))),
                    TextButton(
                      onPressed: () async {
                        try {
                          if (open == null) {
                            await app.checkIn();
                          } else {
                            await app.checkOut();
                          }
                        } catch (e) {
                          if (context.mounted) showToast(context, e.toString(), error: true);
                        }
                      },
                      child: Text(open == null ? 'Check In' : 'Check Out'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.3,
                children: [
                  KpiCard(label: "Today's Sales", value: Formatters.money(sales), icon: Icons.trending_up, iconColor: AppColors.success),
                  KpiCard(label: "Today's Expenses", value: Formatters.money(expenses), icon: Icons.receipt_long, iconColor: AppColors.danger),
                  KpiCard(label: 'Present', value: '${att['present']} / ${att['total']}', icon: Icons.groups_outlined),
                  KpiCard(label: 'Late', value: '${att['late']}', icon: Icons.schedule, iconColor: AppColors.warning),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Wrap(
                spacing: 8,
                children: [
                  ActionChip(label: const Text('Add Sale'), onPressed: () => context.push('/mg/sales/add')),
                  ActionChip(label: const Text('Add Expense'), onPressed: () => context.push('/mg/expenses/add')),
                  ActionChip(label: const Text('Employees'), onPressed: () => context.go('/mg/employees')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ManagerMoreScreen extends StatelessWidget {
  const ManagerMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AppCard(
              child: Column(
                children: [
                  MenuTile(icon: Icons.receipt_long_outlined, label: 'Expenses', onTap: () => context.push('/mg/expenses')),
                  MenuTile(icon: Icons.fact_check_outlined, label: 'Team Attendance', onTap: () => context.push('/mg/attendance/team')),
                  MenuTile(icon: Icons.lock_reset, label: 'Password Requests', onTap: () => context.push('/mg/password-requests')),
                  MenuTile(icon: Icons.bar_chart, label: 'Reports', onTap: () => context.push('/mg/reports')),
                  MenuTile(icon: Icons.notifications_none, label: 'Notifications', onTap: () => context.push('/mg/notifications')),
                  MenuTile(icon: Icons.person_outline, label: 'Profile', onTap: () => context.push('/mg/profile')),
                  MenuTile(icon: Icons.lock_outline, label: 'Change Password', onTap: () => context.push('/mg/password')),
                  MenuTile(icon: Icons.help_outline, label: 'Help & Support', onTap: () => context.push('/mg/help')),
                  MenuTile(icon: Icons.info_outline, label: 'About App', onTap: () => context.push('/mg/about')),
                  MenuTile(
                    icon: Icons.logout,
                    label: 'Logout',
                    color: AppColors.danger,
                    onTap: () async {
                      final ok = await confirmAction(context, title: 'Logout?', message: 'Sign out?', confirmLabel: 'Logout', destructive: true);
                      if (ok && context.mounted) {
                        await app.logout();
                        if (context.mounted) context.go('/login');
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmployeeMoreScreen extends StatelessWidget {
  const EmployeeMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AppCard(
              child: Column(
                children: [
                  MenuTile(icon: Icons.person_outline, label: 'Profile', onTap: () => context.push('/emp/profile')),
                  MenuTile(icon: Icons.lock_outline, label: 'Change Password', onTap: () => context.push('/emp/password')),
                  MenuTile(
                    icon: Icons.storefront_outlined,
                    label: 'My Branch',
                    subtitle: app.branchName(app.currentUser?.branchId),
                    onTap: () {
                      final id = app.currentUser?.branchId;
                      if (id == null) {
                        showToast(context, 'No branch assigned', error: true);
                        return;
                      }
                      final b = app.branchById(id);
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(b?.name ?? 'Branch'),
                          content: Text(
                            [
                              if ((b?.address ?? '').isNotEmpty) b!.address,
                              if ((b?.city ?? '').isNotEmpty) b!.city,
                              if ((b?.phone ?? '').isNotEmpty) b!.phone,
                              if (b?.hasLocation == true)
                                'GPS: ${b!.latitude!.toStringAsFixed(5)}, ${b.longitude!.toStringAsFixed(5)} (±${b.geofenceRadius.round()}m)'
                              else
                                'Shop GPS not set yet',
                            ].where((e) => e.isNotEmpty).join('\n'),
                          ),
                          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
                        ),
                      );
                    },
                  ),
                  MenuTile(icon: Icons.account_balance_wallet_outlined, label: 'Cash in Hand', onTap: () => context.push('/emp/cash')),
                  MenuTile(icon: Icons.notifications_none, label: 'Notifications', onTap: () => context.push('/emp/notifications')),
                  MenuTile(icon: Icons.lock_reset, label: 'Password Recovery', onTap: () => context.push('/emp/recovery')),
                  MenuTile(icon: Icons.help_outline, label: 'Help & Support', onTap: () => context.push('/emp/help')),
                  MenuTile(icon: Icons.info_outline, label: 'About App', onTap: () => context.push('/emp/about')),
                  MenuTile(
                    icon: Icons.logout,
                    label: 'Logout',
                    color: AppColors.danger,
                    onTap: () async {
                      final ok = await confirmAction(context, title: 'Logout?', message: 'Sign out?', confirmLabel: 'Logout', destructive: true);
                      if (ok && context.mounted) {
                        await app.logout();
                        if (context.mounted) context.go('/login');
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Center(child: Text('StaffPro  ·  v1.0.0', style: TextStyle(color: AppColors.muted))),
          ],
        ),
      ),
    );
  }
}

class _PosBridgeDashboardCard extends StatefulWidget {
  const _PosBridgeDashboardCard();

  @override
  State<_PosBridgeDashboardCard> createState() => _PosBridgeDashboardCardState();
}

class _PosBridgeDashboardCardState extends State<_PosBridgeDashboardCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<StaffProController>().refreshPosBridgeDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final data = app.posBridgeDashboard;
    final kpis = data?['kpis'];
    final map = kpis is Map ? Map<String, dynamic>.from(kpis) : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('POS live (bridge)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                IconButton(
                  tooltip: 'Refresh POS data',
                  onPressed: () => app.refreshPosBridgeDashboard(),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (map == null)
              const Text(
                'Connect the bridge API to see today’s POS sales, shifts and stock alerts.',
                style: TextStyle(color: AppColors.muted),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _chip('POS sales', Formatters.money((map['salesToday'] as num?)?.toDouble() ?? 0)),
                  _chip('Orders', '${map['ordersToday'] ?? 0}'),
                  _chip('Active shifts', '${map['activeShifts'] ?? 0}'),
                  _chip('Low stock', '${map['lowStockCount'] ?? 0}'),
                  _chip('Out of stock', '${map['outOfStockCount'] ?? 0}'),
                  _chip('Refunds', Formatters.money((map['refundsToday'] as num?)?.toDouble() ?? 0)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.wash,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
