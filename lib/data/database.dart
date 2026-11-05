import 'package:drift/drift.dart';

part 'database.g.dart';

/// Read-model of accounts (from Artha, or entered manually). Samridhi never
/// writes back to Artha's ledger.
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// e.g. isa, pension, taxable, cash — drives wrapper rules later.
  TextColumn get wrapper => text().withDefault(const Constant('taxable'))();

  /// 'manual' or 'artha'.
  TextColumn get source => text().withDefault(const Constant('manual'))();

  @override
  Set<Column> get primaryKey => {id};
}

class Holdings extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get name => text()();

  /// Name of an AssetClass enum value.
  TextColumn get assetClass => text()();
  RealColumn get value => real()();

  @override
  Set<Column> get primaryKey => {id};
}

class Goals extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get targetAmount => real()();
  RealColumn get horizonYears => real()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One row per answered risk question (question id -> chosen option index).
class RiskAnswers extends Table {
  TextColumn get questionId => text()();
  IntColumn get optionIndex => integer()();

  @override
  Set<Column> get primaryKey => {questionId};
}

@DriftDatabase(tables: [Accounts, Holdings, Goals, RiskAnswers])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  // ---- accounts / holdings ----
  Stream<List<Account>> watchAccounts() => select(accounts).watch();
  Future<void> upsertAccount(AccountsCompanion a) =>
      into(accounts).insertOnConflictUpdate(a);
  Future<void> deleteAccount(String id) async {
    await (delete(holdings)..where((h) => h.accountId.equals(id))).go();
    await (delete(accounts)..where((a) => a.id.equals(id))).go();
  }

  Stream<List<Holding>> watchHoldings() => select(holdings).watch();
  Future<void> upsertHolding(HoldingsCompanion h) =>
      into(holdings).insertOnConflictUpdate(h);
  Future<void> deleteHolding(String id) =>
      (delete(holdings)..where((h) => h.id.equals(id))).go();

  // ---- goals ----
  Stream<List<Goal>> watchGoals() => select(goals).watch();
  Future<void> upsertGoal(GoalsCompanion g) =>
      into(goals).insertOnConflictUpdate(g);
  Future<void> deleteGoal(String id) =>
      (delete(goals)..where((g) => g.id.equals(id))).go();

  // ---- risk answers ----
  Stream<Map<String, int>> watchRiskAnswers() =>
      select(riskAnswers)
          .watch()
          .map((rows) => {for (final r in rows) r.questionId: r.optionIndex});

  Future<void> saveRiskAnswers(Map<String, int> answers) => transaction(
    () async {
      await delete(riskAnswers).go();
      for (final e in answers.entries) {
        await into(riskAnswers).insert(
          RiskAnswersCompanion.insert(questionId: e.key, optionIndex: e.value),
        );
      }
    },
  );
}
