import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BlindTemplateSelectorPage extends StatelessWidget {
  const BlindTemplateSelectorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('テンプレートを選択')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('blindTemplates').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return ListTile(
                title: Text(data['name'] ?? '無名テンプレート'),
                onTap: () {
                  final levels = List<Map<String, dynamic>>.from(data['levels'] ?? []);
                  Navigator.pop(context, levels);
                },
              );
            },
          );
        },
      ),
    );
  }
}
