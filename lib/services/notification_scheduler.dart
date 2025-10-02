import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

// Key used by notifications settings page
const String _prefsKey = 'notifications.homework_reminder';

// Unique base for weekday alarm IDs (0..6 added)
const int _alarmBaseId = 41000;

// Notification channel details
const String _channelId = 'homework_reminder_channel';
const String _channelName = 'Homework Reminder';
const String _channelDescription = 'Напоминания о домашней работе';

final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();

class NotificationScheduler {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    // Local notifications
    debugPrint('NotificationScheduler.init: start');
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('ic_alarm');
    const InitializationSettings initSettings = InitializationSettings(android: androidInit);
    await _fln.initialize(initSettings);

    // Create channel explicitly for Android 8+
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );
    final androidImpl = _fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(channel);
    // Note: On Android 13+ apps should request POST_NOTIFICATIONS at runtime.
    // flutter_local_notifications 17.x doesn't expose an Android permission API;
    // permission will need to be handled by the app if required.

    // Timezone setup for zoned scheduling (no native plugin; use offset mapping)
    try {
      tzdata.initializeTimeZones();
      final Duration offset = DateTime.now().timeZoneOffset;
      final int hours = offset.inHours;
      final String name = hours >= 0 ? 'Etc/GMT-${hours.abs()}' : 'Etc/GMT+${hours.abs()}';
      tz.setLocalLocation(tz.getLocation(name));
      debugPrint('NotificationScheduler.init: timezone set to $name');
    } catch (e) {
      debugPrint('NotificationScheduler.init: timezone init failed: $e');
    }
    _initialized = true;
    debugPrint('NotificationScheduler.init: completed');
  }

  // Public entry to reschedule according to saved preferences
  static Future<void> rescheduleFromPrefs() async {
    debugPrint('NotificationScheduler.rescheduleFromPrefs: start');
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);

    // Cancel all scheduled notifications for this app
    await _fln.cancelAll();
    debugPrint('NotificationScheduler.rescheduleFromPrefs: canceled existing alarms');

    if (raw == null) return;
    Map<String, dynamic> data;
    try {
      data = json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      debugPrint('NotificationScheduler.rescheduleFromPrefs: malformed prefs');
      return;
    }

    final enabled = data['enabled'] == true;
    if (!enabled) {
      debugPrint('NotificationScheduler.rescheduleFromPrefs: disabled');
      return;
    }

    final int hour = (data['hour'] as int?) ?? 16;
    final int minute = (data['minute'] as int?) ?? 0;
    final List daysRaw = (data['days'] as List?) ?? const [true, true, true, true, true, false, false];
    final List<bool> days = List<bool>.generate(7, (i) => i < daysRaw.length ? (daysRaw[i] == true) : false);

    // Schedule weekly notifications using flutter_local_notifications
    for (var i = 0; i < 7; i++) {
      if (!days[i]) continue;
      final scheduled = _nextTzWeekdayAt(i, hour, minute);
      final id = _alarmBaseId + i;

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_alarm',
        category: AndroidNotificationCategory.reminder,
      );
      const NotificationDetails details = NotificationDetails(android: androidDetails);

      try {
        await _fln.zonedSchedule(
          id,
          'Напоминание',
          'Пора приступать к Домашечке!',
          scheduled,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
        debugPrint('NotificationScheduler.rescheduleFromPrefs: scheduled id=$id at ${scheduled.toString()} (exact)');
      } on PlatformException catch (e) {
        if (e.code == 'exact_alarms_not_permitted') {
          debugPrint('NotificationScheduler: exact not permitted; falling back to inexact for id=$id');
          await _fln.zonedSchedule(
            id,
            'Напоминание',
            'Пора приступать к Домашечке!',
            scheduled,
            details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
          debugPrint('NotificationScheduler.rescheduleFromPrefs: scheduled id=$id at ${scheduled.toString()} (inexact)');
        } else {
          debugPrint('NotificationScheduler: schedule failed for id=$id error=${e.code} ${e.message}');
        }
      }
    }
    debugPrint('NotificationScheduler.rescheduleFromPrefs: completed');
  }
}

// Compute the next occurrence of weekday index [0=Mon..6=Sun] at [hour:minute]
tz.TZDateTime _nextTzWeekdayAt(int weekdayIndex, int hour, int minute) {
  final now = tz.TZDateTime.now(tz.local);
  final targetWeekday = weekdayIndex + 1; // Monday=1..Sunday=7
  var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
  int addDays = (targetWeekday - scheduled.weekday) % 7;
  if (addDays < 0) addDays += 7;
  scheduled = scheduled.add(Duration(days: addDays));
  if (!scheduled.isAfter(now)) {
    scheduled = scheduled.add(const Duration(days: 7));
  }
  return scheduled;
}

// Top-level callback for AndroidAlarmManager
// No background callback needed when using zonedSchedule
