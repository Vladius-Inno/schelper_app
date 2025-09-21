import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/tasks.dart';
import '../../store/tasks_store.dart';

class SubtaskScreen extends StatefulWidget {
  final String subjectId;
  final String taskId;
  final String subtaskId;
  const SubtaskScreen({super.key, required this.subjectId, required this.taskId, required this.subtaskId});

  @override
  State<SubtaskScreen> createState() => _SubtaskScreenState();
}

class _SubtaskScreenState extends State<SubtaskScreen> {
  static const int defaultMinutes = 20;
  late Duration _duration;
  Timer? _timer;
  bool _running = false;

  Subtask? get _subtask => tasksStore.findSubtask(widget.subjectId, widget.taskId, widget.subtaskId);

  @override
  void initState() {
    super.initState();
    _duration = const Duration(minutes: defaultMinutes);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    if (_subtask != null) {
      tasksStore.startSubtask(widget.subjectId, widget.taskId, widget.subtaskId);
    }
    _timer?.cancel();
    setState(() {
      _running = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_duration.inSeconds <= 1) {
        t.cancel();
        setState(() {
          _running = false;
          _duration = Duration.zero;
        });
      } else {
        setState(() {
          _duration -= const Duration(seconds: 1);
        });
      }
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() {
      _running = false;
    });
  }

  void _stop() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _duration = const Duration(minutes: defaultMinutes);
    });
    tasksStore.stopSubtask(widget.subjectId, widget.taskId, widget.subtaskId);
  }

  Future<void> _markDone() async {
    final allDone = tasksStore.completeSubtask(widget.subjectId, widget.taskId, widget.subtaskId);
    _pause();
    await _showRewardPopup(context);
    if (allDone) {
      await _showRewardPopup(context, bonus: true);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _showRewardPopup(BuildContext context, {bool bonus = false}) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'reward',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, a1, a2) {
        return Center(
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(bonus ? 'Бонусная награда!' : 'Награда!',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  bonus
                      ? 'Все подзадачи в задании выполнены — бонус!'
                      : 'Вы получили очко за выполнение подзадачи.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(bonus ? '🌟' : '🎉', style: const TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Ок')),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (context, anim, _, child) {
        return Transform.scale(
            scale: 0.9 + 0.1 * anim.value, child: Opacity(opacity: anim.value, child: child));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = _subtask;
    if (st == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Подзадача')),
        body: const Center(child: Text('Подзадача не найдена')),
      );
    }
    final minutes = _duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Scaffold(
      appBar: AppBar(title: Text(st.title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Статус: ${statusLabelSubtask(st.status)}'),
                Text('Очки: ${tasksStore.rewards}')
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$minutes:$seconds',
                        style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.play_arrow),
                          iconSize: 36,
                          tooltip: 'Старт',
                          onPressed: _running ? null : _start,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.pause),
                          iconSize: 36,
                          tooltip: 'Пауза',
                          onPressed: _running ? _pause : null,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.stop),
                          iconSize: 36,
                          tooltip: 'Стоп',
                          onPressed: _stop,
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  showDragHandle: true,
                  builder: (context) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Подсказка',
                              style:
                                  TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          SizedBox(height: 12),
                          Text(
                              'Разбей задание на шаги, начни с простого. Если сложно — посмотри пример или спроси у взрослого.'),
                          SizedBox(height: 12),
                        ],
                      ),
                    );
                  },
                );
              },
              child: const Text('📖 Подсказка'),
            ),
            const Spacer(),
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Выполнено'),
              onPressed: _markDone,
            ),
          ],
        ),
      ),
    );
  }
}

