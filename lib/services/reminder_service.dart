import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

/// Prottidin ekta shomoye "Duty entry din" reminder notification pathay.
/// Notification permission (Android 13+) auto request kore.
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

  static Future<void> requestPermission() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();
  }

  static Future<void> scheduleDaily(TimeOfDay time) async {
    await init();
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
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
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
