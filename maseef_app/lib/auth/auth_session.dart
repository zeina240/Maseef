import 'package:flutter/foundation.dart';
import 'package:maseef_app/auth/auth_client.dart';
import 'package:maseef_app/auth/auth_models.dart';
import 'package:maseef_app/auth/token_store.dart';

class AuthSession extends ChangeNotifier {
  AuthSession({required this.client, required this.tokens});

  final AuthClient client;
  final SessionTokenStore tokens;

  AuthUser? user;
  String? _token;
  bool ready = false;
  bool persistenceFailed = false;
  Future<void>? _restoring;

  String? get token => _token;

  bool get isSignedIn => user != null && _token != null;

  Future<void> restore() {
    if (ready) return Future<void>.value();
    return _restoring ??= _restore();
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    required String role,
  }) async {
    final result = await client.register(
      fullName: fullName,
      email: email,
      password: password,
      phone: phone,
      role: role,
    );
    await _keep(result);
  }

  Future<void> login({required String email, required String password}) async {
    final result = await client.login(email: email, password: password);
    await _keep(result);
  }

  Future<void> requestPasswordReset({
    required String email,
    String locale = 'en',
  }) => client.requestPasswordReset(email: email, locale: locale);

  Future<void> resetPassword({
    required String token,
    required String password,
  }) => client.resetPassword(token: token, password: password);

  Future<void> logout() async {
    final current = _token;
    if (current != null) {
      try {
        await client.logout(current);
      } on AuthException {
        // The server already rejected the token. Drop the local copy too.
      } catch (_) {
        // The device stops sending the token even if revocation did not finish.
        // That server session can remain until it expires.
      }
    }
    _token = null;
    user = null;
    persistenceFailed = false;
    try {
      await tokens.clear();
    } catch (_) {
      persistenceFailed = true;
    }
    notifyListeners();
  }

  Future<void> _restore() async {
    try {
      final saved = await tokens.read();
      if (saved == null || saved.isEmpty) {
        _token = null;
        user = null;
        return;
      }
      _token = saved;
      user = await client.currentUser(saved);
    } on AuthException catch (error) {
      user = null;
      if (error.code == 'unauthenticated') {
        _token = null;
        await _clearQuietly();
      }
    } catch (_) {
      user = null;
    } finally {
      ready = true;
      notifyListeners();
    }
  }

  Future<void> _keep(AuthSessionResult result) async {
    _token = result.token;
    user = result.user;
    persistenceFailed = false;
    try {
      await tokens.write(result.token);
    } catch (_) {
      persistenceFailed = true;
    }
    ready = true;
    notifyListeners();
  }

  Future<void> _clearQuietly() async {
    try {
      await tokens.clear();
    } catch (_) {
      persistenceFailed = true;
    }
  }
}
