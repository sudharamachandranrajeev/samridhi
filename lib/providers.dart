import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'agents/agents.dart';
import 'core/asset_class.dart';
import 'core/forecast.dart';
import 'core/sample_data.dart';
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

/// Chosen discrete risk tier (1-7), or null for the default per-goal mode.
final tierProvider = StreamProvider<int?>(
  (ref) => ref
      .watch(databaseProvider)
      .watchSetting('plan.tier')
      .map((v) => int.tryParse(v ?? '')),
);

final planProvider = Provider<PlanResult?>((ref) {
  final risk = ref.watch(riskScoreProvider);
  if (risk == null) return null;
  final goals = ref.watch(goalsProvider).asData?.value ?? const [];
  return buildPlan(
    riskScore: risk.score,
    goals: [
      for (final g in goals) GoalInput(g.name, g.targetAmount, g.horizonYears),
    ],
    tier: ref.watch(tierProvider).asData?.value,
  );
});

// ---- sample data + forecasts (synthetic; see sample_data.dart) ----
final sampleDataProvider = Provider((ref) => sampleMonthlyReturns());

final forecastsProvider = Provider<Map<AssetClass, Forecast>>((ref) {
  final data = ref.watch(sampleDataProvider);
  return {
    for (final c in AssetClass.values)
      if (c != AssetClass.cash) c: forecastSes(annualise(data[c]!)),
  };
});

// ---- agents / AI switches (both off by default) ----
final agentsEnabledProvider = StreamProvider<bool>(
  (ref) => ref
      .watch(databaseProvider)
      .watchSetting('agents.enabled')
      .map((v) => v == '1'),
);
final aiEnabledProvider = StreamProvider<bool>(
  (ref) => ref
      .watch(databaseProvider)
      .watchSetting('ai.enabled')
      .map((v) => v == '1'),
);
final decisionsProvider = StreamProvider<Map<String, String>>(
  (ref) => ref.watch(databaseProvider).watchDecisions(),
);

final acceptedRebalancesProvider = StreamProvider<List<DateTime>>(
  (ref) => ref.watch(databaseProvider).watchAcceptedAt('Rebalancing'),
);

/// Everything the agents may see; null until the questionnaire is done.
final agentContextProvider = Provider<AgentContext?>((ref) {
  final risk = ref.watch(riskScoreProvider);
  final plan = ref.watch(planProvider);
  if (risk == null || plan == null) return null;
  final accounts = ref.watch(accountsProvider).asData?.value ?? const [];
  return AgentContext(
    risk: risk,
    plan: plan,
    values: ref.watch(currentMixProvider),
    wrappers: {for (final a in accounts) a.wrapper},
    forecasts: ref.watch(forecastsProvider),
    acceptedRebalances:
        ref.watch(acceptedRebalancesProvider).asData?.value ?? const [],
  );
});
