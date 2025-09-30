import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  final String baseUrl;
  final http.Client _client;

  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? AppConfig.baseUrl;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<dynamic> get(String path, {Map<String, String>? headers}) async {
    final resp = await _client.get(
      _uri(path),
      headers: {
        'Accept': 'application/json',
        if (headers != null) ...headers,
      },
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return resp.body.isEmpty ? <String, dynamic>{} : jsonDecode(resp.body);
    }
    String msg = 'HTTP ${resp.statusCode}';
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map && decoded['detail'] != null) {
        msg = decoded['detail'].toString();
      }
    } catch (_) {}
    throw ApiException(msg, statusCode: resp.statusCode);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body,
      {Map<String, String>? headers}) async {
    final resp = await _client.post(
      _uri(path),
      headers: {
        'Content-Type': 'application/json',
        if (headers != null) ...headers,
      },
      body: jsonEncode(body),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return resp.body.isEmpty ? <String, dynamic>{} : jsonDecode(resp.body);
    }
    String msg = 'HTTP ${resp.statusCode}';
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map && decoded['detail'] != null) {
        msg = decoded['detail'].toString();
      }
    } catch (_) {}
    throw ApiException(msg, statusCode: resp.statusCode);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body,
      {Map<String, String>? headers}) async {
    final resp = await _client.patch(
      _uri(path),
      headers: {
        'Content-Type': 'application/json',
        if (headers != null) ...headers,
      },
      body: jsonEncode(body),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return resp.body.isEmpty ? <String, dynamic>{} : jsonDecode(resp.body);
    }
    String msg = 'HTTP ${resp.statusCode}';
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map && decoded['detail'] != null) {
        msg = decoded['detail'].toString();
      }
    } catch (_) {}
    throw ApiException(msg, statusCode: resp.statusCode);
  }

  // Backwards-compatible helpers for Map-shaped responses
  Future<Map<String, dynamic>> getJson(String path, {Map<String, String>? headers}) async {
    final data = await get(path, headers: headers);
    if (data is Map<String, dynamic>) return data;
    throw ApiException('Expected object, got ${data.runtimeType}');
  }

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body,
      {Map<String, String>? headers}) async {
    final data = await post(path, body, headers: headers);
    if (data is Map<String, dynamic>) return data;
    throw ApiException('Expected object, got ${data.runtimeType}');
  }
}
