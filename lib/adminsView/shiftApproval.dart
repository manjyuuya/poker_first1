import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ShiftApprovalPage extends StatelessWidget {
  const ShiftApprovalPage({super.key});

  void _approveShift(String docId, String ownerId) {
    FirebaseFirestore.instance.collection('schedules').doc(docId).update({
      'confirmed': true,
      'approvedBy': ownerId,
      'denied': false, // 否認されていないことを明示
    });
  }

  void _denyShift(String docId) {
    FirebaseFirestore.instance.collection('schedules').doc(docId).update({
      'denied': true, // 否認フラグを立てる
      'confirmed': false,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("シフト承認")),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('schedules')
            .where('confirmed', isEqualTo: false) // 未承認のシフト
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          var shiftDocs = snapshot.data!.docs.where((doc) {
            // `denied` フィールドが存在しない場合は `false` とみなす
            var data = doc.data() as Map<String, dynamic>;
            return (data.containsKey('denied') ? data['denied'] : false) == false;
          }).toList();

          if (shiftDocs.isEmpty) {
            return Center(child: Text("未承認のシフトはありません"));
          }

          return ListView(
            children: shiftDocs.map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              return ListTile(
                title: Text("${data['userName']} - ${data['date']}"),
                subtitle: Text(data['shift']),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () => _approveShift(doc.id, "owner1"), // owner ID は適宜取得
                      child: Text("承認"),
                    ),
                    SizedBox(width: 8), // ボタンの間隔を空ける
                    ElevatedButton(
                      onPressed: () => _denyShift(doc.id),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red), // 赤いボタン
                      child: Text("否認"),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}






