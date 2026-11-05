import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/database.dart';
import '../../providers.dart';
import '../../sync/pocketbase_transport.dart';
import '../../sync/sync_service.dart';
import '../../sync/vault_crypto.dart';
import '../dialogs.dart';

const _pwKey = 'samridhi_sync_password_v1';

/// Optional self-hosted sync. Off until the user enters a server.
class SyncSection extends ConsumerStatefulWidget {
  const SyncSection({super.key});

  @override
  ConsumerState<SyncSection> createState() => _SyncSectionState();
}

class _SyncSectionState extends ConsumerState<SyncSection> {
  final _url = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _invite = TextEditingController();
  final _storage = const FlutterSecureStorage();
  bool _busy = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    _url.text = await db.getSetting('sync.url') ?? '';
    _email.text = await db.getSetting('sync.email') ?? '';
    _password.text = await _storage.read(key: _pwKey) ?? '';
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _url.dispose();
    _email.dispose();
    _password.dispose();
    _invite.dispose();
    super.dispose();
  }

  Future<String> _deviceId(AppDatabase db) async {
    var id = await db.getSetting('sync.device');
    if (id == null || id.length != 32) {
      final r = Random.secure();
      id = List.generate(
        16,
        (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await db.setSetting('sync.device', id);
    }
    return id;
  }

  Future<PocketBaseTransport> _connect({bool signUp = false}) async {
    final db = ref.read(databaseProvider);
    final device = await _deviceId(db);
    await db.setSetting('sync.url', _url.text.trim());
    await db.setSetting('sync.email', _email.text.trim());
    await _storage.write(key: _pwKey, value: _password.text);
    return signUp
        ? PocketBaseTransport.signUp(
            serverUrl: _url.text,
            email: _email.text.trim(),
            password: _password.text,
            invite: _invite.text.trim(),
            device: device,
          )
        : PocketBaseTransport.signIn(
            serverUrl: _url.text,
            email: _email.text.trim(),
            password: _password.text,
            device: device,
          );
  }

  Future<void> _run(Future<String> Function() action) async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final msg = await action();
      if (mounted) setState(() => _status = msg);
    } on SyncConflict catch (e) {
      if (mounted) setState(() => _status = '$e');
    } on WrongPassphraseOrCorrupt catch (e) {
      if (mounted) setState(() => _status = '$e');
    } on Object catch (e) {
      if (mounted) setState(() => _status = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _createAccount() async {
    await _connect(signUp: true);
    return 'Account created and signed in.';
  }

  Future<String> _push() async {
    final pass = await askPassphrase(
      context,
      title: 'Sync passphrase',
      confirm: true,
    );
    if (pass == null) return 'Cancelled';
    final svc = SyncService(ref.read(databaseProvider), await _connect());
    try {
      return 'Pushed snapshot #${await svc.push(pass)}.';
    } on SyncConflict catch (e) {
      if (!mounted) return '$e';
      final force = await confirmDialog(
        context,
        title: 'Overwrite the server copy?',
        body: '$e\n\nOverwriting replaces what the other device pushed.',
        yes: 'Overwrite',
      );
      if (!force) return 'Not pushed: $e';
      return 'Pushed snapshot #${await svc.push(pass, force: true)}.';
    }
  }

  Future<String> _pull() async {
    final pass = await askPassphrase(context, title: 'Sync passphrase');
    if (pass == null) return 'Cancelled';
    final svc = SyncService(ref.read(databaseProvider), await _connect());
    try {
      final seq = await svc.pull(pass);
      return seq == null ? 'Server has no data yet.' : 'Pulled snapshot #$seq.';
    } on SyncConflict catch (e) {
      if (!mounted) return '$e';
      final force = await confirmDialog(
        context,
        title: 'Replace local changes?',
        body: '$e',
        yes: 'Replace with server copy',
      );
      if (!force) return 'Not pulled: $e';
      return 'Pulled snapshot #${await svc.pull(pass, force: true)}.';
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sync (self-hosted)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text(
            'Optional. Your data is encrypted on this device with your sync '
            'passphrase before upload; the server sees only ciphertext. '
            'See docs/self-hosting.md.',
          ),
          TextField(
            controller: _url,
            decoration: const InputDecoration(labelText: 'Server URL'),
            keyboardType: TextInputType.url,
          ),
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Account e-mail'),
            keyboardType: TextInputType.emailAddress,
          ),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Account password'),
          ),
          TextField(
            controller: _invite,
            decoration: const InputDecoration(
              labelText: 'Invite code (only to create an account)',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: _busy ? null : () => _run(_createAccount),
                child: const Text('Create account'),
              ),
              FilledButton(
                onPressed: _busy ? null : () => _run(_push),
                child: const Text('Push'),
              ),
              FilledButton.tonal(
                onPressed: _busy ? null : () => _run(_pull),
                child: const Text('Pull'),
              ),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_status!),
            ),
        ],
      ),
    ),
  );
}
