import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StaffDetailPage extends StatefulWidget {
  final String staffId;
  final Map<String, dynamic> staffData;

  const StaffDetailPage({
    super.key,
    required this.staffId,
    required this.staffData,
  });

  @override
  State<StaffDetailPage> createState() => _StaffDetailPageState();
}

class _StaffDetailPageState extends State<StaffDetailPage> {
  late TextEditingController _nameController;
  late TextEditingController _loginIdController;
  late TextEditingController _hourlyWageController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.staffData['pokerName']);
    _loginIdController = TextEditingController(text: widget.staffData['loginId']);
    _hourlyWageController = TextEditingController(
      text: widget.staffData['hourlyWage']?.toString() ?? '',
    );
  }

  Future<void> _saveStaffData() async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(widget.staffId);
    await docRef.update({
      'name': _nameController.text.trim(),
      'loginId': _loginIdController.text.trim(),
      'hourlyWage': int.tryParse(_hourlyWageController.text.trim()) ?? 0,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('スタッフ情報を更新しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('スタッフ詳細')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '名前'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _loginIdController,
              decoration: const InputDecoration(labelText: 'ログインID'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _hourlyWageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '時給（円）'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveStaffData,
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
