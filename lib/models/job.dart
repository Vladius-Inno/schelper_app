import 'dart:convert';

class JobOut {
  final String type;
  final Map<String, dynamic>? payload;
  final int id;
  final int userId;
  final String status; // pending | running | done | failed
  final Map<String, dynamic>? result;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const JobOut({
    required this.type,
    required this.payload,
    required this.id,
    required this.userId,
    required this.status,
    required this.result,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPending => status == 'pending' || status == 'running';
  bool get isDone => status == 'done';
  bool get isFailed => status == 'failed';

  static JobOut fromJson(Map<String, dynamic> json) {
    return JobOut(
      type: json['type'] as String? ?? '',
      payload: json['payload'] is Map<String, dynamic>
          ? json['payload'] as Map<String, dynamic>
          : null,
      id: _asInt(json['id']),
      userId: _asInt(json['user_id']),
      status: json['status'] as String? ?? 'pending',
      result: json['result'] is Map<String, dynamic>
          ? json['result'] as Map<String, dynamic>
          : null,
      createdAt: _asDate(json['created_at']),
      updatedAt: _asDate(json['updated_at']),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  @override
  String toString() => jsonEncode({
        'id': id,
        'status': status,
        'type': type,
      });
}

