import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/asset_class.dart';
import '../core/backtest.dart';
import '../core/plan.dart';
import '../core/rebalance.dart';
import '../core/sample_data.dart';
import '../providers.dart';
import 'common.dart';

/// Target used when the questionnaire is not done yet: a plain 60/40.
const _fallbackTarget = {
  AssetClass.equity: 0.6,
  AssetClass.bonds: 0.4,
  AssetClass.property: 0.0,
  AssetClass.gold: 0.0,
  AssetClass.cash: 0.0,
};

final _targetProvider = Provider<Map<AssetClass, double>>(
  (ref) => ref.watch(planProvider)?.blended ?? _fallbackTarget,
);

final backtestsProvider = Provider<List<BacktestResult>>((ref) {
  final data = ref.watch(sampleDataProvider);
  final target = ref.watch(_targetProvider);
  return [
    for (final r in RebalanceRule.values)
      backtest(monthly: data, target: target, rule: r),
  ];
});

class InsightsTab extends ConsumerWidget {
  const InsightsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.all(16),
    children: const [
      RebalanceCard(),
      SizedBox(height: 12),
      BacktestCard(),
      SizedBox(height: 12),
      ForecastCard(),
      SizedBox(height: 8),
      DisclosureBanner(),
    ],
  );
}

class RebalanceCard extends ConsumerStatefulWidget {
  const RebalanceCard({super.key});

  @override
  ConsumerState<RebalanceCard> createState() => _RebalanceCardState();
}

class _RebalanceCardState extends ConsumerState<RebalanceCard> {
  final _flow = TextEditingController(text: '0');

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final values = ref.watch(currentMixProvider);
    final target = ref.watch(_targetProvider);
    final total = values.values.fold(0.0, (a, b) => a + b);
    final t = Theme.of(context).textTheme;
    final children = <Widget>[
      Text('Rebalancing', style: t.titleMedium),
      const SizedBox(height: 4),
      const Text(
        'Bands: ±3% per asset class (Vanguard-style default). '
        'Suggestions only — Samridhi never places orders.',
      ),
    ];
    if (total == 0) {
      children.add(
        const EmptyState('Add holdings in the Wealth tab to see drift.'),
      );
    } else {
      final cur = toWeights(values);
      final flow = double.tryParse(_flow.text.trim()) ?? 0;
      final breached = breachesBands(target, cur);
      final plan = cashFlowRebalance(
        values: values,
        target: target,
        cashFlow: flow,
      );
      children.addAll([
        const SizedBox(height: 8),
        for (final r in driftRows(target, cur))
          Text(
            '${r.assetClass.label}: ${fmtPct(r.current)} vs '
            '${fmtPct(r.target)} (${r.drift >= 0 ? '+' : ''}'
            '${fmtPct(r.drift)})',
          ),
        const SizedBox(height: 8),
        Chip(
          label: Text(breached ? 'Outside bands' : 'Within bands'),
          avatar: Icon(
            breached ? Icons.warning_amber : Icons.check_circle_outline,
            size: 18,
          ),
        ),
        TextField(
          controller: _flow,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: const InputDecoration(
            labelText: 'Contribution (+) or withdrawal (−)',
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (flow != 0) ...[
          const SizedBox(height: 8),
          Text(
            flow > 0
                ? 'Direct the contribution like this:'
                : 'Draw the withdrawal like this:',
          ),
          for (final c in AssetClass.values)
            if (plan.flows[c]!.abs() >= 0.5)
              Text(
                '${c.label}: ${plan.flows[c]! > 0 ? 'buy' : 'sell'} '
                '${fmtMoney(plan.flows[c]!.abs())}',
              ),
          Text(
            plan.stillBreached
                ? 'Still outside bands after this cash flow.'
                : 'Back within bands after this cash flow.',
          ),
        ],
        if (breached && (flow == 0 || plan.stillBreached)) ...[
          const SizedBox(height: 8),
          Text(
            'Sell-based option (simulated suggestion):',
            style: t.labelLarge,
          ),
          for (final e in fullRebalanceTrades(
            values: values,
            target: target,
          ).entries)
            if (e.value.abs() >= 0.5)
              Text(
                '${e.key.label}: ${e.value > 0 ? 'buy' : 'sell'} '
                '${fmtMoney(e.value.abs())}',
              ),
        ],
      ]);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class BacktestCard extends ConsumerWidget {
  const BacktestCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(backtestsProvider);
    final scheme = Theme.of(context).colorScheme;
    final colours = [scheme.outline, scheme.primary, scheme.tertiary];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Backtest (20 years, 10,000 start)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(sampleDataLabel),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  titlesData: const FlTitlesData(
                    topTitles: AxisTitles(),
                    rightTitles: AxisTitles(),
                    bottomTitles: AxisTitles(),
                  ),
                  gridData: const FlGridData(show: false),
                  lineBarsData: [
                    for (var i = 0; i < results.length; i++)
                      LineChartBarData(
                        spots: [
                          for (var m = 0; m < results[i].values.length; m++)
                            FlSpot(m.toDouble(), results[i].values[m]),
                        ],
                        color: colours[i],
                        dotData: const FlDotData(show: false),
                        barWidth: 2,
                      ),
                  ],
                ),
              ),
            ),
            for (var i = 0; i < results.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(Icons.show_chart, color: colours[i], size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${results[i].rule.label}: ends '
                        '${fmtMoney(results[i].finalValue)}, '
                        '${fmtPct(results[i].cagr)}/yr, '
                        'vol ${fmtPct(results[i].annualVol)}, '
                        'max drawdown ${fmtPct(results[i].maxDrawdown)}, '
                        '${results[i].rebalances} rebalances',
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            const Text('Costs and tax are not modelled.'),
          ],
        ),
      ),
    );
  }
}

class ForecastCard extends ConsumerWidget {
  const ForecastCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.watch(forecastsProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Next-year return forecast (exponential smoothing)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(sampleDataLabel),
            const SizedBox(height: 8),
            for (final e in fs.entries)
              Text(
                '${e.key.label}: ${fmtPct(e.value.mean.first)} '
                '(${fmtPct(e.value.confidence, 0)} band '
                '${fmtPct(e.value.lower.first)} to '
                '${fmtPct(e.value.upper.first)}) · band held '
                '${e.value.track.hits}/${e.value.track.trials} past years',
              ),
            const SizedBox(height: 4),
            const Text(
              'A simple statistical model, not a prediction you can rely on: '
              'the band is a guide to uncertainty, not a guarantee.',
            ),
          ],
        ),
      ),
    );
  }
}
