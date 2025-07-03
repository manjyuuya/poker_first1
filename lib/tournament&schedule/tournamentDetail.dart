import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:poker_first/tournament&schedule/playerRegister.dart';
import 'package:poker_first/tournament&schedule/playersList.dart';
import 'blindTimer.dart';

class TournamentDetailPage extends StatelessWidget {
  final String tournamentId;

  const TournamentDetailPage({super.key, required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('トーナメント詳細'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: '参加者登録',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlayerRegisterPage(tournamentId: tournamentId),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: '参加者リスト',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlayersListPage(tournamentId: tournamentId),
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('tournaments').doc(tournamentId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('データの取得に失敗しました'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final name = data['name'] ?? '無名トーナメント';
          final date = (data['date'] as Timestamp).toDate();
          final startTime = (data['startTime'] as Timestamp?)?.toDate();
          final registerTime = (data['registerClose'] as Timestamp?)?.toDate();
          final entryFee = data['entryFee'];
          final reentryFee = data['reentryFee'];
          final addonFee = data['addonFee'];
          final blindStructure = data['blindStructure'] ?? '';
          final description = data['description'] ?? '';
          final isOpen = data['isOpen'] ?? true;

          // ステータス判定ロジック
          final now = DateTime.now();
          String statusText = '不明';
          Color statusColor = Colors.grey;

          if (!isOpen) {
            statusText = '終了';
            statusColor = Colors.grey;
          } else if (registerTime != null && now.isBefore(registerTime)) {
            statusText = '受付中';
            statusColor = Colors.green;
          } else {
            statusText = '受付終了';
            statusColor = Colors.orange;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today),
                  const SizedBox(width: 8),
                  Text(DateFormat('yyyy/MM/dd').format(date)),
                ],
              ),
              if (startTime != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time),
                    const SizedBox(width: 8),
                    Text('開始: ${DateFormat('HH:mm').format(startTime)}'),
                  ],
                ),
              ],
              if (registerTime != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.timer_off),
                    const SizedBox(width: 8),
                    Text('レジスト終了: ${DateFormat('HH:mm').format(registerTime)}'),
                  ],
                ),
              ],
              const Divider(height: 32),
              _feeRow('エントリー費', entryFee),
              _feeRow('リエントリー費', reentryFee),
              _feeRow('アドオン費', addonFee),
              const Divider(height: 32),
              ListTile(
                title: const Text('ブラインド構成'),
                subtitle: Text((blindStructure is num && blindStructure > 0)
                    ? '$blindStructure分'
                    : '未設定'),
              ),
              const Divider(height: 32),
              ListTile(
                title: const Text('備考'),
                subtitle: Text(description.isNotEmpty ? description : 'なし'),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 16,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.timer),
                  label: const Text('ブラインドタイマーを開く'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BlindTimerPage(tournamentId: tournamentId),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _feeRow(String label, dynamic amount) {
    return amount != null
        ? ListTile(
      title: Text(label),
      trailing: Text('¥${amount.toString()}'),
    )
        : const SizedBox.shrink();
  }
}
