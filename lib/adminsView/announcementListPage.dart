import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AnnouncementListPage extends StatefulWidget {
  final String currentUserId; // ← 追加

  const AnnouncementListPage({super.key, required this.currentUserId}); // ← 追加

  @override
  _AnnouncementListPageState createState() => _AnnouncementListPageState();
}

class _AnnouncementListPageState extends State<AnnouncementListPage> {
  bool isLoading = false;
  bool isAdminUser = false; // 管理者フラグ
  final user = FirebaseAuth.instance.currentUser; // 現在のログインユーザーを取得

  @override
  void initState() {
    super.initState();
    _checkIfAdmin(); // ユーザーの権限を確認
  }

  Future<void> _checkIfAdmin() async {
    if (user == null) return;

    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();

    if (userDoc.exists) {
      setState(() {
        isAdminUser = userDoc['role'] == 'admin'; // Firestore の role を確認
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("投稿一覧")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('announcements')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
              String userId = announcement["userId"];

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(announcement["title"]),
                  subtitle: Text(announcement["content"]),
                  trailing: user != null && (isAdminUser || userId == widget.currentUserId)
                      ? IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      // 削除確認ダイアログを表示
                      _showDeleteConfirmationDialog(announcementId);
                    },
                  )
                      : null,
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
      await FirebaseFirestore.instance.collection('announcements').doc(announcementId).delete();
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
