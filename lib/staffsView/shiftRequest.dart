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
  final List<Map<String, dynamic>> _shiftList = [];

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  DateTime? _selectedDate;

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2099),
      locale: const Locale('ja', 'JP'),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text =
        "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  Future<void> _selectEndTime() async {
    if (_startTime == null) return;

    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime!,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  void _addShiftToList() {
    if (_selectedDate == null || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("日付・開始・終了時間をすべて選択してください")),
      );
      return;
    }

    final start = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _startTime!.hour,
      _startTime!.minute,
    );

    // 🔽 翌日になるかを判定（24時超え対応）
    DateTime end = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _endTime!.hour,
      _endTime!.minute,
    );
    if (_endTime!.hour < _startTime!.hour) {
      end = end.add(const Duration(days: 1));
    }

    final shiftText =
        "${_startTime!.format(context)} - ${_endTime!.format(context)}";

    setState(() {
      _shiftList.add({
        'start': start,
        'end': end,
        'shift': shiftText,
      });
      _startTime = null;
      _endTime = null;
    });
  }

  Future<void> _submitShiftRequests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _selectedDate == null || _shiftList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("シフトを入力してください")),
      );
      return;
    }

    final dateKey = _dateController.text.replaceAll("-", "");

    // 🔽 すでに提出済みのシフト件数を取得（同日＋同ユーザーの件数）
    final existingSnapshot = await FirebaseFirestore.instance
        .collection('shifts')
        .where('userId', isEqualTo: user.uid)
        .where('date', isEqualTo: _dateController.text)
        .get();

    final existingCount = existingSnapshot.docs.length;

    final batch = FirebaseFirestore.instance.batch();

    for (var i = 0; i < _shiftList.length; i++) {
      final shift = _shiftList[i];
      final docId = "${user.uid}_${dateKey}_${existingCount + i}";

      final docRef = FirebaseFirestore.instance.collection('shifts').doc(docId);

      batch.set(docRef, {
        'userId': user.uid,
        'userName': user.displayName ?? 'Unknown',
        'role': 'staff',
        'date': _dateController.text,
        'shift': shift['shift'],
        'start': Timestamp.fromDate(shift['start']),
        'end': Timestamp.fromDate(shift['end']),
        'confirmed': false,
        'denied': false,
        'approvedBy': null,
      });
    }

    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("シフト希望を提出しました")),
    );

    setState(() {
      _shiftList.clear();
      _dateController.clear();
      _selectedDate = null;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("シフト希望提出")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _dateController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: "希望日",
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: _selectDate,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectStartTime,
                    child: Text(_startTime == null
                        ? "開始時間を選択"
                        : "開始: ${_startTime!.format(context)}"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectEndTime,
                    child: Text(_endTime == null
                        ? "終了時間を選択"
                        : "終了: ${_endTime!.format(context)}"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _addShiftToList,
              child: const Text("シフトを追加"),
            ),
            const SizedBox(height: 20),
            if (_shiftList.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _shiftList.length,
                  itemBuilder: (context, index) {
                    final shift = _shiftList[index];
                    return ListTile(
                      title: Text("${shift['shift']}"),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            _shiftList.removeAt(index);
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _submitShiftRequests,
              child: const Text("提出"),
            ),
          ],
        ),
      ),
    );
  }
}

