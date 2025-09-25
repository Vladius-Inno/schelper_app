import 'package:flutter/material.dart';

import '../../models/tasks.dart';
import '../../store/tasks_store.dart';
import 'subtask_screen.dart';

class TaskDetailsPage extends StatefulWidget {
  final int taskId;
  const TaskDetailsPage({super.key, required this.taskId});

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
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

  TaskItem? get _task => tasksStore.findTask(widget.taskId);

  @override
  Widget build(BuildContext context) {
    final task = _task;
    if (task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Задача')),
        body: const Center(child: Text('Задача не найдена')),
      );
    }
    final theme = Theme.of(context);
    final status = task.aggregatedStatus;
    final progress = '(${task.doneCount} of ${task.totalSubtasks} done)';
    final title = task.title?.trim();
    final hasTitle = title != null && title.isNotEmpty;
    final hasSubtasks = task.subtasks.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(task.subjectName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
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
                            Text(
                              task.subjectName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
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
                        tooltip: 'Сменить статус',
                        onPressed: hasSubtasks
                            ? () async {
                                await tasksStore.toggleTaskStatus(task.id);
                              }
                            : null,
                        icon: Icon(_statusIcon(status)),
                        color: _statusColor(theme, status),
                      ),
                    ],
                  ),
                  if (hasTitle) ...[
                    const SizedBox(height: 12),
                    Text(title!, style: theme.textTheme.titleSmall),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {},
            child: const Text('Разбить на подзадачи'),
          ),
          if (hasSubtasks) ...[
            const SizedBox(height: 24),
            Text(
              'Подзадачи',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            for (final subtask in task.subtasks)
              _SubtaskTile(taskId: task.id, subtask: subtask, theme: theme),
          ],
        ],
      ),
    );
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

  Color _statusColor(ThemeData theme, TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return theme.colorScheme.outline;
      case TaskStatus.inProgress:
        return theme.colorScheme.primary;
      case TaskStatus.done:
        return Colors.green;
      case TaskStatus.checked:
        return Colors.purple;
    }
  }
}

class _SubtaskTile extends StatelessWidget {
  final int taskId;
  final Subtask subtask;
  final ThemeData theme;
  const _SubtaskTile({
    required this.taskId,
    required this.subtask,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _statusIcon(subtask.status);
    final color = _statusColor(subtask.status);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, color: color),
        title: Text(subtask.title),
        subtitle:
            subtask.parentReaction == null || subtask.parentReaction!.isEmpty
            ? null
            : Text('Отзыв: ${subtask.parentReaction!}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  SubtaskScreen(taskId: taskId, subtaskId: subtask.id),
            ),
          );
        },
      ),
    );
  }

  IconData _statusIcon(SubtaskStatus status) {
    switch (status) {
      case SubtaskStatus.todo:
        return Icons.radio_button_unchecked;
      case SubtaskStatus.inProgress:
        return Icons.timelapse;
      case SubtaskStatus.done:
        return Icons.check_circle_outline;
      case SubtaskStatus.checked:
        return Icons.verified_outlined;
    }
  }

  Color _statusColor(SubtaskStatus status) {
    switch (status) {
      case SubtaskStatus.todo:
        return theme.colorScheme.outline;
      case SubtaskStatus.inProgress:
        return theme.colorScheme.primary;
      case SubtaskStatus.done:
        return Colors.green;
      case SubtaskStatus.checked:
        return Colors.purple;
    }
  }
}
