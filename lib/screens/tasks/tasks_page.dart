import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/tasks.dart';
import '../../models/homework_upload.dart';
import '../../store/tasks_store.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/homework_job_service.dart' as hwjobs;
import '../../services/job_polling_service.dart';
import '../../widgets/import_status_banner.dart';
import '../../models/job.dart';
import '../../config.dart';
import '../../utils/status_utils.dart';
import 'day_tasks_page.dart';
import 'task_details_page.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  bool _fabExpanded = false;
  List<HomeworkUploadResult>? _lastUploadResults;
  // Import job tracking
  bool _showImportBanner = false;
  String _importBannerMessage = '';
  int? _activeJobId;
  hwjobs.HomeworkService? _jobService;
  String? _authToken;

  @override
  void initState() {
    super.initState();
    tasksStore.addListener(_onChanged);
    tasksStore.load();
    // Prepare job service and resume pending jobs, if any
    _setupJobServiceAndResume();
  }

  @override
  void dispose() {
    tasksStore.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  Future<void> _refresh() async {
    await tasksStore.reloadCurrentWeek();
  }

  void _toggleFab() {
    setState(() => _fabExpanded = !_fabExpanded);
  }

  void _collapseFab() {
    if (_fabExpanded) {
      setState(() => _fabExpanded = false);
    }
  }

  Future<void> _setupJobServiceAndResume() async {
    await _ensureJobServiceReady();
    final service = _jobService;
    if (service == null) return;
    await service.resumePendingJobs(
      onUpdate: (job, elapsed) {
        setState(() {
          _activeJobId = job.id;
          _showImportBanner = true;
          _importBannerMessage = statusMessageForElapsed(elapsed);
        });
      },
      onDone: (job) async {
        await _handleJobCompletion(job);
      },
      onFailed: (job) async {
        await _handleJobFailure(job);
      },
    );
    
    // Hand off to background job; stop here
    return;
  }

  Future<void> _ensureJobServiceReady() async {
    if (_jobService != null) return;
    // Fetch token once
    _authToken ??= await AuthService().getAccessToken();
    _jobService = hwjobs.HomeworkService(
      baseUrl: AppConfig.baseUrl,
      headersProvider: () => {
        if (_authToken != null) 'Authorization': 'Bearer ${_authToken!}',
      },
    );
  }

  void _startPolling(JobOut job) {
    setState(() {
      _activeJobId = job.id;
      _showImportBanner = true;
      _importBannerMessage = statusMessageForElapsed(const Duration(seconds: 0));
    });
    final service = _jobService;
    if (service == null) return;
    service.startPollingJob(
      jobId: job.id,
      onUpdate: (j, elapsed) {
        setState(() {
          _importBannerMessage = statusMessageForElapsed(elapsed);
        });
      },
      onDone: (j) async {
        await _handleJobCompletion(j);
      },
      onFailed: (j) async {
        await _handleJobFailure(j);
      },
    );
  }

  Future<void> _handleJobCompletion(JobOut job) async {
    if (!mounted) return;
    // Hide banner
    setState(() {
      _showImportBanner = false;
      _importBannerMessage = '';
      _activeJobId = null;
    });
    // Parse results
    final results = _parseResultsFromJob(job);
    
    /*
    if (false && results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Импорт завершён, но результатов нет')),
      );
      return;
    }
    */
    // Refresh tasks (current week by default)
    await tasksStore.reloadCurrentWeek();
    // Show existing result dialog
    final action = await _showUploadResultsDialogV3(results);
    if (!mounted) return;
    if (action == _UploadAction.goTo) {
      final iso = _resolveIsoDateFromResultsV2(results);
      if (iso != null) {
        // Ensure the week containing the imported homework is loaded
        final date = DateTime.tryParse(iso);
        if (date != null) {
          await tasksStore.load(weekStart: date);
        }
        _collapseFab();
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DayTasksPage(isoDate: iso),
          ),
        );
      }
    }
    
  }

  Future<void> _handleJobFailure(JobOut job) async {
    if (!mounted) return;
    setState(() {
      _showImportBanner = false;
      _importBannerMessage = '';
      _activeJobId = null;
    });
    final detail = job.result != null ? job.result.toString() : 'Неизвестная ошибка';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Не удалось импортировать'),
        content: Text(detail),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ок'),
          ),
        ],
      ),
    );
  }

  List<HomeworkUploadResult> _parseResultsFromJob(JobOut job) {
    final dynamic result = job.result;
    if (result == null) return const [];
    List<dynamic>? list;
    if (result is List) {
      list = List<dynamic>.from(result);
    } else if (result is Map<String, dynamic>) {
      final inner = result['data'];
      if (inner is List) list = inner;
    }
    if (list == null) return const [];
    return list
        .map((item) => HomeworkUploadResult.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList(growable: false);
  }

  Future<void> _openHomeworkComposer() async {
    final childId = await tasksStore.ensureChildId();
    if (!mounted) return;
    if (childId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось определить ребёнка для загрузки домашнего задания')));
      return;
    }

    final initialDate = DateTime.now().add(const Duration(days: 1));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _HomeworkTextSheet(
          initialDate: initialDate,
          onSubmit: (text, date) async {
            await _ensureJobServiceReady();
            final service = _jobService;
            if (service == null) {
              throw ApiException('Service not ready');
            }
            final job = await service.createImportJob(
              text: text,
              childId: childId,
            );
            _startPolling(job);
          },
        );
      },
    );
    // legacy flow below is disabled; keep stub for analyzer
    final List<HomeworkUploadResult> results = const [];
    // if (!mounted || results == null) return;
    if (false && results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сервер не вернул новых заданий')),
      );
      return;
    }
    if (false) {
    // Show results in a modal dialog instead of a top banner
    final action = await _showUploadResultsDialogV3(results);
    if (!mounted) return;
    if (action == _UploadAction.goTo) {
      final iso = _resolveIsoDateFromResultsV2(results);
      if (iso != null) {
        _collapseFab();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DayTasksPage(isoDate: iso),
          ),
        );
      }
    }
    }
  }

  String? _resolveIsoDateFromResults(List<HomeworkUploadResult> results) {
    DateTime? best;
    for (final entry in results) {
      final taskPayload = entry.task;
      if (taskPayload?.date != null) {
        final d = taskPayload!.date!;
        best = (best == null || d.isBefore(best!)) ? d : best;
        continue;
      }
      final task = tasksStore.findTask(entry.taskId);
      if (task != null) {
        final d = task.date;
        best = (best == null || d.isBefore(best!)) ? d : best;
      }
    }
    if (best == null) return null;
    return _toIso(best!);
  }

  String _toIso(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String? _resolveIsoDateFromResultsV2(List<HomeworkUploadResult> results) {
    DateTime? best;
    final filtered = results.where((e) =>
        e.status == HomeworkResultStatus.created ||
        e.status == HomeworkResultStatus.updated);
    for (final entry in filtered) {
      final taskPayload = entry.task;
      if (taskPayload?.date != null) {
        final d = taskPayload!.date!;
        best = (best == null || d.isBefore(best!)) ? d : best;
        continue;
      }
      final task = tasksStore.findTask(entry.taskId);
      if (task != null) {
        final d = task.date;
        best = (best == null || d.isBefore(best!)) ? d : best;
      }
    }
    if (best == null) return null;
    return _toIso(best!);
  }

  String _subjectNameForResult(HomeworkUploadResult entry) {
    final task = tasksStore.findTask(entry.taskId);
    if (task != null) return task.subjectName;
    return tasksStore.subjectNameFor(entry.subjectId);
  }

  Future<_UploadAction?> _showUploadResultsDialogV3(
    List<HomeworkUploadResult> results,
  ) {
    return showDialog<_UploadAction>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final canGo = results.any((e) =>
            e.status == HomeworkResultStatus.created ||
            e.status == HomeworkResultStatus.updated);
        return AlertDialog(
          title: Text(
            'Статус импорта',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in results)
                  _HomeworkStatusRow(
                    icon: _visualForStatus(entry.status, theme).icon,
                    text: '${_subjectNameForResult(entry)} - ${_visualForStatus(entry.status, theme).label}',
                    color: _visualForStatus(entry.status, theme).color,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(_UploadAction.close),
              child: const Text('Ok'),
            ),
            if (canGo)
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(_UploadAction.goTo),
                child: const Text('Перейти'),
              ),
          ],
        );
      },
    );
  }

  Future<_UploadAction?> _showUploadResultsDialogV2(
    List<HomeworkUploadResult> results,
  ) {
    return showDialog<_UploadAction>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final canGo = results.any((e) =>
            e.status == HomeworkResultStatus.created ||
            e.status == HomeworkResultStatus.updated);
        return AlertDialog(
          title: Text(
            'Статус импорта',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in results)
                  _HomeworkStatusRow(
                    icon: _visualForStatus(entry.status, theme).icon,
                    text:
                        '${tasksStore.subjectNameFor(entry.subjectId)} — ${_visualForStatus(entry.status, theme).label}',
                    color: _visualForStatus(entry.status, theme).color,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(_UploadAction.close),
              child: const Text('Ok'),
            ),
            if (canGo)
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(_UploadAction.goTo),
                child: const Text('Перейти'),
              ),
          ],
        );
      },
    );
  }

  _StatusVisual _visualForStatus(
    HomeworkResultStatus status,
    ThemeData theme,
  ) {
    switch (status) {
      case HomeworkResultStatus.created:
        return _StatusVisual('✅', 'Создано', theme.colorScheme.primary);
      case HomeworkResultStatus.updated:
        return _StatusVisual('✏️', 'Обновлено', theme.colorScheme.secondary);
      case HomeworkResultStatus.duplicate:
        return _StatusVisual('⚠️', 'Дубликат', theme.colorScheme.error);
    }
  }

  Future<_UploadAction?> _showUploadResultsDialog(
    List<HomeworkUploadResult> results,
  ) {
    return showDialog<_UploadAction>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text(
            'Статус импорта',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in results)
                  _HomeworkUploadSummary(
                    results: [entry],
                    resolveSubjectName: tasksStore.subjectNameFor,
                    onDismiss: () {},
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(_UploadAction.close),
              child: const Text('Ok'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(_UploadAction.goTo),
              child: const Text('Перейти'),
            ),
          ],
        );
      },
    );
  }

  String _formatShortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month';
  }

  String _weekLabel(DateTime start, DateTime end) {
    final startLabel = _formatShortDate(start);
    final endLabel = _formatShortDate(end);
    if (start.year == end.year) {
      return '$startLabel - $endLabel ${start.year}';
    }
    return '$startLabel ${start.year} - $endLabel ${end.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekStart = tasksStore.currentWeekStart;
    final weekEnd = tasksStore.currentWeekEnd;
    final weekLabel = _weekLabel(weekStart, weekEnd);
    final prevHandler = tasksStore.loading
        ? null
        : () => tasksStore.loadPreviousWeek();
    final nextHandler = tasksStore.loading
        ? null
        : () => tasksStore.loadNextWeek();
    final resetHandler = tasksStore.loading || tasksStore.isOnCurrentWeek
        ? null
        : () => tasksStore.loadCurrentWeek();

    // Build scrollable content children (excluding fixed header)
    final children = <Widget>[];

    if (_lastUploadResults != null && _lastUploadResults!.isNotEmpty) {
      children.insert(
        0,
        _HomeworkUploadSummary(
          results: _lastUploadResults!,
          resolveSubjectName: tasksStore.subjectNameFor,
          onDismiss: () => setState(() => _lastUploadResults = null),
        ),
      );
      children.insert(1, const SizedBox(height: 12));
    }

    if (tasksStore.loading) {
      children.add(
        const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    } else if (tasksStore.days.isEmpty) {
      children.add(
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: Center(
            child: Text(
              'Заданий пока нет',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ),
      );
    } else {
      final days = tasksStore.days.reversed.toList();
      for (var i = 0; i < days.length; i++) {
        final day = days[i];
        children.add(_DayCard(day: day, theme: theme));
        if (i != days.length - 1) {
          children.add(const SizedBox(height: 12));
        }
      }
    }

    final bottomInset = MediaQuery.of(context).padding.bottom;
    final listView = ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      children: children,
    );

    // Fixed header with week switcher and (optional) import status banner
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _WeekSwitcher(
            label: weekLabel,
            isLoading: tasksStore.loading,
            onPrevious: prevHandler,
            onNext: nextHandler,
            onReset: resetHandler,
          ),
          if (_showImportBanner) const SizedBox(height: 8),
          if (_showImportBanner)
            ImportStatusBanner(message: _importBannerMessage),
        ],
      ),
    );

    return Stack(
      children: [
        // Layout: fixed header on top, scrollable content below
        Column(
          children: [
            header,
            const SizedBox(height: 12),
            Expanded(child: listView),
          ],
        ),
        if (_fabExpanded)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _collapseFab,
              child: Container(color: Colors.black.withOpacity(0.05)),
            ),
          ),
        Positioned(
          right: 16,
          bottom: 16 + bottomInset,
          child: _HomeworkFabMenu(
            expanded: _fabExpanded,
            onToggle: _toggleFab,
            onTextPressed: () {
              _collapseFab();
              _openHomeworkComposer();
            },
          ),
        ),
      ],
    );
  }
}

class _WeekSwitcher extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onReset;

  const _WeekSwitcher({
    required this.label,
    required this.isLoading,
    this.onPrevious,
    this.onNext,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: onPrevious,
                tooltip: 'Предыдущая неделя',
                splashRadius: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Неделя',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isLoading) ...[
                      const SizedBox(height: 4),
                      const LinearProgressIndicator(minHeight: 2),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: onNext,
                tooltip: 'Следуюшая неделя',
                splashRadius: 20,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.today_outlined),
          onPressed: onReset,
          tooltip: 'На текущую неделю',
          splashRadius: 20,
        ),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  final DayTasks day;
  final ThemeData theme;
  const _DayCard({required this.day, required this.theme});

  @override
  Widget build(BuildContext context) {
    final highlightTomorrow = _isTomorrow(day.date);
    final outlineColor = theme.colorScheme.primary.withOpacity(0.35);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: highlightTomorrow
            ? BorderSide(color: outlineColor, width: 1.5)
            : BorderSide.none,
      ),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DayTasksPage(isoDate: day.isoDate),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        _formatDayLabel(day.date),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  color: theme.colorScheme.outline,
                  tooltip: 'Открыть список дня',
                  splashRadius: 20,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DayTasksPage(isoDate: day.isoDate),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                for (final task in day.tasks)
                  _SubjectPreview(
                    task: task,
                    theme: theme,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TaskDetailsPage(taskId: task.id),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDayLabel(DateTime date) {
    const weekDays = [
      'Понедельник',
      'Вторник',
      'Среда',
      'Четверг',
      'Пятница',
      'Суббота',
      'Воскресенье',
    ];
    const months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    final target = DateTime(date.year, date.month, date.day);
    final dayName = weekDays[target.weekday - 1];
    final month = months[target.month - 1];
    return '$dayName ${target.day} $month';
  }

  bool _isTomorrow(DateTime date) {
    final now = DateTime.now();
    final tomorrow = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    return _isSameDay(date, tomorrow);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _SubjectPreview extends StatelessWidget {
  final TaskItem task;
  final ThemeData theme;
  final VoidCallback onTap;
  const _SubjectPreview({
    required this.task,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = theme.textTheme.bodyMedium?.color?.withOpacity(0.7);
    final text = task.firstLine.isEmpty ? 'Нет описания' : task.firstLine;
    final status = task.aggregatedStatus;
    final statusLabel = taskStatusTitle(status);
    final statusColor = taskStatusColor(status, theme);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: task.subjectColor.withOpacity(0.15),
              foregroundColor: task.subjectColor,
              child: Icon(task.subjectIcon, size: 20),
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
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (status != TaskStatus.todo) ...[
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
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeworkUploadSummary extends StatelessWidget {
  final List<HomeworkUploadResult> results;
  final String Function(int subjectId) resolveSubjectName;
  final VoidCallback onDismiss;

  const _HomeworkUploadSummary({
    required this.results,
    required this.resolveSubjectName,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Домашка загружена',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Скрыть',
                  onPressed: onDismiss,
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final entry in results) _buildRow(theme, entry),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(ThemeData theme, HomeworkUploadResult entry) {
    final visual = _statusVisual(entry.status, theme);
    final subject = resolveSubjectName(entry.subjectId);
    return _HomeworkStatusRow(
      icon: visual.icon,
      text: '$subject — ${visual.label}',
      color: visual.color,
    );
  }

  _StatusVisual _statusVisual(HomeworkResultStatus status, ThemeData theme) {
    switch (status) {
      case HomeworkResultStatus.created:
        return _StatusVisual('✅', 'новое задание', theme.colorScheme.primary);
      case HomeworkResultStatus.updated:
        return _StatusVisual(
          '🔄',
          'добавлены подзадания',
          theme.colorScheme.secondary,
        );
      case HomeworkResultStatus.duplicate:
        return _StatusVisual(
          '⚠️',
          'пропускаем дубликат',
          theme.colorScheme.error,
        );
    }
  }
}

class _HomeworkStatusRow extends StatelessWidget {
  final String icon;
  final String text;
  final Color color;

  const _HomeworkStatusRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusVisual {
  final String icon;
  final String label;
  final Color color;
  const _StatusVisual(this.icon, this.label, this.color);
}

class _HomeworkTextSheet extends StatefulWidget {
  final DateTime initialDate;
  final Future<void> Function(String text, DateTime? date) onSubmit;

  const _HomeworkTextSheet({required this.initialDate, required this.onSubmit});

  @override
  State<_HomeworkTextSheet> createState() => _HomeworkTextSheetState();
}

class _HomeworkTextSheetState extends State<_HomeworkTextSheet> {
  final TextEditingController _controller = TextEditingController();
  DateTime? _selectedDate;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedDate ?? widget.initialDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final value = data?.text?.trim();
    if (value == null || value.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Буфер обмена пуст')));
      return;
    }
    setState(() {
      final current = _controller.text;
      final text = current.isEmpty ? value : '$current\n$value';
      _controller.text = text;
      _controller.selection = TextSelection.collapsed(offset: text.length);
    });
  }

  String _formatIso(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatDisplayDate(DateTime date) {
    const months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Добавь текст задания');
      return;
    }
    setState(() {
      _error = null;
      _isSubmitting = true;
    });
    final prepared = _selectedDate == null
        ? raw
        : 'На ${_formatIso(_selectedDate!)} дату: $raw';
    try {
      await widget.onSubmit(prepared, _selectedDate);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException ? error.message : error.toString();
      setState(() {
        _error = message;
        _isSubmitting = false;
      });
    }
  }

  Widget _buildDateSelector(ThemeData theme) {
    final selector = _selectedDate == null
        ? TextButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event_available_outlined),
            label: const Text('Добавить дату'),
          )
        : Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event_note_outlined),
                label: Text(_formatDisplayDate(_selectedDate!)),
              ),
              IconButton(
                tooltip: 'Очистить дату',
                onPressed: () => setState(() => _selectedDate = null),
                icon: const Icon(Icons.close),
              ),
            ],
          );
    return selector;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'Добавь домашечку',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildDateSelector(theme),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                minLines: 5,
                maxLines: 10,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Опиши домашнее задание',
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _isSubmitting ? null : _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste_go_outlined),
                  label: const Text('Вставить из буфера'),
                ),
              ),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Отправить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeworkFabMenu extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onTextPressed;

  const _HomeworkFabMenu({
    required this.expanded,
    required this.onToggle,
    required this.onTextPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1.0,
                child: child,
              ),
            );
          },
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _HomeworkFabOption(
                        icon: Icons.edit_outlined,
                        label: 'Текст',
                        onTap: onTextPressed,
                      ),
                      const SizedBox(height: 8),
                      const _HomeworkFabOption(
                        icon: Icons.mic_none_outlined,
                        label: 'Голос',
                        enabled: false,
                        // secondary: 'Скоро',
                      ),
                      const SizedBox(height: 8),
                      const _HomeworkFabOption(
                        icon: Icons.attach_file,
                        label: 'Файл',
                        enabled: false,
                        // secondary: 'Скоро',
                      ),
                      const SizedBox(height: 8),
                      const _HomeworkFabOption(
                        icon: Icons.photo_camera_outlined,
                        label: 'Фото',
                        enabled: false,
                        // secondary: 'Скоро',
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Tooltip(
          message: 'Нажми +, чтобы добавить ДЗ',
          child: FloatingActionButton(
            onPressed: onToggle,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return RotationTransition(
                  turns: Tween<double>(
                    begin: 0.75,
                    end: 1.0,
                  ).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: expanded
                  ? const Icon(Icons.close, key: ValueKey('fab-close'))
                  : const Icon(Icons.add, key: ValueKey('fab-add')),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeworkFabOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? secondary;
  final bool enabled;
  final VoidCallback? onTap;

  const _HomeworkFabOption({
    required this.icon,
    required this.label,
    this.secondary,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = enabled ? colorScheme.onSurface : colorScheme.outline;
    final iconColor = enabled ? colorScheme.primary : colorScheme.outline;
    final background = enabled
        ? colorScheme.primary.withOpacity(0.12)
        : colorScheme.surfaceVariant;

    return Material(
      color: background,
      elevation: enabled ? 2 : 0,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                  if (!enabled && secondary != null)
                    Text(
                      secondary!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _UploadAction { close, goTo }
