import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maseef_app/l10n/locale_scope.dart';
import 'package:maseef_app/theme/maseef_theme.dart';

const _fieldFill = Color(0xFFF7FBFD);
const _errorInk = Color(0xFF8C2F2F);

OutlineInputBorder _border(Color color, [double width = 1]) =>
    OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: color, width: width),
    );

InputDecoration _decoration({
  required String label,
  String? hint,
  String? errorText,
  IconData? icon,
  Widget? suffix,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    errorText: errorText,
    errorMaxLines: 3,
    filled: true,
    fillColor: _fieldFill,
    floatingLabelStyle: const TextStyle(
      color: MaseefColors.navy,
      fontWeight: FontWeight.w700,
    ),
    labelStyle: const TextStyle(color: MaseefColors.muted, fontSize: 15),
    prefixIcon: icon == null
        ? null
        : Icon(icon, size: 21, color: MaseefColors.blue),
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    border: _border(MaseefColors.line),
    enabledBorder: _border(MaseefColors.line),
    disabledBorder: _border(MaseefColors.line),
    focusedBorder: _border(MaseefColors.navy, 1.8),
    errorBorder: _border(const Color(0xFFC25B5B)),
    focusedErrorBorder: _border(const Color(0xFFC25B5B), 1.8),
    errorStyle: const TextStyle(color: _errorInk, fontSize: 13, height: 1.35),
  );
}

/// A single-line text field in the shared authentication style.
///
/// Fields that always hold Latin text (email, phone) pass [latin] so the text
/// stays left-to-right, but it is aligned to the *end* of the field in Arabic
/// so it lines up with the label and icon instead of floating on the far side.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.errorText,
    this.icon,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.latin = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? errorText;
  final IconData? icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool latin;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textDirection: latin ? TextDirection.ltr : null,
      textAlign: latin
          ? (rtl ? TextAlign.right : TextAlign.left)
          : TextAlign.start,
      style: const TextStyle(
        color: MaseefColors.ink,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: _decoration(
        label: label,
        hint: hint,
        errorText: errorText,
        icon: icon,
      ),
    );
  }
}

/// A password field with its own show/hide eye.
///
/// The visibility lives in this widget's own [State], so every password field
/// on a page toggles independently: revealing "New password" never reveals
/// "Confirm new password".
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.toggleKey,
    this.hint,
    this.errorText,
    this.textInputAction,
    this.autofillHints,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;

  /// Key of the eye button (each field needs its own).
  final Key toggleKey;
  final String? hint;
  final String? errorText;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context).strings;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final label = _obscured ? strings.showPassword : strings.hidePassword;
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      obscureText: _obscured,
      enableSuggestions: false,
      autocorrect: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      textDirection: TextDirection.ltr,
      textAlign: rtl ? TextAlign.right : TextAlign.left,
      style: const TextStyle(
        color: MaseefColors.ink,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: _decoration(
        label: widget.label,
        hint: widget.hint,
        errorText: widget.errorText,
        icon: Icons.lock_outline_rounded,
        suffix: IconButton(
          key: widget.toggleKey,
          tooltip: label,
          // 48 x 48 keeps the eye comfortable to hit on a phone.
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          onPressed: widget.enabled
              ? () => setState(() => _obscured = !_obscured)
              : null,
          // The icon shows the current state: an eye with a slash means the
          // password is hidden (dots); an open eye means it is visible.
          // The tooltip names the action a press performs.
          icon: Icon(
            _obscured
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 22,
            color: MaseefColors.muted,
          ),
        ),
      ),
    );
  }
}

enum AuthNoticeTone { error, success, info }

/// A soft, rounded message box: errors, success confirmations and notes.
class AuthNotice extends StatelessWidget {
  const AuthNotice({
    super.key,
    required this.message,
    this.title,
    this.tone = AuthNoticeTone.info,
  });

  final String message;
  final String? title;
  final AuthNoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, border, ink, icon) = switch (tone) {
      AuthNoticeTone.error => (
        const Color(0xFFFBEEEE),
        const Color(0xFFE9C6C6),
        _errorInk,
        Icons.error_outline_rounded,
      ),
      AuthNoticeTone.success => (
        MaseefColors.aqua,
        MaseefColors.skyBlue,
        MaseefColors.navy,
        Icons.check_circle_outline_rounded,
      ),
      AuthNoticeTone.info => (
        MaseefColors.goldSoft,
        MaseefColors.gold.withValues(alpha: 0.35),
        MaseefColors.ink,
        Icons.info_outline_rounded,
      ),
    };
    final iconColor = tone == AuthNoticeTone.info ? MaseefColors.gold : ink;
    return Semantics(
      container: true,
      liveRegion: tone != AuthNoticeTone.info,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          title!,
                          style: TextStyle(
                            color: ink,
                            fontSize: 15,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    Text(
                      message,
                      style: TextStyle(
                        color: tone == AuthNoticeTone.info ? ink : ink,
                        fontSize: 13.5,
                        height: 1.5,
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

/// The main call to action. While [busy] it shows a spinner and a progress
/// label and ignores presses, so a form cannot be submitted twice.
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.busyLabel,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final String busyLabel;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: MaseefColors.navy.withValues(alpha: busy ? 0.08 : 0.24),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: busy
            ? null
            : () {
                HapticFeedback.selectionClick();
                onPressed();
              },
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: MaseefColors.navy,
          foregroundColor: Colors.white,
          // Keep the same navy while busy instead of the default grey.
          disabledBackgroundColor: MaseefColors.navy.withValues(alpha: 0.85),
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: Row(
            key: ValueKey(busy),
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy) ...[
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Text(
                  busy ? busyLabel : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Prompt  action" row such as "Need an account? Create account".
class AuthLinkRow extends StatelessWidget {
  const AuthLinkRow({
    super.key,
    required this.prompt,
    required this.action,
    required this.onPressed,
    required this.actionKey,
  });

  final String prompt;
  final String action;
  final VoidCallback? onPressed;
  final Key actionKey;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      children: [
        Text(
          prompt,
          style: const TextStyle(color: MaseefColors.muted, fontSize: 14.5),
        ),
        TextButton(
          key: actionKey,
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: MaseefColors.blue,
            minimumSize: const Size(48, 44),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: Text(action),
        ),
      ],
    );
  }
}

/// Two fields side by side when there is room, stacked otherwise.
class AuthFieldPair extends StatelessWidget {
  const AuthFieldPair({
    super.key,
    required this.first,
    required this.second,
    this.gap = 14,
    this.breakpoint = 500,
  });

  final Widget first;
  final Widget second;
  final double gap;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              first,
              SizedBox(height: gap),
              second,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            SizedBox(width: gap),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}
