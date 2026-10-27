import 'package:flutter/material.dart';
import 'package:maseef_app/l10n/locale_scope.dart';
import 'package:maseef_app/theme/maseef_theme.dart';
import 'package:maseef_app/widgets/brand_mark.dart';
import 'package:maseef_app/widgets/language_switcher.dart';
import 'package:maseef_app/widgets/optical_align.dart';

/// Width from which the image and the form sit side by side.
const double kAuthSplitBreakpoint = 720;

/// The shared shell of every sign-in screen.
///
/// * Wide screens (720 px and up): the `sign.png` hero on one side (half the
///   width on large screens, about 38% on tablets) and the form on the other.
/// * Phones: a compact image banner on top and the form in a rounded sheet that
///   overlaps it, scrolling as one page so the keyboard never hides a field.
///
/// The hero is placed first, so it lands on the start side: left in English
/// and right in Arabic.
class AuthFrame extends StatelessWidget {
  const AuthFrame({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.maxFormWidth = 440,
  });

  /// Heading of the form.
  final String title;
  final String? subtitle;
  final Widget child;

  /// Widest the form column may grow on large screens.
  final double maxFormWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      backgroundColor: Colors.white,
      body: width >= kAuthSplitBreakpoint
          ? _SplitLayout(
              title: title,
              subtitle: subtitle,
              maxFormWidth: maxFormWidth,
              child: child,
            )
          : _PhoneLayout(title: title, subtitle: subtitle, child: child),
    );
  }
}

class _SplitLayout extends StatelessWidget {
  const _SplitLayout({
    required this.title,
    required this.subtitle,
    required this.maxFormWidth,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final double maxFormWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final strings = LocaleScope.of(context).strings;
    // Half the page on laptops and desktops; a narrower strip on tablets so
    // the form keeps a comfortable width.
    final heroWidth = width >= 1000
        ? width * 0.5
        : (width * 0.38).clamp(280.0, 420.0);
    final margin = width >= 1000 ? 48.0 : 28.0;
    return Row(
      children: [
        SizedBox(
          key: const Key('auth-hero'),
          width: heroWidth,
          child: _AuthHero(large: width >= 1000, wide: heroWidth >= 640),
        ),
        Expanded(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [Colors.white, Colors.white, Color(0xFFFBF7EE)],
                stops: [0, 0.55, 1],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(margin - 8, 12, margin - 8, 0),
                    child: Row(
                      children: [
                        TextButton(
                          key: const Key('auth-back'),
                          onPressed: () => Navigator.of(context).maybePop(),
                          style: TextButton.styleFrom(
                            foregroundColor: MaseefColors.navy,
                            minimumSize: const Size(48, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const OpticalLift(
                                textSize: 15,
                                child: BackButtonIcon(),
                              ),
                              const SizedBox(width: 6),
                              Text(strings.back),
                            ],
                          ),
                        ),
                        const Spacer(),
                        const LanguageSwitcher(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.symmetric(
                            horizontal: margin,
                            vertical: 16,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight - 32,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: maxFormWidth,
                                ),
                                child: _FormBody(
                                  title: title,
                                  subtitle: subtitle,
                                  headingSize: 32,
                                  child: child,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhoneLayout extends StatelessWidget {
  const _PhoneLayout({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  static const double _overlap = 28;

  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context).strings;
    final top = MediaQuery.paddingOf(context).top;
    final bannerHeight = 210 + top;
    return LayoutBuilder(
      builder: (context, constraints) {
        final sheetTop = bannerHeight - _overlap;
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: bannerHeight,
                child: const _AuthHero(compact: true),
              ),
              Padding(
                padding: EdgeInsets.only(top: sheetTop),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - sheetTop,
                  ),
                  child: DecoratedBox(
                    key: const Key('auth-sheet'),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: MaseefColors.navy.withValues(alpha: 0.12),
                          blurRadius: 24,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
                          child: _FormBody(
                            title: title,
                            subtitle: subtitle,
                            headingSize: 28,
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: top + 8,
                left: 8,
                right: 12,
                child: Row(
                  children: [
                    Material(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: const CircleBorder(),
                      child: IconButton(
                        key: const Key('auth-back'),
                        tooltip: strings.back,
                        onPressed: () => Navigator.of(context).maybePop(),
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        icon: const BackButtonIcon(),
                        color: MaseefColors.navy,
                      ),
                    ),
                    const Spacer(),
                    const LanguageSwitcher(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Heading, optional subtitle and the form, fading and sliding in once.
class _FormBody extends StatelessWidget {
  const _FormBody({
    required this.title,
    required this.subtitle,
    required this.headingSize,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final double headingSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          key: const Key('auth-title'),
          style: TextStyle(
            color: MaseefColors.navy,
            fontSize: headingSize,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            width: 44,
            height: 3,
            decoration: BoxDecoration(
              color: MaseefColors.gold,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 14),
          Text(
            subtitle!,
            key: const Key('auth-subtitle'),
            style: const TextStyle(
              color: MaseefColors.muted,
              fontSize: 15.5,
              height: 1.55,
            ),
          ),
        ],
        const SizedBox(height: 26),
        child,
      ],
    );
    if (reduceMotion) return content;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 14),
          child: child,
        ),
      ),
      child: content,
    );
  }
}

/// The `sign.png` photograph with a navy wash and a short welcome message.
///
/// The photo is decorative, so it is excluded from semantics; the message
/// carries the meaning. It is cropped with [BoxFit.cover], never stretched.
class _AuthHero extends StatelessWidget {
  const _AuthHero({this.compact = false, this.large = false, this.wide = true});

  /// Phone banner: image and one line of text only.
  final bool compact;
  final bool large;

  /// Wide enough for the larger text size.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context).strings;
    final pad = compact ? 20.0 : (large ? 48.0 : 28.0);
    // 40 px needs a wide panel; on a 1000-1200 px window the panel is about
    // 500-600 px and long Arabic lines would leave a lone word on the last row.
    final headline = compact ? 21.0 : (large ? (wide ? 40.0 : 34.0) : 26.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/sign.png',
          fit: BoxFit.cover,
          // The photo is portrait; on a wide strip keep the pool and flowers,
          // on a phone banner keep the water line and sunset.
          alignment: Alignment(0, compact ? 0.55 : 0.35),
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
          errorBuilder: (context, error, stackTrace) => const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [MaseefColors.navy, MaseefColors.blue],
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                MaseefColors.navy.withValues(alpha: compact ? 0.45 : 0.4),
                MaseefColors.navy.withValues(alpha: 0.0),
                MaseefColors.navy.withValues(alpha: compact ? 0.78 : 0.86),
              ],
              stops: const [0, 0.38, 1],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            // On phones the form sheet overlaps the bottom of the banner, so
            // the message sits above that overlap.
            padding: EdgeInsets.fromLTRB(
              pad,
              pad,
              pad,
              compact ? pad + _PhoneLayout._overlap : pad,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!compact) _HeroBrand(large: large),
                const Spacer(),
                if (!compact)
                  Container(
                    width: 52,
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: MaseefColors.gold,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                Text(
                  strings.authTagline,
                  key: const Key('auth-hero-tagline'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: headline,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    shadows: const [
                      Shadow(color: Color(0x66000000), blurRadius: 12),
                    ],
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 12),
                  Text(
                    strings.authTaglineSub,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: large ? 18 : 15.5,
                      height: 1.5,
                      shadows: const [
                        Shadow(color: Color(0x55000000), blurRadius: 10),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroBrand extends StatelessWidget {
  const _HeroBrand({required this.large});

  final bool large;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: BrandMark(size: large ? 46 : 38),
        ),
        const SizedBox(width: 12),
        const Text(
          'MASEEF',
          textDirection: TextDirection.ltr,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            height: 1,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
            shadows: [Shadow(color: Color(0x66000000), blurRadius: 10)],
          ),
        ),
      ],
    );
  }
}
