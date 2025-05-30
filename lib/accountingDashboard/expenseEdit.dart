import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseEditPage extends StatefulWidget {
  final String expenseId;
  final DocumentSnapshot initialData;

  const ExpenseEditPage({required this.expenseId, required this.initialData, Key? key}) : super(key: key);

  @override
  State<ExpenseEditPage> createState() => _ExpenseEditPageState();
}

class _ExpenseEditPageState extends State<ExpenseEditPage> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _selectedDate;
  late String _category;
  late String _paymentMethod;
  late int _amount;
  late String _memo;

  final List<String> _categories = ['備品', '交通費', '光熱費', '仕入', '人件費', 'その他'];
  final List<String> _paymentMethods = ['現金', 'クレジット', '振込', 'その他'];

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _selectedDate = (data['date'] as Timestamp).toDate();
    _category = data['category'] ?? '備品';
    _paymentMethod = data['paymentMethod'] ?? '現金';
    _amount = data['amount'] ?? 0;
    _memo = data['memo'] ?? '';
  }

  Future<void> _updateExpense() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    try {
      await FirebaseFirestore.instance.collection('expenses').doc(widget.expenseId).update({
        'date': Timestamp.fromDate(_selectedDate),
        'category': _category,
        'amount': _amount,
        'paymentMethod': _paymentMethod,
        'memo': _memo,
        'updatedAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('経費を更新しました')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新エラー: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('経費編集')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
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
                    setState(() => _selectedDate = picked);
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
                initialValue: _amount.toString(),
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
                initialValue: _memo,
                decoration: const InputDecoration(labelText: '備考（任意）'),
                onSaved: (value) => _memo = value ?? '',
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _updateExpense,
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
