import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'monthlyAttendance.dart';

class SalaryDetailPage extends StatefulWidget {
  final String uid;

  const SalaryDetailPage({super.key, required this.uid});

  @override
  State<SalaryDetailPage> createState() => _SalaryDetailPageState();
}

class _SalaryDetailPageState extends State<SalaryDetailPage> {
  String selectedMonth = DateFormat('yyyyMM').format(DateTime.now());
  String pokerName = '';
  double hourlyWage = 0;
  double baseSalary = 0;
  double lateNightBonus = 0;
  double overtimePay = 0;
  double totalSalary = 0;
  int totalWorkingMinutes = 0;
  int baseMinutes = 0;


  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
    if (doc.exists) {
      setState(() {
        pokerName = doc['pokerName'] ?? '';
        hourlyWage = (doc['hourlyWage'] ?? 0).toDouble();
      });
      await _fetchAndCalculateSalary();
    }
  }


  Future<void> _fetchAndCalculateSalary() async {
    final year = int.parse(selectedMonth.substring(0, 4));
    final month = int.parse(selectedMonth.substring(4));
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);

    print('▶ 集計対象期間: $start 〜 $end');

    final snapshot = await FirebaseFirestore.instance
        .collection('attendances')
        .where('userId', isEqualTo: widget.uid)
        .get();

    double totalMinutes = 0;
    double nightMinutes = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();

      if (data['clockIn'] == null || data['clockOut'] == null) continue;

      final clockIn = (data['clockIn'] as Timestamp).toDate();
      final clockOut = (data['clockOut'] as Timestamp).toDate();

      if (clockOut.isBefore(clockIn)) continue;

      if (!clockIn.isBefore(start) && clockIn.isBefore(end)) {
        final workMinutes = clockOut.difference(clockIn).inMinutes.toDouble();
        totalMinutes += workMinutes;

        final night = (data['nightMinutes'] ?? 0).toDouble();
        nightMinutes += night;

        print('✅ 対象勤務: $clockIn - $clockOut (${workMinutes}分, 深夜: $night分)');
      } else {
        print('❌ 範囲外勤務: $clockIn');
      }
    }

    final basePay = hourlyWage > 0 ? (hourlyWage * (totalMinutes / 60)) : 0;
    final nightPay = hourlyWage > 0 ? (hourlyWage * 0.25 * (nightMinutes / 60)) : 0;

    setState(() {
      baseSalary = basePay.floorToDouble();
      lateNightBonus = nightPay.floorToDouble();
      totalSalary = baseSalary + lateNightBonus;
      totalWorkingMinutes = totalMinutes.floor();
      baseMinutes = totalMinutes.floor();
    });
  }


  @override
  Widget build(BuildContext context) {
    final workingHours = totalWorkingMinutes ~/ 60;
    final workingMinutes = totalWorkingMinutes % 60;

    return Scaffold(
      appBar: AppBar(title: const Text("給与計算サマリー")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              DropdownButton<String>(
                value: selectedMonth,
                items: List.generate(6, (index) {
                  final now = DateTime.now();
                  final date = DateTime(now.year, now.month - index, 1);
                  final formatted = DateFormat('yyyyMM').format(date);
                  return DropdownMenuItem(value: formatted, child: Text('$formatted 月'));
                }),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedMonth = value);
                    _fetchAndCalculateSalary();
                  }
                },
              ),
              const SizedBox(height: 20),

              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("スタッフ名：$pokerName", style: const TextStyle(fontSize: 16)),
                      Text("時給：¥${hourlyWage.toStringAsFixed(0)}", style: const TextStyle(fontSize: 16)),
                      Text("合計勤務時間：$workingHours時間$workingMinutes分", style: const TextStyle(fontSize: 16)),
                      Text("合計支給額：¥${totalSalary.toStringAsFixed(0)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text("※ 計算式：", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("基本給（時給）+ 深夜割増（時給×0.25）", style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),

              ListTile(title: const Text("基本給"), trailing: Text("¥${baseSalary.toStringAsFixed(0)}")),
              ListTile(title: const Text("深夜割増"), trailing: Text("¥${lateNightBonus.toStringAsFixed(0)}")),
              const Divider(),
              ListTile(
                title: const Text("合計支給額", style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: Text("¥${totalSalary.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),

              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("■ 支給額の内訳（分単位）", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      if (hourlyWage > 0) ...[
                        Text("基本給：${baseMinutes ~/ 60}時間${baseMinutes % 60}分 × ¥${hourlyWage.toStringAsFixed(2)} = ¥${baseSalary.toStringAsFixed(0)}"),
                        Text("深夜割増：${(lateNightBonus / (hourlyWage * 0.25)).floor()}時間"
                            "${((lateNightBonus / (hourlyWage * 0.25)) * 60 % 60).round()}分 × ¥${(hourlyWage * 0.25).toStringAsFixed(2)} = ¥${lateNightBonus.toStringAsFixed(0)}"),
                      ] else
                        const Text("※ 時給が未設定のため、内訳は表示できません。"),
                      const Divider(),
                      Text(
                        "合計支給額：¥${totalSalary.toStringAsFixed(0)}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MonthlyAttendancePage(
                        uid: widget.uid,
                        selectedMonth: selectedMonth,
                      ),
                    ),
                  );
                },
                child: Text('この月の勤務記録を表示'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
