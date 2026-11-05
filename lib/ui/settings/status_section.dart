import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../security/lock_controller.dart';
import '../../security/sentinel.dart';

/// Local-only health checks. Nothing here is sent anywhere.
class StatusSection extends ConsumerStatefulWidget {
  const StatusSection({super.key});

  @override
  ConsumerState<StatusSection> createState() => _StatusSectionState();
}

class _StatusSectionState extends ConsumerState<StatusSection> {
  late final Future<List<(IconData, String)>> _rows = _check();

  Future<List<(IconData, String)>> _check() async {
    final rows = <(IconData, String)>[];
    final integrity = await ref.read(databaseProvider).integrityCheck();
    rows.add(
      integrity == 'ok'
          ? (Icons.check_circle_outline, 'Database integrity: OK')
          : (Icons.error_outline, 'Database integrity problem: $integrity'),
    );
    final hasPin = await ref.read(pinLockProvider).isSet;
    rows.add(
      hasPin
          ? (Icons.lock_outline, 'App lock: on')
          : (Icons.lock_open, 'App lock: off (set a PIN above)'),
    );
    if (Platform.isWindows) {
      rows.add(switch (await querySentinel()) {
        SentinelRunning(:final version) => (
          Icons.shield_outlined,
          'Sentinel $version is running',
        ),
        SentinelRestricted() => (
          Icons.shield_outlined,
          'Sentinel is running (its status needs administrator rights)',
        ),
        SentinelAbsent() => (
          Icons.shield_outlined,
          'Sentinel not installed (optional)',
        ),
        SentinelUnusable(:final reason) => (
          Icons.shield_outlined,
          'Sentinel found but not usable ($reason)',
        ),
      });
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Security status',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          FutureBuilder(
            future: _rows,
            builder: (context, snap) {
              if (!snap.hasData) return const LinearProgressIndicator();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (icon, text) in snap.data!)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Icon(icon, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(text)),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}
