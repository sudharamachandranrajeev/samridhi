import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/asset_class.dart';
import '../data/database.dart';
import '../providers.dart';
import 'common.dart';

class WealthTab extends ConsumerWidget {
  const WealthTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).asData?.value ?? const [];
    final holdings = ref.watch(holdingsProvider).asData?.value ?? const [];
    final total = holdings.fold(0.0, (a, h) => a + h.value);
    return Scaffold(
      body: holdings.isEmpty
          ? const EmptyState(
              'No holdings yet. Enter them manually — nothing leaves this '
              'device. (Reading from Artha arrives with sync.)',
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                ListTile(
                  title: const Text('Total'),
                  trailing: Text(
                    fmtMoney(total),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                for (final a in accounts) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      a.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  for (final h in holdings.where((h) => h.accountId == a.id))
                    ListTile(
                      title: Text(h.name),
                      subtitle: Text(assetClassFromName(h.assetClass).label),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(fmtMoney(h.value)),
                          IconButton(
                            tooltip: 'Delete holding',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                ref.read(databaseProvider).deleteHolding(h.id),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref, accounts),
        icon: const Icon(Icons.add),
        label: const Text('Add holding'),
      ),
    );
  }

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    List<Account> accounts,
  ) async {
    final account = TextEditingController(
      text: accounts.isEmpty ? 'My account' : accounts.first.name,
    );
    final name = TextEditingController();
    final value = TextEditingController();
    var cls = AssetClass.equity;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('New holding'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: account,
                decoration: const InputDecoration(labelText: 'Account name'),
              ),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Holding name'),
              ),
              DropdownButtonFormField<AssetClass>(
                initialValue: cls,
                decoration: const InputDecoration(labelText: 'Asset class'),
                items: [
                  for (final c in AssetClass.values)
                    DropdownMenuItem(value: c, child: Text(c.label)),
                ],
                onChanged: (v) => setState(() => cls = v!),
              ),
              TextField(
                controller: value,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Value'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    final v = double.tryParse(value.text);
    if (ok != true ||
        v == null ||
        v < 0 ||
        name.text.trim().isEmpty ||
        account.text.trim().isEmpty) {
      return;
    }
    final db = ref.read(databaseProvider);
    final existing = accounts.where((a) => a.name == account.text.trim());
    final accountId = existing.isNotEmpty
        ? existing.first.id
        : const Uuid().v4();
    if (existing.isEmpty) {
      await db.upsertAccount(
        AccountsCompanion(
          id: Value(accountId),
          name: Value(account.text.trim()),
        ),
      );
    }
    await db.upsertHolding(
      HoldingsCompanion(
        id: Value(const Uuid().v4()),
        accountId: Value(accountId),
        name: Value(name.text.trim()),
        assetClass: Value(cls.name),
        value: Value(v),
      ),
    );
  }
}
