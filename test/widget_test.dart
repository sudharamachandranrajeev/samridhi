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
    await tester.pumpWidget(app(db));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.textContaining('profile'), findsWidgets);
    expect(find.text('Sample retirement'), findsOneWidget);
    expect(find.textContaining('not financial advice'), findsOneWidget);
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
