import 'package:flutter/material.dart';

import '../../models/tasks.dart';
import '../../store/tasks_store.dart';
import '../../utils/status_utils.dart';
import 'task_details_page.dart';

class DayTasksPage extends StatefulWidget {
  final String isoDate;
  const DayTasksPage({super.key, required this.isoDate});

  @override
  State<DayTasksPage> createState() => _DayTasksPageState();
}

class _DayTasksPageState extends State<DayTasksPage> {
  @override
  void initState() {
    super.initState();
    tasksStore.addListener(_onChanged);
  }

  @override
  void dispose() {
    tasksStore.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  DayTasks? get _day => tasksStore.findDayByIso(widget.isoDate);

  @override
  Widget build(BuildContext context) {
    final day = _day;
    if (day == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Задания')),
        body: const Center(child: Text('Список пуст')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(_formatDayTitle(day.date))),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: day.tasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final task = day.tasks[index];
          return Dismissible(
            key: ValueKey('task-${task.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            secondaryBackground: Container(
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (direction) async {
              if (direction != DismissDirection.endToStart) return false;
              final result = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Удалить задание?'),
                  content: const Text(
                    'Все подзадания будут также удалены. Это действие нельзя отменить.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Отмена'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Удалить'),
                    ),
                  ],
                ),
              );
              if (result != true) return false;
              try {
                final ok = await tasksStore.deleteTask(task.id);
                if (!ok) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Ошибка при удалении. Попробуйте ещё раз',
                          style: TextStyle(color: Colors.white),
                        ),
                        duration: Duration(seconds: 3),
                        backgroundColor: Colors.black87,
                      ),
                    );
                  }
                  return false;
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Задание удалено',
                        style: TextStyle(color: Colors.white),
                      ),
                      duration: Duration(seconds: 2),
                      backgroundColor: Colors.black87,
                    ),
                  );
                }
                return true;
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Ошибка при удалении. Попробуйте ещё раз',
                        style: TextStyle(color: Colors.white),
                      ),
                      duration: Duration(seconds: 3),
                      backgroundColor: Colors.black87,
                    ),
                  );
                }
                return false;
              }
            },
            child: _SubjectTaskCard(task: task),
          );
        },
      ),
    );
  }

  String _formatDayTitle(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$d.$m.$y';
  }
}

class _SubjectTaskCard extends StatelessWidget {
  final TaskItem task;
  const _SubjectTaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = '(${task.doneCount} of ${task.totalSubtasks} done)';
    final status = task.aggregatedStatus;
    final isCompleted = isTaskCompletedStatus(status);
    final statusLabel = taskStatusTitle(status);
    final statusColor = taskStatusColor(status, theme);
    final title = task.firstLine.isEmpty ? (task.title ?? '') : task.firstLine;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TaskDetailsPage(taskId: task.id)),
        );
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: task.subjectColor.withOpacity(0.15),
                    foregroundColor: task.subjectColor,
                    child: Icon(task.subjectIcon),
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
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700),
                              ),
                            ),
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
                        ),
                        const SizedBox(height: 4),
                        if (task.subtasks.isNotEmpty)
                          Text(
                            progress,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: isCompleted
                        ? 'Снять выполнение'
                        : 'Отметить выполненным',
                    onPressed: () async {
                      await tasksStore.toggleTaskCompletion(task.id);
                    },
                    icon: Icon(_statusIcon(status)),
                    color: statusColor,
                  ),
                ],
              ),
              if (title.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(title, style: theme.textTheme.titleSmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

IconData _statusIcon(TaskStatus status) {
  switch (status) {
    case TaskStatus.todo:
      return Icons.radio_button_unchecked;
    case TaskStatus.inProgress:
      return Icons.timelapse;
    case TaskStatus.done:
      return Icons.check_circle_outline;
    case TaskStatus.checked:
      return Icons.verified_outlined;
  }
}
