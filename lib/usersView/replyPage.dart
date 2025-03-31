import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 追加
import 'package:flutter/material.dart';

class ReplyPage extends StatefulWidget {
  final String postId;

  const ReplyPage({super.key, required this.postId});

  @override
  State<ReplyPage> createState() => _ReplyPageState();
}

class _ReplyPageState extends State<ReplyPage> {
  final TextEditingController _replyController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // 追加

  void _sendReply() async {
    if (_replyController.text.isNotEmpty) {
      User? user = _auth.currentUser; // 現在のユーザーを取得

      if (user != null) {
        await _firestore
            .collection('announcements')
            .doc(widget.postId)
            .collection('replies')
            .add({
          'content': _replyController.text,
          'createdAt': FieldValue.serverTimestamp(),
          'userId': user.uid, // userId を保存
        });

        _replyController.clear();
        Navigator.pop(context); // 返信完了後に戻る
      } else {
        // ユーザーがログインしていない場合のエラーハンドリング
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ログインしていません。')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("返信")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _replyController,
              decoration: const InputDecoration(labelText: "返信を入力"),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _sendReply,
              child: const Text("送信"),
            ),
          ],
        ),
      ),
    );
  }
}
