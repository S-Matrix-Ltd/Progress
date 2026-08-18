import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

/// Prottidin thik shomoy-e ekta "Duty entry din" reminder pathay.
///
/// AGE ei service 'inexactAllowWhileIdle' mode use korto — mane Android
/// battery-optimizer (biশেষ kore Xiaomi/Oppo/Vivo/Realme-er moto phone-e,
/// jegula Bangladesh-e onek popular) ei notification ke Doze mode-e onek
/// deri kore dito, ba shomponno suppress-o kore dito. Tai user-er kache
/// mone hoto "reminder kaj kore na".
///
/// EKHON 'AndroidScheduleMode.alarmClock' use kora hocche — eta thik
/// shei-i API (AlarmManager.setAlarmClock) jeta আসল Alarm/Clock app
/// use kore. Ei mode-e:
///  - Notification ekdom EXACT shomoy-e baje, Doze mode-eo deri hoy na
///  - Status bar-e ekta chhoto alarm-icon dekhay (jemon real alarm app-e hoy)
///  - Kintu Android 12+ e ei exact-alarm chalanor jonne user-ke ekta
///    আলাদা "Alarms & reminders" permission Settings-e giye ON korte hoy —
///    tai ei service-e ekta requestExactAlarmPermission() method ache
///    jeta shei Settings screen ta shorasori open kore dey.
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

  /// "Alarms & reminders" (Exact Alarm) permission — Android 12+ e ei
  /// permission na thakle alarm-clock-grade exact timing kaj korbe na.
  /// Ei method Android-er nijer Settings screen open kore dey jekhane
  /// user ekta toggle ON korte parben. Purono Android (12-er niche) e
  /// eta lagei na — automatically true return kore.
  static Future<bool> requestExactAlarmPermission() async {
    await init();
    final androidImpl = _android;
    if (androidImpl == null) return true;
    try {
      final granted = await androidImpl.requestExactAlarmsPermission();
      return granted ?? true;
    } catch (_) {
      // Plugin/OS version ei API support na korle (purono Android),
      // exact alarm-e restriction-i thake na — tai true.
      return true;
    }
  }

  static Future<void> scheduleDaily(TimeOfDay time) async {
    await init();
    // Age ekbar schedule kora thakle prothome cancel kore notun kore
    // schedule kora hocche — nahole purono shomoy-er shathe notunta
    // duita-i thakte pare.
    await _plugin.cancel(100);
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
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
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
