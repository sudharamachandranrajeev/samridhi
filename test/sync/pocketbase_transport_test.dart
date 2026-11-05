import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:samridhi/sync/pocketbase_transport.dart';
import 'package:samridhi/sync/sync_service.dart';

http.Response _json(int code, Object body) => http.Response(
  jsonEncode(body),
  code,
  headers: {'content-type': 'application/json'},
);

Future<PocketBaseTransport> _transport(
  http.Response Function(http.Request) onCollection,
  List<http.Request> log,
) {
  final client = MockClient((req) async {
    log.add(req);
    if (req.url.path.contains('auth-with-password')) {
      return _json(200, {
        'token': 't',
        'record': {'id': 'owner1', 'collectionName': 'users'},
      });
    }
    return onCollection(req);
  });
  return PocketBaseTransport.signIn(
    serverUrl: 'https://sync.example.org',
    email: 'a@b.c',
    password: 'pw',
    device: 'dev0',
    httpClientFactory: () => client,
  );
}

void main() {
  test('latest() returns the highest seq, or null when empty', () async {
    final log = <http.Request>[];
    final t = await _transport(
      (_) => _json(200, {
        'page': 1,
        'perPage': 1,
        'totalItems': 1,
        'totalPages': 1,
        'items': [
          {'id': 'r1', 'seq': 7, 'payload': 'blob'},
        ],
      }),
      log,
    );
    final head = await t.latest();
    expect(head!.seq, 7);
    expect(head.payload, 'blob');
    expect(log.last.url.queryParameters['sort'], '-seq');

    final empty = await _transport(
      (_) => _json(200, {
        'page': 1,
        'perPage': 1,
        'totalItems': 0,
        'totalPages': 0,
        'items': [],
      }),
      log,
    );
    expect(await empty.latest(), isNull);
  });

  test('push sends owner/device/seq/payload', () async {
    final log = <http.Request>[];
    final t = await _transport((_) => _json(200, {'id': 'x'}), log);
    await t.push(seq: 3, payload: 'p');
    final body = jsonDecode(log.last.body) as Map<String, dynamic>;
    expect(body, {
      'owner': 'owner1',
      'device': 'dev0',
      'seq': 3,
      'payload': 'p',
    });
  });

  test('unique-index rejection becomes SyncConflict', () async {
    final t = await _transport(
      (_) => _json(400, {
        'status': 400,
        'message': 'Failed to create record.',
        'data': {
          'seq': {'code': 'validation_not_unique', 'message': 'dup'},
        },
      }),
      [],
    );
    expect(t.push(seq: 3, payload: 'p'), throwsA(isA<SyncConflict>()));
  });

  test('other server errors are not disguised as conflicts', () async {
    final t = await _transport(
      (_) => _json(500, {'status': 500, 'message': 'boom', 'data': {}}),
      [],
    );
    expect(t.push(seq: 3, payload: 'p'), throwsA(isNot(isA<SyncConflict>())));
  });

  test('signIn refuses plain http to a public host', () {
    expect(
      PocketBaseTransport.signIn(
        serverUrl: 'http://evil.example.com',
        email: 'a@b.c',
        password: 'pw',
        device: 'd',
      ),
      throwsArgumentError,
    );
  });
}
