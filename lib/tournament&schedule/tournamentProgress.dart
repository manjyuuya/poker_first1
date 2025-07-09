import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:poker_first/tournament&schedule/prizeDistribution.dart';

class TournamentProgressPage extends StatefulWidget {
  final String tournamentId;

  const TournamentProgressPage({super.key, required this.tournamentId});

  @override
  State<TournamentProgressPage> createState() => _TournamentProgressPageState();
}

class _TournamentProgressPageState extends State<TournamentProgressPage> {
  DocumentSnapshot? tournamentDoc;
  DateTime? startTime;
  List<dynamic> blindLevels = [];
  int blindStructure = 20;
  int currentLevel = 1;
  int lastLevelBeforeBreak = 1;
  Map<String, dynamic> currentBlind = {};
  Timer? _timer;
  String countdownLabel = 'スタートまで';
  Duration remainingDuration = Duration.zero;
  bool isOpen = true;
  Map<String, int>? breakTime;
  bool isOnBreak = false;

  @override
  void initState() {
    super.initState();
    _fetchTournament();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchTournament() async {
    final doc = await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .get();

    final data = doc.data() as Map<String, dynamic>;

    setState(() {
      tournamentDoc = doc;
      startTime = (data['startTime'] as Timestamp?)?.toDate();
      blindLevels = data['blindLevels'] ?? [];
      blindStructure = (data['blindStructure'] ?? 20).toInt();
      currentLevel = (data['currentLevel'] ?? 1).toInt();
      lastLevelBeforeBreak = currentLevel;
      isOpen = data['isOpen'] ?? true;
      if (blindLevels.isNotEmpty && currentLevel >= 1 && currentLevel <= blindLevels.length) {
        currentBlind = Map<String, dynamic>.from(blindLevels[currentLevel - 1]);
      }
    });

    if (data['breakTime'] != null) {
      final bt = Map<String, dynamic>.from(data['breakTime']);
      breakTime = {
        'afterMinutes': (bt['afterMinutes'] as num?)?.toInt() ?? 0,
        'durationMinutes': (bt['durationMinutes'] as num?)?.toInt() ?? 0,
      };
    } else {
      breakTime = null;
    }

    if (isOpen) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (startTime == null || blindLevels.isEmpty || !mounted) return;

      final now = DateTime.now();

      if (now.isBefore(startTime!)) {
        setState(() {
          countdownLabel = 'スタートまで';
          remainingDuration = startTime!.difference(now);
          currentLevel = 0;
          currentBlind = {};
          isOnBreak = false;
        });
        return;
      }

      final elapsedSeconds = now.difference(startTime!).inSeconds;
      final elapsedMinutes = elapsedSeconds ~/ 60;

      int breakCycleMin = breakTime?['afterMinutes'] ?? 0;
      int breakDurationMin = breakTime?['durationMinutes'] ?? 0;

      int cycle = (breakCycleMin > 0)
          ? (elapsedMinutes ~/ (breakCycleMin + breakDurationMin))
          : 0;

      int nextBreakStart = (cycle + 1) * (breakCycleMin + breakDurationMin);
      int breakStart = nextBreakStart - breakDurationMin;

      final isInBreak = breakTime != null &&
          elapsedMinutes >= breakStart &&
          elapsedMinutes < nextBreakStart;

      final totalBreakMinutesPassed = (breakTime != null)
          ? (elapsedMinutes ~/ (breakCycleMin + breakDurationMin)) * breakDurationMin
          : 0;

      final adjustedElapsedMinutes = elapsedMinutes - totalBreakMinutesPassed;
      final newLevel = (adjustedElapsedMinutes ~/ blindStructure) + 1;

      if (isInBreak) {
        setState(() {
          countdownLabel = '休憩終了まで';
          remainingDuration = Duration(seconds: (nextBreakStart * 60) - elapsedSeconds);
          isOnBreak = true;
          currentLevel = lastLevelBeforeBreak;
          currentBlind = (currentLevel <= blindLevels.length)
              ? Map<String, dynamic>.from(blindLevels[currentLevel - 1])
              : Map<String, dynamic>.from(blindLevels.last);
        });
        return;
      }

      isOnBreak = false;
      lastLevelBeforeBreak = newLevel;

      setState(() {
        countdownLabel = '次のレベルまで';
        currentLevel = newLevel;
        currentBlind = (newLevel <= blindLevels.length)
            ? Map<String, dynamic>.from(blindLevels[newLevel - 1])
            : Map<String, dynamic>.from(blindLevels.last);

        final nextLevelStart = startTime!.add(
          Duration(minutes: newLevel * blindStructure + cycle * breakDurationMin),
        );
        remainingDuration = nextLevelStart.difference(now);
      });

      if (newLevel <= blindLevels.length && newLevel != tournamentDoc?['currentLevel']) {
        await FirebaseFirestore.instance
            .collection('tournaments')
            .doc(widget.tournamentId)
            .update({
          'currentLevel': newLevel,
          'blind': blindLevels[newLevel - 1],
        });
      }
    });
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<void> _updateStatus() async {
    if (tournamentDoc == null) return;
    final data = tournamentDoc!.data() as Map<String, dynamic>;
    final registerClose = (data['registerClose'] as Timestamp?)?.toDate();
    final now = DateTime.now();
    if (!isOpen || registerClose == null || now.isBefore(registerClose)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認'),
        content: const Text('このトーナメントを本当に「終了」にしますか？\n※この操作は元に戻せません。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('終了する')),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .update({'isOpen': false});
      _fetchTournament();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (tournamentDoc == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final data = tournamentDoc!.data() as Map<String, dynamic>;
    final name = data['name'] ?? '無名トーナメント';
    final registerClose = (data['registerClose'] as Timestamp?)?.toDate();
    final now = DateTime.now();
    final bool prizeCalculated = data['prizeCalculated'] == true;

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

    final small = currentBlind['small']?.toString() ?? '-';
    final big = currentBlind['big']?.toString() ?? '-';
    final ante = currentBlind['ante']?.toString() ?? '-';

    return Scaffold(
      appBar: AppBar(title: Text('$name - 進行管理')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ステータス: $statusText', style: TextStyle(fontSize: 18, color: statusColor)),
            const SizedBox(height: 8),
            if (startTime != null)
              Text('開始時刻: ${DateFormat('yyyy/MM/dd HH:mm').format(startTime!)}'),
            const SizedBox(height: 16),
            Text('レベル: $currentLevel'),
            Text('ブラインド: $small / $big (Ante: $ante)'),
            const SizedBox(height: 16),
            if (isOpen)
              Text('$countdownLabel: ${_formatDuration(remainingDuration)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (isOnBreak)
              const Text(
                '現在は休憩中です',
                style: TextStyle(fontSize: 16, color: Colors.blue),
              ),
            const Spacer(),
            if (prizeCalculated)
              ElevatedButton.icon(
                icon: const Icon(Icons.emoji_events),
                label: const Text('プライズ配分を確認・編集'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PrizeDistributionPage(
                        tournamentId: widget.tournamentId,
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 30),
            if (isOpen && registerClose != null && now.isAfter(registerClose))
              ElevatedButton.icon(
                icon: const Icon(Icons.flag),
                label: const Text('トーナメント終了にする'),
                onPressed: _updateStatus,
              ),
          ],
        ),
      ),
    );
  }
}