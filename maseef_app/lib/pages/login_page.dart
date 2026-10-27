import 'package:flutter/material.dart';
import 'package:maseef_app/auth/auth_models.dart';
import 'package:maseef_app/auth/auth_scope.dart';
import 'package:maseef_app/l10n/locale_scope.dart';
import 'package:maseef_app/pages/forgot_password_page.dart';
import 'package:maseef_app/pages/register_page.dart';
import 'package:maseef_app/theme/maseef_theme.dart';
import 'package:maseef_app/widgets/auth_frame.dart';
import 'package:maseef_app/widgets/auth_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _busy = false;
  String? _emailError;
  String? _passwordError;
  String? _errorCode;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    final password = _password.text;

    String? emailError;
    String? passwordError;
    if (!email.contains('@') || email.length > 255) {
      emailError = 'invalid_email';
    }
    if (password.isEmpty) {
      passwordError = 'password_required';
    } else if (password.length < 10 || password.length > 128) {
      passwordError = 'invalid_password';
    }
    if (emailError != null || passwordError != null) {
      setState(() {
        _emailError = emailError;
        _passwordError = passwordError;
        _errorCode = null;
      });
      // Jump to the first problem so it is never off-screen on a phone.
      (emailError != null ? _emailFocus : _passwordFocus).requestFocus();
      return;
    }

    setState(() {
      _busy = true;
      _emailError = null;
      _passwordError = null;
      _errorCode = null;
    });
    try {
      final session = AuthScope.read(context);
      if (session == null) throw const AuthException('network');
      await session.login(email: email, password: password);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorCode = error.code;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorCode = 'network';
      });
    }
  }

  void _openForgot() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            ForgotPasswordPage(initialEmail: _email.text.trim()),
      ),
    );
  }

  void _openRegister() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (context) => const RegisterPage()));
  }

  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context).strings;
    final error = _errorCode == null ? null : strings.authError(_errorCode!);
    return AuthFrame(
      title: strings.welcomeBack,
      subtitle: strings.signInSubtitle,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null) ...[
              AuthNotice(
                key: const Key('auth-error'),
                message: error,
                tone: AuthNoticeTone.error,
              ),
              const SizedBox(height: 16),
            ],
            AuthTextField(
              key: const Key('auth-email'),
              controller: _email,
              focusNode: _emailFocus,
              label: strings.email,
              icon: Icons.mail_outline_rounded,
              errorText: _emailError == null
                  ? null
                  : strings.authError(_emailError!),
              enabled: !_busy,
              latin: true,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              onChanged: (_) {
                if (_emailError != null) setState(() => _emailError = null);
              },
              onSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            const SizedBox(height: 16),
            PasswordField(
              key: const Key('auth-password'),
              toggleKey: const Key('auth-password-toggle'),
              controller: _password,
              focusNode: _passwordFocus,
              label: strings.password,
              errorText: _passwordError == null
                  ? null
                  : strings.authError(_passwordError!),
              enabled: !_busy,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onChanged: (_) {
                if (_passwordError != null) {
                  setState(() => _passwordError = null);
                }
              },
              onSubmitted: (_) => _submit(),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                key: const Key('auth-go-forgot'),
                onPressed: _busy ? null : _openForgot,
                style: TextButton.styleFrom(
                  foregroundColor: MaseefColors.blue,
                  minimumSize: const Size(48, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(strings.forgotPasswordLink),
              ),
            ),
            const SizedBox(height: 8),
            AuthSubmitButton(
              key: const Key('auth-submit'),
              label: strings.signIn,
              busyLabel: strings.signingIn,
              busy: _busy,
              onPressed: _submit,
            ),
            const SizedBox(height: 18),
            AuthLinkRow(
              prompt: strings.needAccount,
              action: strings.register,
              actionKey: const Key('auth-go-register'),
              onPressed: _busy ? null : _openRegister,
            ),
          ],
        ),
      ),
    );
  }
}
