import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maseef_app/data/real_listings.dart';
import 'package:maseef_app/main.dart';
import 'package:maseef_app/models/listing.dart';
import 'package:maseef_app/models/rating.dart';
import 'package:maseef_app/pages/listing_details_page.dart';
import 'package:maseef_app/theme/maseef_theme.dart';
import 'package:maseef_app/widgets/optical_align.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final hareem = realListings.first;
  final celine = realListings.firstWhere((l) => l.id == 'celine-villa');

  group('amenities chip', () {
    for (final language in const ['lang-en', 'lang-ar']) {
      for (final size in const [Size(1280, 800), Size(390, 800)]) {
        testWidgets(
          'scrolls the amenities heading into view ($language, ${size.width.toInt()} px)',
          (tester) async {
            await _pump(tester, _details(hareem), size);
            await tester.tap(find.byKey(Key(language)));
            await tester.pumpAndSettle();

            final section = find.byKey(const Key('amenities-section'));
            final scrollable = Scrollable.of(tester.element(section));
            expect(scrollable.position.pixels, 0);
            // Below the fold before the tap.
            expect(
              tester.getTopLeft(section).dy,
              greaterThan(size.height * 0.6),
            );

            final chip = find.byKey(const Key('listing-amenity-count'));
            await tester.ensureVisible(chip);
            await tester.pumpAndSettle();
            final before = scrollable.position.pixels;
            await tester.tap(chip);
            await tester.pumpAndSettle();

            expect(scrollable.position.pixels, isNot(before));
            final top = tester.getTopLeft(section).dy;
            expect(top, greaterThanOrEqualTo(0));
            expect(top, lessThan(size.height * 0.4));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  group('location link', () {
    testWidgets('the locality text and the panel open the area search', (
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

      await tester.tap(find.byKey(const Key('listing-location-link')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('location-panel-tap')));
      await tester.tap(find.byKey(const Key('location-panel-tap')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('open-in-maps')));
      await tester.tap(find.byKey(const Key('open-in-maps')));
      await tester.pump();

      expect(opened, hasLength(3));
      for (final uri in opened) {
        expect(uri, hareem.mapsUri);
        expect(uri.host, 'www.google.com');
        final query = uri.queryParameters['query']!;
        expect(query, contains(hareem.locality));
        expect(query, contains(hareem.governorate));
        // An area search, never invented coordinates.
        expect(RegExp(r'\d+\.\d+\s*,\s*\d+\.\d+').hasMatch(query), isFalse);
      }
    });

    testWidgets('no verified coordinates means no marker and no fake map', (
      tester,
    ) async {
      for (final listing in realListings) {
        await _pump(tester, _details(listing), const Size(1280, 3600));
        await tester.ensureVisible(find.byKey(const Key('location-section')));
        expect(
          find.byKey(const Key('location-marker')),
          findsNothing,
          reason: listing.id,
        );
        expect(
          find.byKey(const Key('location-badge-area')),
          findsOneWidget,
          reason: listing.id,
        );
      }
    });
  });

  group('contact card', () {
    testWidgets('shows each number once and no duplicate WhatsApp button', (
      tester,
    ) async {
      await _pump(tester, _details(celine), const Size(1280, 3600));
      expect(find.text(celine.whatsapp), findsOneWidget);
      expect(find.text('Message on WhatsApp'), findsNothing);
      expect(find.text('Social channels'), findsOneWidget);
      expect(find.byKey(const Key('price-text')), findsOneWidget);
      expect(find.byKey(const Key('booking-not-open-note')), findsOneWidget);
      expect(find.byKey(Key('whatsapp-${celine.id}')), findsOneWidget);
    });

    testWidgets('WhatsApp, Facebook and Instagram open their destinations', (
      tester,
    ) async {
      final opened = <Uri>[];
      await _pump(
        tester,
        ListingDetailsPage(
          listing: celine,
          onOpenLink: (uri) async => opened.add(uri),
        ),
        const Size(1280, 3600),
      );

      Future<void> tapKey(String key) async {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.tap(find.byKey(Key(key)));
        await tester.pump();
      }

      await tapKey('whatsapp-${celine.id}');
      expect(opened.last, whatsAppUri(celine.whatsapp));
      await tapKey('facebook-${celine.id}');
      expect(opened.last, Uri.parse(celine.facebookUrl!));
      await tapKey('instagram-${celine.id}');
      expect(opened.last, Uri.parse(celine.instagramUrl!));
      expect(opened, hasLength(3));
    });

    testWidgets('channel buttons sit side by side, not stacked', (
      tester,
    ) async {
      await _pump(tester, _details(hareem), const Size(1280, 3600));
      final whatsapp = tester.getRect(find.byKey(Key('whatsapp-${hareem.id}')));
      final facebook = tester.getRect(find.byKey(Key('facebook-${hareem.id}')));
      expect(whatsapp.top, closeTo(facebook.top, 1));
      expect((whatsapp.left - facebook.left).abs(), greaterThan(80));
      expect(whatsapp.height, closeTo(facebook.height, 1));
      expect(find.byKey(Key('instagram-${hareem.id}')), findsNothing);
    });

    testWidgets('only real channels are offered', (tester) async {
      for (final listing in realListings) {
        await _pump(tester, _details(listing), const Size(1280, 3600));
        expect(
          find.byKey(Key('facebook-${listing.id}')),
          listing.facebookUrl == null ? findsNothing : findsOneWidget,
          reason: listing.id,
        );
        expect(
          find.byKey(Key('instagram-${listing.id}')),
          listing.instagramUrl == null ? findsNothing : findsOneWidget,
          reason: listing.id,
        );
      }
    });
  });

  group('rating', () {
    test('only a real, in-range summary is showable', () {
      expect(const RatingSummary(average: 4.5, count: 12).isShowable, isTrue);
      expect(const RatingSummary(average: 4.5, count: 0).isShowable, isFalse);
      expect(const RatingSummary(average: 0, count: 3).isShowable, isFalse);
      expect(const RatingSummary(average: 5.4, count: 3).isShowable, isFalse);
      expect(
        const RatingSummary(average: double.nan, count: 3).isShowable,
        isFalse,
      );
    });

    testWidgets('no ratings are shown or invented by default', (tester) async {
      for (final listing in realListings) {
        await _pump(tester, _details(listing), const Size(1280, 3600));
        expect(
          find.byKey(const Key('no-ratings-yet')),
          findsOneWidget,
          reason: listing.id,
        );
        expect(find.byKey(const Key('rating-average')), findsNothing);
        expect(find.byKey(const Key('rating-count')), findsNothing);
      }
    });

    testWidgets('a supplied summary shows its average and review count', (
      tester,
    ) async {
      await _pump(
        tester,
        ListingDetailsPage(
          listing: hareem,
          onOpenLink: _ignoreLink,
          rating: const RatingSummary(average: 4.5, count: 12),
        ),
        const Size(1280, 3000),
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('rating-average'))).data,
        '4.5',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('rating-count'))).data,
        '12 reviews',
      );
      expect(find.byKey(const Key('no-ratings-yet')), findsNothing);
    });

    for (final language in const ['lang-en', 'lang-ar']) {
      testWidgets('stars start a preview and nothing appears before a tap '
          '($language)', (tester) async {
        await _pump(tester, _details(hareem), const Size(1280, 3000));
        await tester.tap(find.byKey(Key(language)));
        await tester.pumpAndSettle();

        // Before any tap: no prompt, no action, no old always-on button.
        expect(find.byKey(const Key('rating-panel')), findsNothing);
        expect(find.byKey(const Key('rating-prompt')), findsNothing);
        expect(find.byKey(const Key('rating-confirm')), findsNothing);
        expect(find.byKey(const Key('rate-chalet')), findsNothing);
        expect(_filledStars(tester), 0);

        // Each star is a labelled, thumb-sized control.
        for (var i = 1; i <= 5; i++) {
          final star = find.byKey(Key('rating-star-$i'));
          expect(star, findsOneWidget);
          expect(tester.getSize(star).width, greaterThanOrEqualTo(44));
          expect(tester.getSize(star).height, greaterThanOrEqualTo(44));
        }

        await tester.tap(find.byKey(const Key('rating-star-4')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('rating-panel')), findsOneWidget);
        expect(_text(tester, 'rating-prompt'), contains('4'));
        expect(find.byKey(const Key('rating-preview-note')), findsOneWidget);
        expect(find.byKey(const Key('rating-confirm')), findsOneWidget);
        expect(_filledStars(tester), 4);

        // Changing the star updates the selection.
        await tester.tap(find.byKey(const Key('rating-star-2')));
        await tester.pumpAndSettle();
        expect(_filledStars(tester), 2);
        expect(_text(tester, 'rating-prompt'), contains('2'));
        expect(_text(tester, 'rating-prompt'), isNot(contains('4')));

        // Nothing is ever shown as an average or a count.
        expect(find.byKey(const Key('rating-average')), findsNothing);
        expect(find.byKey(const Key('rating-count')), findsNothing);
        expect(find.byKey(const Key('no-ratings-yet')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('confirming is a preview and never says it was saved '
          '($language)', (tester) async {
        await _pump(tester, _details(hareem), const Size(390, 3000));
        await tester.tap(find.byKey(Key(language)));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('rating-star-5')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('rating-confirm')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('rating-confirmed')), findsOneWidget);
        expect(find.byKey(const Key('rating-confirm')), findsNothing);
        expect(find.byKey(const Key('rating-preview-note')), findsOneWidget);
        final confirmed = _text(tester, 'rating-confirmed');
        expect(confirmed, contains('5'));
        expect(
          confirmed,
          language == 'lang-en'
              ? contains('Nothing was saved')
              : contains('لم يُحفظ'),
        );
        // The page still has no rating of its own.
        expect(find.byKey(const Key('rating-average')), findsNothing);
        expect(find.byKey(const Key('no-ratings-yet')), findsOneWidget);

        // Picking another star starts over with an unconfirmed prompt.
        await tester.tap(find.byKey(const Key('rating-star-3')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('rating-confirmed')), findsNothing);
        expect(find.byKey(const Key('rating-confirm')), findsOneWidget);
        expect(_filledStars(tester), 3);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('each star has a spoken label and a hint of its value', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _details(hareem), const Size(390, 3000));
      for (var i = 1; i <= 5; i++) {
        final node = tester.getSemantics(find.byKey(Key('rating-star-$i')));
        expect(node.label, contains('$i of 5'), reason: 'star $i');
      }
      handle.dispose();
    });
  });

  group('icon alignment and phone rating', () {
    test('the optical lift scales with the text size', () {
      expect(opticalLift(15), closeTo(15 * kTajawalOpticalLift, 1e-9));
      expect(opticalLift(30), closeTo(2 * opticalLift(15), 1e-9));
    });

    testWidgets('OpticalIcon sits above a plain centred icon by the lift', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 40),
              OpticalIcon(
                key: Key('optical'),
                icon: Icons.star,
                size: 20,
                color: Colors.black,
                textSize: 20,
              ),
              Icon(Icons.star, key: Key('plain'), size: 20),
            ],
          ),
        ),
      );
      // The shift is a paint transform, so measure the icon inside it.
      final optical = tester
          .getCenter(
            find.descendant(
              of: find.byKey(const Key('optical')),
              matching: find.byType(Icon),
            ),
          )
          .dy;
      final plain = tester.getCenter(find.byKey(const Key('plain'))).dy;
      expect(plain - optical, closeTo(opticalLift(20), 0.01));
    });

    for (final language in const ['lang-en', 'lang-ar']) {
      testWidgets('contact-card icons sit on their text line ($language)', (
        tester,
      ) async {
        await _pump(tester, _details(hareem), const Size(1280, 3000));
        await tester.tap(find.byKey(Key(language)));
        await tester.pumpAndSettle();

        double centre(Finder f) => tester.getCenter(f).dy;
        final number = find.byKey(const Key('contact-whatsapp-number'));
        final phone = find.byIcon(Icons.call_outlined);
        final note = find.byKey(const Key('booking-not-open-note'));
        final info = find.byIcon(Icons.info_outline);

        expect((centre(phone) - centre(number)).abs(), lessThanOrEqualTo(4));
        // The note wraps, so compare with its first line (top of the text).
        final firstLine = tester.getTopLeft(note).dy + 13 * 1.45 / 2;
        expect((centre(info) - firstLine).abs(), lessThanOrEqualTo(4));
      });

      testWidgets('locality and fact icons sit on their text ($language)', (
        tester,
      ) async {
        await _pump(tester, _details(hareem), const Size(1280, 3000));
        await tester.tap(find.byKey(Key(language)));
        await tester.pumpAndSettle();

        final link = find.byKey(const Key('listing-location-link'));
        final text = tester.getCenter(
          find.byKey(const Key('listing-location')),
        );
        for (final icon in [
          Icons.location_on_outlined,
          Icons.open_in_new_rounded,
        ]) {
          final centre = tester.getCenter(
            find.descendant(of: link, matching: find.byIcon(icon)),
          );
          expect((centre.dy - text.dy).abs(), lessThanOrEqualTo(5));
        }

        // Badge icon vs the two-line value/label block beside it.
        final fact = find.byKey(const Key('listing-bedrooms'));
        final badge = tester.getCenter(
          find.descendant(of: fact, matching: find.byIcon(Icons.bed_outlined)),
        );
        final block = tester.getRect(
          find.descendant(of: fact, matching: find.byType(Column)).first,
        );
        expect((badge.dy - block.center.dy).abs(), lessThanOrEqualTo(6));
      });
    }

    for (final width in const [360.0, 390.0]) {
      for (final language in const ['lang-en', 'lang-ar']) {
        testWidgets('phone ($width px, $language): facts balanced, rating '
            'compact and unframed', (tester) async {
          await _pump(tester, _details(hareem), Size(width, 3000));
          await tester.tap(find.byKey(Key(language)));
          await tester.pumpAndSettle();

          Rect tile(String key) => tester.getRect(
            find
                .ancestor(
                  of: find.byKey(Key(key)),
                  matching: find.byType(Material),
                )
                .first,
          );
          final bedrooms = tile('listing-bedrooms');
          final amenities = tile('listing-amenity-count');
          // Two even tiles on one row.
          expect(bedrooms.top, closeTo(amenities.top, 1));
          expect(bedrooms.width, closeTo(amenities.width, 1));
          expect(bedrooms.height, closeTo(amenities.height, 1));
          expect(
            (bedrooms.width + amenities.width + 12),
            closeTo(width - 40, 1),
          );

          // The rating is a light line under them: no strip, no tile frame,
          // no panel and no button until a star is tapped.
          final rating = tester.getRect(
            find.byKey(const Key('listing-rating')),
          );
          expect(find.byKey(const Key('facts-strip')), findsNothing);
          expect(rating.top, greaterThan(bedrooms.bottom));
          expect(rating.height, lessThan(110));
          expect(rating.left, greaterThanOrEqualTo(0));
          expect(rating.right, lessThanOrEqualTo(width));
          expect(find.byKey(const Key('rating-panel')), findsNothing);
          expect(find.byKey(const Key('rating-confirm')), findsNothing);

          // After a tap the panel stays inside the content width.
          await tester.tap(find.byKey(const Key('rating-star-3')));
          await tester.pumpAndSettle();
          final panel = tester.getRect(find.byKey(const Key('rating-panel')));
          expect(panel.left, greaterThanOrEqualTo(20 - 1));
          expect(panel.right, lessThanOrEqualTo(width - 20 + 1));
          expect(
            tester.getSize(find.byKey(const Key('rating-confirm'))).height,
            greaterThanOrEqualTo(44),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('amenities chip still scrolls from the phone layout', (
      tester,
    ) async {
      await _pump(tester, _details(hareem), const Size(390, 800));
      final section = find.byKey(const Key('amenities-section'));
      final scrollable = Scrollable.of(tester.element(section));
      await tester.ensureVisible(
        find.byKey(const Key('listing-amenity-count')),
      );
      await tester.pumpAndSettle();
      final before = scrollable.position.pixels;
      await tester.tap(find.byKey(const Key('listing-amenity-count')));
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, isNot(before));
      expect(tester.getTopLeft(section).dy, lessThan(800 * 0.4));
    });

    testWidgets('tablet and narrow desktop use light tiles, wide desktop a '
        'strip', (tester) async {
      for (final width in const [768.0, 1024.0]) {
        await _pump(tester, _details(hareem), Size(width, 3000));
        expect(find.byKey(const Key('facts-strip')), findsNothing);
        expect(find.byKey(const Key('listing-rating')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$width');
      }
      await _pump(tester, _details(hareem), const Size(1280, 3000));
      expect(find.byKey(const Key('facts-strip')), findsOneWidget);
      final strip = tester.getRect(find.byKey(const Key('facts-strip')));
      final rating = tester.getRect(find.byKey(const Key('listing-rating')));
      expect(rating.left, greaterThan(strip.left));
      expect(rating.right, lessThanOrEqualTo(strip.right));

      // The prompt appears inside the strip after a tap, not before.
      expect(find.byKey(const Key('rating-panel')), findsNothing);
      await tester.tap(find.byKey(const Key('rating-star-4')));
      await tester.pumpAndSettle();
      final panel = tester.getRect(find.byKey(const Key('rating-panel')));
      final grown = tester.getRect(find.byKey(const Key('facts-strip')));
      expect(panel.bottom, lessThanOrEqualTo(grown.bottom));
      expect(tester.takeException(), isNull);
    });
  });

  group('background', () {
    testWidgets('the page is a pale water blue, not beige', (tester) async {
      await _pump(tester, _details(hareem), const Size(1280, 3000));
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      final color = scaffold.backgroundColor!;
      expect(color, MaseefColors.page);
      // Blue-leaning and very light.
      expect(color.b, greaterThan(color.r));
      expect(color.r, greaterThan(0.85));
    });
  });

  group('responsive', () {
    for (final width in const [360.0, 390.0, 768.0, 1024.0, 1280.0, 1920.0]) {
      testWidgets('details fit at ${width.toInt()} px in English and Arabic', (
        tester,
      ) async {
        for (final listing in [hareem, celine, realListings[1]]) {
          for (final language in const ['lang-en', 'lang-ar']) {
            await _pump(tester, _details(listing), Size(width, 3600));
            await tester.tap(find.byKey(Key(language)));
            await tester.pumpAndSettle();
            for (final key in const [
              'amenities-section',
              'availability-section',
              'location-section',
            ]) {
              final finder = find.byKey(Key(key));
              if (finder.evaluate().isEmpty) continue;
              await tester.ensureVisible(finder);
              await tester.pump();
            }
            expect(
              tester.takeException(),
              isNull,
              reason: '${listing.id} $language at $width',
            );
          }
        }
      });
    }

    testWidgets('desktop puts the contact card in its own column', (
      tester,
    ) async {
      await _pump(tester, _details(hareem), const Size(1440, 3000));
      final card = tester.getRect(find.byKey(const Key('price-card')));
      final amenities = tester.getRect(
        find.byKey(const Key('amenities-section')),
      );
      final title = tester.getRect(find.byKey(const Key('listing-title')));
      expect(card.left, greaterThan(amenities.right));
      expect(title.right, lessThanOrEqualTo(card.left));
      expect(card.width, greaterThanOrEqualTo(360));
    });

    testWidgets('the phone reads in one column', (tester) async {
      await _pump(tester, _details(hareem), const Size(390, 3600));
      final title = tester.getRect(find.byKey(const Key('listing-title')));
      final card = tester.getRect(find.byKey(const Key('price-card')));
      final amenities = tester.getRect(
        find.byKey(const Key('amenities-section')),
      );
      expect(card.top, greaterThan(title.bottom));
      expect(amenities.top, greaterThan(card.bottom));
      expect(card.width, greaterThan(300));
    });
  });
}

Widget _details(Listing listing) =>
    ListingDetailsPage(listing: listing, onOpenLink: _ignoreLink);

Future<void> _ignoreLink(Uri uri) async {}

Future<void> _pump(WidgetTester tester, Widget home, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaseefApp(home: home));
  await tester.pumpAndSettle();
}

/// Number of filled stars in the page's rating selector.
int _filledStars(WidgetTester tester) => find
    .descendant(
      of: find.byKey(const Key('rating-stars')),
      matching: find.byIcon(Icons.star_rounded),
    )
    .evaluate()
    .length;

String? _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data;
