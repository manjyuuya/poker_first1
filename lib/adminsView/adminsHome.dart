import 'package:flutter/material.dart';
import 'package:poker_first/adminsView/adminsPost.dart';
import 'package:poker_first/adminsView/shiftApproval.dart';


class OwnersHome extends StatefulWidget {
  const OwnersHome({super.key});

  @override
  State<OwnersHome> createState() => _OwnersHomeState();
}

class _OwnersHomeState extends State<OwnersHome> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(onPressed: (){
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => ShiftApprovalPage())
              );
            }, child: Text("シフト承認")),
            ElevatedButton(onPressed: (){
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) =>AdminsPost())
              );
            }, child: Text("投稿"))
          ],
        ),
      ),
    );
  }
}
