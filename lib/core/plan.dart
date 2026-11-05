import 'allocation.dart';
import 'asset_class.dart';

/// Minimal goal input for planning (decoupled from the DB row type).
class GoalInput {
  const GoalInput(this.name, this.targetAmount, this.horizonYears);
  final String name;
  final double targetAmount;
  final double horizonYears;
}

class GoalPlan {
  const GoalPlan(this.goal, this.allocation);
  final GoalInput goal;
  final TargetAllocation allocation;
}

class PlanResult {
  const PlanResult({required this.perGoal, required this.blended});
  final List<GoalPlan> perGoal;

  /// Goal-amount-weighted blend of per-goal targets (weights sum to 1).
  final Map<AssetClass, double> blended;
}

/// Sums holdings value per asset class.
Map<AssetClass, double> valueByClass(
  Iterable<({AssetClass assetClass, double value})> holdings,
) {
  final out = {for (final c in AssetClass.values) c: 0.0};
  for (final h in holdings) {
    out[h.assetClass] = out[h.assetClass]! + h.value;
  }
  return out;
}

/// Converts values to fractions of the total (all zero if total is zero).
Map<AssetClass, double> toWeights(Map<AssetClass, double> values) {
  final total = values.values.fold(0.0, (a, b) => a + b);
  return {
    for (final e in values.entries) e.key: total == 0 ? 0.0 : e.value / total,
  };
}

/// Discrete risk tiers 1 (most cautious) to 7 (most adventurous), the simpler
/// "just pick a number" alternative to per-goal glide paths.
const riskTierCount = 7;

/// Risk score (0-100) a tier stands for; tiers are evenly spaced.
double tierRiskScore(int tier) {
  final t = tier.clamp(1, riskTierCount);
  return 100.0 * (t - 1) / (riskTierCount - 1);
}

/// Builds per-goal targets and the blended overall target. With no goals,
/// a single default 20-year "general investing" goal is assumed.
PlanResult buildPlan({
  required double riskScore,
  required List<GoalInput> goals,
  int? tier,
}) {
  final inputs = goals.isEmpty
      ? const [GoalInput('General investing', 1, 20)]
      : goals;
  final perGoal = [
    for (final g in inputs)
      GoalPlan(
        g,
        // In tier mode every goal gets the same portfolio, whatever its
        // horizon (a long horizon here only means "no glide-path cap").
        tier == null
            ? targetAllocation(
                riskScore: riskScore,
                horizonYears: g.horizonYears,
              )
            : targetAllocation(
                riskScore: tierRiskScore(tier),
                horizonYears: 30,
              ),
      ),
  ];
  final totalAmt = inputs.fold(0.0, (a, g) => a + g.targetAmount);
  final blended = {for (final c in AssetClass.values) c: 0.0};
  for (final p in perGoal) {
    final share = totalAmt == 0
        ? 1 / perGoal.length
        : p.goal.targetAmount / totalAmt;
    for (final c in AssetClass.values) {
      blended[c] = blended[c]! + share * p.allocation.weights[c]!;
    }
  }
  return PlanResult(perGoal: perGoal, blended: blended);
}
