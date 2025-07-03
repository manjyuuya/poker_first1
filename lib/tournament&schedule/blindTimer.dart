import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BlindTimerPage extends StatefulWidget {
  final String tournamentId;

  const BlindTimerPage({super.key, required this.tournamentId});

  @override
  State<BlindTimerPage> createState() => _BlindTimerPageState();
}

class _BlindTimerPageState extends State<BlindTimerPage> {
  Timer? _timer;
  DocumentSnapshot? tournamentDoc;
  DateTime? startTime;
  int blindStructure = 20;
  List<dynamic> blindLevels = [];
  int currentLevel = 1;
  bool isOpen = true;
  DateTime? registerClose;

  Map<String, dynamic> currentBlind = {};
  Map<String, dynamic>? nextBlind;

  Duration timeLeft = Duration.zero;
  Duration nextBreakTimeLeft = Duration.zero;
  Duration regTimeLeft = Duration.zero;

  Map<String, int>? breakTime;
  bool isOnBreak = false;

  int playerCount = 0;
  int totalEntries = 0;
  int totalAddons = 0;
  int remainingPlayers = 0;
  int averageStack = 0;
  int totalPlayerEntries = 0;

  int initialStack = 20000;
  int addonStack = 10000;

  @override
  void initState() {
    super.initState();
    _fetchTournament();
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
      isOpen = data['isOpen'] ?? true;
      registerClose = (data['registerClose'] as Timestamp?)?.toDate();

      initialStack = (data['initialStack'] ?? 20000).toInt();
      addonStack = (data['addonStack'] ?? 10000).toInt();

      if (data['breakTime'] != null) {
        final bt = Map<String, dynamic>.from(data['breakTime']);
        breakTime = {
          'afterMinutes': (bt['afterMinutes'] as num?)?.toInt() ?? 0,
          'durationMinutes': (bt['durationMinutes'] as num?)?.toInt() ?? 0,
        };
      } else {
        breakTime = null;
      }
    });

    if (blindLevels.isNotEmpty && currentLevel <= blindLevels.length) {
      currentBlind = blindLevels[currentLevel - 1];
      nextBlind = (currentLevel < blindLevels.length)
          ? blindLevels[currentLevel]
          : null;
    }

    _fetchPlayers();
    if (isOpen) {
      _startTimer();
    }
  }

  Future<void> _fetchPlayers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .collection('players')
        .get();

    int totalEntries = 0;
    int totalAddons = 0;
    int remainingPlayers = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final reentryCount = (data['reentryCount'] ?? 0) as num;
      final addonCount = (data['addonCount'] ?? 0) as num;
      final isBusted = data['isBusted'] ?? false;

      totalEntries += 1 + reentryCount.toInt();  // エントリー + リエントリー
      totalAddons += addonCount.toInt();

      if (!isBusted) remainingPlayers++;
    }

    final tournamentData = tournamentDoc?.data() as Map<String, dynamic>? ?? {};
    final initialStack = (tournamentData['initialStack'] ?? 20000) as int;
    final addonStack = (tournamentData['addonStack'] ?? 10000) as int;

    final totalChips = totalEntries * initialStack + totalAddons * addonStack;
    final avgStack = remainingPlayers > 0 ? (totalChips ~/ remainingPlayers) : 0;

    setState(() {
      playerCount = remainingPlayers;
      averageStack = avgStack;
      totalPlayerEntries = totalEntries; // ← 新たに定義して、残り人数の分母に使用
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      if (startTime == null || blindLevels.isEmpty) return;

      final elapsedSeconds = now.difference(startTime!).inSeconds;
      final elapsedMinutes = elapsedSeconds ~/ 60;

      int breakCycleMin = breakTime?['afterMinutes'] ?? 0;
      int breakDurationMin = breakTime?['durationMinutes'] ?? 0;

      int cycle = (breakCycleMin > 0) ? (elapsedMinutes ~/ (breakCycleMin + breakDurationMin)) : 0;
      int nextBreakStart = (cycle + 1) * (breakCycleMin + breakDurationMin);
      int breakStart = nextBreakStart - breakDurationMin;

      final isInBreak = breakTime != null &&
          elapsedMinutes >= breakStart &&
          elapsedMinutes < nextBreakStart;

      if (isInBreak) {
        isOnBreak = true;
        timeLeft = Duration(seconds: (nextBreakStart * 60) - elapsedSeconds);
      } else {
        if (isOnBreak) {
          isOnBreak = false;
        }

        int totalBreakMinutesPassed = (breakTime != null)
            ? (elapsedMinutes ~/ (breakCycleMin + breakDurationMin)) * breakDurationMin
            : 0;

        final adjustedElapsedMinutes = elapsedMinutes - totalBreakMinutesPassed;
        final newLevel = (adjustedElapsedMinutes ~/ blindStructure) + 1;

        // 画面表示用としてレベルは上がり続ける
        currentLevel = newLevel;

        currentBlind = (newLevel <= blindLevels.length)
            ? blindLevels[newLevel - 1]
            : blindLevels.last;

        nextBlind = (newLevel < blindLevels.length)
            ? blindLevels[newLevel]
            : null;

        // Firestore への書き込みは最大レベルまで
        if (newLevel <= blindLevels.length && newLevel != tournamentDoc?['currentLevel']) {
          FirebaseFirestore.instance
              .collection('tournaments')
              .doc(widget.tournamentId)
              .update({
            'currentLevel': newLevel,
            'blind': blindLevels[newLevel - 1],
          });
        }

        final nextLevelStart = startTime!.add(
          Duration(
            minutes: (newLevel * blindStructure) + (cycle * breakDurationMin),
          ),
        );
        timeLeft = nextLevelStart.difference(now);
      }

      if (breakTime != null) {
        final nextBreakSeconds = (nextBreakStart * 60) - elapsedSeconds;
        nextBreakTimeLeft = Duration(seconds: nextBreakSeconds);
      }

      if (registerClose != null) {
        regTimeLeft = registerClose!.difference(now);
      }

      setState(() {});
    });
  }


  String formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (tournamentDoc == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('ブラインドタイマー')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('現在のレベル: Lv$currentLevel', style: const TextStyle(fontSize: 24)),
            Text('ブラインド: ${currentBlind['small']} / ${currentBlind['big']} (Ante: ${currentBlind['ante']})',
                style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            Text('残り時間: ${formatDuration(timeLeft)}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (isOnBreak)
              const Text('Next: break', style: TextStyle(fontSize: 18, color: Colors.blue)),
            if (!isOnBreak && nextBlind != null)
              Text('Next: ${nextBlind!['small']} / ${nextBlind!['big']} (Ante: ${nextBlind!['ante']})',
                  style: const TextStyle(fontSize: 18)),
            if (registerClose != null && regTimeLeft.inSeconds > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Text('レジスト終了まで: ${formatDuration(regTimeLeft)}',
                    style: const TextStyle(fontSize: 16, color: Colors.orange)),
              ),
            if (breakTime != null && nextBreakTimeLeft.inSeconds > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Text('次の休憩まで: ${formatDuration(nextBreakTimeLeft)}',
                    style: const TextStyle(fontSize: 16, color: Colors.green)),
              ),
            const Divider(height: 32),
            Text('残りプレイヤー数: $playerCount / $totalPlayerEntries', style: const TextStyle(fontSize: 16)),
            Text('平均スタック: $averageStack', style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}