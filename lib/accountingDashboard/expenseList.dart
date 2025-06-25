import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:poker_first/accountingDashboard/expenseEdit.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExpenseListPage extends StatefulWidget {
  const ExpenseListPage({Key? key}) : super(key: key);

  @override
  State<ExpenseListPage> createState() => _ExpenseListPageState();
}

class _ExpenseListPageState extends State<ExpenseListPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<DocumentSnapshot> _expenses = [];
  List<DocumentSnapshot> _filteredExpenses = [];

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
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
    _monthOptions = months;
  }

  Future<void> _loadData() async {
    final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);

    QuerySnapshot expenseSnapshot = await _firestore
        .collection('expenses')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
        .get();

    List<DocumentSnapshot> expenseDocs = expenseSnapshot.docs;

    setState(() {
      _expenses = expenseDocs;
    });

    _generateDropdownOptions();
    _applyFilters();
  }

  void _generateDropdownOptions() {
    final categories = <String>{};
    final payments = <String>{};

    for (var doc in _expenses) {
      final category = doc['category']?.toString().trim();
      final payment = doc['paymentMethod']?.toString().trim();

      if (category != null && category.isNotEmpty) categories.add(category);
      if (payment != null && payment.isNotEmpty) payments.add(payment);
    }

    setState(() {
      _categoryOptions = categories.toList()..sort();
      _paymentOptions = payments.toList()..sort();
    });
  }

  void _applyFilters() {
    List<DocumentSnapshot> filtered = _expenses;

    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      filtered = filtered
          .where((doc) => doc['category']?.toString().trim() == _selectedCategory)
          .toList();
    }

    if (_selectedPayment != null && _selectedPayment!.isNotEmpty) {
      filtered = filtered
          .where((doc) => doc['paymentMethod']?.toString().trim() == _selectedPayment)
          .toList();
    }

    setState(() {
      _filteredExpenses = filtered;
    });
  }

  void _onDropdownChanged(String? selected) {
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
      final headers = ['日付', 'カテゴリ', '金額', '支払方法', 'メモ'];
      final dateFormat = DateFormat('yyyy/MM/dd');

      final rows = _filteredExpenses.map((doc) {
        final date = (doc['date'] as Timestamp).toDate();
        return [
          dateFormat.format(date),
          doc['category'] ?? '',
          doc['amount'].toString(),
          doc['paymentMethod'] ?? '',
          doc['memo'] ?? '',
        ];
      }).toList();

      final csvData = const ListToCsvConverter().convert([headers, ...rows]);

      // 🔽 ディレクトリの取得を try-catch の中で安全に行う
      Directory? directory;
      try {
        directory = await getTemporaryDirectory();
      } catch (e) {
        throw Exception('一時ディレクトリの取得に失敗しました: $e');
      }

      if (directory == null) {
        throw Exception('一時ディレクトリが null です');
      }

      final fileName = 'expenses_${DateFormat('yyyyMM').format(_selectedMonth)}.csv';
      final file = File('${directory.path}/$fileName');

      // ファイルの親ディレクトリを作成（念のため）
      if (!(await file.parent.exists())) {
        await file.parent.create(recursive: true);
      }

      await file.writeAsString(csvData);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '経費データ（CSV）を共有します',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSVファイルを正常に出力しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV出力中にエラーが発生しました: $e')),
      );
    }
  }

  Future<void> _exportSingleCSV(DocumentSnapshot expense) async {
    try {
      final headers = ['日付', 'カテゴリ', '金額', '支払方法', 'メモ'];
      final displayFormat = DateFormat('yyyy/MM/dd'); // 表示用
      final fileNameFormat = DateFormat('yyyyMMdd_HHmmss'); // ファイル名用

      final date = (expense['date'] as Timestamp).toDate();
      final row = [
        [
          displayFormat.format(date),
          expense['category'] ?? '',
          expense['amount'].toString(),
          expense['paymentMethod'] ?? '',
          expense['memo'] ?? '',
        ]
      ];

      final csvData = const ListToCsvConverter().convert([headers, ...row]);

      final directory = await getTemporaryDirectory();
      await Directory(directory.path).create(recursive: true);

      final fileName = 'expense_${fileNameFormat.format(date)}.csv';
      final path = '${directory.path}/$fileName';

      final file = File(path);
      await file.writeAsString(csvData);

      await Share.shareXFiles([XFile(file.path)], text: '経費1件のCSVを共有します');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('個別CSVを出力しました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('個別CSV出力中にエラーが発生しました: $e')),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd');
    return Scaffold(
      appBar: AppBar(
        title: const Text('経費一覧'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'CSV出力',
            onPressed: _filteredExpenses.isEmpty ? null : _exportCSV,
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
                  onChanged: _onDropdownChanged,
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
                    Expanded(
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
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredExpenses.length,
              itemBuilder: (context, index) {
                final expense = _filteredExpenses[index];
                final id = expense.id;
                final date = (expense['date'] as Timestamp).toDate();

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
                        content: const Text("この経費を削除しますか？"),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text("キャンセル")),
                          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text("削除")),
                        ],
                      ),
                    );
                  },
                  onDismissed: (_) async {
                    try {
                      await _firestore.collection('expenses').doc(id).delete();
                      _loadData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('経費を削除しました')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('削除中にエラーが発生しました: $e')),
                      );
                    }
                  },
                  child: ListTile(
                    leading: const Icon(Icons.money_off),
                    title: Text(expense['category'] ?? '不明なカテゴリ'),
                    subtitle: Text('${dateFormat.format(date)}\n${expense['memo'] ?? ''}'),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.download_rounded),
                          tooltip: 'CSV出力',
                          onPressed: () => _exportSingleCSV(expense),
                        ),
                        Text('¥${expense['amount']}'),
                      ],
                    ),
                    isThreeLine: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExpenseEditPage(
                            expenseId: id,
                            initialData: expense,
                          ),
                        ),
                      ).then((_) => _loadData());
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
