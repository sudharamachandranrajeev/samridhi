import '../data/database.dart';
import 'llm_client.dart';

/// Keychain entry name for the user's model API key.
const aiKeyName = 'samridhi_ai_key_v1';

const _enabled = 'ai.enabled';
const _kind = 'ai.kind';
const _endpoint = 'ai.endpoint';
const _model = 'ai.model';

/// Non-secret AI settings. Off by default; the API key lives only in the OS
/// keychain under [aiKeyName].
class AiSettings {
  const AiSettings({
    this.enabled = false,
    this.kind = AiKind.local,
    this.endpoint = '',
    this.model = '',
  });
  final bool enabled;
  final AiKind kind;
  final String endpoint;
  final String model;
}

Future<void> saveAiSettings(AppDatabase db, AiSettings s) async {
  await db.setSetting(_enabled, s.enabled ? '1' : '0');
  await db.setSetting(_kind, s.kind.name);
  await db.setSetting(_endpoint, s.endpoint.trim());
  await db.setSetting(_model, s.model.trim());
}

Future<AiSettings> loadAiSettings(AppDatabase db) async {
  final kind = await db.getSetting(_kind);
  return AiSettings(
    enabled: await db.getSetting(_enabled) == '1',
    kind: AiKind.values.firstWhere(
      (k) => k.name == kind,
      orElse: () => AiKind.local,
    ),
    endpoint: await db.getSetting(_endpoint) ?? '',
    model: await db.getSetting(_model) ?? '',
  );
}

/// A usable [AiConfig], or null if AI is off or the saved settings are
/// invalid. [readKey] fetches the API key from the keychain on demand.
Future<AiConfig?> activeAiConfig(
  AppDatabase db,
  Future<String?> Function() readKey,
) async {
  final s = await loadAiSettings(db);
  if (!s.enabled) return null;
  final cfg = AiConfig(
    kind: s.kind,
    endpoint: s.endpoint,
    model: s.model,
    apiKey: await readKey(),
  );
  return cfg.validate() == null ? cfg : null;
}
