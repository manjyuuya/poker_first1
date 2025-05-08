import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:poker_first/adminsView/manualAttendance.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:collection/collection.dart';

class AttendanceScanPage extends StatefulWidget {
  const AttendanceScanPage({super.key});

  @override
  State<AttendanceScanPage> createState() => _AttendanceScanPageState();
}

class _AttendanceScanPageState extends State<AttendanceScanPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _scanned = false;

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (_scanned) return;
      _scanned = true;

      try {
        final data = jsonDecode(scanData.code!);
        final userId = data['uid'];
        await _startAttendanceFlow(userId);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("読み取りエラー")));
        Navigator.pop(context);
      }
    });
  }

  void _debugSkip() async {
    const userId = "debugUser123";
    await _startAttendanceFlow(userId);
  }

  Future<void> _startAttendanceFlow(String userId) async {
    final result = await handleAttendance(userId);

    if (result['type'] == '未退勤あり') {
      final manualTime = await _showManualClockOutDialog(result['clockIn'] as DateTime);
      if (manualTime != null) {
        final retry = await handleAttendance(userId, isManual: true, manualClockOut: manualTime);
        if (retry['type'] == '退勤（手動）') {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("手動退勤を記録しました")));
          if (mounted) Navigator.pop(context);
          return; // ❗ ここで return を追加（以降の pop を防ぐ）
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(retry['message'] ?? "エラー")));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("手動退勤をキャンセルしました")));
      }

      if (mounted) Navigator.pop(context); // ダイアログ後に戻る
      return;
    }
    if (result['type'] == '出勤') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("出勤を記録しました")));
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.pop(context);
    } else if (result['type'] == '退勤') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("退勤を記録しました")));
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.pop(context);
    }// 正常出退勤後に戻る
  }

  Future<DateTime?> _showManualClockOutDialog(DateTime clockIn) async {
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    return await showDialog<DateTime>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('退勤時間を入力'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: clockIn,
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => selectedDate = picked);
                      }
                    },
                    child: Text("日付選択: ${DateFormat('yyyy/MM/dd').format(selectedDate)}"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setState(() => selectedTime = picked);
                      }
                    },
                    child: Text("時間選択: ${selectedTime.format(context)}"),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text("キャンセル"),
                  onPressed: () => Navigator.of(context).pop(null),
                ),
                ElevatedButton(
                  child: const Text("退勤記録"),
                  onPressed: () {
                    final combined = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );
                    Navigator.of(context).pop(combined);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR打刻'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_calendar),
            tooltip: '手動打刻',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ManualAttendancePage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: QRView(key: qrKey, onQRViewCreated: _onQRViewCreated),
          ),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: _debugSkip,
                  child: const Text("デバッグ用：打刻スキップ"),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

Future<Map<String, dynamic>> handleAttendance(String userId, {
  bool isManual = false,
  DateTime? manualClockOut,
}) async {
  final now = DateTime.now();
  final dateOnly = DateTime(now.year, now.month, now.day);
  final dateKey = "${userId}_${DateFormat('yyyyMMdd').format(dateOnly)}";

  final attendanceRef = FirebaseFirestore.instance.collection("attendances");

  // 🔍 未退勤（clockOut == null）データがあるかチェック
  final unresolvedQuery = await attendanceRef
      .where("userId", isEqualTo: userId)
      .where("clockOut", isNull: true)
      .get();

  if (unresolvedQuery.docs.isNotEmpty) {
    final unresolvedDoc = unresolvedQuery.docs.first;
    final docData = unresolvedDoc.data();
    final clockIn = (docData['clockIn'] as Timestamp).toDate();

    final shiftQuery = await FirebaseFirestore.instance
        .collection("shifts")
        .where("userId", isEqualTo: userId)
        .where("date", isGreaterThanOrEqualTo: DateFormat("yyyy-MM-dd").format(clockIn.subtract(const Duration(hours: 5))))
        .where("date", isLessThanOrEqualTo: DateFormat("yyyy-MM-dd").format(clockIn.add(const Duration(hours: 5))))
        .get();

    final matchedShift = shiftQuery.docs.firstWhereOrNull((doc) {
      final start = (doc['start'] as Timestamp).toDate();
      final end = (doc['end'] as Timestamp).toDate();
      return clockIn.isAfter(start.subtract(const Duration(hours: 5))) &&
          clockIn.isBefore(end.add(const Duration(hours: 5)));
    });

    if (matchedShift != null && manualClockOut == null) {
      final shiftEnd = (matchedShift['end'] as Timestamp).toDate();
      final diffHours = now.difference(shiftEnd).inHours.abs();

      if (diffHours <= 5) {
        final actualMinutes = now.difference(clockIn).inMinutes;
        final scheduledMinutes = shiftEnd.difference((matchedShift['start'] as Timestamp).toDate()).inMinutes;

        int overtimeMinutes = 0;
        int shortageMinutes = 0;
        if (actualMinutes > scheduledMinutes) {
          overtimeMinutes = actualMinutes - scheduledMinutes;
        } else if (actualMinutes < scheduledMinutes) {
          shortageMinutes = scheduledMinutes - actualMinutes;
        }

        final totalMinutes = now.difference(clockIn).inMinutes;
        final nightMinutes = calculateNightMinutes(clockIn, now);

        await attendanceRef.doc(unresolvedDoc.id).update({
          'clockOut': Timestamp.fromDate(now),
          'overtimeMinutes': overtimeMinutes,
          'shortageMinutes': shortageMinutes,
          'totalMinutes': totalMinutes,
          'nightMinutes': nightMinutes,
        });

        return {'type': '退勤（自動）', 'time': now};
      }
    }

    if (manualClockOut == null) {
      return {
        'type': '未退勤あり',
        'clockIn': clockIn,
        'docId': unresolvedDoc.id,
        'message': '前回の退勤が未記録です。退勤時間を入力してください。'
      };
    }

    if (manualClockOut.isBefore(clockIn)) {
      return {
        'type': 'エラー',
        'message': '退勤時間は出勤時間より後に設定してください。'
      };
    }
    if (manualClockOut.isAfter(now)) {
      return {
        'type': 'エラー',
        'message': '退勤時間を未来に設定することはできません。'
      };
    }

    int overtimeMinutes = 0;
    int shortageMinutes = 0;
    if (matchedShift != null) {
      final shiftStart = (matchedShift['start'] as Timestamp).toDate();
      final shiftEnd = (matchedShift['end'] as Timestamp).toDate();
      final scheduledMinutes = shiftEnd.difference(shiftStart).inMinutes;
      final actualMinutes = manualClockOut.difference(clockIn).inMinutes;

      if (actualMinutes > scheduledMinutes) {
        overtimeMinutes = actualMinutes - scheduledMinutes;
      } else if (actualMinutes < scheduledMinutes) {
        shortageMinutes = scheduledMinutes - actualMinutes;
      }
    }

    final totalMinutes = manualClockOut.difference(clockIn).inMinutes;
    final nightMinutes = calculateNightMinutes(clockIn, manualClockOut);

    await attendanceRef.doc(unresolvedDoc.id).update({
      'clockOut': Timestamp.fromDate(manualClockOut),
      'overtimeMinutes': overtimeMinutes,
      'shortageMinutes': shortageMinutes,
      'totalMinutes': totalMinutes,
      'nightMinutes': nightMinutes,
    });

    return {'type': '退勤（手動）', 'time': manualClockOut};
  }

  // 🕐 通常の出勤/退勤処理へ
  final docRef = attendanceRef.doc(dateKey);
  final doc = await docRef.get();

  final shiftQuery = await FirebaseFirestore.instance
      .collection("shifts")
      .where("userId", isEqualTo: userId)
      .where("date", isEqualTo: DateFormat("yyyy-MM-dd").format(dateOnly))
      .get();
  final shifts = shiftQuery.docs;

  if (!doc.exists) {
    final matchedShift = shifts.firstWhereOrNull((doc) {
      final start = (doc['start'] as Timestamp).toDate();
      final end = (doc['end'] as Timestamp).toDate();
      return now.isAfter(start.subtract(const Duration(hours: 5))) &&
          now.isBefore(end.add(const Duration(hours: 5)));
    });

    await docRef.set({
      'userId': userId,
      'date': Timestamp.fromDate(dateOnly),
      'clockIn': Timestamp.fromDate(now),
      'clockOut': null,
      'isManual': isManual,
      'late': false,
      'absent': false,
      'overtimeMinutes': 0,
      'shortageMinutes': 0,
      'shiftId': matchedShift?.id,
    });

    if (matchedShift != null) {
      final shiftStart = (matchedShift['start'] as Timestamp).toDate();
      if (now.isAfter(shiftStart)) {
        await docRef.update({'late': true});
      } else {
        final earlyMinutes = shiftStart.difference(now).inMinutes;
        await docRef.update({'overtimeMinutes': earlyMinutes});
      }
    }

    return {'type': '出勤', 'time': now};
  } else {
    final docData = doc.data();
    final clockIn = (docData?['clockIn'] as Timestamp).toDate();
    final clockOut = now;

    int overtimeMinutes = 0;
    int shortageMinutes = 0;

    final matchedShift = shifts.firstWhereOrNull((doc) {
      final start = (doc['start'] as Timestamp).toDate();
      final end = (doc['end'] as Timestamp).toDate();
      return clockIn.isAfter(start.subtract(const Duration(hours: 5))) &&
          clockIn.isBefore(end.add(const Duration(hours: 5)));
    });

    if (matchedShift != null) {
      final shiftStart = (matchedShift['start'] as Timestamp).toDate();
      final shiftEnd = (matchedShift['end'] as Timestamp).toDate();
      final scheduledMinutes = shiftEnd.difference(shiftStart).inMinutes;
      final actualMinutes = clockOut.difference(clockIn).inMinutes;

      if (actualMinutes > scheduledMinutes) {
        overtimeMinutes = actualMinutes - scheduledMinutes;
      } else if (actualMinutes < scheduledMinutes) {
        shortageMinutes = scheduledMinutes - actualMinutes;
      }
    }

    final totalMinutes = clockOut.difference(clockIn).inMinutes;
    final nightMinutes = calculateNightMinutes(clockIn, clockOut);

    await docRef.update({
      'clockOut': Timestamp.fromDate(clockOut),
      'overtimeMinutes': overtimeMinutes,
      'shortageMinutes': shortageMinutes,
      'totalMinutes': totalMinutes,
      'nightMinutes': nightMinutes,
    });

    return {'type': '退勤', 'time': now};
  }
}

int calculateNightMinutes(DateTime clockIn, DateTime clockOut) {
  const int nightStartHour = 22;
  const int nightEndHour = 5;

  int totalNightSeconds = 0;
  DateTime current = clockIn;

  while (current.isBefore(clockOut)) {
    final next = current.add(const Duration(minutes: 1));
    final hour = current.hour;

    // 深夜帯判定：22:00〜24:00 or 0:00〜5:00
    if (hour >= nightStartHour || hour < nightEndHour) {
      // 1分未満の端数がある場合の対応（最後のループなど）
      final end = next.isAfter(clockOut) ? clockOut : next;
      totalNightSeconds += end.difference(current).inSeconds;
    }

    current = next;
  }

  // 分単位に切り捨て変換
  return totalNightSeconds ~/ 60;
}

