import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PrizeDistributionPage extends StatefulWidget {
  final String tournamentId;
  const PrizeDistributionPage({super.key, required this.tournamentId});

  @override
  State<PrizeDistributionPage> createState() => _PrizeDistributionPageState();
}

class _PrizeDistributionPageState extends State<PrizeDistributionPage> {
  int prizeAmount = 0;
  List<double> prizePercentages = [50, 30, 20];
  List<TextEditingController> _controllers = [];
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPrizeAmount();
  }

  Future<void> _loadPrizeAmount() async {
    final doc = await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      prizeAmount = data['prizeAmount'] ?? 0;
      prizePercentages = List<double>.from(
          (data['prizeDistribution'] ?? [50, 30, 20]).map((e) => (e as num).toDouble()));

      _controllers = prizePercentages
          .map((p) => TextEditingController(text: p.toStringAsFixed(1)))
          .toList();

      setState(() {});
    }
  }

  void _updatePercentage(int index, double value) {
    setState(() {
      prizePercentages[index] = value;
      _controllers[index].text = value.toStringAsFixed(1);
    });
  }

  void _updateFromText(int index, String value) {
    final parsed = double.tryParse(value);
    if (parsed != null && parsed >= 0 && parsed <= 100) {
      setState(() => prizePercentages[index] = parsed);
    }
  }

  double get totalPercentage =>
      prizePercentages.fold(0.0, (sum, e) => sum + e);

  List<Map<String, dynamic>> _buildWinners() {
    return List.generate(prizePercentages.length, (i) {
      final percent = prizePercentages[i];
      final amount = ((percent / 100) * prizeAmount).round();
      return {
        'rank': i + 1,
        'percent': percent,
        'amount': amount,
      };
    });
  }

  Future<void> _saveDistribution() async {
    if (totalPercentage != 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('合計が100%になるように調整してください')),
      );
      return;
    }

    setState(() => isSaving = true);
    final winners = _buildWinners();

    await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .update({
      'prizeDistribution': prizePercentages,
      'prizeWinners': winners,
      'prizeConfirmed': true,
    });

    setState(() => isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プライズ配分を保存しました')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プライズ配分決定')),
      body: prizeAmount == 0
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('総プライズ額: ¥$prizeAmount',
                style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: prizePercentages.length,
                itemBuilder: (context, index) {
                  final percent = prizePercentages[index];
                  final amount = ((percent / 100) * prizeAmount).round();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${index + 1}位: $amount'),
                      Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Slider(
                              value: percent,
                              min: 0,
                              max: 100,
                              divisions: 100,
                              label: '${percent.toStringAsFixed(1)}%',
                              onChanged: (value) =>
                                  _updatePercentage(index, value),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _controllers[index],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                suffixText: '%',
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 0),
                              ),
                              onChanged: (value) =>
                                  _updateFromText(index, value),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('順位を追加'),
              onPressed: () {
                setState(() {
                  prizePercentages.add(0);
                  _controllers.add(TextEditingController(text: '0.0'));
                });
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: isSaving ? null : _saveDistribution,
              icon: const Icon(Icons.save),
              label: const Text('確定して保存'),
            ),
            const SizedBox(height: 8),
            Text(
              '合計: ${totalPercentage.toStringAsFixed(1)}%',
              style: TextStyle(
                  color: totalPercentage != 100 ? Colors.red : Colors.green),
            )
          ],
        ),
      ),
    );
  }
}

