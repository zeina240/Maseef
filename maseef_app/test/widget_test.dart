import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maseef_app/booking/booking_client.dart';
import 'package:maseef_app/data/real_listings.dart';
import 'package:maseef_app/main.dart';
import 'package:maseef_app/models/listing.dart';
import 'package:maseef_app/pages/home_page.dart';
import 'package:maseef_app/pages/listing_details_page.dart';
import 'package:maseef_app/widgets/social_icon_button.dart';
import 'package:maseef_app/widgets/svg_path.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('local numbers use the Palestinian WhatsApp country code', () {
    expect(whatsAppUri('0597302415').toString(), 'https://wa.me/970597302415');
    expect(
      whatsAppUri('+972594796885').toString(),
      'https://wa.me/972594796885',
    );
  });

  test('brand icon paths parse into visible marks', () {
    final rect = parseSvgPath('M0 0 H10 V10 H0 Z');
    expect(rect.getBounds(), const Rect.fromLTRB(0, 0, 10, 10));

    final arc = parseSvgPath('M12 12 a9.87 9.87 0 01-5.031-1.378');
    expect(arc.getBounds().width, greaterThan(0));

    for (final platform in SocialPlatform.values) {
      final bounds = parseSvgPath(glyphPathFor(platform)).getBounds();
      expect(bounds.width, greaterThan(10));
      expect(bounds.height, greaterThan(10));
      expect(bounds.left, greaterThan(-1));
      expect(bounds.top, greaterThan(-1));
      expect(bounds.right, lessThan(26));
      expect(bounds.bottom, lessThan(26));
    }
  });

  test('contact buttons use brand colors for hover, focus, and press', () {
    expect(
      socialButtonBackground(SocialPlatform.whatsapp, {}),
      Colors.white,
    );
    final hovered = socialButtonBackground(SocialPlatform.whatsapp, {
      WidgetState.hovered,
    });
    expect(hovered.a, closeTo(0.12, 0.02));
    expect(hovered.r, closeTo(0x25 / 255, 0.01));
    expect(hovered.g, closeTo(0xD3 / 255, 0.01));

    final pressed = socialButtonBackground(SocialPlatform.facebook, {
      WidgetState.pressed,
    });
    expect(pressed.a, closeTo(0.22, 0.02));
    expect(
      socialButtonBorder(SocialPlatform.instagram, {WidgetState.focused}),
      const Color(0xFF123A68),
    );
    expect(
      socialButtonBorder(SocialPlatform.instagram, {WidgetState.hovered}),
      const Color(0xFFE1306C),
    );
  });

  test('search matches names and places in English and Arabic', () {
    final hareem = realListings.first;
    expect(hareem.matchesQuery('Hareem'), isTrue);
    expect(hareem.matchesQuery('Nablus'), isTrue);
    expect(hareem.matchesQuery('نابلس'), isTrue);
    expect(hareem.matchesQuery('Al-Nasariya'), isTrue);
    expect(hareem.matchesQuery('Jenin'), isFalse);

    final garden = realListings.last;
    expect(garden.matchesQuery('Deir Ghazala'), isTrue);
    expect(garden.matchesQuery('دير غزالة'), isTrue);
    expect(garden.matchesQuery('Talluza'), isFalse);
  });

  test('the catalog keeps the five supplied listings and their real photos', () {
    expect(realListings, hasLength(5));
    expect(realListings.map((listing) => listing.name), [
      'Hareem Sultan Resort',
      'W Villa',
      'Celine Villa',
      'Haifa Villa',
      'Green Garden Villa',
    ]);
    expect(realListings.map((listing) => listing.whatsapp), [
      '+970566232380',
      '+970597200700',
      '+970566600051',
      '+972594796885',
      '0597302415',
    ]);
    expect(realListings.first.photoAssets, hareemSultanGallery);
    expect(realListings.first.bedrooms, 3);
    expect(realListings.first.amenityKeys, hareemSultanAmenities);
    expect(realListings.first.whatsapp, '+970566232380');
    expect(
      realListings.first.facebookUrl,
      'https://www.facebook.com/share/1BQ7hugSBH/?mibextid=LQQJ4d',
    );
    expect(
      realListings.skip(1).map((listing) => listing.photoAssets.single),
      [
        'assets/images/W.png',
        'assets/images/CelineVilla.png',
        'assets/images/Haifa.png',
        'assets/images/GreenGarden.png',
      ],
    );
    expect(
      realListings.skip(1).every((listing) => listing.bedrooms == null),
      isTrue,
    );
    expect(
      realListings.skip(1).every((listing) => listing.amenityKeys.isEmpty),
      isTrue,
    );
    expect(
      realListings.map((listing) => listing.referencedImageFilename),
      [
        'Pool.jpg',
        'W.png',
        'CelineVilla.png',
        'Haifa.png',
        'GreenGarden.png',
      ],
    );
  });

  test('bundled images and the web favicon exist', () async {
    for (final asset in [
      'assets/images/home.png',
      'assets/images/Favicon.png',
      'assets/images/HareemSultan.png',
      ...hareemSultanGallery,
      'assets/images/W.png',
      'assets/images/CelineVilla.png',
      'assets/images/Haifa.png',
      'assets/images/GreenGarden.png',
    ]) {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(1000), reason: asset);
    }

    final html = File('web/index.html').readAsStringSync();
    expect(html, contains('<title>MASEEF</title>'));
    expect(html, contains('href="favicon.png"'));
    expect(File('web/favicon.png').existsSync(), isTrue);
  });

  testWidgets('shows the five chalets in English without a stay count', (
    tester,
  ) async {
    await _pump(tester, const HomePage(bookingClient: NotConfiguredBookingClient()));

    expect(find.text('MASEEF'), findsWidgets);
    expect(find.text('Find Your Perfect Getaway'), findsOneWidget);
    expect(
      find.text(
        'Discover beautiful chalets and relaxing escapes across Palestine.',
      ),
      findsWidgets,
    );
    expect(find.text('Hareem Sultan Resort'), findsOneWidget);
    expect(find.text('W Villa'), findsOneWidget);
    expect(find.text('Celine Villa'), findsOneWidget);
    expect(find.text('Haifa Villa'), findsOneWidget);
    expect(find.text('Green Garden Villa'), findsOneWidget);
    expect(find.text('Contact for price'), findsWidgets);
    expect(find.text('Price unavailable'), findsNothing);
    expect(find.text('السعر غير متوفر'), findsNothing);
    expect(find.text('5 stays'), findsNothing);
    expect(find.text('5 إقامات'), findsNothing);
    expect(find.text('Details'), findsNothing);
    expect(find.text('التفاصيل'), findsNothing);
    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.byKey(const Key('filter-المحافظة-جنين')), findsNothing);
    expect(
      Directionality.of(tester.element(find.text('Find Your Perfect Getaway'))),
      TextDirection.ltr,
    );

    final hero = tester.widget<Image>(find.byKey(const Key('home-hero-image')));
    expect((hero.image as AssetImage).assetName, 'assets/images/home.png');
    final hareem = tester.widget<Image>(
      find.byKey(const Key('photo-hareem-sultan')),
    );
    expect(
      (hareem.image as AssetImage).assetName,
      'assets/images/HareemSultan/Pool.jpg',
    );
    expect(find.text('Al-Nasariya, Nablus'), findsOneWidget);
  });

  testWidgets('search finds governorate and locality without filter chips', (
    tester,
  ) async {
    await _pump(tester, const HomePage(bookingClient: NotConfiguredBookingClient()));

    await tester.enterText(find.byKey(const Key('search-field')), 'Jenin');
    await tester.pumpAndSettle();

    expect(find.text('Celine Villa'), findsOneWidget);
    expect(find.text('Haifa Villa'), findsOneWidget);
    expect(find.text('Green Garden Villa'), findsOneWidget);
    expect(find.text('Hareem Sultan Resort'), findsNothing);

    await tester.enterText(find.byKey(const Key('search-field')), 'طلوزة');
    await tester.pumpAndSettle();

    expect(find.text('W Villa'), findsOneWidget);
    expect(find.text('Haifa Villa'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('search-field')),
      'Deir Ghazaleh',
    );
    await tester.pumpAndSettle();

    expect(find.text('Green Garden Villa'), findsOneWidget);
    expect(find.text('Celine Villa'), findsNothing);
  });

  testWidgets('a card opens details and contact icons keep the real links', (
    tester,
  ) async {
    final opened = <Uri>[];
    await _pump(
      tester,
      HomePage(
        bookingClient: const NotConfiguredBookingClient(),
        openLink: (uri) async => opened.add(uri),
      ),
    );

    await tester.tap(find.byKey(const Key('whatsapp-hareem-sultan')));
    await tester.pumpAndSettle();

    expect(opened, [whatsAppUri('+970566232380')]);
    expect(find.byKey(const Key('house-rules')), findsNothing);

    await tester.ensureVisible(find.text('W Villa'));
    await tester.tap(find.text('W Villa'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('details-brand')), findsOneWidget);
    expect(find.text('W Villa'), findsOneWidget);
    expect(find.text('+970597200700'), findsOneWidget);
    final photo = tester.widget<Image>(find.byKey(const Key('photo-cover-w-villa')));
    expect((photo.image as AssetImage).assetName, 'assets/images/W.png');
    expect(find.byKey(const Key('instagram-w-villa')), findsOneWidget);
    expect(find.byKey(const Key('facebook-w-villa')), findsNothing);
    expect(find.byKey(const Key('whatsapp-w-villa')), findsOneWidget);
    expect(
      find.text('House rules have not been provided yet.'),
      findsOneWidget,
    );
    expect(find.textContaining('Bedrooms'), findsNothing);
    expect(find.text('Swimming pool'), findsNothing);
    expect(find.byKey(const Key('availability-not-provided')), findsOneWidget);
    expect(find.text('Details'), findsNothing);

    await tester.tap(find.byKey(const Key('instagram-w-villa')));
    await tester.pump();
    expect(
      opened.last.toString(),
      'https://www.instagram.com/w.villa.nablus?psln=YTB2MmtlOTZncWM0',
    );

    await tester.tap(find.byKey(const Key('back-to-listings')));
    await tester.pumpAndSettle();
    expect(find.text('Find Your Perfect Getaway'), findsOneWidget);
  });

  testWidgets('Arabic switches the interface copy and the reading direction', (
    tester,
  ) async {
    await _pump(tester, const HomePage(bookingClient: NotConfiguredBookingClient()));

    await tester.tap(find.byKey(const Key('lang-ar')));
    await tester.pumpAndSettle();

    expect(find.text('اعثر على إجازتك المثالية'), findsOneWidget);
    expect(find.text('تواصل لمعرفة السعر'), findsWidgets);
    expect(find.text('الشاليهات'), findsOneWidget);
    expect(find.text('النصارية، نابلس'), findsOneWidget);
    expect(find.text('Hareem Sultan Resort'), findsOneWidget);
    expect(find.text('Nablus'), findsNothing);
    expect(
      Directionality.of(tester.element(find.text('اعثر على إجازتك المثالية'))),
      TextDirection.rtl,
    );

    await tester.ensureVisible(find.text('W Villa'));
    await tester.tap(find.text('W Villa'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('details-brand')), findsOneWidget);
    expect(find.text('رجوع'), findsOneWidget);
    expect(find.text('+970597200700'), findsOneWidget);
    expect(find.text('لم يزوّد المالك قواعد المنزل بعد.'), findsOneWidget);
    expect(find.byKey(const Key('instagram-w-villa')), findsOneWidget);
    expect(find.text('إنستغرام'), findsOneWidget);
    expect(find.textContaining('طلوزة'), findsWidgets);
    expect(
      Directionality.of(tester.element(find.byKey(const Key('details-brand')))),
      TextDirection.rtl,
    );

    await tester.tap(find.byKey(const Key('lang-en')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('details-brand')), findsOneWidget);
    expect(find.byKey(const Key('listing-location')), findsOneWidget);
    expect(find.text('Talluza, Nablus'), findsWidgets);
    expect(
      Directionality.of(tester.element(find.byKey(const Key('details-brand')))),
      TextDirection.ltr,
    );
  });

  testWidgets('shows an error state when listings cannot load', (tester) async {
    await _pump(
      tester,
      HomePage(
        bookingClient: const NotConfiguredBookingClient(),
        source: _FailingSource(),
        openLink: (_) async {},
      ),
    );

    expect(find.byKey(const Key('listings-error')), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text("Couldn't load stays"), findsOneWidget);
  });

  testWidgets('a missing photo uses the fallback instead of another picture', (
    tester,
  ) async {
    const listing = Listing(
      id: 'missing-photo',
      name: 'Missing Photo',
      governorate: 'جنين',
      locality: 'جنين',
      whatsapp: '+970566600051',
      referencedImageFilename: 'missing.png',
    );
    await _pump(
      tester,
      const ListingDetailsPage(listing: listing, onOpenLink: _ignoreLink),
    );

    expect(find.byKey(const Key('photo-fallback-missing-photo')), findsOneWidget);
    expect(find.text('Photo not available'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            (widget.image as AssetImage).assetName !=
                'assets/images/Favicon.png',
      ),
      findsNothing,
    );
  });

  testWidgets('layouts stay within bounds on phone, tablet, and desktop', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    tester.view.physicalSize = const Size(360, 2200);
    await tester.pumpWidget(
      const MaseefApp(
        home: HomePage(bookingClient: NotConfiguredBookingClient()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Find Your Perfect Getaway'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Hareem Sultan Resort'));
    await tester.tap(find.text('Hareem Sultan Resort'));
    await tester.pumpAndSettle();
    expect(find.text('+970566232380'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('lang-ar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('details-brand')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('back-to-listings')));
    await tester.pumpAndSettle();

    for (final size in const [Size(800, 1600), Size(1280, 1600)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}

class _FailingSource extends ListingSource {
  @override
  Future<List<Listing>> load() async {
    throw Exception('failed');
  }
}

Future<void> _ignoreLink(Uri uri) async {}

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1280, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaseefApp(home: home));
  await tester.pumpAndSettle();
}
