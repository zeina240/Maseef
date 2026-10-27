import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maseef_app/l10n/locale_scope.dart';
import 'package:maseef_app/widgets/listing_photo.dart';

/// Opens the full-screen photo viewer on [initialIndex].
Future<void> showPhotoViewer(
  BuildContext context, {
  required List<String> photos,
  required String listingId,
  int initialIndex = 0,
}) {
  return showDialog<void>(
    context: context,
    useSafeArea: false,
    barrierColor: Colors.black87,
    builder: (context) => PhotoViewer(
      photos: photos,
      listingId: listingId,
      initialIndex: initialIndex,
    ),
  );
}

/// Large, swipeable viewer with previous/next buttons, arrow-key support, a
/// counter, and a thumbnail strip. It works in both reading directions: "next"
/// always sits at the end edge, and swiping follows the page direction.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({
    super.key,
    required this.photos,
    required this.listingId,
    this.initialIndex = 0,
  });

  final List<String> photos;
  final String listingId;
  final int initialIndex;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  static const _background = Color(0xFF0A1424);

  late final PageController _controller;
  late final List<GlobalKey> _thumbKeys;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.photos.length - 1);
    _controller = PageController(initialPage: _index);
    _thumbKeys = List.generate(widget.photos.length, (_) => GlobalKey());
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealThumb());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  void _goTo(int index) {
    if (index < 0 || index >= widget.photos.length) return;
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _revealThumb() {
    if (!mounted) return;
    final context = _thumbKeys[_index].currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0.5,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = LocaleScope.of(context).strings;
    final total = widget.photos.length;
    final rtl = _rtl;

    return Dialog.fullscreen(
      backgroundColor: _background,
      child: Focus(
        autofocus: true,
        child: CallbackShortcuts(
          bindings: {
            // Arrow keys move in the direction they point on screen.
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                _goTo(_index + (rtl ? 1 : -1)),
            const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                _goTo(_index + (rtl ? -1 : 1)),
          },
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                  child: Row(
                    children: [
                      Semantics(
                        liveRegion: true,
                        label: strings.galleryPosition(_index + 1, total),
                        child: ExcludeSemantics(
                          child: Text(
                            '${_index + 1} / $total',
                            key: const Key('viewer-counter'),
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        key: const Key('viewer-close'),
                        tooltip: strings.closeViewer,
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                        iconSize: 28,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      PageView.builder(
                        key: const Key('viewer-pages'),
                        controller: _controller,
                        itemCount: total,
                        onPageChanged: (value) {
                          setState(() => _index = value);
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _revealThumb(),
                          );
                        },
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: ListingPhoto(
                            asset: widget.photos[index],
                            id: 'viewer-${widget.listingId}-$index',
                            aspectRatio: null,
                            fit: BoxFit.contain,
                            backdrop: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      if (total > 1) ...[
                        PositionedDirectional(
                          start: 12,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _ArrowButton(
                              key: const Key('viewer-previous'),
                              tooltip: strings.previousPhoto,
                              icon: rtl
                                  ? Icons.chevron_right
                                  : Icons.chevron_left,
                              onPressed: _index > 0
                                  ? () => _goTo(_index - 1)
                                  : null,
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          end: 12,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _ArrowButton(
                              key: const Key('viewer-next'),
                              tooltip: strings.nextPhoto,
                              icon: rtl
                                  ? Icons.chevron_left
                                  : Icons.chevron_right,
                              onPressed: _index < total - 1
                                  ? () => _goTo(_index + 1)
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (total > 1)
                  SizedBox(
                    height: 84,
                    child: ListView.separated(
                      key: const Key('viewer-thumbs'),
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                      scrollDirection: Axis.horizontal,
                      itemCount: total,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final selected = index == _index;
                        return Semantics(
                          button: true,
                          selected: selected,
                          label: strings.galleryPosition(index + 1, total),
                          child: GestureDetector(
                            key: _thumbKeys[index],
                            onTap: () => _goTo(index),
                            child: AnimatedContainer(
                              key: Key('viewer-thumb-$index'),
                              duration: const Duration(milliseconds: 160),
                              width: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFFD9B878)
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Opacity(
                                opacity: selected ? 1 : 0.62,
                                child: ListingPhoto(
                                  asset: widget.photos[index],
                                  id: 'viewerthumb-${widget.listingId}-$index',
                                  aspectRatio: null,
                                  compact: true,
                                  borderRadius: BorderRadius.circular(8),
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
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 28,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.16),
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.06),
        disabledForegroundColor: Colors.white30,
        minimumSize: const Size(48, 48),
      ),
      icon: Icon(icon),
    );
  }
}
