import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:staffpro/core/theme/app_colors.dart';
import 'package:staffpro/core/widgets/ui_kit.dart';
import 'package:staffpro/state/app_state.dart';

class OrderFeedbackScreen extends StatefulWidget {
  const OrderFeedbackScreen({super.key});

  @override
  State<OrderFeedbackScreen> createState() => _OrderFeedbackScreenState();
}

class _OrderFeedbackScreenState extends State<OrderFeedbackScreen> {
  String _filter = 'all';
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
      appBar: AppBar(title: const Text('Order feedback')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: app.db.watchOrderFeedback(businessId),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const EmptyView(title: 'Feedback could not be loaded');
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs.toList()
            ..sort((a, b) => _millis(b.data()['updatedAt'] ?? b.data()['createdAt']).compareTo(_millis(a.data()['updatedAt'] ?? a.data()['createdAt'])));
          final query = _search.text.trim().toLowerCase();
          final visible = docs.where((doc) {
            final data = doc.data();
            if (_filter == 'new' && data['status'] != 'new') return false;
            if (_filter == 'reviewed' && data['status'] != 'reviewed') return false;
            if (query.isEmpty) return true;
            final haystack = '${data['orderNumber'] ?? ''} ${data['customerName'] ?? ''} ${data['comment'] ?? ''}'.toLowerCase();
            return haystack.contains(query);
          }).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SearchField(controller: _search, hint: 'Search order, name, or comment', onChanged: (_) => setState(() {})),
              ),
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    for (final item in const [('all', 'All'), ('new', 'New'), ('reviewed', 'Reviewed')])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(item.$2),
                          selected: _filter == item.$1,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(color: _filter == item.$1 ? Colors.white : AppColors.text, fontWeight: FontWeight.w700),
                          onSelected: (_) => setState(() => _filter = item.$1),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? const EmptyView(title: 'No feedback in this view')
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: visible.map((doc) => _FeedbackCard(id: doc.id, data: doc.data())).toList(),
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

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.id, required this.data});
  final String id;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final rating = (data['rating'] as num?)?.toInt() ?? 0;
    final reviewed = data['status'] == 'reviewed';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order ${data['orderNumber'] ?? id}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            Text(data['customerName']?.toString() ?? 'Customer'),
            Text('${'★' * rating}${'☆' * (5 - rating)}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
            if ((data['comment']?.toString() ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(data['comment'].toString()),
            ],
            const SizedBox(height: 8),
            Text(reviewed ? 'Reviewed' : 'New', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.read<StaffProController>().db.reviewOrderFeedback(id, reviewed ? 'new' : 'reviewed'),
                child: Text(reviewed ? 'Hide from website' : 'Show on website'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
