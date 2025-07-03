import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:poker_first/tournament&schedule/prizeSettings.dart';
import 'package:poker_first/tournament&schedule/tournamentDetail.dart';
import 'package:poker_first/tournament&schedule/tournamentRegister.dart';
import 'package:poker_first/tournament&schedule/tournamentProgress.dart';
import 'package:table_calendar/table_calendar.dart';

class TournamentListPage extends StatefulWidget {
  const TournamentListPage({super.key});

  @override
  State<TournamentListPage> createState() => _TournamentListPageState();
}

class _TournamentListPageState extends State<TournamentListPage> {
  bool _isCalendarView = false;
  DateTime _focusedDay = DateTime.now();
  Map<DateTime, List<Map<String, dynamic>>> _tournamentEvents = {};

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  void _loadTournaments() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('tournaments')
        .orderBy('date')
        .get();

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final events = <DateTime, List<Map<String, dynamic>>>{};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (!data.containsKey('date')) continue;

      final date = (data['date'] as Timestamp).toDate();
      final dayKey = DateTime(date.year, date.month, date.day);
      data['id'] = doc.id;

      final isOpen = data['isOpen'] ?? true;
      final isBeforeToday = date.isBefore(todayStart);

      // ✅ 修正ポイント: 終了済みかつ過去日のトーナメントは除外
      if (isBeforeToday && !isOpen) continue;

      events.putIfAbsent(dayKey, () => []);
      events[dayKey]!.add(data);
    }

    setState(() {
      _tournamentEvents = events;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('トーナメント一覧'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新規作成',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const TournamentRegisterPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const Icon(Icons.view_list),
                Switch(
                  value: _isCalendarView,
                  onChanged: (val) {
                    setState(() {
                      _isCalendarView = val;
                    });
                  },
                ),
                const Icon(Icons.calendar_today),
                const SizedBox(width: 12),
                Text(_isCalendarView ? 'カレンダー表示' : 'リスト表示'),
              ],
            ),
          ),
          Expanded(
            child: _isCalendarView ? _buildCalendarView() : _buildListView(),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('tournaments')
          .orderBy('date')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
        }

        final allDocs = snapshot.data?.docs ?? [];

        // ✅ 修正ポイント: 終了済かつ過去日のトーナメントは除外
        final docs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final date = (data['date'] as Timestamp?)?.toDate();
          if (date == null) return false;

          final isOpen = data['isOpen'] ?? true;
          final isBeforeToday = date.isBefore(todayStart);

          return !(isBeforeToday && !isOpen);
        }).toList();

        if (docs.isEmpty) {
          return const Center(child: Text('トーナメントはまだ登録されていません'));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            final name = data['name'] ?? '無名トーナメント';
            final date = (data['date'] as Timestamp).toDate();
            final start = (data['startTime'] as Timestamp).toDate();
            final entryFee = data['entryFee'];
            final dateStr = DateFormat('yyyy/MM/dd').format(date);
            final timeStr = DateFormat('HH:mm').format(start);
            final entryFeeStr = entryFee != null ? '¥$entryFee' : '未定';

            final isOpen = data['isOpen'] ?? true;
            final registerClose = (data['registerClose'] as Timestamp?)?.toDate();
            final now = DateTime.now();

            String statusText;
            Color statusColor;

            if (!isOpen) {
              statusText = '終了';
              statusColor = Colors.grey;
            } else if (registerClose != null && now.isAfter(registerClose)) {
              statusText = '受付終了';
              statusColor = Colors.orange;
            } else {
              statusText = '受付中';
              statusColor = Colors.green;
            }

            return Card(
              child: ListTile(
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('日付: $dateStr\n開始: $timeStr\nエントリー費: $entryFeeStr'),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TournamentProgressPage(
                                  tournamentId: docs[index].id),
                            ),
                          );
                        },
                        child: const Text('進行管理'),
                      ),
                    ),
                  ],
                ),
                trailing: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          TournamentDetailPage(tournamentId: docs[index].id),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCalendarView() {
    final events = _tournamentEvents[DateTime(
        _focusedDay.year, _focusedDay.month, _focusedDay.day)] ??
        [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TableCalendar(
            locale: 'ja_JP',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2099, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(day, _focusedDay),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _focusedDay = selectedDay;
              });
            },
            headerStyle: const HeaderStyle(formatButtonVisible: false),
            eventLoader: (day) =>
            _tournamentEvents[DateTime(day.year, day.month, day.day)] ?? [],
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return const SizedBox.shrink();
                return Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.all(3.0),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            DateFormat('yyyy/MM/dd').format(_focusedDay),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (events.isEmpty)
            const Text('この日のトーナメントはありません')
          else
            ...events.map((t) {
              final tournamentId = t['id'];
              final startTime = t['startTime'] != null
                  ? DateFormat('HH:mm')
                  .format((t['startTime'] as Timestamp).toDate())
                  : '未定';
              final entryFee =
              t['entryFee'] != null ? '¥${t['entryFee']}' : '未定';

              final isOpen = t['isOpen'] ?? true;
              final registerClose =
              (t['registerClose'] as Timestamp?)?.toDate();
              final now = DateTime.now();

              String statusText;
              Color statusColor;

              if (!isOpen) {
                statusText = '終了';
                statusColor = Colors.grey;
              } else if (registerClose != null && now.isAfter(registerClose)) {
                statusText = '受付終了';
                statusColor = Colors.orange;
              } else {
                statusText = '受付中';
                statusColor = Colors.green;
              }

              return Card(
                child: ListTile(
                  title: Text(t['name'] ?? '無名トーナメント'),
                  subtitle: Text('開始: $startTime / エントリー費: $entryFee'),
                  trailing: Wrap(
                    direction: Axis.vertical,
                    spacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TournamentProgressPage(
                                  tournamentId: tournamentId),
                            ),
                          );
                        },
                        child:
                        const Text('進行管理', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}
