// ── AppLockGate ───────────────────────────────────────────────────────────────
// Sits above the whole app. While locked it hides the app (still mounted, so no
// state is lost) behind a lock screen and asks the phone for the user's
// fingerprint / PIN. It locks on start and when the app comes back after being
// away for [grace]: the file picker, share sheet and permission screens also
// take the app to the background, and those must not lock it.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:financeapp/shared/services/app_lock.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:flutter/material.dart';

class AppLockGate extends StatefulWidget {
  final Widget child;
  final Duration grace;
  const AppLockGate(
      {super.key, required this.child, this.grace = const Duration(seconds: 30)});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  final _lock = AppLock.instance;
  late bool _locked = _lock.enabled.value;
  DateTime? _leftAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lock.enabled.addListener(_enabledChanged);
    if (_locked) WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void dispose() {
    _lock.enabled.removeListener(_enabledChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _enabledChanged() {
    if (!_lock.enabled.value && _locked) setState(() => _locked = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_lock.busy) return; // the system prompt itself pauses the app
    if (state == AppLifecycleState.paused) {
      _leftAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final left = _leftAt;
      _leftAt = null;
      if (_lock.enabled.value &&
          !_locked &&
          left != null &&
          DateTime.now().difference(left) >= widget.grace) {
        setState(() => _locked = true);
        _unlock();
      }
    }
  }

  Future<void> _unlock() async {
    if (await _lock.unlock() && mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      fit: StackFit.expand,
      children: [
        Offstage(offstage: _locked, child: widget.child),
        if (_locked)
          MaterialApp(
            debugShowCheckedModeBanner: false,
            home: _LockScreen(onUnlock: _unlock),
          ),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  final VoidCallback onUnlock;
  const _LockScreen({required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded, color: Colors.white, size: 44),
                ),
                const SizedBox(height: 24),
                const Text(
                  'FinanceApp is locked',
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: onUnlock,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: const Text('Unlock',
                      style: TextStyle(
                          fontFamily: 'Rubik', fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.myGreen,
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
