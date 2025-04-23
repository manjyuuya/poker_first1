import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StaffDetailPage extends StatefulWidget {
  final String uid;

  const StaffDetailPage({Key? key, required this.uid}) : super(key: key);

  @override
  State<StaffDetailPage> createState() => _StaffDetailPageState();
}

class _StaffDetailPageState extends State<StaffDetailPage> {
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _isLoading = true;
  int totalWorkingMinutes = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      // usersドキュメント取得
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception("ユーザーが存在しません");
      }

      final userData = userDoc.data()!;
      setState(() {
        _userData = userData;
      });

      // attendancesから該当ユーザーの勤務履歴取得
      final attendanceQuery = await FirebaseFirestore.instance
          .collection('attendances')
          .where('userId', isEqualTo: widget.uid)
          .orderBy('date', descending: true)
          .get();

      final records = await Future.wait(attendanceQuery.docs.map((doc) async {
        final data = doc.data();
        final date = (data['date'] as Timestamp).toDate();
        final clockIn = (data['clockIn'] as Timestamp?)?.toDate();
        final clockOut = (data['clockOut'] as Timestamp?)?.toDate();
        final duration = (clockIn != null && clockOut != null)
            ? clockOut.difference(clockIn)
            : null;

        final shiftId = data['shiftId'];
        String shiftDetails = 'シフト取得失敗';

        if (shiftId != null) {
          final shiftDoc = await FirebaseFirestore.instance
              .collection('shifts')
              .doc(shiftId)
              .get();
          if (shiftDoc.exists) {
            final shiftData = shiftDoc.data();
            final startTime = (shiftData?['start'] as Timestamp).toDate();
            final endTime = (shiftData?['end'] as Timestamp).toDate();
            shiftDetails =
            '${DateFormat('HH:mm').format(startTime)} - ${DateFormat('HH:mm').format(endTime)}';
          }
        }

        if (duration != null) {
          totalWorkingMinutes += duration.inMinutes;
        }

        return {
          'date': DateFormat('yyyy/MM/dd').format(date),
          'clockIn': clockIn != null ? DateFormat.Hm().format(clockIn) : '未打刻',
          'clockOut': clockOut != null ? DateFormat.Hm().format(clockOut) : '未打刻',
          'duration': duration?.inMinutes,
          'overtime': data['overtimeMinutes'] ?? 0,
          'shift': shiftDetails,
          'late': data['late'] ?? false,
          'overtimeMinutes': data['overtimeMinutes'] ?? 0,
          'shortageMinutes': data['shortageMinutes'] ?? 0,
        };
      }).toList());

      setState(() {
        _attendanceRecords = records;
        _isLoading = false;
      });
    } catch (e) {
      print("❌ データ取得エラー: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getTotalWorkingHours() {
    int hours = totalWorkingMinutes ~/ 60;
    int minutes = totalWorkingMinutes % 60;
    return '$hours時間 $minutes分';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(body: Center(child: CircularProgressIndicator()));

    if (_userData == null) return Scaffold(body: Center(child: Text('ユーザー情報が取得できませんでした')));

    return Scaffold(
      appBar: AppBar(title: Text('${_userData!['pokerName']} の詳細')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          ListTile(
            title: Text('Poker Name'),
            subtitle: Text(_userData!['pokerName'] ?? '未設定'),
          ),
          ListTile(
            title: Text('Login ID'),
            subtitle: Text(_userData!['loginId'] ?? '不明'),
          ),
          ListTile(
            title: Text('UID'),
            subtitle: Text(widget.uid),
          ),
          Divider(),
          Text('勤務合計時間: ${_getTotalWorkingHours()}',
              style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          ..._attendanceRecords.map((record) {
            return Card(
              child: ListTile(
                title: Text(record['date']),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('出勤: ${record['clockIn']}'),
                    Text('退勤: ${record['clockOut']}'),
                    Text('遅刻: ${record['late'] ? '有' : '無'}'),
                    if ((record['overtime'] ?? 0) > 0)
                      Text('残業: ${record['overtime'] ~/ 60}時間 ${record['overtime'] % 60}分'),
                    if ((record['shortageMinutes'] ?? 0) > 0)
                      Text('不足: ${record['shortageMinutes'] ~/ 60}時間 ${record['shortageMinutes'] % 60}分'),
                    Text('シフト: ${record['shift']}'),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}



