import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:staffpro/core/theme/app_colors.dart';
import 'package:staffpro/core/utils/formatters.dart';
import 'package:staffpro/core/widgets/ui_kit.dart';
import 'package:staffpro/state/app_state.dart';

class _CustomerRow {
  _CustomerRow({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.guest,
  });

  final String id;
  String name;
  String email;
  String phone;
  bool guest;
  int orders = 0;
  double spent = 0;
  int points = 0;
  int lifetimePoints = 0;
  DateTime? lastOrder;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> history = [];
}

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key, required this.detailPrefix});

  final String detailPrefix;

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _search = TextEditingController();
  String _kind = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final businessId = app.currentUser?.businessId;
    if (businessId == null || businessId.isEmpty) {
      return const Scaffold(body: EmptyView(title: 'No business selected'));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: app.db.watchCustomerOrders(businessId),
        builder: (context, ordersSnap) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: app.db.watchLoyaltyAccounts(businessId),
            builder: (context, loyaltySnap) {
              if (ordersSnap.hasError || loyaltySnap.hasError) {
                return const EmptyView(title: 'Customers could not be loaded');
              }
              if (!ordersSnap.hasData || !loyaltySnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final rows = _mergeCustomers(ordersSnap.data!.docs, loyaltySnap.data!.docs);
              final query = _search.text.trim().toLowerCase();
              final visible = rows.where((row) {
                if (_kind == 'account' && row.guest) return false;
                if (_kind == 'guest' && !row.guest) return false;
                if (query.isEmpty) return true;
                return row.name.toLowerCase().contains(query) ||
                    row.email.toLowerCase().contains(query) ||
                    row.phone.toLowerCase().contains(query);
              }).toList();
              final points = rows.fold<int>(0, (total, row) => total + row.points);
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        _Stat(label: 'Customers', value: '${rows.length}'),
                        const SizedBox(width: 8),
                        _Stat(label: 'Accounts', value: '${rows.where((row) => !row.guest).length}'),
                        const SizedBox(width: 8),
                        _Stat(label: 'Points held', value: '$points'),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search name, email or phone',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: Row(
                      children: [
                        _FilterChip(label: 'All', selected: _kind == 'all', onTap: () => setState(() => _kind = 'all')),
                        const SizedBox(width: 8),
                        _FilterChip(label: 'Accounts', selected: _kind == 'account', onTap: () => setState(() => _kind = 'account')),
                        const SizedBox(width: 8),
                        _FilterChip(label: 'Guests', selected: _kind == 'guest', onTap: () => setState(() => _kind = 'guest')),
                      ],
                    ),
                  ),
                  Expanded(
                    child: visible.isEmpty
                        ? EmptyView(
                            title: rows.isEmpty ? 'No customers yet' : 'No customers match',
                            subtitle: rows.isEmpty ? 'People who order from the public menu show up here.' : null,
                            icon: Icons.people_outline,
                          )
                        : Scrollbar(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  showCheckboxColumn: false,
                                  headingRowColor: WidgetStateProperty.all(AppColors.wash),
                                  columns: const [
                                    DataColumn(label: Text('Name')),
                                    DataColumn(label: Text('Email')),
                                    DataColumn(label: Text('Phone')),
                                    DataColumn(label: Text('Type')),
                                    DataColumn(label: Text('Orders'), numeric: true),
                                    DataColumn(label: Text('Spent'), numeric: true),
                                    DataColumn(label: Text('Points'), numeric: true),
                                    DataColumn(label: Text('Last order')),
                                  ],
                                  rows: [
                                    for (final row in visible)
                                      DataRow(
                                        onSelectChanged: (_) => context.push('${widget.detailPrefix}/${row.id}'),
                                        cells: [
                                          DataCell(Text(row.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                                          DataCell(Text(row.email.isEmpty ? '—' : row.email)),
                                          DataCell(Text(row.phone.isEmpty ? '—' : row.phone)),
                                          DataCell(Text(row.guest ? 'Guest' : 'Account')),
                                          DataCell(Text('${row.orders}')),
                                          DataCell(Text(Formatters.money(row.spent))),
                                          DataCell(Text('${row.points}')),
                                          DataCell(Text(row.lastOrder == null ? '—' : Formatters.dateTime(row.lastOrder!))),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

}

List<_CustomerRow> _mergeCustomers(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> orders,
  List<QueryDocumentSnapshot<Map<String, dynamic>>> accounts,
) {
    final byId = <String, _CustomerRow>{};
    for (final doc in orders) {
      final data = doc.data();
      final id = data['customerUid']?.toString() ?? '';
      if (id.isEmpty) continue;
      final row = byId.putIfAbsent(
        id,
        () => _CustomerRow(
          id: id,
          name: data['customerName']?.toString() ?? 'Customer',
          email: data['customerEmail']?.toString() ?? '',
          phone: data['phone']?.toString() ?? '',
          guest: data['customerKind'] == 'guest',
        ),
      );
      final name = data['customerName']?.toString() ?? '';
      final email = data['customerEmail']?.toString() ?? '';
      final phone = data['phone']?.toString() ?? '';
      if (name.isNotEmpty) row.name = name;
      if (email.isNotEmpty) row.email = email;
      if (phone.isNotEmpty) row.phone = phone;
      if (data['customerKind'] == 'account') row.guest = false;
      row.orders += 1;
      row.history.add(doc);
      final status = data['orderStatus']?.toString() ?? '';
      if (status != 'CANCELLED' && status != 'PAYMENT_REJECTED') {
        row.spent += (data['total'] as num?)?.toDouble() ?? 0;
      }
      final at = _time(data['createdAt']);
      if (at != null && (row.lastOrder == null || at.isAfter(row.lastOrder!))) row.lastOrder = at;
    }
    for (final doc in accounts) {
      final data = doc.data();
      final id = data['customerId']?.toString() ?? '';
      if (id.isEmpty) continue;
      final row = byId.putIfAbsent(
        id,
        () => _CustomerRow(id: id, name: 'Customer', email: '', phone: '', guest: false),
      );
      row.guest = false;
      row.points = (data['pointsBalance'] as num?)?.toInt() ?? 0;
      row.lifetimePoints = (data['lifetimePoints'] as num?)?.toInt() ?? 0;
    }
    final list = byId.values.toList()
      ..sort((a, b) => (b.lastOrder ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(a.lastOrder ?? DateTime.fromMillisecondsSinceEpoch(0)));
    return list;
}

class CustomerDetailScreen extends StatelessWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final businessId = app.currentUser?.businessId;
    if (businessId == null || businessId.isEmpty) {
      return const Scaffold(body: EmptyView(title: 'No business selected'));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Customer')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: app.db.watchCustomerOrders(businessId),
        builder: (context, ordersSnap) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: app.db.watchLoyaltyAccounts(businessId),
            builder: (context, loyaltySnap) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: app.db.watchLoyaltyTransactions(businessId, customerId),
                builder: (context, txnSnap) {
                  if (!ordersSnap.hasData || !loyaltySnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final rows = _mergeCustomers(ordersSnap.data!.docs, loyaltySnap.data!.docs);
                  _CustomerRow? row;
                  for (final item in rows) {
                    if (item.id == customerId) row = item;
                  }
                  if (row == null) {
                    return const EmptyView(title: 'Customer not found', subtitle: 'They have no orders or points for this business.');
                  }
                  final orders = row.history.toList()
                    ..sort((a, b) => _time(b.data()['createdAt'])?.compareTo(_time(a.data()['createdAt']) ?? DateTime(0)) ?? 0);
                  final txns = txnSnap.data?.docs.toList() ?? [];
                  txns.sort((a, b) => _time(b.data()['createdAt'])?.compareTo(_time(a.data()['createdAt']) ?? DateTime(0)) ?? 0);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      AppCard(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: AppColors.washStrong,
                              child: Text(
                                row.name.isEmpty ? '?' : row.name[0].toUpperCase(),
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(row.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy)),
                                  const SizedBox(height: 2),
                                  Text(row.email.isEmpty ? 'No email' : row.email, style: const TextStyle(color: AppColors.muted)),
                                  Text(row.phone.isEmpty ? 'No phone' : row.phone, style: const TextStyle(color: AppColors.muted)),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: row.guest ? AppColors.warningSoft : AppColors.successSoft,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      row.guest ? 'Guest' : 'Account',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: row.guest ? AppColors.orange : AppColors.success,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _Stat(label: 'Orders', value: '${row.orders}'),
                          const SizedBox(width: 8),
                          _Stat(label: 'Spent', value: Formatters.money(row.spent)),
                          const SizedBox(width: 8),
                          _Stat(label: 'Points', value: '${row.points}'),
                        ],
                      ),
                      if (!row.guest)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('Lifetime points earned: ${row.lifetimePoints}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                        ),
                      const SizedBox(height: 18),
                      const Text('Points history', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navy)),
                      const SizedBox(height: 8),
                      if (row.guest)
                        const Text('Guests do not earn points.', style: TextStyle(color: AppColors.muted))
                      else if (!txnSnap.hasData && !txnSnap.hasError)
                        const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator())
                      else
                        _PointsHistory(transactions: txns, orders: orders),
                      const SizedBox(height: 18),
                      const Text('Order history', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navy)),
                      const SizedBox(height: 8),
                      if (orders.isEmpty)
                        const Text('No orders yet.', style: TextStyle(color: AppColors.muted))
                      else
                        for (final doc in orders) ...[
                          _OrderTile(id: doc.id, data: doc.data()),
                          const SizedBox(height: 8),
                        ],
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _PointsHistory extends StatelessWidget {
  const _PointsHistory({required this.transactions, required this.orders});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> transactions;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> orders;

  @override
  Widget build(BuildContext context) {
    final rows = transactions.isNotEmpty
        ? [
            for (final doc in transactions) doc.data(),
          ]
        : _fromOrders(orders);
    if (rows.isEmpty) {
      return const Text('No points activity yet.', style: TextStyle(color: AppColors.muted));
    }
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 16),
            _TxnTile(data: rows[i]),
          ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _fromOrders(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final rows = <Map<String, dynamic>>[];
    for (final doc in docs) {
      final data = doc.data();
      final status = data['orderStatus']?.toString() ?? '';
      final earned = (data['loyaltyPointsEarned'] as num?)?.toInt() ?? 0;
      final redeemed = (data['pointsRedeemed'] as num?)?.toInt() ?? 0;
      final number = data['orderNumber'] ?? doc.id;
      final when = data['createdAt'];
      if (redeemed > 0) {
        rows.add({
          'description': 'Redeemed on order $number',
          'type': 'REDEEM',
          'orderNumber': number,
          'points': -redeemed,
          'createdAt': when,
        });
      }
      if (earned > 0 && status == 'COMPLETED') {
        rows.add({
          'description': 'Earned on order $number',
          'type': 'EARN',
          'orderNumber': number,
          'points': earned,
          'createdAt': when,
        });
      }
      if (earned > 0 && (status == 'CANCELLED' || status == 'PAYMENT_REJECTED')) {
        rows.add({
          'description': 'Reversed earn for order $number',
          'type': 'REVERSAL',
          'orderNumber': number,
          'points': -earned,
          'createdAt': when,
        });
      }
    }
    return rows;
  }
}

class _TxnTile extends StatelessWidget {
  const _TxnTile({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final points = (data['points'] as num?)?.toInt() ?? 0;
    final when = _time(data['createdAt']);
    final positive = points >= 0;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['description']?.toString() ?? data['type']?.toString() ?? 'Points', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                '${data['type'] ?? ''} · order ${data['orderNumber'] ?? ''}${when == null ? '' : ' · ${Formatters.dateTime(when)}'}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        Text(
          '${positive ? '+' : ''}$points',
          style: TextStyle(fontWeight: FontWeight.w800, color: positive ? AppColors.success : AppColors.danger),
        ),
      ],
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.id, required this.data});
  final String id;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final when = _time(data['createdAt']);
    final items = (data['items'] as List?) ?? const [];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Order ${data['orderNumber'] ?? id}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy)),
              ),
              Text(Formatters.money((data['total'] as num?) ?? 0), style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_label(data['orderStatus']?.toString() ?? '')} · ${_label(data['orderType']?.toString() ?? '')}${when == null ? '' : ' · ${Formatters.dateTime(when)}'}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          if ((data['pointsRedeemed'] as num?) != null && (data['pointsRedeemed'] as num) > 0)
            Text('Redeemed ${data['pointsRedeemed']} pts', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          if ((data['loyaltyPointsEarned'] as num?) != null && (data['loyaltyPointsEarned'] as num) > 0)
            Text('Earned ${data['loyaltyPointsEarned']} pts', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 8),
          for (final raw in items)
            if (raw is Map)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '${raw['quantity'] ?? 1} × ${raw['name'] ?? 'Item'}${raw['variantName'] == null || '${raw['variantName']}'.isEmpty ? '' : ' (${raw['variantName']})'}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            const SizedBox(height: 2),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy)),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.navy, fontWeight: FontWeight.w700, fontSize: 12)),
      ),
    );
  }
}

String _label(String raw) {
  if (raw.isEmpty) return '';
  final spaced = raw.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}').replaceAll('_', ' ');
  return spaced[0].toUpperCase() + spaced.substring(1).toLowerCase();
}

DateTime? _time(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}
