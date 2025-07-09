import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:poker_first/orderingSystem/dailySettledOrders.dart';

class UnsettledOrdersPage extends StatelessWidget {
  const UnsettledOrdersPage({super.key});

  Stream<QuerySnapshot> _unsettledOrdersStream() {
    return FirebaseFirestore.instance
        .collection('orders')
        .where('isSettled', isEqualTo: false)
        .orderBy('orderingAt', descending: true)
        .snapshots();
  }

  Future<String> _getCurrentUserName() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return '不明なユーザー';

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    return userDoc.data()?['pokerName'] ?? '不明なユーザー';
  }

  void _confirmSettlement(
      BuildContext context,
      String userId,
      List<DocumentSnapshot> userOrders,
      ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('会計を確定しますか？'),
        content: const Text('この操作は取り消せません。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('確定')),
        ],
      ),
    );

    if (confirm == true) {
      final settledBy = await _getCurrentUserName();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in userOrders) {
        batch.update(doc.reference, {
          'isSettled': true,
          'settledAt': Timestamp.now(),
          'settledBy': settledBy,
        });
      }
      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('会計を確定しました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('未会計の注文一覧'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: '会計済み一覧',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DailySettledOrdersPage()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _unsettledOrdersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('未会計の注文はありません'));
          }

          final orders = snapshot.data!.docs;

          final Map<String, List<DocumentSnapshot>> ordersByUser = {};
          for (final doc in orders) {
            final data = doc.data() as Map<String, dynamic>;
            final userId = data['userId'] ?? 'unknown';
            ordersByUser.putIfAbsent(userId, () => []).add(doc);
          }

          return ListView(
            children: ordersByUser.entries.map((entry) {
              final userOrders = entry.value;
              final userName = userOrders.first.data() is Map
                  ? (userOrders.first.data() as Map)['userName'] ?? '名無し'
                  : '名無し';
              final totalAmount = userOrders.fold<num>(
                0,
                    (sum, doc) => sum + ((doc.data() as Map)['totalPrice'] ?? 0),
              );

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('顧客: $userName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...userOrders.expand((doc) {
                        final menuItems = (doc.data() as Map)['menuItems'] as List<dynamic>? ?? [];
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
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: () => _confirmSettlement(context, entry.key, userOrders),
                          child: const Text('会計する'),
                        ),
                      ),
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
