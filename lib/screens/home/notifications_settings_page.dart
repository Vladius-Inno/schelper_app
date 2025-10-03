import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:schelper_app/constants/storage_keys.dart';
import 'package:schelper_app/services/local_notifications_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsSettingsPage extends StatefulWidget {
  const NotificationsSettingsPage({super.key});

  @override
  State<NotificationsSettingsPage> createState() =>
      _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState extends State<NotificationsSettingsPage> {
  final LocalNotificationsService _notificationsService =
      LocalNotificationsService();

  bool _enabled = true;
  TimeOfDay _time = const TimeOfDay(hour: 16, minute: 0);
  final List<bool> _days = [true, true, true, true, true, false, false];

  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    debugPrint('[NotificationsSettingsPage] _load() start');
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(homeworkReminderPrefsKey);
    if (raw == null) {
      debugPrint('[NotificationsSettingsPage] No stored settings found');
      return;
    }
    try {
      final Map<String, dynamic> data = json.decode(raw);
      final enabled = data['enabled'] as bool? ?? true;
      final hour = data['hour'] as int? ?? 16;
      final minute = data['minute'] as int? ?? 0;
      final days =
          (data['days'] as List?)?.map((e) => e == true).toList() ??
          [true, true, true, true, true, false, false];
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _time = TimeOfDay(hour: hour, minute: minute);
        for (var i = 0; i < _days.length && i < days.length; i++) {
          _days[i] = days[i] == true;
        }
      });
      debugPrint(
        '[NotificationsSettingsPage] Loaded settings enabled='
        '$enabled time=${_formatTime(_time)} days=${_days.toString()}',
      );
      await _notificationsService.scheduleHomeworkReminders(
        enabled: _enabled,
        time: _time,
        days: List<bool>.from(_days),
      );
      debugPrint(
        '[NotificationsSettingsPage] Applied scheduled reminders from stored settings',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[NotificationsSettingsPage] Failed to parse stored settings: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _scheduleSave() {
    debugPrint('[NotificationsSettingsPage] _scheduleSave() queued');
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 350), _saveNow);
  }

  Future<void> _saveNow() async {
    debugPrint('[NotificationsSettingsPage] _saveNow() start');
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'enabled': _enabled,
      'hour': _time.hour,
      'minute': _time.minute,
      'days': List<bool>.from(_days),
    };
    try {
      await prefs.setString(homeworkReminderPrefsKey, json.encode(data));
      debugPrint('[NotificationsSettingsPage] Saved settings: $data');
    } catch (error, stackTrace) {
      debugPrint(
        '[NotificationsSettingsPage] Failed to persist settings: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return;
    }
    try {
      await _notificationsService.scheduleHomeworkReminders(
        enabled: _enabled,
        time: _time,
        days: List<bool>.from(_days),
      );
      debugPrint(
        '[NotificationsSettingsPage] Notifications rescheduled after save',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[NotificationsSettingsPage] Failed to reschedule notifications: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    debugPrint('[NotificationsSettingsPage] dispose()');
    _saveDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);
    return Scaffold(
      appBar: AppBar(title: const Text('Уведомления')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Block: Напоминание о Домашечке
          Text('Напоминание о Домашечке', style: titleStyle),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _enabled
                    ? () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _time,
                          builder: (context, child) => MediaQuery(
                            data: MediaQuery.of(
                              context,
                            ).copyWith(alwaysUse24HourFormat: true),
                            child: child ?? const SizedBox.shrink(),
                          ),
                        );
                        if (picked != null) {
                          setState(() => _time = picked);
                          debugPrint(
                            '[NotificationsSettingsPage] Time updated to ${_formatTime(picked)}',
                          );
                          _scheduleSave();
                        }
                      }
                    : null,
                icon: const Icon(Icons.access_time),
                label: Text(_formatTime(_time)),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Включить напоминания',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _enabled,
                    onChanged: (v) {
                      setState(() => _enabled = v);
                      debugPrint(
                        '[NotificationsSettingsPage] Enabled toggled to $v',
                      );
                      _scheduleSave();
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: _buildWeekdayCheckboxes(context),
          ),
          const SizedBox(height: 24),
          Text('Тест уведомлений', style: titleStyle),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _enabled
                    ? () async {
                        debugPrint(
                          '[NotificationsSettingsPage] Trigger immediate test notification',
                        );
                        await _notificationsService.showHomeworkReminderNow();
                      }
                    : null,
                child: const Text('Отправить сейчас'),
              ),
              OutlinedButton(
                onPressed: _enabled
                    ? () async {
                        debugPrint(
                          '[NotificationsSettingsPage] Schedule test notification in 2 minutes',
                        );
                        await _notificationsService.scheduleHomeworkReminderIn(
                          const Duration(minutes: 2),
                        );
                      }
                    : null,
                child: const Text('Через 2 минуты'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildWeekdayCheckboxes(BuildContext context) {
    const labels = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
    final disabled = !_enabled;
    return List.generate(7, (i) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: _days[i],
            onChanged: disabled
                ? null
                : (v) {
                    final newValue = v ?? false;
                    setState(() => _days[i] = newValue);
                    debugPrint(
                      '[NotificationsSettingsPage] Day index $i set to $newValue',
                    );
                    _scheduleSave();
                  },
          ),
          Text(labels[i]),
        ],
      );
    });
  }

  String _formatTime(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
