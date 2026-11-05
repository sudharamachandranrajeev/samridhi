import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samridhi/data/database.dart';
import 'package:samridhi/sync/backup.dart';
import 'package:samridhi/sync/snapshot.dart';
import 'package:samridhi/sync/sync_service.dart';
import 'package:samridhi/sync/vault_crypto.dart';

/// In-memory stand-in for the server: same unique-seq rule as the real
/// `sam_changes` collection.
class FakeServer implements SyncTransport {
  final rows = <int, String>{};

  @override
  Future<RemoteHead?> latest() async {
    if (rows.isEmpty) return null;
    final seq = rows.keys.reduce((a, b) => a > b ? a : b);
    return RemoteHead(seq, rows[seq]!);
  }

  @override
  Future<void> push({required int seq, required String payload}) async {
    if (rows.containsKey(seq)) throw const SyncConflict('taken');
    rows[seq] = payload;
  }
}

Future<void> seed(AppDatabase db, {String goal = 'Sample retirement'}) async {
  await db.upsertAccount(AccountsCompanion.insert(id: 'a', name: 'Sample ISA'));
  await db.upsertHolding(
    HoldingsCompanion.insert(
      id: 'h',
      accountId: 'a',
      name: 'Sample fund',
      assetClass: 'equity',
      value: 1000,
    ),
  );
  await db.upsertGoal(
    GoalsCompanion.insert(
      id: 'g',
      name: goal,
      targetAmount: 50000,
      horizonYears: 20,
    ),
  );
  await db.saveRiskAnswers({'q1': 2});
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  const fast = KdfParams.fastForTests;

  group('vault_crypto', () {
    test('round-trips and the envelope hides the plaintext', () async {
      final sealed = await sealString('secret holdings', 'pw', params: fast);
      expect(
        utf8.decode(sealed, allowMalformed: true),
        isNot(contains('secret')),
      );
      expect(await openString(sealed, 'pw'), 'secret holdings');
    });

    test('same input sealed twice differs (fresh salt + nonce)', () async {
      final a = await sealString('x', 'pw', params: fast);
      final b = await sealString('x', 'pw', params: fast);
      expect(a, isNot(b));
    });

    test('wrong passphrase, tampering and junk are rejected', () async {
      final sealed = await sealString('data', 'right', params: fast);
      await expectLater(
        openString(sealed, 'wrong'),
        throwsA(isA<WrongPassphraseOrCorrupt>()),
      );
      final flipped = List<int>.from(sealed)..[sealed.length - 20] ^= 1;
      await expectLater(
        openString(flipped, 'right'),
        throwsA(isA<WrongPassphraseOrCorrupt>()),
      );
      // Header (KDF params) is authenticated too.
      final hdr = List<int>.from(sealed)..[9] = 2;
      await expectLater(
        openString(hdr, 'right'),
        throwsA(isA<WrongPassphraseOrCorrupt>()),
      );
      await expectLater(
        open([1, 2, 3], 'right'),
        throwsA(isA<WrongPassphraseOrCorrupt>()),
      );
    });

    test('absurd KDF cost in a hostile header is refused up front', () async {
      final sealed = await sealString('d', 'pw', params: fast);
      final evil = List<int>.from(sealed)
        ..[5] = 0xff
        ..[6] = 0xff;
      await expectLater(
        open(evil, 'pw'),
        throwsA(isA<WrongPassphraseOrCorrupt>()),
      );
    });
  });

  group('snapshot', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('export -> import into a fresh DB reproduces the data', () async {
      await seed(db);
      final json = await exportSnapshot(db);
      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      await importSnapshot(other, json);
      expect(await exportSnapshot(other), json);
      expect((await other.select(other.holdings).get()).single.value, 1000);
    });

    test('bad snapshot changes nothing', () async {
      await seed(db);
      final before = await exportSnapshot(db);
      for (final bad in ['not json', '{"v":99}', '{"v":1,"accounts":5}']) {
        await expectLater(importSnapshot(db, bad), throwsA(anything));
      }
      expect(await exportSnapshot(db), before);
    });
  });

  group('SyncService', () {
    late AppDatabase d1, d2;
    late FakeServer server;
    late SyncService s1, s2;
    setUp(() {
      d1 = AppDatabase(NativeDatabase.memory());
      d2 = AppDatabase(NativeDatabase.memory());
      server = FakeServer();
      s1 = SyncService(d1, server, kdf: KdfParams.fastForTests);
      s2 = SyncService(d2, server, kdf: KdfParams.fastForTests);
    });
    tearDown(() async {
      await d1.close();
      await d2.close();
    });

    test('push then pull on a second device', () async {
      await seed(d1);
      expect(await s1.push('pw'), 1);
      expect(server.rows[1], isNot(contains('Sample retirement')));
      expect(await s2.pull('pw'), 1);
      expect(await exportSnapshot(d2), await exportSnapshot(d1));
    });

    test('pull from an empty server is a no-op', () async {
      expect(await s2.pull('pw'), isNull);
    });

    test('stale push is refused; force overwrites', () async {
      await seed(d1);
      await s1.push('pw');
      await s2.pull('pw');
      await d2.upsertGoal(
        GoalsCompanion.insert(
          id: 'g',
          name: 'Edited on device 2',
          targetAmount: 1,
          horizonYears: 1,
        ),
      );
      await s2.push('pw'); // seq 2
      await d1.upsertGoal(
        GoalsCompanion.insert(
          id: 'g',
          name: 'Edited on device 1',
          targetAmount: 1,
          horizonYears: 1,
        ),
      );
      await expectLater(s1.push('pw'), throwsA(isA<SyncConflict>()));
      expect(server.rows.length, 2);
      expect(await s1.push('pw', force: true), 3);
    });

    test('pull refuses to discard unpushed local changes', () async {
      await seed(d1);
      await s1.push('pw');
      await seed(d2, goal: 'Local only');
      await expectLater(s2.pull('pw'), throwsA(isA<SyncConflict>()));
      expect((await d2.select(d2.goals).get()).single.name, 'Local only');
      expect(await s2.pull('pw', force: true), 1);
      expect(
        (await d2.select(d2.goals).get()).single.name,
        'Sample retirement',
      );
    });

    test('wrong passphrase on pull leaves local data intact', () async {
      await seed(d1);
      await s1.push('right');
      await expectLater(
        s2.pull('wrong'),
        throwsA(isA<WrongPassphraseOrCorrupt>()),
      );
      expect(await d2.select(d2.goals).get(), isEmpty);
    });

    test('hasLocalChanges tracks edits after a sync', () async {
      await seed(d1);
      await s1.push('pw');
      expect(await s1.hasLocalChanges(), isFalse);
      await d1.deleteGoal('g');
      expect(await s1.hasLocalChanges(), isTrue);
    });
  });

  test(
    'backup file restores; wrong passphrase leaves data untouched',
    () async {
      final a = AppDatabase(NativeDatabase.memory());
      final b = AppDatabase(NativeDatabase.memory());
      addTearDown(a.close);
      addTearDown(b.close);
      await seed(a);
      final file = await createBackup(a, 'pass-1234', params: fast);
      await seed(b, goal: 'Untouched');
      await expectLater(
        restoreBackup(b, file, 'nope'),
        throwsA(isA<WrongPassphraseOrCorrupt>()),
      );
      expect((await b.select(b.goals).get()).single.name, 'Untouched');
      await restoreBackup(b, file, 'pass-1234');
      expect((await b.select(b.goals).get()).single.name, 'Sample retirement');
    },
  );

  test('server URL policy', () {
    for (final ok in [
      'https://sync.example.com',
      'http://127.0.0.1:8090',
      'http://localhost:8090',
      'http://192.168.1.20:8090',
      'http://10.0.0.5',
      'http://172.16.0.1',
      'http://100.64.1.2',
      'http://nas.local:8090',
    ]) {
      expect(isAllowedServerUrl(ok), isTrue, reason: ok);
    }
    for (final bad in [
      'http://example.com',
      'http://8.8.8.8',
      'http://172.32.0.1',
      'ftp://192.168.1.1',
      'not a url',
      '',
    ]) {
      expect(isAllowedServerUrl(bad), isFalse, reason: bad);
    }
  });
}
