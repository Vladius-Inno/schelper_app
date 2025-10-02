import 'dart:convert';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    // Alarm manager
    await AndroidAlarmManager.initialize();
    _initialized = true;
  }

  // Public entry to reschedule according to saved preferences
  static Future<void> rescheduleFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);

    // Cancel any existing scheduled alarms for all weekdays first
    for (var i = 0; i < 7; i++) {
      await AndroidAlarmManager.cancel(_alarmBaseId + i);
    }

    if (raw == null) return;
    Map<String, dynamic> data;
    try {
      data = json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final enabled = data['enabled'] == true;
    if (!enabled) return;

    final int hour = (data['hour'] as int?) ?? 16;
    final int minute = (data['minute'] as int?) ?? 0;
    final List daysRaw = (data['days'] as List?) ?? const [true, true, true, true, true, false, false];
    final List<bool> days = List<bool>.generate(7, (i) => i < daysRaw.length ? (daysRaw[i] == true) : false);

    // Schedule weekly alarms for selected days
    for (var i = 0; i < 7; i++) {
      if (!days[i]) continue;
      final startAt = _nextWeekdayAt(i, hour, minute);
      final id = _alarmBaseId + i;
      await AndroidAlarmManager.periodic(
        const Duration(days: 7),
        id,
        _alarmCallback,
        startAt: startAt,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
        allowWhileIdle: true,
      );
    }
  }
}

// Compute the next occurrence of weekday index [0=Mon..6=Sun] at [hour:minute]
DateTime _nextWeekdayAt(int weekdayIndex, int hour, int minute) {
  final now = DateTime.now();
  // Flutter DateTime.weekday: Monday=1..Sunday=7
  final targetWeekday = weekdayIndex + 1;
  var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
  // advance to target weekday
  int addDays = (targetWeekday - scheduled.weekday) % 7;
  if (addDays < 0) addDays += 7;
  scheduled = scheduled.add(Duration(days: addDays));
  if (!scheduled.isAfter(now)) {
    scheduled = scheduled.add(const Duration(days: 7));
  }
  return scheduled;
}

// Top-level callback for AndroidAlarmManager
@pragma('vm:entry-point')
Future<void> _alarmCallback() async {
  // Ensure plugin is available in background isolate
  const AndroidInitializationSettings androidInit = AndroidInitializationSettings('ic_alarm');
  const InitializationSettings initSettings = InitializationSettings(android: androidInit);
  await _fln.initialize(initSettings);

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

  // Show reminder notification
  await _fln.show(
    99001, // fixed ID; updates the existing reminder if still visible
    'Напоминание',
    'Пора приступать к Домашечке!',
    details,
  );
}
