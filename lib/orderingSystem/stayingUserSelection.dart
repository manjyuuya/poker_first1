import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:poker_first/orderingSystem/orderEntry.dart';

class StayingUserSelectionPage extends StatelessWidget {
  const StayingUserSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final usersRef = FirebaseFirestore.instance.collection('users');

    return Scaffold(
      appBar: AppBar(
        title: const Text('滞在中のユーザー選択'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: usersRef.where('isStaying', isEqualTo: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('エラーが発生しました'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final stayingUsers = snapshot.data!.docs;

          if (stayingUsers.isEmpty) {
            return const Center(child: Text('滞在中のユーザーはいません'));
          }

          return ListView.builder(
            itemCount: stayingUsers.length,
            itemBuilder: (context, index) {
              final user = stayingUsers[index];
              final userName = user['pokerName'] ?? '名前未登録';
              final userId = user['uid'];

              return ListTile(
                title: Text(userName),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  // 🎯 注文ページなどに遷移
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderEntryPage(
                        userId: userId,
                        userName: userName,
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
