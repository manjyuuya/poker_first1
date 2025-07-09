import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserDetailPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const UserDetailPage({super.key, required this.userData});

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  int points = 1000; // 仮ポイント
  int visitCount = 5; // 仮来店回数
  DateTime lastVisitDate = DateTime.now().subtract(Duration(days: 2)); // 仮最終来店日

  void _addPoints() {
    setState(() {
      points += 1000;
    });
  }

  void _subtractPoints() {
    setState(() {
      if (points >= 1000) points -= 1000;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.userData;

    return Scaffold(
      appBar: AppBar(
        title: Text("詳細"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildInfoTile("Poker Name", user['pokerName']),
            _buildInfoTile("Login ID", user['loginId']),
            _buildInfoTile("role", user['role']),
            _buildInfoTile("Email", user['email']),
            _buildInfoTile("UID", user['uid']),
            _buildInfoTile("生年月日", user['birthMonthDay']),
            _buildInfoTile("アカウント作成日", user['createdAt']?.toDate()?.toString() ?? "不明"),
            _buildInfoTile("来店回数", "$visitCount 回"),
            _buildInfoTile("最終来店日", "${lastVisitDate.toLocal()}".split(' ')[0]),
            _buildInfoTile("保有ポイント", "$points pt"),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: _addPoints, child: Text("＋1000pt")),
                ElevatedButton(onPressed: _subtractPoints, child: Text("−1000pt")),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // 履歴表示 or 編集画面へ（仮）
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("機能は今後追加されます")));
              },
              child: Text("履歴を表示 / 編集する"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return ListTile(
      title: Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(value),
    );
  }
}
