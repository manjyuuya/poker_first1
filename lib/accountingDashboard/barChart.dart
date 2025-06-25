import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class MonthlySummaryChartPage extends StatefulWidget {
  const MonthlySummaryChartPage({super.key});

  @override
  State<MonthlySummaryChartPage> createState() => _MonthlySummaryChartPageState();
}

class _MonthlySummaryChartPageState extends State<MonthlySummaryChartPage> {
  late Future<Map<String, Map<String, double>>> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = fetchMonthlySummary();
  }

  Future<Map<String, Map<String, double>>> fetchMonthlySummary() async {
    final salesSnapshot = await FirebaseFirestore.instance.collection('sales').get();
    final expensesSnapshot = await FirebaseFirestore.instance.collection('expenses').get();

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
      for (var k in allKeys)
        k: (monthlySales[k] ?? 0) - (monthlyExpenses[k] ?? 0)
    };

    return {
      'sales': monthlySales,
      'expenses': monthlyExpenses,
      'profits': monthlyProfits,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('月別売上・経費・利益')),
      body: FutureBuilder<Map<String, Map<String, double>>>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          final sales = data['sales']!;
          final expenses = data['expenses']!;
          final profits = data['profits']!;

          final months = {...sales.keys, ...expenses.keys, ...profits.keys}.toList()..sort();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: MonthlySummaryBarChart(
                    months: months,
                    sales: months.map((m) => sales[m] ?? 0).toList(),
                    expenses: months.map((m) => expenses[m] ?? 0).toList(),
                    profits: months.map((m) => profits[m] ?? 0).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    LegendItem(color: Colors.green, label: '売上'),
                    SizedBox(width: 16),
                    LegendItem(color: Colors.red, label: '経費'),
                    SizedBox(width: 16),
                    LegendItem(color: Colors.blue, label: '利益'),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class MonthlySummaryBarChart extends StatelessWidget {
  final List<String> months;
  final List<double> sales;
  final List<double> expenses;
  final List<double> profits;

  const MonthlySummaryBarChart({
    super.key,
    required this.months,
    required this.sales,
    required this.expenses,
    required this.profits,
  });

  @override
  Widget build(BuildContext context) {
    final maxY = [
      ...sales,
      ...expenses,
      ...profits,
    ].reduce((a, b) => a > b ? a : b) * 1.2;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        groupsSpace: 24,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index < 0 || index >= months.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  months[index],
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, interval: 10000),
          ),
          rightTitles: AxisTitles(),
          topTitles: AxisTitles(),
        ),
        barGroups: List.generate(months.length, (i) {
          return BarChartGroupData(
            x: i,
            barsSpace: 4,
            barRods: [
              BarChartRodData(toY: sales[i], color: Colors.green, width: 8),
              BarChartRodData(toY: expenses[i], color: Colors.red, width: 8),
              BarChartRodData(toY: profits[i], color: Colors.blue, width: 8),
            ],
          );
        }),
      ),
    );
  }
}

class LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const LegendItem({
    super.key,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
