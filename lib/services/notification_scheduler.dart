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
  static Future<void>? _initializing;

  static Future<void> init() async {
    if (_initialized) return;
    if (_initializing != null) {
      await _initializing;
      return;
    }
    _initializing = _performInit();
    try {
      await _initializing;
    } finally {
      _initializing = null;
    }
  }

  static Future<void> _performInit() async {
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
    if (androidImpl != null) {
      await _ensureAndroidPermissions(androidImpl);
    }

    // Timezone setup for zoned scheduling using native timezone id
    try {
      tzdata.initializeTimeZones();
      final tz.Location loc = await _resolveLocalTzLocation();
      tz.setLocalLocation(loc);
      final now = tz.TZDateTime.now(tz.local);
      debugPrint('NotificationScheduler.init: timezone set to ${loc.name} (offset=${now.timeZoneOffset})');
    } catch (e) {
      debugPrint('NotificationScheduler.init: timezone init failed: $e');
    }
    _initialized = true;
    debugPrint('NotificationScheduler.init: completed');
  }

  static Future<void> _ensureAndroidPermissions(
    AndroidFlutterLocalNotificationsPlugin androidImpl,
  ) async {
    try {
      final bool? notificationsEnabled = await androidImpl.areNotificationsEnabled();
      if (notificationsEnabled == false) {
        final granted = await androidImpl.requestNotificationsPermission();
        debugPrint('NotificationScheduler: requested POST_NOTIFICATIONS permission (granted: ${granted == true})');
      }
    } catch (e) {
      debugPrint('NotificationScheduler: notification permission check failed: $e');
    }

    try {
      final bool? exactPermitted = await androidImpl.canScheduleExactNotifications();
      if (exactPermitted == false) {
        final granted = await androidImpl.requestExactAlarmsPermission();
        debugPrint('NotificationScheduler: requested SCHEDULE_EXACT_ALARM permission (granted: ${granted == true})');
      }
    } catch (e) {
      debugPrint('NotificationScheduler: exact alarm permission check failed: $e');
    }
  }

  // Public entry to reschedule according to saved preferences
  static Future<void> rescheduleFromPrefs() async {
    debugPrint('NotificationScheduler.rescheduleFromPrefs: start');
    await init();
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
        debugPrint('NotificationScheduler.rescheduleFromPrefs: scheduled id=$id at ${scheduled.toString()} (exactAllowWhileIdle)');
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
    // Diagnostics: log pending notifications count
    final pending = await _fln.pendingNotificationRequests();
    debugPrint('NotificationScheduler: pending notifications count=${pending.length}');
    debugPrint('NotificationScheduler.rescheduleFromPrefs: completed');
  }
}

Future<String?> _getNativeTimeZoneId() async {
  try {
    const channel = MethodChannel('schelper/timezone');
    final String? id = await channel.invokeMethod<String>('getTimeZone');
    return id;
  } catch (e) {
    debugPrint('NotificationScheduler: failed to get native timezone: $e');
    return null;
  }
}

Future<tz.Location> _resolveLocalTzLocation() async {
  // Try native IANA timezone first
  final String? tzId = await _getNativeTimeZoneId();
  if (tzId != null && tzId.isNotEmpty) {
    try {
      return tz.getLocation(tzId);
    } catch (_) {
      // Not an IANA ID; try to parse common variants like "GMT+03:00"
      final parsed = _mapGmtLikeToEtc(tzId);
      if (parsed != null) {
        return tz.getLocation(parsed);
      }
    }
  }

  // Fallback: use current offset to map to Etc/GMT±H (note: inverted sign per IANA rules)
  final Duration offset = DateTime.now().timeZoneOffset;
  final int hours = offset.inHours;
  final String name = hours >= 0 ? 'Etc/GMT-${hours.abs()}' : 'Etc/GMT+${hours.abs()}';
  return tz.getLocation(name);
}

String? _mapGmtLikeToEtc(String id) {
  // Accept forms: GMT, UTC, GMT+03:00, GMT-7, UTC+5, etc.
  final upper = id.toUpperCase().trim();
  if (upper == 'GMT' || upper == 'UTC') {
    return 'Etc/GMT';
  }
  final regex = RegExp(r'^(GMT|UTC)([+-])(\d{1,2})(?::?(\d{2}))?$');
  final m = regex.firstMatch(upper);
  if (m == null) return null;
  final sign = m.group(2)!; // "+" or "-"
  final h = int.tryParse(m.group(3) ?? '0') ?? 0;
  // IANA Etc/GMT uses inverted sign semantics
  final inverted = sign == '+' ? '-' : '+';
  return 'Etc/GMT$inverted$h';
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
