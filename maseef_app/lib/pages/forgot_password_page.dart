import 'package:flutter/material.dart';
import 'package:maseef_app/auth/auth_models.dart';
import 'package:maseef_app/auth/auth_scope.dart';
import 'package:maseef_app/l10n/locale_scope.dart';
import 'package:maseef_app/widgets/auth_frame.dart';
import 'package:maseef_app/widgets/auth_widgets.dart';

/// Step one of password recovery: ask for a reset link by email.
///
/// The confirmation is the same for every address, so the page never tells
/// anyone whether an email is registered.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.initialEmail = ''});

  /// Pre-fills the field with what the user already typed on the sign-in page.
  final String initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail,
  );
  final _emailFocus = FocusNode();
  bool _busy = false;
  bool _sent = false;
  String? _emailError;
  String? _errorCode;

  @override
  void dispose() {
    _email.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    if (!email.contains('@') || email.length > 255) {
      setState(() {
        _emailError = 'invalid_email';
        _errorCode = null;
      });
      _emailFocus.requestFocus();
      return;
    }
    setState(() {
      _busy = true;
      _emailError = null;
      _errorCode = null;
    });
    try {
      final session = AuthScope.read(context);
      if (session == null) throw const AuthException('network');
      final isArabic = LocaleScope.of(context).strings.isArabic;
      await session.requestPasswordReset(
        email: email,
        locale: isArabic ? 'ar' : 'en',
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _sent = true;
      });
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

  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context).strings;
    final error = _errorCode == null ? null : strings.authError(_errorCode!);
    return AuthFrame(
      title: strings.forgotHeading,
      subtitle: _sent ? null : strings.forgotSubtitle,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _sent
            ? _SentView(
                key: const ValueKey('sent'),
                onAnotherEmail: () => setState(() => _sent = false),
              )
            : Column(
                key: const ValueKey('form'),
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
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    onChanged: (_) {
                      if (_emailError != null) {
                        setState(() => _emailError = null);
                      }
                    },
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 20),
                  AuthSubmitButton(
                    key: const Key('auth-submit'),
                    label: strings.sendResetLink,
                    busyLabel: strings.sendingLink,
                    busy: _busy,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton.icon(
                      key: const Key('auth-go-login'),
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).maybePop(),
                      icon: const BackButtonIcon(),
                      label: Text(strings.backToSignIn),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 44),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SentView extends StatelessWidget {
  const _SentView({super.key, required this.onAnotherEmail});

  final VoidCallback onAnotherEmail;

  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context).strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthNotice(
          key: const Key('forgot-success'),
          title: strings.forgotSuccessTitle,
          message: strings.forgotSuccessBody,
          tone: AuthNoticeTone.success,
        ),
        const SizedBox(height: 20),
        AuthSubmitButton(
          key: const Key('auth-go-login'),
          label: strings.backToSignIn,
          busyLabel: strings.backToSignIn,
          busy: false,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            key: const Key('forgot-another'),
            onPressed: onAnotherEmail,
            style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
            child: Text(strings.useAnotherEmail),
          ),
        ),
      ],
    );
  }
}
