import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:poker_first/adminsView/adminsPost.dart';
import 'package:poker_first/adminsView/shiftApproval.dart';
import 'package:poker_first/usersView/userDetailPage.dart';

class AdminsHome extends StatefulWidget {
  const AdminsHome({super.key});

  @override
  State<AdminsHome> createState() => _AdminsHomeState();
}

class _AdminsHomeState extends State<AdminsHome> {
  final TextEditingController _pokerNameController = TextEditingController();
  final TextEditingController _loginIdController = TextEditingController();
  final TextEditingController _visitCountController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();
  final TextEditingController _birth4DigitsController = TextEditingController();
  DateTime? _lastVisitAfterDate;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  void _navigateTo(BuildContext context, Widget page) {
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  Future<void> _searchUsers() async {
    setState(() {
      _isLoading = true;
      _searchResults.clear();
    });

    try {
      final firestore = FirebaseFirestore.instance;
      Query query = firestore.collection('users');

      if (_pokerNameController.text.isNotEmpty) {
        query = query.where('pokerName', isEqualTo: _pokerNameController.text.trim());
      }

      if (_loginIdController.text.isNotEmpty) {
        query = query.where('loginId', isEqualTo: _loginIdController.text.trim());
      }

      if (_birth4DigitsController.text.isNotEmpty && _birth4DigitsController.text.length == 4) {
        query = query.where('birthMonthDay', isEqualTo: _birth4DigitsController.text.trim());
      }

      if (_lastVisitAfterDate != null) {
        query = query.where('lastVisitDate', isGreaterThanOrEqualTo: Timestamp.fromDate(_lastVisitAfterDate!));
      }

      if (_visitCountController.text.isNotEmpty) {
        final count = int.tryParse(_visitCountController.text);
        if (count != null) {
          query = query.where('visitCount', isGreaterThanOrEqualTo: count);
        }
      }

      if (_pointsController.text.isNotEmpty) {
        final points = int.tryParse(_pointsController.text);
        if (points != null) {
          query = query.where('points', isGreaterThanOrEqualTo: points);
        }
      }

      final result = await query.get();

      setState(() {
        _searchResults = result.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      });
    } catch (e) {
      print('検索エラー: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _resetFields() {
    _pokerNameController.clear();
    _loginIdController.clear();
    _visitCountController.clear();
    _pointsController.clear();
    _birth4DigitsController.clear();
    _lastVisitAfterDate = null;
    _searchResults.clear();
    setState(() {});
  }

  Widget _buildUserItem(Map<String, dynamic> user) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text("PokerName: ${user['pokerName'] ?? 'なし'}"),
        subtitle: Text("Login ID: ${user['loginId'] ?? 'なし'}"),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("来店回数: ${user['visitCount'] ?? '不明'}"),
            Text("ポイント: ${user['points'] ?? '0'}"),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserDetailPage(userData: user),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickDate(Function(DateTime) onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("管理者画面"),
        actions: [
          Builder(
            builder: (context) {
              return PopupMenuButton<int>(
                icon: const Icon(Icons.menu, size: 30),
                onSelected: (value) {
                  switch (value) {
                    case 1:
                      _navigateTo(context, const ShiftApprovalPage());
                      break;
                    case 2:
                      _navigateTo(context, const AdminsPost());
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 1, child: Text("シフト承認")),
                  PopupMenuItem(value: 2, child: Text("投稿")),
                ],
                color: Colors.white,
                elevation: 8,
                position: PopupMenuPosition.under,
                constraints: const BoxConstraints(minWidth: 150),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _pokerNameController,
              decoration: const InputDecoration(labelText: 'PokerName'),
            ),
            TextField(
              controller: _loginIdController,
              decoration: const InputDecoration(labelText: 'Login ID'),
            ),
            TextField(
              controller: _birth4DigitsController,
              decoration: const InputDecoration(labelText: '誕生日（0401）'),
              keyboardType: TextInputType.number,
              maxLength: 4,
            ),
            TextButton(
              onPressed: () => _pickDate((d) => setState(() => _lastVisitAfterDate = d)),
              child: Text(_lastVisitAfterDate == null ? '最終来店日以降' : '最終来店日: \${_lastVisitAfterDate!.toLocal()}'.split(' ')[0]),
            ),
            TextField(
              controller: _visitCountController,
              decoration: const InputDecoration(labelText: '来店回数（〇回以上）'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _pointsController,
              decoration: const InputDecoration(labelText: 'ポイント（〇pt以上）'),
              keyboardType: TextInputType.number,
            ),
            Row(
              children: [
                ElevatedButton(onPressed: _searchUsers, child: const Text('検索')),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _resetFields, child: const Text('リセット')),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_searchResults.isEmpty)
              const Text("検索結果がありません")
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) => _buildUserItem(_searchResults[index]),
                ),
              )
          ],
        ),
      ),
    );
  }
}