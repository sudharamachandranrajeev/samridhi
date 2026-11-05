import 'dart:math' as math;

/// Education-only direct-indexing simulator. It runs on a small **synthetic**
/// universe (seeded random, not any real index or market history) and shows
/// how tax-loss harvesting trades a little tracking difference for realised
/// losses. Nothing here places or suggests a real trade.
const indexingDataLabel =
    'Synthetic constituents, for illustration only, not real market history.';

const _sectors = 4;

class SyntheticUniverse {
  const SyntheticUniverse(this.monthly);

  /// monthly[stock][month] simple returns. Stock i is in sector i % 4.
  final List<List<double>> monthly;
  int get stocks => monthly.length;
  int get months => monthly.first.length;
}

SyntheticUniverse syntheticUniverse({
  int seed = 11,
  int stocks = 40,
  int months = 60,
}) {
  final rnd = math.Random(seed);
  double normal() {
    final u1 = 1 - rnd.nextDouble(), u2 = rnd.nextDouble();
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }

  final out = List.generate(stocks, (_) => <double>[]);
  for (var m = 0; m < months; m++) {
    final market = 0.007 + 0.04 * normal();
    final sector = List.generate(_sectors, (_) => 0.025 * normal());
    for (var i = 0; i < stocks; i++) {
      out[i].add(market + sector[i % _sectors] + 0.06 * normal());
    }
  }
  return SyntheticUniverse(out);
}

class DirectIndexResult {
  const DirectIndexResult({
    required this.indexValues,
    required this.portfolioValues,
    required this.harvestedLosses,
    required this.harvests,
    required this.taxOffsetValue,
    required this.trackingDifference,
  });

  /// Start value then month-end values, for the plain index and the
  /// harvesting portfolio.
  final List<double> indexValues;
  final List<double> portfolioValues;

  /// Total losses realised by selling a position below cost.
  final double harvestedLosses;
  final int harvests;

  /// harvestedLosses × tax rate: what the losses could offset *if* the
  /// investor has taxable gains to use them against. It is mostly a deferral,
  /// since each swap lowers the new position's cost basis.
  final double taxOffsetValue;

  /// Annualised standard deviation of monthly portfolio-minus-index return.
  final double trackingDifference;
}

/// Holds every stock in equal weight (the "index"), and in parallel a copy
/// that sells any position down [harvestThreshold] or more from its cost and
/// moves the money into a same-sector peer. Wash-sale rules, costs and
/// tax-lot detail are not modelled.
DirectIndexResult simulateDirectIndexing(
  SyntheticUniverse u, {
  double initial = 100000,
  double harvestThreshold = 0.10,
  double taxRate = 0.20,
}) {
  final n = u.stocks;
  final index = List.filled(n, initial / n);
  final value = List.filled(n, initial / n);
  final basis = List.filled(n, initial / n);
  final idx = <double>[initial], port = <double>[initial];
  final diffs = <double>[];
  var losses = 0.0;
  var harvests = 0;
  for (var m = 0; m < u.months; m++) {
    for (var i = 0; i < n; i++) {
      index[i] *= 1 + u.monthly[i][m];
      value[i] *= 1 + u.monthly[i][m];
    }
    for (var i = 0; i < n; i++) {
      if (value[i] > 0 && value[i] <= basis[i] * (1 - harvestThreshold)) {
        losses += basis[i] - value[i];
        harvests++;
        final peer = (i + _sectors) % n;
        value[peer] += value[i];
        basis[peer] += value[i];
        value[i] = 0;
        basis[i] = 0;
      }
    }
    final a = index.fold(0.0, (s, v) => s + v);
    final b = value.fold(0.0, (s, v) => s + v);
    diffs.add((b / port.last) - (a / idx.last));
    idx.add(a);
    port.add(b);
  }
  final mean = diffs.fold(0.0, (s, d) => s + d) / diffs.length;
  final variance =
      diffs.fold(0.0, (s, d) => s + (d - mean) * (d - mean)) /
      (diffs.length - 1);
  return DirectIndexResult(
    indexValues: idx,
    portfolioValues: port,
    harvestedLosses: losses,
    harvests: harvests,
    taxOffsetValue: losses * taxRate,
    trackingDifference: math.sqrt(variance) * math.sqrt(12),
  );
}
