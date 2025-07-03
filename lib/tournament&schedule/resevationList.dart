import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:poker_first/tournament&schedule/resevationEdit.dart';
import 'package:poker_first/tournament&schedule/resevationRegister.dart';

class ReservationListPage extends StatefulWidget {
  const ReservationListPage({super.key});

  @override
  State<ReservationListPage> createState() => _ReservationListPageState();
}

class _ReservationListPageState extends State<ReservationListPage> {
  String _searchKeyword = '';

  Future<List<Map<String, dynamic>>> fetchFutureReservations() async {
    final reservationSnapshot =
    await FirebaseFirestore.instance.collection('reservations').orderBy('reservedAt').get();

    final reservations = <Map<String, dynamic>>[];

    for (final doc in reservationSnapshot.docs) {
      final data = doc.data();
      final tournamentId = data['tournamentId'];
      if (tournamentId == null) continue;

      final tournamentDoc = await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(tournamentId)
          .get();

      if (!tournamentDoc.exists) continue;

      final tournamentData = tournamentDoc.data();
      final registerClose = tournamentData?['registerClose'];
      if (registerClose is! Timestamp) continue;

      final registerCloseDate = registerClose.toDate();
      if (registerCloseDate.isAfter(DateTime.now())) {
        reservations.add({
          'id': doc.id,
          ...data,
          'tournamentName': tournamentData?['name'] ?? '不明なトーナメント',
          'registerClose': registerCloseDate,
        });
      }
    }

    return reservations;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('予約一覧'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final keyword = await showSearch(
                context: context,
                delegate: _TournamentSearchDelegate(),
              );
              if (keyword != null) {
                setState(() {
                  _searchKeyword = keyword.trim();
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新規作成',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReservationRegisterPage()),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchFutureReservations(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('エラー: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allReservations = snapshot.data ?? [];
          final filtered = _searchKeyword.isEmpty
              ? allReservations
              : allReservations.where((r) {
            final name = (r['tournamentName'] ?? '').toString();
            return name.contains(_searchKeyword);
          }).toList();

          if (filtered.isEmpty) {
            return const Center(child: Text('予約はありません'));
          }

          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final data = filtered[index];

              final userName = data['userName'] ?? '不明';
              final tournamentName = data['tournamentName'] ?? '無名トーナメント';
              final reservedAt = (data['reservedAt'] as Timestamp).toDate();
              final memo = data['memo'] ?? '';
              final status = data['status'] ?? '不明';

              final dateStr = DateFormat('yyyy/MM/dd HH:mm').format(reservedAt);

              Color statusColor;
              switch (status) {
                case '予約済み':
                  statusColor = Colors.green;
                  break;
                case 'キャンセル':
                  statusColor = Colors.red;
                  break;
                default:
                  statusColor = Colors.grey;
              }

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: ListTile(
                  title: Text('$userName 様が $tournamentName を予約'),
                  subtitle: Text('日時: $dateStr\nメモ: $memo'),
                  trailing: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ReservationEditPage(reservationId: data['id']),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _TournamentSearchDelegate extends SearchDelegate<String> {
  @override
  String get searchFieldLabel => 'トーナメント名で検索';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear))];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(onPressed: () => close(context, ''), icon: const Icon(Icons.arrow_back));
  }

  @override
  Widget buildResults(BuildContext context) {
    close(context, query);
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return const SizedBox.shrink();
  }
}
