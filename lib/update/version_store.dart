import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

class UpdateStoreException implements Exception {
  const UpdateStoreException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Self-contained app versions kept side by side under [root]:
///
///     root/current/    the version to run
///     root/previous/   N-1, kept for rollback
///     root/staging/    a verified download being prepared
///     root/state.json  health bookkeeping for the current version
///
/// Directory renames on one volume are atomic, so a crash leaves either the
/// old or the new layout, never a half-written version. Each version folder
/// carries a `.samridhi-version` file.
class VersionStore {
  VersionStore(this.root);
  final Directory root;

  /// A new version that fails to confirm health after this many launches is
  /// rolled back automatically.
  static const maxUnhealthyLaunches = 2;
  static const _versionFile = '.samridhi-version';

  Directory get current => Directory(p.join(root.path, 'current'));
  Directory get previous => Directory(p.join(root.path, 'previous'));
  Directory get staging => Directory(p.join(root.path, 'staging'));
  File get _state => File(p.join(root.path, 'state.json'));

  String? _versionOf(Directory d) {
    final f = File(p.join(d.path, _versionFile));
    return f.existsSync() ? f.readAsStringSync().trim() : null;
  }

  String? get currentVersion => _versionOf(current);
  String? get previousVersion => _versionOf(previous);
  String? get stagedVersion => _versionOf(staging);

  /// Extracts a verified bundle (.zip or .tar.gz) into a fresh staging
  /// folder. Entries that would land outside it are rejected.
  void stage({
    required List<int> bundle,
    required String assetName,
    required String version,
  }) {
    final Archive archive;
    if (assetName.endsWith('.zip')) {
      archive = ZipDecoder().decodeBytes(bundle);
    } else if (assetName.endsWith('.tar.gz')) {
      archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bundle));
    } else {
      throw UpdateStoreException('Unsupported bundle type: $assetName');
    }
    if (staging.existsSync()) staging.deleteSync(recursive: true);
    staging.createSync(recursive: true);
    try {
      final base = p.canonicalize(staging.path);
      for (final entry in archive) {
        // A tar bundle wraps everything in one top-level folder.
        var rel = entry.name.replaceAll('\\', '/');
        if (assetName.endsWith('.tar.gz')) {
          final slash = rel.indexOf('/');
          if (slash < 0) continue;
          rel = rel.substring(slash + 1);
        }
        if (rel.isEmpty) continue;
        final target = p.canonicalize(p.join(staging.path, rel));
        if (p.isAbsolute(rel) ||
            !(target == base || p.isWithin(base, target)) ||
            entry.isSymbolicLink) {
          throw UpdateStoreException('Unsafe path in update bundle: $rel');
        }
        if (entry.isFile) {
          File(target)
            ..createSync(recursive: true)
            ..writeAsBytesSync(entry.content);
          if (!Platform.isWindows && entry.unixPermissions & 0x40 != 0) {
            Process.runSync('chmod', ['u+x', target]);
          }
        } else {
          Directory(target).createSync(recursive: true);
        }
      }
      File(p.join(staging.path, _versionFile)).writeAsStringSync(version);
    } on Object {
      staging.deleteSync(recursive: true);
      rethrow;
    }
  }

  /// Promotes staging to current and keeps the old current as previous.
  void swap() {
    if (!staging.existsSync() || stagedVersion == null) {
      throw const UpdateStoreException('Nothing is staged.');
    }
    if (previous.existsSync()) previous.deleteSync(recursive: true);
    final hadCurrent = current.existsSync();
    if (hadCurrent) current.renameSync(previous.path);
    try {
      staging.renameSync(current.path);
    } on Object {
      // Put things back exactly as they were.
      if (hadCurrent) previous.renameSync(current.path);
      rethrow;
    }
    _writeState({'pending': currentVersion, 'launches': 0});
  }

  /// Restores the previous version. The abandoned version is discarded.
  void rollback() {
    if (!previous.existsSync()) {
      throw const UpdateStoreException('No previous version to restore.');
    }
    final failed = Directory(p.join(root.path, 'failed'));
    if (failed.existsSync()) failed.deleteSync(recursive: true);
    if (current.existsSync()) current.renameSync(failed.path);
    previous.renameSync(current.path);
    if (failed.existsSync()) failed.deleteSync(recursive: true);
    _writeState({});
  }

  // ---- health check ----

  Map<String, dynamic> _readState() {
    try {
      return jsonDecode(_state.readAsStringSync()) as Map<String, dynamic>;
    } on Object {
      return {};
    }
  }

  void _writeState(Map<String, dynamic> s) {
    root.createSync(recursive: true);
    _state.writeAsStringSync(jsonEncode(s));
  }

  /// True while the current version has not yet confirmed it starts fine.
  bool get isPendingHealth => _readState()['pending'] != null;

  /// Call each time the launcher starts the pending version. Returns the
  /// launch count including this one.
  int recordLaunch() {
    final s = _readState();
    final n = ((s['launches'] as num?)?.toInt() ?? 0) + 1;
    _writeState({...s, 'launches': n});
    return n;
  }

  /// True if the pending version had its chances and never confirmed.
  bool get shouldAutoRollback {
    final s = _readState();
    return s['pending'] != null &&
        ((s['launches'] as num?)?.toInt() ?? 0) >= maxUnhealthyLaunches &&
        previous.existsSync();
  }

  /// Called by the running (updated) app once it has started successfully.
  void markHealthy() => _writeState({});
}
