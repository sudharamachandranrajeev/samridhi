import 'dart:math' as math;

import 'asset_class.dart';

/// Deterministic **synthetic** monthly returns (20 years) so the backtest and
/// forecast views work offline. Not market data. Generated from the generic
/// capital-market assumptions in [AssetClass] with one common factor and a
/// built-in equity drawdown so rebalancing behaviour is visible. Replace with
/// real history only through an explicit, user-approved data feed.
const sampleDataLabel =
    'Synthetic sample data (seeded random, not real market history).';

const sampleMonths = 240;

Map<AssetClass, List<double>> sampleMonthlyReturns({int seed = 7}) {
  final rnd = math.Random(seed);
  double normal() {
    // Box-Muller.
    final u1 = 1 - rnd.nextDouble(), u2 = rnd.nextDouble();
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }

  // Loading of each class on the common "market" factor.
  const load = {
    AssetClass.equity: 0.9,
    AssetClass.bonds: 0.1,
    AssetClass.property: 0.7,
    AssetClass.gold: 0.05,
    AssetClass.cash: 0.0,
  };
  final out = {for (final c in AssetClass.values) c: <double>[]};
  for (var m = 0; m < sampleMonths; m++) {
    final market = normal();
    // A 14-month bear market starting at month 100.
    final bear = m >= 100 && m < 114;
    for (final c in AssetClass.values) {
      final l = load[c]!;
      final z = l * market + math.sqrt(1 - l * l) * normal();
      var shock = 0.0;
      if (bear) {
        if (c == AssetClass.equity || c == AssetClass.property) shock = -0.03;
        if (c == AssetClass.bonds) shock = 0.005;
      }
      out[c]!.add(
        c.expectedReturn / 12 + c.volatility / math.sqrt(12) * z + shock,
      );
    }
  }
  return out;
}

/// Compounds monthly returns into calendar-year returns.
List<double> annualise(List<double> monthly) => [
  for (var i = 0; i + 12 <= monthly.length; i += 12)
    monthly.sublist(i, i + 12).fold(1.0, (a, r) => a * (1 + r)) - 1,
];
