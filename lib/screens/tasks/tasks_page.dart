import 'package:flutter/material.dart';

import '../../models/tasks.dart';
import '../../store/tasks_store.dart';
import 'day_tasks_page.dart';

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
    await tasksStore.load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: tasksStore.days.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final day = tasksStore.days[index];
        return _DayCard(day: day, theme: theme);
      },
    );

    if (tasksStore.loading && tasksStore.days.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (tasksStore.days.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.4,
              child: Center(
                child: Text(
                  'No tasks yet',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(onRefresh: _refresh, child: list);
  }
}

class _DayCard extends StatelessWidget {
  final DayTasks day;
  final ThemeData theme;
  const _DayCard({required this.day, required this.theme});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DayTasksPage(isoDate: day.isoDate)),
        );
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatDayLabel(day.date),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: theme.colorScheme.outline),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                children: [
                  for (final task in day.tasks)
                    _SubjectPreview(task: task, theme: theme),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    if (target == today) return 'Сегодня';
    if (target == today.add(const Duration(days: 1))) return 'Завтра';
    if (target == today.subtract(const Duration(days: 1))) return 'Вчера';
    const months = [
      'янв',
      'фев',
      'мар',
      'апр',
      'май',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек',
    ];
    final month = months[target.month - 1];
    return '${target.day} $month ${target.year}';
  }
}

class _SubjectPreview extends StatelessWidget {
  final TaskItem task;
  final ThemeData theme;
  const _SubjectPreview({required this.task, required this.theme});

  @override
  Widget build(BuildContext context) {
    final secondary = theme.textTheme.bodyMedium?.color?.withOpacity(0.7);
    final text = task.firstLine.isEmpty ? 'Без названия' : task.firstLine;
    return Padding(
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    task.subjectName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
