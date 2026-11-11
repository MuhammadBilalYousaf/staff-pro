import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
    final today = PeriodFilter.today();
    final yesterday = PeriodFilter(from: today.from.subtract(const Duration(days: 1)), to: today.from);
    final branchId = app.effectiveBranchId;
    final sales = app.salesTotal(businessId: user.businessId, branchId: branchId, period: today);
    final expenses = app.expensesTotal(businessId: user.businessId, branchId: branchId, period: today);
    final ySales = app.salesTotal(businessId: user.businessId, branchId: branchId, period: yesterday);
    final yExp = app.expensesTotal(businessId: user.businessId, branchId: branchId, period: yesterday);
    final accounts = app.monthAccounts(businessId: user.businessId, branchId: branchId);
    final att = app.attendanceSummary(day: DateTime.now(), businessId: user.businessId, branchId: branchId);
    final present = (att['present'] as num?)?.toInt() ?? 0;
    final total = (att['total'] as num?)?.toInt() ?? 0;
    final presentRatio = total == 0 ? 0.0 : (present / total).clamp(0.0, 1.0);
    final logs = app.visibleLogs().take(6).toList();
    final businessName = app.businessName(user.businessId);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${user.firstName}! 👋',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.text),
                ),
                const SizedBox(height: 4),
                Text(
                  businessName,
                  style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
          ),
          const BranchSelectorBar(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: HeroMetricCard(
              label: 'Total Sales Today',
              value: Formatters.money(sales),
              trend: Formatters.trend(sales, ySales),
              trendUp: sales >= ySales,
              subtitle: 'vs yesterday',
            ).animate().fadeIn(),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: KpiCard(
                    label: "Today's Expenses",
                    value: Formatters.money(expenses),
                    trend: Formatters.trend(expenses, yExp),
                    trendUp: expenses <= yExp,
                    icon: Icons.trending_down_rounded,
                    iconColor: AppColors.danger,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Present Today', style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$present / $total',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.text),
                              ),
                            ),
                            SizedBox(
                              width: 42,
                              height: 42,
                              child: CircularProgressIndicator(
                                value: presentRatio == 0 && total == 0 ? 0 : presentRatio,
                                strokeWidth: 5,
                                backgroundColor: AppColors.glassStrong,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: AppCard(
              onTap: () => context.push('/ba/cash'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Accounts this month', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(
                    Formatters.money(accounts.totalBalance),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 26, color: AppColors.text),
                  ),
                  const SizedBox(height: 14),
                  _accountRow('Cash', Formatters.money(accounts.cashInHand)),
                  const Divider(height: 18, color: AppColors.border),
                  _accountRow('Card', Formatters.money(accounts.cardBalance)),
                  const Divider(height: 18, color: AppColors.border),
                  _accountRow('Online', Formatters.money(accounts.onlineBalance)),
                ],
              ),
            ),
          ),
          const _PosBridgeDashboardCard(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text)),
                ),
                TextButton(
                  onPressed: () => context.go('/ba/more'),
                  child: const Text('View All →', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                _quickAction(context, Icons.add_rounded, 'Sale', () => context.push('/ba/sales/add')),
                _quickAction(context, Icons.receipt_long_rounded, 'Expense', () => context.push('/ba/expenses/add')),
                _quickAction(context, Icons.calendar_month_outlined, 'Attend', () => context.push('/ba/attendance')),
                _quickAction(context, Icons.shopping_cart_outlined, 'Orders', () => context.push('/ba/orders')),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text('Branch Performance', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text)),
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
                        Row(
                          children: [
                            Expanded(child: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text))),
                            Text(Formatters.money(val), style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: val / max,
                            minHeight: 8,
                            color: AppColors.primary,
                            backgroundColor: AppColors.glassStrong,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('Recent Activity', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text)),
          ),
          if (logs.isEmpty)
            const Padding(padding: EdgeInsets.all(20), child: EmptyView(title: 'No recent activity'))
          else
            ...logs.map((l) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: AppCard(
                    child: Text(
                      '${l.action.name} ${l.module} · ${Formatters.relative(l.createdAt)}',
                      style: const TextStyle(color: AppColors.text),
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _accountRow(String label, String value) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.text)),
      ],
    );
  }

  Widget _quickAction(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: AppCard(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              SoftIconBox(icon: icon, color: AppColors.primary, size: 40),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.text)),
            ],
          ),
        ),
      ),
    );
  }
}

class BranchesScreen extends StatefulWidget {
  const BranchesScreen({super.key});

  @override
  State<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends State<BranchesScreen> {
  final _search = TextEditingController();
  String _filter = 'All'; // All | Active | Inactive

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final all = app.visibleBranches();
    final activeCount = all.where((b) => b.status == EntityStatus.active).length;
    final inactiveCount = all.length - activeCount;
    final totalStaff = all.fold<int>(0, (sum, b) {
      return sum +
          app.usersWhere(role: UserRole.manager, branchId: b.id).length +
          app.usersWhere(role: UserRole.employee, branchId: b.id).length;
    });

    final q = _search.text.trim().toLowerCase();
    var list = all.toList();
    if (_filter == 'Active') list = list.where((b) => b.status == EntityStatus.active).toList();
    if (_filter == 'Inactive') list = list.where((b) => b.status != EntityStatus.active).toList();
    if (q.isNotEmpty) {
      list = list
          .where((b) => '${b.name} ${b.address} ${b.city} ${b.code}'.toLowerCase().contains(q))
          .toList();
    }

    final accentIcons = [AppColors.blue, AppColors.warning, AppColors.muted, AppColors.purple, AppColors.teal];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
        children: [
          const Text('Branches', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text)),
          const SizedBox(height: 4),
          const Text('Manage your business branches', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w500, fontSize: 14)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SearchField(
                  controller: _search,
                  hint: 'Search branches...',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              _GlassIconButton(
                icon: Icons.tune_rounded,
                active: _filter != 'All',
                onTap: () => _openFilterSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Row(
              children: [
                _BranchStat(icon: Icons.apartment_outlined, color: AppColors.purple, label: 'Total', value: '${all.length}'),
                _statDivider(),
                _BranchStat(icon: Icons.check_circle_outline, color: AppColors.success, label: 'Active', value: '$activeCount'),
                _statDivider(),
                _BranchStat(icon: Icons.link_off_rounded, color: AppColors.primary, label: 'Inactive', value: '$inactiveCount'),
                _statDivider(),
                _BranchStat(icon: Icons.groups_outlined, color: AppColors.blue, label: 'Total Staff', value: '$totalStaff'),
              ],
            ),
          ),
          if (app.canManageBranches) ...[
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: AppColors.orangeGlow,
              ),
              child: AppButton(
                label: 'Add Branch',
                icon: Icons.add_rounded,
                onPressed: () => context.push('/ba/branches/add'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: EmptyView(title: 'No branches yet', subtitle: 'Create your first branch.'),
            )
          else
            ...List.generate(list.length, (i) {
              final b = list[i];
              final managers = app.usersWhere(role: UserRole.manager, branchId: b.id).length;
              final employees = app.usersWhere(role: UserRole.employee, branchId: b.id).length;
              final staffTotal = managers + employees;
              final isActive = b.status == EntityStatus.active;
              final location = [b.address, b.city].where((e) => e.trim().isNotEmpty).join(', ');
              final iconColor = isActive ? accentIcons[i % accentIcons.length] : AppColors.muted;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  onTap: () => context.push('/ba/branches/${b.id}'),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SoftIconBox(icon: Icons.storefront_rounded, color: iconColor, size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    b.name,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text),
                                  ),
                                ),
                                StatusBadge.active(isActive),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.muted),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    location.isEmpty ? 'No address set' : location,
                                    style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.groups_outlined, size: 14, color: AppColors.muted),
                                const SizedBox(width: 4),
                                Text(
                                  '$staffTotal Staff',
                                  style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('|', style: TextStyle(color: AppColors.borderGlow)),
                                ),
                                const Icon(Icons.manage_accounts_outlined, size: 14, color: AppColors.muted),
                                const SizedBox(width: 4),
                                Text(
                                  '$managers Managers',
                                  style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                const Spacer(),
                                const Icon(Icons.chevron_right_rounded, color: AppColors.placeholder),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(width: 1, height: 42, color: AppColors.border);
  }

  Future<void> _openFilterSheet(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.navySoft,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Filter branches', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.text)),
                const SizedBox(height: 12),
                for (final option in ['All', 'Active', 'Inactive'])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(option, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
                    trailing: _filter == option ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                    onTap: () => Navigator.pop(ctx, option),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null && mounted) setState(() => _filter = selected);
  }
}

class _BranchStat extends StatelessWidget {
  const _BranchStat({required this.icon, required this.color, required this.label, required this.value});
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.text)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap, this.active = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: active ? AppColors.primarySoft : AppColors.glassStrong,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? AppColors.primary.withValues(alpha: 0.5) : AppColors.borderGlow),
          ),
          child: Icon(icon, color: active ? AppColors.primary : AppColors.text),
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
    final teamItems = <_MoreLink>[
      if (app.canCreateRole(UserRole.manager))
        _MoreLink(
          icon: Icons.manage_accounts_outlined,
          color: AppColors.blue,
          title: 'Managers',
          subtitle: 'Add, edit and manage managers',
          onTap: () => context.push('/ba/managers'),
        ),
      if (app.canManageAdmins)
        _MoreLink(
          icon: Icons.admin_panel_settings_outlined,
          color: AppColors.purple,
          title: 'Manage Admins',
          subtitle: 'Business admin users and permissions',
          onTap: () => context.push('/ba/admins'),
        ),
    ];

    final setupItems = <_MoreLink>[
      _MoreLink(
        icon: Icons.lock_reset_rounded,
        color: AppColors.warning,
        title: 'Password Requests',
        subtitle: 'Review and approve password resets',
        onTap: () => context.push('/ba/password-requests'),
      ),
      _MoreLink(
        icon: Icons.notifications_none_rounded,
        color: AppColors.info,
        title: 'Notifications',
        subtitle: 'System and business alerts',
        onTap: () => context.push('/ba/notifications'),
      ),
      _MoreLink(
        icon: Icons.apartment_outlined,
        color: AppColors.primary,
        title: 'Business Profile',
        subtitle: 'Business details, ordering page and payment QR',
        onTap: () => context.push('/ba/business-profile'),
      ),
      if (app.canEditMenu)
        _MoreLink(
          icon: Icons.restaurant_menu_rounded,
          color: AppColors.orange,
          title: 'Menu',
          subtitle: 'Manage menu items and categories',
          onTap: () => context.push('/ba/menu'),
        ),
      if (app.canManageCategories)
        _MoreLink(
          icon: Icons.category_outlined,
          color: AppColors.teal,
          title: 'Expense Categories',
          subtitle: 'Create and manage expense categories',
          onTap: () => context.push('/ba/categories'),
        ),
      if (app.canManageAdmins || app.canManageBranches)
        _MoreLink(
          icon: Icons.schedule_outlined,
          color: AppColors.blue,
          title: 'Shift Management',
          subtitle: 'Shift times and grace periods',
          onTap: () => context.push('/ba/shifts'),
        ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
        children: [
          const Text('More', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text)),
          const SizedBox(height: 4),
          const Text(
            'Manage your business, team and settings',
            style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w500, fontSize: 14),
          ),
          const SizedBox(height: 18),
          if (teamItems.isNotEmpty) ...[
            _MoreSection(
              icon: Icons.groups_outlined,
              title: 'Team & Users',
              items: teamItems,
            ),
            const SizedBox(height: 14),
          ],
          _MoreSection(
            icon: Icons.layers_outlined,
            title: 'Operations',
            items: [
              _MoreLink(
                icon: Icons.point_of_sale_rounded,
                color: AppColors.primary,
                title: 'Sales',
                subtitle: 'Record and manage sales',
                onTap: () => context.push('/ba/sales'),
              ),
              _MoreLink(
                icon: Icons.people_alt_outlined,
                color: AppColors.success,
                title: 'Customers',
                subtitle: 'Customer profiles and loyalty',
                onTap: () => context.push('/ba/customers'),
              ),
              _MoreLink(
                icon: Icons.shopping_bag_outlined,
                color: AppColors.warning,
                title: 'Customer Orders',
                subtitle: 'View and manage customer orders',
                onTap: () => context.push('/ba/orders'),
              ),
              _MoreLink(
                icon: Icons.reviews_outlined,
                color: AppColors.primary,
                title: 'Customer Feedback',
                subtitle: 'Ratings from completed orders',
                onTap: () => context.push('/ba/feedback'),
              ),
              _MoreLink(
                icon: Icons.receipt_long_outlined,
                color: AppColors.danger,
                title: 'Expenses',
                subtitle: 'Track and manage business expenses',
                onTap: () => context.push('/ba/expenses'),
              ),
              _MoreLink(
                icon: Icons.account_balance_wallet_outlined,
                color: AppColors.teal,
                title: 'Accounts & Cash',
                subtitle: 'Cash, card and online accounts',
                onTap: () => context.push('/ba/cash'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _MoreSection(
            icon: Icons.bar_chart_rounded,
            title: 'Reports & Insights',
            items: [
              _MoreLink(
                icon: Icons.table_chart_outlined,
                color: AppColors.blue,
                title: 'Daily P&L Report',
                subtitle: 'Day-wise sales, expenses and profit',
                onTap: () => context.push('/ba/reports/daily'),
              ),
              _MoreLink(
                icon: Icons.fact_check_outlined,
                color: AppColors.purple,
                title: 'Attendance',
                subtitle: 'Staff attendance, shifts and hours',
                onTap: () => context.push('/ba/attendance'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _MoreSection(
            icon: Icons.settings_outlined,
            title: 'Business Setup',
            items: setupItems,
          ),
          const SizedBox(height: 14),
          _MoreSection(
            icon: Icons.manage_accounts_outlined,
            title: 'Account',
            items: [
              _MoreLink(
                icon: Icons.history_rounded,
                color: AppColors.muted,
                title: 'Activity Logs',
                subtitle: 'Audit trail of business actions',
                onTap: () => context.push('/ba/logs'),
              ),
              _MoreLink(
                icon: Icons.person_outline_rounded,
                color: AppColors.primary,
                title: 'Profile',
                subtitle: 'Your name, phone and account details',
                onTap: () => context.push('/ba/profile'),
              ),
              _MoreLink(
                icon: Icons.lock_outline_rounded,
                color: AppColors.blue,
                title: 'Change Password',
                subtitle: 'Update your login password',
                onTap: () => context.push('/ba/password'),
              ),
              _MoreLink(
                icon: Icons.help_outline_rounded,
                color: AppColors.info,
                title: 'Help & Support',
                subtitle: 'Guides and support contacts',
                onTap: () => context.push('/ba/help'),
              ),
              _MoreLink(
                icon: Icons.info_outline_rounded,
                color: AppColors.muted,
                title: 'About App',
                subtitle: 'Version and app information',
                onTap: () => context.push('/ba/about'),
              ),
              _MoreLink(
                icon: Icons.logout_rounded,
                color: AppColors.danger,
                title: 'Logout',
                subtitle: 'Sign out of StaffPro',
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
        ],
      ),
    );
  }
}

class _MoreLink {
  const _MoreLink({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _MoreSection extends StatelessWidget {
  const _MoreSection({required this.icon, required this.title, required this.items});

  final IconData icon;
  final String title;
  final List<_MoreLink> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SoftIconBox(icon: icon, color: AppColors.primary, size: 34),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text)),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.only(left: 56),
                child: Divider(height: 1, color: AppColors.border),
              ),
            _MoreRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({required this.item});
  final _MoreLink item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            SoftIconBox(icon: item.icon, color: item.color, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text)),
                  const SizedBox(height: 3),
                  Text(item.subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.placeholder),
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
  String _paymentQr = '';
  String _logo = '';
  bool _cashOnDelivery = false;
  bool _saving = false;
  bool _uploadingQr = false;
  bool _uploadingLogo = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _slug = TextEditingController(text: profile?.slug.isNotEmpty == true ? profile!.slug : _slugFromName(widget.business.name));
    _name = TextEditingController(text: profile?.name.isNotEmpty == true ? profile!.name : widget.business.name);
    _accountName = TextEditingController(text: profile?.paymentAccountName ?? '');
    _accountNumber = TextEditingController(text: profile?.paymentAccountNumber ?? '');
    _instructions = TextEditingController(text: profile?.paymentInstructions ?? '');
    _paymentQr = profile?.paymentQrUrl ?? '';
    _logo = profile?.logoUrl ?? '';
    _cashOnDelivery = profile?.cashOnDelivery == true;
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
          const SizedBox(height: 12),
          const Text('Logo (optional)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Shown on the customer home, menu, and header. A square image looks best.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 72,
                  width: 72,
                  child: ColoredBox(
                    color: const Color(0xFFF3F1EC),
                    child: _logo.isEmpty
                        ? const Icon(Icons.storefront_outlined, color: AppColors.muted)
                        : _paymentQrImage(_logo),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploadingLogo || _saving ? null : _uploadLogo,
                  icon: _uploadingLogo
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.image_outlined),
                  label: Text(_logo.isEmpty ? 'Upload logo' : 'Replace logo'),
                ),
              ),
              if (_logo.isNotEmpty)
                IconButton(
                  tooltip: 'Remove logo',
                  onPressed: _saving ? null : () async {
                    setState(() => _logo = '');
                    await _publish(logo: '');
                  },
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                ),
            ],
          ),
          TextField(controller: _accountName, decoration: const InputDecoration(labelText: 'Account name')),
          TextField(controller: _accountNumber, decoration: const InputDecoration(labelText: 'EasyPaisa / JazzCash number')),
          TextField(controller: _instructions, decoration: const InputDecoration(labelText: 'Payment instructions')),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Cash on Delivery (COD)'),
            subtitle: const Text('When on, customers can choose cash on delivery or prepaid.'),
            value: _cashOnDelivery,
            onChanged: _saving ? null : (value) async {
              setState(() => _cashOnDelivery = value);
              await _publish(cashOnDelivery: value);
            },
          ),
          const SizedBox(height: 12),
          const Text('Payment QR (optional)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Customers can scan this on the home and checkout pages.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          if (_paymentQr.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: ColoredBox(
                  color: const Color(0xFFF3F1EC),
                  child: _paymentQrImage(_paymentQr),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploadingQr || _saving ? null : _uploadQr,
                  icon: _uploadingQr
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.qr_code_2_rounded),
                  label: Text(_paymentQr.isEmpty ? 'Upload QR' : 'Replace QR'),
                ),
              ),
              if (_paymentQr.isNotEmpty) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Remove QR',
                  onPressed: _saving ? null : () => setState(() => _paymentQr = ''),
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          AppButton(
            label: _saving ? 'Saving...' : 'Publish page',
            expand: true,
            onPressed: _saving ? null : () => _publish(),
          ),
        ],
      ),
    );
  }

  String _slugFromName(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  }

  Future<void> _uploadLogo() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 512);
    if (file == null || !mounted) return;
    setState(() => _uploadingLogo = true);
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > 250000) {
        if (mounted) showToast(context, 'That logo is too large. Use a simpler image.', error: true);
        return;
      }
      final lower = file.path.toLowerCase();
      final mime = lower.endsWith('.png') ? 'image/png' : 'image/jpeg';
      if (!mounted) return;
      final logo = 'data:$mime;base64,${base64Encode(bytes)}';
      setState(() => _logo = logo);
      await _publish(logo: logo);
    } catch (error) {
      if (mounted) showToast(context, 'Could not read that logo.', error: true);
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _uploadQr() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 92, maxWidth: 720);
    if (file == null || !mounted) return;
    setState(() => _uploadingQr = true);
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > 250000) {
        if (mounted) showToast(context, 'That QR image is too large. Try a clearer crop.', error: true);
        return;
      }
      final lower = file.path.toLowerCase();
      final mime = lower.endsWith('.png') ? 'image/png' : 'image/jpeg';
      if (!mounted) return;
      setState(() => _paymentQr = 'data:$mime;base64,${base64Encode(bytes)}');
    } catch (error) {
      if (mounted) showToast(context, 'Could not read that QR image.', error: true);
    } finally {
      if (mounted) setState(() => _uploadingQr = false);
    }
  }

  Future<void> _publish({bool? cashOnDelivery, String? logo}) async {
    setState(() => _saving = true);
    try {
      await context.read<StaffProController>().savePublicBusiness(PublicBusiness(
            slug: _slug.text,
            businessId: widget.business.id,
            name: _name.text,
            paymentAccountName: _accountName.text,
            paymentAccountNumber: _accountNumber.text,
            paymentInstructions: _instructions.text,
            paymentQrUrl: _paymentQr,
            logoUrl: logo ?? _logo,
            cashOnDelivery: cashOnDelivery ?? _cashOnDelivery,
          ));
      if (mounted) showToast(context, 'Customer page published');
    } catch (error) {
      if (mounted) showToast(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

Widget _paymentQrImage(String url) {
  const fallback = ColoredBox(
    color: Color(0xFFE8E4DE),
    child: Center(child: Icon(Icons.qr_code_2_rounded)),
  );
  if (url.startsWith('data:image')) {
    final comma = url.indexOf(',');
    if (comma < 0) return fallback;
    try {
      return Image.memory(
        base64Decode(url.substring(comma + 1)),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => fallback,
      );
    } catch (_) {
      return fallback;
    }
  }
  if (url.startsWith('http')) {
    return Image.network(url, fit: BoxFit.contain, errorBuilder: (_, _, _) => fallback);
  }
  return fallback;
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
    final accounts = app.monthAccounts(userId: user.id, branchId: user.branchId, businessId: user.businessId);
    final monthSales = app.salesTotal(userId: user.id, period: month);
    final open = app.openAttendance(user.id);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text('Hello, ${user.firstName}! 👋', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.text)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppCard(
                padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 148,
                      height: 148,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            (open == null ? AppColors.primary : AppColors.success).withValues(alpha: 0.22),
                            Colors.transparent,
                          ],
                        ),
                        border: Border.all(color: open == null ? AppColors.primary : AppColors.success, width: 8),
                        boxShadow: [
                          BoxShadow(
                            color: (open == null ? AppColors.primary : AppColors.success).withValues(alpha: 0.35),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(open == null ? Icons.login_rounded : Icons.check_circle_rounded, size: 32, color: open == null ? AppColors.primary : AppColors.success),
                          const SizedBox(height: 6),
                          Text(open == null ? 'Check In' : 'Checked In', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text)),
                          if (open != null) Text(Formatters.time(open.checkInAt), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppButton(
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
                  KpiCard(label: 'Should have (MTD)', value: Formatters.money(accounts.totalBalance), icon: Icons.account_balance_wallet_outlined),
                  KpiCard(label: 'This Month Sales', value: Formatters.money(monthSales), icon: Icons.calendar_month, iconColor: AppColors.teal),
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
                  _qa(context, Icons.add_card, 'My Sales', '/emp/sales/add'),
                  _qa(context, Icons.receipt_long, 'My Expenses', '/emp/expenses/add'),
                  _qa(context, Icons.shopping_bag_outlined, 'My Orders', '/emp/orders'),
                  _qa(context, Icons.account_balance_wallet_outlined, 'View Cash', '/emp/cash'),
                ],
              ),
            ),
          ],
      ),
    );
  }

  Widget _qa(BuildContext context, IconData icon, String label, String route) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: AppCard(
          onTap: () => context.push(route),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(
            children: [
              SoftIconBox(icon: icon, color: AppColors.green, size: 40),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
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
      backgroundColor: Colors.transparent,
      body: ListView(
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text('Hello, ${user.firstName}! 👋', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.text)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: HeroMetricCard(
                label: 'Total Sales Today',
                value: Formatters.money(sales),
                subtitle: open == null ? 'You are not checked in' : 'Checked in at ${Formatters.time(open.checkInAt)}',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: AppCard(
                child: Row(
                  children: [
                    SoftIconBox(
                      icon: open == null ? Icons.login_rounded : Icons.check_circle_rounded,
                      color: open == null ? AppColors.blue : AppColors.success,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        open == null ? 'Ready to start your shift?' : 'On shift now',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
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
                      child: Text(
                        open == null ? 'Check In' : 'Check Out',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800),
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
                  KpiCard(label: "Today's Expenses", value: Formatters.money(expenses), icon: Icons.receipt_long, iconColor: AppColors.danger),
                  KpiCard(label: 'Present', value: '${att['present']} / ${att['total']}', icon: Icons.groups_outlined, iconColor: AppColors.teal),
                  KpiCard(label: 'Late', value: '${att['late']}', icon: Icons.schedule, iconColor: AppColors.warning),
                  KpiCard(label: 'Team', value: '${att['total']}', icon: Icons.badge_outlined, iconColor: AppColors.blue),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
              child: Row(
                children: [
                  _mgQuick(context, Icons.add_card_rounded, 'Sale', () => context.push('/mg/sales/add')),
                  _mgQuick(context, Icons.receipt_long_rounded, 'Expense', () => context.push('/mg/expenses/add')),
                  _mgQuick(context, Icons.groups_outlined, 'Staff', () => context.go('/mg/employees')),
                  _mgQuick(context, Icons.shopping_bag_outlined, 'Orders', () => context.push('/mg/orders')),
                ],
              ),
            ),
          ],
      ),
    );
  }

  Widget _mgQuick(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: AppCard(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(
            children: [
              SoftIconBox(icon: icon, color: AppColors.blue, size: 40),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            ],
          ),
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
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
        children: [
          const Text('More', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text)),
          const SizedBox(height: 4),
          const Text('Manage branch operations and settings', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w500, fontSize: 14)),
          const SizedBox(height: 18),
          _MoreSection(
            icon: Icons.layers_outlined,
            title: 'Operations',
            items: [
              _MoreLink(icon: Icons.shopping_bag_outlined, color: AppColors.warning, title: 'Customer Orders', subtitle: 'View and manage customer orders', onTap: () => context.push('/mg/orders')),
              _MoreLink(icon: Icons.reviews_outlined, color: AppColors.primary, title: 'Customer Feedback', subtitle: 'Ratings from completed orders', onTap: () => context.push('/mg/feedback')),
              _MoreLink(icon: Icons.people_alt_outlined, color: AppColors.success, title: 'Customers', subtitle: 'Customer profiles and loyalty', onTap: () => context.push('/mg/customers')),
              _MoreLink(icon: Icons.receipt_long_outlined, color: AppColors.danger, title: 'Expenses', subtitle: 'Track and manage expenses', onTap: () => context.push('/mg/expenses')),
              _MoreLink(icon: Icons.fact_check_outlined, color: AppColors.purple, title: 'Team Attendance', subtitle: 'Staff attendance for your branch', onTap: () => context.push('/mg/attendance/team')),
            ],
          ),
          const SizedBox(height: 14),
          _MoreSection(
            icon: Icons.bar_chart_rounded,
            title: 'Reports & Insights',
            items: [
              _MoreLink(icon: Icons.bar_chart_rounded, color: AppColors.blue, title: 'Reports', subtitle: 'Sales, expenses and attendance reports', onTap: () => context.push('/mg/reports')),
              _MoreLink(icon: Icons.lock_reset_rounded, color: AppColors.warning, title: 'Password Requests', subtitle: 'Review and approve password resets', onTap: () => context.push('/mg/password-requests')),
              _MoreLink(icon: Icons.notifications_none_rounded, color: AppColors.info, title: 'Notifications', subtitle: 'System and branch alerts', onTap: () => context.push('/mg/notifications')),
            ],
          ),
          const SizedBox(height: 14),
          _MoreSection(
            icon: Icons.manage_accounts_outlined,
            title: 'Account',
            items: [
              _MoreLink(icon: Icons.person_outline_rounded, color: AppColors.primary, title: 'Profile', subtitle: 'Your name, phone and account details', onTap: () => context.push('/mg/profile')),
              _MoreLink(icon: Icons.lock_outline_rounded, color: AppColors.blue, title: 'Change Password', subtitle: 'Update your login password', onTap: () => context.push('/mg/password')),
              _MoreLink(icon: Icons.help_outline_rounded, color: AppColors.info, title: 'Help & Support', subtitle: 'Guides and support contacts', onTap: () => context.push('/mg/help')),
              _MoreLink(icon: Icons.info_outline_rounded, color: AppColors.muted, title: 'About App', subtitle: 'Version and app information', onTap: () => context.push('/mg/about')),
              _MoreLink(
                icon: Icons.logout_rounded,
                color: AppColors.danger,
                title: 'Logout',
                subtitle: 'Sign out of StaffPro',
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
        ],
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
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
        children: [
          const Text('More', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text)),
          const SizedBox(height: 4),
          const Text('Your tools, branch and account', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w500, fontSize: 14)),
          const SizedBox(height: 18),
          _MoreSection(
            icon: Icons.layers_outlined,
            title: 'Operations',
            items: [
              _MoreLink(icon: Icons.shopping_bag_outlined, color: AppColors.warning, title: 'Customer Orders', subtitle: 'View and update order status', onTap: () => context.push('/emp/orders')),
              _MoreLink(icon: Icons.reviews_outlined, color: AppColors.primary, title: 'Customer Feedback', subtitle: 'Ratings from completed orders', onTap: () => context.push('/emp/feedback')),
              _MoreLink(
                icon: Icons.storefront_outlined,
                color: AppColors.blue,
                title: 'My Branch',
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
              _MoreLink(icon: Icons.account_balance_wallet_outlined, color: AppColors.teal, title: 'Accounts & Cash', subtitle: 'Your month-to-date cash position', onTap: () => context.push('/emp/cash')),
            ],
          ),
          const SizedBox(height: 14),
          _MoreSection(
            icon: Icons.manage_accounts_outlined,
            title: 'Account',
            items: [
              _MoreLink(icon: Icons.person_outline_rounded, color: AppColors.primary, title: 'Profile', subtitle: 'Your name, phone and account details', onTap: () => context.push('/emp/profile')),
              _MoreLink(icon: Icons.lock_outline_rounded, color: AppColors.blue, title: 'Change Password', subtitle: 'Update your login password', onTap: () => context.push('/emp/password')),
              _MoreLink(icon: Icons.notifications_none_rounded, color: AppColors.info, title: 'Notifications', subtitle: 'Alerts and updates', onTap: () => context.push('/emp/notifications')),
              _MoreLink(icon: Icons.lock_reset_rounded, color: AppColors.warning, title: 'Password Recovery', subtitle: 'Request a password reset', onTap: () => context.push('/emp/recovery')),
              _MoreLink(icon: Icons.help_outline_rounded, color: AppColors.info, title: 'Help & Support', subtitle: 'Guides and support contacts', onTap: () => context.push('/emp/help')),
              _MoreLink(icon: Icons.info_outline_rounded, color: AppColors.muted, title: 'About App', subtitle: 'Version and app information', onTap: () => context.push('/emp/about')),
              _MoreLink(
                icon: Icons.logout_rounded,
                color: AppColors.danger,
                title: 'Logout',
                subtitle: 'Sign out of StaffPro',
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
          const SizedBox(height: 20),
          const Center(child: Text('StaffPro  ·  v1.0.0', style: TextStyle(color: AppColors.muted))),
        ],
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
        child: Row(
          children: [
            SoftIconBox(icon: Icons.point_of_sale_rounded, color: AppColors.primary, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('POS Live (Bridge)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text)),
                  const SizedBox(height: 2),
                  Text(
                    map == null
                        ? 'Connect the bridge API for live POS figures'
                        : 'Sales ${Formatters.money((map['salesToday'] as num?)?.toDouble() ?? 0)} · Orders ${map['ordersToday'] ?? 0}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => app.refreshPosBridgeDashboard(),
              child: Text(map == null ? 'Connect' : 'Refresh', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}
