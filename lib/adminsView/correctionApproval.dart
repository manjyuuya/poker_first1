import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CorrectionApprovalPage extends StatelessWidget {
  const CorrectionApprovalPage({super.key});

  Future<void> _updateStatus(String docId, String status) async {
    await FirebaseFirestore.instance
        .collection('attendanceCorrections')
        .doc(docId)
        .update({'status': status});
  }

  String formatTime(Timestamp? ts) {
    if (ts == null) return '??:??';
    return DateFormat('HH:mm').format(ts.toDate());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('勤怠修正申請の承認'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('attendanceCorrections')
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('データの取得中にエラーが発生しました'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('未処理の申請はありません'));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final String reason = data['reason'] ?? 'No Reason';
              final String userId = data['userId'] ?? 'Unknown';
              final String userName = data['userName'] ?? 'No Name';
              final Timestamp? targetDateTs = data['targetDate'];

              final Timestamp? requestedClockIn = data['requestedClockInDateTime'];
              final Timestamp? requestedClockOut = data['requestedClockOutDateTime'];
              final Timestamp? originalClockIn = data['originalClockInDateTime'];
              final Timestamp? originalClockOut = data['originalClockOutDateTime'];

              final formattedDate = targetDateTs != null
                  ? DateFormat('yyyy/MM/dd').format(targetDateTs.toDate())
                  : '日付なし';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('スタッフ: $userName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('対象日: $formattedDate'),
                      Text('元の出勤: ${formatTime(originalClockIn)}'),
                      Text('元の退勤: ${formatTime(originalClockOut)}'),
                      Text('希望出勤: ${formatTime(requestedClockIn)}'),
                      Text('希望退勤: ${formatTime(requestedClockOut)}'),
                      const SizedBox(height: 4),
                      Text('理由: $reason'),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              final scaffoldMessenger = ScaffoldMessenger.of(context);

                              if (userId.isNotEmpty &&
                                  targetDateTs != null &&
                                  requestedClockIn != null &&
                                  requestedClockOut != null) {
                                try {
                                  final baseDate = targetDateTs.toDate();
                                  final formattedDate = DateFormat('yyyyMMdd').format(baseDate);
                                  final attendanceDocId = '${userId}_$formattedDate';

                                  await FirebaseFirestore.instance
                                      .collection('attendances')
                                      .doc(attendanceDocId)
                                      .set({
                                    'clockIn': requestedClockIn,
                                    'clockOut': requestedClockOut,
                                    'correctedByAdmin': true,
                                    'correctionUpdatedAt': Timestamp.now(),
                                  }, SetOptions(merge: true));
                                } catch (e) {
                                  debugPrint('勤怠反映エラー: $e');
                                  scaffoldMessenger.showSnackBar(
                                    const SnackBar(content: Text('エラーが発生しました')),
                                  );
                                  return;
                                }
                              }

                              await _updateStatus(doc.id, 'approved');

                              scaffoldMessenger.showSnackBar(
                                const SnackBar(content: Text('申請を承認し、勤怠に反映しました')),
                              );
                            },
                            icon: const Icon(Icons.check),
                            label: const Text('承認'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await _updateStatus(doc.id, 'rejected');

                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('申請を却下しました')),
                              );
                            },
                            icon: const Icon(Icons.close),
                            label: const Text('却下'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
