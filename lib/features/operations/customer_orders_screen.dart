import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:staffpro/core/theme/app_colors.dart';
import 'package:staffpro/core/utils/formatters.dart';
import 'package:staffpro/core/widgets/ui_kit.dart';
import 'package:staffpro/state/app_state.dart';

class _StatusTab {
  const _StatusTab(this.label, this.orderStatus, {this.codOnly = false, this.prepaidOnly = false});
  final String label;
  final String? orderStatus;
  final bool codOnly;
  final bool prepaidOnly;
}

const _tabs = [
  _StatusTab('All', null),
  _StatusTab('Pending', 'PENDING_PAYMENT_VERIFICATION', codOnly: true),
  _StatusTab('To be verified', 'PENDING_PAYMENT_VERIFICATION', prepaidOnly: true),
  _StatusTab('Rejected', 'PAYMENT_REJECTED'),
  _StatusTab('Accepted', 'ACCEPTED'),
  _StatusTab('Preparing', 'PREPARING'),
  _StatusTab('Ready', 'READY'),
  _StatusTab('Completed', 'COMPLETED'),
  _StatusTab('Cancelled', 'CANCELLED'),
];

List<_StatusTab> _actionsFor(String? method) {
  final cod = method == 'cod';
  return [
    if (cod) const _StatusTab('Pending', 'PENDING_PAYMENT_VERIFICATION'),
    if (!cod) const _StatusTab('To be verified', 'PENDING_PAYMENT_VERIFICATION'),
    if (!cod) const _StatusTab('Rejected', 'PAYMENT_REJECTED'),
    const _StatusTab('Accepted', 'ACCEPTED'),
    const _StatusTab('Preparing', 'PREPARING'),
    const _StatusTab('Ready', 'READY'),
    const _StatusTab('Completed', 'COMPLETED'),
    const _StatusTab('Cancel', 'CANCELLED'),
  ];
}

bool _tabMatches(String? tab, Map<String, dynamic> data) {
  if (tab == null || tab == 'All') return true;
  final match = _tabs.where((item) => item.label == tab).firstOrNull;
  if (match == null) return data['orderStatus'] == tab;
  if (data['orderStatus'] != match.orderStatus) return false;
  final cod = data['paymentMethod'] == 'cod';
  if (match.codOnly) return cod;
  if (match.prepaidOnly) return !cod;
  return true;
}

class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  String? _filter;
  final _search = TextEditingController();

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
      appBar: AppBar(
        title: const Text('Customer orders'),
        actions: [
          IconButton(
            tooltip: 'Order feedback',
            onPressed: () {
              final path = GoRouterState.of(context).uri.path;
              final prefix = path.startsWith('/mg') ? '/mg' : path.startsWith('/emp') ? '/emp' : '/ba';
              context.push('$prefix/feedback');
            },
            icon: const Icon(Icons.reviews_outlined),
          ),
        ],
      ),
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
          final query = _search.text.trim().toLowerCase();
          final visible = docs.where((doc) {
            if (_filter != null && !_tabMatches(_filter, doc.data())) return false;
            if (query.isEmpty) return true;
            final data = doc.data();
            final orderNumber = data['orderNumber']?.toString().toLowerCase() ?? '';
            final name = data['customerName']?.toString().toLowerCase() ?? '';
            final phone = data['phone']?.toString().toLowerCase() ?? '';
            final reference = data['paymentReference']?.toString().toLowerCase() ?? '';
            return orderNumber.contains(query) ||
                name.contains(query) ||
                phone.contains(query) ||
                reference.contains(query) ||
                doc.id.toLowerCase().contains(query);
          }).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SearchField(
                  controller: _search,
                  hint: 'Search by order, name, phone, reference',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: _tabs.map((tab) {
                    final selected = _filter == tab.label;
                    final count = docs.where((doc) => _tabMatches(tab.label == 'All' ? null : tab.label, doc.data())).length;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${tab.label} ($count)'),
                        selected: selected,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(color: selected ? Colors.white : AppColors.text, fontWeight: FontWeight.w700),
                        onSelected: (_) => setState(() => _filter = tab.label == 'All' ? null : tab.label),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? EmptyView(title: query.isEmpty ? 'No orders in this tab' : 'No orders match this search')
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: visible.map((doc) => _OrderSummaryCard(id: doc.id, data: doc.data())).toList(),
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

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.id, required this.data});
  final String id;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final items = (data['items'] as List?) ?? [];
    final summary = items.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final flavors = ((map['flavors'] as List?) ?? [])
          .map((flavor) => Map<String, dynamic>.from(flavor as Map)['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .join(' + ');
      return '${map['quantity']} × ${map['name']}${flavors.isEmpty ? '' : ' ($flavors)'}';
    }).join(', ');
    final comments = (data['staffComments'] as List?) ?? [];
    final status = _statusLabel(data['orderStatus']?.toString(), data['paymentMethod']?.toString());
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CustomerOrderDetailScreen(orderId: id),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order ${data['orderNumber'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ],
            ),
            const SizedBox(height: 4),
            Text('${data['customerName'] ?? ''} · ${data['phone'] ?? ''}', style: const TextStyle(color: AppColors.text)),
            Text(
              '${data['orderType'] == 'dineIn' ? 'Dine-in' : 'Takeaway'} · ${_paymentMethodLabel(data['paymentMethod'])} · $status',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 6),
            Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  Formatters.money((data['total'] as num?)?.toDouble() ?? 0),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.text),
                ),
                const Spacer(),
                if (comments.isNotEmpty)
                  Text(
                    '${comments.length} comment${comments.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap to open full details',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomerOrderDetailScreen extends StatefulWidget {
  const CustomerOrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  State<CustomerOrderDetailScreen> createState() => _CustomerOrderDetailScreenState();
}

class _CustomerOrderDetailScreenState extends State<CustomerOrderDetailScreen> {
  final _comment = TextEditingController();
  bool _savingComment = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<StaffProController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Order details')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: app.db.watchCustomerOrder(widget.orderId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const EmptyView(title: 'Order could not be loaded');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final doc = snapshot.data!;
          if (!doc.exists || doc.data() == null) {
            return const EmptyView(title: 'Order not found');
          }
          final data = doc.data()!;
          final items = (data['items'] as List?) ?? [];
          final comments = ((data['staffComments'] as List?) ?? [])
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList()
            ..sort((a, b) => _commentMillis(b['createdAt']).compareTo(_commentMillis(a['createdAt'])));
          final proofUrl = data['paymentProofUrl']?.toString() ?? '';
          final current = data['orderStatus']?.toString();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order ${data['orderNumber'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                    ),
                    const SizedBox(height: 4),
                    Text('Status: ${_statusLabel(current, data['paymentMethod']?.toString())}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('Payment: ${_statusLabel(data['paymentStatus']?.toString())}'),
                    Text(_formatCreatedAt(data['createdAt'])),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Customer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text('${data['customerName'] ?? ''}'),
                    Text('${data['phone'] ?? ''}'),
                    if ((data['customerEmail']?.toString() ?? '').isNotEmpty) Text(data['customerEmail'].toString()),
                    const SizedBox(height: 8),
                    Text(data['orderType'] == 'dineIn' ? 'Dine-in' : 'Takeaway'),
                    if (data['orderType'] == 'dineIn')
                      Text(
                        data['dineInPickup'] == true
                            ? 'Collect from the shop with the order number'
                            : 'Seat: ${data['seatingNote'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    if ((data['orderNotes']?.toString() ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Customer notes: ${data['orderNotes']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Items', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 8),
                    ...items.map((raw) {
                      final item = Map<String, dynamic>.from(raw as Map);
                      final addons = ((item['addons'] as List?) ?? [])
                          .map((addon) => Map<String, dynamic>.from(addon as Map)['name']?.toString() ?? '')
                          .where((name) => name.isNotEmpty)
                          .join(', ');
                      final flavors = ((item['flavors'] as List?) ?? [])
                          .map((flavor) => Map<String, dynamic>.from(flavor as Map)['name']?.toString() ?? '')
                          .where((name) => name.isNotEmpty)
                          .join(', ');
                      final extras = [
                        if ((item['variantName']?.toString() ?? '').isNotEmpty) item['variantName'].toString(),
                        if (flavors.isNotEmpty) flavors,
                        if (addons.isNotEmpty) addons,
                      ].join(' · ');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item['quantity'] ?? 0} × ${item['name'] ?? ''}',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  if (extras.isNotEmpty)
                                    Text(extras, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                                ],
                              ),
                            ),
                            Text(
                              Formatters.money((item['lineTotal'] as num?)?.toDouble() ??
                                  ((item['unitPrice'] as num?)?.toDouble() ?? 0) * ((item['quantity'] as num?)?.toDouble() ?? 1)),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 20),
                    _moneyRow('Subtotal', (data['subtotal'] as num?)?.toDouble() ?? 0),
                    if (((data['loyaltyDiscount'] as num?)?.toDouble() ?? 0) > 0)
                      _moneyRow('Loyalty', -((data['loyaltyDiscount'] as num?)?.toDouble() ?? 0)),
                    _moneyRow('Total', (data['total'] as num?)?.toDouble() ?? 0, bold: true),
                    if (((data['pointsRedeemed'] as num?)?.toInt() ?? 0) > 0)
                      Text('Loyalty redeemed: ${data['pointsRedeemed']} points'),
                    if (((data['loyaltyPointsEarned'] as num?)?.toInt() ?? 0) > 0)
                      Text('Loyalty earned: ${data['loyaltyPointsEarned']} points'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Payment', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(_paymentMethodLabel(data['paymentMethod'])),
                    if ((data['paymentReference']?.toString() ?? '').isNotEmpty)
                      Text('Reference: ${data['paymentReference']}'),
                    if (proofUrl.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text('Payment screenshot · tap to view full size', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _openFullImage(context, proofUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 220,
                            width: double.infinity,
                            child: ColoredBox(
                              color: const Color(0xFFF3F1EC),
                              child: _paymentProofImage(proofUrl),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Update status', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _actionsFor(data['paymentMethod']?.toString()).map((action) {
                        final selected = current == action.orderStatus;
                        return ChoiceChip(
                          label: Text(action.label),
                          selected: selected,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : AppColors.text,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) => _setStatus(context, action.orderStatus!),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Staff comments', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 4),
                    const Text(
                      'Pass notes to kitchen or other staff on this order.',
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _comment,
                      minLines: 2,
                      maxLines: 4,
                      style: const TextStyle(color: AppColors.navy),
                      cursorColor: AppColors.navy,
                      decoration: InputDecoration(
                        hintText: 'Write a comment to pass…',
                        filled: true,
                        fillColor: const Color(0xFFF7F5F1),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _savingComment ? null : () => _addComment(context),
                        icon: _savingComment
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded),
                        label: Text(_savingComment ? 'Saving…' : 'Pass comment'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (comments.isEmpty)
                      const Text('No comments yet.', style: TextStyle(color: AppColors.muted))
                    else
                      ...comments.map((comment) {
                        final created = DateTime.tryParse(comment['createdAt']?.toString() ?? '');
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F5F1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                comment['text']?.toString() ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${comment['authorName'] ?? 'Staff'}${created == null ? '' : ' · ${Formatters.dateTime(created)}'}',
                                style: const TextStyle(color: AppColors.muted, fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addComment(BuildContext context) async {
    final text = _comment.text.trim();
    if (text.isEmpty) {
      showToast(context, 'Write a comment first.', error: true);
      return;
    }
    final user = context.read<StaffProController>().currentUser;
    if (user == null) return;
    setState(() => _savingComment = true);
    try {
      await context.read<StaffProController>().db.addCustomerOrderComment(
            orderId: widget.orderId,
            text: text,
            authorId: user.id,
            authorName: user.fullName,
          );
      _comment.clear();
      if (context.mounted) showToast(context, 'Comment passed to this order');
    } catch (error) {
      if (context.mounted) showToast(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _savingComment = false);
    }
  }

  Future<void> _setStatus(BuildContext context, String orderStatus) async {
    final paymentStatus = switch (orderStatus) {
      'PENDING_PAYMENT_VERIFICATION' => 'PENDING_PAYMENT_VERIFICATION',
      'PAYMENT_REJECTED' => 'PAYMENT_REJECTED',
      'CANCELLED' => 'CANCELLED',
      'ACCEPTED' || 'PREPARING' || 'READY' || 'COMPLETED' => 'PAYMENT_VERIFIED',
      _ => null,
    };
    try {
      await context.read<StaffProController>().db.updateCustomerOrder(
            widget.orderId,
            paymentStatus: paymentStatus,
            orderStatus: orderStatus,
          );
    } catch (error) {
      if (context.mounted) showToast(context, error.toString(), error: true);
    }
  }
}

Widget _moneyRow(String label, double value, {bool bold = false}) {
  final style = TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500);
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(Formatters.money(value), style: style),
      ],
    ),
  );
}

String _paymentMethodLabel(Object? method) {
  return method == 'cod' ? 'Cash on delivery' : 'Prepaid';
}

String _statusLabel(String? status, [String? paymentMethod]) {
  return switch (status) {
    'PENDING_PAYMENT_VERIFICATION' => paymentMethod == 'cod' ? 'Pending' : 'Waiting for payment check',
    'PAYMENT_VERIFIED' => 'Payment verified',
    'PAYMENT_REJECTED' => 'Payment rejected',
    'ACCEPTED' => 'Accepted',
    'PREPARING' => 'Preparing',
    'READY' => 'Ready',
    'COMPLETED' => 'Completed',
    'CANCELLED' => 'Cancelled',
    _ => status?.isNotEmpty == true ? status! : 'Unknown',
  };
}

String _formatCreatedAt(dynamic value) {
  if (value is Timestamp) return Formatters.dateTime(value.toDate());
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  return parsed == null ? 'Created just now' : Formatters.dateTime(parsed);
}

int _commentMillis(dynamic value) {
  if (value is Timestamp) return value.millisecondsSinceEpoch;
  return DateTime.tryParse(value?.toString() ?? '')?.millisecondsSinceEpoch ?? 0;
}

void _openFullImage(BuildContext context, String url) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    builder: (dialogContext) {
      return Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5,
                child: _paymentProofImage(url, fit: BoxFit.contain),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _paymentProofImage(String url, {BoxFit fit = BoxFit.contain}) {
  const fallback = ColoredBox(
    color: Color(0xFFE8E4DE),
    child: Center(child: Icon(Icons.receipt_long_outlined)),
  );
  if (url.startsWith('data:image')) {
    final comma = url.indexOf(',');
    if (comma < 0) return fallback;
    try {
      return Image.memory(
        base64Decode(url.substring(comma + 1)),
        fit: fit,
        errorBuilder: (_, _, _) => fallback,
      );
    } catch (_) {
      return fallback;
    }
  }
  if (url.startsWith('http')) {
    return Image.network(url, fit: fit, errorBuilder: (_, _, _) => fallback);
  }
  return fallback;
}
