import 'package:flutter/material.dart';

enum SubtaskStatus { todo, inProgress, done, checked }

enum TaskStatus { todo, inProgress, done, checked }

TaskStatus taskStatusFromStr(String value) {
  switch (value) {
    case 'in_progress':
      return TaskStatus.inProgress;
    case 'done':
      return TaskStatus.done;
    case 'checked':
      return TaskStatus.checked;
    case 'todo':
    default:
      return TaskStatus.todo;
  }
}

String statusLabelTask(TaskStatus status) {
  switch (status) {
    case TaskStatus.todo:
      return 'todo';
    case TaskStatus.inProgress:
      return 'in_progress';
    case TaskStatus.done:
      return 'done';
    case TaskStatus.checked:
      return 'checked';
  }
}

SubtaskStatus subtaskStatusFromStr(String value) {
  switch (value) {
    case 'in_progress':
      return SubtaskStatus.inProgress;
    case 'done':
      return SubtaskStatus.done;
    case 'checked':
      return SubtaskStatus.checked;
    case 'todo':
    default:
      return SubtaskStatus.todo;
  }
}

String statusLabelSubtask(SubtaskStatus status) {
  switch (status) {
    case SubtaskStatus.todo:
      return 'todo';
    case SubtaskStatus.inProgress:
      return 'in_progress';
    case SubtaskStatus.done:
      return 'done';
    case SubtaskStatus.checked:
      return 'checked';
  }
}

class Subtask {
  final int id;
  final String title;
  SubtaskStatus status;
  String? parentReaction;

  Subtask({
    required this.id,
    required this.title,
    this.status = SubtaskStatus.todo,
    this.parentReaction,
  });
}

class TaskItem {
  final int id;
  final int subjectId;
  final String subjectName;
  final Color subjectColor;
  final IconData subjectIcon;
  final DateTime date;
  final String? title;
  final List<Subtask> subtasks;
  TaskStatus status;

  TaskItem({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    required this.subjectColor,
    required this.subjectIcon,
    required this.date,
    required this.subtasks,
    required this.status,
    this.title,
  });

  int get totalSubtasks => subtasks.length;

  int get doneCount => subtasks
      .where(
        (s) =>
            s.status == SubtaskStatus.done || s.status == SubtaskStatus.checked,
      )
      .length;

  TaskStatus get aggregatedStatus {
    if (subtasks.isEmpty) {
      return status;
    }
    final statuses = subtasks.map((s) => s.status).toSet();
    if (statuses.isEmpty) {
      return TaskStatus.todo;
    }
    if (statuses.every((s) => s == SubtaskStatus.checked)) {
      return TaskStatus.checked;
    }
    if (statuses.every(
      (s) => s == SubtaskStatus.done || s == SubtaskStatus.checked,
    )) {
      return TaskStatus.done;
    }
    if (statuses.any(
      (s) =>
          s == SubtaskStatus.inProgress ||
          s == SubtaskStatus.done ||
          s == SubtaskStatus.checked,
    )) {
      return TaskStatus.inProgress;
    }
    return TaskStatus.todo;
  }

  void syncStatusFromSubtasks() {
    status = aggregatedStatus;
  }

  String get firstLine {
    final value = title?.trim();
    if (value != null && value.isNotEmpty) {
      final first = value.split('\n').first.trim();
      if (first.isNotEmpty) {
        return first;
      }
    }
    if (subtasks.isEmpty) {
      return '';
    }
    return subtasks.first.title.trim();
  }

  String get dateKey {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class DayTasks {
  final DateTime date;
  final List<TaskItem> tasks;

  DayTasks({required this.date, required this.tasks});

  String get isoDate {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

SubtaskStatus subtaskStatusFromTask(TaskStatus status) {
  switch (status) {
    case TaskStatus.todo:
      return SubtaskStatus.todo;
    case TaskStatus.inProgress:
      return SubtaskStatus.inProgress;
    case TaskStatus.done:
      return SubtaskStatus.done;
    case TaskStatus.checked:
      return SubtaskStatus.checked;
  }
}

TaskStatus nextTaskStatus(TaskStatus current) {
  switch (current) {
    case TaskStatus.todo:
      return TaskStatus.inProgress;
    case TaskStatus.inProgress:
      return TaskStatus.done;
    case TaskStatus.done:
      return TaskStatus.checked;
    case TaskStatus.checked:
      return TaskStatus.todo;
  }
}
