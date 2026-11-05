import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_info.dart';
import '../../update/launcher.dart';
import '../../update/release.dart';
import '../../update/updater.dart';
import '../../update/version_store.dart';
import '../dialogs.dart';

/// In-app updates for the Windows/Linux builds: check GitHub Releases,
/// verify SHA256SUMS.txt, stage, swap atomically, keep the previous version
/// and roll back in one tap. Android updates through the APK on the
/// releases page.
class UpdatesSection extends StatefulWidget {
  const UpdatesSection({super.key});

  @override
  State<UpdatesSection> createState() => _UpdatesSectionState();
}

class _UpdatesSectionState extends State<UpdatesSection> {
  VersionStore? _store;
  ReleaseInfo? _available;
  String? _status;
  bool _busy = false;
  bool _needsRestart = false;

  @override
  void initState() {
    super.initState();
    if (updatesSupported) {
      defaultVersionStore().then((s) {
        if (mounted) setState(() => _store = s);
      });
    }
  }

  Future<void> _guard(Future<void> Function() body) async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await body();
    } on Object catch (e) {
      if (mounted) setState(() => _status = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() => _guard(() async {
    final r = await Updater().check();
    setState(() {
      _available = r;
      _status = r == null
          ? 'You are on the latest version ($appVersion).'
          : null;
    });
  });

  Future<void> _install() => _guard(() async {
    final store = _store!;
    final release = _available!;
    await Updater().downloadAndStage(release, Platform.operatingSystem, store);
    if (!mounted) return;
    final ok = await confirmDialog(
      context,
      title: 'Install ${release.version}?',
      body:
          'The download matched its published checksum. Your current version '
          '($appVersion) is kept so you can roll back. Tip: export a backup '
          'first (Backup & restore) in case the new version changes how data '
          'is stored.',
      yes: 'Install',
    );
    if (!ok) {
      store.staging.deleteSync(recursive: true);
      setState(() => _status = 'Cancelled. Nothing was installed.');
      return;
    }
    store.swap();
    setState(() {
      _available = null;
      _needsRestart = true;
      _status = 'Installed ${release.version}. Restart to use it.';
    });
  });

  Future<void> _rollback() async {
    final store = _store!;
    final ok = await confirmDialog(
      context,
      title: 'Roll back to ${store.previousVersion}?',
      body:
          'Restores the previous version you had. Your data stays; if the '
          'newer version changed how data is stored, restore a backup made '
          'before updating.',
      yes: 'Roll back',
    );
    if (!ok) return;
    await _guard(() async {
      store.rollback();
      setState(() {
        _needsRestart = true;
        _status = 'Rolled back to ${store.currentVersion}. Restart to use it.';
      });
    });
  }

  Future<void> _restart() async {
    final ok = await launchStoredVersion(_store!);
    if (ok) {
      exit(0);
    } else if (mounted) {
      setState(
        () => _status =
            'Could not start the stored version. Close and reopen the app.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Updates', style: t.titleMedium),
            Text('Installed: $appVersion'),
            if (store != null && store.currentVersion != null)
              Text('Running update: ${store.currentVersion}'),
            if (store != null && store.previousVersion != null)
              Text('Previous version kept: ${store.previousVersion}'),
            const SizedBox(height: 8),
            if (!updatesSupported)
              OutlinedButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse('$repoUrl/releases'),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open releases page'),
              )
            else
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: _busy || store == null ? null : _check,
                    child: const Text('Check for updates'),
                  ),
                  if (_available != null)
                    FilledButton.tonal(
                      onPressed: _busy ? null : _install,
                      child: Text('Download & install ${_available!.version}'),
                    ),
                  if (store?.previousVersion != null)
                    OutlinedButton(
                      onPressed: _busy ? null : _rollback,
                      child: const Text('Roll back'),
                    ),
                  if (_needsRestart)
                    FilledButton(
                      onPressed: _restart,
                      child: const Text('Restart now'),
                    ),
                ],
              ),
            if (_busy) const LinearProgressIndicator(),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_status!),
              ),
            const SizedBox(height: 4),
            Text(
              'Only checks when you press the button. Downloads come from this '
              "project's GitHub releases and are verified against "
              'SHA256SUMS.txt before anything is installed.',
              style: t.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
