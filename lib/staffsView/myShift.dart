import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';

class MyShiftsPage extends StatefulWidget {
  const MyShiftsPage({super.key});

  @override
  _MyShiftsPageState createState() => _MyShiftsPageState();
}

class _MyShiftsPageState extends State<MyShiftsPage> {
  final user = FirebaseAuth.instance.currentUser;
  Map<DateTime, List<Map<String, dynamic>>> _shifts = {};
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchShifts();
  }

  @override
  void _fetchShifts() async {
    if (user == null) {
      print("⚠️ ユーザーがログインしていません");
      return;
    }

    print("✅ _fetchShifts() が呼ばれました (ユーザーID: ${user!.uid})");

    try {
      // **ログインユーザーのシフトを取得**
      QuerySnapshot myShiftsSnapshot = await FirebaseFirestore.instance
          .collection('shifts')
          .where('denied', isEqualTo: false)
          .where('userId', isEqualTo: user!.uid) // **ログインユーザーのみ**
          .get();

      // **他のスタッフの確定シフトを取得**
      QuerySnapshot confirmedShiftsSnapshot = await FirebaseFirestore.instance
          .collection('shifts')
          .where('denied', isEqualTo: false)
          .where('confirmed', isEqualTo: true) // **確定シフトのみ**
          .get();

      print("📄 Firestore 取得データ（本人）: ${myShiftsSnapshot.docs.length} 件");
      print("📄 Firestore 取得データ（確定）: ${confirmedShiftsSnapshot.docs.length} 件");

      Map<DateTime, List<Map<String, dynamic>>> tempShifts = {};

      // **取得したデータを処理**
      List<QueryDocumentSnapshot> allDocs = [
        ...myShiftsSnapshot.docs,
        ...confirmedShiftsSnapshot.docs
      ];

      for (var doc in allDocs) {
        DateTime date;
        if (doc['date'] is Timestamp) {
          date = (doc['date'] as Timestamp).toDate();
        } else {
          date = DateTime.parse(doc['date']);
        }
        DateTime dayKey = DateTime(date.year, date.month, date.day);

        bool isConfirmed = doc['confirmed'] ?? false;
        String shiftText = isConfirmed ? doc['shift'] : doc['shift'] + "(仮)";
        String statusText = isConfirmed ? doc['approvedBy'] : "未承認";
        Color shiftColor = isConfirmed ? Colors.red : Colors.blue;

        String userName = doc['userName'] ?? "不明なスタッフ";

        // 同じ内容のシフトが既に追加されていないかチェック
        bool alreadyExists = false;
        if (tempShifts.containsKey(dayKey)) {
          for (var existingShift in tempShifts[dayKey]!) {
            // 内容が一致するシフトがあれば重複としてスキップ
            if (existingShift["shift"] == shiftText &&
                existingShift["userName"] == userName &&
                existingShift["approvedBy"] == statusText) {
              alreadyExists = true;
              break;
            }
          }
        }
        // 重複がない場合にのみ追加
        if (!alreadyExists) {
          if (!tempShifts.containsKey(dayKey)) {
            tempShifts[dayKey] = [];
          }
          tempShifts[dayKey]!.add({
            "shift": shiftText,
            "approvedBy": statusText,
            "userName": userName,
            "isConfirmed": isConfirmed,
            "shiftColor": shiftColor,
          });
        }
      }

      setState(() {
        _shifts = tempShifts;
        print("✅ 取得したシフトデータ: $_shifts");
      });

    } catch (e) {
      print("❌ Firestore データ取得エラー: $e");
    }
  }



  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text("確定シフト")),
        body: Center(child: Text("ログインしてください")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("シフト表")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            TableCalendar(
              locale: 'ja_JP',
              firstDay: DateTime(2020, 1, 1),
              lastDay: DateTime(2099, 12, 31),
              focusedDay: _selectedDay,
              selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                });
              },
              eventLoader: (day) {
                DateTime dayKey = DateTime(day.year, day.month, day.day);
                var events = _shifts[dayKey] ?? [];
                return events.isNotEmpty ? events : [];
              },
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  if (events.isEmpty) return SizedBox.shrink();
                  var event = events.first as Map<String, dynamic>;
                  Color markerColor = event["shiftColor"] ?? Colors.grey;
                  return Container(
                    decoration: BoxDecoration(
                      color: markerColor,
                      shape: BoxShape.circle,
                    ),
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.all(4.0),
                  );
                },
              ),
            ),

            // ListViewをSizedBoxで囲み、shrinkWrap & physicsを調整
            SizedBox(
              height: 300, // ここで高さを決める。必要に応じて調整してください。
              child: _shifts[DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day)] != null
                  ? ListView.builder(
                shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _shifts[DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day)]!.length,
                itemBuilder: (context, index) {
                  var shift = _shifts[DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day)]![index];
                  return ListTile(
                    title: Text("${shift["userName"]}：${shift["shift"]}"),
                    subtitle: Text("承認者: ${shift["approvedBy"]}"),
                  );
                },
              )
                  : Center(child: Text("この日の確定シフトはありません")),
            ),
          ],
        ),
      ),
    );

  }
}
