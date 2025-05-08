import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:intl/intl.dart';

import 'adminAttendanceScan.dart';

class ManualAttendancePage extends StatefulWidget {
  const ManualAttendancePage({super.key});

  @override
  State<ManualAttendancePage> createState() => _ManualAttendancePageState();
}

class _ManualAttendancePageState extends State<ManualAttendancePage> {
  final TextEditingController loginIdController = TextEditingController();
  final TextEditingController pinController = TextEditingController();

  Map<String, dynamic>? selectedUser; // Firestoreから取得したユーザー

  // Firestoreからユーザーを検索
  Future<void> searchUserByLoginId() async {
    final loginId = loginIdController.text.trim();
    if (loginId.isEmpty) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('loginId', isEqualTo: loginId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      setState(() {
        selectedUser = null;
      });
      _showDialog("エラー", "ユーザーが見つかりません");
      return;
    }

    setState(() {
      selectedUser = snapshot.docs.first.data();
    });
  }

  // 手動打刻処理
  Future<void> handleManualAttendance() async {
    if (selectedUser == null) return;

    final inputPin = pinController.text.trim();
    final hashedPin = selectedUser!['hashedPin'];
    final isPinValid = BCrypt.checkpw(inputPin, hashedPin);

    if (!isPinValid) {
      _showDialog("エラー", "PINが正しくありません");
      return;
    }

    final uid = selectedUser!['uid'];
    final result = await handleAttendance(uid, isManual: true);

    // 時刻をフォーマット
    final formattedTime = DateFormat('HH:mm').format(result['time']);
    _showDialog("成功", "${result['type']}：$formattedTime に打刻しました");
    pinController.clear();
    loginIdController.clear();
    setState(() => selectedUser = null);
  }

  // ダイアログ表示
  void _showDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("手動打刻")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: loginIdController,
              decoration: InputDecoration(
                labelText: "ログインID",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: searchUserByLoginId,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (selectedUser != null) ...[
              Card(
                elevation: 2,
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text("PokerName: ${selectedUser!['pokerName'] ?? '未設定'}"),
                  subtitle: Text("UID: ${selectedUser!['uid'] ?? '不明'}"),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "PINコード",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: handleManualAttendance,
                child: const Text("打刻する"),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
