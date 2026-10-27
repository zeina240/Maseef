import 'package:flutter/material.dart';
import 'package:maseef_app/theme/maseef_theme.dart';

/// Section title with the small gold accent used on every details section, so
/// headings stay the same size and weight across the page.
class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.title, this.trailing});

  final String title;

  /// Optional widget at the end of the title row (for example a status badge).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontSize: 24, height: 1.25),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: trailing!,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: 32,
          height: 3,
          decoration: BoxDecoration(
            color: MaseefColors.gold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

/// A titled section on the details page.
///
/// By default it is a white card (used where the content needs a surface, such
/// as the calendar and the location). With [flat] it sits directly on the page
/// background, so a run of sections does not read as a pile of identical boxes.
class DetailSection extends StatelessWidget {
  const DetailSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.flat = false,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(title: title, trailing: trailing),
        const SizedBox(height: 20),
        child,
      ],
    );
    if (flat) {
      return SizedBox(width: double.infinity, child: content);
    }
    final padding = MediaQuery.sizeOf(context).width >= 600 ? 28.0 : 20.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MaseefColors.line),
      ),
      child: content,
    );
  }
}
