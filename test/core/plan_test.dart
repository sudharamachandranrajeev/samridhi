import 'package:flutter_test/flutter_test.dart';
import 'package:samridhi/core/asset_class.dart';
import 'package:samridhi/core/plan.dart';

void main() {
  test('valueByClass/toWeights aggregate and normalise', () {
    final v = valueByClass([
      (assetClass: AssetClass.equity, value: 300.0),
      (assetClass: AssetClass.equity, value: 100.0),
      (assetClass: AssetClass.bonds, value: 600.0),
    ]);
    final w = toWeights(v);
    expect(w[AssetClass.equity], closeTo(0.4, 1e-12));
    expect(w[AssetClass.bonds], closeTo(0.6, 1e-12));
    expect(toWeights(valueByClass([]))[AssetClass.cash], 0);
  });

  test('blended plan sums to one and weights goals by amount', () {
    final p = buildPlan(
      riskScore: 70,
      goals: const [GoalInput('Far', 900, 25), GoalInput('Near', 100, 1)],
    );
    expect(p.blended.values.fold(0.0, (a, b) => a + b), closeTo(1, 1e-6));
    expect(p.perGoal.length, 2);
    // Dominated by the long-horizon goal => meaningful equity.
    expect(p.blended[AssetClass.equity]!, greaterThan(0.3));
  });

  test('no goals falls back to a default long-horizon goal', () {
    final p = buildPlan(riskScore: 50, goals: const []);
    expect(p.perGoal.single.goal.horizonYears, 20);
  });

  group('risk tiers', () {
    test('tier scores are evenly spaced and clamped', () {
      expect(tierRiskScore(1), 0);
      expect(tierRiskScore(7), 100);
      expect(tierRiskScore(4), 50);
      expect(tierRiskScore(0), 0);
      expect(tierRiskScore(99), 100);
    });

    test(
      'tier mode gives every goal the same portfolio; higher = more equity',
      () {
        const goals = [GoalInput('a', 100, 2), GoalInput('b', 100, 30)];
        final p = buildPlan(riskScore: 10, goals: goals, tier: 6);
        expect(
          p.perGoal[0].allocation.weights,
          p.perGoal[1].allocation.weights,
        );
        final lo = buildPlan(riskScore: 10, goals: goals, tier: 1);
        final hi = buildPlan(riskScore: 10, goals: goals, tier: 7);
        expect(
          hi.blended[AssetClass.equity]!,
          greaterThan(lo.blended[AssetClass.equity]!),
        );
        final sum = p.blended.values.fold(0.0, (a, b) => a + b);
        expect(sum, closeTo(1, 1e-9));
      },
    );
  });
}
