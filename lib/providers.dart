import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/asset_class.dart';
import 'core/plan.dart';
import 'core/risk_profile.dart';
import 'data/database.dart';

/// Overridden in main() (and in tests) with a concrete database.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final accountsProvider = StreamProvider<List<Account>>(
  (ref) => ref.watch(databaseProvider).watchAccounts(),
);
final holdingsProvider = StreamProvider<List<Holding>>(
  (ref) => ref.watch(databaseProvider).watchHoldings(),
);
final goalsProvider = StreamProvider<List<Goal>>(
  (ref) => ref.watch(databaseProvider).watchGoals(),
);
final riskAnswersProvider = StreamProvider<Map<String, int>>(
  (ref) => ref.watch(databaseProvider).watchRiskAnswers(),
);

AssetClass assetClassFromName(String name) => AssetClass.values.firstWhere(
  (c) => c.name == name,
  orElse: () => AssetClass.cash,
);

/// Risk score derived from saved answers, or null if the questionnaire has
/// not been completed.
final riskScoreProvider = Provider<RiskScore?>((ref) {
  final answers = ref.watch(riskAnswersProvider).asData?.value;
  if (answers == null || answers.length < riskQuestions.length) return null;
  return scoreRisk(answers);
});

final currentMixProvider = Provider<Map<AssetClass, double>>((ref) {
  final hs = ref.watch(holdingsProvider).asData?.value ?? const [];
  return valueByClass([
    for (final h in hs)
      (assetClass: assetClassFromName(h.assetClass), value: h.value),
  ]);
});

final planProvider = Provider<PlanResult?>((ref) {
  final risk = ref.watch(riskScoreProvider);
  if (risk == null) return null;
  final goals = ref.watch(goalsProvider).asData?.value ?? const [];
  return buildPlan(
    riskScore: risk.score,
    goals: [
      for (final g in goals) GoalInput(g.name, g.targetAmount, g.horizonYears),
    ],
  );
});
