import 'dart:typed_data';

import '../data/database.dart';
import 'snapshot.dart';
import 'vault_crypto.dart';

/// Suggested file extension for backup files.
const backupExtension = 'samridhi-db';

/// Encrypted backup of the user's data. Self-contained: restorable on any
/// device with the passphrase, independent of that device's keychain key.
Future<Uint8List> createBackup(
  AppDatabase db,
  String passphrase, {
  KdfParams params = KdfParams.standard,
}) async => sealString(await exportSnapshot(db), passphrase, params: params);

/// Replaces local data with the backup. A wrong passphrase or damaged file
/// throws before anything is changed.
Future<void> restoreBackup(
  AppDatabase db,
  List<int> backup,
  String passphrase,
) async => importSnapshot(db, await openString(backup, passphrase));
