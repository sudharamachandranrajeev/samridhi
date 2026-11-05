import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:io';

import 'data/connection.dart';
import 'providers.dart';
import 'security/device_security.dart';
import 'ui/home_page.dart';
import 'ui/lock_gate.dart';
import 'update/launcher.dart';

/// Samridhi — local-first wealth, asset and investment planning.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // If an updated version was installed in-app, hand over to it.
  final store = updatesSupported ? await defaultVersionStore() : null;
  if (store != null && await relaunchIfUpdated(store)) exit(0);
  final db = await openEncryptedDatabase();
  await applyCaptureBlock(await db.getSetting(blockCaptureSetting) == '1');
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const SamridhiApp(),
    ),
  );
  // An updated copy proves it starts (DB opened, first frame drawn); until
  // then the launcher may roll it back.
  if (store != null && runningFromStore(store)) {
    WidgetsBinding.instance.addPostFrameCallback((_) => store.markHealthy());
  }
}

class SamridhiApp extends StatelessWidget {
  const SamridhiApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
      colorSchemeSeed: const Color(0xFF2E7D32),
      useMaterial3: true,
      brightness: b,
    );
    return MaterialApp(
      title: 'Samridhi',
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: const LockGate(child: HomePage()),
    );
  }
}
