import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/connection.dart';
import 'providers.dart';
import 'ui/home_page.dart';

/// Samridhi — local-first wealth, asset and investment planning.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await openEncryptedDatabase();
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const SamridhiApp(),
    ),
  );
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
      home: const HomePage(),
    );
  }
}
