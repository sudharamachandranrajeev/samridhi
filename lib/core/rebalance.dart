import 'asset_class.dart';

/// Drift tolerance bands, in absolute portfolio-weight fractions.
///
/// Defaults follow the published Vanguard research summarised in
/// `docs/plan/2026-11-05-competitor-research.md`: a 3% band for a typical
/// 60/40 portfolio, and a 200/175 bp asymmetric band for glide-path funds.
class RebalanceBands {
  const RebalanceBands({this.over = 0.03, this.under = 0.03});

  /// Band for a class running above target (current - target > over).
  final double over;

  /// Band for a class running below target (target - current > under).
  final double under;

  static const standard = RebalanceBands();
  static const glidePath = RebalanceBands(over: 0.02, under: 0.0175);
}

/// One class's position against its target.
class DriftRow {
  const DriftRow(this.assetClass, this.target, this.current);
  final AssetClass assetClass;
  final double target;
  final double current;
  double get drift => current - target;
}

List<DriftRow> driftRows(
  Map<AssetClass, double> target,
  Map<AssetClass, double> current,
) => [
  for (final c in AssetClass.values)
    DriftRow(c, target[c] ?? 0, current[c] ?? 0),
];

/// True if any class sits outside its band.
bool breachesBands(
  Map<AssetClass, double> target,
  Map<AssetClass, double> current, [
  RebalanceBands bands = RebalanceBands.standard,
]) => driftRows(
  target,
  current,
).any((r) => r.drift > bands.over + 1e-12 || -r.drift > bands.under + 1e-12);

/// Result of directing a cash flow, expressed as money per class
/// (positive = buy, negative = sell/withdraw).
class RebalancePlan {
  const RebalancePlan({
    required this.flows,
    required this.afterWeights,
    required this.stillBreached,
  });
  final Map<AssetClass, double> flows;
  final Map<AssetClass, double> afterWeights;

  /// Whether bands are still breached after applying [flows].
  final bool stillBreached;
}

Map<AssetClass, double> _weights(Map<AssetClass, double> v) {
  final t = v.values.fold(0.0, (a, b) => a + b);
  return {for (final e in v.entries) e.key: t == 0 ? 0.0 : e.value / t};
}

double _pos(double x) => x < 0 ? 0 : x;

/// Cash-flow rebalancing: a contribution (+) buys the most underweight
/// classes first; a withdrawal (-) is drawn from the most overweight classes
/// first. Never produces a sell for a contribution or a buy for a withdrawal,
/// so it avoids realising gains where possible.
///
/// [values] are current money amounts per class; [target] sums to 1.
RebalancePlan cashFlowRebalance({
  required Map<AssetClass, double> values,
  required Map<AssetClass, double> target,
  required double cashFlow,
  RebalanceBands bands = RebalanceBands.standard,
}) {
  final total = values.values.fold(0.0, (a, b) => a + b);
  final flows = {for (final c in AssetClass.values) c: 0.0};
  if (cashFlow > 0) {
    final newTotal = total + cashFlow;
    final short = {
      for (final c in AssetClass.values)
        c: _pos((target[c] ?? 0) * newTotal - (values[c] ?? 0)),
    };
    final shortSum = short.values.fold(0.0, (a, b) => a + b);
    if (shortSum >= cashFlow) {
      for (final c in AssetClass.values) {
        flows[c] = shortSum == 0 ? 0 : cashFlow * short[c]! / shortSum;
      }
    } else {
      // Fill every shortfall, spread the rest by target weight.
      final rest = cashFlow - shortSum;
      for (final c in AssetClass.values) {
        flows[c] = short[c]! + rest * (target[c] ?? 0);
      }
    }
  } else if (cashFlow < 0) {
    // Cannot withdraw more than is held.
    final w = (-cashFlow) > total ? total : -cashFlow;
    final newTotal = total - w;
    final excess = {
      for (final c in AssetClass.values)
        c: _pos((values[c] ?? 0) - (target[c] ?? 0) * newTotal),
    };
    final excessSum = excess.values.fold(0.0, (a, b) => a + b);
    if (excessSum >= w) {
      for (final c in AssetClass.values) {
        flows[c] = excessSum == 0 ? 0 : -w * excess[c]! / excessSum;
      }
    } else {
      final rest = w - excessSum;
      for (final c in AssetClass.values) {
        flows[c] =
            -excess[c]! - (total == 0 ? 0 : rest * (values[c] ?? 0) / total);
      }
    }
  }
  final after = {
    for (final c in AssetClass.values) c: (values[c] ?? 0) + flows[c]!,
  };
  final aw = _weights(after);
  return RebalancePlan(
    flows: flows,
    afterWeights: aw,
    stillBreached: breachesBands(target, aw, bands),
  );
}

/// Sell-based fallback: trades that bring every class exactly to target.
/// Only suggested when cash-flow rebalancing leaves bands breached. This is a
/// suggestion to the user, never an order.
Map<AssetClass, double> fullRebalanceTrades({
  required Map<AssetClass, double> values,
  required Map<AssetClass, double> target,
}) {
  final total = values.values.fold(0.0, (a, b) => a + b);
  return {
    for (final c in AssetClass.values)
      c: (target[c] ?? 0) * total - (values[c] ?? 0),
  };
}
