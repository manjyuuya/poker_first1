import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:poker_first/adminsView/salaryCalculation.dart';
import 'package:poker_first/adminsView/staffAttendance.dart';

class AttendanceSearchPage extends StatefulWidget {
  @override
  _AttendanceSearchPageState createState() => _AttendanceSearchPageState();
}

class _AttendanceSearchPageState extends State<AttendanceSearchPage> {
  final TextEditingController _loginIdController = TextEditingController();
  bool useExactDay = false;
  bool useYear = false;
  DateTime selectedDate = DateTime.now();
  int selectedYear = DateTime.now().year;

  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _isLoading = false;
  String? _error;
  int totalWorkingMinutes = 0;
  bool _hasSearched = false;
  bool _noRecordsFound = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('勤怠記録検索')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _loginIdController,
                decoration: InputDecoration(
                  labelText: 'ログインID',
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search),
                    onPressed: _onSearch,
                  ),
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Text('日付指定'),
                  Switch(
                    value: useExactDay,
                    onChanged: (value) {
                      setState(() {
                        useExactDay = value;
                        useYear = false;
                      });
                    },
                  ),
                  Text('年指定'),
                  Switch(
                    value: useYear,
                    onChanged: (value) {
                      setState(() {
                        useYear = value;
                        useExactDay = false;
                      });
                    },
                  ),
                ],
              ),
              if (useYear)
                DropdownButton<int>(
                  value: selectedYear,
                  onChanged: (year) {
                    setState(() {
                      selectedYear = year!;
                      selectedDate = DateTime(selectedYear);
                    });
                  },
                  items: List.generate(10, (index) {
                    int year = DateTime.now().year - index;
                    return DropdownMenuItem<int>(
                      value: year,
                      child: Text('$year年'),
                    );
                  }),
                ),

              ElevatedButton.icon(
                icon: Icon(Icons.calendar_today),
                label: Text(useExactDay
                    ? DateFormat('yyyy年MM月dd日').format(selectedDate)
                    : useYear
                    ? '$selectedYear年'
                    : DateFormat('yyyy年MM月').format(selectedDate)),
                onPressed: () async {
                  final now = DateTime.now();
                  final firstDate = DateTime(2020, 1, 1);
                  final lastDate = now;
                  DateTime initialDate = selectedDate;
                  if (initialDate.isBefore(firstDate)) initialDate = firstDate;
                  if (initialDate.isAfter(lastDate)) initialDate = lastDate;

                  if (useExactDay) {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initialDate,
                      firstDate: firstDate,
                      lastDate: lastDate,
                      locale: const Locale('ja', 'JP'),
                    );
                    if (picked != null) {
                      setState(() {
                        selectedDate = picked;
                      });
                    }
                  } else if (useYear) {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initialDate,
                      firstDate: DateTime(2000),
                      lastDate: lastDate,
                      initialDatePickerMode: DatePickerMode.year,
                      helpText: '年を選択',
                      locale: const Locale('ja', 'JP'),
                    );
                    if (picked != null) {
                      setState(() {
                        selectedYear = picked.year;
                        selectedDate = DateTime(selectedYear);
                      });
                    }
                  } else {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initialDate,
                      firstDate: firstDate,
                      lastDate: DateTime(now.year, now.month + 1, 0),
                      initialDatePickerMode: DatePickerMode.year,
                      helpText: '年月を選択',
                      locale: const Locale('ja', 'JP'),
                    );
                    if (picked != null) {
                      setState(() {
                        selectedDate = DateTime(picked.year, picked.month);
                      });
                    }
                  }
                },
              ),

              SizedBox(height: 24),
              if (_isLoading) CircularProgressIndicator(),
              if (_error != null)
                Text(_error!, style: TextStyle(color: Colors.red)),
              if (_hasSearched) ...[
              if (_attendanceRecords.isEmpty)
                Text('勤怠記録がありません', style: TextStyle(fontSize: 16,color: Colors.black,fontWeight: FontWeight.bold)),
              if (_attendanceRecords.isNotEmpty) ...[
               Text(
                  '合計勤務時間: ${_getTotalWorkingHours()}時間 ${_getTotalWorkingMinutes()}分',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                _buildAttendanceList(),
                Divider(thickness: 2),
              ],
            ],
              SizedBox(height: 24),
              Text('スタッフ一覧', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Container(
                height: 180,
                child: buildStaffMonthlyWorkTimeList(),
              ),
           ]
          ),
        ),
      ),
    );
  }

  void _onSearch() async {
    final loginId = _loginIdController.text.trim();
    if (loginId.isEmpty) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _attendanceRecords.clear();
      totalWorkingMinutes = 0;
      _hasSearched = true;
      _noRecordsFound = false;
    });
    try {
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('loginId', isEqualTo: loginId)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        setState(() {
          _error = '該当するユーザーが見つかりません';
          _isLoading = false;
        });
        return;
      }
      final uid = userQuery.docs.first.id;
      DateTime startDate;
      DateTime endDate;
      if (useExactDay) {
        startDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
        endDate = startDate.add(Duration(days: 1));
      } else if (useYear) {
        startDate = DateTime(selectedYear, 1, 1);
        endDate = DateTime(selectedYear + 1, 1, 1);
      } else {
        startDate = DateTime(selectedDate.year, selectedDate.month, 1);
        endDate = DateTime(selectedDate.year, selectedDate.month + 1, 1);
      }
      final attendanceQuery = await FirebaseFirestore.instance
          .collection('attendances')
          .where('userId', isEqualTo: uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThan: Timestamp.fromDate(endDate))
          .orderBy('date', descending: true)
          .get();
      if (attendanceQuery.docs.isEmpty) {
        setState(() {
          _noRecordsFound = true;
          _isLoading = false;
        });
        return;
      }
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
    } catch (e, stack) {
      print("❌ エラー発生: $e");
      print("📄 スタック: $stack");
      setState(() {
        _error = 'データの取得中にエラーが発生しました';
        _isLoading = false;
      });
    }
  }
  String _getTotalWorkingHours() {
    int hours = totalWorkingMinutes ~/ 60;
    return hours.toString();
  }
  int _getTotalWorkingMinutes() {
    return totalWorkingMinutes % 60;
  }
  Widget _buildAttendanceList() {
    if (_attendanceRecords.isEmpty && !_isLoading) {
      return Center(child: Text('勤務記録が見つかりません'));
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _attendanceRecords.length,
      itemBuilder: (context, index) {
        final record = _attendanceRecords[index];
        final late = record['late'] == true;
        final overtime = record['overtimeMinutes'];
        final shortage = record['shortageMinutes'];
        return Card(
          child: ListTile(
            title: Text('${record['date']}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('出勤: ${record['clockIn']}'),
                Text('退勤: ${record['clockOut']}'),
                Text('遅刻:${late ? '有' : '無'}'),
                if ((overtime ?? 0) > 0)
                  Text('超過: ${overtime ~/ 60}時間 ${overtime % 60}分'),
                if ((shortage ?? 0) > 0)
                  Text('不足: ${shortage ~/ 60}時間 ${shortage % 60}分'),
                Text('シフト: ${record['shift']}'),
              ],
            ),
          ),
        );
      },
    );
  }
  Future<List<StaffWorkTime>> fetchStaffWithMonthlyWorkTime() async {
    final firestore = FirebaseFirestore.instance;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final staffSnapshot = await firestore
        .collection('users')
        .where('role', isEqualTo: 'staff')
        .get();

    final staffDocs = staffSnapshot.docs;

    // 並列で各スタッフの勤怠データを取得
    final staffList = await Future.wait(staffSnapshot.docs.map((doc) async {
      final uid = doc.id;
      final data = doc.data();
      final pokerName = data['pokerName'] ?? '不明';
      final loginId = data['loginId'] ?? '不明';
      final lastLogin = (data['lastLogin'] as Timestamp?)?.toDate() ?? DateTime(2000);

      final attendanceSnapshot = await firestore
          .collection('attendances')
          .where('userId', isEqualTo: uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .get();

      Duration totalDuration = Duration();
      for (var att in attendanceSnapshot.docs) {
        final attData = att.data();
        final clockIn = (attData['clockIn'] as Timestamp?)?.toDate();
        final clockOut = (attData['clockOut'] as Timestamp?)?.toDate();
        if (clockIn != null && clockOut != null) {
          totalDuration += clockOut.difference(clockIn);
        }
      }

      return StaffWorkTime(
        uid: uid,
        pokerName: pokerName,
        loginId: loginId,
        totalWorkDuration: totalDuration,
        lastLogin: lastLogin,
      );
    }).toList());

    staffList.sort((a, b) => b.lastLogin.compareTo(a.lastLogin));

    return staffList;
  }

  Widget buildStaffMonthlyWorkTimeList() {
    return FutureBuilder<List<StaffWorkTime>>(
      future: fetchStaffWithMonthlyWorkTime(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          print('FutureBuilder Error: ${snapshot.error}');
          return Center(child: Text('エラーが発生しました'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('スタッフが見つかりません'));
        }
        final staffList = snapshot.data!;
        return SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: staffList.length,
            itemBuilder: (context, index) {
              final staff = staffList[index];
              final hours = staff.totalWorkDuration.inHours;
              final minutes = staff.totalWorkDuration.inMinutes % 60;
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StaffAttendancePage(uid: staff.uid),
                    ),
                  );
                },
                child: Container(
                  width: 160,
                  margin: EdgeInsets.all(8),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.person, size: 32, color: Colors.blue),
                          SizedBox(height: 8),
                          Text(staff.pokerName,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Login ID: ${staff.loginId}',
                              style: TextStyle(fontSize: 12)),
                          SizedBox(height: 4),
                          Text('今月: ${hours}時間${minutes}分',
                              style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
class StaffWorkTime {
  final String uid;
  final String pokerName;
  final String loginId;
  final Duration totalWorkDuration;
  final DateTime lastLogin;

  StaffWorkTime({
    required this.uid,
    required this.pokerName,
    required this.loginId,
    required this.totalWorkDuration,
    required this.lastLogin,
  });
}
