import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_info.dart';
import '../../support/issue_report.dart';
import '../dialogs.dart';

class HelpSection extends StatelessWidget {
  const HelpSection({super.key});

  Future<void> _report(BuildContext context, IssueKind kind) async {
    final controller = TextEditingController();
    final platform = Platform.operatingSystem;
    final osVersion = Platform.operatingSystemVersion;
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          kind == IssueKind.bug ? 'Report a problem' : 'Request a feature',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                maxLines: 5,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Describe it',
                  helperText:
                      'Do not include account numbers, balances or real '
                      'holdings.',
                ),
              ),
              if (kind == IssueKind.bug) ...[
                const SizedBox(height: 12),
                const Text('Also included:'),
                Text(diagnostics(platform: platform, osVersion: osVersion)),
              ],
              const SizedBox(height: 12),
              const Text(
                'This opens a prefilled GitHub issue in your browser. '
                'Nothing is sent until you press Submit there.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open in browser'),
          ),
        ],
      ),
    );
    final text = controller.text;
    controller.dispose();
    if (open != true) return;
    final ok = await launchUrl(
      buildIssueUrl(
        kind: kind,
        description: text,
        platform: platform,
        osVersion: osVersion,
      ),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) showSnack(context, 'Could not open a browser');
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Help & feedback',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('Samridhi $appVersion'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _report(context, IssueKind.bug),
                icon: const Icon(Icons.bug_report_outlined),
                label: const Text('Report a problem'),
              ),
              OutlinedButton.icon(
                onPressed: () => _report(context, IssueKind.feature),
                icon: const Icon(Icons.lightbulb_outline),
                label: const Text('Request a feature'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
