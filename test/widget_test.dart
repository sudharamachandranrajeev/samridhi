import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samridhi/core/risk_profile.dart';
import 'package:samridhi/data/database.dart';
import 'package:samridhi/main.dart';
import 'package:samridhi/providers.dart';

Widget app(AppDatabase db) => ProviderScope(
  overrides: [databaseProvider.overrideWithValue(db)],
  child: const SamridhiApp(),
);

/// Unmounts the app so Riverpod cancels its drift streams, then lets drift's
/// zero-duration stream-cleanup timer fire before the test ends.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(Duration.zero);
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
    await tester.tap(find.text('Insights'));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    expect(find.text('Rebalancing'), findsOneWidget);
    expect(find.textContaining('Outside bands'), findsOneWidget);
    expect(find.textContaining('Synthetic sample data'), findsWidgets);
    expect(find.textContaining('Never rebalance'), findsOneWidget);
    expect(find.textContaining('band held'), findsWidgets);
    expect(find.textContaining('not financial advice'), findsOneWidget);
    await unmount(tester);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
  }

  testWidgets('agents are off by default and need an explicit tap', (
    tester,
  ) async {
    await tester.pumpWidget(app(db));
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
