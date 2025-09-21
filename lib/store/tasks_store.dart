import 'dart:math';
import 'package:flutter/material.dart';
import '../models/tasks.dart';

class TasksStore extends ChangeNotifier {
  final List<Subject> subjects;
  int rewards = 0; // points

  TasksStore({List<Subject>? seed}) : subjects = seed ?? _mockSubjects();

  Subject? findSubject(String subjectId) {
    for (final s in subjects) {
      if (s.id == subjectId) return s;
    }
    return null;
  }

  TaskItem? findTask(String subjectId, String taskId) {
    final subject = findSubject(subjectId);
    if (subject == null) return null;
    for (final t in subject.tasks) {
      if (t.id == taskId) return t;
    }
    return null;
  }

  Subtask? findSubtask(String subjectId, String taskId, String subtaskId) {
    final task = findTask(subjectId, taskId);
    if (task == null) return null;
    for (final st in task.subtasks) {
      if (st.id == subtaskId) return st;
    }
    return null;
  }

  void startSubtask(String subjectId, String taskId, String subtaskId) {
    final s = findSubtask(subjectId, taskId, subtaskId);
    if (s == null) return;
    if (s.status == SubtaskStatus.todo) {
      s.status = SubtaskStatus.inProgress;
      notifyListeners();
    }
  }

  void stopSubtask(String subjectId, String taskId, String subtaskId) {
    // no status change on stop; remains inProgress or todo
    notifyListeners();
  }

  /// Mark subtask done and award reward. Returns true if the whole task is now complete.
  bool completeSubtask(String subjectId, String taskId, String subtaskId) {
    final task = findTask(subjectId, taskId);
    final s = findSubtask(subjectId, taskId, subtaskId);
    if (task == null || s == null) return false;
    if (s.status == SubtaskStatus.done || s.status == SubtaskStatus.checked) {
      return task.subtasks
          .every((x) => x.status == SubtaskStatus.done || x.status == SubtaskStatus.checked);
    }
    s.status = SubtaskStatus.done;
    rewards += 1; // base reward per subtask
    final allDone = task.subtasks
        .every((x) => x.status == SubtaskStatus.done || x.status == SubtaskStatus.checked);
    if (allDone) {
      rewards += 2; // bonus for task completion
    }
    notifyListeners();
    return allDone;
  }

  static List<Subject> _mockSubjects() {
    final now = DateTime.now();
    Subject math = Subject(
      id: 'subj_math',
      name: 'Математика',
      color: const Color(0xFF3B82F6),
      icon: Icons.calculate_outlined,
      tasks: [
        TaskItem(
          id: 'm_${now.toIso8601String().substring(0, 10)}',
          date: DateTime(now.year, now.month, now.day),
          subtasks: [
            Subtask(id: 'm1', title: 'Упр. 4 (стр. 15)'),
            Subtask(id: 'm2', title: 'Пример 3 (стр. 16)'),
          ],
        ),
        TaskItem(
          id: 'm_prev',
          date: DateTime(now.year, now.month, max(1, now.day - 1)),
          subtasks: [
            Subtask(id: 'm3', title: 'Повторить таблицу умножения'),
          ],
        ),
      ],
    );
    Subject rus = Subject(
      id: 'subj_rus',
      name: 'Русский',
      color: const Color(0xFF10B981),
      icon: Icons.menu_book_outlined,
      tasks: [
        TaskItem(
          id: 'r_${now.toIso8601String().substring(0, 10)}',
          date: DateTime(now.year, now.month, now.day),
          subtasks: [
            Subtask(id: 'r1', title: 'Правописание ЖИ-ШИ'),
            Subtask(id: 'r2', title: 'Диктант №2'),
          ],
        ),
      ],
    );
    return [math, rus];
  }
}

final TasksStore tasksStore = TasksStore();

