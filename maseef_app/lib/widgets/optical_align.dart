import 'package:flutter/widgets.dart';

/// Vertical alignment of icons against Tajawal text.
///
/// A [Row] with `crossAxisAlignment: center` centres the icon on the text's
/// *line box*, but not on what the eye reads as the middle of the glyphs.
/// Tajawal's `hhea` metrics are ascent 0.643 em and descent 0.357 em, and its
/// cap height is 0.633 em. So the line box is centred 0.143 em above the
/// baseline while the middle of the letters sits about 0.27-0.32 em above it
/// (x-height and cap-height centres). Text therefore looks roughly 0.13 em
/// high inside its own line box, which is what makes plain centred icons look
/// low.
///
/// The correction scales with the text size instead of being a fixed pixel
/// nudge, so it stays right for a 13 px caption and an 18 px heading alike.
/// It is purely a paint offset: layout, hit testing and RTL are unaffected.
const double kTajawalOpticalLift = 0.13;

/// How far (in logical pixels) a glyph of [fontSize] sits above the centre of
/// its line box.
double opticalLift(double fontSize) => fontSize * kTajawalOpticalLift;

/// An icon that lines up with the middle of neighbouring text of [textSize].
///
/// Use inside a centred `Row`:
/// `Row(children: [OpticalIcon(Icons.call, size: 17, textSize: 15), Text(...)])`.
class OpticalIcon extends StatelessWidget {
  const OpticalIcon({
    super.key,
    required this.icon,
    required this.size,
    required this.color,
    required this.textSize,
    this.lineHeight,
  });

  final IconData icon;
  final double size;
  final Color color;

  /// Font size of the text this icon sits beside.
  final double textSize;

  /// Height of that text's first line, for rows aligned to the top of a
  /// multi-line paragraph. Leave null in a centred row.
  final double? lineHeight;

  @override
  Widget build(BuildContext context) {
    final glyph = Transform.translate(
      offset: Offset(0, -opticalLift(textSize)),
      child: Icon(icon, size: size, color: color),
    );
    final height = lineHeight;
    if (height == null) return glyph;
    return SizedBox(
      height: height > size ? height : size,
      child: Center(child: glyph),
    );
  }
}

/// Lifts any leading widget (such as `BackButtonIcon`) onto the middle of the
/// neighbouring text of [textSize].
class OpticalLift extends StatelessWidget {
  const OpticalLift({super.key, required this.textSize, required this.child});

  final double textSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, -opticalLift(textSize)),
      child: child,
    );
  }
}

/// Moves text *down* to the middle of a neighbouring icon or badge.
///
/// Use when the icon is the fixed element (for example a round badge) and the
/// text is what has to follow it. [fontSize] is the text's own size; for a
/// block of several sizes pass their average.
class OpticalText extends StatelessWidget {
  const OpticalText({super.key, required this.fontSize, required this.child});

  final double fontSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, opticalLift(fontSize)),
      child: child,
    );
  }
}
