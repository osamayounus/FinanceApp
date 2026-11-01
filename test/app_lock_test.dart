import 'package:financeapp/shared/networks/local/profile_manager.dart';
import 'package:financeapp/shared/overlays/app_lock_gate.dart';
import 'package:financeapp/shared/services/app_lock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_env.dart';

void main() {
  setUpAll(setUpTestEnv);
  tearDownAll(tearDownTestEnv);

  final lock = AppLock.instance;
  late FakeAuthenticator phone;
  setUp(() async {
    phone = FakeAuthenticator();
    await resetAppLock(phone);
  });

  Future<bool> saved() => ProfileManager.instance.isLockEnabled();

  group('AppLock', () {
    test('turning it on asks the phone, then remembers', () async {
      expect(await lock.setEnabled(true), isNull);
      expect(lock.enabled.value, isTrue);
      expect(await saved(), isTrue);
      expect(phone.asked, ['Turn on the app lock']);

      lock.enabled.value = false;
      await lock.load();
      expect(lock.enabled.value, isTrue, reason: 'load() reads what was saved');
    });

    test('a phone without a screen lock cannot turn it on, and is not asked', () async {
      phone.supported = false;
      expect(await lock.setEnabled(true), contains('screen lock'));
      expect(lock.enabled.value, isFalse);
      expect(await saved(), isFalse);
      expect(phone.asked, isEmpty);
    });

    test('not confirming leaves it as it was', () async {
      phone.accept = false;
      expect(await lock.setEnabled(true), 'Could not confirm it is you');
      expect(await saved(), isFalse);

      phone.accept = true;
      await lock.setEnabled(true);
      phone.accept = false;
      expect(await lock.setEnabled(false), 'Could not confirm it is you');
      expect(lock.enabled.value, isTrue);
      expect(await saved(), isTrue);
    });

    test('turning it off also needs the phone to confirm', () async {
      await lock.setEnabled(true);
      expect(await lock.setEnabled(false), isNull);
      expect(lock.enabled.value, isFalse);
      expect(await saved(), isFalse);
      expect(phone.asked.last, 'Turn off the app lock');
    });

    test('unlock returns what the phone answered', () async {
      expect(await lock.unlock(), isTrue);
      phone.accept = false;
      expect(await lock.unlock(), isFalse);
    });

    test('a phone that lost its screen lock switches the lock off instead of locking you out',
        () async {
      await lock.setEnabled(true);
      phone.supported = false;
      expect(await lock.unlock(), isTrue);
      expect(lock.enabled.value, isFalse);
      expect(await saved(), isFalse);
    });

    test('busy is only set while the phone is being asked', () async {
      expect(lock.busy, isFalse);
      final pending = lock.setEnabled(true);
      expect(lock.busy, isTrue);
      await pending;
      expect(lock.busy, isFalse);
    });

    test('a second prompt while one is open is refused', () async {
      lock.busy = true;
      expect(await lock.unlock(), isFalse);
      expect(await lock.setEnabled(true), 'Another prompt is open');
      expect(phone.asked, isEmpty);
    });
  });

  group('AppLockGate', () {
    Future<void> show(WidgetTester t,
        {bool locked = true, Duration grace = const Duration(seconds: 30)}) async {
      lock.enabled.value = locked;
      await t.pumpWidget(AppLockGate(
        grace: grace,
        child: const MaterialApp(home: Scaffold(body: Text('secret'))),
      ));
      await t.pump();
    }

    Future<void> away(WidgetTester t) async {
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
    }

    testWidgets('with the lock off the app is just there', (t) async {
      await show(t, locked: false);
      expect(find.text('secret'), findsOneWidget);
      expect(find.text('FinanceApp is locked'), findsNothing);
      expect(phone.asked, isEmpty);
    });

    testWidgets('on start it asks the phone and opens when answered', (t) async {
      await show(t);
      expect(phone.asked, ['Unlock FinanceApp']);
      expect(find.text('secret'), findsOneWidget);
      expect(find.text('FinanceApp is locked'), findsNothing);
    });

    testWidgets('if the phone refuses, the app stays hidden until Unlock works', (t) async {
      phone.accept = false;
      await show(t);
      expect(find.text('FinanceApp is locked'), findsOneWidget);
      expect(find.text('secret'), findsNothing, reason: 'the app must not show through');

      await t.tap(find.text('Unlock'));
      await t.pump();
      expect(find.text('secret'), findsNothing);
      expect(phone.asked.length, 2);

      phone.accept = true;
      await t.tap(find.text('Unlock'));
      await t.pump();
      expect(find.text('secret'), findsOneWidget);
      expect(find.text('FinanceApp is locked'), findsNothing);
    });

    testWidgets('the app keeps its state while locked', (t) async {
      final key = GlobalKey<_CounterState>();
      lock.enabled.value = false;
      await t.pumpWidget(AppLockGate(
        grace: Duration.zero,
        child: MaterialApp(home: Scaffold(body: _Counter(key: key))),
      ));
      key.currentState!.bump();
      await t.pump();
      phone.accept = false;
      lock.enabled.value = true;
      await away(t); // locks (grace is zero) and the phone refuses
      expect(find.text('FinanceApp is locked'), findsOneWidget);

      phone.accept = true;
      await t.tap(find.text('Unlock'));
      await t.pump();
      expect(find.text('count 1'), findsOneWidget);
    });

    testWidgets('coming back after the grace period locks and asks again', (t) async {
      await show(t, grace: Duration.zero);
      phone.accept = false;
      await away(t);
      expect(phone.asked.length, 2);
      expect(find.text('FinanceApp is locked'), findsOneWidget);
    });

    testWidgets('a short trip out of the app (file picker, share sheet) does not lock', (t) async {
      await show(t);
      await away(t);
      expect(phone.asked.length, 1, reason: 'only the start-up prompt');
      expect(find.text('secret'), findsOneWidget);
    });

    testWidgets('the phone prompt pausing the app does not count as leaving it', (t) async {
      await show(t, locked: false, grace: Duration.zero);
      lock.enabled.value = true; // e.g. just turned on
      lock.busy = true; // its own prompt is up
      await away(t);
      lock.busy = false;
      expect(find.text('secret'), findsOneWidget);
      expect(phone.asked, isEmpty);
    });

    testWidgets('with the lock off, leaving the app never locks', (t) async {
      await show(t, locked: false, grace: Duration.zero);
      await away(t);
      expect(find.text('secret'), findsOneWidget);
      expect(phone.asked, isEmpty);
    });

    testWidgets('turning the lock off while it shows opens the app', (t) async {
      phone.accept = false;
      await show(t);
      expect(find.text('FinanceApp is locked'), findsOneWidget);
      lock.enabled.value = false;
      await t.pump();
      expect(find.text('secret'), findsOneWidget);
    });
  });
}

class _Counter extends StatefulWidget {
  const _Counter({super.key});
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;
  void bump() => setState(() => n++);
  @override
  Widget build(BuildContext context) => Text('count $n');
}
