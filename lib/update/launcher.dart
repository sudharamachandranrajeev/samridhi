import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../app_info.dart';
import 'release.dart';
import 'version_store.dart';

bool get updatesSupported => Platform.isWindows || Platform.isLinux;

Future<VersionStore> defaultVersionStore() async => VersionStore(
  Directory(p.join((await getApplicationSupportDirectory()).path, 'updates')),
);

/// True when this process is the copy under the update store (as opposed to
/// the originally installed one).
bool runningFromStore(VersionStore store) =>
    p.isWithin(store.root.path, Platform.resolvedExecutable);

String _exeIn(Directory d) =>
    p.join(d.path, Platform.isWindows ? 'samridhi.exe' : 'samridhi');

/// Starts the current stored version as a separate process. Returns false if
/// there is nothing runnable.
Future<bool> launchStoredVersion(VersionStore store) async {
  final exe = _exeIn(store.current);
  if (!File(exe).existsSync()) return false;
  await Process.start(
    exe,
    const [],
    workingDirectory: store.current.path,
    mode: ProcessStartMode.detached,
  );
  return true;
}

/// Called first thing at startup by the installed copy. If an updated version
/// has been staged and swapped in, hands over to it (the caller then exits).
/// An updated version that never confirmed it starts is rolled back first.
/// Any problem means "just run this copy" — an update can never stop the
/// installed app from starting.
Future<bool> relaunchIfUpdated(VersionStore store) async {
  if (!updatesSupported) return false;
  try {
    if (runningFromStore(store)) return false;
    if (store.shouldAutoRollback) store.rollback();
    final cur = SemVer.tryParse(store.currentVersion ?? '');
    final me = SemVer.tryParse(appVersion);
    if (cur == null || me == null || cur.compareTo(me) <= 0) return false;
    if (store.isPendingHealth) store.recordLaunch();
    return await launchStoredVersion(store);
  } on Object {
    return false;
  }
}
