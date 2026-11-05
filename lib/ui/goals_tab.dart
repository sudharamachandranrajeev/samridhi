import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../providers.dart';
import 'common.dart';

class GoalsTab extends ConsumerWidget {
  const GoalsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider).asData?.value ?? const <Goal>[];
    return Scaffold(
      body: goals.isEmpty
          ? const EmptyState(
              'No goals yet. Add goals like retirement or a house deposit; '
              'each gets its own target mix based on its time horizon.',
            )
          : ListView(
              children: [
                for (final g in goals)
                  ListTile(
                    title: Text(g.name),
                    subtitle: Text(
                      'Target ${fmtMoney(g.targetAmount)} · '
                      '${g.horizonYears.toStringAsFixed(0)} years',
                    ),
                    trailing: IconButton(
                      tooltip: 'Delete goal',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          ref.read(databaseProvider).deleteGoal(g.id),
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add goal'),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final amount = TextEditingController();
    final years = TextEditingController(text: '10');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target amount'),
            ),
            TextField(
              controller: years,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Years to goal'),
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
    );
    final a = double.tryParse(amount.text);
    final y = double.tryParse(years.text);
    if (ok != true || name.text.trim().isEmpty || a == null || y == null) {
      return;
    }
    await ref
        .read(databaseProvider)
        .upsertGoal(
          GoalsCompanion(
            id: Value(const Uuid().v4()),
            name: Value(name.text.trim()),
            targetAmount: Value(a),
            horizonYears: Value(y.clamp(0.5, 60)),
          ),
        );
  }
}
