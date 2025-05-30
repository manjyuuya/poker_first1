import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'expenseList.dart';

class ExpenseEntryPage extends StatefulWidget {
  const ExpenseEntryPage({Key? key}) : super(key: key);

  @override
  State<ExpenseEntryPage> createState() => _ExpenseEntryPageState();
}

class _ExpenseEntryPageState extends State<ExpenseEntryPage> {
  final _formKey = GlobalKey<FormState>();

  DateTime _selectedDate = DateTime.now();
  String _category = '備品';
  String _paymentMethod = '現金';
  int _amount = 0;
  String _memo = '';

  final List<String> _categories = ['備品', '交通費', '光熱費', '仕入', '人件費', 'その他'];
  final List<String> _paymentMethods = ['現金', 'クレジット', '振込', 'その他'];

  Future<void> _submitExpense() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final expenseData = {
      'date': Timestamp.fromDate(_selectedDate),
      'category': _category,
      'amount': _amount,
      'paymentMethod': _paymentMethod,
      'memo': _memo,
      'createdBy': user.uid,
      'createdAt': Timestamp.now(),
    };

    try {
      await FirebaseFirestore.instance.collection('expenses').add(expenseData);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('経費を登録しました')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登録エラー: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('経費登録')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(children: [
            ListTile(
              title: const Text('日付'),
              subtitle: Text('${_selectedDate.toLocal()}'.split(' ')[0]),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setState(() {
                    _selectedDate = picked;
                  });
                }
              },
            ),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'カテゴリ'),
              items: _categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (value) => setState(() => _category = value!),
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: '金額（円）'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || int.tryParse(value) == null || int.parse(value) <= 0) {
                  return '有効な金額を入力してください';
                }
                return null;
              },
              onSaved: (value) => _amount = int.parse(value!),
            ),
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: const InputDecoration(labelText: '支払方法'),
              items: _paymentMethods.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (value) => setState(() => _paymentMethod = value!),
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: '備考（任意）'),
              onSaved: (value) => _memo = value ?? '',
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitExpense,
              child: const Text('登録'),
            ),
        ElevatedButton(
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ExpenseListPage()));
            }, child: const Text("経費リスト"),
           ),
          ]
          ),
        ),
      ),
    );
  }
}
