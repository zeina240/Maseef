import 'package:flutter/material.dart';
import 'package:maseef_app/auth/auth_models.dart';
import 'package:maseef_app/auth/auth_scope.dart';
import 'package:maseef_app/l10n/locale_scope.dart';
import 'package:maseef_app/theme/maseef_theme.dart';
import 'package:maseef_app/widgets/auth_frame.dart';
import 'package:maseef_app/widgets/auth_widgets.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  String _role = 'customer';
  bool _busy = false;
  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;
  String? _confirmError;
  String? _errorCode;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password, _confirm]) {
      c.dispose();
    }
    for (final f in [
      _nameFocus,
      _emailFocus,
      _phoneFocus,
      _passwordFocus,
      _confirmFocus,
    ]) {
      f.dispose();
    }
    super.dispose();
  }

  void _clearErrors() {
    _nameError = null;
    _emailError = null;
    _phoneError = null;
    _passwordError = null;
    _confirmError = null;
    _errorCode = null;
  }

  Future<void> _submit() async {
    if (_busy) return;
    final name = _name.text.trim();
    final email = _email.text.trim();
    final phone = _phone.text.trim();
    final password = _password.text;

    final nameError = (name.isEmpty || name.length > 150)
        ? 'invalid_name'
        : null;
    final emailError = (!email.contains('@') || email.length > 255)
        ? 'invalid_email'
        : null;
    final phoneError = (phone.isNotEmpty && phone.length > 30)
        ? 'invalid_phone'
        : null;
    final passwordError = password.isEmpty
        ? 'password_required'
        : (password.length < 10 || password.length > 128)
        ? 'invalid_password'
        : null;
    final confirmError = _confirm.text.isEmpty
        ? 'confirm_required'
        : (password != _confirm.text ? 'password_mismatch' : null);
    final roleError = (_role != 'customer' && _role != 'owner')
        ? 'invalid_role'
        : null;

    final failed = [
      nameError,
      emailError,
      phoneError,
      passwordError,
      confirmError,
      roleError,
    ].any((e) => e != null);
    if (failed) {
      setState(() {
        _nameError = nameError;
        _emailError = emailError;
        _phoneError = phoneError;
        _passwordError = passwordError;
        _confirmError = confirmError;
        _errorCode = roleError;
      });
      // Focus the first invalid field so it scrolls into view.
      final first = nameError != null
          ? _nameFocus
          : emailError != null
          ? _emailFocus
          : phoneError != null
          ? _phoneFocus
          : passwordError != null
          ? _passwordFocus
          : confirmError != null
          ? _confirmFocus
          : null;
      first?.requestFocus();
      return;
    }

    setState(() {
      _busy = true;
      _clearErrors();
    });
    try {
      final session = AuthScope.read(context);
      if (session == null) throw const AuthException('network');
      await session.register(
        fullName: name,
        email: email,
        password: password,
        phone: phone.isEmpty ? null : phone,
        role: _role,
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (error.code == 'email_taken') {
          _emailError = error.code;
          _emailFocus.requestFocus();
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

  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context).strings;
    final error = _errorCode == null ? null : strings.authError(_errorCode!);
    return AuthFrame(
      title: strings.registerHeading,
      subtitle: strings.registerSubtitle,
      maxFormWidth: 560,
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
            Text(
              strings.roleLabel,
              style: const TextStyle(
                color: MaseefColors.navy,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _RoleCard(
                      labelKey: const Key('role-customer'),
                      icon: Icons.luggage_outlined,
                      title: strings.customerRole,
                      hint: strings.roleCustomerHint,
                      selected: _role == 'customer',
                      onTap: _busy
                          ? null
                          : () => setState(() => _role = 'customer'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RoleCard(
                      labelKey: const Key('role-owner'),
                      icon: Icons.villa_outlined,
                      title: strings.ownerRole,
                      hint: strings.roleOwnerHint,
                      selected: _role == 'owner',
                      onTap: _busy
                          ? null
                          : () => setState(() => _role = 'owner'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Always visible: it explains what a host account does and does
            // not do, and that registration cannot create an admin.
            _RegisterInfoNote(key: const Key('register-owner-note')),
            const SizedBox(height: 20),
            AuthTextField(
              key: const Key('register-name'),
              controller: _name,
              focusNode: _nameFocus,
              label: strings.fullName,
              icon: Icons.person_outline_rounded,
              errorText: _nameError == null
                  ? null
                  : strings.authError(_nameError!),
              enabled: !_busy,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
              onSubmitted: (_) => _emailFocus.requestFocus(),
            ),
            const SizedBox(height: 16),
            AuthFieldPair(
              first: AuthTextField(
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
                onSubmitted: (_) => _phoneFocus.requestFocus(),
              ),
              second: AuthTextField(
                key: const Key('register-phone'),
                controller: _phone,
                focusNode: _phoneFocus,
                label: strings.phoneOptional,
                icon: Icons.phone_outlined,
                errorText: _phoneError == null
                    ? null
                    : strings.authError(_phoneError!),
                enabled: !_busy,
                latin: true,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                onChanged: (_) {
                  if (_phoneError != null) setState(() => _phoneError = null);
                },
                onSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
              gap: 14,
              breakpoint: 520,
            ),
            const SizedBox(height: 16),
            AuthFieldPair(
              first: PasswordField(
                key: const Key('auth-password'),
                toggleKey: const Key('auth-password-toggle'),
                controller: _password,
                focusNode: _passwordFocus,
                label: strings.password,
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
              second: PasswordField(
                key: const Key('register-confirm'),
                toggleKey: const Key('register-confirm-toggle'),
                controller: _confirm,
                focusNode: _confirmFocus,
                label: strings.confirmPassword,
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
              gap: 14,
              breakpoint: 520,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4),
              child: Text(
                strings.passwordHint,
                style: const TextStyle(
                  color: MaseefColors.muted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 22),
            AuthSubmitButton(
              key: const Key('auth-submit'),
              label: strings.register,
              busyLabel: strings.creatingAccount,
              busy: _busy,
              onPressed: _submit,
            ),
            const SizedBox(height: 16),
            AuthLinkRow(
              prompt: strings.haveAccount,
              action: strings.signIn,
              actionKey: const Key('auth-go-login'),
              onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the two account types, as a selectable card.
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.labelKey,
    required this.icon,
    required this.title,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final Key labelKey;
  final IconData icon;
  final String title;
  final String hint;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? MaseefColors.aqua : const Color(0xFFF7FBFD),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? MaseefColors.navy : MaseefColors.line,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        icon,
                        size: 22,
                        color: selected ? MaseefColors.navy : MaseefColors.blue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          key: labelKey,
                          style: TextStyle(
                            color: MaseefColors.navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 20,
                        color: selected
                            ? MaseefColors.navy
                            : MaseefColors.skyBlue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hint,
                    style: const TextStyle(
                      color: MaseefColors.muted,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A friendly "good to know" card under the Guest / Host choice. It is
/// information, not a warning: soft water-blue tint, a round info badge and
/// three short points that carry the same facts as the original sentence.
class _RegisterInfoNote extends StatelessWidget {
  const _RegisterInfoNote({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context).strings;
    final points = [
      strings.registerNoteHost,
      strings.registerNoteLink,
      strings.registerNoteAdmin,
    ];
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: MaseefColors.aqua.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MaseefColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 18,
                    color: MaseefColors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        strings.registerNoteTitle,
                        style: const TextStyle(
                          color: MaseefColors.navy,
                          fontSize: 14,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final point in points)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 7),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: MaseefColors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: SizedBox(width: 5, height: 5),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                point,
                                style: const TextStyle(
                                  color: MaseefColors.ink,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
