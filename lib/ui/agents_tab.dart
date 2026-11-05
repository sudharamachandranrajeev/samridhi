import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../agents/agents.dart';
import '../agents/orchestrator.dart';
import '../ai/ai_store.dart';
import '../ai/llm_client.dart';
import '../providers.dart';
import 'common.dart';
import 'dialogs.dart';

class AgentsTab extends ConsumerStatefulWidget {
  const AgentsTab({super.key});

  @override
  ConsumerState<AgentsTab> createState() => _AgentsTabState();
}

class _AgentsTabState extends ConsumerState<AgentsTab> {
  String? _narrative;
  String? _narrativeModel;
  String? _narrativeError;
  bool _busy = false;

  Future<void> _explain(AgentContext ctx) async {
    final db = ref.read(databaseProvider);
    setState(() {
      _busy = true;
      _narrativeError = null;
    });
    try {
      final cfg = await activeAiConfig(
        db,
        () => const FlutterSecureStorage().read(key: aiKeyName),
      );
      if (cfg == null) {
        _narrativeError =
            'AI is off or not fully configured. Set it up in Settings.';
      } else {
        final run = await Orchestrator(
          agents: const [],
          narrator: Narrator(LlmClient(cfg)),
        ).run(ctx);
        _narrative = run.narrative;
        _narrativeModel = cfg.model;
        if (run.narrative == null) _narrativeError = run.errors.join('\n');
      }
    } on Object catch (e) {
      _narrativeError = '$e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.read(databaseProvider);
    final enabled = ref.watch(agentsEnabledProvider).asData?.value ?? false;
    final ctx = ref.watch(agentContextProvider);
    final decisions = ref.watch(decisionsProvider).asData?.value ?? const {};
    final t = Theme.of(context).textTheme;
    if (!enabled) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Agents are off', style: t.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Agents read your plan and holdings on this device and suggest '
            'next steps: rebalancing, tax-wrapper order, an outlook. They '
            'never place trades or move money — every suggestion waits for '
            'your tap, and "Accept" only records that you intend to act.',
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => db.setSetting('agents.enabled', '1'),
            child: const Text('Turn agents on'),
          ),
          const SizedBox(height: 8),
          const DisclosureBanner(),
        ],
      );
    }
    if (ctx == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          EmptyState('Complete the Risk questionnaire so agents have a plan.'),
          DisclosureBanner(),
        ],
      );
    }
    final run = Orchestrator().runAgents(ctx);
    final aiOn = ref.watch(aiEnabledProvider).asData?.value ?? false;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: Text('Suggestions', style: t.titleMedium)),
            TextButton(
              onPressed: () => db.setSetting('agents.enabled', '0'),
              child: const Text('Turn off'),
            ),
          ],
        ),
        const Text(
          'Suggestions only. Samridhi never trades for you; accepting records '
          'your intent and you carry it out yourself.',
        ),
        const SizedBox(height: 8),
        for (final s in run.suggestions) _SuggestionCard(s, decisions[s.id]),
        for (final e in run.errors) Text('Agent error: $e'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Plain-English explanation (AI)', style: t.titleSmall),
                if (!aiOn)
                  const Text(
                    'Off. Add your own model in Settings → AI narration to '
                    'enable it.',
                  )
                else ...[
                  const Text(
                    'Sends rounded, anonymous figures to your configured '
                    'model.',
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy ? null : () => _explain(ctx),
                    child: const Text('Explain my plan'),
                  ),
                ],
                if (_busy) const LinearProgressIndicator(),
                if (_narrativeError != null)
                  Text(
                    _narrativeError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_narrative != null) ...[
                  const SizedBox(height: 8),
                  Text(_narrative!),
                  const SizedBox(height: 4),
                  Text(
                    'AI-generated by $_narrativeModel — it can be wrong; '
                    'check it against the figures above. Narrative only: it '
                    'adds no forecast and changes nothing.',
                    style: t.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        const DisclosureBanner(),
      ],
    );
  }
}

class _SuggestionCard extends ConsumerWidget {
  const _SuggestionCard(this.s, this.status);
  final Suggestion s;
  final String? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.agent, style: t.labelSmall),
            Text(s.title, style: t.titleSmall),
            const SizedBox(height: 4),
            Text(s.detail),
            const SizedBox(height: 4),
            Text(
              'Confidence: ${s.confidence}',
              style: t.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
            if (s.actionable) ...[
              const SizedBox(height: 8),
              if (status == null)
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: () async {
                        await db.decide(s.id, s.agent, s.title, 'accepted');
                        if (context.mounted) {
                          showSnack(
                            context,
                            'Recorded. Nothing was traded — carry this out '
                            'yourself.',
                          );
                        }
                      },
                      child: const Text('Accept (record my intent)'),
                    ),
                    TextButton(
                      onPressed: () =>
                          db.decide(s.id, s.agent, s.title, 'dismissed'),
                      child: const Text('Dismiss'),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Chip(
                      label: Text(
                        status == 'accepted'
                            ? 'Accepted — not executed'
                            : 'Dismissed',
                      ),
                    ),
                    TextButton(
                      onPressed: () => db.undecide(s.id),
                      child: const Text('Undo'),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
