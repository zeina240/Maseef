import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:maseef_app/auth/auth_client.dart';
import 'package:maseef_app/auth/auth_session.dart';
import 'package:maseef_app/auth/token_store.dart';
import 'package:maseef_app/booking/booking_client.dart';
import 'package:maseef_app/booking/booking_models.dart';
import 'package:maseef_app/main.dart';
import 'package:maseef_app/pages/home_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('session token is stored without the role and cleared on logout', () async {
    final tokens = MemoryTokenStore();
    final calls = <AuthHttpRequest>[];
    final session = AuthSession(
      client: AuthClient(transport: (request) async {
        calls.add(request);
        if (request.uri.path.endsWith('/logout')) {
          return http.Response('{"status":"success"}', 200);
        }
        return _sessionResponse(
          token: 'opaque-session-token',
          role: 'customer',
          email: 'lina@example.com',
          fullName: 'Lina Guest',
        );
      }),
      tokens: tokens,
    );

    await session.login(email: 'lina@example.com', password: 'correct-horse');
    expect(session.user?.role, 'customer');
    expect(await tokens.read(), 'opaque-session-token');
    expect(calls.single.body, isNot(contains('role')));
    expect(calls.single.body, isNot(contains('listingKey')));

    await session.logout();
    expect(session.isSignedIn, isFalse);
    expect(await tokens.read(), isNull);
    expect(calls.last.headers['authorization'], 'Bearer opaque-session-token');
  });

  test('a rejected session is dropped and a network miss keeps the saved token', () async {
    final rejected = MemoryTokenStore();
    await rejected.write('old-token');
    final signedOut = AuthSession(
      client: AuthClient(
        transport: (request) async => http.Response(
          jsonEncode({'status': 'error', 'code': 'unauthenticated'}),
          401,
        ),
      ),
      tokens: rejected,
    );
    await signedOut.restore();
    expect(signedOut.user, isNull);
    expect(await rejected.read(), isNull);

    final kept = MemoryTokenStore();
    await kept.write('kept-token');
    final offline = AuthSession(
      client: AuthClient(
        transport: (request) async => throw Exception('offline'),
      ),
      tokens: kept,
    );
    await offline.restore();
    expect(offline.isSignedIn, isFalse);
    expect(await kept.read(), 'kept-token');
  });

  test('booking writes stay closed while the session token is ready to send', () async {
    final session = AuthSession(
      client: AuthClient(
        transport: (request) async => _sessionResponse(
          token: 'bearer-token',
          role: 'owner',
          email: 'host@example.com',
          fullName: 'Host Person',
        ),
      ),
      tokens: MemoryTokenStore(),
    );
    await session.register(
      fullName: 'Host Person',
      email: 'host@example.com',
      password: 'correct-horse',
      role: 'owner',
    );

    final blockedCalls = <BookingCall>[];
    final blocked = ApiBookingClient(
      session: session,
      callSender: (call) async {
        blockedCalls.add(call);
        return http.Response('{}', 500);
      },
    );
    const draft = BookingDraft(
      listingKey: 'hareem-sultan',
      stayDate: '2026-11-02',
      mode: BookingMode.morning,
    );
    expect(
      blocked.submitRequest(draft),
      throwsA(
        isA<BookingAuthException>().having(
          (error) => error.reason,
          'reason',
          BookingBlockReason.storageNotApproved,
        ),
      ),
    );
    expect(blocked.loadMyRequests(), throwsA(isA<BookingAuthException>()));
    expect(blockedCalls, isEmpty);

    final sent = <BookingCall>[];
    final enabled = ApiBookingClient(
      session: session,
      writesEnabled: true,
      callSender: (call) async {
        sent.add(call);
        if (call.method == 'GET') {
          return http.Response(
            jsonEncode({
              'status': 'success',
              'data': [
                {
                  'reference': 'MS-READY',
                  'listingKey': 'hareem-sultan',
                  'stayDate': '2026-11-02',
                  'mode': 'morning',
                  'status': 'pending',
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'status': 'success',
            'data': {
              'reference': 'MS-READY',
              'listingKey': 'hareem-sultan',
              'stayDate': '2026-11-02',
              'mode': 'morning',
              'status': 'pending',
            },
          }),
          201,
        );
      },
    );
    final created = await enabled.submitRequest(draft);
    expect(created.status, 'pending');
    expect(created.reference, 'MS-READY');
    final body = jsonDecode(sent.single.body!) as Map<String, dynamic>;
    expect(body.keys.toSet(), {'stayDate', 'mode'});
    expect(sent.single.headers['authorization'], 'Bearer bearer-token');
    expect(sent.single.headers.containsKey('x-user-role'), isFalse);
    expect(sent.single.uri.path, '/api/listings/hareem-sultan/booking-requests');

    final requests = await enabled.loadMyRequests();
    expect(requests.single.reference, 'MS-READY');
    expect(sent.last.headers['authorization'], 'Bearer bearer-token');
    expect(sent.last.uri.path, '/api/me/booking-requests');

    final unsigned = ApiBookingClient(writesEnabled: true);
    expect(unsigned.submitRequest(draft), throwsA(isA<BookingAuthException>()));
  });

  testWidgets('login, registration, and account screens follow the session', (
    tester,
  ) async {
    final calls = <AuthHttpRequest>[];
    final session = AuthSession(
      client: AuthClient(transport: (request) async {
        calls.add(request);
        final body = request.body == null
            ? null
            : jsonDecode(request.body!) as Map<String, dynamic>;
        if (request.uri.path.endsWith('/login')) {
          if (body?['password'] == 'wrong-password-value') {
            return http.Response(
              jsonEncode({'status': 'error', 'code': 'invalid_credentials'}),
              401,
            );
          }
        }
        if (request.uri.path.endsWith('/register') &&
            body?['email'] == 'taken@example.com') {
          return http.Response(
            jsonEncode({'status': 'error', 'code': 'email_taken'}),
            409,
          );
        }
        if (request.uri.path.endsWith('/logout')) {
          return http.Response('{"status":"success"}', 200);
        }
        return _sessionResponse(
          token: 'screen-token',
          role: body?['role'] as String? ?? 'customer',
          email: body?['email'] as String? ?? 'lina@example.com',
          fullName: body?['fullName'] as String? ?? 'Lina Guest',
          phone: body?['phone'] as String?,
        );
      }),
      tokens: MemoryTokenStore(),
    );

    await _pump(tester, session, const Size(1280, 1600));
    expect(find.text('Sign in'), findsOneWidget);
    await tester.tap(find.byKey(const Key('account-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth-email')), findsOneWidget);

    await tester.tap(find.byKey(const Key('lang-ar')));
    await tester.pumpAndSettle();
    expect(find.text('تسجيل الدخول'), findsWidgets);
    expect(
      Directionality.of(tester.element(find.text('تسجيل الدخول').first)),
      TextDirection.rtl,
    );

    await tester.tap(find.byKey(const Key('lang-en')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('auth-go-register')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('role-customer')), findsOneWidget);
    expect(find.byKey(const Key('role-owner')), findsOneWidget);
    expect(find.byKey(const Key('role-admin')), findsNothing);
    expect(find.textContaining('create or assign a chalet'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('register-name')), 'Lina Guest');
    await tester.enterText(find.byKey(const Key('auth-email')), 'lina@example.com');
    await tester.enterText(find.byKey(const Key('auth-password')), 'short');
    await tester.enterText(find.byKey(const Key('register-confirm')), 'short');
    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    // Validation is inline now: the short password is flagged on its own field.
    expect(
      find.text('Use a password of at least 10 characters and at most 128.'),
      findsOneWidget,
    );
    expect(calls, isEmpty);

    await tester.enterText(find.byKey(const Key('auth-password')), 'correct-horse');
    await tester.enterText(find.byKey(const Key('register-confirm')), 'correct-horse');
    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    final registerBody = jsonDecode(calls.single.body!) as Map<String, dynamic>;
    expect(registerBody['role'], 'customer');
    expect(registerBody.containsKey('listingKey'), isFalse);
    expect(registerBody.containsKey('userId'), isFalse);
    expect(registerBody.containsKey('chaletId'), isFalse);
    expect(find.text('Account'), findsOneWidget);

    await tester.tap(find.byKey(const Key('account-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-email')), findsOneWidget);
    expect(find.text('lina@example.com'), findsOneWidget);
    expect(find.text('Guest'), findsOneWidget);
    expect(find.byKey(const Key('account-booking-closed')), findsOneWidget);
    expect(find.byKey(const Key('account-owner-note')), findsNothing);

    await tester.tap(find.byKey(const Key('account-logout')));
    await tester.pumpAndSettle();
    expect(session.isSignedIn, isFalse);
    expect(find.text('Sign in'), findsOneWidget);

    await tester.tap(find.byKey(const Key('account-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('auth-email')), 'lina@example.com');
    await tester.enterText(find.byKey(const Key('auth-password')), 'wrong-password-value');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    expect(find.text('The email or password is incorrect.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('auth-go-register')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('role-owner')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('register-name')), 'Host Person');
    await tester.enterText(find.byKey(const Key('auth-email')), 'taken@example.com');
    await tester.enterText(find.byKey(const Key('auth-password')), 'correct-horse');
    await tester.enterText(find.byKey(const Key('register-confirm')), 'correct-horse');
    await tester.ensureVisible(find.byKey(const Key('auth-submit')));
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    expect(find.text('An account with this email already exists.'), findsOneWidget);
    final taken = jsonDecode(calls.last.body!) as Map<String, dynamic>;
    expect(taken['role'], 'owner');
    expect(taken.containsKey('listingKey'), isFalse);

    await tester.tap(find.byKey(const Key('lang-ar')));
    await tester.pumpAndSettle();
    expect(find.text('يوجد حساب بهذا البريد.'), findsOneWidget);
    expect(find.textContaining('لا ينشئ شاليهاً'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('auth screens stay within bounds on a phone and a desktop', (
    tester,
  ) async {
    final session = AuthSession(
      client: AuthClient(
        transport: (request) async => http.Response('{}', 500),
      ),
      tokens: MemoryTokenStore(),
    );
    for (final size in const [Size(360, 900), Size(1280, 900)]) {
      await _pump(tester, session, size);
      await tester.tap(find.byKey(const Key('account-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('auth-email')), findsOneWidget);
      await tester.tap(find.byKey(const Key('auth-go-register')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('register-name')), findsOneWidget);
      await tester.tap(find.byKey(const Key('lang-ar')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('auth-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('auth-back')));
      await tester.pumpAndSettle();
    }
  });
}

http.Response _sessionResponse({
  required String token,
  required String role,
  required String email,
  required String fullName,
  String? phone,
}) {
  return http.Response(
    jsonEncode({
      'status': 'success',
      'data': {
        'token': token,
        'expiresAt': '2026-11-24T00:00:00.000Z',
        'user': {
          'id': '4',
          'fullName': fullName,
          'email': email,
          'phone': phone,
          'role': role,
        },
      },
    }),
    201,
  );
}

Future<void> _pump(WidgetTester tester, AuthSession session, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaseefApp(
      session: session,
      home: const HomePage(bookingClient: NotConfiguredBookingClient()),
    ),
  );
  await tester.pumpAndSettle();
}
