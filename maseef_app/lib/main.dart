import 'package:flutter/material.dart';
import 'package:maseef_app/auth/auth_client.dart';
import 'package:maseef_app/auth/auth_scope.dart';
import 'package:maseef_app/auth/auth_session.dart';
import 'package:maseef_app/auth/token_store.dart';
import 'package:maseef_app/l10n/locale_scope.dart';
import 'package:maseef_app/pages/home_page.dart';
import 'package:maseef_app/pages/reset_password_page.dart';
import 'package:maseef_app/theme/maseef_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final session = AuthSession(
    client: AuthClient(),
    tokens: const SecureSessionTokenStore(),
  );
  runApp(MaseefApp(session: session));
}

class MaseefApp extends StatefulWidget {
  const MaseefApp({super.key, this.home, this.session});

  final Widget? home;

  /// Widget tests omit this and get an in-memory session. The app entrypoint
  /// passes [SecureSessionTokenStore] so a browser or device test is not required
  /// to keep a token.
  final AuthSession? session;

  @override
  State<MaseefApp> createState() => _MaseefAppState();
}

class _MaseefAppState extends State<MaseefApp> {
  final _locale = LocaleController();
  late final AuthSession _session;
  late final bool _ownsSession;

  @override
  void initState() {
    super.initState();
    _ownsSession = widget.session == null;
    _session =
        widget.session ??
        AuthSession(client: AuthClient(), tokens: MemoryTokenStore());
    _session.restore();
  }

  @override
  void dispose() {
    _locale.dispose();
    if (_ownsSession) _session.dispose();
    super.dispose();
  }

  /// Deep link from the password-reset email: `/#/reset-password?token=...`.
  /// "/" itself falls through to [MaterialApp.home]; any other unknown address
  /// shows the home page instead of an error.
  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final name = settings.name;
    if (name == null || name == Navigator.defaultRouteName) return null;
    final uri = Uri.tryParse(name);
    if (uri != null && uri.path == '/reset-password') {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (context) =>
            ResetPasswordPage(token: uri.queryParameters['token']),
      );
    }
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) => widget.home ?? const HomePage(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      session: _session,
      child: LocaleScope(
        controller: _locale,
        child: ListenableBuilder(
          listenable: _locale,
          builder: (context, child) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'MASEEF',
              theme: buildMaseefTheme(),
              builder: (context, child) {
                return Directionality(
                  textDirection: _locale.direction,
                  child: child ?? const SizedBox.shrink(),
                );
              },
              home: widget.home ?? const HomePage(),
              onGenerateRoute: _onGenerateRoute,
            );
          },
        ),
      ),
    );
  }
}
