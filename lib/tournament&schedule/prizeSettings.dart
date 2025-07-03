import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PrizeSettingsPage extends StatelessWidget {
  const PrizeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プライズテンプレート一覧')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('prizeSettings').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('テンプレートが存在しません'));
          }
          final templates = snapshot.data!.docs;
          return ListView.builder(
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final data = templates[index].data() as Map<String, dynamic>;
              final docId = templates[index].id;
              return ListTile(
                title: Text(data['name'] ?? '名称未設定'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditPrizeTemplatePage(templateId: docId),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const EditPrizeTemplatePage(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class EditPrizeTemplatePage extends StatefulWidget {
  final String? templateId;
  const EditPrizeTemplatePage({super.key, this.templateId});

  @override
  State<EditPrizeTemplatePage> createState() => _EditPrizeTemplatePageState();
}

class _EditPrizeTemplatePageState extends State<EditPrizeTemplatePage> {
  final TextEditingController _nameController = TextEditingController();
  double entryPercentage = 100;
  double reentryPercentage = 100;
  double addonPercentage = 0;

  @override
  void initState() {
    super.initState();
    if (widget.templateId != null) _loadTemplate(widget.templateId!);
  }

  Future<void> _loadTemplate(String id) async {
    final doc = await FirebaseFirestore.instance.collection('prizeSettings').doc(id).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    setState(() {
      _nameController.text = data['name'] ?? '';
      entryPercentage = (data['entryPercentage'] ?? 100).toDouble();
      reentryPercentage = (data['reentryPercentage'] ?? 100).toDouble();
      addonPercentage = (data['addonPercentage'] ?? 0).toDouble();
    });
  }

  Future<void> _saveTemplate() async {
    final data = {
      'name': _nameController.text,
      'entryPercentage': entryPercentage,
      'reentryPercentage': reentryPercentage,
      'addonPercentage': addonPercentage,
    };
    final ref = FirebaseFirestore.instance.collection('prizeSettings');
    if (widget.templateId == null) {
      await ref.add(data);
    } else {
      await ref.doc(widget.templateId!).set(data);
    }
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('テンプレートを保存しました')),
      );
    }
  }

  Widget _buildSlider(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 16)),
        Slider(
          value: value,
          min: 0,
          max: 100,
          divisions: 20,
          label: '${value.toStringAsFixed(0)}%',
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.templateId == null ? 'テンプレート新規作成' : 'テンプレート編集')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'テンプレート名'),
            ),
            const SizedBox(height: 24),
            _buildSlider('エントリー反映率', entryPercentage, (v) => setState(() => entryPercentage = v)),
            _buildSlider('リエントリー反映率', reentryPercentage, (v) => setState(() => reentryPercentage = v)),
            _buildSlider('アドオン反映率', addonPercentage, (v) => setState(() => addonPercentage = v)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _saveTemplate,
              icon: const Icon(Icons.save),
              label: const Text('保存する'),
            ),
          ],
        ),
      ),
    );
  }
}
