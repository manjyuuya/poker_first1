import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:poker_first/adminsView/salaryDetail.dart';

class SalaryCalculationPage extends StatelessWidget {
  const SalaryCalculationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("給与計算")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'staff')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final staffDocs = snapshot.data!.docs;

          if (staffDocs.isEmpty) {
            return const Center(child: Text('スタッフが登録されていません'));
          }

          return ListView.builder(
            itemCount: staffDocs.length,
            itemBuilder: (context, index) {
              final staffData = staffDocs[index].data() as Map<String, dynamic>;
              final staffId = staffDocs[index].id;  // FirestoreのドキュメントIDがuid

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  title: Text(staffData['pokerName'] ?? 'No Name'),
                  subtitle: Text('Login ID: ${staffData['loginId'] ?? 'N/A'}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // タップしたスタッフのuidを渡して給与計算画面に遷移
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SalaryDetailPage(uid: staffId),
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