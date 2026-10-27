import 'package:flutter/material.dart';
import 'package:maseef_app/l10n/locale_scope.dart';
import 'package:maseef_app/models/listing.dart';
import 'package:maseef_app/theme/maseef_theme.dart';
import 'package:maseef_app/widgets/optical_align.dart';
import 'package:maseef_app/widgets/detail_section.dart';

/// Builds a real interactive map for exact coordinates.
///
/// No map package is bundled yet: no chalet has host-supplied coordinates, and
/// a tile map needs either a keyed paid service (Google Maps) or attribution and
/// tile-usage compliance (OpenStreetMap). When exact coordinates exist and a
/// builder is supplied, [ListingLocationSection] shows it in place of the
/// built-in coordinate panel. See the project notes for the options considered.
typedef LocationMapBuilder =
    Widget Function(BuildContext context, double latitude, double longitude);

/// Location section that is honest about how precise it is.
///
/// * Exact (both coordinates valid): a marker, the coordinates, and an
///   "Open in Google Maps" action that opens that point.
/// * Area only: no marker. The known locality and governorate are shown inside
///   an area ring, labelled "Area-level location", and the action opens a Google
///   Maps search for the area, never the chalet.
///
/// The exact state is ready for a future host workflow in which the owner picks
/// the point on a map and saves it. Nothing here writes or geocodes anything.
class ListingLocationSection extends StatelessWidget {
  const ListingLocationSection({
    super.key,
    required this.listing,
    required this.onOpenLink,
    this.mapBuilder,
  });

  final Listing listing;
  final Future<void> Function(Uri uri) onOpenLink;
  final LocationMapBuilder? mapBuilder;

  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context).strings;
    final exact = listing.hasExactLocation;
    final area = strings.locationLine(listing.locality, listing.governorate);

    return DetailSection(
      key: const Key('location-section'),
      title: strings.locationTitle,
      trailing: _Badge(
        key: Key(exact ? 'location-badge-exact' : 'location-badge-area'),
        exact: exact,
        label: exact ? strings.exactLocationBadge : strings.areaLevelBadge,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Side by side when the card is wide enough, stacked otherwise.
          final sideBySide = constraints.maxWidth >= 600;
          final height = sideBySide ? 240.0 : 180.0;

          final visual = (exact && mapBuilder != null)
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    key: const Key('location-map'),
                    height: height,
                    child: mapBuilder!(
                      context,
                      listing.latitude!,
                      listing.longitude!,
                    ),
                  ),
                )
              : _Panel(
                  exact: exact,
                  areaLabel: area,
                  height: height,
                  caption: strings.areaOnlyCaption,
                  tooltip: strings.locationLinkTooltip(area),
                  onTap: () => onOpenLink(listing.mapsUri),
                );

          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                exact ? strings.exactLocationNote : strings.areaLocationNote,
                key: const Key('location-note'),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (exact) ...[
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${strings.coordinatesLabel}: ',
                        style: const TextStyle(color: MaseefColors.muted),
                      ),
                      TextSpan(
                        text: '${listing.latitude}, ${listing.longitude}',
                        style: const TextStyle(
                          color: MaseefColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  key: const Key('location-coordinates'),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('open-in-maps'),
                onPressed: () => onOpenLink(listing.mapsUri),
                icon: const OpticalIcon(
                  icon: Icons.map_outlined,
                  size: 20,
                  color: Colors.white,
                  textSize: 14,
                ),
                label: Text(
                  exact ? strings.openInMaps : strings.openAreaInMaps,
                ),
              ),
            ],
          );

          if (!sideBySide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [visual, const SizedBox(height: 16), details],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 11, child: visual),
              const SizedBox(width: 28),
              Expanded(flex: 9, child: details),
            ],
          );
        },
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({super.key, required this.exact, required this.label});

  final bool exact;
  final String label;

  @override
  Widget build(BuildContext context) {
    final foreground = exact ? Colors.white : MaseefColors.navy;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: exact ? MaseefColors.blue : MaseefColors.goldSoft,
        borderRadius: BorderRadius.circular(999),
        border: exact
            ? null
            : Border.all(color: MaseefColors.gold.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: foreground,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

/// Map-style locality panel. It is **not** a map and never claims to be one.
///
/// * Area level: a calm water-blue panel with faint street-grid texture, the
///   locality name, and an "Area only" caption. There is no pin and no marker,
///   so it cannot be read as the chalet's position. Tapping it opens the same
///   Google Maps area search as the button.
/// * Exact (genuine coordinates, no map builder): a single marker.
class _Panel extends StatefulWidget {
  const _Panel({
    required this.exact,
    required this.areaLabel,
    required this.height,
    required this.caption,
    required this.tooltip,
    required this.onTap,
  });

  final bool exact;
  final String areaLabel;
  final double height;
  final String caption;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_Panel> createState() => _PanelState();
}

class _PanelState extends State<_Panel> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final exact = widget.exact;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Semantics(
          button: true,
          label: widget.tooltip,
          excludeSemantics: true,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              key: const Key('location-panel'),
              height: widget.height,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _PanelPainter(exact: exact)),
                  ),
                  if (exact)
                    const Icon(
                      Icons.place,
                      key: Key('location-marker'),
                      size: 48,
                      color: MaseefColors.navy,
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _hover
                                    ? MaseefColors.blue
                                    : MaseefColors.line,
                                width: _hover ? 1.5 : 1,
                              ),
                              boxShadow: maseefShadow(raised: _hover),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            child: Text(
                              widget.areaLabel,
                              key: const Key('location-area-label'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: MaseefColors.navy,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                decoration: _hover
                                    ? TextDecoration.underline
                                    : TextDecoration.none,
                                decorationColor: MaseefColors.blue,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.caption,
                            key: const Key('location-area-caption'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: MaseefColors.muted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Positioned.fill(
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        key: const Key('location-panel-tap'),
                        onTap: widget.onTap,
                        hoverColor: MaseefColors.blue.withValues(alpha: 0.04),
                        splashColor: MaseefColors.blue.withValues(alpha: 0.08),
                      ),
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

class _PanelPainter extends CustomPainter {
  const _PanelPainter({required this.exact});

  final bool exact;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDDEEF7), Color(0xFFEAF5FA)],
        ).createShader(rect),
    );

    // Faint street-grid texture.
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = 1;
    for (var x = 18.0; x <= size.width; x += 42) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 12.0; y <= size.height; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    if (exact) {
      final center = size.center(Offset.zero);
      canvas.drawCircle(
        center,
        34,
        Paint()..color = MaseefColors.skyBlue.withValues(alpha: 0.2),
      );
      canvas.drawCircle(
        center,
        34,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = MaseefColors.blue.withValues(alpha: 0.28),
      );
      return;
    }

    // Two soft, curving "roads" and a pale water shape for a map-like feel.
    final road = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7
      ..color = Colors.white;
    final first = Path()
      ..moveTo(-10, size.height * 0.72)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.45,
        size.width * 0.55,
        size.height * 0.95,
        size.width + 10,
        size.height * 0.38,
      );
    final second = Path()
      ..moveTo(size.width * 0.28, -10)
      ..cubicTo(
        size.width * 0.4,
        size.height * 0.35,
        size.width * 0.2,
        size.height * 0.7,
        size.width * 0.34,
        size.height + 10,
      );
    canvas.drawPath(first, road);
    canvas.drawPath(second, road);
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * 0.66,
        size.height * 0.1,
        size.width * 0.42,
        size.height * 0.38,
      ),
      Paint()..color = MaseefColors.skyBlue.withValues(alpha: 0.28),
    );
  }

  @override
  bool shouldRepaint(covariant _PanelPainter oldDelegate) =>
      oldDelegate.exact != exact;
}
