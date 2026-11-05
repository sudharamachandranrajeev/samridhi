import 'dart:io';

import 'package:flutter/services.dart';

/// Setting key: block screenshots/recording (Android FLAG_SECURE). Off by
/// default so it never interferes with the user's own screenshots or the
/// issue-report capture unless deliberately enabled.
const blockCaptureSetting = 'security.blockCapture';

const _channel = MethodChannel('dev.samridhi/device');

/// Android-only device hardening hooks; everywhere else these are no-ops.
bool get deviceSecuritySupported => Platform.isAndroid;

Future<void> applyCaptureBlock(bool on) async {
  if (!deviceSecuritySupported) return;
  try {
    await _channel.invokeMethod<void>('setSecure', on);
  } on PlatformException {
    // Hardening is best-effort; failing to apply it must not break the app.
  }
}

/// Reasons the device looks rooted (empty = none found, or not checkable).
/// A best-effort hint that is easy to defeat; it only informs, never blocks.
Future<List<String>> rootHints() async {
  if (!deviceSecuritySupported) return const [];
  try {
    final hints = await _channel.invokeListMethod<String>('rootHints');
    return hints ?? const [];
  } on PlatformException {
    return const [];
  }
}
