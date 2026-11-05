import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:samridhi/agents/agents.dart';
import 'package:samridhi/agents/orchestrator.dart';
import 'package:samridhi/ai/ai_store.dart';
import 'package:samridhi/ai/digest.dart';
import 'package:samridhi/ai/llm_client.dart';
import 'package:samridhi/core/asset_class.dart';
import 'package:samridhi/core/forecast.dart';
import 'package:samridhi/core/plan.dart';
import 'package:samridhi/core/risk_profile.dart';
import 'package:samridhi/core/sample_data.dart';
import 'package:samridhi/data/database.dart';

Map<AssetClass, double> money(double eq, double bonds) => {
  AssetClass.equity: eq,
  AssetClass.bonds: bonds,
  AssetClass.property: 0,
  AssetClass.gold: 0,
  AssetClass.cash: 0,
};

AgentContext ctx({
  Map<AssetClass, double>? values,
  Set<String> wrappers = const {},
}) {
  final risk = scoreRisk({for (final q in riskQuestions) q.id: 2});
  final plan = buildPlan(
    riskScore: risk.score,
    goals: const [GoalInput('Secret house fund', 123456, 12)],
  );
  final data = sampleMonthlyReturns();
  return AgentContext(
    risk: risk,
    plan: plan,
    values: values ?? money(60000, 40000),
    wrappers: wrappers,
    forecasts: {
      AssetClass.equity: forecastSes(annualise(data[AssetClass.equity]!)),
    },
  );
}

AiConfig local() => const AiConfig(
  kind: AiKind.local,
  endpoint: 'http://localhost:11434/v1',
  model: 'llama3',
);

void main() {
  group('digest privacy', () {
    test('rounded, anonymous, no names or exact balances', () {
      final c = ctx(values: money(123456, 78901));
      final text = jsonEncode(
        buildDigest(risk: c.risk, plan: c.plan, currentValues: c.values),
      );
      expect(text, isNot(contains('Secret')));
      expect(text, isNot(contains('house')));
      expect(text, isNot(contains('123456')));
      expect(text, isNot(contains('78901')));
      expect(text, contains('Goal 1'));
      expect(text, contains('"total_invested_approx":200000')); // 2 s.f.
    });

    test('roundSig', () {
      expect(roundSig(123456), 120000);
      expect(roundSig(0.0), 0);
      expect(roundSig(987), 990);
    });
  });

  group('LlmClient', () {
    test('local config accepts localhost http, rejects public http', () {
      expect(local().validate(), isNull);
      expect(
        const AiConfig(
          kind: AiKind.local,
          endpoint: 'http://example.com/v1',
          model: 'm',
        ).validate(),
        isNotNull,
      );
    });

    test('cloud config needs https and a key', () {
      const base = 'https://api.anthropic.com';
      expect(
        const AiConfig(
          kind: AiKind.anthropic,
          endpoint: base,
          model: 'm',
        ).validate(),
        contains('API key'),
      );
      expect(
        const AiConfig(
          kind: AiKind.anthropic,
          endpoint: 'http://api.anthropic.com',
          model: 'm',
          apiKey: 'k',
        ).validate(),
        contains('https'),
      );
      expect(
        const AiConfig(
          kind: AiKind.anthropic,
          endpoint: base,
          model: 'm',
          apiKey: 'k',
        ).validate(),
        isNull,
      );
    });

    test('OpenAI-compatible request and reply', () async {
      late http.Request seen;
      final client = LlmClient(
        local(),
        client: MockClient((req) async {
          seen = req;
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': ' Hello. '},
                },
              ],
            }),
            200,
          );
        }),
      );
      expect(await client.complete(system: 's', user: 'u'), 'Hello.');
      expect(seen.url.toString(), 'http://localhost:11434/v1/chat/completions');
      expect(seen.headers.containsKey('authorization'), isFalse);
      final body = jsonDecode(seen.body) as Map;
      expect((body['messages'] as List).first['role'], 'system');
    });

    test('Anthropic request carries key header, never in the body', () async {
      late http.Request seen;
      final client = LlmClient(
        const AiConfig(
          kind: AiKind.anthropic,
          endpoint: 'https://api.anthropic.com/',
          model: 'm',
          apiKey: 'sk-test-123',
        ),
        client: MockClient((req) async {
          seen = req;
          return http.Response(
            jsonEncode({
              'content': [
                {'type': 'text', 'text': 'Hi'},
              ],
            }),
            200,
          );
        }),
      );
      expect(await client.complete(system: 's', user: 'u'), 'Hi');
      expect(seen.url.toString(), 'https://api.anthropic.com/v1/messages');
      expect(seen.headers['x-api-key'], 'sk-test-123');
      expect(seen.body, isNot(contains('sk-test-123')));
    });

    test('errors never echo the response body', () async {
      final client = LlmClient(
        local(),
        client: MockClient(
          (_) async => http.Response('echo of your prompt: SECRET', 500),
        ),
      );
      await expectLater(
        client.complete(system: 's', user: 'u'),
        throwsA(
          isA<LlmException>().having(
            (e) => e.message,
            'message',
            allOf(contains('500'), isNot(contains('SECRET'))),
          ),
        ),
      );
    });

    test('garbled reply is a clean error', () async {
      final client = LlmClient(
        local(),
        client: MockClient((_) async => http.Response('{"nope":1}', 200)),
      );
      await expectLater(
        client.complete(system: 's', user: 'u'),
        throwsA(isA<LlmException>()),
      );
    });
  });

  group('agents', () {
    test('every suggestion states its confidence/basis', () async {
      final run = await Orchestrator().run(ctx());
      expect(run.suggestions, isNotEmpty);
      for (final s in run.suggestions) {
        expect(s.confidence.trim(), isNotEmpty, reason: s.id);
      }
      expect(run.errors, isEmpty);
      expect(run.narrative, isNull);
    });

    test('rebalancing: on-target is info, drifted is actionable', () {
      final c = ctx();
      final target = c.plan.blended;
      final onTarget = {
        for (final k in AssetClass.values) k: target[k]! * 100000,
      };
      final ok = RebalancingAgent().run(
        AgentContext(
          risk: c.risk,
          plan: c.plan,
          values: onTarget,
          wrappers: const {},
          forecasts: const {},
        ),
      );
      expect(ok.single.actionable, isFalse);

      final drifted = RebalancingAgent().run(
        AgentContext(
          risk: c.risk,
          plan: c.plan,
          values: money(100000, 0),
          wrappers: const {},
          forecasts: const {},
        ),
      );
      expect(drifted.single.actionable, isTrue);
      expect(drifted.single.detail, contains('Sell'));
    });

    test('no holdings -> no rebalancing suggestion', () {
      expect(RebalancingAgent().run(ctx(values: money(0, 0))), isEmpty);
    });

    test('compliance note only with both sheltered and taxable accounts', () {
      expect(ComplianceAgent().run(ctx(wrappers: {'taxable'})), isEmpty);
      expect(ComplianceAgent().run(ctx(wrappers: {'isa'})), isEmpty);
      expect(
        ComplianceAgent().run(ctx(wrappers: {'isa', 'taxable'})).single.kind,
        SuggestionKind.note,
      );
    });
  });

  group('orchestrator', () {
    test('a failing agent does not hide the others', () async {
      final run = await Orchestrator(agents: [_Boom(), RiskProfileAgent()])
          .run(ctx());
      expect(run.suggestions.single.id, 'risk:band');
      expect(run.errors.single, contains('Boom'));
    });

    test('narrator gets only the anonymised digest', () async {
      late String sent;
      final narrator = Narrator(
        LlmClient(
          local(),
          client: MockClient((req) async {
            sent = req.body;
            return http.Response(
              jsonEncode({
                'choices': [
                  {
                    'message': {'content': 'Plain English plan.'},
                  },
                ],
              }),
              200,
            );
          }),
        ),
      );
      final run = await Orchestrator(narrator: narrator).run(ctx());
      expect(run.narrative, 'Plain English plan.');
      expect(sent, isNot(contains('Secret')));
      expect(sent, isNot(contains('123456')));
      expect(sent, contains('Goal 1'));
    });

    test('narrator failure keeps the quantitative suggestions', () async {
      final narrator = Narrator(
        LlmClient(
          local(),
          client: MockClient((_) async => http.Response('no', 503)),
        ),
      );
      final run = await Orchestrator(narrator: narrator).run(ctx());
      expect(run.narrative, isNull);
      expect(run.suggestions, isNotEmpty);
      expect(run.errors.single, contains('Narrator'));
    });

    test('running never touches the database (no auto-accept)', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await Orchestrator().run(ctx(values: money(100000, 0)));
      expect(await db.select(db.suggestionLog).get(), isEmpty);
    });
  });

  test('AI is off by default and only active when fully configured', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    Future<String?> key() async => 'k';
    expect((await loadAiSettings(db)).enabled, isFalse);
    expect(await activeAiConfig(db, key), isNull);
    await saveAiSettings(
      db,
      const AiSettings(
        enabled: true,
        kind: AiKind.local,
        endpoint: 'http://localhost:11434/v1',
        model: 'llama3',
      ),
    );
    expect((await activeAiConfig(db, key))?.model, 'llama3');
    // Enabled but invalid (public http) -> still null, nothing is sent.
    await saveAiSettings(
      db,
      const AiSettings(
        enabled: true,
        kind: AiKind.local,
        endpoint: 'http://example.com/v1',
        model: 'm',
      ),
    );
    expect(await activeAiConfig(db, key), isNull);
  });

  test('decisions are logged and updatable', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.decide('rebalance:trades', 'Rebalancing', 'Rebalance', 'accepted');
    await db.decide(
      'rebalance:trades',
      'Rebalancing',
      'Rebalance',
      'dismissed',
    );
    final rows = await db.select(db.suggestionLog).get();
    expect(rows.single.status, 'dismissed');
  });
}

class _Boom implements Agent {
  @override
  String get name => 'Boom';
  @override
  List<Suggestion> run(AgentContext ctx) => throw StateError('kaput');
}
