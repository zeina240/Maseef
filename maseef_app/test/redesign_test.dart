import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maseef_app/booking/booking_client.dart';
import 'package:maseef_app/data/real_listings.dart';
import 'package:maseef_app/main.dart';
import 'package:maseef_app/models/listing.dart';
import 'package:maseef_app/pages/home_page.dart';
import 'package:maseef_app/pages/listing_details_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final hareem = realListings.first;

  group('location model', () {
    test('only complete, in-range coordinates count as an exact location', () {
      expect(isValidCoordinate(32.22, 35.25), isTrue);
      expect(isValidCoordinate(null, null), isFalse);
      expect(isValidCoordinate(32.22, null), isFalse);
      expect(isValidCoordinate(null, 35.25), isFalse);
      expect(isValidCoordinate(91, 35.25), isFalse);
      expect(isValidCoordinate(32.22, 181), isFalse);
      expect(isValidCoordinate(double.nan, 35.25), isFalse);
    });

    test('no supplied chalet has invented coordinates', () {
      for (final listing in realListings) {
        expect(listing.latitude, isNull, reason: listing.id);
        expect(listing.longitude, isNull, reason: listing.id);
        expect(listing.hasExactLocation, isFalse, reason: listing.id);
      }
    });

    test('the Maps link searches the area or the exact coordinates', () {
      final area = hareem.mapsUri;
      expect(area.host, 'www.google.com');
      expect(area.path, '/maps/search/');
      expect(area.queryParameters['api'], '1');
      expect(area.queryParameters['query'], contains('النصارية'));
      expect(area.queryParameters['query'], contains('نابلس'));

      final exact = _withCoordinates.mapsUri;
      expect(exact.queryParameters['query'], '32.2211,35.2544');
    });
  });

  group('home cards', () {
    testWidgets('show only verified information and the real contact links', (
      tester,
    ) async {
      final opened = <Uri>[];
      await _pump(
        tester,
        HomePage(
          bookingClient: const NotConfiguredBookingClient(),
          openLink: (uri) async => opened.add(uri),
        ),
        const Size(1280, 2400),
      );

      expect(find.byIcon(Icons.location_on_outlined), findsNWidgets(5));
      expect(find.text('Contact for price'), findsNWidgets(5));
      expect(find.byIcon(Icons.star), findsNothing);
      expect(find.byIcon(Icons.star_rate_rounded), findsNothing);
      expect(find.textContaining('review'), findsNothing);
      expect(
        find.byKey(const Key('photo-count-hareem-sultan')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('photo-count-w-villa')), findsNothing);

      for (final listing in realListings) {
        expect(find.byKey(Key('whatsapp-${listing.id}')), findsOneWidget);
        expect(
          find.byKey(Key('instagram-${listing.id}')),
          listing.instagramUrl == null ? findsNothing : findsOneWidget,
        );
        expect(
          find.byKey(Key('facebook-${listing.id}')),
          listing.facebookUrl == null ? findsNothing : findsOneWidget,
        );
      }

      await tester.tap(find.byKey(const Key('facebook-hareem-sultan')));
      await tester.pump();
      expect(opened.last, Uri.parse(hareem.facebookUrl!));
    });

    testWidgets('cards in a row share one height', (tester) async {
      await _pump(
        tester,
        const HomePage(bookingClient: NotConfiguredBookingClient()),
        const Size(1280, 2400),
      );
      final first = tester.getSize(
        find
            .ancestor(
              of: find.text('Hareem Sultan Resort'),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final second = tester.getSize(
        find
            .ancestor(
              of: find.text('W Villa'),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      expect(first.height, second.height);
      expect(first.width, second.width);
    });
  });

  group('gallery', () {
    testWidgets('desktop shows a photo mosaic and opens the viewer', (
      tester,
    ) async {
      await _pump(tester, _details(hareem), const Size(1280, 3000));

      expect(
        find.byKey(const Key('gallery-mosaic-hareem-sultan')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('gallery-pages-hareem-sultan')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('gallery-show-all-hareem-sultan')),
        findsOneWidget,
      );
      expect(find.text('Show all 7 photos'), findsOneWidget);

      await tester.tap(find.byKey(const Key('gallery-tile-hareem-sultan-0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('viewer-pages')), findsOneWidget);
      expect(_counter(tester), '1 / 7');
      expect(_arrow(tester, 'viewer-previous').onPressed, isNull);

      final seen = <String>[];
      for (var i = 0; i < 7; i++) {
        final image = tester.widget<Image>(
          find.byKey(Key('photo-viewer-hareem-sultan-$i')),
        );
        seen.add((image.image as AssetImage).assetName);
        if (i < 6) {
          await tester.tap(find.byKey(const Key('viewer-next')));
          await tester.pumpAndSettle();
        }
      }
      expect(seen, hareemSultanGallery);
      expect(_counter(tester), '7 / 7');
      expect(_arrow(tester, 'viewer-next').onPressed, isNull);

      await tester.tap(find.byKey(const Key('viewer-previous')));
      await tester.pumpAndSettle();
      expect(_counter(tester), '6 / 7');

      await tester.tap(find.byKey(const Key('viewer-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('viewer-pages')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('phones get a swipeable carousel with a counter', (
      tester,
    ) async {
      await _pump(tester, _details(hareem), const Size(390, 3000));

      expect(
        find.byKey(const Key('gallery-pages-hareem-sultan')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('gallery-mosaic-hareem-sultan')),
        findsNothing,
      );
      expect(_galleryCounter(tester), '1 / 7');

      await tester.drag(
        find.byKey(const Key('gallery-pages-hareem-sultan')),
        const Offset(-390, 0),
      );
      await tester.pumpAndSettle();
      expect(_galleryCounter(tester), '2 / 7');
      expect(tester.takeException(), isNull);
    });

    testWidgets('the viewer works in Arabic with mirrored arrows', (
      tester,
    ) async {
      await _pump(tester, _details(hareem), const Size(1280, 3000));
      await tester.tap(find.byKey(const Key('lang-ar')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('gallery-tile-hareem-sultan-0')));
      await tester.pumpAndSettle();
      expect(
        Directionality.of(
          tester.element(find.byKey(const Key('viewer-pages'))),
        ),
        TextDirection.rtl,
      );
      await tester.tap(find.byKey(const Key('viewer-next')));
      await tester.pumpAndSettle();
      expect(_counter(tester), '2 / 7');
      await tester.tap(find.byKey(const Key('viewer-close')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('details content', () {
    testWidgets('amenities are an icon grid and price never offers booking', (
      tester,
    ) async {
      await _pump(tester, _details(hareem), const Size(1280, 3600));

      for (final key in hareemSultanAmenities) {
        expect(find.byKey(Key('amenity-$key')), findsOneWidget, reason: key);
      }
      expect(find.byIcon(Icons.pool_outlined), findsOneWidget);
      expect(find.byIcon(Icons.wifi), findsOneWidget);

      expect(find.text('Contact for price'), findsOneWidget);
      expect(find.byKey(const Key('booking-not-open-note')), findsOneWidget);
      expect(find.text('Book now'), findsNothing);
      expect(find.text('Reserve'), findsNothing);
      expect(find.byKey(const Key('whatsapp-hareem-sultan')), findsOneWidget);
      expect(find.text('+970566232380'), findsOneWidget);
      expect(find.byKey(const Key('house-rules')), findsOneWidget);
      expect(find.byKey(const Key('availability-section')), findsOneWidget);
    });

    testWidgets('price card and social links open the real destinations', (
      tester,
    ) async {
      final opened = <Uri>[];
      await _pump(
        tester,
        ListingDetailsPage(
          listing: hareem,
          onOpenLink: (uri) async => opened.add(uri),
        ),
        const Size(1280, 3600),
      );

      await tester.tap(find.byKey(const Key('whatsapp-hareem-sultan')));
      await tester.pump();
      expect(opened.last, whatsAppUri('+970566232380'));

      await tester.ensureVisible(
        find.byKey(const Key('facebook-hareem-sultan')),
      );
      await tester.tap(find.byKey(const Key('facebook-hareem-sultan')));
      await tester.pump();
      expect(opened.last, Uri.parse(hareem.facebookUrl!));
    });

    testWidgets('listings without facts do not show an empty facts row', (
      tester,
    ) async {
      await _pump(tester, _details(realListings[1]), const Size(1280, 3000));
      expect(find.byKey(const Key('listing-bedrooms')), findsNothing);
      expect(find.byKey(const Key('listing-amenity-count')), findsNothing);
      expect(find.byKey(const Key('amenities-section')), findsNothing);
    });
  });

  group('location section', () {
    testWidgets('area-only listings are labelled honestly with no marker', (
      tester,
    ) async {
      final opened = <Uri>[];
      await _pump(
        tester,
        ListingDetailsPage(
          listing: hareem,
          onOpenLink: (uri) async => opened.add(uri),
        ),
        const Size(1280, 3600),
      );

      await tester.ensureVisible(find.byKey(const Key('location-section')));
      expect(find.byKey(const Key('location-badge-area')), findsOneWidget);
      expect(find.byKey(const Key('location-badge-exact')), findsNothing);
      expect(find.text('Area-level location'), findsOneWidget);
      expect(find.byKey(const Key('location-marker')), findsNothing);
      expect(find.byKey(const Key('location-coordinates')), findsNothing);
      expect(
        find.textContaining('area only, not the chalet itself'),
        findsOneWidget,
      );
      expect(find.text('Open area in Google Maps'), findsOneWidget);

      await tester.tap(find.byKey(const Key('open-in-maps')));
      await tester.pump();
      expect(opened.single, hareem.mapsUri);
      expect(opened.single.queryParameters['query'], isNot(contains('35.')));
    });

    testWidgets(
      'exact coordinates (test fixture) show a marker and exact link',
      (tester) async {
        final opened = <Uri>[];
        await _pump(
          tester,
          ListingDetailsPage(
            listing: _withCoordinates,
            onOpenLink: (uri) async => opened.add(uri),
          ),
          const Size(1280, 3600),
        );

        await tester.ensureVisible(find.byKey(const Key('location-section')));
        expect(find.byKey(const Key('location-badge-exact')), findsOneWidget);
        expect(find.byKey(const Key('location-badge-area')), findsNothing);
        expect(find.byKey(const Key('location-marker')), findsOneWidget);
        expect(find.byKey(const Key('location-coordinates')), findsOneWidget);
        expect(find.text('Open in Google Maps'), findsOneWidget);

        await tester.tap(find.byKey(const Key('open-in-maps')));
        await tester.pump();
        expect(opened.single.queryParameters['query'], '32.2211,35.2544');
      },
    );

    testWidgets('both states render in Arabic without layout errors', (
      tester,
    ) async {
      for (final listing in [hareem, _withCoordinates]) {
        await _pump(tester, _details(listing), const Size(390, 3600));
        await tester.tap(find.byKey(const Key('lang-ar')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('location-section')));
        expect(
          Directionality.of(
            tester.element(find.byKey(const Key('location-section'))),
          ),
          TextDirection.rtl,
        );
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('details layout grid', () {
    testWidgets('desktop uses two columns aligned to the gallery edges', (
      tester,
    ) async {
      await _pump(tester, _details(hareem), const Size(1280, 3000));

      final gallery = tester.getRect(
        find.byKey(const Key('gallery-mosaic-hareem-sultan')),
      );
      final title = tester.getRect(find.byKey(const Key('listing-title')));
      final card = tester.getRect(find.byKey(const Key('price-card')));
      final availability = tester.getRect(
        find.byKey(const Key('availability-section')),
      );
      final location = tester.getRect(
        find.byKey(const Key('location-section')),
      );

      // Main column starts at the gallery's left edge; the card ends at its
      // right edge; the card sits to the right of the main column.
      expect(title.left, gallery.left);
      expect(availability.left, gallery.left);
      expect(location.left, gallery.left);
      expect(card.right, closeTo(gallery.right, 0.5));
      expect(card.left, greaterThan(availability.right));
      expect(card.top, closeTo(title.top, 2));
      expect(card.width, 400);
      // The main column has room to breathe, not a narrow strip.
      expect(availability.width, greaterThan(650));
      // Page margins are balanced.
      expect(gallery.left, 1280 - gallery.right);
    });

    testWidgets('very wide screens cap the content width', (tester) async {
      await _pump(tester, _details(hareem), const Size(2200, 2400));
      final gallery = tester.getRect(
        find.byKey(const Key('gallery-mosaic-hareem-sultan')),
      );
      expect(gallery.width, lessThanOrEqualTo(1320));
      expect(gallery.left, 2200 - gallery.right);
      expect(gallery.left, greaterThan(400));
    });

    testWidgets('amenities use three columns on desktop, two on a phone', (
      tester,
    ) async {
      await _pump(tester, _details(hareem), const Size(1280, 3000));
      final lefts = {
        for (final key in hareemSultanAmenities)
          tester.getTopLeft(find.byKey(Key('amenity-$key'))).dx,
      };
      expect(lefts, hasLength(3));

      await _pump(tester, _details(hareem), const Size(390, 3600));
      final phoneLefts = {
        for (final key in hareemSultanAmenities)
          tester.getTopLeft(find.byKey(Key('amenity-$key'))).dx,
      };
      expect(phoneLefts, hasLength(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('location text sits beside the visual on desktop only', (
      tester,
    ) async {
      await _pump(tester, _details(hareem), const Size(1280, 3000));
      var panel = tester.getRect(find.byKey(const Key('location-panel')));
      var note = tester.getRect(find.byKey(const Key('location-note')));
      expect(note.left, greaterThan(panel.right));

      await _pump(tester, _details(hareem), const Size(390, 3600));
      panel = tester.getRect(find.byKey(const Key('location-panel')));
      note = tester.getRect(find.byKey(const Key('location-note')));
      expect(note.top, greaterThan(panel.bottom));
    });

    testWidgets('phones read in one column: title, contact, then sections', (
      tester,
    ) async {
      await _pump(tester, _details(hareem), const Size(390, 3600));
      final title = tester.getRect(find.byKey(const Key('listing-title')));
      final card = tester.getRect(find.byKey(const Key('price-card')));
      final amenities = tester.getRect(
        find.byKey(const Key('amenities-section')),
      );
      expect(card.top, greaterThan(title.bottom));
      expect(amenities.top, greaterThan(card.bottom));
      expect(card.left, title.left);
      expect(card.right, closeTo(390 - title.left, 0.5));
    });

    testWidgets('tablets stack the card full width above the sections', (
      tester,
    ) async {
      await _pump(tester, _details(hareem), const Size(768, 3600));
      final gallery = tester.getRect(
        find.byKey(const Key('gallery-mosaic-hareem-sultan')),
      );
      final card = tester.getRect(find.byKey(const Key('price-card')));
      expect(card.left, gallery.left);
      expect(card.right, closeTo(gallery.right, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the contact card stays in view and parks inside its area', (
      tester,
    ) async {
      await _pump(tester, _details(hareem), const Size(1280, 800));
      final restingTop = tester
          .getTopLeft(find.byKey(const Key('price-card')))
          .dy;

      final scroll = find.byType(SingleChildScrollView).first;
      await tester.drag(scroll, const Offset(0, -700));
      await tester.pumpAndSettle();
      final stuck = tester.getRect(find.byKey(const Key('price-card')));
      // AppBar (68) plus the sticky offset (24).
      expect(stuck.top, closeTo(68 + 24, 1.5));
      expect(stuck.top, lessThan(restingTop));

      // Scrolled to the very end the card has not left the page content.
      await tester.drag(scroll, const Offset(0, -6000));
      await tester.pumpAndSettle();
      final location = tester.getRect(
        find.byKey(const Key('location-section')),
      );
      final parked = tester.getRect(find.byKey(const Key('price-card')));
      expect(parked.bottom, lessThanOrEqualTo(location.bottom + 1));
      expect(parked.top, greaterThanOrEqualTo(68));
      expect(tester.takeException(), isNull);

      // Its buttons still work where it ended up.
      expect(find.byKey(const Key('whatsapp-hareem-sultan')), findsOneWidget);
    });

    testWidgets('the desktop layout mirrors in Arabic', (tester) async {
      await _pump(tester, _details(hareem), const Size(1280, 3000));
      await tester.tap(find.byKey(const Key('lang-ar')));
      await tester.pumpAndSettle();
      final title = tester.getRect(find.byKey(const Key('listing-title')));
      final card = tester.getRect(find.byKey(const Key('price-card')));
      expect(card.right, lessThan(title.left));
      expect(tester.takeException(), isNull);
    });
  });

  group('responsive layouts', () {
    for (final width in const [360.0, 390.0, 768.0, 1280.0]) {
      testWidgets(
        'home and details fit at ${width.toInt()} px in both languages',
        (tester) async {
          await _pump(
            tester,
            const HomePage(bookingClient: NotConfiguredBookingClient()),
            Size(width, 2600),
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const Key('lang-ar')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          for (final listing in [hareem, realListings[1]]) {
            for (final language in const ['lang-en', 'lang-ar']) {
              await _pump(tester, _details(listing), Size(width, 3600));
              await tester.tap(find.byKey(Key(language)));
              await tester.pumpAndSettle();
              await tester.ensureVisible(
                find.byKey(const Key('location-section')),
              );
              expect(
                tester.takeException(),
                isNull,
                reason: '${listing.id} $language',
              );
            }
          }
        },
      );
    }
  });
}

const _withCoordinates = Listing(
  id: 'fixture',
  name: 'Fixture Chalet',
  governorate: 'نابلس',
  locality: 'النصارية',
  whatsapp: '+970566232380',
  referencedImageFilename: 'Pool.jpg',
  photoAssets: ['assets/images/HareemSultan/Pool.jpg'],
  latitude: 32.2211,
  longitude: 35.2544,
);

Widget _details(Listing listing) =>
    ListingDetailsPage(listing: listing, onOpenLink: _ignoreLink);

Future<void> _ignoreLink(Uri uri) async {}

String? _galleryCounter(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(const Key('gallery-counter-hareem-sultan')),
        matching: find.byType(Text),
      ),
    )
    .data;

IconButton _arrow(WidgetTester tester, String key) => tester.widget<IconButton>(
  find.descendant(of: find.byKey(Key(key)), matching: find.byType(IconButton)),
);

String? _counter(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('viewer-counter'))).data;

Future<void> _pump(WidgetTester tester, Widget home, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaseefApp(home: home));
  await tester.pumpAndSettle();
}
