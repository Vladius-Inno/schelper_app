import 'package:flutter/material.dart';

import '../models/tasks.dart';

bool isTaskCompletedStatus(TaskStatus status) {
  return status == TaskStatus.done || status == TaskStatus.checked;
}

bool isSubtaskCompletedStatus(SubtaskStatus status) {
  return status == SubtaskStatus.done || status == SubtaskStatus.checked;
}

String taskStatusTitle(TaskStatus status) {
  switch (status) {
    case TaskStatus.todo:
      return 'Не начато';
    case TaskStatus.inProgress:
      return 'В процессе';
    case TaskStatus.done:
      return 'Выполнено';
    case TaskStatus.checked:
      return 'Проверено';
  }
}

Color taskStatusColor(TaskStatus status, ThemeData theme) {
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

String subtaskStatusTitle(SubtaskStatus status) {
  switch (status) {
    case SubtaskStatus.todo:
      return 'Не начато';
    case SubtaskStatus.inProgress:
      return 'В процессе';
    case SubtaskStatus.done:
      return 'Выполнено';
    case SubtaskStatus.checked:
      return 'Проверено';
  }
}

Color subtaskStatusColor(SubtaskStatus status, ThemeData theme) {
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
