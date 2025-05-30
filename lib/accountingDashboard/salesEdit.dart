import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SalesEditPage extends StatefulWidget {
  final String saleId;
  final DocumentSnapshot? initialData;

  const SalesEditPage({Key? key, required this.saleId, this.initialData}) : super(key: key);

  @override
  State<SalesEditPage> createState() => _SalesEditPageState();
}

class _SalesEditPageState extends State<SalesEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;

  late DateTime _selectedDate;
  late String _category;
  late int _amount;
  late String _memo;

  final _categories = ['通常売上', 'イベント売上', 'チップ購入', 'フード、ドリンク', '貸切', 'その他'];

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _selectedDate = (data?['date'] as Timestamp?)?.toDate() ?? DateTime.now();
    _category = data?['category'] ?? 'チップ販売';
    _amount = data?['amount'] ?? 0;
    _memo = data?['memo'] ?? '';
  }

  Future<void> _updateSale() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    try {
      await _firestore.collection('sales').doc(widget.saleId).update({
        'date': Timestamp.fromDate(_selectedDate),
        'category': _category,
        'amount': _amount,
        'memo': _memo,
        'updatedAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('売上を更新しました')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新エラー: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('売上編集')),
      body: Padding(
        padding: const EdgeInsets.all(16),
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
              TextFormField(
                initialValue: _memo,
                decoration: const InputDecoration(labelText: '備考（任意）'),
                onSaved: (value) => _memo = value ?? '',
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _updateSale,
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
