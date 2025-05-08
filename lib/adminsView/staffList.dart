import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:poker_first/adminsView/staffDetail.dart';

class StaffListPage extends StatelessWidget {
  const StaffListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('スタッフ一覧')),
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
              final data = staffDocs[index].data() as Map<String, dynamic>;
              final docId = staffDocs[index].id;

              return ListTile(
                title: Text(data['pokerName'] ?? 'No Name'),
                subtitle: Text('Login ID: ${data['loginId'] ?? 'N/A'}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StaffDetailPage(
                        staffId: docId,
                        staffData: data,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

