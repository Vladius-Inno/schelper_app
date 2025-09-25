import 'dart:math';

import 'package:flutter/material.dart';

import '../models/tasks.dart';
import '../services/subjects_service.dart';
import '../services/tasks_service.dart';

class TasksStore extends ChangeNotifier {
  final TasksService _api;
  final SubjectsService _subjectsApi;
  final Map<int, TaskItem> _taskIndex = {};

  List<DayTasks> days = [];
  int rewards = 0;
  bool loading = false;

  TasksStore({TasksService? api, SubjectsService? subjectsApi})
    : _api = api ?? TasksService(),
      _subjectsApi = subjectsApi ?? SubjectsService();

  DayTasks? findDayByIso(String iso) {
    for (final day in days) {
      if (day.isoDate == iso) {
        return day;
      }
    }
    return null;
  }

  TaskItem? findTask(int taskId) => _taskIndex[taskId];

  Subtask? findSubtask(int taskId, int subtaskId) {
    final task = findTask(taskId);
    if (task == null) return null;
    for (final st in task.subtasks) {
      if (st.id == subtaskId) {
        return st;
      }
    }
    return null;
  }

  Future<void> load({int? subjectId}) async {
    loading = true;
    notifyListeners();
    try {
      final dtos = await _api.fetchTasks(subjectId: subjectId);
      final subjectsList = await _subjectsApi.fetchSubjects();
      final Map<int, String> subjectNames = {
        for (final s in subjectsList) s.id: s.name,
      };
      final palette = [
        const Color(0xFF3B82F6),
        const Color(0xFF10B981),
        const Color(0xFFF59E0B),
        const Color(0xFF8B5CF6),
        const Color(0xFFEF4444),
        const Color(0xFF6366F1),
      ];
      final icons = [
        Icons.calculate_outlined,
        Icons.menu_book_outlined,
        Icons.science_outlined,
        Icons.public_outlined,
        Icons.psychology_alt_outlined,
        Icons.palette_outlined,
      ];

      final Map<String, List<TaskItem>> grouped = {};
      _taskIndex.clear();
      for (final dto in dtos) {
        final subjId = dto.subjectId;
        final name = subjectNames[subjId]?.trim();
        final safeName = (name == null || name.isEmpty)
            ? 'Subject #$subjId'
            : name;
        final color = palette[(max(subjId, 1) - 1) % palette.length];
        final icon = icons[(max(subjId, 1) - 1) % icons.length];
        final task = dto.toModel(
          subjectName: safeName,
          subjectColor: color,
          subjectIcon: icon,
        );
        task.syncStatusFromSubtasks();
        grouped.putIfAbsent(task.dateKey, () => []).add(task);
        _taskIndex[task.id] = task;
      }
      final List<DayTasks> result = [];
      for (final entry in grouped.entries) {
        final tasks = entry.value
          ..sort(
            (a, b) => a.subjectName.toLowerCase().compareTo(
              b.subjectName.toLowerCase(),
            ),
          );
        final date = tasks.first.date;
        result.add(DayTasks(date: date, tasks: tasks));
      }
      result.sort((a, b) => a.date.compareTo(b.date));
      days = result;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> startSubtask(int taskId, int subtaskId) async {
    final subtask = findSubtask(taskId, subtaskId);
    final task = findTask(taskId);
    if (subtask == null || task == null) return;
    final updated = await _api.startSubtask(subtaskId);
    final model = updated.toModel();
    subtask.status = model.status;
    subtask.parentReaction = model.parentReaction;
    task.syncStatusFromSubtasks();
    notifyListeners();
  }

  Future<void> stopSubtask(int taskId, int subtaskId) async {
    // no API endpoint yet; keep method for compatibility
    notifyListeners();
  }

  Future<bool> completeSubtask(int taskId, int subtaskId) async {
    final task = findTask(taskId);
    final subtask = findSubtask(taskId, subtaskId);
    if (task == null || subtask == null) return false;
    final updated = await _api.completeSubtask(subtaskId);
    final updatedModel = updated.toModel();
    final wasDone =
        subtask.status == SubtaskStatus.done ||
        subtask.status == SubtaskStatus.checked;
    subtask.status = updatedModel.status;
    subtask.parentReaction = updatedModel.parentReaction;
    if (!wasDone && subtask.status == SubtaskStatus.done) {
      rewards += 1;
    }
    task.syncStatusFromSubtasks();
    final allDone = task.subtasks.every(
      (s) =>
          s.status == SubtaskStatus.done || s.status == SubtaskStatus.checked,
    );
    if (allDone) {
      rewards += 2;
    }
    notifyListeners();
    return allDone;
  }

  Future<void> toggleTaskStatus(int taskId) async {
    final task = findTask(taskId);
    if (task == null || task.subtasks.isEmpty) {
      return;
    }
    final target = nextTaskStatus(task.aggregatedStatus);
    final SubtaskStatus targetSubtask = subtaskStatusFromTask(target);
    for (final subtask in task.subtasks) {
      final updated = await _api.updateSubtask(
        subtask.id,
        status: statusLabelSubtask(targetSubtask),
      );
      final model = updated.toModel();
      subtask.status = model.status;
      subtask.parentReaction = model.parentReaction;
    }
    task.status = target;
    task.syncStatusFromSubtasks();
    notifyListeners();
  }
}

final TasksStore tasksStore = TasksStore();
