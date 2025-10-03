import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schelper_app/services/notification_scheduler.dart';

class NotificationsSettingsPage extends StatefulWidget {
  const NotificationsSettingsPage({super.key});

  @override
  State<NotificationsSettingsPage> createState() => _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState extends State<NotificationsSettingsPage> {
  static const _prefsKey = 'notifications.homework_reminder';

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
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final Map<String, dynamic> data = json.decode(raw);
      final enabled = data['enabled'] as bool? ?? true;
      final hour = data['hour'] as int? ?? 16;
      final minute = data['minute'] as int? ?? 0;
      final days = (data['days'] as List?)?.map((e) => e == true).toList() ??
          [true, true, true, true, true, false, false];
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _time = TimeOfDay(hour: hour, minute: minute);
        for (var i = 0; i < _days.length && i < days.length; i++) {
          _days[i] = days[i] == true;
        }
      });
    } catch (_) {
      // ignore malformed
    }
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 350), _saveNow);
  }

  Future<void> _saveNow() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'enabled': _enabled,
      'hour': _time.hour,
      'minute': _time.minute,
      'days': _days,
    };
    await prefs.setString(_prefsKey, json.encode(data));
    // Update alarms immediately when settings change
    await NotificationScheduler.rescheduleFromPrefs();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);
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
                            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                            child: child ?? const SizedBox.shrink(),
                          ),
                        );
                        if (picked != null) {
                          setState(() => _time = picked);
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
                  Text('Включить напоминания', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(width: 8),
                  Switch(
                    value: _enabled,
                    onChanged: (v) {
                      setState(() => _enabled = v);
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

          const Divider(height: 32),

          // 🔔 Тестовая кнопка
          ElevatedButton.icon(
            onPressed: () {
              NotificationScheduler.testNotificationIn(const Duration(minutes: 2));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Тестовое уведомление запланировано через 2 минуты')),
              );
            },
            icon: const Icon(Icons.notifications_active),
            label: const Text('Проверить уведомление (через 2 мин)'),
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
                    setState(() => _days[i] = v ?? false);
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
