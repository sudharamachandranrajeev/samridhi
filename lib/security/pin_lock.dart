import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../sync/vault_crypto.dart' show KdfParams;

/// Tiny key/value secret storage; the real one is the OS keychain.
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class KeychainStore implements SecretStore {
  const KeychainStore([this._s = const FlutterSecureStorage()]);
  final FlutterSecureStorage _s;
  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _s.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _s.delete(key: key);
}

sealed class PinResult {
  const PinResult();
}

class PinOk extends PinResult {
  const PinOk();
}

class PinWrong extends PinResult {
  const PinWrong(this.attemptsLeft);

  /// Attempts before the next lockout starts (0 = locked out now).
  final int attemptsLeft;
}

class PinLockedOut extends PinResult {
  const PinLockedOut(this.until);
  final DateTime until;
}

const _pinKey = 'samridhi_pin_v1';
const _failKey = 'samridhi_pin_fail_v1';
const freeAttempts = 5;

/// App-lock PIN. The PIN is stored only as a salted Argon2id hash in the OS
/// keychain. This is a UI gate against someone picking up an unlocked device,
/// not encryption: the database key is protected by the OS keychain, not by
/// this PIN.
///
/// Wrong guesses are rate-limited: [freeAttempts] free tries, then a lockout
/// that doubles each further failure (30 s, 60 s, ... capped at 1 h). The
/// counter persists across restarts.
class PinLock {
  PinLock(
    this._store, {
    this.kdf = KdfParams.standard,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;
  final SecretStore _store;
  final KdfParams kdf;
  final DateTime Function() _now;

  Future<bool> get isSet async => await _store.read(_pinKey) != null;

  static bool isValidPin(String pin) => RegExp(r'^\d{4,12}$').hasMatch(pin);

  Future<List<int>> _hash(String pin, List<int> salt) async {
    final key = await Argon2id(
      memory: kdf.memoryKiB,
      parallelism: 1,
      iterations: kdf.iterations,
      hashLength: 32,
    ).deriveKeyFromPassword(password: pin, nonce: salt);
    return key.extractBytes();
  }

  Future<void> setPin(String pin) async {
    if (!isValidPin(pin)) {
      throw ArgumentError('PIN must be 4 to 12 digits.');
    }
    final r = Random.secure();
    final salt = List.generate(16, (_) => r.nextInt(256));
    final h = await _hash(pin, salt);
    await _store.write(_pinKey, '${base64.encode(salt)}:${base64.encode(h)}');
    await _store.delete(_failKey);
  }

  Future<void> clear() async {
    await _store.delete(_pinKey);
    await _store.delete(_failKey);
  }

  (int, DateTime?) _readFails(String? raw) {
    if (raw == null) return (0, null);
    final p = raw.split('|');
    final until = p.length > 1 ? int.tryParse(p[1]) : null;
    return (
      int.tryParse(p[0]) ?? 0,
      until == null ? null : DateTime.fromMillisecondsSinceEpoch(until),
    );
  }

  Future<PinResult> verify(String pin) async {
    final stored = await _store.read(_pinKey);
    if (stored == null) return const PinOk();
    final (fails, until) = _readFails(await _store.read(_failKey));
    if (until != null && until.isAfter(_now())) return PinLockedOut(until);
    final parts = stored.split(':');
    final salt = base64.decode(parts[0]);
    final want = base64.decode(parts[1]);
    final got = await _hash(pin, salt);
    var diff = want.length ^ got.length;
    for (var i = 0; i < want.length && i < got.length; i++) {
      diff |= want[i] ^ got[i]; // constant-time compare
    }
    if (diff == 0) {
      await _store.delete(_failKey);
      return const PinOk();
    }
    final n = fails + 1;
    DateTime? lockUntil;
    if (n >= freeAttempts) {
      final secs = min(3600, 30 * pow(2, n - freeAttempts).toInt());
      lockUntil = _now().add(Duration(seconds: secs));
    }
    await _store.write(
      _failKey,
      '$n|${lockUntil?.millisecondsSinceEpoch ?? ''}',
    );
    return lockUntil != null
        ? PinLockedOut(lockUntil)
        : PinWrong(freeAttempts - n);
  }
}
