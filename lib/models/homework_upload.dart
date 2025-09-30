enum HomeworkResultStatus { created, updated, duplicate }

HomeworkResultStatus homeworkStatusFromString(String value) {
  switch (value) {
    case 'updated':
      return HomeworkResultStatus.updated;
    case 'duplicate':
      return HomeworkResultStatus.duplicate;
    case 'created':
    default:
      return HomeworkResultStatus.created;
  }
}

class HomeworkUploadResult {
  final HomeworkResultStatus status;
  final int taskId;
  final int subjectId;
  final HomeworkTaskPayload? task;

  const HomeworkUploadResult({
    required this.status,
    required this.taskId,
    required this.subjectId,
    this.task,
  });

  factory HomeworkUploadResult.fromJson(Map<String, dynamic> json) {
    final statusValue = json['status']?.toString() ?? 'created';

    // Support both legacy shape {status, task_id, subject_id, task?}
    // and new shape {status, task: {...}} as returned by API.
    HomeworkTaskPayload? taskPayload;
    final taskRaw = json['task'];
    if (taskRaw is Map) {
      taskPayload = HomeworkTaskPayload.fromJson(
        Map<String, dynamic>.from(taskRaw as Map),
      );
    }

    int parseInt(dynamic v) {
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    final int resolvedTaskId = json.containsKey('task_id')
        ? parseInt(json['task_id'])
        : (taskPayload?.id ?? 0);

    final int resolvedSubjectId = json.containsKey('subject_id')
        ? parseInt(json['subject_id'])
        : (taskPayload?.subjectId ?? 0);

    return HomeworkUploadResult(
      status: homeworkStatusFromString(statusValue),
      taskId: resolvedTaskId,
      subjectId: resolvedSubjectId,
      task: taskPayload,
    );
  }
}

class HomeworkTaskPayload {
  final int id;
  final int childId;
  final int subjectId;
  final DateTime? date;
  final String? title;
  final String? hash;
  final String status;
  final List<HomeworkSubtaskPayload> subtasks;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const HomeworkTaskPayload({
    required this.id,
    required this.childId,
    required this.subjectId,
    required this.status,
    required this.subtasks,
    this.date,
    this.title,
    this.hash,
    this.createdAt,
    this.updatedAt,
  });

  factory HomeworkTaskPayload.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? value) {
      if (value == null || value.isEmpty) return null;
      return DateTime.tryParse(value);
    }

    final subtasksJson = json['subtasks'] as List<dynamic>?;
    return HomeworkTaskPayload(
      id: json['id'] as int,
      childId: json['child_id'] as int,
      subjectId: json['subject_id'] as int,
      status: json['status']?.toString() ?? 'todo',
      title: json['title']?.toString(),
      hash: json['hash']?.toString(),
      date: parseDate(json['date']?.toString()),
      createdAt: parseDate(json['created_at']?.toString()),
      updatedAt: parseDate(json['updated_at']?.toString()),
      subtasks: subtasksJson == null
          ? const []
          : subtasksJson
                .map(
                  (e) => HomeworkSubtaskPayload.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList(growable: false),
    );
  }
}

class HomeworkSubtaskPayload {
  final int id;
  final String title;
  final String type;
  final String status;
  final int? position;

  const HomeworkSubtaskPayload({
    required this.id,
    required this.title,
    required this.type,
    required this.status,
    this.position,
  });

  factory HomeworkSubtaskPayload.fromJson(Map<String, dynamic> json) {
    return HomeworkSubtaskPayload(
      id: json['id'] as int,
      title: json['title']?.toString() ?? '',
      type: json['type']?.toString() ?? 'text',
      status: json['status']?.toString() ?? 'todo',
      position: json['position'] as int?,
    );
  }
}
