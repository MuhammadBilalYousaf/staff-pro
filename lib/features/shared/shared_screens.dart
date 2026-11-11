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
import 'package:staffpro/core/widgets/brand_logo.dart';
import 'package:staffpro/core/widgets/ui_kit.dart';
import 'package:staffpro/features/shells/app_shell.dart';
import 'package:staffpro/models/enums.dart';
import 'package:staffpro/models/models.dart';
import 'package:staffpro/state/app_state.dart';

PeriodFilter periodFrom(String label, {DateTimeRange? customRange}) {
  switch (label) {
    case 'Yesterday':
      return PeriodFilter.yesterday();
    case 'This Week':
      return PeriodFilter.week();
    case 'Last Week':
      return PeriodFilter.lastWeek();
    case 'This Month':
      return PeriodFilter.month();
    case 'Custom':
      if (customRange != null) {
        return PeriodFilter.custom(customRange.start, customRange.end);
      }
      return PeriodFilter.today();
    default:
      return PeriodFilter.today();
  }
}

Future<DateTimeRange?> pickPeriodRange(BuildContext context, {DateTimeRange? current}) {
  final now = DateTime.now();
  return showDateRangePicker(
    context: context,
    firstDate: DateTime(2020),
    lastDate: now,
    initialDateRange: current ??
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        ),
    helpText: 'Select dates or a full month',
    saveText: 'Apply',
  );
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
  DateTimeRange? customRange;

  Future<void> _onPeriodChanged(String next) async {
    if (next == 'Custom') {
      final picked = await pickPeriodRange(context, current: customRange);
      if (picked == null || !mounted) return;
      setState(() {
        period = 'Custom';
        customRange = picked;
      });
      return;
    }
    setState(() {
      period = next;
      customRange = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final filter = periodFrom(period, customRange: customRange);
    final sales = app.visibleSales(period: filter);
    final total = sales.fold<double>(0, (p, e) => p + e.amount);
    final prev = period == 'Today'
        ? app.visibleSales(period: PeriodFilter.yesterday())
        : period == 'Yesterday'
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
              child: PeriodChips(value: period, onChanged: _onPeriodChanged),
            ),
            if (period == 'Custom' && customRange != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: AppCard(
                  onTap: () => _onPeriodChanged('Custom'),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${Formatters.date(customRange!.start)} → ${Formatters.date(customRange!.end)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Text('Change', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
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
                        Text('Total Sales · ${filter.label}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(Formatters.money(total), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                        if (period == 'Today' || period == 'Yesterday')
                          Text(Formatters.trend(total, prevTotal), style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
                        Text('${sales.length} record${sales.length == 1 ? '' : 's'} in this period', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
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
                  const Text('Sales in period', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (sales.isEmpty)
                    const EmptyView(title: 'No sales in this period', subtitle: 'Try another filter or pick custom dates.')
                  else
                    ...sales.map((s) => _SaleTile(sale: s)).toList().animate(interval: 40.ms).fadeIn().slideX(begin: 0.04, end: 0),
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
    final canManage = app.canManageSalesExpenses;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: canManage ? () => context.push('/ba/sales/edit/${sale.id}') : null,
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
            if (canManage) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Edit sale',
                onPressed: () => context.push('/ba/sales/edit/${sale.id}'),
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
              IconButton(
                tooltip: 'Delete sale',
                onPressed: () => _deleteSale(context, sale),
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSale(BuildContext context, Sale sale) async {
    final ok = await confirmAction(
      context,
      title: 'Delete sale?',
      message: 'Remove this ${Formatters.money(sale.amount)} ${sale.category} sale? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await context.read<StaffProController>().deleteSale(sale.id);
      if (context.mounted) showToast(context, 'Sale deleted');
    } catch (error) {
      if (context.mounted) showToast(context, error.toString(), error: true);
    }
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
  const AddSaleScreen({super.key, this.saleId});
  final String? saleId;

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
  bool get _editing => widget.saleId != null;

  @override
  void initState() {
    super.initState();
    final app = context.read<StaffProController>();
    final existing = _editing ? app.saleById(widget.saleId) : null;
    if (existing != null) {
      _amount.text = existing.amount.toStringAsFixed(0);
      _desc.text = existing.description;
      _date = existing.date;
      _category = AppConstants.saleCategories.contains(existing.category) ? existing.category : AppConstants.saleCategories.first;
      _payment = AppConstants.paymentMethods.contains(existing.paymentMethod) ? existing.paymentMethod : AppConstants.paymentMethods.first;
      _branchId = existing.branchId;
      return;
    }
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
      final app = context.read<StaffProController>();
      if (_editing) {
        await app.updateSale(
          saleId: widget.saleId!,
          amount: double.parse(_amount.text.replaceAll(',', '')),
          date: _date,
          category: _category,
          paymentMethod: _payment,
          description: _desc.text,
          branchId: _branchId,
        );
      } else {
        await app.addSale(
          amount: double.parse(_amount.text.replaceAll(',', '')),
          date: _date,
          category: _category,
          paymentMethod: _payment,
          description: _desc.text,
          branchId: _branchId,
        );
      }
      if (!mounted) return;
      showToast(context, _editing ? 'Sale updated' : 'Sale saved');
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
      appBar: AppBar(title: Text(_editing ? 'Edit Sale' : 'Add Sale')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!locked)
              DropdownButtonFormField<String>(
                initialValue: _branchId != null && app.visibleBranches().any((b) => b.id == _branchId) ? _branchId : null,
                decoration: const InputDecoration(labelText: 'Branch'),
                items: app.visibleBranches().map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                validator: (v) => (v == null || v.isEmpty) ? 'Select a branch' : null,
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
            AppButton(
              label: _editing ? 'Update Sale' : 'Save Sale',
              loading: _loading,
              onPressed: _loading
                  ? null
                  : () {
                      if (!locked && (_branchId == null || _branchId!.isEmpty)) {
                        showToast(context, 'Select a branch first (not All Branches)', error: true);
                        return;
                      }
                      _save();
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key, this.showHeader = true});
  final bool showHeader;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String period = 'Today';
  DateTimeRange? customRange;

  Future<void> _onPeriodChanged(String next) async {
    if (next == 'Custom') {
      final picked = await pickPeriodRange(context, current: customRange);
      if (picked == null || !mounted) return;
      setState(() {
        period = 'Custom';
        customRange = picked;
      });
      return;
    }
    setState(() {
      period = next;
      customRange = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final filter = periodFrom(period, customRange: customRange);
    final items = app.visibleExpenses(period: filter);
    final total = items.fold<double>(0, (p, e) => p + e.amount);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (widget.showHeader) const ScreenHeader(title: 'Expenses'),
            const BranchSelectorBar(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: PeriodChips(value: period, onChanged: _onPeriodChanged),
            ),
            if (period == 'Custom' && customRange != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: AppCard(
                  onTap: () => _onPeriodChanged('Custom'),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${Formatters.date(customRange!.start)} → ${Formatters.date(customRange!.end)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Text('Change', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
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
                        Text('Total Expenses · ${filter.label}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(Formatters.money(total), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                        Text('${items.length} record${items.length == 1 ? '' : 's'} in this period', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                        SizedBox(height: 110, child: _HourBarChart(sales: items.map((e) => Sale(id: e.id, businessId: e.businessId, branchId: e.branchId, userId: e.userId, amount: e.amount, date: e.date)).toList(), color: AppColors.danger)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppButton(label: 'Add Expense', icon: Icons.add, onPressed: () => context.push(_addRoute(app.currentUser?.role))),
                  const SizedBox(height: 18),
                  const Text('Expenses in period', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (items.isEmpty)
                    const EmptyView(title: 'No expenses in this period', subtitle: 'Try another filter or pick custom dates.')
                  else
                    ...items.map((e) => _ExpenseTile(expense: e)),
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

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense});
  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final canManage = app.canManageSalesExpenses;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: canManage ? () => context.push('/ba/expenses/edit/${expense.id}') : null,
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
                  Text(expense.categoryName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    '${expense.paymentMethod} · ${Formatters.time(expense.date)} · ${app.userName(expense.userId)}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  if (expense.description.isNotEmpty)
                    Text(expense.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            Text(Formatters.money(expense.amount), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.danger)),
            if (canManage) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Edit expense',
                onPressed: () => context.push('/ba/expenses/edit/${expense.id}'),
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
              IconButton(
                tooltip: 'Delete expense',
                onPressed: () => _deleteExpense(context, expense),
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _deleteExpense(BuildContext context, Expense expense) async {
    final ok = await confirmAction(
      context,
      title: 'Delete expense?',
      message: 'Remove this ${Formatters.money(expense.amount)} ${expense.categoryName} expense? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await context.read<StaffProController>().deleteExpense(expense.id);
      if (context.mounted) showToast(context, 'Expense deleted');
    } catch (error) {
      if (context.mounted) showToast(context, error.toString(), error: true);
    }
  }
}

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key, this.expenseId});
  final String? expenseId;

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
  bool get _editing => widget.expenseId != null;

  @override
  void initState() {
    super.initState();
    final app = context.read<StaffProController>();
    final existing = _editing ? app.expenseById(widget.expenseId) : null;
    if (existing != null) {
      _amount.text = existing.amount.toStringAsFixed(0);
      _desc.text = existing.description;
      _date = existing.date;
      _categoryId = existing.categoryId;
      _payment = AppConstants.paymentMethods.contains(existing.paymentMethod) ? existing.paymentMethod : 'Cash';
      _receipt = existing.receiptPath;
      _branchId = existing.branchId;
      return;
    }
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
    final app = context.read<StaffProController>();
    final locked = app.currentUser?.role == UserRole.employee || app.currentUser?.role == UserRole.manager;
    if (!locked && (_branchId == null || _branchId!.isEmpty)) {
      showToast(context, 'Select a branch first (not All Branches)', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      if (_editing) {
        await app.updateExpense(
          expenseId: widget.expenseId!,
          amount: double.parse(_amount.text.replaceAll(',', '')),
          date: _date,
          categoryId: _categoryId!,
          paymentMethod: _payment,
          description: _desc.text,
          receiptPath: _receipt,
          branchId: _branchId,
        );
      } else {
        await app.addExpense(
          amount: double.parse(_amount.text.replaceAll(',', '')),
          date: _date,
          categoryId: _categoryId!,
          paymentMethod: _payment,
          description: _desc.text,
          receiptPath: _receipt,
          branchId: _branchId,
        );
      }
      if (!mounted) return;
      showToast(context, _editing ? 'Expense updated' : 'Expense saved');
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
    if (_categoryId != null && cats.every((c) => c.id != _categoryId)) {
      final existing = app.expenseById(widget.expenseId);
      if (existing != null) {
        cats.insert(0, ExpenseCategory(id: existing.categoryId, businessId: existing.businessId, name: existing.categoryName));
      }
    }
    final locked = app.currentUser?.role == UserRole.employee || app.currentUser?.role == UserRole.manager;
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit Expense' : 'Add Expense')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!locked)
              DropdownButtonFormField<String>(
                initialValue: _branchId != null && app.visibleBranches().any((b) => b.id == _branchId) ? _branchId : null,
                decoration: const InputDecoration(labelText: 'Branch'),
                items: app.visibleBranches().map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                validator: (v) => (v == null || v.isEmpty) ? 'Select a branch' : null,
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
            AppButton(label: _editing ? 'Update Expense' : 'Save Expense', loading: _loading, onPressed: _loading ? null : _save),
          ],
        ),
      ),
    );
  }
}

class AttendanceActionScreen extends StatelessWidget {
  const AttendanceActionScreen({super.key, this.showHeader = true});
  final bool showHeader;

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
            if (showHeader) ScreenHeader(title: 'Attendance', onBell: () => context.push(user.role == UserRole.manager ? '/mg/notifications' : '/emp/notifications')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: 188,
                      height: 188,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: open == null ? AppColors.primary : AppColors.success, width: 10),
                        gradient: RadialGradient(
                          colors: [
                            (open == null ? AppColors.primary : AppColors.success).withValues(alpha: 0.16),
                            open == null ? AppColors.wash : AppColors.successSoft,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (open == null ? AppColors.primary : AppColors.success).withValues(alpha: 0.22),
                            blurRadius: 28,
                            spreadRadius: 2,
                          ),
                        ],
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
                        _kv('Shop', app.branchName(user.branchId)),
                        Builder(builder: (_) {
                          final branch = app.branchById(user.branchId);
                          if (branch?.hasLocation != true) {
                            return _kv('Shop GPS', 'Not set — ask admin to pin on map');
                          }
                          return _kv(
                            'Shop GPS',
                            '${branch!.latitude!.toStringAsFixed(5)}, ${branch.longitude!.toStringAsFixed(5)} (±${branch.geofenceRadius.round()}m)',
                          );
                        }),
                        _kv('Status', open == null ? 'Not in' : attendanceLabel(open.status)),
                        if (open != null && open.checkInDistanceMeters != null)
                          _kv(
                            'Distance at check-in',
                            open.outsideGeofence
                                ? '${open.checkInDistanceMeters!.round()}m · OUT OF RANGE'
                                : '${open.checkInDistanceMeters!.round()}m · In range',
                          ),
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
              child: PeriodChips(
                value: period,
                showCustom: false,
                onChanged: (v) => setState(() => period = v),
              ),
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
                        final branch = app.branchById(a.branchId);
                        final dist = a.checkInDistanceMeters;
                        final rangeLabel = a.checkInLatitude == null
                            ? 'No GPS'
                            : a.outsideGeofence
                                ? 'Out of range${dist != null ? ' · ${dist.round()}m' : ''}'
                                : a.locationVerified
                                    ? 'In range${dist != null ? ' · ${dist.round()}m' : ''}'
                                    : 'Unverified';
                        final rangeColor = a.outsideGeofence
                            ? AppColors.danger
                            : a.locationVerified
                                ? AppColors.success
                                : AppColors.warning;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            onTap: (app.currentUser?.role == UserRole.superAdmin ||
                                    (app.currentUser?.role == UserRole.businessAdmin &&
                                        (app.currentUser!.isOwner || app.currentUser!.permissions.canCorrectAttendance)))
                                ? () => _correct(context, a)
                                : null,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
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
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    StatusBadge(label: rangeLabel, color: rangeColor),
                                    if (a.checkInLatitude != null)
                                      StatusBadge(
                                        label: '${a.checkInLatitude!.toStringAsFixed(5)}, ${a.checkInLongitude!.toStringAsFixed(5)}',
                                        color: AppColors.primary,
                                      ),
                                    if (a.checkInAccuracyMeters != null)
                                      StatusBadge(
                                        label: '±${a.checkInAccuracyMeters!.round()}m GPS',
                                        color: AppColors.muted,
                                      ),
                                    if (widget.team && branch?.hasLocation == true)
                                      StatusBadge(
                                        label: 'Shop ${branch!.geofenceRadius.round()}m',
                                        color: AppColors.teal,
                                      ),
                                  ],
                                ),
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
  const PeopleListScreen({super.key, required this.role, this.showHeader = true});
  final UserRole role;
  final bool showHeader;

  @override
  State<PeopleListScreen> createState() => _PeopleListScreenState();
}

class _PeopleListScreenState extends State<PeopleListScreen> {
  final _search = TextEditingController();
  String filter = 'All'; // All | Active | Inactive | Suspended

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final user = app.currentUser!;
    final title = widget.role == UserRole.manager ? 'Managers' : 'Staff';
    final subtitle = widget.role == UserRole.manager ? 'Manage your managers' : 'Manage your team members';
    final addLabel = widget.role == UserRole.manager ? 'Add Manager' : 'Add Employee';
    final addRoute = widget.role == UserRole.manager
        ? (user.role == UserRole.superAdmin ? '/sa/managers/add' : '/ba/managers/add')
        : (user.role == UserRole.manager ? '/mg/employees/add' : '/ba/employees/add');

    final allPeople = app.usersWhere(
      role: widget.role,
      businessId: user.role == UserRole.superAdmin ? null : user.businessId,
      branchId: user.role == UserRole.manager
          ? user.branchId
          : user.role == UserRole.superAdmin
              ? null
              : app.effectiveBranchId,
      query: _search.text,
    );

    final activeCount = allPeople.where((p) => p.status == EntityStatus.active).length;
    final inactiveCount = allPeople.where((p) => p.status == EntityStatus.inactive).length;
    final suspendedCount = allPeople.where((p) => p.status == EntityStatus.suspended).length;
    final inactiveStat = inactiveCount + suspendedCount;

    final people = allPeople.where((p) {
      if (filter == 'Active') return p.status == EntityStatus.active;
      if (filter == 'Inactive') return p.status == EntityStatus.inactive;
      if (filter == 'Suspended') return p.status == EntityStatus.suspended;
      return true;
    }).toList();

    final chipItems = [
      'All (${allPeople.length})',
      'Active ($activeCount)',
      'Inactive ($inactiveCount)',
      'Suspended ($suspendedCount)',
    ];
    final selectedChip = chipItems.firstWhere(
      (e) => e.startsWith(filter),
      orElse: () => chipItems.first,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
        children: [
          if (widget.showHeader) ...[
            ScreenHeader(title: title),
            const SizedBox(height: 4),
          ],
          Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w500, fontSize: 14)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SearchField(
                  controller: _search,
                  hint: widget.role == UserRole.manager ? 'Search managers...' : 'Search employees...',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              _PeopleFilterButton(
                active: filter != 'All',
                onTap: () => _openFilterSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: chipItems.map((label) {
                final selected = label == selectedChip;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        if (label.startsWith('All')) filter = 'All';
                        if (label.startsWith('Active')) filter = 'Active';
                        if (label.startsWith('Inactive')) filter = 'Inactive';
                        if (label.startsWith('Suspended')) filter = 'Suspended';
                      });
                    },
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.glassStrong,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    side: BorderSide(color: selected ? AppColors.primary : AppColors.borderGlow),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Row(
              children: [
                _PeopleStat(icon: Icons.groups_outlined, color: AppColors.purple, label: 'Total Staff', value: '${allPeople.length}'),
                _peopleStatDivider(),
                _PeopleStat(icon: Icons.check_circle_outline, color: AppColors.success, label: 'Active', value: '$activeCount'),
                _peopleStatDivider(),
                _PeopleStat(icon: Icons.pause_circle_outline, color: AppColors.primary, label: 'Inactive', value: '$inactiveStat'),
              ],
            ),
          ),
          if (app.canCreateRole(widget.role)) ...[
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: AppColors.orangeGlow,
              ),
              child: AppButton(
                label: addLabel,
                icon: Icons.add_rounded,
                onPressed: () => context.push(addRoute),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (people.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: EmptyView(title: 'No $title yet', subtitle: 'Create the first record to get started.'),
            )
          else
            ...List.generate(people.length, (i) {
              final p = people[i];
              final avatarColor = i.isEven ? AppColors.blue : AppColors.primary;
              final position = p.position ?? roleLabel(p.role);
              final branch = app.branchName(p.branchId);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  onTap: () => context.push('${_detailBase(user.role, widget.role)}/${p.id}'),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: avatarColor.withValues(alpha: 0.22),
                        child: Text(
                          Formatters.initials(p.fullName),
                          style: TextStyle(color: avatarColor, fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.fullName,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.work_outline_rounded, size: 13, color: AppColors.muted),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    position,
                                    style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 13, color: AppColors.muted),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    branch,
                                    style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _statusBadge(p.status),
                          const SizedBox(height: 10),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.placeholder),
                        ],
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

  Widget _peopleStatDivider() => Container(width: 1, height: 46, color: AppColors.border);

  Widget _statusBadge(EntityStatus status) {
    switch (status) {
      case EntityStatus.active:
        return const StatusBadge(label: 'Active', color: AppColors.success, soft: AppColors.successSoft);
      case EntityStatus.suspended:
        return const StatusBadge(label: 'Suspended', color: AppColors.warning, soft: AppColors.warningSoft);
      case EntityStatus.archived:
        return const StatusBadge(label: 'Archived', color: AppColors.muted, soft: AppColors.glassStrong);
      case EntityStatus.inactive:
        return const StatusBadge(label: 'Inactive', color: AppColors.muted, soft: AppColors.glassStrong);
    }
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
                const Text('Filter staff', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.text)),
                const SizedBox(height: 12),
                for (final option in ['All', 'Active', 'Inactive', 'Suspended'])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(option, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
                    trailing: filter == option ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                    onTap: () => Navigator.pop(ctx, option),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null && mounted) setState(() => filter = selected);
  }

  String _detailBase(UserRole actor, UserRole target) {
    if (actor == UserRole.superAdmin) {
      return target == UserRole.manager ? '/sa/managers' : '/sa/admins';
    }
    if (actor == UserRole.manager) return '/mg/employees';
    if (target == UserRole.manager) return '/ba/managers';
    return '/ba/employees';
  }
}

class _PeopleStat extends StatelessWidget {
  const _PeopleStat({required this.icon, required this.color, required this.label, required this.value});
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

class _PeopleFilterButton extends StatelessWidget {
  const _PeopleFilterButton({required this.onTap, this.active = false});
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
          child: Icon(Icons.tune_rounded, color: active ? AppColors.primary : AppColors.text),
        ),
      ),
    );
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
              initialValue: _branchId != null && app.visibleBranches().any((b) => b.id == _branchId) ? _branchId : null,
              decoration: const InputDecoration(labelText: 'Branch'),
              items: app.visibleBranches().map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
              validator: (v) => (v == null || v.isEmpty) ? 'Select a branch' : null,
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
                  final ok = await confirmAction(
                    context,
                    title: 'Reset password?',
                    message: 'A Firebase password-reset email will be sent to ${_existing!.email}.',
                  );
                  if (ok && context.mounted) {
                    final result = await app.resetAccess(_existing!.id, '');
                    if (context.mounted) {
                      final email = result.startsWith('EMAIL_SENT:') ? result.substring(11) : _existing!.email;
                      showToast(context, 'Reset email sent to $email');
                    }
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
  const NotificationsScreen({super.key, this.showHeader = true});
  final bool showHeader;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String tab = 'All'; // All | Unread
  String category = 'All'; // All | Orders | Sales | Expenses | Attendance | System

  bool _matchesCategory(AppNotification n) {
    switch (category) {
      case 'Orders':
        final text = '${n.title} ${n.message}'.toLowerCase();
        return text.contains('order');
      case 'Sales':
        return n.type == NotificationType.saleAdded;
      case 'Expenses':
        return n.type == NotificationType.expenseAdded;
      case 'Attendance':
        return n.type == NotificationType.employeeCheckin ||
            n.type == NotificationType.employeeCheckout ||
            n.type == NotificationType.managerCheckin ||
            n.type == NotificationType.managerCheckout;
      case 'System':
        return n.type == NotificationType.system ||
            n.type == NotificationType.passwordResetRequest ||
            n.type == NotificationType.branchTransfer ||
            n.type == NotificationType.userCreated ||
            n.type == NotificationType.businessCreated;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final canPop = Navigator.of(context).canPop();
    final all = app.myNotifications(unreadOnly: tab == 'Unread').where(_matchesCategory).toList();

    final categories = <(String, IconData)>[
      ('All', Icons.apps_rounded),
      ('Orders', Icons.shopping_cart_outlined),
      ('Sales', Icons.point_of_sale_rounded),
      ('Expenses', Icons.receipt_long_rounded),
      ('Attendance', Icons.event_available_rounded),
      ('System', Icons.notifications_none_rounded),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  if (canPop) ...[
                    _GlassRoundButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => context.pop(),
                    ),
                    const SizedBox(width: 12),
                  ],
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Notifications', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.text)),
                        SizedBox(height: 2),
                        Text(
                          'Stay updated with your business activity',
                          style: TextStyle(color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _NotifPill(
                    label: 'All',
                    selected: tab == 'All',
                    icon: Icons.check_rounded,
                    onTap: () => setState(() => tab = 'All'),
                  ),
                  const SizedBox(width: 8),
                  _NotifPill(
                    label: 'Unread',
                    selected: tab == 'Unread',
                    leading: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle),
                    ),
                    onTap: () => setState(() => tab = 'Unread'),
                  ),
                  const Spacer(),
                  _NotifPill(
                    label: 'Mark all read',
                    selected: false,
                    icon: Icons.done_all_rounded,
                    accentIcon: true,
                    onTap: app.markAllRead,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final item = categories[i];
                  final selected = category == item.$1;
                  return _CategoryIconButton(
                    icon: item.$2,
                    selected: selected,
                    onTap: () => setState(() => category = item.$1),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: all.isEmpty
                  ? const EmptyView(title: 'No notifications', subtitle: 'Operational alerts will appear here.')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                      itemCount: all.length,
                      itemBuilder: (context, i) {
                        final n = all[i];
                        final unread = !n.isRead;
                        final color = _nColor(n.type);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppCard(
                            onTap: () => _openNotification(app, n),
                            padding: const EdgeInsets.all(14),
                            border: Border.all(
                              color: unread ? AppColors.primary.withValues(alpha: 0.75) : AppColors.borderGlow,
                              width: unread ? 1.4 : 1,
                            ),
                            color: unread ? AppColors.primary.withValues(alpha: 0.08) : AppColors.glass,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SoftIconBox(icon: _nIcon(n.type), color: color, size: 44),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        n.title,
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        n.message,
                                        style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      Formatters.relative(n.createdAt),
                                      style: const TextStyle(fontSize: 11, color: AppColors.placeholder, fontWeight: FontWeight.w600),
                                    ),
                                    if (unread) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                          boxShadow: AppColors.orangeGlow,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
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

  String _nLabel(NotificationType t) {
    switch (t) {
      case NotificationType.saleAdded:
        return 'Sale';
      case NotificationType.expenseAdded:
        return 'Expense';
      case NotificationType.employeeCheckin:
      case NotificationType.managerCheckin:
        return 'Check in';
      case NotificationType.employeeCheckout:
      case NotificationType.managerCheckout:
        return 'Check out';
      case NotificationType.passwordResetRequest:
        return 'Password';
      case NotificationType.businessCreated:
        return 'Business';
      case NotificationType.userCreated:
        return 'User';
      case NotificationType.branchTransfer:
        return 'Branch';
      case NotificationType.system:
        return 'Update';
    }
  }

  Future<void> _openNotification(StaffProController app, AppNotification n) async {
    final color = _nColor(n.type);
    final business = app.businessName(n.businessId);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.navySoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SoftIconBox(icon: _nIcon(n.type), color: color, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_nLabel(n.type), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(n.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFFF4F7FB))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(n.message, style: const TextStyle(color: Color(0xFFE7EDF5), fontSize: 14, height: 1.4)),
              const SizedBox(height: 12),
              Text(Formatters.dateTime(n.createdAt), style: const TextStyle(color: Color(0xFFB7C2D0), fontSize: 12, fontWeight: FontWeight.w600)),
              if (business != '—') ...[
                const SizedBox(height: 4),
                Text(business, style: const TextStyle(color: Color(0xFFB7C2D0), fontSize: 12, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted && !n.isRead) await app.markNotificationRead(n.id);
  }

  IconData _nIcon(NotificationType t) {
    switch (t) {
      case NotificationType.saleAdded:
        return Icons.point_of_sale_rounded;
      case NotificationType.expenseAdded:
        return Icons.receipt_long_rounded;
      case NotificationType.employeeCheckin:
      case NotificationType.managerCheckin:
        return Icons.login_rounded;
      case NotificationType.employeeCheckout:
      case NotificationType.managerCheckout:
        return Icons.logout_rounded;
      case NotificationType.passwordResetRequest:
        return Icons.lock_reset_rounded;
      case NotificationType.businessCreated:
        return Icons.apartment_rounded;
      case NotificationType.userCreated:
        return Icons.person_add_alt_1_rounded;
      case NotificationType.branchTransfer:
        return Icons.swap_horiz_rounded;
      case NotificationType.system:
        return Icons.notifications_none_rounded;
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
      case NotificationType.employeeCheckout:
      case NotificationType.managerCheckout:
        return AppColors.blue;
      case NotificationType.passwordResetRequest:
        return AppColors.warning;
      case NotificationType.businessCreated:
      case NotificationType.userCreated:
      case NotificationType.branchTransfer:
        return AppColors.purple;
      case NotificationType.system:
        return AppColors.info;
    }
  }
}

class _GlassRoundButton extends StatelessWidget {
  const _GlassRoundButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.glassStrong,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderGlow),
          ),
          child: Icon(icon, size: 18, color: AppColors.text),
        ),
      ),
    );
  }
}

class _NotifPill extends StatelessWidget {
  const _NotifPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.leading,
    this.accentIcon = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? leading;
  final bool accentIcon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.glassStrong,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: selected ? AppColors.primary : AppColors.borderGlow),
            boxShadow: selected ? AppColors.orangeGlow : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 6)],
              if (icon != null) ...[
                Icon(icon, size: 15, color: selected ? Colors.white : (accentIcon ? AppColors.primary : AppColors.text)),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryIconButton extends StatelessWidget {
  const _CategoryIconButton({required this.icon, required this.selected, required this.onTap});
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : AppColors.glassStrong,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.borderGlow,
              width: selected ? 1.4 : 1,
            ),
            boxShadow: selected ? AppColors.orangeGlow : null,
          ),
          child: Icon(icon, color: selected ? AppColors.primary : AppColors.text, size: 22),
        ),
      ),
    );
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

class ReportsHubScreen extends StatefulWidget {
  const ReportsHubScreen({super.key, this.platform = false, this.showHeader = true});
  final bool platform;
  final bool showHeader;

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
    final span = range.end.difference(range.start);
    final prevPeriod = PeriodFilter(
      from: range.start.subtract(span + const Duration(days: 1)),
      to: range.start,
      label: 'Previous',
    );
    final biz = app.currentUser?.businessId;
    final branch = widget.platform ? null : app.effectiveBranchId;
    final sales = app.salesTotal(businessId: widget.platform ? null : biz, branchId: branch, period: period);
    final expenses = app.expensesTotal(businessId: widget.platform ? null : biz, branchId: branch, period: period);
    final prevSales = app.salesTotal(businessId: widget.platform ? null : biz, branchId: branch, period: prevPeriod);
    final prevExpenses = app.expensesTotal(businessId: widget.platform ? null : biz, branchId: branch, period: prevPeriod);
    final salesUp = sales >= prevSales;
    final expensesUp = expenses >= prevExpenses;

    final reportItems = <_ReportMenuItem>[
      if (!widget.platform)
        _ReportMenuItem(
          title: 'Daily P&L Report',
          subtitle: 'Day-wise sale, expenses, remaining & profit',
          icon: Icons.bar_chart_rounded,
          color: AppColors.primary,
          onTap: () {
            final role = app.currentUser?.role;
            final path = role == UserRole.manager ? '/mg/reports/daily' : '/ba/reports/daily';
            context.push(path);
          },
        ),
      _ReportMenuItem(
        title: 'Sales Report',
        subtitle: 'Detailed sales with filters and breakdown',
        icon: Icons.point_of_sale_rounded,
        color: AppColors.blue,
        onTap: () => _open(context, 'sales', period, prevPeriod),
      ),
      _ReportMenuItem(
        title: 'Expense Report',
        subtitle: 'All expenses by category and period',
        icon: Icons.receipt_long_rounded,
        color: AppColors.danger,
        onTap: () => _open(context, 'expenses', period, prevPeriod),
      ),
      _ReportMenuItem(
        title: 'Attendance Report',
        subtitle: 'Staff attendance, hours and status',
        icon: Icons.event_available_rounded,
        color: AppColors.success,
        onTap: () => _open(context, 'attendance', period, prevPeriod),
      ),
      if (!widget.platform)
        _ReportMenuItem(
          title: 'Branch Comparison',
          subtitle: 'Compare sales, expenses and profit across branches',
          icon: Icons.account_tree_outlined,
          color: AppColors.purple,
          onTap: () => _open(context, 'branches', period, prevPeriod),
        ),
      if (widget.platform)
        _ReportMenuItem(
          title: 'Business Overview',
          subtitle: 'Compare sales across businesses',
          icon: Icons.apartment_outlined,
          color: AppColors.purple,
          onTap: () => _open(context, 'businesses', period, prevPeriod),
        ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
        children: [
          if (widget.showHeader) ...[
            const ScreenHeader(title: 'Reports'),
            const SizedBox(height: 4),
          ],
          const Text('Reports', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text)),
          const SizedBox(height: 4),
          const Text(
            'Analyze performance & business insights',
            style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w500, fontSize: 14),
          ),
          const SizedBox(height: 16),
          AppCard(
            onTap: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDateRange: range,
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: AppColors.primary,
                        onPrimary: Colors.white,
                        surface: AppColors.navySoft,
                        onSurface: AppColors.text,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) setState(() => range = picked);
            },
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                SoftIconBox(icon: Icons.calendar_month_rounded, color: AppColors.primary, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${DateFormat('dd MMM yyyy').format(range.start)}  —  ${DateFormat('dd MMM yyyy').format(range.end)}',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text, fontSize: 14),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.muted),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ReportSummaryCard(
                  label: 'Total Sales',
                  value: Formatters.money(sales),
                  trend: Formatters.trend(sales, prevSales),
                  trendUp: salesUp,
                  icon: Icons.trending_up_rounded,
                  accent: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ReportSummaryCard(
                  label: 'Total Expenses',
                  value: Formatters.money(expenses),
                  trend: Formatters.trend(expenses, prevExpenses),
                  trendUp: expensesUp,
                  icon: Icons.trending_down_rounded,
                  accent: AppColors.danger,
                  forceTrendColor: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...reportItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                onTap: item.onTap,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    SoftIconBox(icon: item.icon, color: item.color, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text)),
                          const SizedBox(height: 4),
                          Text(item.subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.placeholder),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          AppButton(
            label: 'Export CSV',
            outlined: true,
            icon: Icons.ios_share_rounded,
            onPressed: () => _export(app, period),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, String type, PeriodFilter period, PeriodFilter previous) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReportDetailSheet(type: type, period: period, previous: previous),
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

class _ReportMenuItem {
  const _ReportMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _ReportSummaryCard extends StatelessWidget {
  const _ReportSummaryCard({
    required this.label,
    required this.value,
    required this.trend,
    required this.trendUp,
    required this.icon,
    required this.accent,
    this.forceTrendColor,
  });

  final String label;
  final String value;
  final String trend;
  final bool trendUp;
  final IconData icon;
  final Color accent;
  final Color? forceTrendColor;

  @override
  Widget build(BuildContext context) {
    final trendColor = forceTrendColor ?? (trendUp ? AppColors.success : AppColors.danger);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600))),
              SoftIconBox(icon: icon, color: accent, size: 34),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.text)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(trendUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 14, color: trendColor),
              const SizedBox(width: 2),
              Text(trend, style: TextStyle(color: trendColor, fontWeight: FontWeight.w800, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportDetailSheet extends StatefulWidget {
  const _ReportDetailSheet({required this.type, required this.period, required this.previous});

  final String type;
  final PeriodFilter period;
  final PeriodFilter previous;

  @override
  State<_ReportDetailSheet> createState() => _ReportDetailSheetState();
}

class _ReportDetailSheetState extends State<_ReportDetailSheet> {
  final _search = TextEditingController();
  String _filter = 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final meta = _meta(widget.type);
    final rows = _rows(app).where((row) {
      final query = _search.text.trim().toLowerCase();
      final matchesQuery = query.isEmpty || row.cells.any((cell) => cell.toLowerCase().contains(query));
      final matchesFilter = _filter == 'All' || row.badge == _filter;
      return matchesQuery && matchesFilter;
    }).toList();
    final filters = ['All', ...{for (final row in _rows(app)) row.badge}];
    final current = _total(app, widget.period);
    final previous = _total(app, widget.previous);
    final up = current >= previous;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 72),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xFF101A2C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 42, height: 4, decoration: BoxDecoration(color: AppColors.navyMuted, borderRadius: BorderRadius.circular(4))),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 0),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: meta.color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
                    child: Icon(meta.icon, color: meta.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(meta.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.text)),
                        const SizedBox(height: 2),
                        Text(meta.subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: AppColors.muted)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(colors: [meta.color.withValues(alpha: 0.22), meta.color.withValues(alpha: 0.06)]),
                  border: Border.all(color: meta.color.withValues(alpha: 0.28)),
                ),
                child: Row(
                  children: [
                    _stat(meta.totalLabel, meta.money ? Formatters.money(current) : _hours(current), meta.color),
                    _stat(switch (widget.type) { 'branches' => 'Branches', 'businesses' => 'Businesses', 'attendance' => 'Records', _ => 'Transactions' }, '${_rows(app).length}', AppColors.info),
                    _stat('vs previous period', Formatters.trend(current, previous), up ? AppColors.success : AppColors.danger, trend: up),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: AppColors.text),
                      decoration: InputDecoration(
                        hintText: meta.searchHint,
                        hintStyle: const TextStyle(color: AppColors.placeholder),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
                        filled: true,
                        fillColor: AppColors.navySoft,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    initialValue: _filter,
                    onSelected: (value) => setState(() => _filter = value),
                    color: AppColors.navySoft,
                    itemBuilder: (context) => filters.map((item) => PopupMenuItem(value: item, child: Text(item))).toList(),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: AppColors.navySoft, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.tune_rounded, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tableWidth = constraints.maxWidth > meta.tableWidth ? constraints.maxWidth : meta.tableWidth;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      height: constraints.maxHeight,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                            child: Row(
                              children: [
                                _col('#', 36),
                                for (final column in meta.columns) _col(column.label, column.width),
                              ],
                            ),
                          ),
                          Expanded(
                            child: rows.isEmpty
                                ? const Center(child: Text('No records in this period', style: TextStyle(color: AppColors.muted)))
                                : ListView.builder(
                                    padding: EdgeInsets.fromLTRB(18, 0, 18, 16 + bottom),
                                    itemCount: rows.length,
                                    itemBuilder: (context, index) {
                                      final row = rows[index];
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: AppColors.navySoft,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 36,
                                              child: Text((index + 1).toString().padLeft(2, '0'), style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                                            ),
                                            for (var i = 0; i < row.cells.length; i++)
                                              SizedBox(
                                                width: meta.columns[i].width,
                                                child: i == row.badgeAt
                                                    ? Align(
                                                        alignment: Alignment.centerLeft,
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                          decoration: BoxDecoration(color: row.color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
                                                          child: Text(row.cells[i], style: TextStyle(color: row.color, fontWeight: FontWeight.w700, fontSize: 12)),
                                                        ),
                                                      )
                                                    : Text(
                                                        row.cells[i],
                                                        style: TextStyle(
                                                          color: i == 0 ? AppColors.text : AppColors.muted,
                                                          fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w600,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
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

  List<_ReportRow> _rows(StaffProController app) {
    switch (widget.type) {
      case 'expenses':
        final items = [...app.visibleExpenses(period: widget.period)]..sort((a, b) => b.date.compareTo(a.date));
        return items
            .map((item) => _ReportRow([
                  Formatters.money(item.amount),
                  item.categoryName.isEmpty ? 'Other' : item.categoryName,
                  app.userName(item.userId),
                  app.branchName(item.branchId),
                  item.paymentMethod,
                  Formatters.dateTime(item.date),
                ], 1, _badgeColor(item.categoryName)))
            .toList();
      case 'attendance':
        final items = [...app.visibleAttendance(period: widget.period)]..sort((a, b) => b.checkInAt.compareTo(a.checkInAt));
        return items
            .map((item) => _ReportRow([
                  app.userName(item.userId),
                  attendanceLabel(item.status),
                  Formatters.dateTime(item.checkInAt),
                  item.checkOutAt == null ? 'Not checked out' : Formatters.dateTime(item.checkOutAt!),
                  Formatters.duration(item.workedMinutes),
                ], 1, attendanceColor(item.status)))
            .toList();
      case 'branches':
        final items = [...app.visibleBranches()]..sort((a, b) => a.name.compareTo(b.name));
        return items.map((branch) {
          final sales = app.salesTotal(businessId: branch.businessId, branchId: branch.id, period: widget.period);
          final profit = sales - app.expensesTotal(businessId: branch.businessId, branchId: branch.id, period: widget.period);
          return _ReportRow([
            branch.name,
            Formatters.money(sales),
            Formatters.money(app.expensesTotal(businessId: branch.businessId, branchId: branch.id, period: widget.period)),
            Formatters.money(profit),
          ], 3, profit >= 0 ? AppColors.success : AppColors.danger);
        }).toList();
      case 'businesses':
        final items = [...app.db.businesses]..sort((a, b) => a.name.compareTo(b.name));
        return items.map((business) {
          final sales = app.salesTotal(businessId: business.id, period: widget.period);
          return _ReportRow([business.name, Formatters.money(sales)], 1, AppColors.purple);
        }).toList();
      default:
        final items = [...app.visibleSales(period: widget.period)]..sort((a, b) => b.date.compareTo(a.date));
        return items
            .map((item) => _ReportRow([
                  Formatters.money(item.amount),
                  item.category,
                  app.userName(item.userId),
                  app.branchName(item.branchId),
                  item.paymentMethod,
                  Formatters.dateTime(item.date),
                ], 1, _badgeColor(item.category)))
            .toList();
    }
  }

  double _total(StaffProController app, PeriodFilter period) {
    switch (widget.type) {
      case 'expenses':
        return app.expensesTotal(period: period);
      case 'attendance':
        return app.visibleAttendance(period: period).fold<int>(0, (sum, item) => sum + (item.workedMinutes ?? 0)).toDouble();
      case 'branches':
        return app.visibleBranches().fold<double>(0, (sum, branch) => sum + app.salesTotal(businessId: branch.businessId, branchId: branch.id, period: period));
      case 'businesses':
        return app.db.businesses.fold<double>(0, (sum, business) => sum + app.salesTotal(businessId: business.id, period: period));
      default:
        return app.salesTotal(period: period);
    }
  }

  _SheetMeta _meta(String type) {
    switch (type) {
      case 'expenses':
        return const _SheetMeta('Expenses Report', 'All business expenses entries', Icons.receipt_long_rounded, AppColors.danger, 'Search expenses...', 'Total Expenses', true, [
          _SheetCol('Amount', 110),
          _SheetCol('Category', 110),
          _SheetCol('Added by', 140),
          _SheetCol('Branch', 130),
          _SheetCol('Payment', 90),
          _SheetCol('Date & Time', 176),
        ]);
      case 'attendance':
        return const _SheetMeta('Attendance Report', 'Staff attendance, hours and status', Icons.event_available_rounded, AppColors.success, 'Search attendance...', 'Hours worked', false, [
          _SheetCol('Staff', 140),
          _SheetCol('Status', 120),
          _SheetCol('Check in', 176),
          _SheetCol('Check out', 176),
          _SheetCol('Hours', 72),
        ]);
      case 'branches':
        return const _SheetMeta('Branch Comparison', 'Sales and profit across branches', Icons.account_tree_outlined, AppColors.purple, 'Search branches...', 'Total Sales', true, [
          _SheetCol('Branch', 150),
          _SheetCol('Sales', 120),
          _SheetCol('Expenses', 120),
          _SheetCol('Profit', 120),
        ]);
      case 'businesses':
        return const _SheetMeta('Business Overview', 'Compare sales across businesses', Icons.apartment_outlined, AppColors.purple, 'Search businesses...', 'Total Sales', true, [
          _SheetCol('Business', 180),
          _SheetCol('Sales', 130),
        ]);
      default:
        return const _SheetMeta('Sales Report', 'Branch-wise retail sales entries', Icons.point_of_sale_rounded, AppColors.success, 'Search sales...', 'Total Sales', true, [
          _SheetCol('Amount', 110),
          _SheetCol('Type', 110),
          _SheetCol('Added by', 140),
          _SheetCol('Branch', 130),
          _SheetCol('Payment', 90),
          _SheetCol('Date & Time', 176),
        ]);
    }
  }

  static String _hours(double minutes) {
    final total = minutes.round();
    final hours = total ~/ 60;
    final mins = total % 60;
    return '${hours}h ${mins.toString().padLeft(2, '0')}m';
  }

  static Color _badgeColor(String label) {
    switch (label.toLowerCase()) {
      case 'retail':
        return AppColors.success;
      case 'supplies':
        return AppColors.blue;
      case 'food':
        return AppColors.warning;
      case 'other':
        return AppColors.purple;
      default:
        return AppColors.info;
    }
  }

  Widget _stat(String label, String value, Color color, {bool? trend}) {
    return Expanded(
      child: Column(
        children: [
          Icon(trend == null ? Icons.layers_rounded : (trend ? Icons.trending_up_rounded : Icons.trending_down_rounded), color: color, size: 18),
          const SizedBox(height: 6),
          Text(value, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _col(String label, double width) {
    return SizedBox(width: width, child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w700)));
  }
}

class _SheetCol {
  const _SheetCol(this.label, this.width);
  final String label;
  final double width;
}

class _SheetMeta {
  const _SheetMeta(this.title, this.subtitle, this.icon, this.color, this.searchHint, this.totalLabel, this.money, this.columns);

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String searchHint;
  final String totalLabel;
  final bool money;
  final List<_SheetCol> columns;

  double get tableWidth => 36 + columns.fold<double>(0, (sum, column) => sum + column.width) + 36;
}

class _ReportRow {
  const _ReportRow(this.cells, this.badgeAt, this.color);

  final List<String> cells;
  final int badgeAt;
  final Color color;

  String get badge => cells[badgeAt];
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

/// Inbox for managers / business admins to approve password recovery requests.
class PasswordRequestsScreen extends StatelessWidget {
  const PasswordRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final pending = app.pendingPasswordRequests();
    return Scaffold(
      appBar: AppBar(title: const Text('Password Requests')),
      body: pending.isEmpty
          ? const EmptyView(title: 'No pending requests', subtitle: 'Employee recovery requests will appear here.')
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: pending.length,
              itemBuilder: (context, i) {
                final req = pending[i];
                AppUser? user;
                try {
                  user = app.db.users.firstWhere((u) => u.id == req.userId);
                } catch (_) {
                  user = null;
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.fullName ?? req.email, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(req.email, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                        if (req.message.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(req.message),
                        ],
                        Text(Formatters.relative(req.createdAt), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                label: 'Reject',
                                outlined: true,
                                onPressed: () async {
                                  try {
                                    await app.rejectPasswordRequest(req.id);
                                    if (context.mounted) showToast(context, 'Request rejected');
                                  } catch (e) {
                                    if (context.mounted) showToast(context, e.toString(), error: true);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AppButton(
                                label: 'Reset password',
                                onPressed: () async {
                                  final ok = await confirmAction(
                                    context,
                                    title: 'Reset password?',
                                    message:
                                        'Send a Firebase password-reset email to ${user?.fullName ?? req.email} (${req.email})?',
                                    confirmLabel: 'Send email',
                                  );
                                  if (!ok || !context.mounted) return;
                                  try {
                                    final result = await app.resetAccess(req.userId, '');
                                    if (context.mounted) {
                                      final email =
                                          result.startsWith('EMAIL_SENT:') ? result.substring(11) : req.email;
                                      showToast(context, 'Reset email sent to $email');
                                    }
                                  } catch (e) {
                                    if (context.mounted) showToast(context, e.toString(), error: true);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isSuper = context.watch<StaffProController>().currentUser?.role == UserRole.superAdmin;
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'StaffPro helps businesses manage branches, staff, sales, expenses and attendance.\n\n'
          'Super Admin creates businesses.\nBusiness Admin manages branches and people.\nManagers operate a single assigned branch.\nEmployees record sales, expenses and attendance.\n\n'
          'Pin each branch on the map so attendance can verify staff are in range.\n'
          '${isSuper ? 'Change the Super Admin secret registration code anytime in Settings.' : 'Contact your Super Admin if you need a new admin account.'}',
          style: const TextStyle(height: 1.5),
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
            BrandLogo(size: 120),
            SizedBox(height: 12),
            Text('Employee Management App'),
            SizedBox(height: 6),
            Text('Version 1.0.0', style: TextStyle(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
