import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReservationEditPage extends StatefulWidget {
  final String reservationId;

  const ReservationEditPage({super.key, required this.reservationId});

  @override
  State<ReservationEditPage> createState() => _ReservationEditPageState();
}

class _ReservationEditPageState extends State<ReservationEditPage> {
  String _status = 'reserved';
  final _memoController = TextEditingController();
  bool _isLoading = true;

  // 表示ラベルと内部値のマップ
  final Map<String, String> statusOptions = {
    'reserved': '予約済み',
    'cancelled': 'キャンセル',
  };

  @override
  void initState() {
    super.initState();
    _fetchReservation();
  }

  void _fetchReservation() async {
    final doc = await FirebaseFirestore.instance
        .collection('reservations')
        .doc(widget.reservationId)
        .get();

    final data = doc.data();
    if (data != null) {
      setState(() {
        _status = data['status'] ?? 'reserved';
        _memoController.text = data['memo'] ?? '';
        _isLoading = false;
      });
    }
  }

  void _saveChanges() async {
    await FirebaseFirestore.instance
        .collection('reservations')
        .doc(widget.reservationId)
        .update({
      'status': _status,
      'memo': _memoController.text,
    });

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('予約情報を更新しました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('予約の編集')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            /// ステータス選択（表示ラベルと内部値を分離）
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'ステータス'),
              items: statusOptions.entries
                  .map((entry) => DropdownMenuItem<String>(
                value: entry.key,
                child: Text(entry.value),
              ))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _status = val);
              },
            ),

            const SizedBox(height: 20),

            /// メモ欄
            TextFormField(
              controller: _memoController,
              decoration: const InputDecoration(labelText: 'メモ'),
              maxLines: 3,
            ),

            const Spacer(),

            /// 保存ボタン
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('変更を保存'),
              onPressed: _saveChanges,
            ),
          ],
        ),
      ),
    );
  }
}
