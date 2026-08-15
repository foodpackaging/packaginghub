import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  /// Status 0 means the request never reached the server (offline, wrong host, backend down).
  bool get isNetworkError => statusCode == 0;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _storage = FlutterSecureStorage();
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _requestTimeout = Duration(seconds: 20);

  String get baseUrl {
    final configured = dotenv.env['API_BASE_URL']?.trim();
    if (configured != null && configured.isNotEmpty) return configured;
    // An Android emulator reaches the host machine's localhost through 10.0.2.2,
    // so plain "localhost" would resolve to the emulator itself and be refused.
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return 'http://${isAndroid ? '10.0.2.2' : 'localhost'}:4000/api';
  }

  String get _networkErrorMessage {
    const friendly = "Can't reach the server. Check your internet connection and try again.";
    return kDebugMode ? '$friendly\n(Tried $baseUrl — is the backend running?)' : friendly;
  }

  Future<String?> get accessToken => _storage.read(key: _accessTokenKey);
  Future<String?> get refreshToken => _storage.read(key: _refreshTokenKey);

  Future<bool> hasSession() async => (await accessToken) != null;

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    Map<String, String>? stringQuery;
    if (query != null) {
      stringQuery = {};
      query.forEach((key, value) {
        if (value != null) stringQuery![key] = value.toString();
      });
    }
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: (stringQuery == null || stringQuery.isEmpty) ? null : stringQuery,
    );
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) => _send('GET', _uri(path, query));

  Future<dynamic> post(String path, {Object? body}) => _send('POST', _uri(path), body: body);

  Future<dynamic> patch(String path, {Object? body}) => _send('PATCH', _uri(path), body: body);

  Future<dynamic> delete(String path, {Object? body}) => _send('DELETE', _uri(path), body: body);

  Future<dynamic> _send(String method, Uri uri, {Object? body, bool isRetry = false}) async {
    final token = await accessToken;
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final encodedBody = body != null ? jsonEncode(body) : null;

    Future<http.Response> request;
    switch (method) {
      case 'GET':
        request = http.get(uri, headers: headers);
        break;
      case 'POST':
        request = http.post(uri, headers: headers, body: encodedBody);
        break;
      case 'PATCH':
        request = http.patch(uri, headers: headers, body: encodedBody);
        break;
      case 'DELETE':
        request = http.delete(uri, headers: headers, body: encodedBody);
        break;
      default:
        throw ArgumentError('Unsupported method: $method');
    }

    final http.Response response;
    try {
      response = await request.timeout(_requestTimeout);
    } on TimeoutException {
      throw ApiException(0, 'The server took too long to respond. Please try again.');
    } catch (_) {
      // SocketException, ClientException, DNS failures — the request never landed.
      throw ApiException(0, _networkErrorMessage);
    }

    if (response.statusCode == 401 && !isRetry && token != null) {
      if (await _tryRefresh()) {
        return _send(method, uri, body: body, isRetry: true);
      }
      await clearTokens();
    }

    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        // A proxy or crash page can return HTML; fall through to a status-based message.
        decoded = null;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = (decoded is Map && decoded['error'] != null)
          ? decoded['error'].toString()
          : 'Request failed (${response.statusCode})';
      throw ApiException(response.statusCode, message);
    }
    return decoded;
  }

  Future<bool> _tryRefresh() async {
    final refresh = await refreshToken;
    if (refresh == null) return false;
    try {
      final response = await http
          .post(
            _uri('/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': refresh}),
          )
          .timeout(_requestTimeout);
      if (response.statusCode != 200) return false;
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      await _storage.write(key: _accessTokenKey, value: decoded['access_token'] as String);
      return true;
    } catch (_) {
      return false;
    }
  }
}
