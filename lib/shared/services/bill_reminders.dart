// ── Bill reminders ────────────────────────────────────────────────────────────
// Schedules the local notifications computed by pendingReminders(). Every call
// replaces ALL pending reminders, so the phone only ever holds the ones of the
// bills that are on screen (the active profile).
// ─────────────────────────────────────────────────────────────────────────────
import 'package:financeapp/modules/fixedExp/bill_due.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

abstract class BillReminders {
  /// [ask] is true when the user just saved a bill with a due day: only then may
  /// the OS permission screens (notifications, exact alarms) be shown.
  Future<void> sync(List<BillReminder> reminders, {bool ask = false});
}

/// Used where there is no notification service (tests, desktop).
class NoBillReminders implements BillReminders {
  const NoBillReminders();
  @override
  Future<void> sync(List<BillReminder> reminders, {bool ask = false}) async {}
}

class LocalBillReminders implements BillReminders {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;
  Future<void> _queue = Future.value();
  // shortcut: asked once per app launch, not remembered across launches; persist a flag if that nags.
  bool _askedExact = false;

  Future<void> _init() => _ready ??= _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Permission is asked in sync() once there is a reminder, not at launch.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );

  /// One sync at a time: two overlapping ones could leave the older bill list scheduled.
  @override
  Future<void> sync(List<BillReminder> reminders, {bool ask = false}) =>
      _queue = _queue.then((_) => _sync(reminders, ask));

  Future<void> _sync(List<BillReminder> reminders, bool ask) async {
    try {
      await _init();
      await _plugin.cancelAllPendingNotifications();
      if (reminders.isEmpty) return;
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      // Always true before Android 12; from 12 on the user grants "Alarms & reminders".
      var exact = await android?.canScheduleExactNotifications() ?? false;
      if (ask) {
        await android?.requestNotificationsPermission();
        if (!exact && !_askedExact) {
          _askedExact = true;
          exact = await android?.requestExactAlarmsPermission() ?? false;
        }
        // iOS delivers a scheduled notification at its exact time once allowed.
        await ios?.requestPermissions(alert: true, sound: true);
      }
      for (final r in reminders) {
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: r.body,
          // The UTC instant is enough for a one-shot alarm, so no device
          // time-zone lookup is needed.
          scheduledDate: tz.TZDateTime.from(r.at, tz.UTC),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'bill_reminders',
              'Bill reminders',
              channelDescription: 'Reminds you before a bill is due',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          // Without the exact-alarm permission Android may delay it by hours.
          androidScheduleMode: exact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (_) {
      // Reminders are a convenience: a failure here must never break the bills screen.
    }
  }
}
