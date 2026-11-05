import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../sync/backup.dart';
import '../../sync/vault_crypto.dart';
import '../dialogs.dart';

class BackupSection extends ConsumerWidget {
  const BackupSection({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final pass = await askPassphrase(
      context,
      title: 'Encrypt backup',
      confirm: true,
    );
    if (pass == null || !context.mounted) return;
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    try {
      final bytes = await createBackup(ref.read(databaseProvider), pass);
      final saved = await FilePicker.saveFile(
        fileName: 'samridhi-$stamp.$backupExtension',
        bytes: bytes,
        dialogTitle: 'Save encrypted backup',
      );
      if (context.mounted) {
        showSnack(context, saved == null ? 'Cancelled' : 'Backup saved');
      }
    } on Object catch (e) {
      if (context.mounted) showSnack(context, 'Backup failed: $e');
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.pickFiles(dialogTitle: 'Choose a backup');
    if (picked.isEmpty || !context.mounted) return;
    final f = picked.single;
    final pass = await askPassphrase(context, title: 'Backup passphrase');
    if (pass == null || !context.mounted) return;
    final ok = await confirmDialog(
      context,
      title: 'Replace current data?',
      body:
          'Restoring replaces all accounts, holdings, goals and risk answers '
          'on this device with the backup.',
      yes: 'Restore',
    );
    if (!ok || !context.mounted) return;
    try {
      final bytes = await f.readAsBytes();
      await restoreBackup(ref.read(databaseProvider), bytes, pass);
      if (context.mounted) showSnack(context, 'Backup restored');
    } on WrongPassphraseOrCorrupt catch (e) {
      if (context.mounted) showSnack(context, '$e');
    } on Object catch (e) {
      if (context.mounted) showSnack(context, 'Restore failed: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Backup & restore',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text(
            'Encrypted with your passphrase (Argon2id + XChaCha20-Poly1305). '
            'The file works on any device; keep the passphrase safe.',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _export(context, ref),
                icon: const Icon(Icons.upload_file),
                label: const Text('Export'),
              ),
              OutlinedButton.icon(
                onPressed: () => _restore(context, ref),
                icon: const Icon(Icons.restore),
                label: const Text('Restore'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
