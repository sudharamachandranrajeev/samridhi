import 'dart:convert';

import 'package:drift/drift.dart' show Insertable;

import '../data/database.dart';

const snapshotVersion = 1;

/// Serialises the user's data (accounts, holdings, goals, risk answers) to
/// JSON. Settings and keys are deliberately excluded: they are per-device.
Future<String> exportSnapshot(AppDatabase db) async {
  final accounts = await db.select(db.accounts).get();
  final holdings = await db.select(db.holdings).get();
  final goals = await db.select(db.goals).get();
  final risk = await db.select(db.riskAnswers).get();
  // Sorted by encoded form so equal data always serialises identically
  // (sync compares hashes of snapshots to detect unpushed changes).
  List<Map<String, dynamic>> sorted(Iterable<Insertable> rows) =>
      [for (final r in rows) (r as dynamic).toJson() as Map<String, dynamic>]
        ..sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
  return jsonEncode({
    'v': snapshotVersion,
    'accounts': sorted(accounts),
    'holdings': sorted(holdings),
    'goals': sorted(goals),
    'riskAnswers': sorted(risk),
  });
}

/// Replaces local user data with the snapshot, atomically. The whole payload
/// is parsed before anything is deleted, so a malformed snapshot changes
/// nothing. Throws [FormatException] for an unsupported/invalid snapshot.
Future<void> importSnapshot(AppDatabase db, String json) async {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    throw const FormatException('Snapshot is not valid JSON');
  }
  if (decoded is! Map<String, dynamic> || decoded['v'] != snapshotVersion) {
    throw const FormatException('Unsupported snapshot version');
  }
  final map = decoded;
  List<T> rows<T>(String key, T Function(Map<String, dynamic>) f) => [
    for (final e in map[key] as List) f(e as Map<String, dynamic>),
  ];
  final accounts = rows('accounts', Account.fromJson);
  final holdings = rows('holdings', Holding.fromJson);
  final goals = rows('goals', Goal.fromJson);
  final risk = rows('riskAnswers', RiskAnswer.fromJson);
  await db.transaction(() async {
    await db.delete(db.holdings).go();
    await db.delete(db.accounts).go();
    await db.delete(db.goals).go();
    await db.delete(db.riskAnswers).go();
    await db.batch((b) {
      b.insertAll(db.accounts, accounts);
      b.insertAll(db.holdings, holdings);
      b.insertAll(db.goals, goals);
      b.insertAll(db.riskAnswers, risk);
    });
  });
}
