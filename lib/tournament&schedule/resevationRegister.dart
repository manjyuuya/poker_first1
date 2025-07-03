import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReservationRegisterPage extends StatefulWidget {
  const ReservationRegisterPage({super.key});

  @override
  State<ReservationRegisterPage> createState() => _ReservationRegisterPageState();
}

class _ReservationRegisterPageState extends State<ReservationRegisterPage> {
  String? selectedUserId;
  String? selectedUserName;
  String? selectedTournamentId;
  String? selectedTournamentName;
  String memo = '';
  bool isSubmitting = false;

  List<Map<String, String>> eligibleUsers = [];
  List<Map<String, String>> upcomingTournaments = [];

  @override
  void initState() {
    super.initState();
    fetchEligibleUsers();
    fetchUpcomingTournaments();
  }

  Future<void> fetchEligibleUsers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'user')
        .get();

    final List<Map<String, String>> users = [];

    for (var doc in snapshot.docs) {
      final visitHistory = await doc.reference.collection('visitHistory').limit(1).get();
      if (visitHistory.docs.isNotEmpty) {
        users.add({
          'id': doc.id,
          'name': doc.data()['pokerName'] ?? '名無し',
        });
      }
    }

    setState(() {
      eligibleUsers = users;
    });
  }

  Future<void> fetchUpcomingTournaments() async {
    final now = DateTime.now();
    final snapshot = await FirebaseFirestore.instance
        .collection('tournaments')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .where('isOpen', isEqualTo: true)
        .orderBy('date')
        .get();

    final List<Map<String, String>> tournaments = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'name': (data['name'] ?? '無名トーナメント').toString(),
      };
    }).toList();


    setState(() {
      upcomingTournaments = tournaments;
    });
  }

  Future<void> submitReservation() async {
    if (selectedUserId == null || selectedTournamentId == null) return;

    setState(() {
      isSubmitting = true;
    });

    await FirebaseFirestore.instance.collection('reservations').add({
      'userId': selectedUserId,
      'userName': selectedUserName,
      'tournamentId': selectedTournamentId,
      'tournamentName': selectedTournamentName,
      'reservedAt': Timestamp.now(),
      'status': 'reserved',
      'memo': memo,
    });

    setState(() {
      isSubmitting = false;
    });

    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('トーナメント予約登録')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isSubmitting
            ? const Center(child: CircularProgressIndicator())
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('顧客選択'),
            DropdownButton<String>(
              value: selectedUserId,
              hint: const Text('顧客を選択'),
              isExpanded: true,
              items: eligibleUsers.map((user) {
                return DropdownMenuItem(
                  value: user['id'],
                  child: Text(user['name'] ?? ''),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedUserId = value;
                  selectedUserName = eligibleUsers.firstWhere((u) => u['id'] == value)['name'];
                });
              },
            ),
            const SizedBox(height: 16),
            const Text('トーナメント選択'),
            DropdownButton<String>(
              value: selectedTournamentId,
              hint: const Text('トーナメントを選択'),
              isExpanded: true,
              items: upcomingTournaments.map((t) {
                return DropdownMenuItem(
                  value: t['id'],
                  child: Text(t['name'] ?? ''),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedTournamentId = value;
                  selectedTournamentName = upcomingTournaments.firstWhere((t) => t['id'] == value)['name'];
                });
              },
            ),
            const SizedBox(height: 16),
            const Text('備考（任意）'),
            TextField(
              onChanged: (value) => memo = value,
              decoration: const InputDecoration(
                hintText: '例: 常連、初心者',
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: (selectedUserId != null && selectedTournamentId != null)
                    ? submitReservation
                    : null,
                child: const Text('予約を登録する'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
