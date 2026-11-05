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
}
