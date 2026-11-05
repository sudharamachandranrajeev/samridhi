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

/// Non-secret app settings (key/value). Secrets never go here — they live in
/// the OS keychain via flutter_secure_storage.
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// The user's decision on an agent suggestion. Accepting only records intent
/// — Samridhi never places orders — and doubles as the local track record.
class SuggestionLog extends Table {
  TextColumn get id => text()();
  TextColumn get agent => text()();
  TextColumn get title => text()();

  /// 'accepted' or 'dismissed'.
  TextColumn get status => text()();
  DateTimeColumn get decidedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [Accounts, Holdings, Goals, RiskAnswers, Settings, SuggestionLog],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(settings);
      if (from < 3) await m.createTable(suggestionLog);
    },
  );

  // ---- suggestion decisions ----
  Stream<Map<String, String>> watchDecisions() =>
      select(suggestionLog)
          .watch()
          .map((rows) => {for (final r in rows) r.id: r.status});
  Future<void> decide(String id, String agent, String title, String status) =>
      into(suggestionLog).insertOnConflictUpdate(
        SuggestionLogCompanion.insert(
          id: id,
          agent: agent,
          title: title,
          status: status,
          decidedAt: DateTime.now(),
        ),
      );

  Future<void> undecide(String id) =>
      (delete(suggestionLog)..where((r) => r.id.equals(id))).go();

  // ---- settings ----
  Stream<String?> watchSetting(String key) => (select(
    settings,
  )..where((s) => s.key.equals(key))).watchSingleOrNull().map((r) => r?.value);
  Future<String?> getSetting(String key) async => (await (select(
    settings,
  )..where((s) => s.key.equals(key))).getSingleOrNull())?.value;
  Future<void> setSetting(String key, String value) => into(settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
  Future<void> removeSetting(String key) =>
      (delete(settings)..where((s) => s.key.equals(key))).go();

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
