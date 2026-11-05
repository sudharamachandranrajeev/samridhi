import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

/// Optional Windows integration with Sentinel (the Brahma security service).
/// Samridhi never needs it: when it is absent, unreachable or incompatible the
/// result is a plain status and nothing else changes.
///
/// Wire format (from Sentinel's `sentinel-core/src/protocol.rs`): each frame
/// is a little-endian u32 byte length followed by that many bytes of UTF-8
/// JSON; one request gets one response. We send `{"type":"hello","protocol":1}`
/// and expect `{"type":"hello","protocol":N,"service_version":"x"}`.
/// Sentinel's protocol does not (yet) expose Defender/tamper health, so the
/// badge says only "running" — it must not claim more than that.
const sentinelPipe = r'\\.\pipe\sentinel';
const sentinelProtocol = 1;
const maxFrame = 1024 * 1024;

sealed class SentinelStatus {
  const SentinelStatus();
}

/// Not Windows, or Sentinel is not installed/running.
class SentinelAbsent extends SentinelStatus {
  const SentinelAbsent();
}

class SentinelRunning extends SentinelStatus {
  const SentinelRunning(this.version);
  final String version;
}

/// The service is there but its pipe is limited to administrators (its
/// default), so an ordinary Samridhi cannot ask it anything.
class SentinelRestricted extends SentinelStatus {
  const SentinelRestricted();
}

class SentinelUnusable extends SentinelStatus {
  const SentinelUnusable(this.reason);
  final String reason;
}

Uint8List encodeFrame(Map<String, Object?> message) {
  final body = utf8.encode(jsonEncode(message));
  if (body.length > maxFrame) throw const FormatException('frame too large');
  final out = ByteData(4 + body.length)
    ..setUint32(0, body.length, Endian.little);
  final bytes = out.buffer.asUint8List()..setRange(4, 4 + body.length, body);
  return bytes;
}

/// Length of the JSON body announced by a frame header; throws on a header
/// that claims more than [maxFrame].
int frameLength(List<int> header) {
  if (header.length < 4) throw const FormatException('short header');
  final n = ByteData.sublistView(Uint8List.fromList(header.sublist(0, 4)))
      .getUint32(0, Endian.little);
  if (n > maxFrame) throw const FormatException('frame too large');
  return n;
}

/// Interprets Sentinel's reply to our hello.
SentinelStatus interpretHello(Map<String, dynamic> reply) {
  if (reply['type'] != 'hello') {
    return const SentinelUnusable('unexpected reply');
  }
  if (reply['protocol'] != sentinelProtocol) {
    return SentinelUnusable('protocol ${reply['protocol']}');
  }
  return SentinelRunning('${reply['service_version'] ?? 'unknown'}');
}

Future<SentinelStatus> querySentinel({
  String pipe = sentinelPipe,
  Duration timeout = const Duration(seconds: 2),
}) async {
  if (!Platform.isWindows) return const SentinelAbsent();
  try {
    return await Isolate.run(() => _queryBlocking(pipe)).timeout(timeout);
  } on Object {
    return const SentinelUnusable('no answer');
  }
}

SentinelStatus _queryBlocking(String pipe) {
  if (!File(pipe).existsSync()) return const SentinelAbsent();
  RandomAccessFile f;
  try {
    f = File(pipe).openSync(mode: FileMode.write);
  } on FileSystemException catch (e) {
    // 5 = ERROR_ACCESS_DENIED: the pipe is admin-only.
    if (e.osError?.errorCode == 5) return const SentinelRestricted();
    if (e.osError?.errorCode == 2) return const SentinelAbsent();
    return SentinelUnusable('open failed (${e.osError?.errorCode})');
  }
  try {
    f.writeFromSync(
      encodeFrame({'type': 'hello', 'protocol': sentinelProtocol}),
    );
    f.flushSync();
    final header = f.readSync(4);
    final n = frameLength(header);
    final body = f.readSync(n);
    return interpretHello(
      jsonDecode(utf8.decode(body)) as Map<String, dynamic>,
    );
  } on Object catch (e) {
    return SentinelUnusable('$e');
  } finally {
    f.closeSync();
  }
}
