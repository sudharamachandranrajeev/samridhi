import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samridhi/core/risk_profile.dart';
import 'package:samridhi/data/database.dart';
import 'package:samridhi/main.dart';
import 'package:samridhi/providers.dart';
import 'package:samridhi/security/lock_controller.dart';
import 'package:samridhi/ui/settings/help_section.dart';
import 'package:samridhi/ui/settings/settings_page.dart';
import 'package:samridhi/ui/motion.dart';
import 'package:samridhi/security/pin_lock.dart';
import 'package:samridhi/sync/vault_crypto.dart' show KdfParams;

import 'support/memory_store.dart';

Widget app(AppDatabase db, {PinLock? lock}) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(db),
    pinLockProvider.overrideWithValue(
      lock ?? PinLock(MemoryStore(), kdf: KdfParams.fastForTests),
    ),
  ],
  child: const SamridhiApp(),
);

/// Unmounts the app so Riverpod cancels its drift streams, then lets drift's
/// zero-duration stream-cleanup timer fire before the test ends.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(Duration.zero);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    // Also lets tab-switch and bar animations finish.
    await tester.pump(const Duration(milliseconds: 600));
  }
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets('empty state asks for the risk questionnaire', (tester) async {
    await tester.pumpWidget(app(db));
    await tester.pump();
    expect(
      find.textContaining('Complete the Risk questionnaire'),
      findsOneWidget,
    );
    expect(find.textContaining('not financial advice'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('saved risk answers produce a plan with disclosure', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await db.saveRiskAnswers({for (final q in riskQuestions) q.id: 2});
      await db.upsertGoal(
        GoalsCompanion.insert(
          id: 'g1',
          name: 'Sample retirement',
          targetAmount: 100000,
          horizonYears: 25,
        ),
      );
    });
    // Tall surface so the lazily built plan ListView renders every row.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(db));
    // drift streams emit on real time; let each provider settle in turn.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    expect(find.textContaining('profile'), findsWidgets);
    expect(find.text('Sample retirement'), findsOneWidget);
    expect(find.textContaining('not financial advice'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('insights tab shows backtest, forecast and rebalance advice', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await db.upsertAccount(AccountsCompanion.insert(id: 'a', name: 'Sample'));
      await db.upsertHolding(
        HoldingsCompanion.insert(
          id: 'h',
          accountId: 'a',
          name: 'Sample equity fund',
          assetClass: 'equity',
          value: 10000,
        ),
      );
    });
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(db));
    await settle(tester);
    await tester.tap(find.text('Insights'));
    await settle(tester);
    expect(find.text('Rebalancing'), findsOneWidget);
    expect(find.textContaining('Outside bands'), findsOneWidget);
    expect(find.textContaining('Synthetic sample data'), findsWidgets);
    expect(find.textContaining('Never rebalance'), findsOneWidget);
    expect(find.textContaining('band held'), findsWidgets);
    expect(find.textContaining('not financial advice'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('agents are off by default and need an explicit tap', (
    tester,
  ) async {
    await tester.pumpWidget(app(db));
    await settle(tester);
    await tester.tap(find.text('Agents'));
    await settle(tester);
    expect(find.text('Agents are off'), findsOneWidget);
    expect(find.textContaining('never place trades'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('accepting a suggestion records intent and executes nothing', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await db.saveRiskAnswers({for (final q in riskQuestions) q.id: 2});
      await db.setSetting('agents.enabled', '1');
      await db.upsertAccount(AccountsCompanion.insert(id: 'a', name: 'Sample'));
      await db.upsertHolding(
        HoldingsCompanion.insert(
          id: 'h',
          accountId: 'a',
          name: 'Sample equity fund',
          assetClass: 'equity',
          value: 10000,
        ),
      );
    });
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(db));
    await settle(tester);
    await tester.tap(find.text('Agents'));
    await settle(tester);
    expect(find.text('Rebalance to target'), findsOneWidget);
    expect(find.textContaining('Confidence:'), findsWidgets);
    expect(find.textContaining('AI-generated'), findsNothing);
    expect(find.textContaining('Off. Add your own model'), findsOneWidget);
    await tester.tap(find.text('Accept (record my intent)'));
    await settle(tester);
    expect(find.text('Accepted — not executed'), findsOneWidget);
    final log = await tester.runAsync(() => db.select(db.suggestionLog).get());
    expect(log!.single.status, 'accepted');
    // Holdings are untouched by accepting.
    final hs = await tester.runAsync(() => db.select(db.holdings).get());
    expect(hs!.single.value, 10000);
    await unmount(tester);
  });

  testWidgets('app lock: PIN screen hides the app until the right PIN', (
    tester,
  ) async {
    final lock = PinLock(MemoryStore(), kdf: KdfParams.fastForTests);
    await tester.runAsync(() => lock.setPin('2468'));
    await tester.pumpWidget(app(db, lock: lock));
    await settle(tester);
    expect(find.text('Samridhi is locked'), findsOneWidget);
    expect(find.text('Plan'), findsNothing);
    await tester.enterText(find.byType(TextField), '0000');
    await tester.tap(find.text('Unlock'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    expect(find.textContaining('Wrong PIN'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '2468');
    await tester.tap(find.text('Unlock'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    expect(find.text('Samridhi is locked'), findsNothing);
    expect(find.text('Plan'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('reduced motion turns animations off', (tester) async {
    late Duration normal, reduced;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            normal = motionDuration(c);
            return MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Builder(
                builder: (c2) {
                  reduced = motionDuration(c2);
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      ),
    );
    expect(normal, const Duration(milliseconds: 350));
    expect(reduced, Duration.zero);
  });

  testWidgets('settings page renders every section without errors', (
    tester,
  ) async {
    // The settings sections read the OS keychain; stub the plugin channel.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        null,
      ),
    );
    await tester.pumpWidget(app(db));
    await settle(tester);
    await tester.tap(find.byTooltip('Settings'));
    await settle(tester);
    expect(find.text('Settings'), findsWidgets);
    // Scroll to the last section so every lazily built section is exercised.
    await tester.scrollUntilVisible(
      find.byType(HelpSection),
      400,
      scrollable: find
          .descendant(
            of: find.byType(SettingsPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await unmount(tester);
  });

  test('database round-trips holdings and cascades account delete', () async {
    await db.upsertAccount(AccountsCompanion.insert(id: 'a', name: 'Sample'));
    await db.upsertHolding(
      HoldingsCompanion.insert(
        id: 'h',
        accountId: 'a',
        name: 'Sample fund',
        assetClass: 'equity',
        value: 1000,
      ),
    );
    expect((await db.select(db.holdings).get()).length, 1);
    await db.deleteAccount('a');
    expect(await db.select(db.holdings).get(), isEmpty);
  });
}
