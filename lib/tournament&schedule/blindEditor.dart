import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BlindEditorPage extends StatefulWidget {
  final List<Map<String, dynamic>>? initialLevels;
  final String? initialTemplateName;

  const BlindEditorPage({super.key, this.initialLevels, this.initialTemplateName});

  @override
  State<BlindEditorPage> createState() => _BlindEditorPageState();
}

class _BlindEditorPageState extends State<BlindEditorPage> {
  List<Map<String, dynamic>> _levels = [];
  final TextEditingController _templateNameController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _levels = widget.initialLevels != null
        ? List<Map<String, dynamic>>.from(widget.initialLevels!)
        : [
      {'level': 1, 'small': 100, 'big': 200, 'ante': 0},
      {'level': 2, 'small': 200, 'big': 300, 'ante': 0},
      {'level': 3, 'small': 200, 'big': 400, 'ante': 0},
      {'level': 4, 'small': 300, 'big': 600, 'ante': 300},
      {'level': 5, 'small': 500, 'big': 1000, 'ante': 500},
      {'level': 6, 'small': 800, 'big': 1600, 'ante': 800},
      {'level': 7, 'small': 1000, 'big': 2000, 'ante': 1000},
      {'level': 8, 'small': 1500, 'big': 3000, 'ante': 1500},
      {'level': 9, 'small': 2000, 'big': 4000, 'ante': 2000},
      {'level': 10, 'small': 2500, 'big': 5000, 'ante': 2500},
      {'level': 11,'small': 3000, 'big': 6000, 'ante': 3000},
      {'level': 12,'small': 4000, 'big': 8000, 'ante': 4000},
      {'level': 13,'small': 5000, 'big': 10000, 'ante': 5000},
      {'level': 14,'small': 6000, 'big': 12000, 'ante': 6000},
      {'level': 15,'small': 8000, 'big': 16000, 'ante': 8000},
      {'level': 16,'small': 10000, 'big': 20000, 'ante': 10000},
      {'level': 17,'small': 12000, 'big': 24000, 'ante': 12000},
      {'level': 18,'small': 15000, 'big': 30000, 'ante': 15000},
      {'level': 19,'small': 20000, 'big': 40000, 'ante': 20000},
      {'level': 20,'small': 25000, 'big': 50000, 'ante': 25000},
    ];

    for (var level in _levels) {
      level['smallController'] = TextEditingController(text: level['small'].toString());
      level['bigController'] = TextEditingController(text: level['big'].toString());
      level['anteController'] = TextEditingController(text: level['ante'].toString());
    }

    if (widget.initialTemplateName != null) {
      _templateNameController.text = widget.initialTemplateName!;
    }
  }

  void _addLevel() {
    int nextLevel = _levels.length + 1;
    _levels.add({
      'level': nextLevel,
      'small': 0,
      'big': 0,
      'ante': 0,
      'smallController': TextEditingController(),
      'bigController': TextEditingController(),
      'anteController': TextEditingController(),
    });
    setState(() {});
  }

  void _removeLevel(int index) {
    _levels.removeAt(index);
    for (int i = 0; i < _levels.length; i++) {
      _levels[i]['level'] = i + 1;
    }
    setState(() {});
  }

  void _clearAllValues() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認'),
        content: const Text('本当にすべての数値をクリアしますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('OK')),
        ],
      ),
    );

    if (confirmed == true) {
      for (var level in _levels) {
        level['smallController'].text = '';
        level['bigController'].text = '';
        level['anteController'].text = '';
      }
      setState(() {});
    }
  }

  void _saveTemplate() async {
    final name = _templateNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('テンプレート名を入力してください')),
      );
      return;
    }

    // コントローラーからデータ抽出
    final List<Map<String, dynamic>> levels = _levels.map((level) {
      return {
        'level': level['level'],
        'small': int.tryParse(level['smallController'].text) ?? 0,
        'big': int.tryParse(level['bigController'].text) ?? 0,
        'ante': int.tryParse(level['anteController'].text) ?? 0,
      };
    }).toList();

    try {
      await FirebaseFirestore.instance.collection('blindTemplates').add({
        'name': name,
        'levels': levels,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('テンプレート "$name" を保存しました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存中にエラーが発生しました: $e')),
      );
    }
  }

  void _saveAndReturn() {
    final result = _levels.map((level) {
      return {
        'level': level['level'],
        'small': int.tryParse(level['smallController'].text) ?? 0,
        'big': int.tryParse(level['bigController'].text) ?? 0,
        'ante': int.tryParse(level['anteController'].text) ?? 0,
      };
    }).toList();

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ブラインドストラクチャー編集')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _templateNameController,
              decoration: const InputDecoration(labelText: 'テンプレート名（保存時に使用）'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                final selectedLevels = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BlindTemplateSelectorPage()),
                );
                if (selectedLevels != null && selectedLevels is List<Map<String, dynamic>>) {
                  setState(() {
                    _levels = selectedLevels.asMap().entries.map((e) {
                      final level = e.value;
                      return {
                        'level': e.key + 1,
                        'small': level['small'],
                        'big': level['big'],
                        'ante': level['ante'],
                        'smallController': TextEditingController(text: level['small'].toString()),
                        'bigController': TextEditingController(text: level['big'].toString()),
                        'anteController': TextEditingController(text: level['ante'].toString()),
                      };
                    }).toList();
                  });
                }
              },
              child: const Text('テンプレート読込'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _levels.length,
                itemBuilder: (context, index) {
                  final level = _levels[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Text('Lv${level['level']}'),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: level['smallController'],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'SB'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: level['bigController'],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'BB'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: level['anteController'],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Ante'),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeLevel(index),
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _addLevel,
                    child: const Text('レベル追加'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _clearAllValues,
                    child: const Text('全てクリア'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveTemplate,
                    child: const Text('テンプレート保存'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveAndReturn,
                    child: const Text('この構成を使う'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BlindTemplateSelectorPage extends StatelessWidget {
  const BlindTemplateSelectorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('テンプレートを選択')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('blindTemplates').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return ListTile(
                title: Text(data['name'] ?? '無名テンプレート'),
                onTap: () {
                  final levels = List<Map<String, dynamic>>.from(data['levels'] ?? []);
                  Navigator.pop(context, levels);
                },
              );
            },
          );
        },
      ),
    );
  }
}
