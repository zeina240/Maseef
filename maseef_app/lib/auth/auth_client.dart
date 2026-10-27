import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:maseef_app/auth/auth_models.dart';
import 'package:maseef_app/booking/booking_client.dart';

class AuthHttpRequest {
  const AuthHttpRequest({
    required this.method,
    required this.uri,
    required this.headers,
    this.body,
  });

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final String? body;
}

typedef AuthTransport = Future<http.Response> Function(AuthHttpRequest request);

class AuthClient {
  AuthClient({this.baseUrl = ApiConfig.baseUrl, AuthTransport? transport})
    : _transport = transport ?? _defaultTransport;

  final String baseUrl;
  final AuthTransport _transport;

  static Future<http.Response> _defaultTransport(AuthHttpRequest request) {
    final headers = request.headers;
    if (request.method == 'GET') {
      return http
          .get(request.uri, headers: headers)
          .timeout(const Duration(seconds: 8));
    }
    return http
        .post(request.uri, headers: headers, body: request.body)
        .timeout(const Duration(seconds: 8));
  }

  Future<AuthSessionResult> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    required String role,
  }) {
    return _session('POST', '/api/auth/register', {
      'fullName': fullName,
      'email': email,
      'password': password,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'role': role,
    });
  }

  Future<AuthSessionResult> login({
    required String email,
    required String password,
  }) {
    return _session('POST', '/api/auth/login', {
      'email': email,
      'password': password,
    });
  }

  /// Asks the server to email a password-reset link.
  ///
  /// The server must answer the same way whether or not the address has an
  /// account, and the app shows the same message either way, so this never
  /// reveals who is registered. [locale] ('ar' or 'en') picks the language of
  /// the email. Calls `POST /api/auth/forgot-password`.
  Future<void> requestPasswordReset({
    required String email,
    String locale = 'en',
  }) async {
    await _send(
      'POST',
      '/api/auth/forgot-password',
      body: {'email': email, 'locale': locale},
    );
  }

  /// Sets a new password using the one-time [token] from the reset link.
  /// Needs `POST /api/auth/reset-password`; a bad or expired token comes back
  /// as the `invalid_token` code.
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    await _send(
      'POST',
      '/api/auth/reset-password',
      body: {'token': token, 'password': password},
    );
  }

  Future<AuthUser> currentUser(String token) async {
    final decoded = await _send('GET', '/api/auth/me', token: token);
    final data = decoded['data'];
    final user = data is Map ? data['user'] : null;
    if (user is Map<String, dynamic>) return AuthUser.fromJson(user);
    if (user is Map) return AuthUser.fromJson(Map<String, dynamic>.from(user));
    throw const AuthException('invalid_response');
  }

  Future<void> logout(String token) async {
    await _send('POST', '/api/auth/logout', token: token);
  }

  Future<AuthSessionResult> _session(
    String method,
    String path,
    Map<String, dynamic> body,
  ) async {
    final decoded = await _send(method, path, body: body);
    final data = decoded['data'];
    if (data is! Map) throw const AuthException('invalid_response');
    final token = data['token'];
    final user = data['user'];
    if (token is! String || user is! Map) {
      throw const AuthException('invalid_response');
    }
    return AuthSessionResult(
      token: token,
      user: AuthUser.fromJson(Map<String, dynamic>.from(user)),
    );
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _transport(
        AuthHttpRequest(
          method: method,
          uri: Uri.parse('$baseUrl$path'),
          headers: {
            'accept': 'application/json',
            'content-type': 'application/json',
            if (token != null) 'authorization': 'Bearer $token',
          },
          body: body == null ? null : jsonEncode(body),
        ),
      );
      final decoded = _decode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final code = decoded['code'];
        if (code is String) throw AuthException(code);
        // No JSON error body: a missing route (404/501) means the server does
        // not offer this yet, 429 means slow down. Anything else is a network
        // style failure.
        final status = response.statusCode;
        if (status == 404 || status == 501) {
          throw const AuthException('unavailable');
        }
        if (status == 429) throw const AuthException('rate_limited');
        throw const AuthException('network');
      }
      return decoded;
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException('network');
    }
  }

  Map<String, dynamic> _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return const {};
    }
    return const {};
  }
}
