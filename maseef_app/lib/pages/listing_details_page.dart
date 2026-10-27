import 'package:flutter/material.dart';
import 'package:maseef_app/booking/booking_client.dart';
import 'package:maseef_app/l10n/app_strings.dart';
import 'package:maseef_app/l10n/locale_scope.dart';
import 'package:maseef_app/models/listing.dart';
import 'package:maseef_app/models/rating.dart';
import 'package:maseef_app/theme/maseef_theme.dart';
import 'package:maseef_app/widgets/amenity_grid.dart';
import 'package:maseef_app/widgets/availability_calendar.dart';
import 'package:maseef_app/widgets/brand_mark.dart';
import 'package:maseef_app/widgets/contact_actions.dart';
import 'package:maseef_app/widgets/detail_section.dart';
import 'package:maseef_app/widgets/language_switcher.dart';
import 'package:maseef_app/widgets/listing_gallery.dart';
import 'package:maseef_app/widgets/location_section.dart';
import 'package:maseef_app/widgets/optical_align.dart';
import 'package:maseef_app/widgets/rating_preview.dart';

/// Viewport width from which the contact card sits in a right-hand column.
const _twoColumnBreakpoint = 1000.0;

/// Widest the page content grows. On larger monitors the extra width becomes
/// margin instead of stretching the layout.
const _contentMaxWidth = 1320.0;

/// Outer page margin. The top bar, gallery and sections all use it, so every
/// edge on the page lines up.
double _pageMargin(double viewportWidth) {
  if (viewportWidth >= 1100) return 48;
  if (viewportWidth >= 720) return 32;
  return 20;
}

class ListingDetailsPage extends StatefulWidget {
  const ListingDetailsPage({
    super.key,
    required this.listing,
    required this.onOpenLink,
    this.bookingClient = const NotConfiguredBookingClient(),
    this.initialMonth,
    this.mapBuilder,
    this.rating,
  });

  final Listing listing;
  final Future<void> Function(Uri uri) onOpenLink;
  final BookingClient bookingClient;
  final DateTime? initialMonth;

  /// Optional interactive map for exact coordinates. See [LocationMapBuilder].
  final LocationMapBuilder? mapBuilder;

  /// The chalet's genuine public rating, once a reviews endpoint supplies one.
  /// `null` (the case for every listing today) shows "No ratings yet".
  final RatingSummary? rating;

  @override
  State<ListingDetailsPage> createState() => _ListingDetailsPageState();
}

class _ListingDetailsPageState extends State<ListingDetailsPage> {
  /// Marks the two-column area so the contact card can stay in view while the
  /// main column scrolls, without ever leaving that area.
  final _columnsKey = GlobalKey();

  /// Lets the "Amenities" fact scroll the amenities section into view.
  final _amenitiesKey = GlobalKey();

  Listing get listing => widget.listing;

  void _openWhatsApp() => widget.onOpenLink(whatsAppUri(listing.whatsapp));

  void _openUrl(String? url) {
    if (url != null) widget.onOpenLink(Uri.parse(url));
  }

  void _openAreaInMaps() => widget.onOpenLink(listing.mapsUri);

  void _scrollToAmenities() {
    final target = _amenitiesKey.currentContext;
    if (target == null) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    Scrollable.ensureVisible(
      target,
      alignment: 0.03,
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context).strings;

    return Scaffold(
      backgroundColor: MaseefColors.page,
      appBar: _TopBar(strings: strings),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final margin = _pageMargin(width);
          final twoColumns = width >= _twoColumnBreakpoint;
          final gap = width >= 720 ? 40.0 : 32.0;

          final contactCard = _ContactCard(
            listing: listing,
            strings: strings,
            horizontal: !twoColumns && width >= 720,
            onWhatsApp: _openWhatsApp,
            onInstagram: () => _openUrl(listing.instagramUrl),
            onFacebook: () => _openUrl(listing.facebookUrl),
          );
          final header = _Header(
            listing: listing,
            strings: strings,
            large: width >= 720,
            rating: widget.rating,
            onAmenities: _scrollToAmenities,
            onLocation: _openAreaInMaps,
          );

          // Everything that follows the header, in reading order.
          final blocks = <Widget>[
            if (listing.amenityKeys.isNotEmpty)
              KeyedSubtree(
                key: _amenitiesKey,
                child: DetailSection(
                  key: const Key('amenities-section'),
                  title: strings.amenities,
                  child: AmenityGrid(amenityKeys: listing.amenityKeys),
                ),
              ),
            AvailabilitySection(
              listingKey: listing.id,
              client: widget.bookingClient,
              initialMonth: widget.initialMonth,
            ),
            _houseRules(strings),
            ListingLocationSection(
              listing: listing,
              onOpenLink: widget.onOpenLink,
              mapBuilder: widget.mapBuilder,
            ),
          ];

          Widget stack(List<Widget> top, int firstOrder) {
            var order = firstOrder;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in top) _Reveal(order: order++, child: item),
                for (final block in blocks) ...[
                  SizedBox(height: gap),
                  _Reveal(order: order++, child: block),
                ],
              ],
            );
          }

          final Widget body;
          if (twoColumns) {
            final railWidth = width >= 1200 ? 400.0 : 360.0;
            body = Row(
              key: _columnsKey,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: stack([header], 1)),
                SizedBox(width: width >= 1200 ? 56 : 40),
                SizedBox(
                  width: railWidth,
                  child: _Reveal(
                    order: 2,
                    child: _StickyRail(
                      areaKey: _columnsKey,
                      child: contactCard,
                    ),
                  ),
                ),
              ],
            );
          } else {
            body = stack([header, const SizedBox(height: 24), contactCard], 1);
          }

          // A very light pool-water wash behind the gallery. It sits in the
          // scrolling content so it moves with the page and never competes
          // with text.
          return SingleChildScrollView(
            child: Stack(
              children: [
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 560,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFDDEEF7), MaseefColors.page],
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _contentMaxWidth,
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(margin, 20, margin, 72),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Reveal(
                            order: 0,
                            child: ListingGallery(listing: listing),
                          ),
                          SizedBox(height: width >= 720 ? 40 : 28),
                          body,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _houseRules(AppStrings strings) {
    return DetailSection(
      key: const Key('house-rules'),
      title: strings.houseRules,
      flat: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: MaseefColors.aqua,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MaseefColors.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Centred on the first line of the 15 px / 1.55 paragraph.
            const OpticalIcon(
              icon: Icons.rule_folder_outlined,
              color: MaseefColors.blue,
              size: 24,
              textSize: 15,
              lineHeight: 15 * 1.55,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                strings.houseRulesNotProvided,
                style: const TextStyle(
                  color: MaseefColors.muted,
                  fontSize: 15,
                  height: 1.55,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Back, MASEEF branding, and the language switch. It uses the same maximum
/// width and margins as the page content so the edges line up.
class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({required this.strings});

  final AppStrings strings;

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Slightly tighter than the page margin: the back button and language
    // switch carry their own internal padding, so their visible edges still
    // line up with the content below.
    final padding = (_pageMargin(width) - 8).clamp(8.0, 40.0);
    return Material(
      color: Colors.white,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: MaseefColors.line)),
        ),
        child: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
              child: SizedBox(
                height: 67,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  child: Row(
                    children: [
                      TextButton(
                        key: const Key('back-to-listings'),
                        onPressed: () => Navigator.of(context).maybePop(),
                        style: TextButton.styleFrom(
                          foregroundColor: MaseefColors.deep,
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const OpticalLift(
                              textSize: 14,
                              child: BackButtonIcon(),
                            ),
                            const SizedBox(width: 4),
                            Text(strings.back),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Semantics(
                              key: const Key('details-brand'),
                              container: true,
                              label: strings.detailsTitle,
                              child: BrandLockup(
                                markSize: width >= 720 ? 40 : 32,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const LanguageSwitcher(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Title, known location, and the facts strip: bedrooms and amenities when
/// supplied, plus the rating summary. Nothing here is filler; every item is
/// either supplied data or an honest "none yet".
class _Header extends StatelessWidget {
  const _Header({
    required this.listing,
    required this.strings,
    required this.large,
    required this.rating,
    required this.onAmenities,
    required this.onLocation,
  });

  final Listing listing;
  final AppStrings strings;
  final bool large;
  final RatingSummary? rating;
  final VoidCallback onAmenities;
  final VoidCallback onLocation;

  @override
  Widget build(BuildContext context) {
    final area = strings.locationLine(listing.locality, listing.governorate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          listing.name,
          key: const Key('listing-title'),
          style: TextStyle(
            color: MaseefColors.navy,
            fontSize: large ? 42 : 30,
            height: 1.15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _LocationLink(area: area, strings: strings, onTap: onLocation),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            // Phones share one row evenly; wider layouts keep natural widths.
            final dense = width < 480;

            final bedrooms = listing.bedrooms == null
                ? null
                : _Fact(
                    key: const Key('listing-bedrooms'),
                    icon: Icons.bed_outlined,
                    value: '${listing.bedrooms}',
                    label: strings.bedrooms,
                    dense: dense,
                  );
            final amenities = listing.amenityKeys.isEmpty
                ? null
                : _Fact(
                    key: const Key('listing-amenity-count'),
                    icon: Icons.auto_awesome_outlined,
                    value: '${listing.amenityKeys.length}',
                    label: strings.amenities,
                    onTap: onAmenities,
                    tooltip: strings.jumpToAmenities,
                    dense: dense,
                  );
            final facts = <Widget>[?bedrooms, ?amenities];

            // Wide screens: one card with the rating as its last segment.
            if (width >= 720) {
              return _FactStrip(
                facts: facts,
                rating: RatingPreview(
                  key: const Key('listing-rating'),
                  summary: rating,
                  captionBelow: true,
                ),
              );
            }

            // Tablets and phones: light tiles for the facts and a plain,
            // surface-free rating line beneath them.
            final tiles = [for (final fact in facts) _FactTile(child: fact)];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tiles.isNotEmpty)
                  dense
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < tiles.length; i++) ...[
                              if (i > 0) const SizedBox(width: 12),
                              Expanded(child: tiles[i]),
                            ],
                          ],
                        )
                      : Wrap(spacing: 12, runSpacing: 12, children: tiles),
                if (tiles.isNotEmpty) const SizedBox(height: 8),
                RatingPreview(
                  key: const Key('listing-rating'),
                  summary: rating,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// The locality line. It opens the same Google Maps area search as the
/// location section's button; it never claims to be the chalet's address.
class _LocationLink extends StatefulWidget {
  const _LocationLink({
    required this.area,
    required this.strings,
    required this.onTap,
  });

  final String area;
  final AppStrings strings;
  final VoidCallback onTap;

  @override
  State<_LocationLink> createState() => _LocationLinkState();
}

class _LocationLinkState extends State<_LocationLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Tooltip(
        message: widget.strings.locationLinkTooltip(widget.area),
        child: Semantics(
          link: true,
          label: widget.strings.locationLinkTooltip(widget.area),
          excludeSemantics: true,
          child: InkWell(
            key: const Key('listing-location-link'),
            onTap: widget.onTap,
            onHover: (value) => setState(() => _hover = value),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const OpticalIcon(
                    icon: Icons.location_on_outlined,
                    color: MaseefColors.gold,
                    size: 22,
                    textSize: 18,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      widget.area,
                      key: const Key('listing-location'),
                      style: TextStyle(
                        color: MaseefColors.blue,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        decoration: _hover
                            ? TextDecoration.underline
                            : TextDecoration.none,
                        decorationColor: MaseefColors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const OpticalIcon(
                    icon: Icons.open_in_new_rounded,
                    color: MaseefColors.blue,
                    size: 16,
                    textSize: 18,
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

/// One white card holding every fact, divided by hairlines. Bedrooms and
/// amenities take only the width of their content; the rating gets whatever
/// room remains. Used on wide screens only - narrower layouts are lighter (see
/// [_Header]).
class _FactStrip extends StatelessWidget {
  const _FactStrip({required this.facts, required this.rating});

  final List<Widget> facts;
  final Widget rating;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('facts-strip'),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: MaseefColors.line),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final fact in facts) ...[
              fact,
              const VerticalDivider(width: 1, color: MaseefColors.line),
            ],
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const _FactBadge(icon: Icons.star_outline_rounded),
                    const SizedBox(width: 12),
                    Expanded(child: rating),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A standalone card around one fact, used where the strip does not fit.
class _FactTile extends StatelessWidget {
  const _FactTile({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: MaseefColors.line),
      ),
      child: child,
    );
  }
}

/// Soft round icon badge shared by every fact.
class _FactBadge extends StatelessWidget {
  const _FactBadge({required this.icon, this.dense = false});

  final IconData icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: MaseefColors.blue.withValues(alpha: 0.1),
      ),
      child: Padding(
        padding: EdgeInsets.all(dense ? 8 : 10),
        child: Icon(icon, size: dense ? 20 : 22, color: MaseefColors.blue),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.onTap,
    this.tooltip,
    this.dense = false,
  });

  final IconData icon;
  final String value;
  final String label;

  /// When set the whole fact is a button.
  final VoidCallback? onTap;
  final String? tooltip;

  /// Phone layout: tighter padding and a smaller badge so two facts share a
  /// row evenly, with the label ellipsised rather than overflowing.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    // The badge is a fixed circle, so the text follows it: the value (20 px)
    // and label (13 px) block is moved onto the badge's centre.
    final text = OpticalText(
      fontSize: 16.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: MaseefColors.ink,
              fontSize: 20,
              height: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: onTap == null ? MaseefColors.muted : MaseefColors.blue,
              fontSize: 13,
              fontWeight: onTap == null ? FontWeight.w400 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 12 : 18,
        vertical: dense ? 12 : 14,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _FactBadge(icon: icon, dense: dense),
          SizedBox(width: dense ? 10 : 12),
          // Bounded (and so shrinkable) only on the phone, where the tile has
          // a fixed width; elsewhere the fact takes its natural width.
          if (dense) Flexible(child: text) else text,
          if (onTap != null) ...[
            SizedBox(width: dense ? 2 : 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: dense ? 18 : 20,
              color: MaseefColors.blue,
            ),
          ],
        ],
      ),
    );
    if (onTap == null) {
      return Align(
        widthFactor: 1,
        alignment: AlignmentDirectional.centerStart,
        child: content,
      );
    }
    return Tooltip(
      message: tooltip ?? '',
      child: Semantics(
        button: true,
        label: '$value $label${tooltip == null ? '' : ', $tooltip'}',
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          hoverColor: MaseefColors.blue.withValues(alpha: 0.05),
          child: Align(
            widthFactor: 1,
            alignment: AlignmentDirectional.centerStart,
            child: content,
          ),
        ),
      ),
    );
  }
}

/// The price and contact card. A navy header carries the price line; the body
/// has the contact channels (WhatsApp, Facebook, and Instagram where the
/// listing has one), the host's number once, and the booking note. It never
/// offers a booking button: the price is unknown and online booking is not
/// open.
///
/// [horizontal] lays the header and body side by side for tablet widths, where
/// the card spans the page instead of sitting in the side column.
class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.listing,
    required this.strings,
    required this.horizontal,
    required this.onWhatsApp,
    required this.onInstagram,
    required this.onFacebook,
  });

  final Listing listing;
  final AppStrings strings;
  final bool horizontal;
  final VoidCallback onWhatsApp;
  final VoidCallback onInstagram;
  final VoidCallback onFacebook;

  @override
  Widget build(BuildContext context) {
    final header = _header(context);
    final body = _body(context);
    return Container(
      key: const Key('price-card'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MaseefColors.line),
        boxShadow: maseefShadow(raised: true),
      ),
      clipBehavior: Clip.antiAlias,
      child: horizontal
          // The contact grid uses a LayoutBuilder, which cannot sit inside an
          // IntrinsicHeight. A hard-stop gradient paints the navy panel at the
          // exact 5:6 split instead, so it spans the full height of the row.
          ? DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: [
                    MaseefColors.navy,
                    MaseefColors.navy,
                    Colors.white,
                    Colors.white,
                  ],
                  stops: [0, 5 / 11, 5 / 11, 1],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: header),
                  Expanded(flex: 6, child: body),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                Container(height: 3, color: MaseefColors.gold),
                body,
              ],
            ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      color: MaseefColors.navy,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            strings.priceLabel,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            strings.contactForPrice,
            key: const Key('price-text'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            strings.contactForPriceHelp,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: 14.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            strings.socialChannels,
            style: const TextStyle(
              color: MaseefColors.muted,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ContactActions(
            listing: listing,
            layout: ContactLayout.labeled,
            onWhatsApp: onWhatsApp,
            onInstagram: onInstagram,
            onFacebook: onFacebook,
          ),
          const SizedBox(height: 16),
          // The number appears exactly once, as a quiet, selectable line.
          Row(
            children: [
              const OpticalIcon(
                icon: Icons.call_outlined,
                size: 17,
                color: MaseefColors.muted,
                textSize: 15,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SelectableText(
                    listing.whatsapp,
                    key: const Key('contact-whatsapp-number'),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: MaseefColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: MaseefColors.line),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Same height as the note's first line (13 px x 1.45) so the
              // icon is centred on that line.
              const OpticalIcon(
                icon: Icons.info_outline,
                size: 18,
                color: MaseefColors.blue,
                textSize: 13,
                lineHeight: 13 * 1.45,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.onlineBookingNotOpen,
                  key: const Key('booking-not-open-note'),
                  style: const TextStyle(
                    color: MaseefColors.muted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Keeps the contact card in view while the main column scrolls, and parks it
/// at the bottom of the two-column area so it can never overlap what follows.
///
/// It only moves the card visually (a translation), so layout, hit testing and
/// the card's own content are unchanged.
class _StickyRail extends StatefulWidget {
  const _StickyRail({required this.areaKey, required this.child});

  /// Key of the two-column area the card must stay inside.
  final GlobalKey areaKey;
  final Widget child;

  @override
  State<_StickyRail> createState() => _StickyRailState();
}

class _StickyRailState extends State<_StickyRail> {
  static const _stickyTop = 24.0;

  final _cardKey = GlobalKey();
  ScrollPosition? _position;
  double _shift = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_update);
      _position = position;
      position?.addListener(_update);
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (!mounted) return;
    final area = widget.areaKey.currentContext?.findRenderObject();
    final card = _cardKey.currentContext?.findRenderObject();
    final scrollable = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (area is! RenderBox ||
        card is! RenderBox ||
        scrollable is! RenderBox ||
        !area.attached ||
        !card.attached ||
        !area.hasSize ||
        !card.hasSize) {
      return;
    }
    final areaTop = area.localToGlobal(Offset.zero, ancestor: scrollable).dy;
    final room = area.size.height - card.size.height;
    final next = (_stickyTop - areaTop).clamp(0.0, room < 0 ? 0.0 : room);
    if ((next - _shift).abs() > 0.5) setState(() => _shift = next);
  }

  @override
  Widget build(BuildContext context) {
    // Re-measure after layout so language changes and window resizes settle.
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
    return Transform.translate(
      offset: Offset(0, _shift),
      child: KeyedSubtree(key: _cardKey, child: widget.child),
    );
  }
}

/// A short fade-and-rise when a section first appears. Later sections take a
/// little longer so the page settles from top to bottom; it never replays on
/// rebuilds or language changes.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.order, required this.child});

  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final milliseconds = 280 + (order > 8 ? 8 : order) * 60;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: milliseconds),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
