import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/asset_class.dart';
import '../core/mvo.dart';
import '../core/plan.dart';
import '../providers.dart';
import 'common.dart';
import 'motion.dart';

class PlanTab extends ConsumerWidget {
  const PlanTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planProvider);
    final risk = ref.watch(riskScoreProvider);
    if (plan == null || risk == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          EmptyState(
            'Complete the Risk questionnaire to generate your target '
            'allocation.',
          ),
          DisclosureBanner(),
        ],
      );
    }
    final current = toWeights(ref.watch(currentMixProvider));
    final classes = AssetClass.values;
    final cov = covarianceFrom([
      for (final c in classes) c.volatility,
    ], defaultCorrelations);
    final w = [for (final c in classes) plan.blended[c]!];
    final er = portfolioReturn(w, [for (final c in classes) c.expectedReturn]);
    final vol = portfolioVariance(w, cov);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${risk.band.label} profile',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Illustrative expected return ${fmtPct(er)} / yr, '
          'volatility ${fmtPct(math.sqrt(vol))}',
        ),
        const SizedBox(height: 16),
        Text(
          'Target vs current',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final c in classes)
          _MixRow(c.label, plan.blended[c]!, current[c]!),
        const SizedBox(height: 16),
        const _TierPicker(),
        const SizedBox(height: 16),
        Text('By goal', style: Theme.of(context).textTheme.titleMedium),
        for (final p in plan.perGoal)
          Card(
            child: ListTile(
              title: Text(p.goal.name),
              subtitle: Text(
                '${p.goal.horizonYears.toStringAsFixed(0)} yrs · '
                '${[for (final c in classes)
                  if (p.allocation.weights[c]! >= 0.005) '${c.label} ${fmtPct(p.allocation.weights[c]!, 0)}'].join(' · ')}',
              ),
            ),
          ),
        const SizedBox(height: 8),
        const DisclosureBanner(),
      ],
    );
  }
}

class _MixRow extends StatelessWidget {
  const _MixRow(this.label, this.target, this.current);
  final String label;
  final double target;
  final double current;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label — target ${fmtPct(target)} · current ${fmtPct(current)}',
          ),
          const SizedBox(height: 4),
          AnimatedBar(value: target),
          const SizedBox(height: 2),
          AnimatedBar(
            value: current,
            height: 4,
            color: Theme.of(context).colorScheme.tertiary,
          ),
        ],
      ),
    );
  }
}

/// Per-goal glide paths (default) or one fixed risk tier 1-7 for everything.
class _TierPicker extends ConsumerWidget {
  const _TierPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tier = ref.watch(tierProvider).asData?.value;
    final db = ref.read(databaseProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Portfolio style', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('Per goal'),
              selected: tier == null,
              onSelected: (_) => db.removeSetting('plan.tier'),
            ),
            for (var t = 1; t <= riskTierCount; t++)
              ChoiceChip(
                label: Text('$t'),
                selected: tier == t,
                onSelected: (_) => db.setSetting('plan.tier', '$t'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          tier == null
              ? 'Each goal glides to safer assets as its date nears.'
              : 'Tier $tier of $riskTierCount (1 cautious, 7 adventurous): '
                    'one fixed portfolio for every goal. It does not de-risk '
                    'short-term goals, so a bad year could hit them hard.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
