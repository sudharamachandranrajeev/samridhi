import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../security/lock_controller.dart';
import '../security/pin_lock.dart';

/// Shows [child] only while unlocked; locks on launch and after the app has
/// been in the background for [relockAfter].
class LockGate extends ConsumerStatefulWidget {
  const LockGate({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate> {
  late final AppLifecycleListener _life;
  DateTime? _hiddenAt;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(
      onHide: () => _hiddenAt = DateTime.now(),
      onShow: () {
        final at = _hiddenAt;
        _hiddenAt = null;
        if (at != null && DateTime.now().difference(at) >= relockAfter) {
          ref.read(lockProvider.notifier).lockIfPinSet();
        }
      },
    );
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => switch (ref.watch(lockProvider)) {
    AppLockState.unlocked => widget.child,
    AppLockState.checking => const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    ),
    AppLockState.locked => const PinScreen(),
  };
}

class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  final _pin = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(lockProvider.notifier).tryBiometric());
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _pin.text.isEmpty) return;
    setState(() => _busy = true);
    final r = await ref.read(pinLockProvider).verify(_pin.text);
    if (!mounted) return;
    switch (r) {
      case PinOk():
        ref.read(lockProvider.notifier).unlock();
      case PinWrong(:final attemptsLeft):
        setState(() {
          _error = 'Wrong PIN. $attemptsLeft tries left before a lockout.';
          _busy = false;
          _pin.clear();
        });
      case PinLockedOut(:final until):
        final secs = until.difference(DateTime.now()).inSeconds + 1;
        setState(() {
          _error = 'Too many tries. Wait ${secs}s.';
          _busy = false;
          _pin.clear();
        });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 12),
              Text(
                'Samridhi is locked',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pin,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'PIN',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: const Text('Unlock'),
              ),
              TextButton(
                onPressed: () => ref.read(lockProvider.notifier).tryBiometric(),
                child: const Text('Use biometrics'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
