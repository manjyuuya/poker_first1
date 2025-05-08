import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MonthlyAttendancePage extends StatelessWidget {
  final String uid;
  final String selectedMonth;

  const MonthlyAttendancePage({
    super.key,
    required this.uid,
    required this.selectedMonth,
  });

  String formatYearMonth(String ym) {
    if (ym.length != 6) return ym;
    final year = ym.substring(0, 4);
    final month = int.parse(ym.substring(4, 6));
    return '$year年$month月';
  }

  String formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}時間${mins}分';
  }

  @override
  Widget build(BuildContext context) {
    final year = int.parse(selectedMonth.substring(0, 4));
    final month = int.parse(selectedMonth.substring(4));
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final userName = userData['name'] ?? 'スタッフ';

        return Scaffold(
          appBar: AppBar(title: Text('勤務記録一覧（${formatYearMonth(selectedMonth)}）')),
          body: FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('attendances')
                .where('userId', isEqualTo: uid)
                .get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final filteredDocs = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final clockIn = (data['clockIn'] as Timestamp?)?.toDate();
                return clockIn != null && clockIn.isAfter(start) && clockIn.isBefore(end);
              }).toList()
                ..sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aDate = (aData['clockIn'] as Timestamp).toDate();
                  final bDate = (bData['clockIn'] as Timestamp).toDate();
                  return aDate.compareTo(bDate);
                });

              int totalMinutes = 0;

              for (var doc in filteredDocs) {
                final data = doc.data() as Map<String, dynamic>;
                final clockIn = (data['clockIn'] as Timestamp?)?.toDate();
                final clockOut = (data['clockOut'] as Timestamp?)?.toDate();
                if (clockIn != null && clockOut != null) {
                  totalMinutes += clockOut.difference(clockIn).inMinutes;
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('$userNameの勤務記録（合計：${formatMinutes(totalMinutes)}）',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final data = filteredDocs[index].data() as Map<String, dynamic>;
                        final clockIn = (data['clockIn'] as Timestamp).toDate();
                        final clockOut = (data['clockOut'] as Timestamp?)?.toDate();
                        final night = data['nightMinutes'] ?? 0;

                        return ListTile(
                          title: Text(DateFormat('MM/dd (E) HH:mm', 'ja_JP').format(clockIn)),
                          subtitle: Text(clockOut != null
                              ? '出勤：${DateFormat('HH:mm').format(clockIn)} → 退勤：${DateFormat('HH:mm').format(clockOut)}｜深夜：$night 分'
                              : '出勤：${DateFormat('HH:mm').format(clockIn)} → 退勤：未記録'),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
