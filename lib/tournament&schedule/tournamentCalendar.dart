import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:poker_first/tournament&schedule/tournamentList.dart';
import 'package:poker_first/tournament&schedule/tournamentRegister.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class TournamentCalendarPage extends StatefulWidget {
  const TournamentCalendarPage({super.key});

  @override
  State<TournamentCalendarPage> createState() => _TournamentCalendarPageState();
}

class _TournamentCalendarPageState extends State<TournamentCalendarPage> {
  Map<DateTime, List<Map<String, dynamic>>> _tournaments = {};
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchTournaments();
  }

  void _fetchTournaments() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('tournaments')
        .get();

    final events = <DateTime, List<Map<String, dynamic>>>{};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (!data.containsKey('date')) continue;

      final date = (data['date'] as Timestamp).toDate();
      final dayKey = DateTime(date.year, date.month, date.day);

      events.putIfAbsent(dayKey, () => []);
      events[dayKey]!.add(data);
    }

    setState(() {
      _tournaments = events;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('トーナメントカレンダー'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TournamentRegisterPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            locale: 'ja_JP',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2099, 12, 31),
            focusedDay: _selectedDay,
            selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
            onDaySelected: (selected, _) {
              setState(() {
                _selectedDay = selected;
              });
            },
            eventLoader: (day) {
              final key = DateTime(day.year, day.month, day.day);
              return _tournaments[key] ?? [];
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return const SizedBox.shrink();
                return Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.all(4.0),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: (_tournaments[DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day)] ?? [])
                .map((t) => ListTile(
              title: Text(t['name'] ?? '無名トーナメント'),
              subtitle: Text(
                '開始: ${t.containsKey('startTime') ? DateFormat('HH:mm').format((t['startTime'] as Timestamp).toDate()) : '未定'}',
              ),
            ))
                .toList()
                .isEmpty
                ? const Center(child: Text('この日に開催されるトーナメントはありません'))
                : ListView(
              children: (_tournaments[DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day)] ?? [])
                  .map((t) => ListTile(
                title: Text(t['name'] ?? '無名トーナメント'),
                subtitle: Text(
                  '開始: ${t.containsKey('startTime') ? DateFormat('HH:mm').format((t['startTime'] as Timestamp).toDate()) : '未定'}',
                ),
              ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
