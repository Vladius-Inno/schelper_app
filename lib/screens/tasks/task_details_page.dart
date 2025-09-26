import 'package:flutter/material.dart';

import '../../models/tasks.dart';
import '../../store/tasks_store.dart';
import '../../utils/status_utils.dart';
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
    final isCompleted = isTaskCompletedStatus(status);
    final statusLabel = taskStatusTitle(status);
    final statusColor = taskStatusColor(status, theme);
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                                      fontWeight: FontWeight.w700,
                                    ),
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
                            ? 'Снять отметку выполнения'
                            : 'Отметить задачу выполненной',
                        onPressed: () async {
                          await tasksStore.toggleTaskCompletion(task.id);
                        },
                        icon: Icon(_statusIcon(status)),
                        color: statusColor,
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
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            for (final subtask in task.subtasks)
              _SubtaskTile(taskId: task.id, subtask: subtask, theme: theme),
          ],
        ],
      ),
    );
  }
}

class _SubtaskTile extends StatelessWidget {
  final int taskId;
  final Subtask subtask;
  final ThemeData theme;
  const _SubtaskTile({required this.taskId, required this.subtask, required this.theme});

  bool get _isCompleted => isSubtaskCompletedStatus(subtask.status);

  @override
  Widget build(BuildContext context) {
    final reaction = subtask.parentReaction?.trim();
    final statusLabel = subtaskStatusTitle(subtask.status);
    final statusColor = subtaskStatusColor(subtask.status, theme);
    final hasStatusBadge = subtask.status != SubtaskStatus.todo;
    final hasReaction = reaction != null && reaction.isNotEmpty;
    final titleStyle = _isCompleted
        ? theme.textTheme.bodyMedium?.copyWith(
            decoration: TextDecoration.lineThrough,
            color: theme.colorScheme.outline,
          )
        : theme.textTheme.bodyMedium;

    final subtitleChildren = <Widget>[];
    if (hasStatusBadge) {
      subtitleChildren.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
      );
    }
    if (hasReaction) {
      if (subtitleChildren.isNotEmpty) {
        subtitleChildren.add(const SizedBox(height: 4));
      }
      subtitleChildren.add(
        Text('Отзыв: $reaction', style: theme.textTheme.bodySmall),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Checkbox(
          value: _isCompleted,
          onChanged: (checked) async {
            if (checked == null) return;
            final target = checked ? SubtaskStatus.done : SubtaskStatus.todo;
            await tasksStore.setSubtaskStatus(taskId, subtask.id, target);
          },
        ),
        title: Text(subtask.title, style: titleStyle),
        subtitle: subtitleChildren.isEmpty
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: subtitleChildren,
              ),
        trailing: IconButton(
          icon: const Icon(Icons.timer_outlined),
          tooltip: 'Открыть таймер',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SubtaskScreen(taskId: taskId, subtaskId: subtask.id),
              ),
            );
          },
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SubtaskScreen(taskId: taskId, subtaskId: subtask.id),
            ),
          );
        },
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
