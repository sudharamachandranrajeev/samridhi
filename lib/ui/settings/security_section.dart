import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../security/lock_controller.dart';
import '../../security/pin_lock.dart';
import '../dialogs.dart';

class SecuritySection extends ConsumerStatefulWidget {
  const SecuritySection({super.key});

  @override
  ConsumerState<SecuritySection> createState() => _SecuritySectionState();
}

class _SecuritySectionState extends ConsumerState<SecuritySection> {
  bool? _hasPin;
  bool _biometric = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final has = await ref.read(pinLockProvider).isSet;
    final bio = await ref.read(databaseProvider).getSetting(biometricSetting);
    if (mounted) {
      setState(() {
        _hasPin = has;
        _biometric = bio == '1';
      });
    }
  }

  Future<String?> _askNewPin() async {
    final a = TextEditingController(), b = TextEditingController();
    String? error;
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Choose a PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: a,
                obscureText: true,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'PIN (4–12 digits)',
                ),
              ),
              TextField(
                controller: b,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Repeat PIN',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!PinLock.isValidPin(a.text)) {
                  setState(() => error = 'Use 4 to 12 digits');
                } else if (a.text != b.text) {
                  setState(() => error = 'PINs do not match');
                } else {
                  Navigator.pop(ctx, a.text);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    a.dispose();
    b.dispose();
    return pin;
  }

  Future<bool> _confirmCurrent() async {
    final pin = await askPassphrase(context, title: 'Enter current PIN');
    if (pin == null) return false;
    final r = await ref.read(pinLockProvider).verify(pin);
    if (!mounted) return false;
    if (r is PinOk) return true;
    showSnack(context, 'Wrong PIN');
    return false;
  }

  Future<void> _setOrChange() async {
    if (_hasPin == true && !await _confirmCurrent()) return;
    final pin = await _askNewPin();
    if (pin == null) return;
    await ref.read(pinLockProvider).setPin(pin);
    await _load();
    if (mounted) showSnack(context, 'PIN saved');
  }

  Future<void> _remove() async {
    if (!await _confirmCurrent()) return;
    await ref.read(pinLockProvider).clear();
    await ref.read(databaseProvider).setSetting(biometricSetting, '0');
    await ref.read(lockProvider.notifier).refresh();
    await _load();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('App lock', style: Theme.of(context).textTheme.titleMedium),
          const Text(
            'A PIN asked at launch and after the app has been in the '
            'background for 30 seconds, independent of your device lock. It '
            'guards the screen; it is not what encrypts your data.',
          ),
          const SizedBox(height: 8),
          if (_hasPin == null)
            const LinearProgressIndicator()
          else ...[
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: _setOrChange,
                  child: Text(_hasPin! ? 'Change PIN' : 'Set a PIN'),
                ),
                if (_hasPin!)
                  OutlinedButton(
                    onPressed: _remove,
                    child: const Text('Remove PIN'),
                  ),
              ],
            ),
            if (_hasPin!)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Also unlock with biometrics'),
                subtitle: const Text(
                  'Windows Hello or fingerprint where available; PIN always '
                  'works.',
                ),
                value: _biometric,
                onChanged: (v) async {
                  await ref
                      .read(databaseProvider)
                      .setSetting(biometricSetting, v ? '1' : '0');
                  setState(() => _biometric = v);
                },
              ),
          ],
        ],
      ),
    ),
  );
}
