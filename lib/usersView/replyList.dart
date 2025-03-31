import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReplyList extends StatelessWidget {
  final String announcementId; // どのお知らせへの返信か識別

  ReplyList({required this.announcementId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("announcements")
          .doc(announcementId)
          .collection("replies")
          .orderBy("createdAt", descending: true) // 🔹 新しい返信を上に表示
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator()); // 🔄 読み込み中
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("まだ返信はありません"));
        }

        var replies = snapshot.data!.docs;

        return ListView.builder(
          itemCount: replies.length,
          itemBuilder: (context, index) {
            var reply = replies[index];
            var content = reply["content"] ?? "（内容なし）";
            var userId = reply["userId"] ?? "匿名";
            var createdAt = reply["createdAt"] != null
                ? (reply["createdAt"] as Timestamp).toDate()
                : DateTime.now();

            return ListTile(
              title: Text(content),
              subtitle: Text("投稿者: $userId"),
              trailing: Text(
                "${createdAt.year}/${createdAt.month}/${createdAt.day} ${createdAt.hour}:${createdAt.minute}",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            );
          },
        );
      },
    );
  }
}
