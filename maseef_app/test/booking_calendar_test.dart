import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:maseef_app/booking/booking_client.dart';
import 'package:maseef_app/booking/booking_models.dart';
import 'package:maseef_app/main.dart';
import 'package:maseef_app/models/listing.dart';
import 'package:maseef_app/pages/booking_requests_page.dart';
import 'package:maseef_app/pages/listing_details_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('availability parsing keeps real states and ignores a missing schedule', () async {
    final calls = <Uri>[];
    final client = ApiBookingClient(
      sender: (uri) async {
        calls.add(uri);
        return http.Response('''
{
  "status": "success",
  "data": {
    "configured": true,
    "reason": "configured",
    "year": 2026,
    "month": 10,
    "days": [
      {
        "date": "2026-10-26",
        "state": "partial",
        "modes": {
          "morning": {"status": "booked", "start": "08:00", "end": "13:00", "price": null},
          "evening": {"status": "available", "start": "14:00", "end": "22:00", "price": 180}
        }
      }
    ]
  }
}
''', 200);
      },
    );

    final snapshot = await client.loadMonth(
      listingKey: 'hareem-sultan',
      year: 2026,
      month: 10,
    );
    expect(calls.single.path, contains('/api/listings/hareem-sultan/availability'));
    expect(snapshot.configured, isTrue);
    expect(snapshot.days.single.state, DayState.partial);
    expect(snapshot.days.single.modes[BookingMode.morning]!.status, ModeAvailability.booked);
    expect(snapshot.days.single.modes[BookingMode.evening]!.price, 180);

    final empty = ApiBookingClient(
      sender: (uri) async => http.Response(
        '{"status":"success","data":{"configured":false,"reason":"not_configured","days":[]}}',
        200,
      ),
    );
    final missing = await empty.loadMonth(
      listingKey: 'hareem-sultan',
      year: 2026,
      month: 10,
    );
    expect(missing.configured, isFalse);
    expect(missing.days, isEmpty);

    var submitCalls = 0;
    final blocked = ApiBookingClient(
      sender: (uri) async {
        submitCalls += 1;
        return http.Response('{}', 500);
      },
    );
    expect(
      blocked.submitRequest(
        const BookingDraft(
          listingKey: 'hareem-sultan',
          stayDate: '2026-10-26',
          mode: BookingMode.morning,
        ),
      ),
      throwsA(isA<BookingAuthException>()),
    );
    expect(blocked.loadMyRequests(), throwsA(isA<BookingAuthException>()));
    expect(submitCalls, 0);
  });

  testWidgets('Hareem Sultan shows its gallery and supplied amenities', (tester) async {
    await _pump(
      tester,
      ListingDetailsPage(
        listing: _hareem,
        onOpenLink: _ignore,
        bookingClient: const NotConfiguredBookingClient(),
      ),
      const Size(1280, 3600),
    );

    final cover = tester.widget<Image>(find.byKey(const Key('photo-cover-hareem-sultan')));
    expect((cover.image as AssetImage).assetName, 'assets/images/HareemSultan/Pool.jpg');
    await tester.tap(find.byKey(const Key('gallery-tile-hareem-sultan-2')));
    await tester.pumpAndSettle();
    final kitchen = tester.widget<Image>(find.byKey(const Key('photo-viewer-hareem-sultan-2')));
    expect((kitchen.image as AssetImage).assetName, 'assets/images/HareemSultan/kitchen.jpg');
    await tester.tap(find.byKey(const Key('viewer-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('viewer-pages')), findsNothing);
    expect(find.descendant(of: find.byKey(const Key('listing-bedrooms')), matching: find.text('3')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('listing-bedrooms')), matching: find.text('Bedrooms')), findsOneWidget);
    expect(find.text('Swimming pool'), findsOneWidget);
    expect(find.text("Children's pool"), findsOneWidget);
    expect(find.text('Barbecue grill'), findsOneWidget);
    expect(find.text('Private parking'), findsOneWidget);
    expect(find.text('+970566232380'), findsOneWidget);
    expect(find.byKey(const Key('availability-not-provided')), findsOneWidget);
    expect(find.text('Booked'), findsNothing);
    expect(find.text('Pending request'), findsNothing);
  });

  testWidgets('calendar states, request blocking, and both languages', (tester) async {
    final client = _FixtureClient(_october());
    await _pump(
      tester,
      ListingDetailsPage(
        listing: _hareem,
        onOpenLink: _ignore,
        bookingClient: client,
        initialMonth: DateTime(2026, 10),
      ),
      const Size(390, 3600),
    );

    expect(find.byKey(const Key('calendar-grid')), findsOneWidget);
    expect(find.byKey(const Key('legend-available')), findsOneWidget);
    expect(find.byKey(const Key('legend-partial')), findsOneWidget);
    expect(find.text('October 2026'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byKey(const Key('calendar-grid')))),
      TextDirection.ltr,
    );

    await tester.ensureVisible(find.byKey(const Key('day-2026-10-29')));
    await tester.tap(find.byKey(const Key('day-2026-10-29')));
    await tester.pumpAndSettle();
    expect(find.text('Booked'), findsWidgets);
    expect(find.byKey(const Key('selected-day-status')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('day-2026-10-27')));
    await tester.tap(find.byKey(const Key('day-2026-10-27')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('selected-day-status')), findsOneWidget);
    expect(find.text('Partially available'), findsWidgets);
    final morning = tester.widget<ChoiceChip>(find.byKey(const Key('mode-morning')));
    final evening = tester.widget<ChoiceChip>(find.byKey(const Key('mode-evening')));
    expect(morning.onSelected, isNull);
    expect(evening.onSelected, isNotNull);

    await tester.ensureVisible(find.byKey(const Key('day-2026-10-26')));
    await tester.tap(find.byKey(const Key('day-2026-10-26')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('submit-booking-request')));
    await tester.tap(find.byKey(const Key('submit-booking-request')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('booking-auth-required')), findsOneWidget);
    expect(find.byKey(const Key('booking-reference')), findsNothing);
    expect(client.submissions, 1);

    await tester.tap(find.byKey(const Key('lang-ar')));
    await tester.pumpAndSettle();
    expect(find.text('أكتوبر 2026'), findsOneWidget);
    expect(find.text('متاح جزئياً'), findsWidgets);
    expect(find.text('طلب قيد الانتظار'), findsWidgets);
    expect(find.text('محجوز'), findsWidgets);
    expect(find.text('مسبح'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('listing-bedrooms')),
        matching: find.text('غرف النوم'),
      ),
      findsOneWidget,
    );
    expect(
      Directionality.of(tester.element(find.byKey(const Key('calendar-grid')))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a returned request stays pending and is not shown as confirmed', (
    tester,
  ) async {
    const created = CustomerBookingRequest(
      reference: 'MS-TESTONLY',
      listingKey: 'hareem-sultan',
      stayDate: '2026-10-26',
      mode: BookingMode.morning,
      status: 'pending',
    );
    final client = _FixtureClient(_october(), created: created);
    await _pump(
      tester,
      ListingDetailsPage(
        listing: _hareem,
        onOpenLink: _ignore,
        bookingClient: client,
        initialMonth: DateTime(2026, 10),
      ),
      const Size(1280, 3600),
    );

    await tester.ensureVisible(find.byKey(const Key('day-2026-10-26')));
    await tester.tap(find.byKey(const Key('day-2026-10-26')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('submit-booking-request')));
    await tester.tap(find.byKey(const Key('submit-booking-request')));
    await tester.pumpAndSettle();
    expect(find.text('Booking reference: MS-TESTONLY'), findsOneWidget);
    expect(find.byKey(const Key('booking-pending-confirmation')), findsOneWidget);
    expect(find.textContaining('not confirmed'), findsOneWidget);

    await tester.tap(find.byKey(const Key('view-booking-requests')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('request-status-MS-TESTONLY')), findsOneWidget);
    expect(find.text('Pending request'), findsWidgets);
    expect(find.byKey(const Key('request-status-MS-TESTONLY')).evaluate().length, 1);
    final status = tester.widget<Text>(
      find.byKey(const Key('request-status-MS-TESTONLY')),
    );
    expect(status.data, 'Pending request');
    expect(tester.takeException(), isNull);
  });

  testWidgets('request list stays empty without a customer session', (tester) async {
    await _pump(
      tester,
      const BookingRequestsPage(client: NotConfiguredBookingClient()),
      const Size(800, 900),
    );
    expect(find.byKey(const Key('requests-auth-required')), findsOneWidget);
    expect(find.textContaining('MS-'), findsNothing);

    await tester.tap(find.byKey(const Key('lang-ar')));
    await tester.pumpAndSettle();
    expect(find.text('طلباتك'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('طلباتك'))),
      TextDirection.rtl,
    );
  });

  testWidgets('calendar layouts stay within bounds on phone and desktop', (tester) async {
    for (final size in const [Size(360, 2400), Size(1280, 1600)]) {
      await _pump(
        tester,
        ListingDetailsPage(
          listing: _hareem,
          onOpenLink: _ignore,
          bookingClient: _FixtureClient(_october()),
          initialMonth: DateTime(2026, 10),
        ),
        size,
      );
      await tester.ensureVisible(find.byKey(const Key('calendar-grid')));
      expect(find.byKey(const Key('calendar-grid')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('lang-ar')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}

const _hareem = Listing(
  id: 'hareem-sultan',
  name: 'Hareem Sultan Resort',
  governorate: 'نابلس',
  locality: 'النصارية',
  whatsapp: '+970566232380',
  facebookUrl: 'https://www.facebook.com/share/1BQ7hugSBH/?mibextid=LQQJ4d',
  referencedImageFilename: 'Pool.jpg',
  photoAssets: [
    'assets/images/HareemSultan/Pool.jpg',
    'assets/images/HareemSultan/livingRoom.jpg',
    'assets/images/HareemSultan/kitchen.jpg',
    'assets/images/HareemSultan/ROOM1.jpg',
    'assets/images/HareemSultan/ROOM2.jpg',
    'assets/images/HareemSultan/ROOM3.jpg',
    'assets/images/HareemSultan/bathRoom.jpg',
  ],
  bedrooms: 3,
  amenityKeys: [
    'outdoor_seating',
    'equipped_kitchen',
    'swimming_pool',
    'wifi',
    'billiards',
    'childrens_pool',
    'childrens_play_equipment',
    'barbecue_grill',
    'private_parking',
  ],
);

AvailabilitySnapshot _october() {
  CalendarDay day(int date, DayState state, Map<BookingMode, ModeOffer> modes) {
    return CalendarDay(date: DateTime(2026, 10, date), state: state, modes: modes);
  }

  ModeOffer mode(BookingMode value, ModeAvailability status, String start, String end) {
    return ModeOffer(mode: value, status: status, start: start, end: end);
  }

  return AvailabilitySnapshot(
    configured: true,
    listingKey: 'hareem-sultan',
    reason: 'configured',
    year: 2026,
    month: 10,
    days: [
      day(26, DayState.available, {
        BookingMode.fullDay: mode(BookingMode.fullDay, ModeAvailability.available, '08:00', '22:00'),
        BookingMode.morning: mode(BookingMode.morning, ModeAvailability.available, '08:00', '13:00'),
        BookingMode.evening: mode(BookingMode.evening, ModeAvailability.available, '14:00', '22:00'),
      }),
      day(27, DayState.partial, {
        BookingMode.morning: mode(BookingMode.morning, ModeAvailability.booked, '08:00', '13:00'),
        BookingMode.evening: mode(BookingMode.evening, ModeAvailability.available, '14:00', '22:00'),
      }),
      day(28, DayState.pending, {
        BookingMode.fullDay: mode(BookingMode.fullDay, ModeAvailability.pending, '08:00', '22:00'),
      }),
      day(29, DayState.booked, {
        BookingMode.fullDay: mode(BookingMode.fullDay, ModeAvailability.booked, '08:00', '22:00'),
      }),
      day(30, DayState.closed, const {}),
    ],
  );
}

class _FixtureClient implements BookingClient {
  _FixtureClient(this.snapshot, {this.created});

  final AvailabilitySnapshot snapshot;
  final CustomerBookingRequest? created;
  int submissions = 0;

  @override
  Future<AvailabilitySnapshot> loadMonth({
    required String listingKey,
    required int year,
    required int month,
  }) async {
    return snapshot;
  }

  @override
  Future<List<CustomerBookingRequest>> loadMyRequests() async {
    final request = created;
    if (request == null) throw const BookingAuthException();
    return [request];
  }

  @override
  Future<CustomerBookingRequest> submitRequest(BookingDraft draft) async {
    submissions += 1;
    final request = created;
    if (request == null) throw const BookingAuthException();
    return request;
  }
}

Future<void> _ignore(Uri uri) async {}

Future<void> _pump(WidgetTester tester, Widget home, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaseefApp(home: home));
  await tester.pumpAndSettle();
}
