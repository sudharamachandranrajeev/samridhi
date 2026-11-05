import 'package:flutter_test/flutter_test.dart';
import 'package:samridhi/security/pin_lock.dart';
import 'package:samridhi/sync/vault_crypto.dart' show KdfParams;

import '../support/memory_store.dart';

void main() {
  late MemoryStore store;
  late DateTime clock;
  late PinLock lock;
  setUp(() {
    store = MemoryStore();
    clock = DateTime(2026, 11, 5, 12);
    lock = PinLock(store, kdf: KdfParams.fastForTests, now: () => clock);
  });

  test('no PIN set: nothing to unlock', () async {
    expect(await lock.isSet, isFalse);
    expect(await lock.verify('anything'), isA<PinOk>());
  });

  test('PIN is stored hashed, never in clear', () async {
    await lock.setPin('482913');
    expect(await lock.isSet, isTrue);
    expect(store.data.values.join(), isNot(contains('482913')));
    expect(await lock.verify('482913'), isA<PinOk>());
    expect(await lock.verify('482914'), isA<PinWrong>());
  });

  test('PIN format is validated', () async {
    for (final bad in ['', '123', 'abcd', '1234567890123', '12 34']) {
      expect(PinLock.isValidPin(bad), isFalse, reason: bad);
      await expectLater(lock.setPin(bad), throwsArgumentError);
    }
    expect(PinLock.isValidPin('1234'), isTrue);
  });

  test('wrong guesses count down, then lock out with doubling delay', () async {
    await lock.setPin('1111');
    for (var i = 1; i < freeAttempts; i++) {
      final r = await lock.verify('0000') as PinWrong;
      expect(r.attemptsLeft, freeAttempts - i);
    }
    final first = await lock.verify('0000') as PinLockedOut;
    expect(first.until.difference(clock), const Duration(seconds: 30));
    // Even the right PIN is refused while locked out.
    expect(await lock.verify('1111'), isA<PinLockedOut>());
    clock = clock.add(const Duration(seconds: 31));
    final second = await lock.verify('0000') as PinLockedOut;
    expect(second.until.difference(clock), const Duration(seconds: 60));
  });

  test('lockout survives a restart (state is in the store)', () async {
    await lock.setPin('1111');
    for (var i = 0; i < freeAttempts; i++) {
      await lock.verify('0000');
    }
    final reborn = PinLock(
      store,
      kdf: KdfParams.fastForTests,
      now: () => clock,
    );
    expect(await reborn.verify('1111'), isA<PinLockedOut>());
  });

  test('correct PIN after failures resets the counter', () async {
    await lock.setPin('1111');
    await lock.verify('0000');
    await lock.verify('0000');
    expect(await lock.verify('1111'), isA<PinOk>());
    final r = await lock.verify('0000') as PinWrong;
    expect(r.attemptsLeft, freeAttempts - 1);
  });

  test('clear removes the PIN and the failure counter', () async {
    await lock.setPin('1111');
    await lock.verify('0000');
    await lock.clear();
    expect(await lock.isSet, isFalse);
    expect(store.data, isEmpty);
  });
}
