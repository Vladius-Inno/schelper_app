import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../constants/storage_keys.dart';

class LocalNotificationsService {
  LocalNotificationsService._();

  static final LocalNotificationsService _instance =
      LocalNotificationsService._();

  factory LocalNotificationsService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const MethodChannel _timezoneChannel = MethodChannel(
    'schelper/timezone',
  );

  static const int _homeworkBaseId = 1000;
  static const int _testImmediateId = 2000;
  static const int _testFutureId = 2001;
  static const String _channelId = 'homework_reminders_channel';
  static const String _channelName = 'Домашечка';
  static const String _channelDescription = 'Homework reminder notifications';
  static const String _payloadHomeworkReminder = 'homework_reminder';

  bool _initialized = false;
  bool _timezoneInitialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      debugPrint(
        '[LocalNotificationsService] initialize() skipped (already initialized)',
      );
      return;
    }
    debugPrint('[LocalNotificationsService] initialize() start');
    const androidInitSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidInitSettings);
    await _plugin.initialize(initSettings);
    await _configureLocalTimeZone();
    await _requestPermissions();
    _initialized = true;
    debugPrint('[LocalNotificationsService] initialize() done');
  }

  Future<void> refreshHomeworkRemindersFromPrefs() async {
    debugPrint(
      '[LocalNotificationsService] refreshHomeworkRemindersFromPrefs() start',
    );
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(homeworkReminderPrefsKey);
    if (raw == null) {
      debugPrint(
        '[LocalNotificationsService] No stored settings, cancelling existing reminders',
      );
      await cancelHomeworkReminders();
      return;
    }
    try {
      final data = json.decode(raw) as Map<String, dynamic>;
      final enabled = data['enabled'] as bool? ?? true;
      final hour = data['hour'] as int? ?? 16;
      final minute = data['minute'] as int? ?? 0;
      final daysRaw = data['days'] as List?;
      final days = List<bool>.generate(
        7,
        (i) =>
            daysRaw != null && i < daysRaw.length ? daysRaw[i] == true : i < 5,
      );
      await scheduleHomeworkReminders(
        enabled: enabled,
        time: TimeOfDay(hour: hour, minute: minute),
        days: days,
      );
      debugPrint(
        '[LocalNotificationsService] Refreshed reminders from stored settings',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[LocalNotificationsService] Failed to decode stored preferences: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> scheduleHomeworkReminders({
    required bool enabled,
    required TimeOfDay time,
    required List<bool> days,
  }) async {
    await initialize();
    debugPrint(
      '[LocalNotificationsService] scheduleHomeworkReminders(enabled=$enabled, time=${_formatTime(time)}, days=$days)',
    );
    await cancelHomeworkReminders();
    if (!enabled) {
      debugPrint(
        '[LocalNotificationsService] Notifications disabled, nothing to schedule',
      );
      return;
    }

    for (var index = 0; index < days.length; index++) {
      if (!days[index]) {
        continue;
      }
      final weekday = index + 1; // DateTime weekday: Monday=1 ... Sunday=7
      final scheduledDate = _nextInstanceOfDayAndTime(weekday, time);
      final notificationId = _homeworkBaseId + weekday;
      try {
        await _plugin.zonedSchedule(
          notificationId,
          null,
          'Пора приступать к Домашечке!',
          scheduledDate,
          _notificationDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: _payloadHomeworkReminder,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        debugPrint(
          '[LocalNotificationsService] Scheduled reminder for weekday=$weekday at $scheduledDate',
        );
      } catch (error, stackTrace) {
        debugPrint(
          '[LocalNotificationsService] Failed to schedule weekday=$weekday: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Future<void> cancelHomeworkReminders() async {
    await initialize();
    debugPrint('[LocalNotificationsService] cancelHomeworkReminders() called');
    for (var weekday = 1; weekday <= 7; weekday++) {
      final notificationId = _homeworkBaseId + weekday;
      await _plugin.cancel(notificationId);
    }
  }

  Future<void> showHomeworkReminderNow() async {
    await initialize();
    debugPrint('[LocalNotificationsService] showHomeworkReminderNow()');
    await _plugin.show(
      _testImmediateId,
      null,
      'Пора приступать к Домашечке!',
      _notificationDetails(),
      payload: _payloadHomeworkReminder,
    );
  }

  Future<void> scheduleHomeworkReminderIn(Duration offset) async {
    await initialize();
    final scheduledDate = tz.TZDateTime.now(tz.local).add(offset);
    debugPrint(
      '[LocalNotificationsService] scheduleHomeworkReminderIn(offset=$offset) -> $scheduledDate',
    );
    await _plugin.zonedSchedule(
      _testFutureId,
      null,
      'Пора приступать к Домашечке!',
      scheduledDate,
      _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: _payloadHomeworkReminder,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) {
      return;
    }
    debugPrint(
      '[LocalNotificationsService] Requesting Android notification permissions',
    );
    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImplementation == null) {
      debugPrint(
        '[LocalNotificationsService] Android implementation not available',
      );
      return;
    }
    try {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    } catch (error, stackTrace) {
      debugPrint(
        '[LocalNotificationsService] Failed to request permissions: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _configureLocalTimeZone() async {
    if (_timezoneInitialized) {
      debugPrint('[LocalNotificationsService] Timezone already configured');
      return;
    }
    debugPrint('[LocalNotificationsService] Configuring timezone');
    tz.initializeTimeZones();
    final timezoneName = await _fetchLocalTimezone();
    try {
      tz.setLocalLocation(tz.getLocation(timezoneName));
      debugPrint('[LocalNotificationsService] Timezone set to $timezoneName');
    } catch (error, stackTrace) {
      debugPrint(
        '[LocalNotificationsService] Failed to apply timezone $timezoneName: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      tz.setLocalLocation(tz.getLocation('UTC'));
      debugPrint('[LocalNotificationsService] Fallback timezone set to UTC');
    }
    _timezoneInitialized = true;
  }

  tz.TZDateTime _nextInstanceOfDayAndTime(int weekday, TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    final daysUntilTarget = (weekday - scheduled.weekday) % 7;
    scheduled = scheduled.add(Duration(days: daysUntilTarget));
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }
    return scheduled;
  }

  Future<String> _fetchLocalTimezone() async {
    try {
      final timezoneName = await _timezoneChannel.invokeMethod<String>(
        'getLocalTimezone',
      );
      if (timezoneName != null && timezoneName.isNotEmpty) {
        debugPrint(
          '[LocalNotificationsService] Platform timezone result: $timezoneName',
        );
        return timezoneName;
      }
      debugPrint(
        '[LocalNotificationsService] Platform returned empty timezone, using UTC fallback',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[LocalNotificationsService] Failed to fetch timezone: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
    return 'UTC';
  }

  NotificationDetails _notificationDetails() {
    const androidSpecifics = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      enableLights: true,
      enableVibration: true,
      playSound: true,
    );
    return const NotificationDetails(android: androidSpecifics);
  }

  String _formatTime(TimeOfDay time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
