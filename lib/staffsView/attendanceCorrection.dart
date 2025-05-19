import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class AttendanceCorrectionPage extends StatefulWidget {
  const AttendanceCorrectionPage({Key? key}) : super(key: key);

  @override
  State<AttendanceCorrectionPage> createState() => _AttendanceCorrectionPageState();
}

class _AttendanceCorrectionPageState extends State<AttendanceCorrectionPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  DateTime? _originalClockInDateTime;
  DateTime? _originalClockOutDateTime;

  DateTime? _requestedClockInDateTime;
  DateTime? _requestedClockOutDateTime;

  final TextEditingController _reasonController = TextEditingController();

  Map<DateTime, Map<String, dynamic>> _attendanceMap = {};

  @override
  void initState() {
    super.initState();
    _fetchUserAttendance();
  }

  Future<void> _fetchUserAttendance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('attendances')
        .where('userId', isEqualTo: user.uid)
        .get();


    final Map<DateTime, Map<String, dynamic>> tempMap = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final clockIn = data['clockIn']?.toDate();
      if (clockIn == null) continue;

      final dateKey = DateTime(clockIn.year, clockIn.month, clockIn.day);
      tempMap[dateKey] = data;
    }

    setState(() {
      _attendanceMap = tempMap;
    });
  }

  bool _isWorkedDay(DateTime day) {
    final dayKey = DateTime(day.year, day.month, day.day);
    return _attendanceMap.containsKey(dayKey);
  }

  Future<void> _pickDateTime({
    required String label,
    required Function(DateTime) onPicked,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDay ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    onPicked(picked);
  }

  Future<void> _submitRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _selectedDay == null) return;
    final userId = user.uid;

    // FirestoreからpokerNameを取得
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final pokerName = userDoc.data()?['pokerName'] ?? 'No Name';

    await FirebaseFirestore.instance.collection('attendanceCorrections').add({
      'userId': user.uid,
      'userName': pokerName,
      'targetDate': Timestamp.fromDate(_selectedDay!),
      'originalClockInDateTime': _originalClockInDateTime != null ? Timestamp.fromDate(_originalClockInDateTime!) : null,
      'originalClockOutDateTime': _originalClockOutDateTime != null ? Timestamp.fromDate(_originalClockOutDateTime!) : null,
      'requestedClockInDateTime': _requestedClockInDateTime != null ? Timestamp.fromDate(_requestedClockInDateTime!) : null,
      'requestedClockOutDateTime': _requestedClockOutDateTime != null ? Timestamp.fromDate(_requestedClockOutDateTime!) : null,
      'reason': _reasonController.text.trim(),
      'status': 'pending',
      'createdAt': Timestamp.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('修正申請を送信しました')),
    );

    setState(() {
      _requestedClockInDateTime = null;
      _requestedClockOutDateTime = null;
      _reasonController.clear();
    });
  }

  String _formatTime(DateTime? dt) {
    return dt != null ? DateFormat.Hm().format(dt) : '---';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('勤怠修正申請')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ListView(
          children: [
            TableCalendar(
              focusedDay: _focusedDay,
              firstDay: DateTime.utc(2020),
              lastDay: DateTime.utc(2030),
              calendarFormat: CalendarFormat.month,
              availableCalendarFormats: const {
                CalendarFormat.month: '月',
              },
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;

                  final key = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
                  final data = _attendanceMap[key];

                  _originalClockInDateTime = data?['clockIn']?.toDate();
                  _originalClockOutDateTime = data?['clockOut']?.toDate();
                });
              },
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  final isWorked = _isWorkedDay(day);
                  return Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isWorked ? Colors.blue.shade100 : null,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        color: isWorked ? Colors.black : Colors.grey.shade700,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedDay != null)
              ListTile(
                title: Text("選択日: ${DateFormat.yMMMd().format(_selectedDay!)}"),
                subtitle: Text(
                  "元の出勤: ${_formatTime(_originalClockInDateTime)} / 元の退勤: ${_formatTime(_originalClockOutDateTime)}",
                ),
              ),
            const Divider(),
            ListTile(
              title: const Text('希望する出勤時刻'),
              subtitle: Text(_requestedClockInDateTime != null
                  ? _formatTime(_requestedClockInDateTime)
                  : '未選択'),
              trailing: IconButton(
                icon: const Icon(Icons.access_time),
                onPressed: () {
                  _pickDateTime(
                    label: '出勤',
                    onPicked: (picked) => setState(() => _requestedClockInDateTime = picked),
                  );
                },
              ),
            ),
            ListTile(
              title: const Text('希望する退勤時刻'),
              subtitle: Text(_requestedClockOutDateTime != null
                  ? _formatTime(_requestedClockOutDateTime)
                  : '未選択'),
              trailing: IconButton(
                icon: const Icon(Icons.access_time),
                onPressed: () {
                  _pickDateTime(
                    label: '退勤',
                    onPicked: (picked) => setState(() => _requestedClockOutDateTime = picked),
                  );
                },
              ),
            ),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: '修正理由',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitRequest,
              child: const Text('修正申請を送信'),
            ),
          ],
        ),
      ),
    );
  }
}
