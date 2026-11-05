import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../providers.dart';
import 'pin_lock.dart';

final pinLockProvider = Provider<PinLock>(
  (ref) => PinLock(const KeychainStore()),
);

enum AppLockState { checking, locked, unlocked }

/// How long the app may sit in the background before it locks again.
const relockAfter = Duration(seconds: 30);

const biometricSetting = 'lock.biometric';

class LockController extends Notifier<AppLockState> {
  @override
  AppLockState build() {
    _init();
    return AppLockState.checking;
  }

  Future<void> _init() async {
    bool set;
    try {
      set = await ref.read(pinLockProvider).isSet;
    } on Object {
      // The database key lives in the same keychain, so the app could not
      // have started if it were really unavailable; do not trap the user.
      set = false;
    }
    state = set ? AppLockState.locked : AppLockState.unlocked;
  }

  /// Re-reads whether a PIN exists (after set/remove in Settings).
  Future<void> refresh() async {
    final set = await ref.read(pinLockProvider).isSet;
    if (!set) state = AppLockState.unlocked;
  }

  Future<void> lockIfPinSet() async {
    if (state == AppLockState.unlocked &&
        await ref.read(pinLockProvider).isSet) {
      state = AppLockState.locked;
    }
  }

  void unlock() => state = AppLockState.unlocked;

  /// Offers OS biometrics (Windows Hello / Android) if the user enabled it.
  /// Returns true and unlocks on success; any failure just falls back to PIN.
  Future<bool> tryBiometric() async {
    try {
      final on = await ref.read(databaseProvider).getSetting(biometricSetting);
      if (on != '1') return false;
      final auth = LocalAuthentication();
      if (!await auth.isDeviceSupported()) return false;
      final ok = await auth.authenticate(
        localizedReason: 'Unlock Samridhi',
        biometricOnly: true,
      );
      if (ok) unlock();
      return ok;
    } on Object {
      return false;
    }
  }
}

final lockProvider = NotifierProvider<LockController, AppLockState>(
  LockController.new,
);
