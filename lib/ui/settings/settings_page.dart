import 'package:flutter/material.dart';

import 'ai_section.dart';
import 'backup_section.dart';
import 'security_section.dart';
import 'sync_section.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        SecuritySection(),
        SizedBox(height: 12),
        AiSection(),
        SizedBox(height: 12),
        BackupSection(),
        SizedBox(height: 12),
        SyncSection(),
      ],
    ),
  );
}
