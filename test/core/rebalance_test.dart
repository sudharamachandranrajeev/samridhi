import 'package:flutter_test/flutter_test.dart';
import 'package:samridhi/core/asset_class.dart';
import 'package:samridhi/core/backtest.dart';
import 'package:samridhi/core/forecast.dart';
import 'package:samridhi/core/rebalance.dart';
import 'package:samridhi/core/sample_data.dart';

Map<AssetClass, double> mix(double eq, double bonds) => {
  AssetClass.equity: eq,
  AssetClass.bonds: bonds,
  AssetClass.property: 0,
  AssetClass.gold: 0,
  AssetClass.cash: 0,
};

double sum(Iterable<double> v) => v.fold(0.0, (a, b) => a + b);

void main() {
  final target = mix(0.6, 0.4);

  group('bands', () {
    test('3% band: 62.9/37.1 inside, 63.1/36.9 outside', () {
      expect(breachesBands(target, mix(0.629, 0.371)), isFalse);
      expect(breachesBands(target, mix(0.631, 0.369)), isTrue);
    });
    test('200/175 glide-path band is asymmetric', () {
      const b = RebalanceBands.glidePath;
      // equity +1.9% over (inside 2.0), bonds -1.9% under (outside 1.75)
      expect(breachesBands(target, mix(0.619, 0.381), b), isTrue);
      // equity +1.9% only matters if it is the max drift; make bonds fine
      expect(
        breachesBands(
          {AssetClass.equity: 0.6, AssetClass.cash: 0.4},
          {AssetClass.equity: 0.619, AssetClass.cash: 0.4},
          b,
        ),
        isFalse,
      );
    });
  });

  group('cash-flow rebalancing', () {
    test('contribution buys underweight first, no sells', () {
      // 100k: equity 70k (over), bonds 30k (under). Contribute 20k.
      final values = {...mix(70000, 30000)};
      final r = cashFlowRebalance(
        values: values,
        target: target,
        cashFlow: 20000,
      );
      expect(r.flows[AssetClass.equity], closeTo(2000, 1e-6));
      expect(r.flows[AssetClass.bonds], closeTo(18000, 1e-6));
      expect(sum(r.flows.values), closeTo(20000, 1e-6));
      expect(r.flows.values.every((f) => f >= 0), isTrue);
      // after: 72k/48k of 120k = exactly on target
      expect(r.stillBreached, isFalse);
    });

    test('small contribution is split in proportion to shortfall', () {
      final values = {...mix(70000, 30000)};
      final r = cashFlowRebalance(
        values: values,
        target: target,
        cashFlow: 5000,
      );
      expect(r.flows[AssetClass.bonds], closeTo(5000, 1e-6));
      expect(r.stillBreached, isTrue); // 70/105 = 66.7% equity
    });

    test('surplus beyond all shortfalls is spread by target weight', () {
      final values = {...mix(60000, 40000)}; // exactly on target
      final r = cashFlowRebalance(
        values: values,
        target: target,
        cashFlow: 10000,
      );
      expect(r.flows[AssetClass.equity], closeTo(6000, 1e-6));
      expect(r.flows[AssetClass.bonds], closeTo(4000, 1e-6));
    });

    test('withdrawal is drawn from the overweight class first', () {
      final values = {...mix(70000, 30000)};
      final r = cashFlowRebalance(
        values: values,
        target: target,
        cashFlow: -10000,
      );
      expect(r.flows[AssetClass.equity], closeTo(-10000, 1e-6));
      expect(r.flows[AssetClass.bonds], closeTo(0, 1e-6));
      expect(r.flows.values.every((f) => f <= 0), isTrue);
    });

    test('withdrawal beyond all excess falls back pro rata', () {
      final values = {...mix(60000, 40000)}; // on target, no excess
      final r = cashFlowRebalance(
        values: values,
        target: target,
        cashFlow: -10000,
      );
      expect(r.flows[AssetClass.equity], closeTo(-6000, 1e-6));
      expect(r.flows[AssetClass.bonds], closeTo(-4000, 1e-6));
    });

    test('withdrawal is capped at the portfolio value', () {
      final r = cashFlowRebalance(
        values: mix(500, 500),
        target: target,
        cashFlow: -5000,
      );
      expect(sum(r.flows.values), closeTo(-1000, 1e-6));
    });

    test('full rebalance trades net to zero and land on target', () {
      final values = mix(70000, 30000);
      final t = fullRebalanceTrades(values: values, target: target);
      expect(sum(t.values), closeTo(0, 1e-6));
      expect(t[AssetClass.equity], closeTo(-10000, 1e-6));
      expect(t[AssetClass.bonds], closeTo(10000, 1e-6));
    });
  });

  group('forecast', () {
    test('constant series forecasts the constant with a tight band', () {
      final f = forecastSes(List.filled(20, 0.05));
      expect(f.mean.single, closeTo(0.05, 1e-9));
      expect(f.upper.single - f.lower.single, closeTo(0, 1e-9));
    });

    test('band widens with horizon and brackets the mean', () {
      final y = [for (var i = 0; i < 30; i++) 0.05 + (i.isEven ? 0.04 : -0.04)];
      final f = forecastSes(y, horizon: 5);
      expect(f.mean.length, 5);
      for (var i = 0; i < 5; i++) {
        expect(f.lower[i], lessThan(f.mean[i]));
        expect(f.upper[i], greaterThan(f.mean[i]));
      }
      expect(
        f.upper.last - f.lower.last,
        greaterThan(f.upper.first - f.lower.first),
      );
      expect(f.track.trials, 22);
    });

    test('rejects short history and unsupported confidence', () {
      expect(() => forecastSes([1, 2, 3]), throwsArgumentError);
      expect(
        () => forecastSes(List.filled(20, 1.0), confidence: 0.5),
        throwsArgumentError,
      );
    });

    test('moving average of last window', () {
      expect(movingAverage([1, 2, 3, 4], 2), 3.5);
    });

    test('track record hit rate is near nominal on sample data', () {
      final annual = annualise(sampleMonthlyReturns()[AssetClass.equity]!);
      final f = forecastSes(annual);
      expect(f.track.trials, annual.length - 8);
      expect(f.track.hitRate, inInclusiveRange(0.5, 1.0));
    });
  });

  group('sample data + backtest', () {
    final data = sampleMonthlyReturns();
    test('sample data is deterministic and 240 months', () {
      expect(data[AssetClass.equity]!.length, sampleMonths);
      expect(
        sampleMonthlyReturns()[AssetClass.equity],
        data[AssetClass.equity],
      );
    });

    test('never-rebalance drifts; threshold keeps drift near the band', () {
      final none = backtest(
        monthly: data,
        target: target,
        rule: RebalanceRule.none,
      );
      final thr = backtest(
        monthly: data,
        target: target,
        rule: RebalanceRule.threshold,
      );
      final ann = backtest(
        monthly: data,
        target: target,
        rule: RebalanceRule.annual,
      );
      expect(none.rebalances, 0);
      expect(ann.rebalances, 20);
      expect(thr.rebalances, greaterThan(0));
      expect(thr.rebalances, lessThan(240));
      for (final r in [none, thr, ann]) {
        expect(r.values.length, 241);
        expect(r.maxDrawdown, inInclusiveRange(0, 1));
        expect(r.annualVol, greaterThan(0));
      }
    });

    test('single-asset-class zero-return portfolio is flat', () {
      final flat = {for (final c in AssetClass.values) c: List.filled(24, 0.0)};
      final r = backtest(
        monthly: flat,
        target: target,
        rule: RebalanceRule.annual,
        initial: 1000,
      );
      expect(r.finalValue, closeTo(1000, 1e-9));
      expect(r.cagr, closeTo(0, 1e-9));
      expect(r.maxDrawdown, 0);
    });
  });
}
