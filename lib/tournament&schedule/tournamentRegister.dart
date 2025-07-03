import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:poker_first/tournament&schedule/blindEditor.dart';
import 'package:poker_first/tournament&schedule/prizeSettings.dart';

class TournamentRegisterPage extends StatefulWidget {
  const TournamentRegisterPage({super.key});

  @override
  State<TournamentRegisterPage> createState() => _TournamentRegisterPageState();
}

class _TournamentRegisterPageState extends State<TournamentRegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _entryFeeController = TextEditingController();
  final TextEditingController _reentryFeeController = TextEditingController();
  final TextEditingController _addonFeeController = TextEditingController();
  final TextEditingController _blindStructureController = TextEditingController();
  final TextEditingController _prizeController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _initialStackController = TextEditingController();
  final TextEditingController _addonStackController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _registerCloseTime = const TimeOfDay(hour: 21, minute: 0);
  TimeOfDay _startTime = const TimeOfDay(hour: 19, minute: 0);

  List<Map<String, dynamic>> _blindLevels = [];

  final List<Map<String, int>> breakOptions = [
    {'afterMinutes': 60, 'durationMinutes': 5},
    {'afterMinutes': 60, 'durationMinutes': 10},
    {'afterMinutes': 90, 'durationMinutes': 5},
    {'afterMinutes': 90, 'durationMinutes': 10},
    {'afterMinutes': 120, 'durationMinutes': 5},
    {'afterMinutes': 120, 'durationMinutes': 10},
  ];

  int? _selectedBreakIndex;

  String? _selectedPrizeTemplateId;
  String? _selectedPrizeTemplateName;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBreakIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('休憩時間を選択してください')),
      );
      return;
    }

    final docRef = FirebaseFirestore.instance.collection('tournaments').doc();
    final startDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    final registerCloseDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _registerCloseTime.hour,
      _registerCloseTime.minute,
    );

    final selectedBreak = breakOptions[_selectedBreakIndex!];

    await docRef.set({
      'name': _nameController.text.trim(),
      'date': _selectedDate,
      'entryFee': int.tryParse(_entryFeeController.text.trim()) ?? 0,
      'reentryFee': int.tryParse(_reentryFeeController.text.trim()) ?? 0,
      'addonFee': int.tryParse(_addonFeeController.text.trim()) ?? 0,
      'initialStack': int.tryParse(_initialStackController.text.trim()) ?? 0,
      'addonStack': int.tryParse(_addonStackController.text.trim()) ?? 0,
      'startTime': startDateTime,
      'registerClose': registerCloseDateTime,
      'blindStructure': int.tryParse(_blindStructureController.text.trim()) ?? 0,
      'blindLevels': _blindLevels,
      'prize': _prizeController.text.trim(),
      'prizeCalculated': false,
      'prizeAmount': 0,
      'memo': _memoController.text.trim(),
      'capacity': int.tryParse(_capacityController.text.trim()) ?? 0,
      'breakTime': selectedBreak,
      'createdAt': FieldValue.serverTimestamp(),
      'isOpen': true,
      'prizeTemplateId': _selectedPrizeTemplateId,
      'prizeTemplateName': _selectedPrizeTemplateName,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('トーナメントを登録しました')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _openBlindEditor() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BlindEditorPage(),
      ),
    );
    if (result != null && result is List<Map<String, dynamic>>) {
      setState(() => _blindLevels = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('トーナメント登録')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'トーナメント名 *'),
                validator: (v) => v == null || v.trim().isEmpty ? '必須項目です' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('開催日 *: '),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2099),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    child: Text(DateFormat('yyyy/MM/dd').format(_selectedDate)),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text('開始時間 *: '),
                  TextButton(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _startTime,
                      );
                      if (picked != null) {
                        setState(() => _startTime = picked);
                      }
                    },
                    child: Text(_startTime.format(context)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('レジスト終了時間 *: '),
                  TextButton(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _registerCloseTime,
                      );
                      if (picked != null) {
                        setState(() => _registerCloseTime = picked);
                      }
                    },
                    child: Text(_registerCloseTime.format(context)),
                  ),
                ],
              ),
              TextFormField(
                controller: _entryFeeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'エントリー費 *'),
                validator: (v) => v == null || v.isEmpty ? '必須項目です' : null,
              ),
              TextFormField(
                controller: _reentryFeeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'リエントリー費 *'),
                validator: (v) => v == null || v.isEmpty ? '必須項目です' : null,
              ),
              TextFormField(
                controller: _addonFeeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'アドオン費 *'),
                validator: (v) => v == null || v.isEmpty ? '必須項目です' : null,
              ),
              TextFormField(
                controller: _initialStackController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '初期スタック *'),
                validator: (v) => v == null || v.isEmpty ? '必須項目です' : null,
              ),
              TextFormField(
                controller: _addonStackController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'アドオンチップ量 *'),
                validator: (v) => v == null || v.isEmpty ? '必須項目です' : null,
              ),
              TextFormField(
                controller: _blindStructureController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'ブラインド構成（例: 30分）*'),
                validator: (v) => v == null || v.isEmpty ? '必須項目です' : null,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ブラインドレベル設定', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: _openBlindEditor,
                    child: const Text('編集'),
                  ),
                ],
              ),
              if (_blindLevels.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _blindLevels
                      .map((level) => Text('Lv${level['level']}: ${level['small']} / ${level['big']} (Ante: ${level['ante']})'))
                      .toList(),
                ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              const Text('プライズテンプレート', style: TextStyle(fontWeight: FontWeight.bold)),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('prizeSettings').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  final docs = snapshot.data!.docs;
                  return DropdownButtonFormField<String>(
                    value: _selectedPrizeTemplateId,
                    hint: const Text('テンプレートを選択'),
                    items: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['name'] ?? '名称未設定';
                      return DropdownMenuItem(
                        value: doc.id,
                        child: Text(name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedPrizeTemplateId = value;
                        _selectedPrizeTemplateName = docs.firstWhere((doc) => doc.id == value!)['name'];
                      });
                    },
                  );
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.settings),
                label: const Text('テンプレートを編集/作成'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrizeSettingsPage()),
                  );
                },
              ),
              const Divider(height: 32),
              const Text('休憩時間（ブレイク）', style: TextStyle(fontWeight: FontWeight.bold)),
              Column(
                children: List.generate(breakOptions.length, (index) {
                  final option = breakOptions[index];
                  final label = '${option['afterMinutes']}分経過で${option['durationMinutes']}分休憩';
                  return RadioListTile<int>(
                    title: Text(label),
                    value: index,
                    groupValue: _selectedBreakIndex,
                    onChanged: (value) => setState(() => _selectedBreakIndex = value),
                  );
                }),
              ),
              TextFormField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '定員（任意）'),
              ),
              TextFormField(
                controller: _prizeController,
                decoration: const InputDecoration(labelText: '賞品（チケットなど）'),
              ),
              TextFormField(
                controller: _memoController,
                decoration: const InputDecoration(labelText: 'メモ'),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('登録'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}