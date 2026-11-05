import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/asset_class.dart';

final _money = NumberFormat('#,##0');
String fmtMoney(double v) => _money.format(v);
String fmtPct(double v, [int digits = 1]) =>
    '${(v * 100).toStringAsFixed(digits)}%';

/// "This is a model, not advice" notice shown on every plan/forecast surface.
class DisclosureBanner extends StatelessWidget {
  const DisclosureBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                modelDisclosure,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}
