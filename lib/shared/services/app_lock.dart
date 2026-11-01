// ── App lock ──────────────────────────────────────────────────────────────────
// Asks for the phone's own fingerprint / face / PIN before the app opens. The
// phone does the checking, so the app stores no secret: only whether the lock
// is on (ProfileManager, device-wide). [Authenticator] is the phone side, swapped
// for a fake in tests, like BillReminders.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:financeapp/shared/networks/local/profile_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

abstract class Authenticator {
  /// The phone has a screen lock or biometrics to ask with.
  Future<bool> isSupported();

  /// True only when the user proved it is them; a cancel or any failure is false.
  Future<bool> authenticate(String reason);
}

class LocalAuthenticator implements Authenticator {
  final _auth = LocalAuthentication();

  @override
  Future<bool> isSupported() => _auth.isDeviceSupported();

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason);
    } on LocalAuthException {
      return false; // cancelled, locked out, no prompt available...
    }
  }
}

class AppLock {
  static final AppLock instance = AppLock._();
  AppLock._();

  Authenticator auth = LocalAuthenticator();

  /// Whether the lock is on. The gate above the app listens to it.
  final enabled = ValueNotifier<bool>(false);

  /// A phone prompt is up (or about to be). The prompt takes the app to the
  /// background, which must not count as the user leaving.
  bool busy = false;

  Future<void> load() async =>
      enabled.value = await ProfileManager.instance.isLockEnabled();

  Future<T> _whileBusy<T>(Future<T> Function() ask) async {
    busy = true;
    try {
      return await ask();
    } finally {
      busy = false;
    }
  }

  /// Asks the phone to unlock the app. A phone with no screen lock cannot be
  /// asked, so the lock switches itself off rather than lock the user out.
  Future<bool> unlock() {
    if (busy) return Future.value(false);
    return _whileBusy(() async {
      if (!await auth.isSupported()) {
        await _save(false);
        return true;
      }
      return auth.authenticate('Unlock FinanceApp');
    });
  }

  /// Turns the lock on or off after the user proves it is them. Returns an error
  /// message, or null when it worked.
  Future<String?> setEnabled(bool on) {
    if (busy) return Future.value('Another prompt is open');
    return _whileBusy(() async {
      if (on && !await auth.isSupported()) {
        return 'Set a screen lock (PIN, pattern or fingerprint) on your phone first';
      }
      if (!await auth.authenticate(on ? 'Turn on the app lock' : 'Turn off the app lock')) {
        return 'Could not confirm it is you';
      }
      await _save(on);
      return null;
    });
  }

  Future<void> _save(bool on) async {
    await ProfileManager.instance.setLockEnabled(on);
    enabled.value = on;
  }
}
