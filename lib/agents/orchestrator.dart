import 'dart:convert';

import '../ai/digest.dart';
import '../ai/llm_client.dart';
import 'agents.dart';

const narratorSystemPrompt =
    'You explain an investment plan in plain English to a non-expert. Use '
    'only the figures in the JSON the user sends; never invent numbers. Do '
    'not recommend specific securities, funds or products and do not give '
    'personalised financial advice. Keep it under 180 words and end with one '
    'sentence saying this is an illustrative model, not advice.';

/// LLM narrator: turns the anonymised digest into prose. Its output is shown
/// as text only; it cannot create or trigger suggestions.
class Narrator {
  Narrator(this.client);
  final LlmClient client;

  Future<String> explain(AgentContext ctx) {
    final digest = buildDigest(
      risk: ctx.risk,
      plan: ctx.plan,
      currentValues: ctx.values,
    );
    return client.complete(
      system: narratorSystemPrompt,
      user: jsonEncode(digest),
    );
  }
}

class AgentRun {
  const AgentRun({
    required this.suggestions,
    required this.narrative,
    required this.errors,
  });
  final List<Suggestion> suggestions;

  /// AI narration, or null if AI is off or the call failed.
  final String? narrative;
  final List<String> errors;
}

/// Sequences the agents. It has no side effects: it returns suggestions and
/// never trades, writes to the database, or accepts anything on the user's
/// behalf. Each agent is isolated so one failure does not hide the rest.
class Orchestrator {
  Orchestrator({List<Agent>? agents, this.narrator})
    : agents = agents ?? defaultAgents();
  final List<Agent> agents;
  final Narrator? narrator;

  /// Runs the deterministic agents only (instant, no network, no AI).
  AgentRun runAgents(AgentContext ctx) {
    final out = <Suggestion>[];
    final errors = <String>[];
    for (final a in agents) {
      try {
        out.addAll(a.run(ctx));
      } on Object catch (e) {
        errors.add('${a.name}: $e');
      }
    }
    return AgentRun(suggestions: out, narrative: null, errors: errors);
  }

  /// Deterministic agents, then the optional AI narrator.
  Future<AgentRun> run(AgentContext ctx) async {
    final base = runAgents(ctx);
    final n = narrator;
    if (n == null) return base;
    try {
      return AgentRun(
        suggestions: base.suggestions,
        narrative: await n.explain(ctx),
        errors: base.errors,
      );
    } on Object catch (e) {
      return AgentRun(
        suggestions: base.suggestions,
        narrative: null,
        errors: [...base.errors, 'Narrator: $e'],
      );
    }
  }
}
