import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samridhi/data/database.dart';
import 'package:samridhi/security/sentinel.dart';

void main() {
  test('hello frame matches Sentinel wire format', () {
    final f = encodeFrame({'type': 'hello', 'protocol': 1});
    const json = '{"type":"hello","protocol":1}';
    expect(f.sublist(0, 4), [json.length, 0, 0, 0]); // u32 little-endian
    expect(utf8.decode(f.sublist(4)), json);
    expect(frameLength(f.sublist(0, 4)), json.length);
  });

  test('oversized or short headers are refused', () {
    final big = ByteData(4)..setUint32(0, maxFrame + 1, Endian.little);
    expect(() => frameLength(big.buffer.asUint8List()), throwsFormatException);
    expect(() => frameLength([1, 2]), throwsFormatException);
  });

  test('interpretHello', () {
    expect(
      interpretHello({
        'type': 'hello',
        'protocol': 1,
        'service_version': '0.3',
      }),
      isA<SentinelRunning>().having((s) => s.version, 'version', '0.3'),
    );
    expect(
      interpretHello({'type': 'hello', 'protocol': 2}),
      isA<SentinelUnusable>(),
    );
    expect(interpretHello({'type': 'error'}), isA<SentinelUnusable>());
  });

  test('absent pipe degrades gracefully (never throws)', () async {
    final s = await querySentinel(pipe: r'\.\pipe\samridhi-test-no-such-pipe');
    expect(s, isA<SentinelAbsent>());
  });

  test('database integrity check reports ok', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await db.integrityCheck(), 'ok');
  });
}
