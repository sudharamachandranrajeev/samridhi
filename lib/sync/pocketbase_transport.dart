import 'dart:convert';

import 'package:pocketbase/pocketbase.dart';

import 'sync_service.dart';

/// [SyncTransport] over a self-hosted PocketBase server (see `server/`).
/// Uses Samridhi's own collection `sam_changes`; never touches Artha's.
class PocketBaseTransport implements SyncTransport {
  PocketBaseTransport._(this._pb, this._device);
  final PocketBase _pb;
  final String _device;

  /// Signs in an existing account. [device] is a random 32-hex-char id for
  /// this installation.
  static Future<PocketBaseTransport> signIn({
    required String serverUrl,
    required String email,
    required String password,
    required String device,
  }) async {
    if (!isAllowedServerUrl(serverUrl)) {
      throw ArgumentError('Use https:// for servers outside your own network.');
    }
    final pb = PocketBase(serverUrl.trim());
    await pb.collection('users').authWithPassword(email, password);
    return PocketBaseTransport._(pb, device);
  }

  /// Creates an account (needs the server's invite code), then signs in.
  static Future<PocketBaseTransport> signUp({
    required String serverUrl,
    required String email,
    required String password,
    required String invite,
    required String device,
  }) async {
    if (!isAllowedServerUrl(serverUrl)) {
      throw ArgumentError('Use https:// for servers outside your own network.');
    }
    final pb = PocketBase(serverUrl.trim());
    await pb
        .collection('users')
        .create(
          body: {
            'email': email,
            'password': password,
            'passwordConfirm': password,
            'invite': invite,
          },
        );
    return signIn(
      serverUrl: serverUrl,
      email: email,
      password: password,
      device: device,
    );
  }

  @override
  Future<RemoteHead?> latest() async {
    final page = await _pb
        .collection('sam_changes')
        .getList(page: 1, perPage: 1, sort: '-seq');
    if (page.items.isEmpty) return null;
    final r = page.items.first;
    return RemoteHead(r.getIntValue('seq'), r.getStringValue('payload'));
  }

  @override
  Future<void> push({required int seq, required String payload}) async {
    try {
      await _pb
          .collection('sam_changes')
          .create(
            body: {
              'owner': _pb.authStore.record!.id,
              'device': _device,
              'seq': seq,
              'payload': payload,
            },
          );
    } on ClientException catch (e) {
      // The unique (owner, seq) index rejects a second writer at this seq.
      if (e.statusCode == 400 &&
          jsonEncode(e.response).contains('validation_not_unique')) {
        throw const SyncConflict(
          'Another device pushed first. Pull, then push again.',
        );
      }
      rethrow;
    }
  }
}
