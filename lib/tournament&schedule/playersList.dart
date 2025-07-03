import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PlayersListPage extends StatefulWidget {
  final String tournamentId;

  const PlayersListPage({super.key, required this.tournamentId});

  @override
  State<PlayersListPage> createState() => _PlayersListPageState();
}

class _PlayersListPageState extends State<PlayersListPage> {
  late CollectionReference playersRef;
  int initialStack = 20000;
  int addonChipAmount = 10000; // アドオン時に追加するチップ量（例）

  @override
  void initState() {
    super.initState();
    playersRef = FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .collection('players');
    _fetchInitialStack();
  }

  Future<void> _fetchInitialStack() async {
    final tournamentDoc = await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .get();
    final data = tournamentDoc.data() as Map<String, dynamic>? ?? {};
    setState(() {
      initialStack = data['initialStack'] ?? 20000;
      addonChipAmount = data['addonStack'] ?? 10000;
    });
  }

  Future<void> _markBusted(String playerId) async {
    await playersRef.doc(playerId).update({
      'isBusted': true,
      'bustTime': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _reentryPlayer(String playerId) async {
    await playersRef.doc(playerId).update({
      'isBusted': false,
      'bustTime': null,
      'chipStack': initialStack,
      'reentryCount': FieldValue.increment(1),
    });
  }

  Future<void> _addonPlayer(String playerId) async {
    await playersRef.doc(playerId).update({
      'addonCount': FieldValue.increment(1),
      'chipStack': FieldValue.increment(addonChipAmount),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('参加者リスト'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: playersRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text('参加者がいません'));
          }

          // ✅ 集計処理
          int totalEntries = 0;
          int totalAddons = 0;
          int remainingPlayers = 0;

          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;

            final reentryCount = (data['reentryCount'] as num?)?.toInt() ?? 0;
            final addonCount = (data['addonCount'] as num?)?.toInt() ?? 0;
            final isBusted = data['isBusted'] ?? false;

            totalEntries += 1 + reentryCount;
            totalAddons += addonCount;
            if (!isBusted) remainingPlayers++;
          }
          

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('残プレイヤー: $remainingPlayers / $totalEntries', style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final userName = data['userName'] ?? '名無し';
                    final chipStack = data['chipStack'] ?? 0;
                    final isBusted = data['isBusted'] ?? false;
                    final reentryCount = data['reentryCount'] ?? 0;
                    final addonCount = data['addonCount'] ?? 0;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(userName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('敗退: ${isBusted ? "はい" : "いいえ"}'),
                            Text('リエントリー回数: $reentryCount'),
                            Text('アドオン回数: $addonCount'),
                          ],
                        ),
                        trailing: SizedBox(
                          width: 160,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (!isBusted)
                                  ElevatedButton(
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('敗退確認'),
                                          content: Text('$userName さんを敗退扱いにしますか？'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
                                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('敗退')),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true) {
                                        await _markBusted(doc.id);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    child: const Text('敗退'),
                                  ),
                                if (isBusted)
                                  ElevatedButton(
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('リエントリー確認'),
                                          content: Text('$userName さんをリエントリーさせますか？'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
                                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('リエントリー')),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true) {
                                        await _reentryPlayer(doc.id);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                    child: const Text('リエントリー'),
                                  ),
                                const SizedBox(width: 6),
                                ElevatedButton(
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('アドオン確認'),
                                        content: Text('$userName さんにアドオンチップを追加しますか？'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
                                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('アドオン')),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      await _addonPlayer(doc.id);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                                  child: const Text('アドオン'),
                                ),
                              ],
                            ),
                          ),
                        ),
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
}
