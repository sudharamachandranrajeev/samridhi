import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_info.dart';
import 'release.dart';
import 'version_store.dart';

class UpdateException implements Exception {
  const UpdateException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Largest bundle the updater will download.
const maxBundleBytes = 300 * 1024 * 1024;

final releasesApi = Uri.parse(
  'https://api.github.com/repos/${Uri.parse(repoUrl).pathSegments.join('/')}/releases',
);

/// Checks GitHub Releases and installs verified bundles into a [VersionStore].
/// Only ever runs when the user asks (no background polling) and sends no
/// identifying data — just plain GET requests to GitHub.
class Updater {
  Updater({http.Client? client, SemVer? running})
    : _http = client ?? http.Client(),
      running = running ?? SemVer.tryParse(appVersion)!;
  final http.Client _http;
  final SemVer running;

  /// The newest release newer than the running version, or null.
  Future<ReleaseInfo?> check() async {
    final http.Response res;
    try {
      res = await _http
          .get(releasesApi, headers: {'accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 20));
    } on Object catch (e) {
      throw UpdateException('Could not reach GitHub: $e');
    }
    if (res.statusCode != 200) {
      throw UpdateException('GitHub returned HTTP ${res.statusCode}.');
    }
    try {
      return newerThan(
        parseReleases(jsonDecode(utf8.decode(res.bodyBytes)) as List),
        running,
      );
    } on Object {
      throw const UpdateException('Unexpected reply from GitHub.');
    }
  }

  Future<List<int>> _download(Uri url, {required int limit}) async {
    final req = http.Request('GET', url);
    final res = await _http.send(req).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw UpdateException('Download failed: HTTP ${res.statusCode}.');
    }
    final len = res.contentLength;
    if (len != null && len > limit) {
      throw const UpdateException('The download is larger than allowed.');
    }
    final out = <int>[];
    await for (final chunk in res.stream) {
      out.addAll(chunk);
      if (out.length > limit) {
        throw const UpdateException('The download is larger than allowed.');
      }
    }
    return out;
  }

  /// Downloads [release]'s bundle for [platform], checks it against the
  /// release's `SHA256SUMS.txt`, and stages it. Fails closed: a missing
  /// checksum file, a missing entry or a mismatch aborts before anything is
  /// extracted. Does not swap; call [VersionStore.swap] after the user agrees.
  Future<void> downloadAndStage(
    ReleaseInfo release,
    String platform,
    VersionStore store,
  ) async {
    final bundle = release.bundleFor(platform);
    if (bundle == null) {
      throw UpdateException('No downloadable build for $platform.');
    }
    final sumsAsset = release.asset('SHA256SUMS.txt');
    if (sumsAsset == null) {
      throw const UpdateException(
        'This release has no SHA256SUMS.txt, so it cannot be verified.',
      );
    }
    final sums = parseSha256Sums(
      utf8.decode(await _download(sumsAsset.url, limit: 1024 * 1024)),
    );
    final expected = sums[bundle.name];
    if (expected == null) {
      throw UpdateException('SHA256SUMS.txt has no entry for ${bundle.name}.');
    }
    final bytes = await _download(bundle.url, limit: maxBundleBytes);
    if (await sha256Hex(bytes) != expected) {
      throw const UpdateException(
        'Checksum mismatch: the download is damaged or has been tampered '
        'with. Nothing was installed.',
      );
    }
    store.stage(
      bundle: bytes,
      assetName: bundle.name,
      version: release.version.toString(),
    );
  }
}
