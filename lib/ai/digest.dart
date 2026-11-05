import 'dart:math' as math;

import '../core/asset_class.dart';
import '../core/plan.dart';
import '../core/risk_profile.dart';

/// Rounds to [sig] significant figures (e.g. 123456 -> 120000).
double roundSig(double v, [int sig = 2]) {
  if (v == 0 || v.isNaN || v.isInfinite) return 0;
  final scale = math.pow(10, sig - 1 - (math.log(v.abs()) / math.ln10).floor());
  return (v * scale).round() / scale;
}

double _to5pct(double w) => (w * 20).round() / 20;

/// The only view of the user's finances that ever leaves the device for an AI
/// agent: rounded, derived, and anonymous. No account/holding names, no ids,
/// no exact balances, no goal names (goals become "Goal 1", "Goal 2", ...).
Map<String, Object?> buildDigest({
  required RiskScore risk,
  required PlanResult plan,
  required Map<AssetClass, double> currentValues,
}) {
  final total = currentValues.values.fold(0.0, (a, b) => a + b);
  final cur = toWeights(currentValues);
  return {
    'risk_profile': risk.band.label,
    'risk_score_rounded_to_10': (risk.score / 10).round() * 10,
    'total_invested_approx': roundSig(total),
    'target_allocation_pct': {
      for (final c in AssetClass.values)
        c.label: (_to5pct(plan.blended[c]!) * 100).round(),
    },
    'current_allocation_pct': total == 0
        ? null
        : {for (final c in AssetClass.values) c.label: (cur[c]! * 100).round()},
    'goals': [
      for (var i = 0; i < plan.perGoal.length; i++)
        {
          'name': 'Goal ${i + 1}',
          'horizon_years': plan.perGoal[i].goal.horizonYears.round(),
          'target_approx': roundSig(plan.perGoal[i].goal.targetAmount),
          'growth_assets_pct':
              (_to5pct(plan.perGoal[i].allocation.growthShare) * 100).round(),
        },
    ],
    'note': 'Figures are rounded model outputs using illustrative assumptions.',
  };
}
