import 'package:flutter/material.dart';

/// Samridhi — local-first wealth, asset and investment management.
///
/// Phase P0 (scaffold): app shell only. No real portfolio engine, no agents,
/// no AI yet — those land in later phases per
/// docs/plan/2026-11-05-samridhi-plan.md.
void main() {
  runApp(const SamridhiApp());
}

class SamridhiApp extends StatelessWidget {
  const SamridhiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Samridhi',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D32),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D32),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const _HomeScaffold(),
    );
  }
}

class _HomeScaffold extends StatelessWidget {
  const _HomeScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Samridhi')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.savings_outlined, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Samridhi — P0 scaffold',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Local-first wealth and investment planning.\n'
                'Risk profiling, portfolio construction, rebalancing and '
                'agents land in later phases.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
