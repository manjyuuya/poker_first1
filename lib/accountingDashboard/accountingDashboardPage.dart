import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:poker_first/accountingDashboard/expenseEntry.dart';
import 'package:poker_first/accountingDashboard/expenseList.dart';
import 'package:poker_first/accountingDashboard/salesEntry.dart';
import 'package:poker_first/accountingDashboard/salesList.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';


class AccountingDashboardPage extends StatefulWidget {
  const AccountingDashboardPage({super.key});

  @override
  State<AccountingDashboardPage> createState() => _AccountingDashboardPageState();
}

class _AccountingDashboardPageState extends State<AccountingDashboardPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<String> _monthOptions = [];

  int _totalSales = 0;
  int _totalExpenses = 0;

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

    final salesSnapshot = await _firestore
        .collection('sales')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();

    final expensesSnapshot = await _firestore
        .collection('expenses')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();

    final totalSales = salesSnapshot.docs.fold<int>(
      0, (sum, doc) => sum + (doc['amount'] as num).toInt(),
    );

    final totalExpenses = expensesSnapshot.docs.fold<int>(
      0, (sum, doc) => sum + (doc['amount'] as num).toInt(),
    );

    setState(() {
      _totalSales = totalSales;
      _totalExpenses = totalExpenses;
    });
  }

  void _onDropdownChanged(String? selected) {
    if (selected == null) return;
    final parts = selected.split('/');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    setState(() {
      _selectedMonth = DateTime(year, month);
    });
    _loadData();
  }
  // 直近12ヶ月分の月次データを取得しCSV出力する関数
  Future<void> _exportMonthlySummaryToCSV() async {
    final now = DateTime.now();
    final List<List<String>> csvData = [
      ['年月', '売上合計', '経費合計', '利益']
    ];

    for (int i = 0; i < 12; i++) {
      final year = now.year;
      final month = now.month - i;
      final date = DateTime(year, month < 1 ? month + 12 : month);

      final start = DateTime(date.year, date.month, 1);
      final end = (date.month == 12)
          ? DateTime(date.year + 1, 1, 1)
          : DateTime(date.year, date.month + 1, 1);

      // Firestoreから売上取得
      final salesSnapshot = await _firestore
          .collection('sales')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThan: Timestamp.fromDate(end))
          .get();

      // Firestoreから経費取得
      final expensesSnapshot = await _firestore
          .collection('expenses')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThan: Timestamp.fromDate(end))
          .get();

      final totalSales = salesSnapshot.docs.fold<int>(
        0, (sum, doc) => sum + (doc['amount'] as num).toInt(),
      );

      final totalExpenses = expensesSnapshot.docs.fold<int>(
        0, (sum, doc) => sum + (doc['amount'] as num).toInt(),
      );

      final profit = totalSales - totalExpenses;

      csvData.add([
        DateFormat('yyyy/MM').format(start),
        totalSales.toString(),
        totalExpenses.toString(),
        profit.toString(),
      ]);
    }

    // CSV文字列に変換
    String csv = const ListToCsvConverter().convert(csvData);

    try {
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/monthly_summary_${DateFormat('yyyyMMdd_HHmmss').format(now)}.csv';
      final file = File(path);
      await file.writeAsString(csv);

      // 共有ダイアログを表示
      await Share.shareXFiles([XFile(file.path)], text: '月次売上・経費・利益のCSVファイル');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSVファイルを正常に出力しました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV出力に失敗しました: $e')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final profit = _totalSales - _totalExpenses;
    return Scaffold(
      appBar: AppBar(title: const Text('会計ダッシュボード'),
          actions: [
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: '月次CSV出力',
              onPressed: _exportMonthlySummaryToCSV,
            ),
          ],
        ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButton<String>(
              value: DateFormat('yyyy/MM').format(_selectedMonth),
              items: _monthOptions.map((month) {
                return DropdownMenuItem(value: month, child: Text(month));
              }).toList(),
              onChanged: _onDropdownChanged,
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: const Text('売上合計'),
                trailing: Text('¥${_totalSales.toString()}'),
              ),
            ),
            Card(
              child: ListTile(
                title: const Text('経費合計'),
                trailing: Text('¥${_totalExpenses.toString()}'),
              ),
            ),
            Card(
              color: profit >= 0 ? Colors.green[100] : Colors.red[100],
              child: ListTile(
                title: const Text('利益'),
                trailing: Text('¥${profit.toString()}'),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.attach_money),
                  label: const Text('売上登録'),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => SalesEntryPage()));
                  },
                ),ElevatedButton.icon(
                  icon: const Icon(Icons.money_off),
                  label: const Text('経費登録'),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ExpenseEntryPage()));
                  },
                ),ElevatedButton.icon(
                  icon: const Icon(Icons.list),
                  label: const Text('売上一覧'),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => SalesListPage()));
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.receipt),
                  label: const Text('経費一覧'),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ExpenseListPage()));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
