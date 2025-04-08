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
  void _navigateTo(BuildContext context, Widget page) {
    if (!mounted) return; // ウィジェットが破棄されていたら何もしない
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("ようこそ ${FirebaseAuth.instance.currentUser?.displayName ?? "ゲスト"}"),
        actions: [
          Builder(
            builder: (context) {
              return PopupMenuButton<int>(
                icon: Icon(Icons.menu, size: 30),
                onSelected: (value) {
                  switch (value) {
                    case 1:
                      _navigateTo(context, ShiftRequestPage());
                      break;
                    case 2:
                      _navigateTo(context, MyShiftsPage());
                      break;
                    case 3:
                      _navigateTo(context, StaffPost());
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 1, child: Text("シフト申請",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold),)),
                  PopupMenuItem(value: 2, child: Text("シフト表",
                      style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold))),
                  PopupMenuItem(value: 3, child: Text("投稿",
                      style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold))),
                ],
                color: Colors.white, // メニューの背景色
                elevation: 8, // 影をつける
                position: PopupMenuPosition.under, // メニューをボタンの下に表示
                constraints: BoxConstraints(minWidth: 150), // メニューの最小幅
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Text("メニューから操作を選んでください"),
      ),
    );
  }
}
