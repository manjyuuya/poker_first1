import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AnnouncementDetailPage extends StatelessWidget {
  final String title;
  final String content;
  final String date;
  final String postId;

  const AnnouncementDetailPage({
    super.key,
    required this.title,
    required this.content,
    required this.date,
    required this.postId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("お知らせ詳細")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("開催 $date", style: const TextStyle(color: Colors.black, fontSize: 14)),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(content, style: const TextStyle(fontSize: 14)),
            const Divider(height: 20, thickness: 1), // 区切り線
            Expanded(child: ReplyList(postId: postId)), // 🔹 返信一覧を表示
          ],
        ),
      ),
    );
  }
}

// 🔹 返信一覧のウィジェット（ユーザー名を表示）
class ReplyList extends StatelessWidget {
  final String postId;

  const ReplyList({super.key, required this.postId});

  Future<String> _getUserName(String? userId) async {
    if (userId == null || userId.isEmpty) {
      return "匿名"; // userIdがない場合は「匿名」
    }

    try {
      var userDoc = await FirebaseFirestore.instance.collection("users").doc(userId).get();
      if (userDoc.exists && userDoc.data()!.containsKey("name")) {
        return userDoc["name"];
      }
    } catch (e) {
      print("Error fetching user name: $e");
    }
    return "匿名"; // エラーが発生した場合も「匿名」
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("announcements")
          .doc(postId)
          .collection("replies")
          .orderBy("createdAt", descending: true) // 新しい返信を上に表示
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("まだコメントはありません"));
        }

        var replies = snapshot.data!.docs;

        return ListView.builder(
          itemCount: replies.length,
          itemBuilder: (context, index) {
            var reply = replies[index];
            var content = reply["content"] ?? "（内容なし）";
            var userId = reply["userId"] ?? ""; // userIdがnullの場合は空文字をセット
            var createdAt = reply["createdAt"] != null
                ? (reply["createdAt"] as Timestamp).toDate()
                : DateTime.now();

            return FutureBuilder<String>(
              future: _getUserName(userId.isEmpty ? null : userId), // userIdが空ならnullを渡す
              builder: (context, userSnapshot) {
                String userName = userSnapshot.data ?? "匿名";
                return ListTile(
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName, // 🔹 ユーザー名を表示
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(content),
                    ],
                  ),
                  subtitle: Text(
                    "${createdAt.year}/${createdAt.month}/${createdAt.day} ${createdAt.hour}:${createdAt.minute}",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
