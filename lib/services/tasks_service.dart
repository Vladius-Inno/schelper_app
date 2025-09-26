import 'package:flutter/material.dart';

import '../models/tasks.dart';
import 'authorized_api_client.dart';

class TasksService {
  final AuthorizedApiClient _client;
  TasksService({AuthorizedApiClient? client})
    : _client = client ?? AuthorizedApiClient();

  Future<List<_TaskDto>> fetchTasks({
    int? subjectId,
    String? startDate,
    String? endDate,
  }) async {
    final query = <String>[];
    if (subjectId != null) {
      query.add('subject_id=$subjectId');
    }
    if (startDate != null) {
      query.add('start_date=$startDate');
    }
    if (endDate != null) {
      query.add('end_date=$endDate');
    }
    final suffix = query.isEmpty ? '' : '?${query.join('&')}';
    final data = await _client.getAny('/tasks$suffix');
    if (data is List) {
      return data
          .map((e) => _TaskDto.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    final list = (data is Map<String, dynamic>)
        ? data['data'] as List<dynamic>?
        : null;
    if (list == null) {
      return [];
    }
    return list
        .map((e) => _TaskDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<_SubtaskDto> startSubtask(int subtaskId) async {
    final data = await _client.postAny('/tasks/subtasks/$subtaskId/start', {});
    return _SubtaskDto.fromJson(Map<String, dynamic>.from(data));
  }

  Future<_SubtaskDto> completeSubtask(int subtaskId) async {
    final data = await _client.postAny(
      '/tasks/subtasks/$subtaskId/complete',
      {},
    );
    return _SubtaskDto.fromJson(Map<String, dynamic>.from(data));
  }

  Future<_SubtaskDto> updateSubtask(
    int subtaskId, {
    String? status,
    String? title,
    String? reaction,
  }) async {
    final body = <String, dynamic>{
      if (status != null) 'status': status,
      if (title != null) 'title': title,
      if (reaction != null) 'parent_reaction': reaction,
    };
    final data = await _client.patchAny('/tasks/subtasks/$subtaskId', body);
    return _SubtaskDto.fromJson(Map<String, dynamic>.from(data));
  }

  Future<String> updateTaskStatus(int taskId, {required String status}) async {
    final data = await _client.patchAny('/tasks/$taskId', {'status': status});
    final map = Map<String, dynamic>.from(data as Map);
    return map['status'] as String;
  }
}

class _SubtaskDto {
  final int id;
  final String title;
  final String status;
  final String? parentReaction;
  final int? position;
  _SubtaskDto({
    required this.id,
    required this.title,
    required this.status,
    this.parentReaction,
    this.position,
  });

  factory _SubtaskDto.fromJson(Map<String, dynamic> json) => _SubtaskDto(
    id: json['id'] as int,
    title: json['title'] as String,
    status: json['status'] as String,
    parentReaction: json['parent_reaction'] as String?,
    position: json['position'] as int?,
  );

  Subtask toModel() => Subtask(
    id: id,
    title: title,
    status: subtaskStatusFromStr(status),
    parentReaction: parentReaction,
  );
}

class _TaskDto {
  final int id;
  final int childId;
  final int subjectId;
  final String date;
  final String? title;
  final String status;
  final List<_SubtaskDto> subtasks;
  _TaskDto({
    required this.id,
    required this.childId,
    required this.subjectId,
    required this.date,
    required this.title,
    required this.status,
    required this.subtasks,
  });

  factory _TaskDto.fromJson(Map<String, dynamic> json) => _TaskDto(
    id: json['id'] as int,
    childId: json['child_id'] as int,
    subjectId: json['subject_id'] as int,
    date: json['date'] as String,
    title: json['title'] as String?,
    status: json['status'] as String,
    subtasks: (json['subtasks'] as List<dynamic>? ?? const [])
        .map((e) => _SubtaskDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );

  TaskItem toModel({
    required String subjectName,
    required Color subjectColor,
    required IconData subjectIcon,
  }) {
    final parts = date.split('-');
    final d = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final items = subtasks.map((s) => s.toModel()).toList();
    final task = TaskItem(
      id: id,
      subjectId: subjectId,
      subjectName: subjectName,
      subjectColor: subjectColor,
      subjectIcon: subjectIcon,
      date: d,
      title: title,
      status: taskStatusFromStr(status),
      subtasks: items,
    );
    task.syncStatusFromSubtasks();
    return task;
  }
}
