import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/holdings_import.dart';
import '../../data/database.dart';
import '../../providers.dart';
import '../dialogs.dart';

/// Read-only holdings import from a JSON/CSV file (e.g. an Artha export).
class ImportSection extends ConsumerWidget {
  const ImportSection({super.key});

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.pickFiles(
      dialogTitle: 'Choose a holdings file',
    );
    if (picked.isEmpty || !context.mounted) return;
    final ImportResult r;
    try {
      r = parseHoldings(await picked.single.readAsBytes());
    } on FormatException catch (e) {
      if (context.mounted) showSnack(context, 'Cannot import: ${e.message}');
      return;
    }
    if (!context.mounted) return;
    final skipped = r.problems.isEmpty
        ? ''
        : ' ${r.problems.length} row(s) will be skipped '
              '(first: ${r.problems.first}).';
    final ok = await confirmDialog(
      context,
      title: 'Import ${r.holdingCount} holdings?',
      body:
          '${r.accounts.length} account(s): '
          '${r.accounts.map((a) => a.name).join(', ')}.$skipped Existing '
          'imported accounts with the same names are updated; nothing is '
          'deleted and nothing is sent anywhere.',
      yes: 'Import',
    );
    if (!ok) return;
    final db = ref.read(databaseProvider);
    for (final a in r.accounts) {
      await db.upsertAccount(
        AccountsCompanion(
          id: Value(a.id),
          name: Value(a.name),
          wrapper: Value(a.wrapper),
          source: const Value('import'),
        ),
      );
      for (final h in a.holdings) {
        await db.upsertHolding(
          HoldingsCompanion(
            id: Value(holdingId(a, h)),
            accountId: Value(a.id),
            name: Value(h.name),
            assetClass: Value(h.assetClass.name),
            value: Value(h.value),
          ),
        );
      }
    }
    if (context.mounted) showSnack(context, 'Imported ${r.holdingCount}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Import holdings',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Reads a JSON ($holdingsFormat) or CSV file you choose, for '
            'example an export from Artha. Samridhi only reads the file and '
            'never writes to Artha. CSV header: '
            'account,wrapper,holding,assetClass,value',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _import(context, ref),
            icon: const Icon(Icons.file_open),
            label: const Text('Choose file…'),
          ),
        ],
      ),
    ),
  );
}
