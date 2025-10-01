import 'api_client.dart';
import 'auth_service.dart';

class AuthorizedApiClient {
  final ApiClient _api;
  final AuthService _auth;

  AuthorizedApiClient({ApiClient? api, AuthService? auth})
      : _api = api ?? ApiClient(),
        _auth = auth ?? AuthService();

  Future<T> _withAuthRetry<T>(
    Future<T> Function(String? token) action,
  ) async {
    String? token = await _auth.getAccessToken();
    try {
      return await action(token);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        final newToken = await _auth.refreshToken();
        if (newToken != null) {
          return await action(newToken);
        }
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getJson(String path) {
    return _withAuthRetry((token) {
      return _api.getJson(path, headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      });
    });
  }

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) {
    return _withAuthRetry((token) {
      return _api.postJson(path, body, headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      });
    });
  }

  Future<dynamic> getAny(String path) {
    return _withAuthRetry((token) {
      return _api.get(path, headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      });
    });
  }

  Future<dynamic> postAny(String path, Map<String, dynamic> body) {
    return _withAuthRetry((token) {
      return _api.post(path, body, headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      });
    });
  }
  Future<dynamic> patchAny(String path, Map<String, dynamic> body) {
    return _withAuthRetry((token) {
      return _api.patch(path, body, headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      });
    });
  }

  Future<dynamic> deleteAny(String path) {
    return _withAuthRetry((token) {
      return _api.delete(path, headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      });
    });
  }

}
