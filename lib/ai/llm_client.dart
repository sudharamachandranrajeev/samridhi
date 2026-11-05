import 'dart:convert';

import 'package:http/http.dart' as http;

import '../sync/sync_service.dart' show isAllowedServerUrl;

/// Where the user's own model lives. Opt-in and BYO: nothing is bundled and
/// there is no default endpoint or key.
enum AiKind {
  /// OpenAI-compatible chat endpoint on the user's machine/network
  /// (Ollama, LM Studio, llama.cpp server). Plain http allowed on private
  /// networks; the key is optional.
  local('Local model (OpenAI-compatible)'),

  /// Anthropic Messages API with the user's own key. https only.
  anthropic('Anthropic (own API key)'),

  /// Any cloud OpenAI-compatible endpoint with the user's own key. https only.
  openaiCompatible('Cloud, OpenAI-compatible (own API key)');

  const AiKind(this.label);
  final String label;
}

class AiConfig {
  const AiConfig({
    required this.kind,
    required this.endpoint,
    required this.model,
    this.apiKey,
  });
  final AiKind kind;

  /// Base URL, e.g. `http://localhost:11434/v1` or `https://api.anthropic.com`.
  final String endpoint;
  final String model;

  /// Held in the OS keychain by the caller; never persisted by this class.
  final String? apiKey;

  /// Returns a problem description, or null if the config is usable.
  String? validate() {
    if (model.trim().isEmpty) return 'Enter a model name.';
    final u = Uri.tryParse(endpoint.trim());
    if (u == null || u.host.isEmpty) return 'Enter a valid endpoint URL.';
    if (kind == AiKind.local) {
      if (!isAllowedServerUrl(endpoint)) {
        return 'Use https:// unless the model runs on this machine or your '
            'own network.';
      }
    } else {
      if (u.scheme != 'https') return 'Cloud endpoints must use https://.';
      if ((apiKey ?? '').isEmpty) return 'Enter your API key.';
    }
    return null;
  }
}

class LlmException implements Exception {
  const LlmException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Minimal one-shot completion. Output is treated as untrusted text: it is
/// only ever displayed, never parsed into actions.
class LlmClient {
  LlmClient(this.config, {http.Client? client})
    : _http = client ?? http.Client();
  final AiConfig config;
  final http.Client _http;

  Future<String> complete({
    required String system,
    required String user,
    int maxTokens = 600,
  }) async {
    final problem = config.validate();
    if (problem != null) throw LlmException(problem);
    final base = config.endpoint.trim().replaceAll(RegExp(r'/+$'), '');
    final anthropic = config.kind == AiKind.anthropic;
    final uri = Uri.parse(
      anthropic ? '$base/v1/messages' : '$base/chat/completions',
    );
    final headers = <String, String>{'content-type': 'application/json'};
    final key = config.apiKey ?? '';
    if (anthropic) {
      headers['x-api-key'] = key;
      headers['anthropic-version'] = '2023-06-01';
    } else if (key.isNotEmpty) {
      headers['authorization'] = 'Bearer $key';
    }
    final body = anthropic
        ? {
            'model': config.model,
            'max_tokens': maxTokens,
            'system': system,
            'messages': [
              {'role': 'user', 'content': user},
            ],
          }
        : {
            'model': config.model,
            'max_tokens': maxTokens,
            'messages': [
              {'role': 'system', 'content': system},
              {'role': 'user', 'content': user},
            ],
          };
    final http.Response res;
    try {
      res = await _http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 90));
    } on Object catch (e) {
      throw LlmException('Could not reach the model: $e');
    }
    if (res.statusCode != 200) {
      // Status only: provider error bodies can echo request content.
      throw LlmException('The model endpoint returned HTTP ${res.statusCode}.');
    }
    try {
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final text = anthropic
          ? (j['content'] as List)
                .whereType<Map<String, dynamic>>()
                .where((b) => b['type'] == 'text')
                .map((b) => b['text'] as String)
                .join()
          : (((j['choices'] as List).first as Map)['message'] as Map)['content']
                as String;
      if (text.trim().isEmpty) throw const LlmException('Empty reply.');
      return text.trim();
    } on LlmException {
      rethrow;
    } on Object {
      throw const LlmException('Unexpected reply format from the model.');
    }
  }
}
