import 'package:flutter_test/flutter_test.dart';
import 'package:samridhi/core/allocation.dart';
import 'package:samridhi/core/asset_class.dart';
import 'package:samridhi/core/mvo.dart';
import 'package:samridhi/core/risk_profile.dart';

double sum(List<double> v) => v.fold(0.0, (a, b) => a + b);

void main() {
  group('projectBoxSimplex', () {
    test('sums to one and respects bounds', () {
      final w = projectBoxSimplex([0.9, 0.9, -0.5], [0, 0, 0], [0.6, 1, 1]);
      expect(sum(w), closeTo(1, 1e-9));
      expect(w[0], lessThanOrEqualTo(0.6 + 1e-12));
      expect(w.every((x) => x >= 0), isTrue);
    });
  });

  group('MVO known cases', () {
    test('two-asset global minimum variance matches closed form', () {
      const s1 = 0.2, s2 = 0.1, rho = 0.3;
      final cov = covarianceFrom(
        [s1, s2],
        [
          [1, rho],
          [rho, 1],
        ],
      );
      final r = optimise(mu: [0.05, 0.05], cov: cov, riskAversion: 10);
      const expected =
          (s2 * s2 - rho * s1 * s2) / (s1 * s1 + s2 * s2 - 2 * rho * s1 * s2);
      expect(r.weights[0], closeTo(expected, 1e-4));
    });

    test('equal vol, uncorrelated, equal return -> 50/50', () {
      final cov = covarianceFrom(
        [0.15, 0.15],
        [
          [1, 0],
          [0, 1],
        ],
      );
      final r = optimise(mu: [0.06, 0.06], cov: cov, riskAversion: 3);
      expect(r.weights[0], closeTo(0.5, 1e-5));
    });

    test('two-asset interior optimum matches closed form', () {
      const s1 = 0.18, s2 = 0.06, rho = 0.2, m1 = 0.08, m2 = 0.03, lam = 4.0;
      const c = rho * s1 * s2;
      final cov = covarianceFrom(
        [s1, s2],
        [
          [1, rho],
          [rho, 1],
        ],
      );
      final r = optimise(mu: [m1, m2], cov: cov, riskAversion: lam);
      const expected =
          ((m1 - m2) / lam + s2 * s2 - c) / (s1 * s1 + s2 * s2 - 2 * c);
      expect(r.weights[0], closeTo(expected, 1e-4));
    });

    test('upper bound binds and weights still sum to one', () {
      final cov = covarianceFrom(
        [0.2, 0.1, 0.05],
        [
          [1, 0.2, 0],
          [0.2, 1, 0],
          [0, 0, 1],
        ],
      );
      final r = optimise(
        mu: [0.1, 0.05, 0.02],
        cov: cov,
        riskAversion: 0.5,
        upper: [0.3, 1, 1],
      );
      expect(r.weights[0], closeTo(0.3, 1e-6));
      expect(sum(r.weights), closeTo(1, 1e-9));
    });

    test('infeasible bounds throw', () {
      final cov = covarianceFrom(
        [0.1, 0.1],
        [
          [1, 0],
          [0, 1],
        ],
      );
      expect(
        () => optimise(
          mu: [0.1, 0.1],
          cov: cov,
          riskAversion: 1,
          upper: [0.3, 0.3],
        ),
        throwsArgumentError,
      );
    });

    test('efficient frontier is monotone in risk and return', () {
      final mu = [for (final c in AssetClass.values) c.expectedReturn];
      final cov = covarianceFrom([
        for (final c in AssetClass.values) c.volatility,
      ], defaultCorrelations);
      final f = efficientFrontier(mu: mu, cov: cov, points: 8);
      for (var i = 1; i < f.length; i++) {
        expect(
          f[i].volatility,
          greaterThanOrEqualTo(f[i - 1].volatility - 1e-6),
        );
        expect(
          f[i].expectedReturn,
          greaterThanOrEqualTo(f[i - 1].expectedReturn - 1e-6),
        );
      }
    });
  });

  group('risk profile', () {
    test('all-cautious answers -> conservative; all-bold -> adventurous', () {
      final low = scoreRisk({for (final q in riskQuestions) q.id: 0});
      final high = scoreRisk({
        for (final q in riskQuestions)
          q.id: q.options.length == 5 ? 3 : q.options.length - 1,
      });
      expect(low.band, RiskBand.conservative);
      expect(high.band, RiskBand.adventurous);
    });

    test('empty answers throw; bad index throws', () {
      expect(() => scoreRisk({}), throwsStateError);
      expect(() => scoreRisk({'drawdown': 99}), throwsRangeError);
    });

    test('partial answers still score', () {
      expect(scoreRisk({'drawdown': 3}).score, 100);
    });
  });

  group('target allocation', () {
    test('weights sum to one for any score/horizon', () {
      for (final s in [0.0, 30.0, 60.0, 100.0]) {
        for (final h in [1.0, 4.0, 8.0, 20.0]) {
          final t = targetAllocation(riskScore: s, horizonYears: h);
          expect(sum(t.weights.values.toList()), closeTo(1, 1e-6));
          expect(t.growthShare, lessThanOrEqualTo(maxGrowthShare(h) + 1e-4));
        }
      }
    });

    test('more risk appetite -> more growth (long horizon)', () {
      final a = targetAllocation(riskScore: 10, horizonYears: 25);
      final b = targetAllocation(riskScore: 90, horizonYears: 25);
      expect(b.growthShare, greaterThan(a.growthShare));
      expect(b.volatility, greaterThan(a.volatility));
    });

    test('short horizon caps growth even for adventurous investors', () {
      final t = targetAllocation(riskScore: 100, horizonYears: 1);
      expect(t.growthShare, lessThanOrEqualTo(0.10 + 1e-4));
      expect(t.weights[AssetClass.property], closeTo(0, 1e-9));
    });

    test('no single growth class above 70%', () {
      final t = targetAllocation(riskScore: 100, horizonYears: 30);
      expect(t.weights[AssetClass.equity]!, lessThanOrEqualTo(0.70 + 1e-6));
    });
  });
}
