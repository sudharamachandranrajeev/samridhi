import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../ai/ai_store.dart';
import '../../ai/llm_client.dart';
import '../../providers.dart';
import '../dialogs.dart';

/// Opt-in, bring-your-own AI. Off until configured; nothing is bundled.
class AiSection extends ConsumerStatefulWidget {
  const AiSection({super.key});

  @override
  ConsumerState<AiSection> createState() => _AiSectionState();
}

class _AiSectionState extends ConsumerState<AiSection> {
  final _endpoint = TextEditingController();
  final _model = TextEditingController();
  final _key = TextEditingController();
  final _storage = const FlutterSecureStorage();
  bool _enabled = false;
  AiKind _kind = AiKind.local;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await loadAiSettings(ref.read(databaseProvider));
    _enabled = s.enabled;
    _kind = s.kind;
    _endpoint.text = s.endpoint;
    _model.text = s.model;
    _key.text = await _storage.read(key: aiKeyName) ?? '';
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final problem = AiConfig(
      kind: _kind,
      endpoint: _endpoint.text,
      model: _model.text,
      apiKey: _key.text,
    ).validate();
    if (_enabled && problem != null) {
      showSnack(context, problem);
      return;
    }
    await saveAiSettings(
      ref.read(databaseProvider),
      AiSettings(
        enabled: _enabled,
        kind: _kind,
        endpoint: _endpoint.text,
        model: _model.text,
      ),
    );
    if (_key.text.isEmpty) {
      await _storage.delete(key: aiKeyName);
    } else {
      await _storage.write(key: aiKeyName, value: _key.text);
    }
    if (mounted) showSnack(context, 'AI settings saved');
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI narration (optional)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text(
            'Off by default. Bring your own model: a local endpoint '
            '(Ollama, LM Studio…) or your own cloud API key, kept in the OS '
            'keychain. Only rounded, anonymous figures are ever sent — never '
            'names, account numbers or exact balances. The AI only explains '
            'the plan in words; it cannot change it or place trades.',
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable AI narration'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          DropdownButtonFormField<AiKind>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Provider'),
            items: [
              for (final k in AiKind.values)
                DropdownMenuItem(value: k, child: Text(k.label)),
            ],
            onChanged: (k) => setState(() => _kind = k ?? _kind),
          ),
          TextField(
            controller: _endpoint,
            decoration: InputDecoration(
              labelText: 'Endpoint URL',
              hintText: switch (_kind) {
                AiKind.local => 'http://localhost:11434/v1',
                AiKind.anthropic => 'https://api.anthropic.com',
                AiKind.openaiCompatible => 'https://…/v1',
              },
            ),
            keyboardType: TextInputType.url,
          ),
          TextField(
            controller: _model,
            decoration: const InputDecoration(labelText: 'Model name'),
          ),
          TextField(
            controller: _key,
            obscureText: true,
            decoration: InputDecoration(
              labelText: _kind == AiKind.local
                  ? 'API key (usually blank for local)'
                  : 'API key',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    ),
  );
}
