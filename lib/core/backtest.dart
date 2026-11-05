import 'dart:math' as math;

import 'asset_class.dart';
import 'rebalance.dart';

enum RebalanceRule {
  none('Never rebalance'),
  annual('Rebalance every 12 months'),
  threshold('Rebalance when a band is breached');

  const RebalanceRule(this.label);
  final String label;
}

class BacktestResult {
  const BacktestResult({
    required this.rule,
    required this.values,
    required this.rebalances,
    required this.cagr,
    required this.annualVol,
    required this.maxDrawdown,
  });
  final RebalanceRule rule;

  /// Portfolio value at the start and after each month.
  final List<double> values;
  final int rebalances;
  final double cagr;
  final double annualVol;

  /// Largest peak-to-trough fall, as a positive fraction.
  final double maxDrawdown;

  double get finalValue => values.last;
}

/// Replays [monthly] returns for a portfolio started at [target] weights with
/// [initial] money, applying [rule]. Rebalancing here is simulated on past
/// data only; no trade is ever placed. Costs are not modelled.
BacktestResult backtest({
  required Map<AssetClass, List<double>> monthly,
  required Map<AssetClass, double> target,
  required RebalanceRule rule,
  RebalanceBands bands = RebalanceBands.standard,
  double initial = 10000,
}) {
  final n = monthly.values.first.length;
  var held = {for (final c in AssetClass.values) c: initial * (target[c] ?? 0)};
  final values = <double>[initial];
  final rets = <double>[];
  var rebalances = 0;
  for (var m = 0; m < n; m++) {
    final before = held.values.fold(0.0, (a, b) => a + b);
    held = {
      for (final c in AssetClass.values) c: held[c]! * (1 + monthly[c]![m]),
    };
    final total = held.values.fold(0.0, (a, b) => a + b);
    rets.add(total / before - 1);
    values.add(total);
    final due = switch (rule) {
      RebalanceRule.none => false,
      RebalanceRule.annual => (m + 1) % 12 == 0,
      RebalanceRule.threshold => breachesBands(target, {
        for (final c in AssetClass.values) c: held[c]! / total,
      }, bands),
    };
    if (due) {
      held = {for (final c in AssetClass.values) c: total * (target[c] ?? 0)};
      rebalances++;
    }
  }
  final years = n / 12;
  final mean = rets.reduce((a, b) => a + b) / rets.length;
  final variance =
      rets.fold(0.0, (a, r) => a + (r - mean) * (r - mean)) / (rets.length - 1);
  var peak = values.first, dd = 0.0;
  for (final v in values) {
    peak = math.max(peak, v);
    dd = math.max(dd, (peak - v) / peak);
  }
  return BacktestResult(
    rule: rule,
    values: values,
    rebalances: rebalances,
    cagr: math.pow(values.last / initial, 1 / years).toDouble() - 1,
    annualVol: math.sqrt(variance * 12),
    maxDrawdown: dd,
  );
}
