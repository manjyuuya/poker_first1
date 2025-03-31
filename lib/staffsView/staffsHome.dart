import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:poker_first/staffsView/myShift.dart';
import 'package:poker_first/staffsView/shiftRequest.dart';
import 'package:poker_first/staffsView/staffPost.dart';

class StaffsHome extends StatefulWidget {
  const StaffsHome({super.key});

  @override
  State<StaffsHome> createState() => _StaffsHomeState();
}

class _StaffsHomeState extends State<StaffsHome> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("ようこそ ${FirebaseAuth.instance.currentUser?.displayName ?? "ゲスト"}"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(onPressed: (){
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => ShiftRequestPage())
              );
            }, child: Text("シフト申請")),
            ElevatedButton(onPressed: (){
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => MyShiftsPage())
              );
            }, child: Text("シフト表")),
            ElevatedButton(onPressed: (){
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => StaffPost())
              );
            }, child: Text("投稿")),
          ],
        ),
      ),
    );
  }
}



