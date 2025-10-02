import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Хранилище pending job_id в локальном сторе (для восстановления после перезапуска)
class ImportJobsStore {
  static const _kKey = 'pending_import_jobs';
  static final ImportJobsStore instance = ImportJobsStore._();

  final FlutterSecureStorage _storage;

  ImportJobsStore._({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<List<int>> loadPending() async {
    try {
      final raw = await _storage.read(key: _kKey);
      if (raw == null || raw.isEmpty) return <int>[];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => e is int ? e : int.tryParse(e.toString()) ?? -1)
            .where((e) => e > 0)
            .toList(growable: false);
      }
      return <int>[];
    } catch (_) {
      return <int>[];
    }
  }

  Future<void> add(int jobId) async {
    final current = await loadPending();
    if (current.contains(jobId)) return;
    final next = [...current, jobId];
    await _storage.write(key: _kKey, value: jsonEncode(next));
  }

  Future<void> remove(int jobId) async {
    final current = await loadPending();
    final next = current.where((e) => e != jobId).toList(growable: false);
    await _storage.write(key: _kKey, value: jsonEncode(next));
  }
}

