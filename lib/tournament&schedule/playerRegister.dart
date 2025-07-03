import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PlayerRegisterPage extends StatelessWidget {
  final String tournamentId;

  const PlayerRegisterPage({super.key, required this.tournamentId});

  Future<void> _registerPlayer(BuildContext context, Map<String, dynamic> userData) async {
    // トーナメント情報を取得して状態チェック
    final tournamentDoc = await FirebaseFirestore.instance.collection('tournaments').doc(tournamentId).get();
    final tournamentData = tournamentDoc.data() as Map<String, dynamic>? ?? {};

    final isOpen = tournamentData['isOpen'] ?? true;
    final registerCloseTimestamp = tournamentData['registerClose'] as Timestamp?;
    final registerClose = registerCloseTimestamp?.toDate();

    final now = DateTime.now();

    if (!isOpen || (registerClose != null && now.isAfter(registerClose))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('参加登録は締め切られています。')),
      );
      return; // 以降の登録処理は行わない
    }

    // userId取得
    final userId = userData['id'] ?? userData['uid'] ?? userData['userId'];
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ユーザーIDが不明です')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('参加登録確認'),
        content: Text('${userData['pokerName'] ?? '顧客'} さんを参加者として登録しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('参加登録')),
        ],
      ),
    );

    if (confirmed != true) return;

    final playersRef = FirebaseFirestore.instance
        .collection('tournaments')
        .doc(tournamentId)
        .collection('players')
        .doc(userId);

    final doc = await playersRef.get();

    if (doc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('すでに参加登録済みです')));
      return;
    }

    final initialStack = tournamentData['initialStack'] ?? 20000;

    await playersRef.set({
      'userId': userId,
      'userName': userData['pokerName'] ?? '',
      'chipStack': initialStack,
      'isBusted': false,
      'reentryCount': 0,
      'addonCount': 0,
      'joinedAt': FieldValue.serverTimestamp(),
      'bustTime': null,
      'memo': '',
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${userData['pokerName'] ?? '顧客'} さんを参加登録しました')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('参加者登録')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('isStaying', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text('現在、店舗にいる顧客はいません'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final user = docs[index];
              final userData = user.data() as Map<String, dynamic>;

              return ListTile(
                title: Text(userData['pokerName'] ?? '名前なし'),
                onTap: () => _registerPlayer(context, {...userData, 'id': user.id}),
              );
            },
          );
        },
      ),
    );
  }
}
