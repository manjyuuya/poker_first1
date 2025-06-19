import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:poker_first/orderingSystem/menuItemEntry.dart';
import 'package:poker_first/orderingSystem/menuItemList.dart';

class OrderEntryPage extends StatefulWidget {
  final String userId;
  final String userName;

  const OrderEntryPage({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<OrderEntryPage> createState() => _OrderEntryPageState();
}

class _OrderEntryPageState extends State<OrderEntryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _selectedItems = [];

  Future<List<QueryDocumentSnapshot>> _fetchMenuItems() async {
    final snapshot = await _firestore.collection('menuItems')
        .where('isAvailable', isEqualTo: true).get();
    return snapshot.docs;
  }

  void _addItem(Map<String, dynamic> item) {
    setState(() {
      _selectedItems.add({...item, 'quantity': 1});
    });
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      _selectedItems[index]['quantity'] += delta;
      if (_selectedItems[index]['quantity'] <= 0) {
        _selectedItems.removeAt(index);
      }
    });
  }

  void _submitOrder() async {
    if (_selectedItems.isEmpty) return;

    final totalPrice = _selectedItems.fold<double>(
      0.0,
          (sum, item) => sum + (item['price'] as num) * (item['quantity'] as num),
    );

    await _firestore.collection('orders').add({
      'menuItems': _selectedItems,
      'totalPrice': totalPrice,
      'timestamp': FieldValue.serverTimestamp(),
      'userId': widget.userId,
      'userName': widget.userName,
      'isSettled': false,
    });

    setState(() {
      _selectedItems.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('注文を記録しました')),
      );
    }
  }

  void _showItemDetailDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item['name'] ?? '商品名不明'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item['imageUrl'] != null)
              Image.network(item['imageUrl'], height: 120),
            const SizedBox(height: 10),
            Text('価格: ¥${item['price']}'),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('閉じる'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('注文登録'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: '商品登録',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) =>  MenuItemEntryPage()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.list),
              tooltip: '商品一覧',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MenuItemListPage()),
                );
              },
            ),
          ],
        ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
          ),
          Expanded(
            child: FutureBuilder<List<QueryDocumentSnapshot>>(
              future: _fetchMenuItems(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final menuItems = snapshot.data!;
                return ListView(
                  children: menuItems.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return ListTile(
                      leading: data['imageUrl'] != null
                          ? Image.network(data['imageUrl'], width: 40, height: 40, fit: BoxFit.cover)
                          : const Icon(Icons.image_not_supported),
                      title: Text(data['name']),
                      subtitle: Text('¥${data['price']}'),
                      onTap: () => _showItemDetailDialog(data),
                      trailing: ElevatedButton(
                        onPressed: () => _addItem(data),
                        child: const Text('追加'),
                      ),
                    );

                  }).toList(),
                );
              },
            ),
          ),
          if (_selectedItems.isNotEmpty) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(8),
              child: const Text('注文内容', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ..._selectedItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return ListTile(
                title: Text('${item['name']} ×${item['quantity']}'),
                subtitle: Text('¥${item['price'] * item['quantity']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(onPressed: () => _updateQuantity(index, -1), icon: const Icon(Icons.remove)),
                    IconButton(onPressed: () => _updateQuantity(index, 1), icon: const Icon(Icons.add)),
                  ],
                ),
              );
            }),
            Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('注文確定'),
                onPressed: _submitOrder,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

