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
import 'package:fl_chart/fl_chart.dart';

class AccountingDashboardPage extends StatefulWidget {
  const AccountingDashboardPage({super.key});

  @override
  State<AccountingDashboardPage> createState() => _AccountingDashboardPageState();
}

class _AccountingDashboardPageState extends State<AccountingDashboardPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime _selectedDate = DateTime.now();
  bool _isMonthlyView = false;
  List<String> _monthOptions = [];

  int _totalSales = 0;
  int _totalExpenses = 0;

  late Future<Map<String, Map<String, double>>> _monthlySummaryFuture;

  @override
  void initState() {
    super.initState();
    _generateMonthOptions();
    _loadData();
    _monthlySummaryFuture = fetchMonthlySummary();
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
    late DateTime start;
    late DateTime end;

    if (_isMonthlyView) {
      start = DateTime(_selectedDate.year, _selectedDate.month, 1);
      end = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
    } else {
      start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      end = start.add(const Duration(days: 1));
    }

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

  void _onDateChanged(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    _loadData();
  }

  void _onMonthlyDropdownChanged(String? selected) {
    if (selected == null) return;
    final parts = selected.split('/');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    setState(() {
      _selectedDate = DateTime(year, month);
    });
    _loadData();
  }

  Future<Map<String, Map<String, double>>> fetchMonthlySummary() async {
    final salesSnapshot = await _firestore.collection('sales').get();
    final expensesSnapshot = await _firestore.collection('expenses').get();

    final Map<String, double> monthlySales = {};
    final Map<String, double> monthlyExpenses = {};

    for (var doc in salesSnapshot.docs) {
      final date = (doc['date'] as Timestamp).toDate();
      final key = "${date.year}/${date.month.toString().padLeft(2, '0')}";
      monthlySales[key] = (monthlySales[key] ?? 0) + (doc['amount'] as num).toDouble();
    }

    for (var doc in expensesSnapshot.docs) {
      final date = (doc['date'] as Timestamp).toDate();
      final key = "${date.year}/${date.month.toString().padLeft(2, '0')}";
      monthlyExpenses[key] = (monthlyExpenses[key] ?? 0) + (doc['amount'] as num).toDouble();
    }

    final allKeys = {...monthlySales.keys, ...monthlyExpenses.keys}.toList()..sort();

    final Map<String, double> monthlyProfits = {
      for (var k in allKeys) k: (monthlySales[k] ?? 0) - (monthlyExpenses[k] ?? 0)
    };

    return {
      'sales': monthlySales,
      'expenses': monthlyExpenses,
      'profits': monthlyProfits,
    };
  }

  Future<void> _exportDailySummaryToCSV() async {
    final DateTime startOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final DateTime endOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);

    final List<List<String>> csvData = [
      ['日付', '売上合計', '経費合計', '利益']
    ];

    for (int day = 0; day < endOfMonth.difference(startOfMonth).inDays; day++) {
      final date = startOfMonth.add(Duration(days: day));
      final nextDate = date.add(const Duration(days: 1));

      final salesSnapshot = await _firestore
          .collection('sales')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(date))
          .where('date', isLessThan: Timestamp.fromDate(nextDate))
          .get();

      final expensesSnapshot = await _firestore
          .collection('expenses')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(date))
          .where('date', isLessThan: Timestamp.fromDate(nextDate))
          .get();

      final totalSales = salesSnapshot.docs.fold<int>(
        0, (sum, doc) => sum + (doc['amount'] as num).toInt(),
      );

      final totalExpenses = expensesSnapshot.docs.fold<int>(
        0, (sum, doc) => sum + (doc['amount'] as num).toInt(),
      );

      final profit = totalSales - totalExpenses;

      csvData.add([
        DateFormat('yyyy/MM/dd').format(date),
        totalSales.toString(),
        totalExpenses.toString(),
        profit.toString(),
      ]);
    }

    String csv = const ListToCsvConverter().convert(csvData);

    try {
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/daily_summary_${DateFormat('yyyyMM').format(_selectedDate)}.csv';
      final file = File(path);
      await file.writeAsString(csv);

      await Share.shareXFiles([XFile(file.path)], text: '日次売上・経費・利益のCSVファイル');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('日次CSVファイルを正常に出力しました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('日次CSV出力に失敗しました: $e')),
      );
    }
  }

  Future<void> _exportToCSV() async {
    await _exportDailySummaryToCSV();
  }

  @override
  Widget build(BuildContext context) {
    final profit = _totalSales - _totalExpenses;
    return Scaffold(
      appBar: AppBar(
        title: const Text('会計ダッシュボード'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'CSV出力',
            onPressed: _exportToCSV,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Switch(
                    value: _isMonthlyView,
                    onChanged: (val) {
                      setState(() {
                        _isMonthlyView = val;
                      });
                      _loadData();
                    },
                  ),
                  Text(_isMonthlyView ? '月毎表示' : '日毎表示'),
                ],
              ),
              _isMonthlyView
                  ? DropdownButton<String>(
                value: DateFormat('yyyy/MM').format(_selectedDate),
                items: _monthOptions.map((month) {
                  return DropdownMenuItem(value: month, child: Text(month));
                }).toList(),
                onChanged: _onMonthlyDropdownChanged,
              )
                  : TextButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(DateFormat('yyyy/MM/dd').format(_selectedDate)),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) _onDateChanged(picked);
                },
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
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.money_off),
                    label: const Text('経費登録'),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => ExpenseEntryPage()));
                    },
                  ),
                  ElevatedButton.icon(
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
              const SizedBox(height: 24),
              SizedBox(
                height: 300,  // 高さ300px固定
                child: FutureBuilder<Map<String, Map<String, double>>>(
                  future: _monthlySummaryFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Text('データ取得エラー: ${snapshot.error}');
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Text('グラフ表示用のデータがありません');
                    }

                    final data = snapshot.data!;
                    final salesMap = data['sales']!;
                    final expensesMap = data['expenses']!;
                    final profitsMap = data['profits']!;

                    final allMonths = {...salesMap.keys, ...expensesMap.keys}.toList()..sort();

                    final salesList = allMonths.map((m) => salesMap[m] ?? 0).toList();
                    final expensesList = allMonths.map((m) => expensesMap[m] ?? 0).toList();
                    final profitsList = allMonths.map((m) => profitsMap[m] ?? 0).toList();

                    final maxY = [
                      ...salesList,
                      ...expensesList,
                      ...profitsList,
                      100
                    ].reduce((a, b) => a > b ? a : b) * 1.2;

                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            LegendItem(color: Colors.green, text: '売上'),
                            SizedBox(width: 16),
                            LegendItem(color: Colors.red, text: '経費'),
                            SizedBox(width: 16),
                            LegendItem(color: Colors.blue, text: '利益'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // ここを Container に変え、高さを明示
                        Container(
                          height: 220,  // グラフ自体の高さ調整
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final minBarGroupWidth = 70;
                              final calculatedWidth = allMonths.length * minBarGroupWidth;
                              final chartWidth = (calculatedWidth < constraints.maxWidth ? constraints.maxWidth : calculatedWidth).toDouble();

                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: chartWidth,
                                  height: constraints.maxHeight,
                                  child: BarChart(
                                    BarChartData(
                                      alignment: BarChartAlignment.spaceAround,
                                      maxY: maxY,
                                      barTouchData: BarTouchData(enabled: true),
                                      titlesData: FlTitlesData(
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(showTitles: false),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 32,
                                            getTitlesWidget: (double value, TitleMeta meta) {
                                              final index = value.toInt();
                                              if (index < 0 || index >= allMonths.length) {
                                                return const SizedBox.shrink();
                                              }
                                              return Text(
                                                allMonths[index],
                                                style: const TextStyle(fontSize: 10),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      barGroups: List.generate(allMonths.length, (i) {
                                        return BarChartGroupData(
                                          x: i,
                                          barRods: [
                                            BarChartRodData(toY: salesList[i], color: Colors.green, width: 8),
                                            BarChartRodData(toY: expensesList[i], color: Colors.red, width: 8),
                                            BarChartRodData(toY: profitsList[i], color: Colors.blue, width: 8),
                                          ],
                                        );
                                      }),
                                      groupsSpace: 12,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class LegendItem extends StatelessWidget {
  final Color color;
  final String text;

  const LegendItem({required this.color, required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 16, height: 16, color: color),
        const SizedBox(width: 6),
        Text(text),
      ],
    );
  }
}
