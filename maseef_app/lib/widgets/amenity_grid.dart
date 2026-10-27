import 'package:flutter/material.dart';
import 'package:maseef_app/l10n/locale_scope.dart';
import 'package:maseef_app/theme/maseef_theme.dart';
import 'package:maseef_app/widgets/optical_align.dart';

/// Icon for each supplied amenity key. Unknown keys get a neutral check mark.
IconData amenityIcon(String key) {
  switch (key) {
    case 'outdoor_seating':
      return Icons.deck_outlined;
    case 'equipped_kitchen':
      return Icons.kitchen_outlined;
    case 'swimming_pool':
      return Icons.pool_outlined;
    case 'wifi':
      return Icons.wifi;
    case 'billiards':
      return Icons.sports_esports_outlined;
    case 'childrens_pool':
      return Icons.waves_outlined;
    case 'childrens_play_equipment':
      return Icons.toys_outlined;
    case 'barbecue_grill':
      return Icons.outdoor_grill_outlined;
    case 'private_parking':
      return Icons.local_parking_outlined;
    default:
      return Icons.check_circle_outline;
  }
}

/// Responsive amenity feature grid: three columns where there is room, two on
/// tablets and phones, one on very narrow screens.
///
/// Each amenity is a soft blue-tinted tile with a white icon badge beside its
/// name. Tiles have a fixed height so columns stay aligned in English and
/// Arabic, and they respond to hover with a slightly deeper tint.
class AmenityGrid extends StatelessWidget {
  const AmenityGrid({super.key, required this.amenityKeys});

  final List<String> amenityKeys;

  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context).strings;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 540 ? 3 : (width >= 280 ? 2 : 1);
        final gap = width >= 540 ? 16.0 : 12.0;
        final itemWidth = (width - gap * (columns - 1)) / columns;
        final compact = itemWidth < 190;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final key in amenityKeys)
              _AmenityTile(
                key: Key('amenity-$key'),
                width: itemWidth,
                compact: compact,
                icon: amenityIcon(key),
                label: strings.amenity(key),
              ),
          ],
        );
      },
    );
  }
}

class _AmenityTile extends StatefulWidget {
  const _AmenityTile({
    super.key,
    required this.width,
    required this.compact,
    required this.icon,
    required this.label,
  });

  final double width;
  final bool compact;
  final IconData icon;
  final String label;

  @override
  State<_AmenityTile> createState() => _AmenityTileState();
}

class _AmenityTileState extends State<_AmenityTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final badge = compact ? 36.0 : 46.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: widget.width,
        height: compact ? 72 : 72,
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
        decoration: BoxDecoration(
          color: _hover
              ? MaseefColors.blue.withValues(alpha: 0.12)
              : MaseefColors.blue.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hover
                ? MaseefColors.skyBlue
                : MaseefColors.blue.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: MaseefColors.line),
                boxShadow: [
                  BoxShadow(
                    color: MaseefColors.navy.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                widget.icon,
                size: compact ? 19 : 24,
                color: MaseefColors.blue,
              ),
            ),
            SizedBox(width: compact ? 8 : 14),
            Expanded(
              child: OpticalText(
                fontSize: compact ? 13.5 : 15.5,
                child: Text(
                  widget.label,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: MaseefColors.navy,
                    fontSize: compact ? 13.5 : 15.5,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
