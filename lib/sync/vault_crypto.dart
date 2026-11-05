import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Passphrase-based authenticated encryption used for both backup files and
/// sync snapshots: Argon2id -> 256-bit key -> XChaCha20-Poly1305.
///
/// Envelope layout (all self-describing so parameters can be raised later):
/// `magic(5) | memoryKiB(u32 BE) | iterations(u8) | salt(16) | nonce(24) |
/// ciphertext | mac(16)`.
class KdfParams {
  const KdfParams({this.memoryKiB = 19456, this.iterations = 2});
  final int memoryKiB;
  final int iterations;

  /// OWASP-recommended Argon2id minimum (19 MiB, 2 passes, 1 lane).
  static const standard = KdfParams();

  /// Cheap parameters for unit tests only.
  static const fastForTests = KdfParams(memoryKiB: 64, iterations: 1);
}

class WrongPassphraseOrCorrupt implements Exception {
  const WrongPassphraseOrCorrupt([this.detail = '']);
  final String detail;
  @override
  String toString() =>
      'Wrong passphrase, or the data is damaged${detail.isEmpty ? '' : ' ($detail)'}.';
}

const _magic = [0x53, 0x4d, 0x52, 0x44, 0x31]; // "SMRD1"
const _saltLen = 16, _nonceLen = 24, _macLen = 16;
const _headerLen = 5 + 4 + 1 + _saltLen;
const _maxMemoryKiB = 262144, _maxIterations = 10;

final _aead = Xchacha20.poly1305Aead();

Future<SecretKey> _derive(String passphrase, List<int> salt, KdfParams p) =>
    Argon2id(
      memory: p.memoryKiB,
      parallelism: 1,
      iterations: p.iterations,
      hashLength: 32,
    ).deriveKeyFromPassword(password: passphrase, nonce: salt);

List<int> _randomBytes(int n) {
  final r = Random.secure();
  return List.generate(n, (_) => r.nextInt(256));
}

/// Encrypts [plain] under [passphrase].
Future<Uint8List> seal(
  List<int> plain,
  String passphrase, {
  KdfParams params = KdfParams.standard,
}) async {
  final salt = _randomBytes(_saltLen);
  final key = await _derive(passphrase, salt, params);
  final header = BytesBuilder()
    ..add(_magic)
    ..add((ByteData(4)..setUint32(0, params.memoryKiB)).buffer.asUint8List())
    ..addByte(params.iterations)
    ..add(salt);
  final headerBytes = header.toBytes();
  // The header is authenticated as associated data.
  final box = await _aead.encrypt(
    plain,
    secretKey: key,
    nonce: _randomBytes(_nonceLen),
    aad: headerBytes,
  );
  return Uint8List.fromList([...headerBytes, ...box.concatenation()]);
}

/// Decrypts an envelope produced by [seal]. Throws
/// [WrongPassphraseOrCorrupt] on a bad passphrase, tampering or bad format.
Future<Uint8List> open(List<int> envelope, String passphrase) async {
  if (envelope.length < _headerLen + _nonceLen + _macLen) {
    throw const WrongPassphraseOrCorrupt('too short');
  }
  for (var i = 0; i < _magic.length; i++) {
    if (envelope[i] != _magic[i]) {
      throw const WrongPassphraseOrCorrupt('not a Samridhi file');
    }
  }
  final bytes = Uint8List.fromList(envelope);
  final mem = ByteData.sublistView(bytes).getUint32(5);
  final iters = bytes[9];
  if (mem < 8 || mem > _maxMemoryKiB || iters < 1 || iters > _maxIterations) {
    throw const WrongPassphraseOrCorrupt('unsupported parameters');
  }
  final headerBytes = bytes.sublist(0, _headerLen);
  final salt = bytes.sublist(10, _headerLen);
  final key = await _derive(
    passphrase,
    salt,
    KdfParams(memoryKiB: mem, iterations: iters),
  );
  try {
    final box = SecretBox.fromConcatenation(
      bytes.sublist(_headerLen),
      nonceLength: _nonceLen,
      macLength: _macLen,
    );
    return Uint8List.fromList(
      await _aead.decrypt(box, secretKey: key, aad: headerBytes),
    );
  } on SecretBoxAuthenticationError {
    throw const WrongPassphraseOrCorrupt();
  }
}

Future<Uint8List> sealString(
  String s,
  String passphrase, {
  KdfParams params = KdfParams.standard,
}) => seal(utf8.encode(s), passphrase, params: params);

Future<String> openString(List<int> envelope, String passphrase) async =>
    utf8.decode(await open(envelope, passphrase));
