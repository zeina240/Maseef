import 'package:flutter/material.dart';
import 'package:maseef_app/l10n/app_strings.dart';
import 'package:maseef_app/l10n/locale_scope.dart';
import 'package:maseef_app/models/listing.dart';
import 'package:maseef_app/theme/maseef_theme.dart';
import 'package:maseef_app/widgets/optical_align.dart';
import 'package:maseef_app/widgets/listing_photo.dart';
import 'package:maseef_app/widgets/photo_viewer.dart';

/// Responsive photo gallery for the details page.
///
/// Wide layouts show one large photo with up to four smaller ones and a
/// "Show all photos" button. Narrow layouts show a swipeable carousel with a
/// visible counter. Tapping any photo opens [PhotoViewer]. Every photo is the
/// chalet's own bundled image; nothing is substituted.
class ListingGallery extends StatefulWidget {
  const ListingGallery({super.key, required this.listing});

  final Listing listing;

  /// Width at which the layout switches from carousel to mosaic.
  static const mosaicBreakpoint = 640.0;

  @override
  State<ListingGallery> createState() => _ListingGalleryState();
}

class _ListingGalleryState extends State<ListingGallery> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  List<String> get _photos => widget.listing.photoAssets;

  void _open(int index) {
    showPhotoViewer(
      context,
      photos: _photos,
      listingId: widget.listing.id,
      initialIndex: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context).strings;
    final photos = _photos;
    final id = widget.listing.id;

    if (photos.isEmpty) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ListingPhoto(
          asset: null,
          id: id,
          aspectRatio: null,
          borderRadius: BorderRadius.circular(20),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ListingGallery.mosaicBreakpoint) {
          return _mosaic(strings, photos, id, constraints.maxWidth);
        }
        return _carousel(strings, photos, id);
      },
    );
  }

  // ---------------------------------------------------------------- desktop

  Widget _mosaic(
    AppStrings strings,
    List<String> photos,
    String id,
    double width,
  ) {
    final height = (width * 0.4).clamp(280.0, 540.0);
    final side = photos.skip(1).take(4).toList();
    const gap = 8.0;

    Widget tile(int index, {String? photoId}) {
      return _Tile(
        key: Key('gallery-tile-$id-$index'),
        asset: photos[index],
        photoId: photoId ?? 'tile-$id-$index',
        compact: index != 0,
        label: strings.galleryPosition(index + 1, photos.length),
        onTap: () => _open(index),
      );
    }

    Widget sideGrid() {
      // Indexes into [photos]: side tiles start at 1.
      Widget row(List<int> indexes) => Row(
        children: [
          for (var i = 0; i < indexes.length; i++) ...[
            if (i > 0) const SizedBox(width: gap),
            Expanded(child: tile(indexes[i])),
          ],
        ],
      );
      final n = side.length;
      if (n == 0) return const SizedBox.shrink();
      if (n == 1) return tile(1);
      if (n == 2) {
        return Column(
          children: [
            Expanded(child: tile(1)),
            const SizedBox(height: gap),
            Expanded(child: tile(2)),
          ],
        );
      }
      if (n == 3) {
        return Column(
          children: [
            Expanded(child: tile(1)),
            const SizedBox(height: gap),
            Expanded(child: row([2, 3])),
          ],
        );
      }
      return Column(
        children: [
          Expanded(child: row([1, 2])),
          const SizedBox(height: gap),
          Expanded(child: row([3, 4])),
        ],
      );
    }

    return Semantics(
      container: true,
      child: SizedBox(
        key: Key('gallery-mosaic-$id'),
        height: height,
        child: Stack(
          children: [
            Row(
              children: [
                Expanded(child: tile(0, photoId: 'cover-$id')),
                if (side.isNotEmpty) ...[
                  const SizedBox(width: gap),
                  Expanded(child: sideGrid()),
                ],
              ],
            ),
            if (photos.length > 1)
              PositionedDirectional(
                end: 16,
                bottom: 16,
                child: _ShowAllButton(
                  key: Key('gallery-show-all-$id'),
                  label: strings.showAllPhotos(photos.length),
                  onPressed: () => _open(0),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- mobile

  Widget _carousel(AppStrings strings, List<String> photos, String id) {
    return AspectRatio(
      aspectRatio: 5 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              key: Key('gallery-pages-$id'),
              controller: _pages,
              itemCount: photos.length,
              onPageChanged: (value) => setState(() => _page = value),
              itemBuilder: (context, index) {
                return Semantics(
                  button: true,
                  label: strings.galleryPosition(index + 1, photos.length),
                  child: GestureDetector(
                    key: Key('gallery-page-$id-$index'),
                    onTap: () => _open(index),
                    child: ListingPhoto(
                      asset: photos[index],
                      id: index == 0 ? 'cover-$id' : 'page-$id-$index',
                      aspectRatio: null,
                    ),
                  ),
                );
              },
            ),
            if (photos.length > 1)
              PositionedDirectional(
                end: 12,
                bottom: 12,
                child: IgnorePointer(
                  child: _CounterChip(
                    key: Key('gallery-counter-$id'),
                    text: '${_page + 1} / ${photos.length}',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One tappable photo in the desktop mosaic.
class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.asset,
    required this.photoId,
    required this.label,
    required this.onTap,
    required this.compact,
  });

  final String asset;
  final String photoId;
  final bool compact;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ListingPhoto(
              asset: asset,
              id: photoId,
              aspectRatio: null,
              compact: compact,
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  hoverColor: Colors.black.withValues(alpha: 0.12),
                  focusColor: MaseefColors.gold.withValues(alpha: 0.2),
                  splashColor: Colors.white24,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShowAllButton extends StatelessWidget {
  const _ShowAllButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const OpticalIcon(
                icon: Icons.grid_view_rounded,
                size: 18,
                color: MaseefColors.navy,
                textSize: 14,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: MaseefColors.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CounterChip extends StatelessWidget {
  const _CounterChip({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MaseefColors.navy.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          text,
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
