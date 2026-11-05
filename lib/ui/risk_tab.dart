import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/risk_profile.dart';
import '../providers.dart';

class RiskTab extends ConsumerStatefulWidget {
  const RiskTab({super.key});

  @override
  ConsumerState<RiskTab> createState() => _RiskTabState();
}

class _RiskTabState extends ConsumerState<RiskTab> {
  final Map<String, int> _answers = {};
  bool _seeded = false;

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(riskAnswersProvider).asData?.value;
    if (!_seeded && saved != null) {
      _answers.addAll(saved);
      _seeded = true;
    }
    final complete = _answers.length == riskQuestions.length;
    final preview = _answers.isEmpty ? null : scoreRisk(_answers);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final q in riskQuestions)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: RadioGroup<int>(
                groupValue: _answers[q.id],
                onChanged: (v) => setState(() => _answers[q.id] = v!),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.prompt,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    for (var i = 0; i < q.options.length; i++)
                      RadioListTile<int>(
                        dense: true,
                        title: Text(q.options[i].label),
                        value: i,
                      ),
                  ],
                ),
              ),
            ),
          ),
        if (preview != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Risk profile: ${preview.band.label} '
              '(${preview.score.toStringAsFixed(0)}/100)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        FilledButton(
          onPressed: complete
              ? () async {
                  await ref.read(databaseProvider).saveRiskAnswers(_answers);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Risk profile saved')),
                    );
                  }
                }
              : null,
          child: Text(complete ? 'Save risk profile' : 'Answer all questions'),
        ),
      ],
    );
  }
}
