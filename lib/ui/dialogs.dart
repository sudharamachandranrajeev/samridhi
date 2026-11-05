import 'package:flutter/material.dart';

/// Asks for a passphrase. With [confirm], asks twice and enforces a minimum
/// length (used when creating a backup or first sync). Returns null if
/// cancelled.
Future<String?> askPassphrase(
  BuildContext context, {
  required String title,
  bool confirm = false,
}) {
  final a = TextEditingController(), b = TextEditingController();
  String? error;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: a,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Passphrase'),
            ),
            if (confirm)
              TextField(
                controller: b,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Repeat passphrase',
                  errorText: error,
                ),
              ),
            if (confirm)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'There is no recovery: if you forget it, the data cannot '
                  'be opened.',
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (confirm) {
                if (a.text.length < 8) {
                  setState(() => error = 'Use at least 8 characters');
                  return;
                }
                if (a.text != b.text) {
                  setState(() => error = 'Passphrases do not match');
                  return;
                }
              } else if (a.text.isEmpty) {
                return;
              }
              Navigator.pop(ctx, a.text);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    ),
  );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  String yes = 'Continue',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(yes),
          ),
        ],
      ),
    ) ??
    false;

void showSnack(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
