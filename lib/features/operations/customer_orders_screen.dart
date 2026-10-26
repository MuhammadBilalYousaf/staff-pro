import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:staffpro/core/theme/app_colors.dart';
import 'package:staffpro/core/utils/formatters.dart';
import 'package:staffpro/core/widgets/ui_kit.dart';
import 'package:staffpro/state/app_state.dart';

class _StatusTab {
  const _StatusTab(this.label, this.orderStatus);
  final String label;
  final String? orderStatus;
}

const _tabs = [
  _StatusTab('All', null),
  _StatusTab('To be verified', 'PENDING_PAYMENT_VERIFICATION'),
  _StatusTab('Rejected', 'PAYMENT_REJECTED'),
  _StatusTab('Accepted', 'ACCEPTED'),
  _StatusTab('Preparing', 'PREPARING'),
  _StatusTab('Ready', 'READY'),
  _StatusTab('Completed', 'COMPLETED'),
];

const _actions = [
  _StatusTab('To be verified', 'PENDING_PAYMENT_VERIFICATION'),
  _StatusTab('Rejected', 'PAYMENT_REJECTED'),
  _StatusTab('Accepted', 'ACCEPTED'),
  _StatusTab('Preparing', 'PREPARING'),
  _StatusTab('Ready', 'READY'),
  _StatusTab('Completed', 'COMPLETED'),
];

class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  String? _filter;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    final businessId = app.currentUser?.businessId;
    if (businessId == null || businessId.isEmpty) {
      return const Scaffold(body: EmptyView(title: 'No business selected'));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Customer orders')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: app.db.watchCustomerOrders(businessId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const EmptyView(title: 'Orders could not be loaded');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs.toList()
            ..sort((a, b) => _millis(b.data()['createdAt']).compareTo(_millis(a.data()['createdAt'])));
          final visible = docs.where((doc) {
            if (_filter == null) return true;
            return doc.data()['orderStatus'] == _filter;
          }).toList();
          return Column(
            children: [
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: _tabs.map((tab) {
                    final selected = _filter == tab.orderStatus;
                    final count = tab.orderStatus == null
                        ? docs.length
                        : docs.where((doc) => doc.data()['orderStatus'] == tab.orderStatus).length;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${tab.label} ($count)'),
                        selected: selected,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(color: selected ? Colors.white : AppColors.navy, fontWeight: FontWeight.w700),
                        onSelected: (_) => setState(() => _filter = tab.orderStatus),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? const EmptyView(title: 'No orders in this tab')
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: visible.map((doc) => _OrderCard(id: doc.id, data: doc.data())).toList(),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  int _millis(dynamic value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    return DateTime.tryParse(value?.toString() ?? '')?.millisecondsSinceEpoch ?? 0;
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.id, required this.data});
  final String id;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final items = (data['items'] as List?) ?? [];
    final summary = items.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return '${map['quantity']} × ${map['name']}';
    }).join(', ');
    final current = data['orderStatus']?.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order ${data['orderNumber'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            Text('${data['customerName'] ?? ''} · ${data['phone'] ?? ''}'),
            Text(data['orderType'] == 'dineIn' ? 'Dine-in' : 'Takeaway', style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 6),
            Text(summary),
            const SizedBox(height: 6),
            Text(Formatters.money((data['total'] as num?)?.toDouble() ?? 0), style: const TextStyle(fontWeight: FontWeight.w800)),
            Text('Reference: ${data['paymentReference'] ?? ''}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _actions.map((action) {
                final selected = current == action.orderStatus;
                return ChoiceChip(
                  label: Text(action.label),
                  selected: selected,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(color: selected ? Colors.white : AppColors.navy, fontWeight: FontWeight.w600),
                  onSelected: (_) => _setStatus(context, action.orderStatus!),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setStatus(BuildContext context, String orderStatus) async {
    final paymentStatus = switch (orderStatus) {
      'PENDING_PAYMENT_VERIFICATION' => 'PENDING_PAYMENT_VERIFICATION',
      'PAYMENT_REJECTED' => 'PAYMENT_REJECTED',
      'ACCEPTED' || 'PREPARING' || 'READY' || 'COMPLETED' => 'PAYMENT_VERIFIED',
      _ => null,
    };
    try {
      await context.read<StaffProController>().db.updateCustomerOrder(
            id,
            paymentStatus: paymentStatus,
            orderStatus: orderStatus,
          );
    } catch (error) {
      if (context.mounted) showToast(context, error.toString(), error: true);
    }
  }
}
