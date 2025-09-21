import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';

class AuthService {
  final ApiClient _api;
  final FlutterSecureStorage _storage;

  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';

  AuthService({ApiClient? api, FlutterSecureStorage? storage})
      : _api = api ?? ApiClient(),
        _storage = storage ?? const FlutterSecureStorage();

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final resp = await _api.postJson('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
      'role': role,
    });
    final token = resp['token'] as String?;
    if (token == null) throw ApiException('Invalid response: no token');
    await _storage.write(key: _kAccessToken, value: token);
  }

  Future<void> login({required String email, required String password}) async {
    final resp = await _api.postJson('/auth/login', {
      'email': email,
      'password': password,
    });
    final token = resp['token'] as String?;
    final refresh = resp['refresh_token'] as String?;
    if (token == null) throw ApiException('Invalid response: no token');
    await _storage.write(key: _kAccessToken, value: token);
    if (refresh != null) {
      await _storage.write(key: _kRefreshToken, value: refresh);
    }
  }

  Future<String?> getAccessToken() => _storage.read(key: _kAccessToken);
  Future<String?> getRefreshToken() => _storage.read(key: _kRefreshToken);

  Future<void> logout() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
  }

  Future<String?> refreshToken() async {
    final refresh = await getRefreshToken();
    if (refresh == null) return null;
    final resp = await _api.postJson('/auth/refresh', {
      'refresh_token': refresh,
    });
    final token = resp['token'] as String?;
    if (token != null) {
      await _storage.write(key: _kAccessToken, value: token);
    }
    return token;
  }
}

