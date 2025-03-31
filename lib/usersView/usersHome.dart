import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'announcementDetailPage.dart';
import 'replyPage.dart'; // 返信ページを追加

class UsersHome extends StatefulWidget {
  const UsersHome({super.key});

  @override
  State<UsersHome> createState() => _UsersHomeState();
}

class _UsersHomeState extends State<UsersHome> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("お知らせ")),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('announcements')
            .where('role', isEqualTo: 'admin')
            .snapshots(),
        builder: (context, adminSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('announcements')
                .where('role', isEqualTo: 'staff')
                .snapshots(),
            builder: (context, staffSnapshot) {
              if (adminSnapshot.connectionState == ConnectionState.waiting ||
                  staffSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!adminSnapshot.hasData && !staffSnapshot.hasData) {
                return const Center(child: Text("現在お知らせはありません"));
              }

              List<QueryDocumentSnapshot> announcements = [];
              if (adminSnapshot.hasData) {
                announcements.addAll(adminSnapshot.data!.docs);
              }
              if (staffSnapshot.hasData) {
                announcements.addAll(staffSnapshot.data!.docs);
              }

              announcements.sort((a, b) {
                Timestamp aTime = a['createdAt'] as Timestamp;
                Timestamp bTime = b['createdAt'] as Timestamp;
                return bTime.compareTo(aTime);
              });

              return ListView.builder(
                itemCount: announcements.length,
                itemBuilder: (context, index) {
                  var announcement = announcements[index];
                  var data = announcement.data() as Map<String, dynamic>;
                  String title = data["title"];
                  String content = data["content"];
                  // 開催日を日付だけでフォーマット
                  String formattedDate = (data["date"] as Timestamp).toDate().toLocal().toString().split(" ")[0];
                  String createdAt = (data["createdAt"] as Timestamp)
                      .toDate()
                      .toLocal()
                      .toString()
                      .split(":")[0] + ":" + (data["createdAt"] as Timestamp)
                      .toDate()
                      .toLocal()
                      .toString()
                      .split(":")[1]; // 分までで表示

                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // 開催日は日付だけ
                              Text(
                                "開催 $formattedDate",
                                style: const TextStyle(color: Colors.black, fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // 返信アイコン追加
                              IconButton(
                                icon: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ReplyPage(postId: announcement.id),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            content,
                            maxLines: 3,
                            style: const TextStyle(fontSize: 14),
                          ),
                          // 「詳細」のリンクを常に表示
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AnnouncementDetailPage(
                                    title: title,
                                    content: content,
                                    date: formattedDate,
                                    postId: announcement.id, // 🔹 postId を渡す
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              "...詳細",
                              style: TextStyle(color: Colors.blue, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                          // 投稿時間をカードの右下に表示
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                               createdAt,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
