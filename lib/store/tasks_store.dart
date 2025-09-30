import 'dart:math';

import 'package:flutter/material.dart';

import '../models/tasks.dart';
import '../services/subjects_service.dart';
import '../services/tasks_service.dart';

class TasksStore extends ChangeNotifier {
  final TasksService _api;
  final SubjectsService _subjectsApi;
  final Map<int, TaskItem> _taskIndex = {};
  int? _currentSubjectId;

  List<DayTasks> days = [];
  int rewards = 0;
  bool loading = false;
  DateTime? _currentWeekStart;

  DateTime get currentWeekStart =>
      _currentWeekStart ?? _normalizeWeekStart(DateTime.now());

  DateTime get currentWeekEnd => currentWeekStart.add(const Duration(days: 6));

  bool get isOnCurrentWeek {
    final normalizedNow = _normalizeWeekStart(DateTime.now());
    final current = currentWeekStart;
    return current.year == normalizedNow.year &&
        current.month == normalizedNow.month &&
        current.day == normalizedNow.day;
  }

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

  bool _isTaskCompleted(TaskItem task) {
    final status = task.aggregatedStatus;
    return status == TaskStatus.done || status == TaskStatus.checked;
  }

  bool _isSubtaskCompleted(Subtask subtask) {
    return subtask.status == SubtaskStatus.done ||
        subtask.status == SubtaskStatus.checked;
  }

  DateTime _normalizeWeekStart(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final delta = (normalized.weekday + 6) % 7;
    return normalized.subtract(Duration(days: delta));
  }

  String _toIsoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DateTime _parseIsoDate(String iso) {
    final parts = iso.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  Future<bool> _hasTasksForWeek({
    required DateTime weekStart,
    int? subjectId,
  }) async {
    final startIso = _toIsoDate(weekStart);
    final endIso = _toIsoDate(weekStart.add(const Duration(days: 6)));
    final tasks = await _api.fetchTasks(
      subjectId: subjectId,
      startDate: startIso,
      endDate: endIso,
    );
    return tasks.isNotEmpty;
  }

  Future<DateTime?> _findTaskDateBeyondWeek({
    required DateTime weekStart,
    required int direction,
    int? subjectId,
  }) async {
    assert(direction == -1 || direction == 1);
    final weekEnd = weekStart.add(const Duration(days: 6));
    if (direction > 0) {
      final from = weekEnd.add(const Duration(days: 1));
      final tasks = await _api.fetchTasks(
        subjectId: subjectId,
        startDate: _toIsoDate(from),
      );
      DateTime? earliest;
      for (final dto in tasks) {
        final date = _parseIsoDate((dto as dynamic).date as String);
        if (!date.isAfter(weekEnd)) {
          continue;
        }
        if (earliest == null || date.isBefore(earliest)) {
          earliest = date;
        }
      }
      return earliest == null ? null : _normalizeWeekStart(earliest);
    }
    final to = weekStart.subtract(const Duration(days: 1));
    final tasks = await _api.fetchTasks(
      subjectId: subjectId,
      endDate: _toIsoDate(to),
    );
    DateTime? latest;
    for (final dto in tasks) {
      final date = _parseIsoDate((dto as dynamic).date as String);
      if (!date.isBefore(weekStart)) {
        continue;
      }
      if (latest == null || date.isAfter(latest)) {
        latest = date;
      }
    }
    return latest == null ? null : _normalizeWeekStart(latest);
  }

  Future<void> load({int? subjectId, DateTime? weekStart}) async {
    _currentSubjectId = subjectId;
    loading = true;
    notifyListeners();
    try {
      final targetWeekStart = _normalizeWeekStart(
        weekStart ?? _currentWeekStart ?? DateTime.now(),
      );
      _currentWeekStart = targetWeekStart;
      final startIso = _toIsoDate(targetWeekStart);
      final endIso = _toIsoDate(targetWeekStart.add(const Duration(days: 6)));
      final taskDtos = await _api.fetchTasks(
        subjectId: subjectId,
        startDate: startIso,
        endDate: endIso,
      );
      int? subjectChildId;
      final childIds = <int>{};
      final subjectIds = <int>{};
      for (final dto in taskDtos) {
        childIds.add(dto.childId);
        subjectIds.add(dto.subjectId);
      }
      if (childIds.length == 1) {
        subjectChildId = childIds.first;
      }

      final subjectsList = await _subjectsApi.fetchSubjects(
        childId: subjectChildId,
      );
      final Map<int, String> subjectNames = {
        for (final s in subjectsList) s.id: s.name.trim(),
      };
      if (subjectNames.length < subjectIds.length) {
        final fallbackSubjects = await _subjectsApi.fetchSubjects();
        for (final s in fallbackSubjects) {
          subjectNames.putIfAbsent(s.id, () => s.name.trim());
        }
      }

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
      for (final dto in taskDtos) {
        final subjId = dto.subjectId;
        final name = subjectNames[subjId];
        final displayName = (name == null || name.isEmpty)
            ? 'Subject #$subjId'
            : name;
        final color = palette[(max(subjId, 1) - 1) % palette.length];
        final icon = icons[(max(subjId, 1) - 1) % icons.length];
        final task = dto.toModel(
          subjectName: displayName,
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

  Future<void> _navigateToWeekWithTasks(int direction) async {
    if (direction == 0 || loading) {
      return;
    }
    final subjectId = _currentSubjectId;
    final currentStart = currentWeekStart;
    final fallback = currentStart.add(Duration(days: 7 * direction));
    loading = true;
    notifyListeners();
    try {
      if (await _hasTasksForWeek(
        weekStart: fallback,
        subjectId: subjectId,
      )) {
        await load(
          subjectId: subjectId,
          weekStart: fallback,
        );
        return;
      }
      final alternativeWeek = await _findTaskDateBeyondWeek(
        weekStart: fallback,
        direction: direction,
        subjectId: subjectId,
      );
      if (alternativeWeek == null) {
        return;
      }
      await load(
        subjectId: subjectId,
        weekStart: alternativeWeek,
      );
    } finally {
      if (loading) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadPreviousWeek() async {
    await _navigateToWeekWithTasks(-1);
  }

  Future<void> loadNextWeek() async {
    await _navigateToWeekWithTasks(1);
  }

  Future<void> loadCurrentWeek() async {
    await load(weekStart: DateTime.now());
  }

  Future<void> reloadCurrentWeek() async {
    await load(weekStart: currentWeekStart);
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
    final wasDone = _isSubtaskCompleted(subtask);
    subtask.status = updatedModel.status;
    subtask.parentReaction = updatedModel.parentReaction;
    if (!wasDone && _isSubtaskCompleted(subtask)) {
      rewards += 1;
    }
    task.syncStatusFromSubtasks();
    final allDone = task.subtasks.every(_isSubtaskCompleted);
    if (allDone) {
      rewards += 2;
    }
    notifyListeners();
    return allDone;
  }

  Future<void> setSubtaskStatus(
    int taskId,
    int subtaskId,
    SubtaskStatus status,
  ) async {
    final task = findTask(taskId);
    final subtask = findSubtask(taskId, subtaskId);
    if (task == null || subtask == null) return;
    final wasTaskDone = _isTaskCompleted(task);
    final wasDone = _isSubtaskCompleted(subtask);
    final updated = await _api.updateSubtask(
      subtaskId,
      status: statusLabelSubtask(status),
    );
    final model = updated.toModel();
    subtask.status = model.status;
    subtask.parentReaction = model.parentReaction;
    task.syncStatusFromSubtasks();
    final isDoneNow = _isSubtaskCompleted(subtask);
    if (!wasDone && isDoneNow) {
      rewards += 1;
      if (task.subtasks.every(_isSubtaskCompleted) && !wasTaskDone) {
        rewards += 2;
      }
    }
    notifyListeners();
  }

  Future<void> setTaskCompletion(int taskId, bool completed) async {
    final task = findTask(taskId);
    if (task == null) return;
    if (task.subtasks.isEmpty) {
      final status = completed ? TaskStatus.done : TaskStatus.todo;
      final updatedStatus = await _api.updateTaskStatus(
        taskId,
        status: statusLabelTask(status),
      );
      task.status = taskStatusFromStr(updatedStatus);
      task.syncStatusFromSubtasks();
      notifyListeners();
      return;
    }
    final SubtaskStatus target = completed
        ? SubtaskStatus.done
        : SubtaskStatus.todo;
    final wasCompleted = task.subtasks.every(_isSubtaskCompleted);
    for (final subtask in task.subtasks) {
      final wasDone = _isSubtaskCompleted(subtask);
      final updated = await _api.updateSubtask(
        subtask.id,
        status: statusLabelSubtask(target),
      );
      final model = updated.toModel();
      subtask.status = model.status;
      subtask.parentReaction = model.parentReaction;
      if (!wasDone && _isSubtaskCompleted(subtask)) {
        rewards += 1;
      }
    }
    task.status = completed ? TaskStatus.done : TaskStatus.todo;
    task.syncStatusFromSubtasks();
    if (completed && !wasCompleted && _isTaskCompleted(task)) {
      rewards += 2;
    }
    notifyListeners();
  }

  Future<void> toggleTaskCompletion(int taskId) async {
    final task = findTask(taskId);
    if (task == null) return;
    final shouldComplete = !_isTaskCompleted(task);
    await setTaskCompletion(taskId, shouldComplete);
  }
}

final TasksStore tasksStore = TasksStore();
