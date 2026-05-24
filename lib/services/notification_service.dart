import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _channelId = 'viali_daily';
  static const _channelName = 'Recordatorio diario';
  static const _notifId = 42;
  static const _keyEnabled = 'notif_enabled';
  static const _keyHour = 'notif_hour';
  static const _keyMinute = 'notif_minute';

  static Future<void> init() async {
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyEnabled) ?? false) {
      await _schedule(
        prefs.getInt(_keyHour) ?? 19,
        prefs.getInt(_keyMinute) ?? 0,
      );
    }
  }

  static Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  static Future<void> enable(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, true);
    await prefs.setInt(_keyHour, hour);
    await prefs.setInt(_keyMinute, minute);
    await _schedule(hour, minute);
  }

  static Future<void> disable() async {
    await _plugin.cancel(_notifId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, false);
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? false;
  }

  static Future<TimeOfDay> getTime() async {
    final prefs = await SharedPreferences.getInstance();
    return TimeOfDay(
      hour: prefs.getInt(_keyHour) ?? 19,
      minute: prefs.getInt(_keyMinute) ?? 0,
    );
  }

  static Future<void> _schedule(int hour, int minute) async {
    await _plugin.cancel(_notifId);
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    var local = DateTime(now.year, now.month, now.day, hour, minute);
    if (!local.isAfter(now)) local = local.add(const Duration(days: 1));
    final utc = local.subtract(offset);
    var scheduled = tz.TZDateTime.from(utc, tz.UTC);
    await _plugin.zonedSchedule(
      _notifId,
      '¡Viali te echa de menos!',
      'Practica unos minutos hoy 🚦',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Recordatorio diario para estudiar',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
