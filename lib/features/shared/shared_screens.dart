import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:staffpro/core/constants/app_constants.dart';
import 'package:staffpro/core/theme/app_colors.dart';
import 'package:staffpro/core/utils/formatters.dart';
import 'package:staffpro/core/validators/validators.dart';
import 'package:staffpro/core/widgets/ui_kit.dart';
import 'package:staffpro/features/shells/app_shell.dart';
import 'package:staffpro/models/enums.dart';
import 'package:staffpro/models/models.dart';
import 'package:staffpro/state/app_state.dart';
import 'package:uuid/uuid.dart';

PeriodFilter periodFrom(String label) {
  switch (label) {
    case 'This Week':
      return PeriodFilter.week();
    case 'This Month':
      return PeriodFilter.month();
    default:
      return PeriodFilter.today();
  }
}

Color attendanceColor(AttendanceStatus status) {
  switch (status) {
    case AttendanceStatus.present:
    case AttendanceStatus.onTime:
      return AppColors.success;
    case AttendanceStatus.late:
      return AppColors.warning;
    case AttendanceStatus.earlyDeparture:
      return AppColors.danger;
    case AttendanceStatus.absent:
      return AppColors.orange;
    case AttendanceStatus.missingCheckout:
      return AppColors.purple;
  }
}

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key, this.showHeader = true});
  final bool showHeader;

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  String period = 'Today';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final filter = periodFrom(period);
    final sales = app.visibleSales(period: filter);
    final total = sales.fold<double>(0, (p, e) => p + e.amount);
    final prev = period == 'Today'
        ? app.visibleSales(period: PeriodFilter(from: filter.from.subtract(const Duration(days: 1)), to: filter.from))
        : <Sale>[];
    final prevTotal = prev.fold<double>(0, (p, e) => p + e.amount);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (widget.showHeader) const ScreenHeader(title: 'Sales'),
            const BranchSelectorBar(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: PeriodChips(value: period, onChanged: (v) => setState(() => period = v)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  AppCard(
                    color: AppColors.successSoft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Sales', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(Formatters.money(total), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                        Text(Formatters.trend(total, prevTotal), style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        SizedBox(height: 110, child: _HourBarChart(sales: sales, color: AppColors.success)),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Add Sale',
                          icon: Icons.add,
                          onPressed: () => context.push(_addSaleRoute(app.currentUser?.role)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text('Recent Sales', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (sales.isEmpty)
                    const EmptyView(title: 'No sales yet', subtitle: 'Record the first sale for this period.')
                  else
                    ...sales.take(20).map((s) => _SaleTile(sale: s)).toList().animate(interval: 40.ms).fadeIn().slideX(begin: 0.04, end: 0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _addSaleRoute(UserRole? role) {
    switch (role) {
      case UserRole.businessAdmin:
        return '/ba/sales/add';
      case UserRole.manager:
        return '/mg/sales/add';
      default:
        return '/emp/sales/add';
    }
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({required this.sale});
  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.point_of_sale_rounded, color: AppColors.success),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sale.category, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    '${sale.paymentMethod} · ${Formatters.time(sale.date)} · ${app.userName(sale.userId)}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  if (sale.description.isNotEmpty)
                    Text(sale.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Text(Formatters.money(sale.amount), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.success)),
          ],
        ),
      ),
    );
  }
}

class _HourBarChart extends StatelessWidget {
  const _HourBarChart({required this.sales, required this.color});
  final List<Sale> sales;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final hours = {6: 0.0, 10: 0.0, 14: 0.0, 18: 0.0, 22: 0.0};
    for (final s in sales) {
      final h = s.date.hour;
      final bucket = h < 10 ? 6 : h < 14 ? 10 : h < 18 ? 14 : h < 22 ? 18 : 22;
      hours[bucket] = (hours[bucket] ?? 0) + s.amount;
    }
    final maxY = (hours.values.fold<double>(0, (p, e) => e > p ? e : p)).clamp(1, double.infinity);
    final keys = hours.keys.toList();
    return BarChart(
      BarChartData(
        maxY: maxY * 1.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= keys.length) return const SizedBox.shrink();
                return Text('${keys[i]}h', style: const TextStyle(fontSize: 10, color: AppColors.muted));
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < keys.length; i++)
            BarChartGroupData(x: i, barRods: [BarChartRodData(toY: hours[keys[i]] ?? 0, color: color, width: 14, borderRadius: BorderRadius.circular(6))]),
        ],
      ),
    );
  }
}

class AddSaleScreen extends StatefulWidget {
  const AddSaleScreen({super.key});

  @override
  State<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends State<AddSaleScreen> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  DateTime _date = DateTime.now();
  String _category = AppConstants.saleCategories.first;
  String _payment = AppConstants.paymentMethods.first;
  String? _branchId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<StaffProController>();
    _branchId = app.effectiveBranchId ?? app.currentUser?.branchId;
  }

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<StaffProController>().addSale(
            amount: double.parse(_amount.text.replaceAll(',', '')),
            date: _date,
            category: _category,
            paymentMethod: _payment,
            description: _desc.text,
            branchId: _branchId,
          );
      if (!mounted) return;
      showToast(context, 'Sale saved');
      context.pop();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final locked = app.currentUser?.role == UserRole.employee || app.currentUser?.role == UserRole.manager;
    return Scaffold(
      appBar: AppBar(title: const Text('Add Sale')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!locked)
              DropdownButtonFormField<String>(
                initialValue: _branchId,
                decoration: const InputDecoration(labelText: 'Branch'),
                items: app.visibleBranches().map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                onChanged: (v) => setState(() => _branchId = v),
              )
            else
              AppTextField(label: 'Branch', controller: TextEditingController(text: app.branchName(_branchId)), readOnly: true, prefix: Icons.storefront_outlined),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Date',
              controller: TextEditingController(text: Formatters.date(_date)),
              readOnly: true,
              prefix: Icons.calendar_today_outlined,
              onTap: () async {
                final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)), initialDate: _date);
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 14),
            AppTextField(label: 'Amount', controller: _amount, hint: '0', prefix: Icons.payments_outlined, keyboardType: TextInputType.number, validator: Validators.amount),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Sale Type / Category'),
              items: AppConstants.saleCategories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _payment,
              decoration: const InputDecoration(labelText: 'Payment Method'),
              items: AppConstants.paymentMethods.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _payment = v ?? _payment),
            ),
            const SizedBox(height: 14),
            AppTextField(label: 'Description (Optional)', controller: _desc, hint: 'Notes', prefix: Icons.notes_outlined, maxLines: 3),
            const SizedBox(height: 24),
            AppButton(label: 'Save Sale', loading: _loading, onPressed: _loading ? null : _save),
          ],
        ),
      ),
    );
  }
}

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String period = 'Today';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final filter = periodFrom(period);
    final items = app.visibleExpenses(period: filter);
    final total = items.fold<double>(0, (p, e) => p + e.amount);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(title: 'Expenses'),
            const BranchSelectorBar(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: PeriodChips(value: period, onChanged: (v) => setState(() => period = v)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  AppCard(
                    color: AppColors.dangerSoft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Expenses', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(Formatters.money(total), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                        SizedBox(height: 110, child: _HourBarChart(sales: items.map((e) => Sale(id: e.id, businessId: e.businessId, branchId: e.branchId, userId: e.userId, amount: e.amount, date: e.date)).toList(), color: AppColors.danger)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppButton(label: 'Add Expense', icon: Icons.add, onPressed: () => context.push(_addRoute(app.currentUser?.role))),
                  const SizedBox(height: 18),
                  const Text('Recent Expenses', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (items.isEmpty)
                    const EmptyView(title: 'No expenses yet', subtitle: 'Record an expense to see it here.')
                  else
                    ...items.take(20).map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(12)),
                                  child: const Icon(Icons.receipt_long_outlined, color: AppColors.danger),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(e.categoryName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Text('${Formatters.time(e.date)} · ${e.description}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Text(Formatters.money(e.amount), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.danger)),
                              ],
                            ),
                          ),
                        )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _addRoute(UserRole? role) {
    switch (role) {
      case UserRole.businessAdmin:
        return '/ba/expenses/add';
      case UserRole.manager:
        return '/mg/expenses/add';
      default:
        return '/emp/expenses/add';
    }
  }
}

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  DateTime _date = DateTime.now();
  String? _categoryId;
  String _payment = 'Cash';
  String? _receipt;
  String? _branchId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<StaffProController>();
    _branchId = app.effectiveBranchId ?? app.currentUser?.branchId;
    final cats = app.categoriesFor(app.currentUser?.businessId).where((c) => c.status == EntityStatus.active);
    if (cats.isNotEmpty) _categoryId = cats.first.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (file != null) setState(() => _receipt = file.path);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_categoryId == null) {
      showToast(context, 'Select a category', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<StaffProController>().addExpense(
            amount: double.parse(_amount.text.replaceAll(',', '')),
            date: _date,
            categoryId: _categoryId!,
            paymentMethod: _payment,
            description: _desc.text,
            receiptPath: _receipt,
            branchId: _branchId,
          );
      if (!mounted) return;
      showToast(context, 'Expense saved');
      context.pop();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final cats = app.categoriesFor(app.currentUser?.businessId).where((c) => c.status == EntityStatus.active).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AppTextField(
              label: 'Date',
              controller: TextEditingController(text: Formatters.date(_date)),
              readOnly: true,
              prefix: Icons.calendar_today_outlined,
              onTap: () async {
                final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDate: _date);
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 14),
            AppTextField(label: 'Amount', controller: _amount, hint: '0', prefix: Icons.payments_outlined, keyboardType: TextInputType.number, validator: Validators.amount),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _payment,
              decoration: const InputDecoration(labelText: 'Payment Method'),
              items: AppConstants.paymentMethods.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _payment = v ?? _payment),
            ),
            const SizedBox(height: 14),
            AppTextField(label: 'Description', controller: _desc, hint: 'What was this for?', prefix: Icons.notes_outlined, maxLines: 3),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _pickReceipt,
              child: Container(
                height: 110,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary, style: BorderStyle.solid),
                  color: AppColors.wash,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
                    const SizedBox(height: 6),
                    Text(_receipt == null ? 'Add Receipt (Optional)' : 'Receipt attached', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            AppButton(label: 'Send Expense', loading: _loading, onPressed: _loading ? null : _save),
          ],
        ),
      ),
    );
  }
}

class AttendanceActionScreen extends StatelessWidget {
  const AttendanceActionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final user = app.currentUser!;
    final open = app.openAttendance(user.id);
    final historyRoute = user.role == UserRole.manager ? '/mg/attendance/history' : '/emp/attendance/history';
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(title: 'Attendance', onBell: () => context.push(user.role == UserRole.manager ? '/mg/notifications' : '/emp/notifications')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: open == null ? AppColors.primary : AppColors.success, width: 10),
                        color: (open == null ? AppColors.wash : AppColors.successSoft),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(open == null ? Icons.login_rounded : Icons.check_circle_rounded, size: 36, color: open == null ? AppColors.primary : AppColors.success),
                          const SizedBox(height: 8),
                          Text(open == null ? 'Checked Out' : 'Checked In', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          if (open != null) Text(Formatters.time(open.checkInAt), style: const TextStyle(color: AppColors.muted)),
                        ],
                      ),
                    ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                  ),
                  const SizedBox(height: 20),
                  AppCard(
                    child: Column(
                      children: [
                        _kv('Shift', app.shiftFor(businessId: user.businessId ?? '', branchId: user.branchId)?.name ?? 'Default'),
                        _kv('Hours', '${app.shiftFor(businessId: user.businessId ?? '', branchId: user.branchId)?.startTime ?? '09:00'} - ${app.shiftFor(businessId: user.businessId ?? '', branchId: user.branchId)?.endTime ?? '18:00'}'),
                        _kv('Location', app.branchName(user.branchId)),
                        _kv('Status', open == null ? 'Not in' : attendanceLabel(open.status)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: open == null ? 'Check In' : 'Check Out',
                    onPressed: () async {
                      try {
                        if (open == null) {
                          await app.checkIn();
                          if (context.mounted) showToast(context, 'Checked in');
                        } else {
                          await app.checkOut();
                          if (context.mounted) showToast(context, 'Checked out');
                        }
                      } catch (e) {
                        if (context.mounted) showToast(context, e.toString(), error: true);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  AppButton(label: 'Attendance History', outlined: true, icon: Icons.history, onPressed: () => context.push(historyRoute)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(k, style: const TextStyle(color: AppColors.muted))),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key, this.team = false});
  final bool team;

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  String period = 'This Week';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final filter = periodFrom(period);
    final records = app.visibleAttendance(period: filter, userId: widget.team ? null : app.currentUser?.id);
    return Scaffold(
      appBar: widget.team ? null : AppBar(title: const Text('Attendance History')),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.team) const ScreenHeader(title: 'Attendance'),
            if (widget.team) const BranchSelectorBar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: PeriodChips(value: period, onChanged: (v) => setState(() => period = v)),
            ),
            if (widget.team)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Builder(builder: (context) {
                  final summary = app.attendanceSummary(
                    day: DateTime.now(),
                    businessId: app.currentUser?.businessId,
                    branchId: app.effectiveBranchId,
                  );
                  return Row(
                    children: [
                      _mini('Present', '${summary['present']}', AppColors.success),
                      _mini('Absent', '${summary['absent']}', AppColors.danger),
                      _mini('Late', '${summary['late']}', AppColors.warning),
                    ],
                  );
                }),
              ),
            Expanded(
              child: records.isEmpty
                  ? const EmptyView(title: 'No attendance records', subtitle: 'Check-in activity will appear here.')
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: records.length,
                      itemBuilder: (context, i) {
                        final a = records[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            onTap: app.currentUser?.role == UserRole.businessAdmin
                                ? () => _correct(context, a)
                                : null,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(widget.team ? app.userName(a.userId) : Formatters.day(a.checkInAt), style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Text(
                                        '${Formatters.time(a.checkInAt)} - ${a.checkOutAt == null ? '--:--' : Formatters.time(a.checkOutAt!)}  ·  ${Formatters.duration(a.workedMinutes)}',
                                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                StatusBadge(label: attendanceLabel(a.status), color: attendanceColor(a.status)),
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

  Widget _mini(String l, String v, Color c) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: AppCard(
          color: c.withValues(alpha: 0.08),
          child: Column(
            children: [
              Text(v, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: c)),
              Text(l, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _correct(BuildContext context, AttendanceRecord record) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Correct attendance'),
        content: TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason'), maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Set checkout now')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      try {
        await context.read<StaffProController>().correctAttendance(
              attendanceId: record.id,
              checkOutAt: DateTime.now(),
              reason: reason.text,
            );
        if (context.mounted) showToast(context, 'Attendance corrected');
      } catch (e) {
        if (context.mounted) showToast(context, e.toString(), error: true);
      }
    }
  }
}

class PeopleListScreen extends StatefulWidget {
  const PeopleListScreen({super.key, required this.role});
  final UserRole role;

  @override
  State<PeopleListScreen> createState() => _PeopleListScreenState();
}

class _PeopleListScreenState extends State<PeopleListScreen> {
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
    final user = app.currentUser!;
    EntityStatus? status;
    if (filter == 'Active') status = EntityStatus.active;
    if (filter == 'Inactive') status = EntityStatus.inactive;
    final people = app.usersWhere(
      role: widget.role,
      businessId: user.role == UserRole.superAdmin ? null : user.businessId,
      branchId: user.role == UserRole.manager ? user.branchId : app.effectiveBranchId,
      status: status,
      query: _search.text,
    );
    final title = widget.role == UserRole.manager ? 'Managers' : 'Employees';
    final addRoute = widget.role == UserRole.manager
        ? (user.role == UserRole.superAdmin ? '/sa/managers/add' : '/ba/managers/add')
        : (user.role == UserRole.manager ? '/mg/employees/add' : '/ba/employees/add');
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(title: title),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: SearchField(controller: _search, hint: 'Search $title', onChanged: (_) => setState(() {})),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FilterChips(items: const ['All', 'Active', 'Inactive'], value: filter, onChanged: (v) => setState(() => filter = v)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: AppButton(label: 'Add $title'.replaceAll('s', '').replaceFirst('Add Employee', 'Add Employee').replaceFirst('Add Manager', 'Add Manager'), icon: Icons.add, onPressed: () => context.push(addRoute)),
            ),
            Expanded(
              child: people.isEmpty
                  ? EmptyView(title: 'No $title yet', subtitle: 'Create the first record to get started.')
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: people.length,
                      itemBuilder: (context, i) {
                        final p = people[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            onTap: () => context.push('${_detailBase(user.role, widget.role)}/${p.id}'),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.washStrong,
                                  child: Text(Formatters.initials(p.fullName), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
                                      Text('${p.position ?? roleLabel(p.role)} · ${app.branchName(p.branchId)}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                StatusBadge.active(p.isActive),
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

  String _detailBase(UserRole actor, UserRole target) {
    if (actor == UserRole.manager) return '/mg/employees';
    if (target == UserRole.manager) return '/ba/managers';
    return '/ba/employees';
  }
}

class PersonFormScreen extends StatefulWidget {
  const PersonFormScreen({super.key, required this.role, this.userId});
  final UserRole role;
  final String? userId;

  @override
  State<PersonFormScreen> createState() => _PersonFormScreenState();
}

class _PersonFormScreenState extends State<PersonFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  String? _branchId;
  String _position = AppConstants.employeePositions.first;
  DateTime _joining = DateTime.now();
  EntityStatus _status = EntityStatus.active;
  bool _loading = false;
  AppUser? _existing;

  @override
  void initState() {
    super.initState();
    final app = context.read<StaffProController>();
    _branchId = app.effectiveBranchId ?? app.currentUser?.branchId;
    if (widget.userId != null) {
      try {
        _existing = app.db.users.firstWhere((u) => u.id == widget.userId);
        _name.text = _existing!.fullName;
        _email.text = _existing!.email;
        _phone.text = _existing!.phone;
        _code.text = _existing!.employeeCode ?? '';
        _branchId = _existing!.branchId;
        _position = _existing!.position ?? _position;
        _joining = _existing!.joiningDate ?? DateTime.now();
        _status = _existing!.status;
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    final app = context.read<StaffProController>();
    try {
      if (_existing == null) {
        await app.createStaff(
          role: widget.role,
          fullName: _name.text,
          email: _email.text,
          phone: _phone.text,
          password: _password.text,
          branchId: _branchId,
          employeeCode: _code.text,
          position: widget.role == UserRole.manager ? 'Branch Manager' : _position,
          joiningDate: _joining,
        );
      } else {
        _existing!
          ..fullName = _name.text
          ..phone = _phone.text
          ..employeeCode = _code.text
          ..position = widget.role == UserRole.manager ? 'Branch Manager' : _position
          ..joiningDate = _joining
          ..status = _status;
        await app.updateStaff(_existing!);
      }
      if (!mounted) return;
      showToast(context, 'Saved');
      context.pop();
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final title = _existing == null
        ? (widget.role == UserRole.manager ? 'Add Manager' : 'Add Employee')
        : (_existing!.fullName);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.washStrong,
                child: Text(Formatters.initials(_name.text.isEmpty ? 'New' : _name.text), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
              ),
            ),
            const SizedBox(height: 18),
            AppTextField(label: 'Full Name', controller: _name, hint: 'Enter full name', prefix: Icons.person_outline, validator: (v) => Validators.requiredField(v, field: 'Name')),
            const SizedBox(height: 14),
            AppTextField(label: 'Email', controller: _email, hint: 'Enter email', prefix: Icons.mail_outline, enabled: _existing == null, validator: Validators.email),
            const SizedBox(height: 14),
            AppTextField(label: 'Phone', controller: _phone, hint: 'Enter phone', prefix: Icons.phone_outlined, keyboardType: TextInputType.phone, validator: Validators.phone),
            const SizedBox(height: 14),
            AppTextField(label: widget.role == UserRole.manager ? 'Manager ID' : 'Employee ID', controller: _code, hint: 'Optional unique ID', prefix: Icons.badge_outlined),
            if (_existing == null) ...[
              const SizedBox(height: 14),
              AppTextField(label: 'Temporary Password', controller: _password, hint: 'Set a password', prefix: Icons.lock_outline, validator: (v) => Validators.password(v)),
            ],
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _branchId,
              decoration: const InputDecoration(labelText: 'Branch'),
              items: app.visibleBranches().map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
              onChanged: app.currentUser?.role == UserRole.manager ? null : (v) => setState(() => _branchId = v),
            ),
            if (widget.role == UserRole.employee) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _position,
                decoration: const InputDecoration(labelText: 'Role / Position'),
                items: AppConstants.employeePositions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _position = v ?? _position),
              ),
            ],
            const SizedBox(height: 14),
            AppTextField(
              label: 'Joining Date',
              controller: TextEditingController(text: Formatters.date(_joining)),
              readOnly: true,
              prefix: Icons.event_outlined,
              onTap: () async {
                final picked = await showDatePicker(context: context, firstDate: DateTime(2018), lastDate: DateTime.now(), initialDate: _joining);
                if (picked != null) setState(() => _joining = picked);
              },
            ),
            if (_existing != null) ...[
              const SizedBox(height: 14),
              const Text('Status', style: TextStyle(fontWeight: FontWeight.w700)),
              Row(
                children: [
                  Radio<EntityStatus>(value: EntityStatus.active, groupValue: _status, onChanged: (v) => setState(() => _status = v!)),
                  const Text('Active'),
                  Radio<EntityStatus>(value: EntityStatus.inactive, groupValue: _status, onChanged: (v) => setState(() => _status = v!)),
                  const Text('Inactive'),
                ],
              ),
              const SizedBox(height: 8),
              AppButton(
                label: 'Transfer Branch',
                outlined: true,
                icon: Icons.swap_horiz,
                onPressed: () async {
                  final branches = app.visibleBranches().where((b) => b.id != _existing!.branchId).toList();
                  if (branches.isEmpty) {
                    showToast(context, 'No other branch available', error: true);
                    return;
                  }
                  final selected = await showModalBottomSheet<String>(
                    context: context,
                    builder: (ctx) => ListView(
                      children: branches.map((b) => ListTile(title: Text(b.name), onTap: () => Navigator.pop(ctx, b.id))).toList(),
                    ),
                  );
                  if (selected != null && context.mounted) {
                    try {
                      await app.transferBranch(userId: _existing!.id, toBranchId: selected, reason: 'Admin transfer');
                      if (context.mounted) showToast(context, 'Branch transferred');
                    } catch (e) {
                      if (context.mounted) showToast(context, e.toString(), error: true);
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
              AppButton(
                label: 'Reset Access',
                outlined: true,
                icon: Icons.lock_reset,
                onPressed: () async {
                  final temp = const Uuid().v4().substring(0, 8);
                  final ok = await confirmAction(context, title: 'Reset password?', message: 'A new temporary password will be set: $temp');
                  if (ok && context.mounted) {
                    await app.resetAccess(_existing!.id, temp);
                    if (context.mounted) showToast(context, 'Temporary password: $temp');
                  }
                },
              ),
            ],
            const SizedBox(height: 22),
            AppButton(label: _existing == null ? 'Create' : 'Save Changes', loading: _loading, onPressed: _loading ? null : _save),
          ],
        ),
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String tab = 'All';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final items = app.myNotifications(unreadOnly: tab == 'Unread');
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(title: 'Notifications'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(child: FilterChips(items: ['All', 'Unread'], value: tab, onChanged: (v) => setState(() => tab = v))),
                  TextButton(onPressed: app.markAllRead, child: const Text('Mark all read')),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const EmptyView(title: 'No notifications', subtitle: 'Operational alerts will appear here.')
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final n = items[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            color: n.isRead ? Colors.white : AppColors.wash,
                            onTap: () => app.markNotificationRead(n.id),
                            child: Row(
                              children: [
                                CircleAvatar(backgroundColor: _nColor(n.type).withValues(alpha: 0.15), child: Icon(_nIcon(n.type), color: _nColor(n.type), size: 20)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(n.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                                      Text(n.message, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Text(Formatters.relative(n.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.placeholder)),
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

  IconData _nIcon(NotificationType t) {
    switch (t) {
      case NotificationType.saleAdded:
        return Icons.point_of_sale;
      case NotificationType.expenseAdded:
        return Icons.receipt_long;
      case NotificationType.employeeCheckin:
      case NotificationType.managerCheckin:
        return Icons.login;
      case NotificationType.employeeCheckout:
      case NotificationType.managerCheckout:
        return Icons.logout;
      case NotificationType.passwordResetRequest:
        return Icons.lock_reset;
      case NotificationType.businessCreated:
        return Icons.apartment;
      default:
        return Icons.notifications;
    }
  }

  Color _nColor(NotificationType t) {
    switch (t) {
      case NotificationType.saleAdded:
        return AppColors.success;
      case NotificationType.expenseAdded:
        return AppColors.danger;
      case NotificationType.employeeCheckin:
      case NotificationType.managerCheckin:
        return AppColors.primary;
      case NotificationType.passwordResetRequest:
        return AppColors.warning;
      default:
        return AppColors.purple;
    }
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final u = app.currentUser!;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: CircleAvatar(
              radius: 42,
              backgroundColor: AppColors.washStrong,
              child: Text(Formatters.initials(u.fullName), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary)),
            ),
          ),
          const SizedBox(height: 10),
          Text(u.fullName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text('${roleLabel(u.role)} · ${app.businessName(u.businessId)}', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              children: [
                _row('Full Name', u.fullName),
                _row('Email', u.email),
                _row('Phone', u.phone.isEmpty ? '—' : u.phone),
                if (u.employeeCode != null) _row('ID', u.employeeCode!),
                if (u.branchId != null) _row('Branch', app.branchName(u.branchId)),
                if (u.position != null) _row('Position', u.position!),
                if (u.joiningDate != null) _row('Joining Date', Formatters.date(u.joiningDate!)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppButton(label: 'Edit Profile', outlined: true, icon: Icons.edit_outlined, onPressed: () => _edit(context, app, u)),
          const SizedBox(height: 10),
          AppButton(label: 'Change Password', outlined: true, icon: Icons.lock_outline, onPressed: () => context.push(_pwd(u.role))),
          const SizedBox(height: 10),
          AppButton(
            label: 'Logout',
            destructive: true,
            icon: Icons.logout,
            onPressed: () async {
              final ok = await confirmAction(context, title: 'Logout?', message: 'You will need to sign in again.', confirmLabel: 'Logout', destructive: true);
              if (ok && context.mounted) {
                await app.logout();
                if (context.mounted) context.go('/login');
              }
            },
          ),
        ],
      ),
    );
  }

  String _pwd(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return '/sa/password';
      case UserRole.businessAdmin:
        return '/ba/password';
      case UserRole.manager:
        return '/mg/password';
      case UserRole.employee:
        return '/emp/password';
    }
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(color: AppColors.muted))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, StaffProController app, AppUser u) async {
    final name = TextEditingController(text: u.fullName);
    final phone = TextEditingController(text: u.phone);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      await app.updateProfile(fullName: name.text, phone: phone.text);
      if (context.mounted) showToast(context, 'Profile updated');
    }
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppTextField(label: 'Current Password', controller: _current, obscure: true, prefix: Icons.lock_outline),
          const SizedBox(height: 14),
          AppTextField(label: 'New Password', controller: _next, obscure: true, prefix: Icons.lock_outline),
          const SizedBox(height: 14),
          AppTextField(label: 'Confirm Password', controller: _confirm, obscure: true, prefix: Icons.lock_outline),
          const SizedBox(height: 22),
          AppButton(
            label: 'Update Password',
            loading: _loading,
            onPressed: () async {
              setState(() => _loading = true);
              try {
                await context.read<StaffProController>().changePassword(current: _current.text, next: _next.text, confirm: _confirm.text);
                if (context.mounted) {
                  showToast(context, 'Password updated');
                  context.pop();
                }
              } catch (e) {
                if (context.mounted) showToast(context, e.toString(), error: true);
              } finally {
                if (mounted) setState(() => _loading = false);
              }
            },
          ),
        ],
      ),
    );
  }
}

class CashScreen extends StatelessWidget {
  const CashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final user = app.currentUser!;
    final today = PeriodFilter.today();
    final month = PeriodFilter.month();
    final dayCash = app.cashInHand(from: today.from, to: today.to, userId: user.id, branchId: user.branchId, businessId: user.businessId);
    final monthCash = app.cashInHand(from: month.from, to: month.to, userId: user.id, branchId: user.branchId, businessId: user.businessId);
    final sales = app.visibleSales(period: today).where((s) => s.isCash).fold<double>(0, (p, e) => p + e.amount);
    final expenses = app.visibleExpenses(period: today).where((e) => e.isCash).fold<double>(0, (p, e) => p + e.amount);
    return Scaffold(
      appBar: AppBar(title: const Text('Cash in Hand')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          KpiCard(label: "Today's cash", value: Formatters.money(dayCash), icon: Icons.account_balance_wallet_outlined, iconColor: AppColors.primary),
          const SizedBox(height: 10),
          KpiCard(label: 'Month to date', value: Formatters.money(monthCash), icon: Icons.calendar_month_outlined, iconColor: AppColors.teal),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('How it is calculated', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Opening (carried cash from prior days) + cash sales − cash expenses.\nToday cash sales: ${Formatters.money(sales)}\nToday cash expenses: ${Formatters.money(expenses)}', style: const TextStyle(color: AppColors.muted, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReportsHubScreen extends StatefulWidget {
  const ReportsHubScreen({super.key, this.platform = false});
  final bool platform;

  @override
  State<ReportsHubScreen> createState() => _ReportsHubScreenState();
}

class _ReportsHubScreenState extends State<ReportsHubScreen> {
  DateTimeRange range = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final period = PeriodFilter(from: range.start, to: range.end.add(const Duration(days: 1)), label: 'Custom');
    final biz = app.currentUser?.businessId;
    final branch = widget.platform ? null : app.effectiveBranchId;
    final sales = app.salesTotal(businessId: widget.platform ? null : biz, branchId: branch, period: period);
    final expenses = app.expensesTotal(businessId: widget.platform ? null : biz, branchId: branch, period: period);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            ScreenHeader(title: 'Reports'),
            AppCard(
              onTap: () async {
                final picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDateRange: range);
                if (picked != null) setState(() => range = picked);
              },
              child: Row(
                children: [
                  const Icon(Icons.date_range, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text('${DateFormat('dd MMM yyyy').format(range.start)}  →  ${DateFormat('dd MMM yyyy').format(range.end)}'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: KpiCard(label: 'Sales', value: Formatters.money(sales), icon: Icons.trending_up, iconColor: AppColors.success)),
                const SizedBox(width: 10),
                Expanded(child: KpiCard(label: 'Expenses', value: Formatters.money(expenses), icon: Icons.trending_down, iconColor: AppColors.danger)),
              ],
            ),
            const SizedBox(height: 16),
            ...[
              ('Sales Report', Icons.point_of_sale, 'sales'),
              ('Expense Report', Icons.receipt_long, 'expenses'),
              ('Attendance Report', Icons.fact_check_outlined, 'attendance'),
              if (!widget.platform) ('Branch Comparison', Icons.account_tree_outlined, 'branches'),
              if (widget.platform) ('Business Overview', Icons.apartment_outlined, 'businesses'),
            ].map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    onTap: () => _open(context, app, e.$3, period),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(backgroundColor: AppColors.wash, child: Icon(e.$2, color: AppColors.primary)),
                      title: Text(e.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ),
                )),
            const SizedBox(height: 8),
            AppButton(
              label: 'Export CSV',
              outlined: true,
              icon: Icons.ios_share,
              onPressed: () => _export(app, period),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, StaffProController app, String type, PeriodFilter period) {
    final sales = app.visibleSales(period: period);
    final expenses = app.visibleExpenses(period: period);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, c) => ListView(
          controller: c,
          padding: const EdgeInsets.all(20),
          children: [
            Text(type.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 12),
            if (type == 'sales') ...sales.map((s) => ListTile(title: Text(Formatters.money(s.amount)), subtitle: Text('${s.category} · ${Formatters.dateTime(s.date)}'))),
            if (type == 'expenses') ...expenses.map((s) => ListTile(title: Text(Formatters.money(s.amount)), subtitle: Text('${s.categoryName} · ${Formatters.dateTime(s.date)}'))),
            if (type == 'attendance') ...app.visibleAttendance(period: period).map((a) => ListTile(title: Text(app.userName(a.userId)), subtitle: Text('${attendanceLabel(a.status)} · ${Formatters.date(a.checkInAt)}'))),
            if (type == 'branches')
              ...app.visibleBranches().map((b) {
                final s = app.salesTotal(businessId: b.businessId, branchId: b.id, period: period);
                return ListTile(title: Text(b.name), trailing: Text(Formatters.money(s)));
              }),
            if (type == 'businesses')
              ...app.db.businesses.map((b) {
                final s = app.salesTotal(businessId: b.id, period: period);
                return ListTile(title: Text(b.name), trailing: Text(Formatters.money(s)));
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _export(StaffProController app, PeriodFilter period) async {
    final sales = app.visibleSales(period: period);
    final buf = StringBuffer('Date,User,Branch,Category,Payment,Amount,Description\n');
    for (final s in sales) {
      buf.writeln('${s.date.toIso8601String()},${app.userName(s.userId)},${app.branchName(s.branchId)},${s.category},${s.paymentMethod},${s.amount},${s.description.replaceAll(',', ' ')}');
    }
    await SharePlus.instance.share(ShareParams(text: buf.toString(), title: 'StaffPro Sales Export'));
  }
}

class ActivityLogsScreen extends StatelessWidget {
  const ActivityLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final logs = app.visibleLogs();
    return Scaffold(
      appBar: AppBar(title: const Text('Activity Logs')),
      body: logs.isEmpty
          ? const EmptyView(title: 'No activity yet')
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: logs.length,
              itemBuilder: (context, i) {
                final l = logs[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${l.action.name} · ${l.module}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${app.userName(l.performedBy)} · ${Formatters.dateTime(l.createdAt)}\n${l.newData ?? ''}'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class PasswordRequestStatusScreen extends StatelessWidget {
  const PasswordRequestStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final req = app.latestRequestFor(app.currentUser!.id);
    final message = TextEditingController();
    return Scaffold(
      appBar: AppBar(title: const Text('Password Recovery')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.vpn_key_outlined, size: 48, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(req == null ? 'No request yet' : 'Status: ${req.status.name}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Send a request to your Manager or Business Admin. You will be notified once the password is reset.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 18),
          AppTextField(label: 'Message', controller: message, hint: 'Add a message', maxLines: 4),
          const SizedBox(height: 18),
          AppButton(
            label: 'Send Request',
            onPressed: () async {
              try {
                await app.submitPasswordRequest(email: app.currentUser!.email, message: message.text);
                if (context.mounted) showToast(context, 'Request sent');
              } catch (e) {
                if (context.mounted) showToast(context, e.toString(), error: true);
              }
            },
          ),
        ],
      ),
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'StaffPro helps businesses manage branches, staff, sales, expenses and attendance.\n\n'
          'Super Admin creates businesses.\nBusiness Admin manages branches and people.\nManagers operate a single assigned branch.\nEmployees record sales, expenses and attendance.\n\n'
          'Default Super Admin secret code: STAFFPRO-2026 (change it in Settings after first login).',
          style: TextStyle(height: 1.5),
        ),
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About App')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('StaffPro', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text('Employee Management App'),
            SizedBox(height: 6),
            Text('Version 1.0.0', style: TextStyle(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
