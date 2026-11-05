import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:samridhi/update/release.dart';
import 'package:samridhi/update/updater.dart';
import 'package:samridhi/update/version_store.dart';

SemVer v(String s) => SemVer.tryParse(s)!;

List<int> zipOf(Map<String, List<int>> files) {
  final a = Archive();
  files.forEach((n, b) => a.addFile(ArchiveFile.bytes(n, b)));
  return ZipEncoder().encode(a);
}

const base = 'https://github.com/sudharamachandranrajeev/samridhi';

Map<String, dynamic> releaseJson(
  String tag, {
  bool draft = false,
  List<Map<String, dynamic>>? assets,
}) => {
  'tag_name': tag,
  'draft': draft,
  'body': 'notes',
  'assets':
      assets ??
      [
        {
          'name': 'Samridhi-${tag.substring(1)}-windows-x64-portable.zip',
          'browser_download_url':
              '$base/releases/download/$tag/Samridhi-${tag.substring(1)}-windows-x64-portable.zip',
          'size': 10,
        },
        {
          'name': 'SHA256SUMS.txt',
          'browser_download_url': '$base/releases/download/$tag/SHA256SUMS.txt',
          'size': 10,
        },
      ],
};

void main() {
  group('SemVer', () {
    test('ordering incl. pre-releases', () {
      final order = [
        '0.1.0-alpha.1',
        '0.1.0-alpha.2',
        '0.1.0-alpha.10',
        '0.1.0-beta.1',
        '0.1.0',
        '0.1.1',
        '0.2.0',
        '1.0.0',
      ];
      for (var i = 0; i + 1 < order.length; i++) {
        expect(
          v(order[i]).compareTo(v(order[i + 1])),
          lessThan(0),
          reason: order[i],
        );
      }
      expect(v('v1.2.3').compareTo(v('1.2.3+7')), 0);
      expect(SemVer.tryParse('nonsense'), isNull);
    });
  });

  group('releases', () {
    test('newerThan picks the newest strictly newer, skips drafts', () {
      final rs = parseReleases([
        releaseJson('v0.1.0-alpha.1'),
        releaseJson('v0.2.0'),
        releaseJson('v0.3.0', draft: true),
        releaseJson('v0.1.5'),
        {'tag_name': 'weekly-build'},
      ]);
      expect(newerThan(rs, v('0.1.0-alpha.1'))!.version.toString(), '0.2.0');
      expect(newerThan(rs, v('0.2.0')), isNull);
    });

    test('assets from other hosts or repos are ignored', () {
      final rs = parseReleases([
        releaseJson(
          'v0.2.0',
          assets: [
            {
              'name': 'Samridhi-0.2.0-windows-x64-portable.zip',
              'browser_download_url': 'https://evil.example/x.zip',
              'size': 1,
            },
            {
              'name': 'Samridhi-0.2.0-linux-x64.tar.gz',
              'browser_download_url':
                  'https://github.com/someone/else/releases/download/v1/x.tgz',
              'size': 1,
            },
            {
              'name': 'SHA256SUMS.txt',
              'browser_download_url': 'http://github.com/x',
              'size': 1,
            },
          ],
        ),
      ]);
      expect(rs.single.assets, isEmpty);
    });

    test('bundleFor per platform; none for android', () {
      final r = parseReleases([releaseJson('v0.2.0')]).single;
      expect(r.bundleFor('windows')!.name, contains('windows-x64-portable'));
      expect(r.bundleFor('linux'), isNull);
      expect(r.bundleFor('android'), isNull);
    });

    test('parseSha256Sums handles both separators', () {
      final h = 'a' * 64, g = 'B' * 64;
      final m = parseSha256Sums('$h  one.zip\n$g *two.zip\njunk\n');
      expect(m, {'one.zip': h, 'two.zip': 'b' * 64});
    });
  });

  group('Updater', () {
    final bundle = zipOf({'samridhi.exe': utf8.encode('v2 binary')});
    const name = 'Samridhi-0.2.0-windows-x64-portable.zip';
    late Directory tmp;
    late VersionStore store;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('samridhi-upd');
      store = VersionStore(tmp);
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    Updater updater({String? sums, List<int>? payload, bool omitSums = false}) {
      return Updater(
        running: v('0.1.0'),
        client: MockClient.streaming((req, _) async {
          List<int> body;
          if (req.url.path.endsWith('SHA256SUMS.txt')) {
            if (omitSums) {
              return http.StreamedResponse(const Stream.empty(), 404);
            }
            body = utf8.encode(sums ?? '');
          } else {
            body = payload ?? bundle;
          }
          return http.StreamedResponse(Stream.value(body), 200);
        }),
      );
    }

    Future<ReleaseInfo> rel() async =>
        parseReleases([releaseJson('v0.2.0')]).single;

    test('check() finds a newer release', () async {
      final u = Updater(
        running: v('0.1.0'),
        client: MockClient(
          (_) async => http.Response(jsonEncode([releaseJson('v0.2.0')]), 200),
        ),
      );
      expect((await u.check())!.version.toString(), '0.2.0');
    });

    test('verified download is staged', () async {
      final sums = '${await sha256Hex(bundle)}  $name\n';
      await updater(sums: sums).downloadAndStage(await rel(), 'windows', store);
      expect(store.stagedVersion, '0.2.0');
      expect(
        File(p.join(store.staging.path, 'samridhi.exe')).existsSync(),
        isTrue,
      );
    });

    test('checksum mismatch installs nothing', () async {
      final sums = '${'0' * 64}  $name\n';
      await expectLater(
        updater(sums: sums).downloadAndStage(await rel(), 'windows', store),
        throwsA(
          isA<UpdateException>().having(
            (e) => e.message,
            'm',
            contains('Checksum'),
          ),
        ),
      );
      expect(store.staging.existsSync(), isFalse);
    });

    test('missing SHA256SUMS entry or file fails closed', () async {
      await expectLater(
        updater(sums: '${'1' * 64}  other.zip\n')
            .downloadAndStage(await rel(), 'windows', store),
        throwsA(isA<UpdateException>()),
      );
      await expectLater(
        updater(omitSums: true).downloadAndStage(await rel(), 'windows', store),
        throwsA(isA<UpdateException>()),
      );
      expect(store.staging.existsSync(), isFalse);
    });
  });

  group('VersionStore', () {
    late Directory tmp;
    late VersionStore store;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('samridhi-vs');
      store = VersionStore(tmp);
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    void install(String version, String marker) {
      store.stage(
        bundle: zipOf({'app.bin': utf8.encode(marker)}),
        assetName: 'x.zip',
        version: version,
      );
      store.swap();
    }

    String content(Directory d) =>
        File(p.join(d.path, 'app.bin')).readAsStringSync();

    test('swap keeps N-1; second update drops N-2', () {
      install('1.0.0', 'one');
      expect(store.currentVersion, '1.0.0');
      expect(store.previousVersion, isNull);
      install('1.1.0', 'two');
      expect(content(store.current), 'two');
      expect(content(store.previous), 'one');
      install('1.2.0', 'three');
      expect(store.previousVersion, '1.1.0');
      expect(content(store.previous), 'two');
      expect(store.staging.existsSync(), isFalse);
    });

    test('rollback restores the previous version in one step', () {
      install('1.0.0', 'one');
      install('1.1.0', 'two');
      store.rollback();
      expect(store.currentVersion, '1.0.0');
      expect(content(store.current), 'one');
      expect(store.previous.existsSync(), isFalse);
      expect(Directory(p.join(tmp.path, 'failed')).existsSync(), isFalse);
      expect(() => store.rollback(), throwsA(isA<UpdateStoreException>()));
    });

    test('swap with nothing staged is refused and changes nothing', () {
      install('1.0.0', 'one');
      expect(() => store.swap(), throwsA(isA<UpdateStoreException>()));
      expect(content(store.current), 'one');
    });

    test('unhealthy new version auto-rolls back after repeated launches', () {
      install('1.0.0', 'one');
      store.markHealthy();
      install('1.1.0', 'two');
      expect(store.isPendingHealth, isTrue);
      expect(store.recordLaunch(), 1);
      expect(store.shouldAutoRollback, isFalse);
      expect(store.recordLaunch(), 2);
      expect(store.shouldAutoRollback, isTrue);
      store.rollback();
      expect(store.currentVersion, '1.0.0');
      expect(store.isPendingHealth, isFalse);
    });

    test('a version that confirms health is never rolled back', () {
      install('1.0.0', 'one');
      install('1.1.0', 'two');
      store.recordLaunch();
      store.markHealthy();
      store.recordLaunch();
      store.recordLaunch();
      expect(store.shouldAutoRollback, isFalse);
    });

    test('zip-slip entries are rejected and leave no staging', () {
      expect(
        () => store.stage(
          bundle: zipOf({
            '../evil.txt': [1],
          }),
          assetName: 'x.zip',
          version: '9.9.9',
        ),
        throwsA(isA<UpdateStoreException>()),
      );
      expect(store.staging.existsSync(), isFalse);
      expect(File(p.join(tmp.parent.path, 'evil.txt')).existsSync(), isFalse);
    });

    test('tar.gz bundles drop their top-level folder', () {
      final a = Archive()
        ..addFile(ArchiveFile.bytes('samridhi-1.0.0-linux-x64/samridhi', [7]))
        ..addFile(ArchiveFile.bytes('samridhi-1.0.0-linux-x64/lib/a.so', [8]));
      final tgz = GZipEncoder().encode(TarEncoder().encode(a));
      store.stage(bundle: tgz, assetName: 'x.tar.gz', version: '1.0.0');
      expect(File(p.join(store.staging.path, 'samridhi')).existsSync(), isTrue);
      expect(
        File(p.join(store.staging.path, 'lib', 'a.so')).existsSync(),
        isTrue,
      );
    });

    test('unknown bundle type is rejected', () {
      expect(
        () => store.stage(bundle: [1], assetName: 'x.rar', version: '1'),
        throwsA(isA<UpdateStoreException>()),
      );
    });
  });
}
