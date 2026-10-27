import 'package:flutter/material.dart';
import 'package:maseef_app/l10n/app_strings.dart';
import 'package:maseef_app/l10n/locale_scope.dart';
import 'package:maseef_app/models/rating.dart';
import 'package:maseef_app/theme/maseef_theme.dart';
import 'package:maseef_app/widgets/optical_align.dart';

/// Star rating shown with the chalet's facts.
///
/// **Preview only.** No endpoint accepts a rating yet, so nothing chosen here
/// is sent, stored or counted, and the widget never claims otherwise:
///
/// * With no genuine [summary] it shows five outline stars and "No ratings
///   yet" - never a default score or a review count.
/// * Tapping a star selects it and reveals a short prompt, a "not saved yet"
///   note and a "Confirm preview" action. Nothing appears before a star is
///   chosen.
/// * Tapping a different star updates the selection and returns to the
///   unconfirmed prompt. Confirming only changes the message to "Preview
///   confirmed ... Nothing was saved."
class RatingPreview extends StatefulWidget {
  const RatingPreview({
    super.key,
    this.summary,
    this.captionBelow = false,
    this.maxPanelWidth = 420,
  });

  /// A genuine average and count, when a reviews backend supplies one.
  final RatingSummary? summary;

  /// Put the caption under the stars instead of beside them.
  final bool captionBelow;

  /// Upper bound for the prompt panel so it stays compact on wide screens.
  final double maxPanelWidth;

  @override
  State<RatingPreview> createState() => _RatingPreviewState();
}

const double _starTarget = 44;
const double _starGlyph = 28;
const double _starInset = (_starTarget - _starGlyph) / 2;

class _RatingPreviewState extends State<RatingPreview> {
  int _stars = 0;
  bool _confirmed = false;

  void _select(int stars) {
    if (stars == _stars) return;
    setState(() {
      _stars = stars;
      _confirmed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context).strings;
    final summary = widget.summary != null && widget.summary!.isShowable
        ? widget.summary
        : null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // Each 28 px glyph sits in a 44 px target, leaving 8 px of empty hit area
    // before the first glyph. Painting the row that far toward the start edge
    // lines the first star up with the text and tiles above it, without
    // shrinking any target (hit testing follows the transform).
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final stars = Semantics(
      container: true,
      label: strings.ratingStarsLabel,
      child: Transform.translate(
        offset: Offset(rtl ? _starInset : -_starInset, 0),
        child: Wrap(
          key: const Key('rating-stars'),
          children: [for (var i = 1; i <= 5; i++) _star(i, strings)],
        ),
      ),
    );

    final Widget caption;
    if (summary != null) {
      caption = Semantics(
        label: strings.ratingSemantics(
          summary.average.toStringAsFixed(1),
          summary.count,
        ),
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              summary.average.toStringAsFixed(1),
              key: const Key('rating-average'),
              style: const TextStyle(
                color: MaseefColors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              strings.reviewCount(summary.count),
              key: const Key('rating-count'),
              style: const TextStyle(color: MaseefColors.muted, fontSize: 13),
            ),
          ],
        ),
      );
    } else {
      caption = Text(
        strings.noRatingsYet,
        key: const Key('no-ratings-yet'),
        style: const TextStyle(color: MaseefColors.muted, fontSize: 13),
      );
    }

    final header = widget.captionBelow
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [stars, caption],
          )
        : Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 0,
            children: [stars, caption],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        AnimatedSize(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: AlignmentDirectional.topStart,
          child: _stars == 0
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: widget.maxPanelWidth),
                    child: _panel(context, strings),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _star(int value, AppStrings strings) {
    final selected = value <= _stars;
    return Semantics(
      button: true,
      selected: _stars == value,
      label: strings.starOf(value),
      excludeSemantics: true,
      child: IconButton(
        key: Key('rating-star-$value'),
        tooltip: strings.starOf(value),
        onPressed: () => _select(value),
        padding: EdgeInsets.zero,
        // 44 x 44 keeps each star easy to hit with a thumb.
        constraints: const BoxConstraints.tightFor(
          width: _starTarget,
          height: _starTarget,
        ),
        iconSize: _starGlyph,
        icon: Icon(
          selected ? Icons.star_rounded : Icons.star_outline_rounded,
          color: selected
              ? MaseefColors.gold
              : MaseefColors.blue.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _panel(BuildContext context, AppStrings strings) {
    final stars = _stars;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        key: const Key('rating-panel'),
        decoration: BoxDecoration(
          color: MaseefColors.aqua,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MaseefColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_confirmed)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const OpticalIcon(
                      icon: Icons.check_circle_outline,
                      size: 20,
                      color: MaseefColors.blue,
                      textSize: 14.5,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        strings.ratingConfirmed(stars),
                        key: const Key('rating-confirmed'),
                        style: const TextStyle(
                          color: MaseefColors.navy,
                          fontSize: 14.5,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Text(
                  strings.ratingPrompt(stars),
                  key: const Key('rating-prompt'),
                  style: const TextStyle(
                    color: MaseefColors.navy,
                    fontSize: 14.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                strings.ratingNotSavedShort,
                key: const Key('rating-preview-note'),
                style: const TextStyle(
                  color: MaseefColors.muted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              if (!_confirmed) ...[
                const SizedBox(height: 10),
                FilledButton(
                  key: const Key('rating-confirm'),
                  onPressed: () => setState(() => _confirmed = true),
                  style: FilledButton.styleFrom(
                    backgroundColor: MaseefColors.navy,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    // Derived from the theme so the label keeps Tajawal.
                    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(strings.ratingConfirmAction),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
