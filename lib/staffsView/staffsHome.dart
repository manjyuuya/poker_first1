import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:poker_first/orderingSystem/menuItemEntry.dart';
import 'package:poker_first/orderingSystem/orderEntry.dart';
import 'package:poker_first/orderingSystem/stayingUserSelection.dart';
import 'package:poker_first/orderingSystem/unsettledOrdersPage.dart';
import 'package:poker_first/staffsView/attendanceCorrection.dart';
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
                    case 4:
                      _navigateTo(context, AttendanceCorrectionPage());
                      break;
                    case 5:
                      _navigateTo(context, StayingUserSelectionPage());
                      break;
                    case 6:
                      _navigateTo(context, UnsettledOrdersPage());
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 1, child: Text("シフト申請",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold))),
                  PopupMenuItem(value: 2, child: Text("シフト表",
                      style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold))),
                  PopupMenuItem(value: 3, child: Text("投稿",
                      style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold))),
                  PopupMenuItem(value: 4, child: Text("勤怠修正申請",
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold))),
                  PopupMenuItem(value: 5, child: Text("注文",
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold))),
                  PopupMenuItem(value: 6, child: Text("会計",
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
