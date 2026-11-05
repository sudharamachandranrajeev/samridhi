import 'dart:math';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'database.dart';

const _keyName = 'samridhi_db_key_v1';

/// Returns the database key from the OS keychain, creating a random 256-bit
/// key on first run. The key is never written to a file or log.
Future<String> loadOrCreateDbKey([
  FlutterSecureStorage storage = const FlutterSecureStorage(),
]) async {
  final existing = await storage.read(key: _keyName);
  if (existing != null && existing.length == 64) return existing;
  final rnd = Random.secure();
  final hex = List.generate(
    32,
    (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  await storage.write(key: _keyName, value: hex);
  return hex;
}

/// Opens the encrypted on-disk database (SQLite3MultipleCiphers, see the
/// `hooks` block in pubspec.yaml).
Future<AppDatabase> openEncryptedDatabase() async {
  final key = await loadOrCreateDbKey();
  return AppDatabase(
    driftDatabase(
      name: 'samridhi',
      native: DriftNativeOptions(
        setup: (rawDb) {
          // Raw 256-bit key syntax understood by SQLite3MultipleCiphers.
          rawDb.execute('PRAGMA key = "x\'$key\'";');
        },
      ),
    ),
  );
}
