import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:staffpro/core/theme/app_colors.dart';
import 'package:staffpro/core/utils/formatters.dart';
import 'package:staffpro/core/widgets/ui_kit.dart';
import 'package:staffpro/features/shells/app_shell.dart';
import 'package:staffpro/models/enums.dart';
import 'package:staffpro/state/app_state.dart';

class CashScreen extends StatelessWidget {
  const CashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final user = app.currentUser!;
    final isAdmin = user.role == UserRole.businessAdmin;
    final branchId = isAdmin ? app.effectiveBranchId : user.branchId;
    final businessId = user.businessId;
    final month = PeriodFilter.month();
    final periodLabel =
        '${DateFormat('dd MMM').format(month.from)} – ${DateFormat('dd MMM yyyy').format(DateTime.now())}';

    if (isAdmin) {
      final accounts = app.monthAccounts(businessId: businessId, branchId: branchId);
      final staff = app.staffAccountsBreakdown(businessId: businessId, branchId: branchId);
      return Scaffold(
        appBar: AppBar(title: const Text('Accounts & Cash')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const BranchSelectorBar(),
            const SizedBox(height: 8),
            AppCard(
              color: AppColors.wash,
              child: Text(
                'This month ($periodLabel). Figures reset on the 1st of every month.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            _AccountsOverview(accounts: accounts),
            const SizedBox(height: 18),
            const Text('By staff', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            const Text(
              'Each person’s month-to-date cash, card, online, and total after their expenses.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (staff.isEmpty)
              const EmptyView(title: 'No staff activity yet', subtitle: 'Sales and expenses this month will show here per person.')
            else
              ...staff.map((row) => _StaffAccountsCard(row: row, branchName: app.branchName(row.user.branchId))),
            const SizedBox(height: 8),
            AppCard(
              color: AppColors.wash,
              child: Row(
                children: [
                  const Expanded(child: Text('Business total (should have)', style: TextStyle(fontWeight: FontWeight.w800))),
                  Text(Formatters.money(accounts.totalBalance), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final accounts = app.monthAccounts(userId: user.id, branchId: user.branchId, businessId: user.businessId);
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts & Cash')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            color: AppColors.wash,
            child: Text(
              'Your month-to-date ($periodLabel). Resets on the 1st of every month.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          _AccountsOverview(accounts: accounts),
        ],
      ),
    );
  }
}

class _AccountsOverview extends StatelessWidget {
  const _AccountsOverview({required this.accounts});
  final AccountsSummary accounts;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        KpiCard(
          label: 'Total sales (this month)',
          value: Formatters.money(accounts.sales),
          icon: Icons.trending_up,
          iconColor: AppColors.success,
        ),
        const SizedBox(height: 10),
        KpiCard(
          label: 'Total expenses (this month)',
          value: Formatters.money(accounts.expenses),
          icon: Icons.trending_down,
          iconColor: AppColors.danger,
        ),
        const SizedBox(height: 10),
        KpiCard(
          label: 'Cash in hand',
          value: Formatters.money(accounts.cashInHand),
          icon: Icons.payments_outlined,
          iconColor: AppColors.primary,
        ),
        const SizedBox(height: 10),
        KpiCard(
          label: 'Card balance',
          value: Formatters.money(accounts.cardBalance),
          icon: Icons.credit_card,
          iconColor: AppColors.teal,
        ),
        const SizedBox(height: 10),
        KpiCard(
          label: 'Online / bank balance',
          value: Formatters.money(accounts.onlineBalance),
          icon: Icons.account_balance_outlined,
          iconColor: AppColors.orange,
        ),
        const SizedBox(height: 10),
        KpiCard(
          label: 'Total you should have',
          value: Formatters.money(accounts.totalBalance),
          icon: Icons.savings_outlined,
          iconColor: accounts.totalBalance >= 0 ? AppColors.success : AppColors.danger,
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('How it is calculated', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'Cash in hand = cash sales − cash expenses\n'
                'Card = card sales − card expenses\n'
                'Online / bank = bank transfer & other non-cash sales − matching expenses\n'
                'Total you should have = all sales − all expenses\n\n'
                'Cash sales: ${Formatters.money(accounts.cashSales)} · Cash expenses: ${Formatters.money(accounts.cashExpenses)}\n'
                'Card sales: ${Formatters.money(accounts.cardSales)} · Card expenses: ${Formatters.money(accounts.cardExpenses)}\n'
                'Online sales: ${Formatters.money(accounts.onlineSales)} · Online expenses: ${Formatters.money(accounts.onlineExpenses)}',
                style: const TextStyle(color: AppColors.muted, height: 1.45, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StaffAccountsCard extends StatelessWidget {
  const _StaffAccountsCard({required this.row, required this.branchName});
  final StaffAccountsRow row;
  final String branchName;

  @override
  Widget build(BuildContext context) {
    final role = switch (row.user.role) {
      UserRole.manager => 'Manager',
      UserRole.employee => 'Employee',
      UserRole.businessAdmin => 'Admin',
      _ => row.user.role.name,
    };
    final a = row.accounts;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: AppColors.wash, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.person_outline, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.user.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('$role · $branchName', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    ],
                  ),
                ),
                Text(
                  Formatters.money(a.totalBalance),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: a.totalBalance >= 0 ? AppColors.success : AppColors.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('Sales', a.sales),
                _chip('Cash', a.cashInHand),
                _chip('Card', a.cardBalance),
                _chip('Online', a.onlineBalance),
                _chip('Expenses', a.expenses),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.wash,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label ${Formatters.money(value)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class DailyPnLReportScreen extends StatefulWidget {
  const DailyPnLReportScreen({super.key});

  @override
  State<DailyPnLReportScreen> createState() => _DailyPnLReportScreenState();
}

class _DailyPnLReportScreenState extends State<DailyPnLReportScreen> {
  DateTimeRange range = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final period = PeriodFilter(from: range.start, to: range.end.add(const Duration(days: 1)), label: 'Custom');
    final biz = app.currentUser?.businessId;
    final branch = app.currentUser?.role == UserRole.superAdmin ? null : app.effectiveBranchId;
    final rows = app.dailyPnLRows(businessId: biz, branchId: branch, period: period);
    final totalSales = rows.fold<double>(0, (p, e) => p + e.sales);
    final totalExpenses = rows.fold<double>(0, (p, e) => p + e.expenses);
    final totalRemaining = totalSales - totalExpenses;
    final profit = totalRemaining;

    return Scaffold(
      appBar: AppBar(title: const Text('Daily P&L Report')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (app.currentUser?.role == UserRole.businessAdmin) ...[
            const BranchSelectorBar(),
            const SizedBox(height: 8),
          ],
          AppCard(
            onTap: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDateRange: range,
              );
              if (picked != null) setState(() => range = picked);
            },
            child: Row(
              children: [
                const Icon(Icons.date_range, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${DateFormat('dd MMM yyyy').format(range.start)}  →  ${DateFormat('dd MMM yyyy').format(range.end)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.edit_calendar_outlined, color: AppColors.muted),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: KpiCard(label: 'Total sales', value: Formatters.money(totalSales), icon: Icons.trending_up, iconColor: AppColors.success)),
              const SizedBox(width: 10),
              Expanded(child: KpiCard(label: 'Profit', value: Formatters.money(profit), icon: Icons.savings_outlined, iconColor: profit >= 0 ? AppColors.success : AppColors.danger)),
            ],
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: MediaQuery.sizeOf(context).width - 32),
                child: DataTable(
                  headingRowColor: const WidgetStatePropertyAll(AppColors.wash),
                  columns: const [
                    DataColumn(label: Text('Day', style: TextStyle(fontWeight: FontWeight.w800))),
                    DataColumn(label: Text('Sale', style: TextStyle(fontWeight: FontWeight.w800)), numeric: true),
                    DataColumn(label: Text('Expenses', style: TextStyle(fontWeight: FontWeight.w800)), numeric: true),
                    DataColumn(label: Text('Remaining', style: TextStyle(fontWeight: FontWeight.w800)), numeric: true),
                  ],
                  rows: [
                    if (rows.isEmpty)
                      const DataRow(cells: [
                        DataCell(Text('No rows in this range')),
                        DataCell(Text('—')),
                        DataCell(Text('—')),
                        DataCell(Text('—')),
                      ])
                    else
                      ...rows.map((row) {
                        return DataRow(cells: [
                          DataCell(Text(DateFormat('dd MMM yyyy').format(row.day))),
                          DataCell(Text(Formatters.money(row.sales))),
                          DataCell(Text(Formatters.money(row.expenses))),
                          DataCell(Text(
                            Formatters.money(row.remaining),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: row.remaining >= 0 ? AppColors.success : AppColors.danger,
                            ),
                          )),
                        ]);
                      }),
                    DataRow(
                      color: WidgetStatePropertyAll(AppColors.primary.withValues(alpha: 0.08)),
                      cells: [
                        const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w900))),
                        DataCell(Text(Formatters.money(totalSales), style: const TextStyle(fontWeight: FontWeight.w800))),
                        DataCell(Text(Formatters.money(totalExpenses), style: const TextStyle(fontWeight: FontWeight.w800))),
                        DataCell(Text(Formatters.money(totalRemaining), style: const TextStyle(fontWeight: FontWeight.w800))),
                      ],
                    ),
                    DataRow(
                      color: const WidgetStatePropertyAll(AppColors.successSoft),
                      cells: [
                        const DataCell(Text('PROFIT', style: TextStyle(fontWeight: FontWeight.w900))),
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                        DataCell(Text(
                          Formatters.money(profit),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: profit >= 0 ? AppColors.success : AppColors.danger,
                          ),
                        )),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Remaining = Sale − Expenses for that day. Profit = total sales − total expenses.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
