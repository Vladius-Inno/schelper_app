import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/job.dart';
import '../services/job_polling_service.dart';
import '../store/import_jobs_store.dart';
import 'auth_service.dart';

/// Сервис импорта домашки с переводом на job + polling
class HomeworkService {
  final String baseUrl; // e.g. https://api.example.com
  final Map<String, String> Function()? headersProvider; // e.g. auth headers
  final http.Client _client;
  final ImportJobsStore _store;
  final JobPollingService _polling;
  final AuthService _auth;

  HomeworkService({
    required this.baseUrl,
    this.headersProvider,
    http.Client? client,
    ImportJobsStore? store,
    AuthService? auth,
  })  : _client = client ?? http.Client(),
        _store = store ?? ImportJobsStore.instance,
        _auth = auth ?? AuthService(),
        _polling = JobPollingService(
          baseUrl: baseUrl,
          headersProvider: headersProvider,
          client: client,
          store: store,
          auth: auth,
        );

  Future<Map<String, String>> _authHeaders({Map<String, String>? base}) async {
    final headers = <String, String>{
      if (base != null) ...base,
    };
    // Merge provided headers but ensure Authorization reflects latest token
    final token = await _auth.getAccessToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    } else if (headersProvider != null) {
      headers.addAll(headersProvider!.call());
    }
    return headers;
  }

  /// Создает job импорта и сохраняет job_id локально для восстановления
  /// Возвращает созданный JobOut (содержит id и начальный статус)
  Future<JobOut> createImportJob({
    required String text,
    int? userId,
    int? childId,
    Map<String, dynamic>? extraParams,
  }) async {
    final uri = Uri.parse("$baseUrl/import/homework");
    final payload = <String, dynamic>{
      'text': text,
      if (userId != null) 'user_id': userId,
      if (childId != null) 'child_id': childId,
      ...?extraParams,
    };
    final baseHeaders = <String, String>{
      'Content-Type': 'application/json',
      ...?headersProvider?.call(),
    };
    var res = await _client.post(
      uri,
      headers: await _authHeaders(base: baseHeaders),
      body: jsonEncode(payload),
    );

    if (res.statusCode == 401) {
      final newToken = await _auth.refreshToken();
      if (newToken != null) {
        final retryHeaders = <String, String>{
          'Content-Type': 'application/json',
          ...?headersProvider?.call(),
        };
        res = await _client.post(
          uri,
          headers: await _authHeaders(base: retryHeaders),
          body: jsonEncode(payload),
        );
      }
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('POST /import/homework failed: ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final job = JobOut.fromJson(data);
    if (job.id > 0) {
      await _store.add(job.id);
    }
    return job;
  }

  /// Запускает polling для данного job_id.
  /// Коллбеки: onUpdate для обновления статуса/индикатора, onDone/onFailed — финальные переходы.
  void startPollingJob({
    required int jobId,
    required JobUpdateCallback onUpdate,
    required void Function(JobOut job) onDone,
    required void Function(JobOut job) onFailed,
  }) {
    _polling.startPolling(
      jobId: jobId,
      onUpdate: onUpdate,
      onDone: onDone,
      onFailed: onFailed,
    );
  }

  /// Возобновляет опрос всех незавершенных задач после перезапуска приложения
  Future<void> resumePendingJobs({
    required JobUpdateCallback onUpdate,
    required void Function(JobOut job) onDone,
    required void Function(JobOut job) onFailed,
  }) async {
    await _polling.resumePending(
      onUpdate: onUpdate,
      onDone: onDone,
      onFailed: onFailed,
    );
  }
}
