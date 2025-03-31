import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:poker_first/staffsView/staffPostList.dart';

class StaffPost extends StatefulWidget {
  const StaffPost({super.key});

  @override
  State<StaffPost> createState() => _StaffPostState();
}

class _StaffPostState extends State<StaffPost> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  DateTime? _selectedDate;
  String _selectedType = "tournament"; // デフォルト値

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Firestoreに投稿を保存
  Future<void> _postAnnouncement() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("ユーザーがログインしていません");
      return;
    }
    if (_formKey.currentState!.validate() && _selectedDate != null) {
      await _firestore.collection('announcements').add({
        "title": _titleController.text,
        "content": _contentController.text,
        "date": Timestamp.fromDate(_selectedDate!),
        "type": _selectedType,
        "createdAt": Timestamp.now(),
        "userId": user.uid,
        "role": "staff", // スタッフの投稿を示す
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("投稿が完了しました")));

      // フォームをクリア
      _titleController.clear();
      _contentController.clear();
      setState(() {
        _selectedDate = null;
        _selectedType = "tournament";
      });
    }
  }

  // 日付選択ダイアログ
  Future<void> _pickDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("スタッフ投稿"),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StaffPostListPage()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: "タイトル"),
                    validator: (value) =>
                    value!.isEmpty ? "タイトルを入力してください" : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _contentController,
                    decoration: const InputDecoration(labelText: "内容"),
                    maxLines: 3,
                    validator: (value) =>
                    value!.isEmpty ? "内容を入力してください" : null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _pickDate,
                        child: const Text("日付を選択"),
                      ),
                      const SizedBox(width: 10),
                      Text(_selectedDate == null
                          ? "未選択"
                          : _selectedDate!.toLocal().toString().split(" ")[0]),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField(
                    value: _selectedType,
                    items: const [
                      DropdownMenuItem(value: "tournament", child: Text("トーナメント")),
                      DropdownMenuItem(value: "event", child: Text("イベント")),
                      DropdownMenuItem(value: "notice", child: Text("お知らせ")),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value.toString();
                      });
                    },
                    decoration: const InputDecoration(labelText: "投稿タイプ"),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      onPressed: _postAnnouncement,
                      child: const Text("投稿する"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}