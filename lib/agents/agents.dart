import '../core/asset_class.dart';
import '../core/forecast.dart';
import '../core/plan.dart';
import '../core/rebalance.dart';
import '../core/risk_profile.dart';

/// What a suggestion is. None of these execute anything: the strongest thing
/// a user can do with one is tap "Accept", which records their intent.
enum SuggestionKind { info, rebalance, note }

class Suggestion {
  const Suggestion({
    required this.id,
    required this.agent,
    required this.kind,
    required this.title,
    required this.detail,
    required this.confidence,
  });

  /// Stable across runs (agent + topic) so a past decision still applies.
  final String id;
  final String agent;
  final SuggestionKind kind;
  final String title;
  final String detail;

  /// Plain-language basis/track record. Never empty: every suggestion says
  /// how much to trust it.
  final String confidence;

  bool get actionable => kind == SuggestionKind.rebalance;
}

/// Read-only inputs the agents reason over (already rounded/derived by the
/// quantitative core — agents never see names or identifiers).
class AgentContext {
  const AgentContext({
    required this.risk,
    required this.plan,
    required this.values,
    required this.wrappers,
    required this.forecasts,
    this.bands = RebalanceBands.standard,
    this.acceptedRebalances = const [],
    this.asOf,
  });
  final RiskScore risk;
  final PlanResult plan;

  /// Money per asset class.
  final Map<AssetClass, double> values;

  /// Account wrapper kinds present (isa, pension, taxable, cash...).
  final Set<String> wrappers;
  final Map<AssetClass, Forecast> forecasts;
  final RebalanceBands bands;

  /// When the user accepted past rebalance suggestions (their own log).
  final List<DateTime> acceptedRebalances;

  /// Clock for the above; null means "now".
  final DateTime? asOf;

  double get total => values.values.fold(0.0, (a, b) => a + b);
}

/// A deterministic agent: pure function of the context, no I/O, no AI.
abstract class Agent {
  String get name;
  List<Suggestion> run(AgentContext ctx);
}

class RiskProfileAgent implements Agent {
  @override
  String get name => 'Risk profile';

  @override
  List<Suggestion> run(AgentContext ctx) => [
    Suggestion(
      id: 'risk:band',
      agent: name,
      kind: SuggestionKind.info,
      title: '${ctx.risk.band.label} profile',
      detail:
          'Your questionnaire answers score ${ctx.risk.score.round()}/100. '
          'Short-horizon goals are capped at lower growth exposure '
          'regardless of this score.',
      confidence:
          'Rule-based from your answers; as reliable as those answers are.',
    ),
  ];
}

class PortfolioAgent implements Agent {
  @override
  String get name => 'Portfolio construction';

  @override
  List<Suggestion> run(AgentContext ctx) {
    final mix = [
      for (final c in AssetClass.values)
        if (ctx.plan.blended[c]! >= 0.005)
          '${c.label} ${(ctx.plan.blended[c]! * 100).round()}%',
    ].join(', ');
    return [
      Suggestion(
        id: 'portfolio:target',
        agent: name,
        kind: SuggestionKind.info,
        title: 'Target allocation',
        detail: mix,
        confidence:
            'Mean-variance optimiser on illustrative long-run assumptions, '
            'not market data. Treat as a starting point.',
      ),
    ];
  }
}

class ForecastAgent implements Agent {
  @override
  String get name => 'Forecast';

  @override
  List<Suggestion> run(AgentContext ctx) {
    final eq = ctx.forecasts[AssetClass.equity];
    if (eq == null) return const [];
    final t = eq.track;
    return [
      Suggestion(
        id: 'forecast:equity',
        agent: name,
        kind: SuggestionKind.info,
        title: 'Equity outlook (statistical)',
        detail:
            'Smoothed annual return ${(eq.mean.first * 100).toStringAsFixed(1)}% '
            '(${(eq.confidence * 100).round()}% band '
            '${(eq.lower.first * 100).toStringAsFixed(1)}% to '
            '${(eq.upper.first * 100).toStringAsFixed(1)}%). '
            'It does not change your target.',
        confidence:
            'Band held in ${t.hits} of ${t.trials} past years on sample data. '
            'A simple model, not a prediction.',
      ),
    ];
  }
}

class RebalancingAgent implements Agent {
  @override
  String get name => 'Rebalancing';

  @override
  List<Suggestion> run(AgentContext ctx) {
    if (ctx.total <= 0) return const [];
    final cur = toWeights(ctx.values);
    if (!breachesBands(ctx.plan.blended, cur, ctx.bands)) {
      return [
        Suggestion(
          id: 'rebalance:ok',
          agent: name,
          kind: SuggestionKind.info,
          title: 'Within tolerance bands',
          detail:
              'No asset class is more than '
              '${(ctx.bands.over * 100).toStringAsFixed(1)}% from target.',
          confidence: 'Exact arithmetic on your entered holdings.',
        ),
      ];
    }
    final trades = fullRebalanceTrades(
      values: ctx.values,
      target: ctx.plan.blended,
    );
    final lines = [
      for (final e in trades.entries)
        if (e.value.abs() >= 1)
          '${e.value > 0 ? 'Buy' : 'Sell'} ${e.key.label} '
              '${e.value.abs().round()}',
    ];
    return [
      Suggestion(
        id: 'rebalance:trades',
        agent: name,
        kind: SuggestionKind.rebalance,
        title: 'Rebalance to target',
        detail:
            '${lines.join('; ')}. Prefer directing new contributions to '
            'underweight classes first (Insights tab).',
        confidence:
            'Exact arithmetic on your entered holdings; a threshold rule '
            '(Vanguard-style 3% band), not a market view.',
      ),
    ];
  }
}

/// Wrapper/tax-location sanity: keeps suggestions legal and tax-aware.
class ComplianceAgent implements Agent {
  @override
  String get name => 'Wrapper rules';

  @override
  List<Suggestion> run(AgentContext ctx) {
    final sheltered = ctx.wrappers.intersection({'isa', 'pension'});
    final taxable = ctx.wrappers.contains('taxable');
    if (sheltered.isEmpty || !taxable) return const [];
    return [
      Suggestion(
        id: 'wrapper:location',
        agent: name,
        kind: SuggestionKind.note,
        title: 'Rebalance inside tax wrappers first',
        detail:
            'You hold both sheltered (${sheltered.join(', ')}) and taxable '
            'accounts. Selling inside an ISA/pension triggers no capital '
            'gains tax, so do any sells there before touching taxable '
            'accounts. Tax-loss harvesting is only relevant in taxable '
            'accounts.',
        confidence:
            'General rule of thumb; rules vary by country and change. '
            'Check your own situation.',
      ),
    ];
  }
}

/// Behavioural-gap nudge from the user's own history. Cites Betterment's
/// published figure as general education only: it describes one provider's
/// clients, not a forecast for this user.
class BehaviorAgent implements Agent {
  @override
  String get name => 'Behaviour';

  /// Accepted rebalances in the trailing year before the nudge appears.
  static const threshold = 3;

  @override
  List<Suggestion> run(AgentContext ctx) {
    final now = ctx.asOf ?? DateTime.now();
    final cutoff = now.subtract(const Duration(days: 365));
    final n = ctx.acceptedRebalances.where((d) => d.isAfter(cutoff)).length;
    if (n < threshold) return const [];
    return [
      Suggestion(
        id: 'behavior:changes',
        agent: name,
        kind: SuggestionKind.note,
        title: 'You have changed course $n times this year',
        detail:
            'You accepted $n rebalance suggestions in the last 12 months. '
            'Betterment reported that its clients who made allocation '
            'changes trailed a simple hold of their own average allocation '
            'by about 22 basis points on average, and the gap grew with the '
            'number of changes. Rebalancing on a schedule or only when a '
            'band is breached avoids reacting to headlines.',
        confidence:
            'Count is from your own local log. The 22 bp figure is one '
            "provider's published average over its clients, an educational "
            'reference and not a prediction for you.',
      ),
    ];
  }
}

List<Agent> defaultAgents() => [
  RiskProfileAgent(),
  PortfolioAgent(),
  ForecastAgent(),
  RebalancingAgent(),
  ComplianceAgent(),
  BehaviorAgent(),
];
