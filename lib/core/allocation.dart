import 'dart:math' as math;

import 'asset_class.dart';
import 'mvo.dart';

const _growth = [AssetClass.equity, AssetClass.property, AssetClass.gold];

/// Max growth exposure (equity + property + gold) allowed by horizon —
/// capacity for loss, independent of stated tolerance.
double maxGrowthShare(double horizonYears) {
  if (horizonYears <= 2) return 0.10;
  if (horizonYears <= 5) return 0.40;
  if (horizonYears <= 10) return 0.70;
  return 0.90;
}

/// Maps a 0..100 risk score to MVO risk aversion (lambda): 0 -> 30,
/// 100 -> 1.5, geometric interpolation.
double riskAversionFor(double score) {
  final t = score.clamp(0, 100) / 100;
  return 30 * math.pow(1.5 / 30, t).toDouble();
}

class TargetAllocation {
  const TargetAllocation({
    required this.weights,
    required this.expectedReturn,
    required this.volatility,
    required this.riskScore,
    required this.horizonYears,
  });
  final Map<AssetClass, double> weights;
  final double expectedReturn;
  final double volatility;
  final double riskScore;
  final double horizonYears;

  double get growthShare => _growth.fold(0.0, (a, c) => a + weights[c]!);
}

/// Builds the target allocation for one goal from risk score + horizon.
/// Growth assets are capped by [maxGrowthShare]; no single class exceeds
/// [maxSingleClass] unless it is bonds/cash (the defensive classes).
TargetAllocation targetAllocation({
  required double riskScore,
  required double horizonYears,
  double maxSingleClass = 0.70,
}) {
  final classes = AssetClass.values;
  final mu = [for (final c in classes) c.expectedReturn];
  final cov = covarianceFrom([
    for (final c in classes) c.volatility,
  ], defaultCorrelations);
  final cap = maxGrowthShare(horizonYears);
  final hi = [
    for (final c in classes)
      _growth.contains(c) ? math.min(cap, maxSingleClass) : 1.0,
  ];
  if (cap <= 0.10) hi[AssetClass.property.index] = 0.0;
  final lambda = riskAversionFor(riskScore);
  var res = optimise(mu: mu, cov: cov, riskAversion: lambda, upper: hi);
  // Enforce the aggregate growth cap by tightening per-class bounds.
  for (var i = 0; i < 30; i++) {
    final growth = _growth.fold(0.0, (a, c) => a + res.weights[c.index]);
    if (growth <= cap + 1e-6) break;
    final k = cap / growth;
    for (final c in _growth) {
      hi[c.index] = math.min(hi[c.index], res.weights[c.index] * k);
    }
    res = optimise(mu: mu, cov: cov, riskAversion: lambda, upper: hi);
  }
  return TargetAllocation(
    weights: {for (final c in classes) c: res.weights[c.index]},
    expectedReturn: res.expectedReturn,
    volatility: res.volatility,
    riskScore: riskScore,
    horizonYears: horizonYears,
  );
}
