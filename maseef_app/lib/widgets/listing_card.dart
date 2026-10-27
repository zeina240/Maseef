import 'package:flutter/material.dart';
import 'package:maseef_app/l10n/locale_scope.dart';
import 'package:maseef_app/models/listing.dart';
import 'package:maseef_app/theme/maseef_theme.dart';
import 'package:maseef_app/widgets/contact_actions.dart';
import 'package:maseef_app/widgets/listing_photo.dart';

/// Photo-first card for the home grid.
///
/// Shows only supplied facts: the chalet's own photo, its name, its known
/// location, and "Contact for price". The card expects a bounded height (the
/// home grid stretches cards in a row to the same height) so the contact
/// buttons line up along the bottom edge.
class ListingCard extends StatefulWidget {
  const ListingCard({
    super.key,
    required this.listing,
    required this.onOpen,
    required this.onWhatsApp,
    required this.onInstagram,
    required this.onFacebook,
  });

  final Listing listing;
  final VoidCallback onOpen;
  final VoidCallback onWhatsApp;
  final VoidCallback onInstagram;
  final VoidCallback onFacebook;

  @override
  State<ListingCard> createState() => _ListingCardState();
}

class _ListingCardState extends State<ListingCard> {
  static const _radius = 22.0;

  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final strings = LocaleScope.of(context).strings;
    final active = _hovered || _focused;
    final photo = listing.photoAssets.isEmpty
        ? null
        : listing.photoAssets.first;
    final photoCount = listing.photoAssets.length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, active ? -4 : 0, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: maseefShadow(raised: active),
      ),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: BorderSide(
            color: _focused
                ? MaseefColors.gold
                : (active ? MaseefColors.skyBlue : MaseefColors.line),
            width: _focused ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: widget.onOpen,
          onHover: (value) => setState(() => _hovered = value),
          onFocusChange: (value) => setState(() => _focused = value),
          hoverColor: MaseefColors.gold.withValues(alpha: 0.05),
          focusColor: MaseefColors.gold.withValues(alpha: 0.08),
          splashColor: MaseefColors.navy.withValues(alpha: 0.08),
          highlightColor: MaseefColors.navy.withValues(alpha: 0.05),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 5 / 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRect(
                      child: AnimatedScale(
                        scale: active ? 1.04 : 1,
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutCubic,
                        child: ListingPhoto(
                          asset: photo,
                          id: listing.id,
                          aspectRatio: null,
                        ),
                      ),
                    ),
                    if (photo != null)
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 72,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x00000000), Color(0x59000000)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (photoCount > 1)
                      PositionedDirectional(
                        end: 12,
                        bottom: 12,
                        child: _PhotoCountChip(
                          key: Key('photo-count-${listing.id}'),
                          label: strings.photoCount(photoCount),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MaseefColors.navy,
                          fontSize: 20,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: MaseefColors.gold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              strings.locationLine(
                                listing.locality,
                                listing.governorate,
                              ),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: MaseefColors.line,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              strings.contactForPrice,
                              style: const TextStyle(
                                color: MaseefColors.ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ExcludeSemantics(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: active
                                    ? MaseefColors.navy
                                    : MaseefColors.aqua,
                              ),
                              child: Icon(
                                Icons.arrow_forward,
                                size: 16,
                                color: active
                                    ? Colors.white
                                    : MaseefColors.navy,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const SizedBox(height: 16),
                      ContactActions(
                        listing: listing,
                        onWhatsApp: widget.onWhatsApp,
                        onInstagram: widget.onInstagram,
                        onFacebook: widget.onFacebook,
                      ),
                    ],
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

class _PhotoCountChip extends StatelessWidget {
  const _PhotoCountChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MaseefColors.navy.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_library_outlined,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
