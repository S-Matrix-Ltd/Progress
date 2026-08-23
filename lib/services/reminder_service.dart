import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

/// Prottidin thik shomoy-e ekta "Duty entry din" reminder pathay.
///
/// 'alarmClock' mode (AlarmManager.setAlarmClock) — asol Alarm app jei
/// API use kore — try kora hoy prothome, jate Doze mode-eo thik
/// shomoy-e baje. Kintu ei mode-er jonne "Alarms & reminders" (Exact
/// Alarm) permission lage (Android 12+). Kono karone (permission na
/// deya, device restriction) exact scheduling fail korle, ei service
/// nijer theke kom-precision mode-e "fallback" kore — tai reminder
/// EKDOM silently fail kore na, kono na kono vabe abossoi schedule hoy.
class ReminderService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));
    } catch (_) {
      // fallback: UTC thakle thakuk, tobu crash korbe na
    }
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Notification dekhanor permission (Android 13+ e lage).
  static Future<bool> requestPermission() async {
    await init();
    final androidImpl = _android;
    if (androidImpl == null) return true; // Android chara onno platform-e assume ok
    final granted = await androidImpl.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Ei muhurte notification dekhanor permission ache kina — shudhu
  /// check kore, notun kore chay na.
  static Future<bool> notificationsAllowed() async {
    await init();
    final androidImpl = _android;
    if (androidImpl == null) return true;
    try {
      final enabled = await androidImpl.areNotificationsEnabled();
      return enabled ?? true;
    } catch (_) {
      return true;
    }
  }

  /// "Alarms & reminders" (Exact Alarm) permission — Android 12+ e ei
  /// permission na thakle exact timing kaj korbe na. Ei method Android-er
  /// nijer Settings screen open kore dey jekhane user ekta toggle ON
  /// korte parben.
  static Future<void> requestExactAlarmPermission() async {
    await init();
    final androidImpl = _android;
    if (androidImpl == null) return;
    try {
      await androidImpl.requestExactAlarmsPermission();
    } catch (_) {
      // Plugin/OS version ei API support na korle (purono Android),
      // eta lagei na.
    }
  }

  /// Exact alarm permission ei muhurte ache kina check kore.
  static Future<bool> canScheduleExact() async {
    await init();
    final androidImpl = _android;
    if (androidImpl == null) return true;
    try {
      final can = await androidImpl.canScheduleExactNotifications();
      return can ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Onek phone-e (Xiaomi/Oppo/Vivo/Realme etc) OS-er nijer "Battery
  /// Saver"/"Autostart" restriction thake, jeta AlarmManager-er exact
  /// permission thakleo background-e app-ke jagte deয় na — tai notification
  /// akhoni test korle ashe kintu scheduled shomoy-e ashe na. Ei permission
  /// (Ignore Battery Optimizations) chaile onek khetreই eta thik hoye jay.
  /// Play Store chara sideload kora app-e eta OS "special access" list-e
  /// nite lage, tai ekta system dialog dekhabe user-ke.
  static Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (!status.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    } catch (_) {
      // Android chara onno platform-e ei permission-i thake na.
    }
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      return await Permission.ignoreBatteryOptimizations.status.then((s) => s.isGranted);
    } catch (_) {
      return true;
    }
  }

  /// Reminder schedule kore, precision fallback shoho:
  /// alarmClock -> exactAllowWhileIdle -> inexactAllowWhileIdle.
  /// Return kore je mode-e ashole schedule hoyeche seta, ba fail hole
  /// "failed: <asol exception message>" — jate lukiye na theke asol
  /// karonta UI-te dekhano jay.
  static Future<String> scheduleOneTimeTest(Duration delay) async {
    await init();
    await _plugin.cancel(998);
    final fireTime = tz.TZDateTime.now(tz.local).add(delay);
    const modes = [
      AndroidScheduleMode.alarmClock,
      AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ];
    String lastError = '';
    for (final mode in modes) {
      try {
        await _plugin.zonedSchedule(
          998,
          'Test Alarm',
          'Eta ashle, background scheduling thik moto kaj kortese ($mode).',
          fireTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'daily-entry-reminder',
              'Daily Entry Reminder',
              channelDescription: 'Ajker duty entry deyar reminder',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
        return mode.toString();
      } catch (e) {
        lastError = e.toString();
        continue;
      }
    }
    return 'failed: $lastError';
  }

  static Future<String> scheduleDaily(TimeOfDay time) async {
    await init();
    await _plugin.cancel(100);

    const modes = [
      AndroidScheduleMode.alarmClock,
      AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ];

    String lastError = '';
    for (final mode in modes) {
      try {
        await _plugin.zonedSchedule(
          100,
          'Duty & OT Entry',
          "Ajker duty/OT entry ta din — bhule jaben na!",
          _nextInstanceOf(time),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'daily-entry-reminder',
              'Daily Entry Reminder',
              channelDescription: 'Ajker duty entry deyar reminder',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
        return mode.toString(); // success — ei mode-e schedule hoyeche
      } catch (e) {
        lastError = e.toString();
        continue;
      }
    }
    return 'failed: $lastError';
  }

  /// Ekdom akhoni ekta test notification pathay (kono schedule chara) —
  /// jate bujha jay device-e notification dekhano-i kaj kore kina, ta
  /// scheduling-er shomossha theke alada kore.
  static Future<bool> showTestNotification() async {
    await init();
    try {
      await _plugin.show(
        999,
        'Test Notification',
        'Eta thik moto ashle, notification system kaj kortese.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily-entry-reminder',
            'Daily Entry Reminder',
            channelDescription: 'Ajker duty entry deyar reminder',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> cancel() async {
    await init();
    await _plugin.cancel(100);
  }

  static tz.TZDateTime _nextInstanceOf(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
