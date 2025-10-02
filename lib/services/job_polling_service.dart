import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/job.dart';
import '../store/import_jobs_store.dart';
import 'auth_service.dart';

typedef JobUpdateCallback = void Function(JobOut job, Duration elapsed);

/// Сообщение статуса для пользователя по времени ожидания
String statusMessageForElapsed(Duration elapsed) {
  final seconds = elapsed.inSeconds;
  if (seconds < 10) return 'Загружаем домашечку…';
  if (seconds < 20) return 'ИИ думает над домашечкой…';
  return 'Сложная оказалась домашечка…';
}

class _Tracker {
  final int jobId;
  final DateTime startAt;
  Timer? timer;
  Duration get elapsed => DateTime.now().difference(startAt);

  _Tracker(this.jobId) : startAt = DateTime.now();
}

/// Сервис опроса статусов задач по job_id
class JobPollingService {
  final String baseUrl; // e.g. https://api.example.com
  final Map<String, String> Function()? headersProvider; // e.g. auth headers
  final http.Client _client;
  final ImportJobsStore _store;
  final AuthService _auth;

  final Map<int, _Tracker> _trackers = {};

  JobPollingService({
    required this.baseUrl,
    this.headersProvider,
    http.Client? client,
    ImportJobsStore? store,
    AuthService? auth,
  })  : _client = client ?? http.Client(),
        _store = store ?? ImportJobsStore.instance,
        _auth = auth ?? AuthService();

  Future<Map<String, String>> _authHeaders({Map<String, String>? base}) async {
    final headers = <String, String>{
      if (base != null) ...base,
    };
    final token = await _auth.getAccessToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    } else if (headersProvider != null) {
      headers.addAll(headersProvider!.call());
    }
    return headers;
  }

  Future<JobOut> fetchJob(int jobId) async {
    final uri = Uri.parse("$baseUrl/jobs/$jobId");
    var res = await _client.get(
      uri,
      headers: await _authHeaders(base: headersProvider?.call()),
    );
    if (res.statusCode == 401) {
      final newToken = await _auth.refreshToken();
      if (newToken != null) {
        res = await _client.get(
          uri,
          headers: await _authHeaders(base: headersProvider?.call()),
        );
      }
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('GET /jobs/$jobId failed: ${res.statusCode}');
    }
    final data = jsonDecode(res.body);
    // API может вернуть объект напрямую
    if (data is Map<String, dynamic>) {
      return JobOut.fromJson(data);
    }
    // или массив с одним объектом (по ТЗ — допустим защитный парсинг)
    if (data is List && data.isNotEmpty && data.first is Map<String, dynamic>) {
      return JobOut.fromJson(data.first as Map<String, dynamic>);
    }
    throw Exception('Unexpected jobs payload');
  }

  /// Запускает опрос конкретного job до статуса done/failed
  void startPolling({
    required int jobId,
    required JobUpdateCallback onUpdate,
    required void Function(JobOut job) onDone,
    required void Function(JobOut job) onFailed,
  }) {
    if (_trackers.containsKey(jobId)) return; // уже идёт опрос
    final tracker = _Tracker(jobId);
    _trackers[jobId] = tracker;

    tracker.timer = Timer.periodic(const Duration(seconds: 2), (t) async {
      try {
        final job = await fetchJob(jobId);
        onUpdate(job, tracker.elapsed);
        if (job.isDone) {
          await _store.remove(jobId);
          stopPolling(jobId);
          onDone(job);
        } else if (job.isFailed) {
          await _store.remove(jobId);
          stopPolling(jobId);
          onFailed(job);
        }
      } catch (_) {
        // Сетевые/временные ошибки игнорируем, продолжаем опрос
        onUpdate(
          JobOut(
            type: 'unknown',
            payload: null,
            id: jobId,
            userId: 0,
            status: 'pending',
            result: null,
          ),
          tracker.elapsed,
        );
      }
    });
  }

  void stopPolling(int jobId) {
    final tr = _trackers.remove(jobId);
    tr?.timer?.cancel();
  }

  /// Возобновляет опрос всех незавершённых job из локального стора
  Future<void> resumePending({
    required JobUpdateCallback onUpdate,
    required void Function(JobOut job) onDone,
    required void Function(JobOut job) onFailed,
  }) async {
    final pending = await _store.loadPending();
    for (final id in pending) {
      startPolling(
        jobId: id,
        onUpdate: onUpdate,
        onDone: onDone,
        onFailed: onFailed,
      );
    }
  }
}
