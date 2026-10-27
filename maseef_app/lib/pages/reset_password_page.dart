import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maseef_app/auth/auth_models.dart';
import 'package:maseef_app/auth/auth_scope.dart';
import 'package:maseef_app/l10n/locale_scope.dart';
import 'package:maseef_app/pages/forgot_password_page.dart';
import 'package:maseef_app/pages/login_page.dart';
import 'package:maseef_app/widgets/auth_frame.dart';
import 'package:maseef_app/widgets/auth_widgets.dart';

/// Step two of password recovery: choose a new password with the one-time
/// [token] from the emailed link.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, required this.token});

  /// The `token` query parameter of the reset link (null when absent).
  final String? token;

  /// A token is an opaque URL-safe string. This only rejects links that are
  /// clearly missing or mangled; the server decides whether it is still valid.
  static bool looksValid(String? token) {
    if (token == null) return false;
    return RegExp(r'^[A-Za-z0-9._~-]{16,512}$').hasMatch(token);
  }

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  Timer? _redirect;
  bool _busy = false;
  bool _done = false;
  late bool _invalid = !ResetPasswordPage.looksValid(widget.token);
  String? _passwordError;
  String? _confirmError;
  String? _errorCode;

  @override
  void dispose() {
    _redirect?.cancel();
    _password.dispose();
    _confirm.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _done) return;
    final password = _password.text;
    final confirm = _confirm.text;

    final passwordError = password.isEmpty
        ? 'password_required'
        : (password.length < 10 || password.length > 128)
        ? 'invalid_password'
        : null;
    final confirmError = confirm.isEmpty
        ? 'confirm_required'
        : (password != confirm ? 'password_mismatch' : null);
    if (passwordError != null || confirmError != null) {
      setState(() {
        _passwordError = passwordError;
        _confirmError = confirmError;
        _errorCode = null;
      });
      (passwordError != null ? _passwordFocus : _confirmFocus).requestFocus();
      return;
    }

    setState(() {
      _busy = true;
      _passwordError = null;
      _confirmError = null;
      _errorCode = null;
    });
    try {
      final session = AuthScope.read(context);
      if (session == null) throw const AuthException('network');
      await session.resetPassword(token: widget.token!, password: password);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _done = true;
      });
      _redirect = Timer(const Duration(milliseconds: 2500), _goToSignIn);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (error.code == 'invalid_token') {
          _invalid = true;
        } else {
          _errorCode = error.code;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorCode = 'network';
      });
    }
  }

  void _goToSignIn() {
    if (!mounted) return;
    _redirect?.cancel();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (context) => const LoginPage()),
      (route) => route.isFirst,
    );
  }

  void _requestNewLink() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (context) => const ForgotPasswordPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context).strings;
    final error = _errorCode == null ? null : strings.authError(_errorCode!);

    final Widget body;
    if (_invalid) {
      body = Column(
        key: const ValueKey('invalid'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthNotice(
            key: const Key('reset-invalid'),
            title: strings.resetLinkInvalidTitle,
            message: strings.resetLinkInvalidBody,
            tone: AuthNoticeTone.error,
          ),
          const SizedBox(height: 20),
          AuthSubmitButton(
            key: const Key('reset-request-new'),
            label: strings.requestNewLink,
            busyLabel: strings.requestNewLink,
            busy: false,
            onPressed: _requestNewLink,
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              key: const Key('auth-go-login'),
              onPressed: _goToSignIn,
              style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
              child: Text(strings.backToSignIn),
            ),
          ),
        ],
      );
    } else if (_done) {
      body = Column(
        key: const ValueKey('done'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthNotice(
            key: const Key('reset-success'),
            title: strings.resetSuccessTitle,
            message: strings.resetSuccessBody,
            tone: AuthNoticeTone.success,
          ),
          const SizedBox(height: 20),
          AuthSubmitButton(
            key: const Key('auth-go-login'),
            label: strings.goToSignIn,
            busyLabel: strings.goToSignIn,
            busy: false,
            onPressed: _goToSignIn,
          ),
        ],
      );
    } else {
      body = AutofillGroup(
        key: const ValueKey('form'),
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
            PasswordField(
              key: const Key('reset-password'),
              toggleKey: const Key('reset-password-toggle'),
              controller: _password,
              focusNode: _passwordFocus,
              label: strings.newPassword,
              hint: strings.passwordHint,
              errorText: _passwordError == null
                  ? null
                  : strings.authError(_passwordError!),
              enabled: !_busy,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (_) {
                if (_passwordError != null) {
                  setState(() => _passwordError = null);
                }
              },
              onSubmitted: (_) => _confirmFocus.requestFocus(),
            ),
            const SizedBox(height: 16),
            PasswordField(
              key: const Key('reset-confirm'),
              toggleKey: const Key('reset-confirm-toggle'),
              controller: _confirm,
              focusNode: _confirmFocus,
              label: strings.confirmNewPassword,
              errorText: _confirmError == null
                  ? null
                  : strings.authError(_confirmError!),
              enabled: !_busy,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (_) {
                if (_confirmError != null) {
                  setState(() => _confirmError = null);
                }
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 22),
            AuthSubmitButton(
              key: const Key('auth-submit'),
              label: strings.resetPasswordAction,
              busyLabel: strings.updatingPassword,
              busy: _busy,
              onPressed: _submit,
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                key: const Key('auth-go-login'),
                onPressed: _busy ? null : _goToSignIn,
                style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
                child: Text(strings.backToSignIn),
              ),
            ),
          ],
        ),
      );
    }

    return AuthFrame(
      title: strings.resetHeading,
      subtitle: (_invalid || _done) ? null : strings.resetSubtitle,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: body,
      ),
    );
  }
}
