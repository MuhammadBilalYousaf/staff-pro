import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:staffpro/core/theme/app_colors.dart';
import 'package:staffpro/core/utils/formatters.dart';
import 'package:staffpro/core/validators/validators.dart';
import 'package:staffpro/core/widgets/ui_kit.dart';
import 'package:staffpro/features/shells/app_shell.dart';
import 'package:staffpro/models/enums.dart';
import 'package:staffpro/state/app_state.dart';

class SuperAdminDashboard extends StatelessWidget {
  const SuperAdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final businesses = app.db.businesses;
    final active = businesses.where((b) => b.status == EntityStatus.active).length;
    final inactive = businesses.length - active;
    final admins = app.db.users.where((u) => u.role == UserRole.businessAdmin).length;
    final managers = app.db.users.where((u) => u.role == UserRole.manager).length;
    final employees = app.db.users.where((u) => u.role == UserRole.employee).length;
    final logs = app.visibleLogs().take(8).toList();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text('${Formatters.greeting()}, ${app.currentUser?.firstName ?? 'Super Admin'}!', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.35,
                children: [
                  KpiCard(label: 'Total Businesses', value: '${businesses.length}', icon: Icons.apartment_outlined),
                  KpiCard(label: 'Active Businesses', value: '$active', icon: Icons.verified_outlined, iconColor: AppColors.success),
                  KpiCard(label: 'Total Admins', value: '$admins', icon: Icons.admin_panel_settings_outlined),
                  KpiCard(label: 'Total Branches', value: '${app.db.branches.length}', icon: Icons.storefront_outlined),
                  KpiCard(label: 'Total Employees', value: '$employees', icon: Icons.groups_outlined, iconColor: AppColors.teal),
                  KpiCard(label: 'Inactive', value: '$inactive', icon: Icons.domain_disabled_outlined, iconColor: AppColors.danger),
                ],
              ).animate().fadeIn(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(
                children: [
                  Expanded(child: AppButton(label: 'Add Business', icon: Icons.add, onPressed: () => context.push('/sa/business/add'))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Wrap(
                spacing: 8,
                children: [
                  ActionChip(label: const Text('Businesses'), onPressed: () => context.go('/sa/businesses')),
                  ActionChip(label: const Text('Admins'), onPressed: () => context.push('/sa/admins')),
                  ActionChip(label: const Text('Reports'), onPressed: () => context.go('/sa/reports')),
                  ActionChip(label: Text('Managers ($managers)'), onPressed: () => context.push('/sa/managers')),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text('Recent Activity', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            if (logs.isEmpty)
              const Padding(padding: EdgeInsets.all(20), child: EmptyView(title: 'No activity yet', subtitle: 'Create a business to get started.'))
            else
              ...logs.map((l) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: AppCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${l.action.name} ${l.module}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${app.userName(l.performedBy)} · ${Formatters.relative(l.createdAt)}'),
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class BusinessesScreen extends StatefulWidget {
  const BusinessesScreen({super.key});

  @override
  State<BusinessesScreen> createState() => _BusinessesScreenState();
}

class _BusinessesScreenState extends State<BusinessesScreen> {
  final _search = TextEditingController();
  String filter = 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    var list = app.db.businesses.toList();
    if (filter == 'Active') list = list.where((b) => b.status == EntityStatus.active).toList();
    if (filter == 'Inactive') list = list.where((b) => b.status != EntityStatus.active).toList();
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((b) => '${b.name} ${b.code} ${b.city} ${b.address}'.toLowerCase().contains(q)).toList();
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: SearchField(controller: _search, hint: 'Search businesses', onChanged: (_) => setState(() {})),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FilterChips(
                items: ['All (${app.db.businesses.length})', 'Active (${app.db.businesses.where((b) => b.status == EntityStatus.active).length})', 'Inactive (${app.db.businesses.where((b) => b.status != EntityStatus.active).length})'],
                value: filter == 'All' ? 'All (${app.db.businesses.length})' : filter == 'Active' ? 'Active (${app.db.businesses.where((b) => b.status == EntityStatus.active).length})' : 'Inactive (${app.db.businesses.where((b) => b.status != EntityStatus.active).length})',
                onChanged: (v) => setState(() {
                  if (v.startsWith('All')) filter = 'All';
                  if (v.startsWith('Active')) filter = 'Active';
                  if (v.startsWith('Inactive')) filter = 'Inactive';
                }),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const EmptyView(title: 'No businesses', subtitle: 'Add a business to start the platform.')
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final b = list[i];
                        final branches = app.branchesFor(b.id).length;
                        final admins = app.usersWhere(role: UserRole.businessAdmin, businessId: b.id).length;
                        final employees = app.usersWhere(role: UserRole.employee, businessId: b.id).length;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppCard(
                            onTap: () => context.push('/sa/business/${b.id}'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                                    StatusBadge.active(b.status == EntityStatus.active),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('${b.city.isEmpty ? b.address : b.city}${b.code.isEmpty ? '' : ' · ${b.code}'}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                                const SizedBox(height: 8),
                                Text('$branches branches · $admins admins · $employees employees', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/sa/business/add'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Business'),
      ),
    );
  }
}

class AddBusinessWizard extends StatefulWidget {
  const AddBusinessWizard({super.key});

  @override
  State<AddBusinessWizard> createState() => _AddBusinessWizardState();
}

class _AddBusinessWizardState extends State<AddBusinessWizard> {
  int step = 0;
  final name = TextEditingController();
  final code = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final address = TextEditingController();
  final city = TextEditingController();
  EntityStatus status = EntityStatus.active;
  final adminName = TextEditingController();
  final adminEmail = TextEditingController();
  final adminPhone = TextEditingController();
  final adminPassword = TextEditingController();
  final adminConfirm = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    phone.dispose();
    email.dispose();
    address.dispose();
    city.dispose();
    adminName.dispose();
    adminEmail.dispose();
    adminPhone.dispose();
    adminPassword.dispose();
    adminConfirm.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (adminPassword.text != adminConfirm.text) {
      showToast(context, 'Passwords do not match', error: true);
      return;
    }
    setState(() => loading = true);
    try {
      await context.read<StaffProController>().createBusiness(
            name: name.text,
            code: code.text,
            phone: phone.text,
            email: email.text,
            address: address.text,
            city: city.text,
            status: status,
            adminName: adminName.text,
            adminEmail: adminEmail.text,
            adminPhone: adminPhone.text,
            adminPassword: adminPassword.text,
          );
      if (!mounted) return;
      showToast(context, 'Business created');
      context.pop();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Business')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _step(1, 'Business Info'),
                Expanded(child: Container(height: 2, color: step >= 1 ? AppColors.primary : AppColors.border)),
                _step(2, 'Admin Details'),
                Expanded(child: Container(height: 2, color: step >= 2 ? AppColors.primary : AppColors.border)),
                _step(3, 'Review'),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: ListView(
                key: ValueKey(step),
                padding: const EdgeInsets.all(20),
                children: [
                  if (step == 0) ...[
                    AppTextField(label: 'Business Name', controller: name, hint: 'Enter business name', prefix: Icons.apartment_outlined),
                    const SizedBox(height: 14),
                    AppTextField(label: 'Business Code (optional)', controller: code, hint: 'Unique code', prefix: Icons.tag),
                    const SizedBox(height: 14),
                    AppTextField(label: 'Phone Number', controller: phone, hint: 'Enter phone', prefix: Icons.phone_outlined, keyboardType: TextInputType.phone),
                    const SizedBox(height: 14),
                    AppTextField(label: 'Email Address', controller: email, hint: 'Enter email', prefix: Icons.mail_outline),
                    const SizedBox(height: 14),
                    AppTextField(label: 'Physical Address', controller: address, hint: 'Enter address', prefix: Icons.location_on_outlined),
                    const SizedBox(height: 14),
                    AppTextField(label: 'City', controller: city, hint: 'Enter city', prefix: Icons.map_outlined),
                    const SizedBox(height: 10),
                    const Text('Business Status', style: TextStyle(fontWeight: FontWeight.w700)),
                    Row(children: [
                      Radio<EntityStatus>(value: EntityStatus.active, groupValue: status, onChanged: (v) => setState(() => status = v!)),
                      const Text('Active'),
                      Radio<EntityStatus>(value: EntityStatus.inactive, groupValue: status, onChanged: (v) => setState(() => status = v!)),
                      const Text('Inactive'),
                    ]),
                  ],
                  if (step == 1) ...[
                    AppTextField(label: 'Full Name', controller: adminName, hint: 'Owner / admin name', prefix: Icons.person_outline),
                    const SizedBox(height: 14),
                    AppTextField(label: 'Email', controller: adminEmail, hint: 'Admin email', prefix: Icons.mail_outline, validator: Validators.email),
                    const SizedBox(height: 14),
                    AppTextField(label: 'Phone', controller: adminPhone, hint: 'Admin phone', prefix: Icons.phone_outlined),
                    const SizedBox(height: 14),
                    AppTextField(label: 'Password', controller: adminPassword, hint: 'Temporary password', prefix: Icons.lock_outline, obscure: true),
                    const SizedBox(height: 14),
                    AppTextField(label: 'Confirm Password', controller: adminConfirm, hint: 'Confirm password', prefix: Icons.lock_outline, obscure: true),
                  ],
                  if (step == 2) ...[
                    const Text('Review', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    AppCard(child: Column(children: [
                      _kv('Business', name.text),
                      _kv('Code', code.text),
                      _kv('Phone', phone.text),
                      _kv('Email', email.text),
                      _kv('Address', address.text),
                      _kv('Status', statusLabel(status)),
                    ])),
                    const SizedBox(height: 12),
                    AppCard(child: Column(children: [
                      _kv('Admin', adminName.text),
                      _kv('Admin email', adminEmail.text),
                      _kv('Admin phone', adminPhone.text),
                    ])),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                if (step > 0) Expanded(child: AppButton(label: 'Back', outlined: true, icon: Icons.arrow_back, onPressed: () => setState(() => step--))),
                if (step > 0) const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: step == 2 ? 'Create Business' : 'Continue',
                    loading: loading,
                    onPressed: () {
                      if (step < 2) {
                        setState(() => step++);
                      } else {
                        _create();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(int n, String label) {
    final active = step + 1 >= n;
    return Column(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: active ? AppColors.primary : AppColors.border,
          child: Text('$n', style: TextStyle(color: active ? Colors.white : AppColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [SizedBox(width: 110, child: Text(k, style: const TextStyle(color: AppColors.muted))), Expanded(child: Text(v.isEmpty ? '—' : v, style: const TextStyle(fontWeight: FontWeight.w700)))]),
      );
}

class BusinessDetailsScreen extends StatelessWidget {
  const BusinessDetailsScreen({super.key, required this.businessId});
  final String businessId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final b = app.businessById(businessId);
    if (b == null) return const Scaffold(body: EmptyView(title: 'Business not found'));
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(b.name),
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Admins'),
            Tab(text: 'Branches'),
            Tab(text: 'Managers'),
            Tab(text: 'Employees'),
          ]),
          actions: [
            IconButton(
              onPressed: () async {
                final next = b.status == EntityStatus.active ? EntityStatus.inactive : EntityStatus.active;
                final ok = await confirmAction(context, title: '${statusLabel(next)} business?', message: 'Historical records are kept.');
                if (ok && context.mounted) await app.setBusinessStatus(b.id, next);
              },
              icon: const Icon(Icons.power_settings_new),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(20),
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.5,
                  children: [
                    KpiCard(label: 'Branches', value: '${app.branchesFor(b.id).length}'),
                    KpiCard(label: 'Admins', value: '${app.usersWhere(role: UserRole.businessAdmin, businessId: b.id).length}'),
                    KpiCard(label: 'Managers', value: '${app.usersWhere(role: UserRole.manager, businessId: b.id).length}'),
                    KpiCard(label: 'Employees', value: '${app.usersWhere(role: UserRole.employee, businessId: b.id).length}'),
                  ],
                ),
                const SizedBox(height: 12),
                AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Business Information', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Name: ${b.name}'),
                  Text('Code: ${b.code.isEmpty ? '—' : b.code}'),
                  Text('Phone: ${b.phone}'),
                  Text('Email: ${b.email}'),
                  Text('Address: ${b.address}'),
                  Text('Status: ${statusLabel(b.status)}'),
                  Text('Created: ${Formatters.date(b.createdAt)}'),
                ])),
              ],
            ),
            _people(app, UserRole.businessAdmin, b.id),
            _branches(context, app, b.id),
            _people(app, UserRole.manager, b.id),
            _people(app, UserRole.employee, b.id),
          ],
        ),
      ),
    );
  }

  Widget _people(StaffProController app, UserRole role, String bizId) {
    final people = app.usersWhere(role: role, businessId: bizId);
    if (people.isEmpty) return EmptyView(title: 'No ${roleLabel(role)}s');
    return ListView(
      padding: const EdgeInsets.all(20),
      children: people
          .map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(child: ListTile(contentPadding: EdgeInsets.zero, title: Text(p.fullName), subtitle: Text(p.email), trailing: StatusBadge.active(p.isActive))),
              ))
          .toList(),
    );
  }

  Widget _branches(BuildContext context, StaffProController app, String bizId) {
    final branches = app.branchesFor(bizId);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AppButton(label: 'Add Branch', icon: Icons.add, onPressed: () => context.push('/sa/business/$bizId/branch/add')),
        const SizedBox(height: 12),
        ...branches.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                onTap: () => context.push('/sa/business/$bizId/branch/${b.id}/edit'),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(b.name),
                  subtitle: Text(
                    [
                      if (b.address.isNotEmpty) b.address,
                      if (b.hasLocation) 'GPS set · ${b.geofenceRadius.round()}m range',
                      if (!b.hasLocation) 'No GPS pin yet',
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                ),
              ),
            )),
      ],
    );
  }
}

class BusinessAdminsScreen extends StatelessWidget {
  const BusinessAdminsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final isSuper = app.currentUser?.role == UserRole.superAdmin;
    // Only true Admins (full access / owner) — not limited emp-access accounts.
    final admins = app
        .usersWhere(
          role: UserRole.businessAdmin,
          businessId: isSuper ? null : app.currentUser?.businessId,
        )
        .where((a) => a.isOwner || a.permissions.fullAccess)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Business Admins')),
      floatingActionButton: app.canManageAdmins
          ? FloatingActionButton.extended(
              onPressed: () => context.push(isSuper ? '/sa/admins/add' : '/ba/admins/add'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              label: const Text('Add Admin / Staff'),
              icon: const Icon(Icons.add),
            )
          : null,
      body: admins.isEmpty
          ? const EmptyView(title: 'No admins yet', subtitle: 'Add Admin / Manager / Employee with the correct access level.')
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: admins.length,
              itemBuilder: (context, i) {
                final a = admins[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(a.fullName),
                      subtitle: Text('${app.businessName(a.businessId)}\n${a.email}'),
                      isThreeLine: true,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const StatusBadge(label: 'Admin', color: AppColors.primary),
                          const SizedBox(height: 4),
                          StatusBadge.active(a.isActive),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class AddAdminScreen extends StatefulWidget {
  const AddAdminScreen({super.key});

  @override
  State<AddAdminScreen> createState() => _AddAdminScreenState();
}

class _AddAdminScreenState extends State<AddAdminScreen> {
  final _form = GlobalKey<FormState>();
  String? businessId;
  String? branchId;
  UserRole accessLevel = UserRole.businessAdmin;
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  bool loading = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<StaffProController>();
    if (app.currentUser?.role == UserRole.businessAdmin) {
      businessId = app.currentUser?.businessId;
    }
    branchId = app.effectiveBranchId;
    if (!app.canCreateRole(UserRole.businessAdmin)) {
      accessLevel = app.canCreateRole(UserRole.manager) ? UserRole.manager : UserRole.employee;
    }
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final businesses = app.currentUser?.role == UserRole.superAdmin
        ? app.db.businesses
        : app.db.businesses.where((b) => b.id == app.currentUser?.businessId).toList();
    final selectedBusiness = businessId ?? (businesses.length == 1 ? businesses.first.id : null);
    final branches = app.branchesFor(selectedBusiness, activeOnly: true);
    final needsBranch = accessLevel == UserRole.manager || accessLevel == UserRole.employee;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Staff')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Access level', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text(
              'Only Admin, Manager, or Employee. Lower roles cannot create higher roles.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ...[
              if (app.canCreateRole(UserRole.businessAdmin)) UserRole.businessAdmin,
              if (app.canCreateRole(UserRole.manager)) UserRole.manager,
              if (app.canCreateRole(UserRole.employee)) UserRole.employee,
            ].map(
              (role) => RadioListTile<UserRole>(
                value: role,
                groupValue: accessLevel,
                onChanged: (v) => setState(() => accessLevel = v!),
                title: Text(role == UserRole.businessAdmin ? 'Admin' : roleLabel(role)),
                subtitle: Text(
                  role == UserRole.businessAdmin
                      ? 'Full business access'
                      : role == UserRole.manager
                          ? 'Branch manager — cannot add Admins'
                          : 'Employee — cannot add staff above them',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (app.currentUser?.role == UserRole.superAdmin)
              DropdownButtonFormField<String>(
                initialValue: selectedBusiness,
                decoration: const InputDecoration(labelText: 'Business'),
                items: businesses.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                validator: (v) => v == null ? 'Select a business' : null,
                onChanged: (v) => setState(() {
                  businessId = v;
                  branchId = null;
                }),
              ),
            if (needsBranch) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: branchId != null && branches.any((b) => b.id == branchId) ? branchId : null,
                decoration: const InputDecoration(labelText: 'Branch'),
                items: branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                validator: (v) => (v == null || v.isEmpty) ? 'Select a branch' : null,
                onChanged: (v) => setState(() => branchId = v),
              ),
            ],
            const SizedBox(height: 14),
            AppTextField(label: 'Full Name', controller: name, hint: 'Enter name', prefix: Icons.person_outline, validator: (v) => Validators.requiredField(v, field: 'Name')),
            const SizedBox(height: 14),
            AppTextField(label: 'Email', controller: email, hint: 'Enter email', prefix: Icons.mail_outline, validator: Validators.email),
            const SizedBox(height: 14),
            AppTextField(label: 'Phone', controller: phone, hint: 'Enter phone', prefix: Icons.phone_outlined, validator: Validators.phone),
            const SizedBox(height: 14),
            AppTextField(label: 'Password', controller: password, hint: 'Temporary password', prefix: Icons.lock_outline, obscure: true, validator: (v) => Validators.password(v)),
            const SizedBox(height: 16),
            AppButton(
              label: 'Create ${accessLevel == UserRole.businessAdmin ? 'Admin' : roleLabel(accessLevel)}',
              loading: loading,
              onPressed: () async {
                if (!_form.currentState!.validate()) return;
                if (selectedBusiness == null) {
                  showToast(context, 'Select a business', error: true);
                  return;
                }
                if (!app.canCreateRole(accessLevel)) {
                  showToast(context, 'You cannot create this access level', error: true);
                  return;
                }
                setState(() => loading = true);
                try {
                  await app.createStaff(
                    role: accessLevel,
                    fullName: name.text,
                    email: email.text,
                    phone: phone.text,
                    password: password.text,
                    businessId: selectedBusiness,
                    branchId: needsBranch ? branchId : null,
                    position: accessLevel == UserRole.manager ? 'Branch Manager' : null,
                  );
                  if (context.mounted) {
                    showToast(context, '${roleLabel(accessLevel)} created');
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
      ),
    );
  }
}

class SuperAdminMoreScreen extends StatelessWidget {
  const SuperAdminMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AppCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text(Formatters.initials(app.currentUser?.fullName ?? 'SA'))),
                title: Text(app.currentUser?.fullName ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Super Admin'),
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                children: [
                  MenuTile(icon: Icons.dashboard_outlined, label: 'Dashboard', onTap: () => context.go('/sa')),
                  MenuTile(icon: Icons.apartment_outlined, label: 'Businesses', onTap: () => context.go('/sa/businesses')),
                  MenuTile(icon: Icons.admin_panel_settings_outlined, label: 'Business Admins', onTap: () => context.push('/sa/admins')),
                  MenuTile(icon: Icons.manage_accounts_outlined, label: 'Managers', onTap: () => context.push('/sa/managers')),
                  MenuTile(icon: Icons.bar_chart_rounded, label: 'Reports', onTap: () => context.go('/sa/reports')),
                  MenuTile(icon: Icons.notifications_none, label: 'Notifications', onTap: () => context.go('/sa/notifications')),
                  MenuTile(icon: Icons.history, label: 'Activity Logs', onTap: () => context.push('/sa/logs')),
                  MenuTile(icon: Icons.person_outline, label: 'Profile', onTap: () => context.push('/sa/profile')),
                  MenuTile(icon: Icons.lock_outline, label: 'Change Password', onTap: () => context.push('/sa/password')),
                  MenuTile(icon: Icons.settings_outlined, label: 'Settings', onTap: () => context.push('/sa/settings')),
                  MenuTile(icon: Icons.help_outline, label: 'Help & Support', onTap: () => context.push('/sa/help')),
                  MenuTile(icon: Icons.info_outline, label: 'About App', onTap: () => context.push('/sa/about')),
                  MenuTile(
                    icon: Icons.logout,
                    label: 'Logout',
                    color: AppColors.danger,
                    onTap: () async {
                      final ok = await confirmAction(context, title: 'Logout?', message: 'Sign out of StaffPro?', confirmLabel: 'Logout', destructive: true);
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

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController code;
  late final TextEditingController radius;

  @override
  void initState() {
    super.initState();
    final s = context.read<StaffProController>().settings;
    code = TextEditingController(text: s.secretCode);
    radius = TextEditingController(text: s.geofenceRadius.toStringAsFixed(0));
  }

  @override
  void dispose() {
    code.dispose();
    radius.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Account', style: TextStyle(fontWeight: FontWeight.w800)),
          MenuTile(icon: Icons.person_outline, label: 'Profile', onTap: () => context.push('/sa/profile')),
          MenuTile(icon: Icons.lock_outline, label: 'Change Password', onTap: () => context.push('/sa/password')),
          const SizedBox(height: 12),
          const Text('Platform', style: TextStyle(fontWeight: FontWeight.w800)),
          AppTextField(label: 'Secret Registration Code', controller: code, prefix: Icons.verified_user_outlined),
          const SizedBox(height: 12),
          AppTextField(label: 'Default geofence radius (meters)', controller: radius, prefix: Icons.radar, keyboardType: TextInputType.number),
          SwitchListTile(
            value: app.settings.blockOutsideGeofence,
            onChanged: (v) => app.updateSettings(blockOutsideGeofence: v),
            title: const Text('Block attendance outside geofence'),
            subtitle: const Text('Off = flag only, still allow check-in'),
          ),
          SwitchListTile(
            value: app.settings.allowManagerCategories,
            onChanged: (v) => app.updateSettings(allowManagerCategories: v),
            title: const Text('Allow managers to manage expense categories'),
          ),
          AppButton(
            label: 'Save Settings',
            onPressed: () async {
              await app.updateSettings(secretCode: code.text, geofenceRadius: double.tryParse(radius.text) ?? 200);
              if (context.mounted) showToast(context, 'Settings saved');
            },
          ),
          const SizedBox(height: 16),
          const Text('Security', style: TextStyle(fontWeight: FontWeight.w800)),
          MenuTile(icon: Icons.history, label: 'Activity Logs', onTap: () => context.push('/sa/logs')),
        ],
      ),
    );
  }
}
