import 'package:cryptography/cryptography.dart';

import '../app_info.dart';

/// Semantic version with pre-release ordering (1.0.0-beta.1 < 1.0.0).
class SemVer implements Comparable<SemVer> {
  const SemVer(this.major, this.minor, this.patch, [this.pre = const []]);

  final int major, minor, patch;
  final List<String> pre;

  static final _re = RegExp(
    r'^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$',
  );

  static SemVer? tryParse(String s) {
    final m = _re.firstMatch(s.trim());
    if (m == null) return null;
    return SemVer(
      int.parse(m[1]!),
      int.parse(m[2]!),
      int.parse(m[3]!),
      m[4] == null ? const [] : m[4]!.split('.'),
    );
  }

  @override
  int compareTo(SemVer o) {
    for (final (a, b) in [
      (major, o.major),
      (minor, o.minor),
      (patch, o.patch),
    ]) {
      if (a != b) return a.compareTo(b);
    }
    if (pre.isEmpty || o.pre.isEmpty) {
      return pre.isEmpty == o.pre.isEmpty ? 0 : (pre.isEmpty ? 1 : -1);
    }
    for (var i = 0; i < pre.length && i < o.pre.length; i++) {
      final a = pre[i], b = o.pre[i];
      final an = int.tryParse(a), bn = int.tryParse(b);
      final c = an != null && bn != null
          ? an.compareTo(bn)
          : an != null
          ? -1
          : bn != null
          ? 1
          : a.compareTo(b);
      if (c != 0) return c;
    }
    return pre.length.compareTo(o.pre.length);
  }

  @override
  String toString() =>
      '$major.$minor.$patch${pre.isEmpty ? '' : '-${pre.join('.')}'}';
}

class ReleaseAsset {
  const ReleaseAsset(this.name, this.url, this.size);
  final String name;
  final Uri url;
  final int size;
}

class ReleaseInfo {
  const ReleaseInfo(this.version, this.assets, this.notes);
  final SemVer version;
  final List<ReleaseAsset> assets;
  final String notes;

  ReleaseAsset? asset(String name) {
    for (final a in assets) {
      if (a.name == name) return a;
    }
    return null;
  }

  /// The portable bundle for [platform], or null (Android: use the APK
  /// through the browser / system installer).
  ReleaseAsset? bundleFor(String platform) {
    final suffix = switch (platform) {
      'windows' => '-windows-x64-portable.zip',
      'linux' => '-linux-x64.tar.gz',
      _ => null,
    };
    if (suffix == null) return null;
    for (final a in assets) {
      if (a.name.startsWith('Samridhi-') && a.name.endsWith(suffix)) return a;
    }
    return null;
  }
}

/// Parses GitHub's list-releases JSON, skipping drafts and unparseable tags.
/// Only downloads from this project's own GitHub release host are accepted.
List<ReleaseInfo> parseReleases(List<dynamic> json) {
  final out = <ReleaseInfo>[];
  for (final r in json) {
    if (r is! Map<String, dynamic> || r['draft'] == true) continue;
    final v = SemVer.tryParse('${r['tag_name']}');
    if (v == null) continue;
    final assets = <ReleaseAsset>[];
    for (final a in (r['assets'] as List? ?? const [])) {
      if (a is! Map<String, dynamic>) continue;
      final url = Uri.tryParse('${a['browser_download_url']}');
      if (url == null || !_trustedDownload(url)) continue;
      assets.add(
        ReleaseAsset('${a['name']}', url, (a['size'] as num?)?.toInt() ?? 0),
      );
    }
    out.add(ReleaseInfo(v, assets, '${r['body'] ?? ''}'));
  }
  return out;
}

bool _trustedDownload(Uri u) =>
    u.scheme == 'https' &&
    u.host == 'github.com' &&
    u.path.startsWith('${Uri.parse(repoUrl).path}/releases/download/');

/// Newest release strictly newer than [current], or null.
ReleaseInfo? newerThan(List<ReleaseInfo> releases, SemVer current) {
  ReleaseInfo? best;
  for (final r in releases) {
    if (r.version.compareTo(current) <= 0) continue;
    if (best == null || r.version.compareTo(best.version) > 0) best = r;
  }
  return best;
}

/// Parses `sha256sum` output: `<64 hex>  <name>` or `<64 hex> *<name>`.
Map<String, String> parseSha256Sums(String text) {
  final out = <String, String>{};
  final re = RegExp(r'^([0-9a-fA-F]{64}) [ *](.+)$');
  for (final line in text.split('\n')) {
    final m = re.firstMatch(line.trimRight());
    if (m != null) out[m[2]!.trim()] = m[1]!.toLowerCase();
  }
  return out;
}

Future<String> sha256Hex(List<int> bytes) async => [
  for (final b in (await Sha256().hash(bytes)).bytes)
    b.toRadixString(16).padLeft(2, '0'),
].join();
