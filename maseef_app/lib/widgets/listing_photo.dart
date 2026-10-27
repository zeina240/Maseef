import 'package:flutter/material.dart';
import 'package:maseef_app/l10n/locale_scope.dart';
import 'package:maseef_app/theme/maseef_theme.dart';

/// A bundled chalet photo. The graceful fallback appears only when there is no
/// photo at all or when the image genuinely fails to load; it never swaps in
/// another picture.
class ListingPhoto extends StatelessWidget {
  const ListingPhoto({
    super.key,
    required this.asset,
    required this.id,
    this.aspectRatio = 4 / 3,
    this.borderRadius = BorderRadius.zero,
    this.fit = BoxFit.cover,
    this.compact = false,
    this.backdrop = MaseefColors.aqua,
  });

  final String? asset;
  final String id;

  /// When null the photo fills whatever space its parent gives it.
  final double? aspectRatio;
  final BorderRadius borderRadius;
  final BoxFit fit;

  /// Icon-only fallback for small tiles where text would not fit.
  final bool compact;

  /// Shown behind the photo while it decodes.
  final Color backdrop;

  @override
  Widget build(BuildContext context) {
    final fill = aspectRatio == null;
    final Widget content = asset == null
        ? _fallback(context)
        : ColoredBox(
            color: backdrop,
            child: Image.asset(
              asset!,
              key: Key('photo-$id'),
              fit: fit,
              width: double.infinity,
              height: fill ? double.infinity : null,
              alignment: Alignment.center,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
              frameBuilder: (context, child, frame, synchronous) {
                if (synchronous) return child;
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOut,
                  child: child,
                );
              },
              errorBuilder: (context, error, stackTrace) => _fallback(context),
            ),
          );

    return ClipRRect(
      borderRadius: borderRadius,
      child: fill
          ? SizedBox.expand(child: content)
          : AspectRatio(aspectRatio: aspectRatio!, child: content),
    );
  }

  Widget _fallback(BuildContext context) {
    final strings = LocaleScope.of(context).strings;
    return DecoratedBox(
      key: Key('photo-fallback-$id'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MaseefColors.blue, MaseefColors.navy],
        ),
      ),
      child: Center(
        child: compact
            ? Tooltip(
                message: strings.photoUnavailable,
                child: const Icon(
                  Icons.villa_outlined,
                  color: Colors.white70,
                  size: 22,
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.villa_outlined,
                      color: Colors.white,
                      size: 36,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.photoUnavailable,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
