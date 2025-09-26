import 'package:flutter/material.dart';

import '../../models/tasks.dart';
import '../../store/tasks_store.dart';
import '../../utils/status_utils.dart';
import 'day_tasks_page.dart';
import 'task_details_page.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  @override
  void initState() {
    super.initState();
    tasksStore.addListener(_onChanged);
    tasksStore.load();
  }

  @override
  void dispose() {
    tasksStore.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  Future<void> _refresh() async {
    await tasksStore.reloadCurrentWeek();
  }

  String _formatShortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month';
  }

  String _weekLabel(DateTime start, DateTime end) {
    final startLabel = _formatShortDate(start);
    final endLabel = _formatShortDate(end);
    if (start.year == end.year) {
      return '$startLabel - $endLabel ${start.year}';
    }
    return '$startLabel ${start.year} - $endLabel ${end.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekStart = tasksStore.currentWeekStart;
    final weekEnd = tasksStore.currentWeekEnd;
    final weekLabel = _weekLabel(weekStart, weekEnd);
    final prevHandler = tasksStore.loading
        ? null
        : () => tasksStore.loadPreviousWeek();
    final nextHandler = tasksStore.loading
        ? null
        : () => tasksStore.loadNextWeek();

    final children = <Widget>[
      _WeekSwitcher(
        label: weekLabel,
        isLoading: tasksStore.loading,
        onPrevious: prevHandler,
        onNext: nextHandler,
      ),
      const SizedBox(height: 12),
    ];

    if (tasksStore.loading && tasksStore.days.isEmpty) {
      children.add(
        const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    } else if (tasksStore.days.isEmpty) {
      children.add(
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: Center(
            child: Text(
              'Заданий пока нет',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ),
      );
    } else {
      final days = tasksStore.days.reversed.toList();
      for (var i = 0; i < days.length; i++) {
        final day = days[i];
        children.add(_DayCard(day: day, theme: theme));
        if (i != days.length - 1) {
          children.add(const SizedBox(height: 12));
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }
}

class _WeekSwitcher extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _WeekSwitcher({
    required this.label,
    required this.isLoading,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
          tooltip: 'Предыдущая неделя',
          splashRadius: 20,
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Неделя',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (isLoading) ...[
                const SizedBox(height: 4),
                const LinearProgressIndicator(minHeight: 2),
              ],
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
          tooltip: 'Следующая неделя',
          splashRadius: 20,
        ),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  final DayTasks day;
  final ThemeData theme;
  const _DayCard({required this.day, required this.theme});

  @override
  Widget build(BuildContext context) {
    final highlightTomorrow = _isTomorrow(day.date);
    final outlineColor = theme.colorScheme.primary.withOpacity(0.35);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: highlightTomorrow
            ? BorderSide(color: outlineColor, width: 1.5)
            : BorderSide.none,
      ),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DayTasksPage(isoDate: day.isoDate),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        _formatDayLabel(day.date),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  color: theme.colorScheme.outline,
                  tooltip: 'Открыть список дня',
                  splashRadius: 20,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DayTasksPage(isoDate: day.isoDate),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                for (final task in day.tasks)
                  _SubjectPreview(
                    task: task,
                    theme: theme,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TaskDetailsPage(taskId: task.id),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDayLabel(DateTime date) {
    const weekDays = [
      'Понедельник',
      'Вторник',
      'Среда',
      'Четверг',
      'Пятница',
      'Суббота',
      'Воскресенье',
    ];
    const months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    final target = DateTime(date.year, date.month, date.day);
    final dayName = weekDays[target.weekday - 1];
    final month = months[target.month - 1];
    return '$dayName ${target.day} $month';
  }

  bool _isTomorrow(DateTime date) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    return _isSameDay(date, tomorrow);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

}

class _SubjectPreview extends StatelessWidget {
  final TaskItem task;
  final ThemeData theme;
  final VoidCallback onTap;
  const _SubjectPreview({
    required this.task,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = theme.textTheme.bodyMedium?.color?.withOpacity(0.7);
    final text = task.firstLine.isEmpty ? 'Нет описания' : task.firstLine;
    final status = task.aggregatedStatus;
    final statusLabel = taskStatusTitle(status);
    final statusColor = taskStatusColor(status, theme);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: task.subjectColor.withOpacity(0.15),
              foregroundColor: task.subjectColor,
              child: Icon(task.subjectIcon, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.subjectName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (status != TaskStatus.todo) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
