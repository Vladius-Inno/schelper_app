import 'package:flutter/material.dart';

enum SubtaskStatus { todo, inProgress, done, checked }
enum TaskStatus { todo, inProgress, done, checked }

class Subtask {
  final String id;
  final String title;
  SubtaskStatus status;
  String? parentReaction; // e.g. 👍 🌟 🎉

  Subtask({
    required this.id,
    required this.title,
    this.status = SubtaskStatus.todo,
    this.parentReaction,
  });
}

class TaskItem {
  final String id;
  final DateTime date;
  final List<Subtask> subtasks;

  TaskItem({required this.id, required this.date, required this.subtasks});

  TaskStatus get status {
    if (subtasks.any((s) => s.status == SubtaskStatus.checked)) {
      return TaskStatus.checked;
    }
    if (subtasks.every((s) => s.status == SubtaskStatus.done || s.status == SubtaskStatus.checked)) {
      return TaskStatus.done;
    }
    if (subtasks.any((s) => s.status == SubtaskStatus.inProgress || s.status == SubtaskStatus.done)) {
      return TaskStatus.inProgress;
    }
    return TaskStatus.todo;
  }

  int get doneCount =>
      subtasks.where((s) => s.status == SubtaskStatus.done || s.status == SubtaskStatus.checked).length;
}

class Subject {
  final String id;
  final String name;
  final Color color;
  final IconData icon;
  final List<TaskItem> tasks;

  Subject({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    required this.tasks,
  });

  TaskStatus get status {
    final allSubtasks = tasks.expand((t) => t.subtasks).toList();
    if (allSubtasks.isEmpty) return TaskStatus.todo;
    if (allSubtasks.any((s) => s.status == SubtaskStatus.checked)) return TaskStatus.checked;
    if (allSubtasks.every((s) => s.status == SubtaskStatus.done || s.status == SubtaskStatus.checked)) {
      return TaskStatus.done;
    }
    if (allSubtasks.any((s) => s.status == SubtaskStatus.inProgress || s.status == SubtaskStatus.done)) {
      return TaskStatus.inProgress;
    }
    return TaskStatus.todo;
  }

  int get totalSubtasks => tasks.fold(0, (acc, t) => acc + t.subtasks.length);
  int get completedSubtasks => tasks.fold(
      0,
      (acc, t) =>
          acc + t.subtasks.where((s) => s.status == SubtaskStatus.done || s.status == SubtaskStatus.checked).length);
}

String statusLabelTask(TaskStatus s) {
  switch (s) {
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

String statusLabelSubtask(SubtaskStatus s) {
  switch (s) {
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

