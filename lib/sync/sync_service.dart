import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../data/database.dart';
import 'snapshot.dart';
import 'vault_crypto.dart';

/// The sync server stores only encrypted snapshots (see vault_crypto.dart);
/// this is the narrow surface the service needs from it.
abstract class SyncTransport {
  /// Newest snapshot on the server, or null if none yet.
  Future<RemoteHead?> latest();

  /// Appends snapshot number [seq]. Must throw [SyncConflict] if that number
  /// is already taken (another device pushed first).
  Future<void> push({required int seq, required String payload});
}

class RemoteHead {
  const RemoteHead(this.seq, this.payload);
  final int seq;

  /// base64 of the sealed envelope.
  final String payload;
}

/// Pushing or pulling would silently lose someone's changes.
class SyncConflict implements Exception {
  const SyncConflict(this.message);
  final String message;
  @override
  String toString() => message;
}

const _seqKey = 'sync.seq';
const _hashKey = 'sync.hash';

/// Optimistic-concurrency snapshot sync.
///
/// Each device remembers the server sequence number it last synced at
/// (`sync.seq`) and a hash of its data at that moment (`sync.hash`):
/// * push is refused if the server has moved on (pull first);
/// * pull is refused if this device has unpushed local changes.
/// Either refusal can be overridden explicitly with `force`, after the user
/// has chosen which side wins. Nothing is ever merged silently.
class SyncService {
  SyncService(this.db, this.transport, {this.kdf = KdfParams.standard});
  final AppDatabase db;
  final SyncTransport transport;
  final KdfParams kdf;

  Future<int> _localSeq() async =>
      int.tryParse(await db.getSetting(_seqKey) ?? '') ?? 0;

  Future<String> _hash(String snapshot) async =>
      base64.encode((await Sha256().hash(utf8.encode(snapshot))).bytes);

  /// True if local data differs from what was last synced.
  Future<bool> hasLocalChanges() async {
    final last = await db.getSetting(_hashKey);
    final now = await _hash(await exportSnapshot(db));
    // Never synced: dirty only if there is something to lose.
    if (last == null) return (await _localSeq()) == 0 && !await _isEmpty();
    return last != now;
  }

  Future<bool> _isEmpty() async {
    final s = jsonDecode(await exportSnapshot(db)) as Map<String, dynamic>;
    return [
      'accounts',
      'holdings',
      'goals',
      'riskAnswers',
    ].every((k) => (s[k] as List).isEmpty);
  }

  Future<void> _markSynced(int seq, String snapshot) async {
    await db.setSetting(_seqKey, '$seq');
    await db.setSetting(_hashKey, await _hash(snapshot));
  }

  /// Encrypts local data and appends it to the server. Returns the new seq.
  Future<int> push(String passphrase, {bool force = false}) async {
    final head = await transport.latest();
    final base = await _localSeq();
    if (head != null && head.seq > base && !force) {
      throw const SyncConflict(
        'The server has newer data from another device. Pull first, or '
        'choose to overwrite the server copy.',
      );
    }
    final next = (head?.seq ?? base) + 1;
    final snapshot = await exportSnapshot(db);
    final sealed = await sealString(snapshot, passphrase, params: kdf);
    await transport.push(seq: next, payload: base64.encode(sealed));
    await _markSynced(next, snapshot);
    return next;
  }

  /// Replaces local data with the newest server snapshot. Returns the seq
  /// pulled, or null if the server is empty. Wrong passphrase / corrupt data
  /// throws [WrongPassphraseOrCorrupt] before anything local is touched.
  Future<int?> pull(String passphrase, {bool force = false}) async {
    final head = await transport.latest();
    if (head == null) return null;
    if (!force && await hasLocalChanges()) {
      throw const SyncConflict(
        'This device has changes that were never pushed. Push them, or '
        'choose to replace them with the server copy.',
      );
    }
    final snapshot = await openString(base64.decode(head.payload), passphrase);
    await importSnapshot(db, snapshot);
    // Hash the re-exported data (not the received text) so the comparison is
    // like-for-like with later hasLocalChanges() calls.
    await _markSynced(head.seq, await exportSnapshot(db));
    return head.seq;
  }
}

/// Plain http is allowed only for networks that are not the public internet:
/// loopback, private ranges, Tailscale CGNAT and `.local`. Anything else must
/// be https, so credentials and ciphertext never travel in the clear.
bool isAllowedServerUrl(String url) {
  final u = Uri.tryParse(url.trim());
  if (u == null || u.host.isEmpty) return false;
  if (u.scheme == 'https') return true;
  if (u.scheme != 'http') return false;
  final h = u.host.toLowerCase();
  if (h == 'localhost' || h == '::1' || h.endsWith('.local')) return true;
  final p = h.split('.');
  if (p.length != 4) return false;
  final n = p.map(int.tryParse).toList();
  if (n.any((x) => x == null || x < 0 || x > 255)) return false;
  final a = n[0]!, b = n[1]!;
  return a == 127 ||
      a == 10 ||
      (a == 192 && b == 168) ||
      (a == 172 && b >= 16 && b <= 31) ||
      (a == 100 && b >= 64 && b <= 127);
}
