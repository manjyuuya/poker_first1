import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ShiftRequestPage extends StatefulWidget {
  const ShiftRequestPage({super.key});

  @override
  State<ShiftRequestPage> createState() => _ShiftRequestPageState();
}

class _ShiftRequestPageState extends State<ShiftRequestPage> {
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _shiftController = TextEditingController();

  // 開始時間と終了時間を保存する変数
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  /// 📅 日付選択ダイアログ
  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(), // デフォルトで今日の日付を選択
      firstDate: DateTime.now(), // 今日以降を選択可能
      lastDate: DateTime(2099), // 未来の制限（任意）
      locale: const Locale('ja', 'JP'), // 日本語に設定
    );

    if (picked != null) {
      setState(() {
        _dateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  /// ⏰ 開始時間選択ダイアログ
  Future<void> _selectStartTime() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _startTime = picked;
        _updateShiftTime(); // 開始時間が選ばれたらUIに反映
      });
    }
  }

  /// ⏰ 終了時間選択ダイアログ
  Future<void> _selectEndTime() async {
    if (_startTime == null) {
      // 開始時間が選択されていない場合、終了時間を選択できないようにする
      return;
    }

    // 開始時間から1分以上遅い時間を制限
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _startTime!.hour, minute: _startTime!.minute + 1), // 開始時間から1分後から開始
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null && (picked.hour > _startTime!.hour || (picked.hour == _startTime!.hour && picked.minute > _startTime!.minute))) {
      setState(() {
        _endTime = picked;
        _updateShiftTime(); // 終了時間が選ばれたらUIに反映
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("終了時間は開始時間より遅く選択してください")),
      );
    }
  }

  /// 開始時間と終了時間をセットして、希望シフトのテキストに反映
  void _updateShiftTime() {
    if (_startTime != null && _endTime != null) {
      setState(() {
        _shiftController.text = "${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}-"
            "${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}";
      });
    } else if (_startTime != null) {
      setState(() {
        // 開始時刻が選択された場合、終了時刻が未選択でも「-」を表示
        _shiftController.text = "${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}-";
      });
    } else if (_endTime != null) {
      setState(() {
        // 終了時刻のみが選択された場合は「〜」で表示
        _shiftController.text = "〜${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}";
      });
    }
  }

  // 時間の再設定をするためのリセット機能
  void _resetShiftTimes() {
    setState(() {
      _startTime = null;
      _endTime = null;
      _shiftController.clear();
    });
  }

  void _submitShiftRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("ユーザーがログインしていません");
      return;
    }

    await FirebaseFirestore.instance.collection('schedules').add({
      'userId': user.uid,
      'userName': user.displayName ?? 'Unknown',
      'role': "staff",
      'date': _dateController.text,
      'shift': _shiftController.text,
      'confirmed': false,
      'denied': false,
      'approvedBy': null,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("シフト希望を提出しました")),
    );

    _dateController.clear();
    _shiftController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("シフト希望提出")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _dateController,
              readOnly: true, // 手動入力を防ぐ
              decoration: const InputDecoration(
                labelText: "希望日",
                suffixIcon: Icon(Icons.calendar_today), // カレンダーアイコン
              ),
              onTap: _selectDate, // タップで日付選択
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _shiftController,
                    readOnly: true, // 手動入力を防ぐ
                    decoration: const InputDecoration(
                      labelText: "希望シフト",
                      suffixIcon: Icon(Icons.access_time), // 時計アイコン
                    ),
                    onTap: () {
                      // 最初に開始時間を選んだ後に終了時間を選択
                      if (_startTime == null) {
                        _selectStartTime();
                      } else {
                        _selectEndTime();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // リセットボタンを追加
            if (_startTime != null && _endTime != null)
              ElevatedButton(
                onPressed: _resetShiftTimes,
                child: const Text("時間を再設定"),
              ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _submitShiftRequest,
              child: const Text("提出"),
            ),
          ],
        ),
      ),
    );
  }
}
