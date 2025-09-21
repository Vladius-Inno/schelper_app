import 'package:flutter/material.dart';
import '../../models/tasks.dart';
import '../../store/tasks_store.dart';
import 'subtask_screen.dart';

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
  }

  @override
  void dispose() {
    tasksStore.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: tasksStore.subjects.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final subject = tasksStore.subjects[index];
        return _SubjectCard(subject: subject);
      },
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final Subject subject;
  const _SubjectCard({required this.subject});

  @override
  Widget build(BuildContext context) {
    final status = subject.status;
    final progress = '${subject.completedSubtasks} / ${subject.totalSubtasks}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: subject.color.withOpacity(0.15),
                  child: Icon(subject.icon, color: subject.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subject.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      Text('${statusLabelTask(status)} • $progress', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final task in subject.tasks) _TaskBlock(subject: subject, task: task),
          ],
        ),
      ),
    );
  }
}

class _TaskBlock extends StatelessWidget {
  final Subject subject;
  final TaskItem task;
  const _TaskBlock({required this.subject, required this.task});

  @override
  Widget build(BuildContext context) {
    final dateLabel = _formatDate(task.date);
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateLabel, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...task.subtasks.map((st) => _SubtaskTile(subjectId: subject.id, taskId: task.id, subtask: st)),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    if (that == today) return 'Сегодня';
    final yesterday = today.subtract(const Duration(days: 1));
    if (that == yesterday) return 'Вчера';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
  }
}

class _SubtaskTile extends StatelessWidget {
  final String subjectId;
  final String taskId;
  final Subtask subtask;
  const _SubtaskTile({required this.subjectId, required this.taskId, required this.subtask});

  Color _statusColor(BuildContext context, SubtaskStatus s) {
    switch (s) {
      case SubtaskStatus.todo:
        return Theme.of(context).colorScheme.surfaceVariant;
      case SubtaskStatus.inProgress:
        return Theme.of(context).colorScheme.primary.withOpacity(0.15);
      case SubtaskStatus.done:
        return Colors.green.withOpacity(0.15);
      case SubtaskStatus.checked:
        return Colors.purple.withOpacity(0.15);
    }
  }

  IconData _statusIcon(SubtaskStatus s) {
    switch (s) {
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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SubtaskScreen(
              subjectId: subjectId,
              taskId: taskId,
              subtaskId: subtask.id,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _statusColor(context, subtask.status),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(_statusIcon(subtask.status), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                subtask.title,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            if (subtask.parentReaction != null)
              Text(subtask.parentReaction!, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

