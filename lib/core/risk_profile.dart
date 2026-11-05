/// Risk questionnaire + scoring. Pure Dart.
class RiskOption {
  const RiskOption(this.label, this.points);
  final String label;

  /// 0 (very cautious) .. 100 (very adventurous).
  final int points;
}

class RiskQuestion {
  const RiskQuestion(this.id, this.prompt, this.options, {this.weight = 1});
  final String id;
  final String prompt;
  final List<RiskOption> options;
  final double weight;
}

const List<RiskQuestion> riskQuestions = [
  RiskQuestion('drawdown', 'Your portfolio falls 20% in three months. You…', [
    RiskOption('Sell everything to stop the losses', 0),
    RiskOption('Sell some to reduce worry', 25),
    RiskOption('Do nothing and wait', 60),
    RiskOption('Buy more while prices are low', 100),
  ], weight: 2),
  RiskQuestion('past_behaviour', 'In a past market fall, you actually…', [
    RiskOption('Sold and stayed out', 0),
    RiskOption('Sold some', 30),
    RiskOption('Held on', 70),
    RiskOption('Bought more', 100),
    RiskOption('I have not been through one', 40),
  ], weight: 2),
  RiskQuestion('trade_off', 'Which range of one-year outcomes do you prefer?', [
    RiskOption('+2% to +4%', 5),
    RiskOption('-5% to +10%', 35),
    RiskOption('-15% to +25%', 70),
    RiskOption('-30% to +45%', 100),
  ]),
  RiskQuestion('income', 'How stable is your income?', [
    RiskOption('Irregular / uncertain', 10),
    RiskOption('Somewhat stable', 45),
    RiskOption('Very stable', 80),
    RiskOption('Stable, with a large safety net', 100),
  ]),
  RiskQuestion('experience', 'Your investing experience?', [
    RiskOption('None', 10),
    RiskOption('A little', 40),
    RiskOption('Some years', 70),
    RiskOption('Extensive', 100),
  ]),
  RiskQuestion('reliance', 'How much of your wealth is this portfolio?', [
    RiskOption('Nearly all of it', 10),
    RiskOption('More than half', 40),
    RiskOption('A minor part', 75),
    RiskOption('A small satellite part', 100),
  ]),
];

enum RiskBand {
  conservative('Conservative'),
  cautious('Cautious'),
  balanced('Balanced'),
  growth('Growth'),
  adventurous('Adventurous');

  const RiskBand(this.label);
  final String label;
}

class RiskScore {
  const RiskScore(this.score, this.band);
  final double score; // 0..100
  final RiskBand band;
}

/// [answers] maps question id -> chosen option index. Unanswered questions
/// are ignored; throws [StateError] if nothing is answered.
RiskScore scoreRisk(Map<String, int> answers) {
  var total = 0.0, weights = 0.0;
  for (final q in riskQuestions) {
    final a = answers[q.id];
    if (a == null) continue;
    if (a < 0 || a >= q.options.length) {
      throw RangeError('Invalid option $a for ${q.id}');
    }
    total += q.options[a].points * q.weight;
    weights += q.weight;
  }
  if (weights == 0) throw StateError('No answers');
  final s = total / weights;
  return RiskScore(s, bandFor(s));
}

RiskBand bandFor(double s) {
  if (s < 20) return RiskBand.conservative;
  if (s < 40) return RiskBand.cautious;
  if (s < 60) return RiskBand.balanced;
  if (s < 80) return RiskBand.growth;
  return RiskBand.adventurous;
}
