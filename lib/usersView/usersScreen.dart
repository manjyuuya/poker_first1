import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:poker_first/usersView/usersHome.dart';
import 'package:poker_first/usersView/usersOrder.dart';
import 'package:poker_first/usersView/usersSchedule.dart';
import 'package:poker_first/usersView/usersTournament.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  int selectedIndex = 0;
  List<Widget> pageList = [
    const UsersHome(),
    const UsersTournament(),
    const UsersOrder(),
   const UsersSchedule(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("ようこそ ${FirebaseAuth.instance.currentUser?.displayName ?? "ゲスト"}"),
      ),
      body: pageList[selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
              icon: Icon(
                Icons.home,
                color: Colors.black45,
              ),
              label: ''),
          BottomNavigationBarItem(
              icon: Icon(
                Icons.balance,
                color: Colors.black45,
              ),
              label: ''),
          BottomNavigationBarItem(
              icon: Icon(
                Icons.bakery_dining,
                color: Colors.black45,
              ),
              label: ''),
          BottomNavigationBarItem(
              icon: Icon(
                Icons.calendar_month,
                color: Colors.black45,
              ),
              label: ''),
        ],
        currentIndex: selectedIndex,
        onTap: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
      ),);
  }
}
