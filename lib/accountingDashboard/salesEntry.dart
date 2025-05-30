import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SalesEntryPage extends StatefulWidget {
  const SalesEntryPage({Key? key}) : super(key: key);

  @override
  _SalesEntryPageState createState() => _SalesEntryPageState();
}

class _SalesEntryPageState extends State<SalesEntryPage> {
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = '通常売上';
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  final List<String> _categories= ['通常売上', 'イベント売上', 'チップ購入', 'フード、ドリンク', '貸切', 'その他'];

  Future<void> _submitSale() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("ログインユーザーが見つかりません");

      await FirebaseFirestore.instance.collection('sales').add({
        'date': Timestamp.fromDate(_selectedDate),
        'category': _selectedCategory,
        'amount': int.parse(_amountController.text),
        'memo': _memoController.text.trim(),
        'staffId': user.uid,
        'createdAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('売上を登録しました')),
      );

      _amountController.clear();
      _memoController.clear();
      setState(() => _selectedDate = DateTime.now());

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('売上登録')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(children: [
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: '金額'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) return '金額を入力してください';
                if (int.tryParse(value) == null) return '数値を入力してください';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              items: _categories.map((cat) {
                return DropdownMenuItem(value: cat, child: Text(cat));
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedCategory = value);
              },
              decoration: const InputDecoration(labelText: 'カテゴリ'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _memoController,
              decoration: const InputDecoration(labelText: 'メモ'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('日付: '),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _selectedDate = picked);
                  },
                  child: Text('${_selectedDate.toLocal()}'.split(' ')[0]),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitSale,
              child: const Text('売上を登録'),
            ),
          ]),
        ),
      ),
    );
  }
}
