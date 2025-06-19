import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DailySettledOrdersPage extends StatelessWidget {
  const DailySettledOrdersPage({super.key});

  Stream<QuerySnapshot> _settledOrdersStream() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return FirebaseFirestore.instance
        .collection('orders')
        .where('isSettled', isEqualTo: true)
        .where('settledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('settledAt', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('settledAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('本日の会計済み注文一覧')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _settledOrdersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('本日会計済みの注文はありません'));
          }

          final orders = snapshot.data!.docs;

          // userId ごとにグループ化
          final Map<String, List<DocumentSnapshot>> ordersByUser = {};
          for (final doc in orders) {
            final data = doc.data() as Map<String, dynamic>;
            final userId = data['userId'] ?? 'unknown';
            ordersByUser.putIfAbsent(userId, () => []).add(doc);
          }

          return ListView(
            children: ordersByUser.entries.map((entry) {
              final userOrders = entry.value;
              final firstOrder = userOrders.first.data() as Map<String, dynamic>;
              final userName = firstOrder['userName'] ?? '名無し';
              final settledBy = firstOrder['settledBy'] ?? '名無し';
              final settledAt = (firstOrder['settledAt'] as Timestamp?)?.toDate();

              final totalAmount = userOrders.fold<num>(
                0,
                    (sum, doc) => sum + ((doc.data() as Map<String, dynamic>)['totalPrice'] ?? 0),
              );

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('顧客: $userName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('会計スタッフ: $settledBy',style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      if (settledAt != null)
                        Text('会計時間: ${settledAt.toLocal()}'.split('.').first),
                      const SizedBox(height: 8),
                      ...userOrders.expand((doc) {
                        final menuItems = (doc.data() as Map<String, dynamic>)['menuItems'] as List<dynamic>? ?? [];
                        return menuItems.map((item) {
                          final name = item['name'] ?? '商品名不明';
                          final quantity = item['quantity'] ?? 1;
                          final price = item['price'] ?? 0;
                          final total = price * quantity;
                          return Text('・$name × $quantity = ¥$total');
                        });
                      }),
                      const SizedBox(height: 8),
                      Text('合計金額: ¥$totalAmount', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
