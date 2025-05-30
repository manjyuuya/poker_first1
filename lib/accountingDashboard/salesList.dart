import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:poker_first/accountingDashboard/salesEdit.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';


class SalesListPage extends StatefulWidget {
  const SalesListPage({super.key});

  @override
  State<SalesListPage> createState() => _SalesListPageState();
}

class _SalesListPageState extends State<SalesListPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  List<DocumentSnapshot> _sales = [];
  List<DocumentSnapshot> _filteredSales = [];

  List<String> _monthOptions = [];
  List<String> _categoryOptions = [];
  List<String> _paymentOptions = [];

  String? _selectedCategory;
  String? _selectedPayment;

  @override
  void initState() {
    super.initState();
    _generateMonthOptions();
    _loadData();
  }

  void _generateMonthOptions() {
    final now = DateTime.now();
    final List<String> months = [];
    for (int i = 0; i < 24; i++) {
      final date = DateTime(now.year, now.month - i);
      months.add(DateFormat('yyyy/MM').format(date));
    }
    setState(() {
      _monthOptions = months;
    });
  }

  Future<void> _loadData() async {
    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('sales')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay))
        .where('date', isLessThan: Timestamp.fromDate(lastDay))
        .orderBy('date', descending: true)
        .get();

    setState(() {
      _sales = snapshot.docs;
    });

    _generateDropdownOptions();
    _applyFilters();
  }

  void _generateDropdownOptions() {
    final categories = <String>{};
    final payments = <String>{};

    for (var doc in _sales) {
      final data = doc.data() as Map<String, dynamic>;
      final category = data['category']?.toString().trim() ?? '';
      final payment = data['paymentMethod']?.toString().trim() ?? '';

      if (category.isNotEmpty) categories.add(category);
      if (payment.isNotEmpty) payments.add(payment);
    }

    setState(() {
      _categoryOptions = categories.toList()..sort();
      _paymentOptions = payments.toList()..sort();
    });
  }

  void _applyFilters() {
    var filtered = _sales;

    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return (data['category']?.toString().trim() ?? '') == _selectedCategory;
      }).toList();
    }

    if (_selectedPayment != null && _selectedPayment!.isNotEmpty) {
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return (data['paymentMethod']?.toString().trim() ?? '') == _selectedPayment;
      }).toList();
    }

    setState(() {
      _filteredSales = filtered;
    });
  }

  void _onMonthDropdownChanged(String? selected) {
    if (selected == null) return;
    final parts = selected.split('/');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    setState(() {
      _selectedMonth = DateTime(year, month);
      _selectedCategory = null;
      _selectedPayment = null;
    });
    _loadData();
  }
  Future<void> _exportCSV() async {
    try {
      final headers = ['日付', 'カテゴリ', '金額',  'メモ'];
      final dateFormat = DateFormat('yyyy/MM/dd');

      final rows = _filteredSales.map((doc) {
        final date = (doc['date'] as Timestamp).toDate();
        return [
          dateFormat.format(date),
          doc['category'] ?? '',
          doc['amount'].toString(),
          doc['memo'] ?? '',
        ];
      }).toList();

      final csvData = const ListToCsvConverter().convert([headers, ...rows]);

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/expenses_${DateFormat('yyyyMM').format(_selectedMonth)}.csv';
      final file = File(path);
      await file.writeAsString(csvData);

      await Share.shareXFiles([XFile(file.path)], text: '経費データ（CSV）を共有します');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSVファイルを正常に出力しました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV出力中にエラーが発生しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final  dateFormat = DateFormat('yyyy/MM/dd');
    int total = 0;
    for (var doc in _filteredSales) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['amount'] ?? 0) as int;
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('売上一覧'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'CSV出力',
            onPressed: _filteredSales.isEmpty
                ? null
                : () async {
              await _exportCSV();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButton<String>(
                  value: DateFormat('yyyy/MM').format(_selectedMonth),
                  items: _monthOptions.map((month) {
                    return DropdownMenuItem(value: month, child: Text(month));
                  }).toList(),
                  onChanged: _onMonthDropdownChanged,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(labelText: 'カテゴリを選択'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('すべて')),
                          ..._categoryOptions.map((cat) =>
                              DropdownMenuItem(value: cat, child: Text(cat))),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedCategory = val);
                          _applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                   /* Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedPayment,
                        decoration: const InputDecoration(labelText: '支払方法を選択'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('すべて')),
                          ..._paymentOptions.map((pm) =>
                              DropdownMenuItem(value: pm, child: Text(pm))),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedPayment = val);
                          _applyFilters();
                        },
                      ),
                    ),*/
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('合計: ¥$total',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredSales.length,
              itemBuilder: (context, index) {
                final sale = _filteredSales[index];
                final id = sale.id;
                final date = (sale['date'] as Timestamp).toDate();

                return Dismissible(
                  key: Key(id),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) async {
                    return await showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("削除確認"),
                        content: const Text("この売上データを削除しますか？"),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text("キャンセル")),
                          TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text("削除")),
                        ],
                      ),
                    );
                  },
                  onDismissed: (_) async {
                    try {
                      await _firestore.collection('sales').doc(id).delete();
                      _loadData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('売上データを削除しました')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('削除中にエラーが発生しました: $e')),
                      );
                    }
                  },
                  child: ListTile(
                    leading: const Icon(Icons.attach_money),
                    title: Text(sale['category'] ?? '不明なカテゴリ'),
                    subtitle: Text('${dateFormat.format(date)}\n${sale['memo'] ?? ''}'),
                    trailing: Text('¥${sale['amount']}'),
                    isThreeLine: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SalesEditPage(
                            saleId: id,
                            initialData: sale,
                          ),
                        ),
                      ).then((_) => _loadData());
                    },
                  ),
                );
              },
            ),
          )
          ,
        ],
      ),
    );
  }
}
