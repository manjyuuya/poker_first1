import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StaffPostListPage extends StatefulWidget {
  const StaffPostListPage({super.key});

  @override
  _StaffPostListPageState createState() => _StaffPostListPageState();
}

class _StaffPostListPageState extends State<StaffPostListPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("ログインしてください")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("自分の投稿一覧")),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('announcements')
            .where('userId', isEqualTo: user.uid) // 自分の投稿のみ取得
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("投稿がありません"));
          }

          var announcements = snapshot.data!.docs;

          return ListView.builder(
            itemCount: announcements.length,
            itemBuilder: (context, index) {
              var announcement = announcements[index].data() as Map<String, dynamic>;
              String announcementId = announcements[index].id;

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(announcement["title"]),
                  subtitle: Text(announcement["content"]),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      // 削除確認ダイアログを表示
                      _showDeleteConfirmationDialog(announcementId);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // 削除確認ダイアログの表示
  Future<void> _showDeleteConfirmationDialog(String announcementId) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('削除の確認'),
          content: const Text('本当に削除しますか？'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // ダイアログを閉じる
              },
              child: const Text('削除しない'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // ダイアログを閉じる
                await _deleteAnnouncement(announcementId); // 削除処理を実行
              },
              child: const Text('削除'),
            ),
          ],
        );
      },
    );
  }

  // 投稿削除処理
  Future<void> _deleteAnnouncement(String announcementId) async {
    setState(() {
      isLoading = true;
    });

    try {
      await _firestore.collection('announcements').doc(announcementId).delete();
      _showSnackBar("投稿が削除されました");
    } catch (e) {
      print(e);
      _showSnackBar("削除に失敗しました");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // SnackBarを表示する関数
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}
