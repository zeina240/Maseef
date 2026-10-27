import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:maseef_app/auth/auth_client.dart';
import 'package:maseef_app/auth/auth_session.dart';
import 'package:maseef_app/auth/token_store.dart';
import 'package:maseef_app/main.dart';
import 'package:maseef_app/pages/forgot_password_page.dart';
import 'package:maseef_app/pages/login_page.dart';
import 'package:maseef_app/pages/register_page.dart';
import 'package:maseef_app/pages/reset_password_page.dart';

const _token = 'abcdefghijklmnop1234567890';

AuthSession _session(Future<http.Response> Function(AuthHttpRequest) handler) {
  return AuthSession(
    client: AuthClient(transport: handler),
    tokens: MemoryTokenStore(),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget page,
  AuthSession session, {
  Size size = const Size(1280, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaseefApp(session: session, home: page));
  await tester.pumpAndSettle();
}

bool _obscured(WidgetTester tester, Key field) {
  final input = find.descendant(
    of: find.byKey(field),
    matching: find.byType(TextField),
  );
  return tester.widget<TextField>(input).obscureText;
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

http.Response _ok() => http.Response('{"status":"success"}', 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('password visibility', () {
    testWidgets('sign in: the eye reveals and hides the password', (
      tester,
    ) async {
      await _pump(tester, const LoginPage(), _session((_) async => _ok()));
      const field = Key('auth-password');
      expect(_obscured(tester, field), isTrue);
      await tester.tap(find.byKey(const Key('auth-password-toggle')));
      await tester.pump();
      expect(_obscured(tester, field), isFalse);
      await tester.tap(find.byKey(const Key('auth-password-toggle')));
      await tester.pump();
      expect(_obscured(tester, field), isTrue);
    });

    testWidgets('create account: the two eyes are independent', (tester) async {
      await _pump(tester, const RegisterPage(), _session((_) async => _ok()));
      const password = Key('auth-password');
      const confirm = Key('register-confirm');
      expect(_obscured(tester, password), isTrue);
      expect(_obscured(tester, confirm), isTrue);

      await _tap(tester, 'auth-password-toggle');
      await tester.pump();
      expect(_obscured(tester, password), isFalse);
      expect(_obscured(tester, confirm), isTrue);

      await _tap(tester, 'register-confirm-toggle');
      await tester.pump();
      expect(_obscured(tester, password), isFalse);
      expect(_obscured(tester, confirm), isFalse);

      await _tap(tester, 'auth-password-toggle');
      await tester.pump();
      expect(_obscured(tester, password), isTrue);
      expect(_obscured(tester, confirm), isFalse);
    });

    testWidgets('reset password: the two eyes are independent', (tester) async {
      await _pump(
        tester,
        const ResetPasswordPage(token: _token),
        _session((_) async => _ok()),
      );
      const password = Key('reset-password');
      const confirm = Key('reset-confirm');
      await tester.tap(find.byKey(const Key('reset-confirm-toggle')));
      await tester.pump();
      expect(_obscured(tester, password), isTrue);
      expect(_obscured(tester, confirm), isFalse);
      await tester.tap(find.byKey(const Key('reset-password-toggle')));
      await tester.pump();
      expect(_obscured(tester, password), isFalse);
      expect(_obscured(tester, confirm), isFalse);
      await tester.tap(find.byKey(const Key('reset-confirm-toggle')));
      await tester.pump();
      expect(_obscured(tester, password), isFalse);
      expect(_obscured(tester, confirm), isTrue);
    });

    testWidgets('every eye is at least 48 px to tap', (tester) async {
      await _pump(
        tester,
        const RegisterPage(),
        _session((_) async => _ok()),
        size: const Size(360, 800),
      );
      for (final key in ['auth-password-toggle', 'register-confirm-toggle']) {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.pump();
        final size = tester.getSize(find.byKey(Key(key)));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
    });
  });

  group('eye icon matches the real state', () {
    // A slashed eye = hidden (dots). An open eye = visible (plain text).
    void expectState(
      WidgetTester tester, {
      required Key field,
      required Key toggle,
      required bool hidden,
    }) {
      expect(_obscured(tester, field), hidden, reason: 'actual text state');
      final icon = tester.widget<Icon>(
        find.descendant(of: find.byKey(toggle), matching: find.byType(Icon)),
      );
      expect(
        icon.icon,
        hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        reason: hidden
            ? 'hidden shows the slashed eye'
            : 'visible shows the open eye',
      );
    }

    testWidgets(
      'sign in: hidden by default with the slashed eye, then toggles',
      (tester) async {
        await _pump(tester, const LoginPage(), _session((_) async => _ok()));
        const field = Key('auth-password');
        const toggle = Key('auth-password-toggle');
        expectState(tester, field: field, toggle: toggle, hidden: true);
        await tester.tap(find.byKey(toggle));
        await tester.pump();
        expectState(tester, field: field, toggle: toggle, hidden: false);
        await tester.tap(find.byKey(toggle));
        await tester.pump();
        expectState(tester, field: field, toggle: toggle, hidden: true);
      },
    );

    testWidgets('typed text is really dots when hidden and plain when shown', (
      tester,
    ) async {
      await _pump(tester, const LoginPage(), _session((_) async => _ok()));
      await _type(tester, 'auth-password', 'correct-horse');
      final editable = find.descendant(
        of: find.byKey(const Key('auth-password')),
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(editable).obscureText, isTrue);
      expect(
        tester.widget<EditableText>(editable).controller.text,
        'correct-horse',
      );
      await tester.tap(find.byKey(const Key('auth-password-toggle')));
      await tester.pump();
      expect(tester.widget<EditableText>(editable).obscureText, isFalse);
      // The value itself is never altered by toggling.
      expect(
        tester.widget<EditableText>(editable).controller.text,
        'correct-horse',
      );
    });

    testWidgets('create account: each eye follows only its own field', (
      tester,
    ) async {
      await _pump(tester, const RegisterPage(), _session((_) async => _ok()));
      const pw = Key('auth-password');
      const pwEye = Key('auth-password-toggle');
      const cf = Key('register-confirm');
      const cfEye = Key('register-confirm-toggle');
      expectState(tester, field: pw, toggle: pwEye, hidden: true);
      expectState(tester, field: cf, toggle: cfEye, hidden: true);

      await _tap(tester, 'auth-password-toggle');
      await tester.pump();
      expectState(tester, field: pw, toggle: pwEye, hidden: false);
      expectState(tester, field: cf, toggle: cfEye, hidden: true);

      await _tap(tester, 'register-confirm-toggle');
      await tester.pump();
      expectState(tester, field: pw, toggle: pwEye, hidden: false);
      expectState(tester, field: cf, toggle: cfEye, hidden: false);

      await _tap(tester, 'auth-password-toggle');
      await tester.pump();
      expectState(tester, field: pw, toggle: pwEye, hidden: true);
      expectState(tester, field: cf, toggle: cfEye, hidden: false);
    });

    testWidgets('reset password: each eye follows only its own field', (
      tester,
    ) async {
      await _pump(
        tester,
        const ResetPasswordPage(token: _token),
        _session((_) async => _ok()),
      );
      const pw = Key('reset-password');
      const pwEye = Key('reset-password-toggle');
      const cf = Key('reset-confirm');
      const cfEye = Key('reset-confirm-toggle');
      expectState(tester, field: pw, toggle: pwEye, hidden: true);
      expectState(tester, field: cf, toggle: cfEye, hidden: true);
      await tester.tap(find.byKey(cfEye));
      await tester.pump();
      expectState(tester, field: pw, toggle: pwEye, hidden: true);
      expectState(tester, field: cf, toggle: cfEye, hidden: false);
      await tester.tap(find.byKey(pwEye));
      await tester.pump();
      expectState(tester, field: pw, toggle: pwEye, hidden: false);
      expectState(tester, field: cf, toggle: cfEye, hidden: false);
      await tester.tap(find.byKey(cfEye));
      await tester.pump();
      expectState(tester, field: pw, toggle: pwEye, hidden: false);
      expectState(tester, field: cf, toggle: cfEye, hidden: true);
    });
  });

  group('guest and host note', () {
    testWidgets('is a friendly note that keeps all three facts', (
      tester,
    ) async {
      await _pump(tester, const RegisterPage(), _session((_) async => _ok()));
      expect(find.byKey(const Key('register-owner-note')), findsOneWidget);
      expect(find.text('Good to know'), findsOneWidget);
      expect(
        find.text(
          'Choosing Host doesn’t create or assign a chalet automatically.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Your chalet is linked in a separate step, after MASEEF approves it.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'For security, admin accounts can’t be created from public sign-up.',
        ),
        findsOneWidget,
      );
      // Not styled as an error: no red anywhere in the note.
      final note = find.byKey(const Key('register-owner-note'));
      for (final text in tester.widgetList<Text>(
        find.descendant(of: note, matching: find.byType(Text)),
      )) {
        expect(text.style?.color, isNot(const Color(0xFF8C2F2F)));
      }
    });

    testWidgets('reads in Arabic too', (tester) async {
      await _pump(tester, const RegisterPage(), _session((_) async => _ok()));
      await tester.tap(find.byKey(const Key('lang-ar')));
      await tester.pumpAndSettle();
      expect(find.text('معلومة مفيدة'), findsOneWidget);
      expect(find.textContaining('لا ينشئ شاليهاً'), findsOneWidget);
      expect(find.textContaining('بعد موافقة'), findsOneWidget);
      expect(find.textContaining('حسابات مدير'), findsOneWidget);
    });
  });

  group('sign in', () {
    testWidgets('required fields are flagged and nothing is sent', (
      tester,
    ) async {
      final calls = <AuthHttpRequest>[];
      await _pump(
        tester,
        const LoginPage(),
        _session((r) async {
          calls.add(r);
          return _ok();
        }),
      );
      await _tap(tester, 'auth-submit');
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(calls, isEmpty);
    });

    testWidgets('a pending request disables the button and sends once', (
      tester,
    ) async {
      final gate = Completer<http.Response>();
      var calls = 0;
      await _pump(
        tester,
        const LoginPage(),
        _session((r) {
          calls++;
          return gate.future;
        }),
      );
      await _type(tester, 'auth-email', 'lina@example.com');
      await _type(tester, 'auth-password', 'correct-horse');
      await _tap(tester, 'auth-submit');
      await tester.pump();
      expect(find.text('Signing in…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('auth-submit')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
      // Pressing Enter in the password field must not submit a second time.
      await tester.tap(find.byKey(const Key('auth-submit')));
      await tester.pump();
      expect(calls, 1);
      gate.complete(http.Response('{"status":"error","code":"x"}', 401));
      await tester.pumpAndSettle();
    });

    testWidgets('a wrong password shows a clear error and re-enables', (
      tester,
    ) async {
      await _pump(
        tester,
        const LoginPage(),
        _session((r) async {
          return http.Response(
            jsonEncode({'status': 'error', 'code': 'invalid_credentials'}),
            401,
          );
        }),
      );
      await _type(tester, 'auth-email', 'lina@example.com');
      await _type(tester, 'auth-password', 'wrong-password-value');
      await _tap(tester, 'auth-submit');
      await tester.pumpAndSettle();
      expect(find.text('The email or password is incorrect.'), findsOneWidget);
      expect(find.text('Sign in'), findsWidgets);
    });

    testWidgets('the forgot-password link opens the recovery page', (
      tester,
    ) async {
      await _pump(tester, const LoginPage(), _session((_) async => _ok()));
      await _type(tester, 'auth-email', 'lina@example.com');
      await _tap(tester, 'auth-go-forgot');
      await tester.pumpAndSettle();
      expect(find.text('Forgot your password?'), findsOneWidget);
      // The typed address carries over.
      expect(find.text('lina@example.com'), findsOneWidget);
    });
  });

  group('create account', () {
    testWidgets('mismatched passwords are flagged on the confirm field', (
      tester,
    ) async {
      var calls = 0;
      await _pump(
        tester,
        const RegisterPage(),
        _session((_) async {
          calls++;
          return _ok();
        }),
      );
      await _type(tester, 'register-name', 'Lina Guest');
      await _type(tester, 'auth-email', 'lina@example.com');
      await _type(tester, 'auth-password', 'correct-horse');
      await _type(tester, 'register-confirm', 'correct-horsf');
      await _tap(tester, 'auth-submit');
      await tester.pumpAndSettle();
      expect(find.text('The passwords do not match.'), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('both account types are offered and admin is not', (
      tester,
    ) async {
      await _pump(tester, const RegisterPage(), _session((_) async => _ok()));
      expect(find.text('Guest'), findsOneWidget);
      expect(find.text('Host'), findsOneWidget);
      expect(find.byKey(const Key('role-admin')), findsNothing);
      expect(find.text('Create your MASEEF account'), findsOneWidget);
    });
  });

  group('forgot password', () {
    testWidgets('shows the same confirmation and sends only the email', (
      tester,
    ) async {
      final bodies = <Map<String, dynamic>>[];
      await _pump(
        tester,
        const ForgotPasswordPage(),
        _session((r) async {
          expect(r.uri.path, '/api/auth/forgot-password');
          bodies.add(jsonDecode(r.body!) as Map<String, dynamic>);
          return _ok();
        }),
      );
      await _type(tester, 'auth-email', 'someone@example.com');
      await _tap(tester, 'auth-submit');
      await tester.pumpAndSettle();
      expect(bodies.single, {'email': 'someone@example.com', 'locale': 'en'});
      final first = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('forgot-success')),
          matching: find.textContaining('If an account exists'),
        ),
      );
      expect(first.data, contains('If an account exists for that email'));

      // A different, never-registered address gets the very same message.
      await tester.tap(find.byKey(const Key('forgot-another')));
      await tester.pumpAndSettle();
      await _type(tester, 'auth-email', 'nobody@example.org');
      await _tap(tester, 'auth-submit');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('forgot-success')), findsOneWidget);
      expect(find.textContaining('If an account exists'), findsOneWidget);
      expect(find.textContaining('nobody@example.org'), findsNothing);
    });

    testWidgets('an invalid email is flagged and nothing is sent', (
      tester,
    ) async {
      var calls = 0;
      await _pump(
        tester,
        const ForgotPasswordPage(),
        _session((_) async {
          calls++;
          return _ok();
        }),
      );
      await _type(tester, 'auth-email', 'not-an-email');
      await _tap(tester, 'auth-submit');
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('a server without the feature says so honestly', (
      tester,
    ) async {
      await _pump(
        tester,
        const ForgotPasswordPage(),
        _session((_) async => http.Response('Not found', 404)),
      );
      await _type(tester, 'auth-email', 'someone@example.com');
      await _tap(tester, 'auth-submit');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('forgot-success')), findsNothing);
      expect(find.byKey(const Key('auth-error')), findsOneWidget);
      expect(find.textContaining("isn't available yet"), findsOneWidget);
    });
  });

  group('reset password', () {
    testWidgets('a missing or mangled link never shows the form', (
      tester,
    ) async {
      for (final token in [null, '', 'short', 'has spaces in it 1234567890']) {
        await _pump(
          tester,
          ResetPasswordPage(token: token),
          _session((_) async => _ok()),
        );
        expect(find.byKey(const Key('reset-invalid')), findsOneWidget);
        expect(find.byKey(const Key('reset-password')), findsNothing);
      }
    });

    testWidgets('mismatched passwords are flagged and nothing is sent', (
      tester,
    ) async {
      var calls = 0;
      await _pump(
        tester,
        const ResetPasswordPage(token: _token),
        _session((_) async {
          calls++;
          return _ok();
        }),
      );
      await _type(tester, 'reset-password', 'brand-new-secret');
      await _type(tester, 'reset-confirm', 'brand-new-secreT');
      await _tap(tester, 'auth-submit');
      await tester.pumpAndSettle();
      expect(find.text('The passwords do not match.'), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('success sends the token and password, then goes to sign in', (
      tester,
    ) async {
      Map<String, dynamic>? body;
      await _pump(
        tester,
        const ResetPasswordPage(token: _token),
        _session((r) async {
          expect(r.uri.path, '/api/auth/reset-password');
          body = jsonDecode(r.body!) as Map<String, dynamic>;
          return _ok();
        }),
      );
      await _type(tester, 'reset-password', 'brand-new-secret');
      await _type(tester, 'reset-confirm', 'brand-new-secret');
      await _tap(tester, 'auth-submit');
      await tester.pumpAndSettle();
      expect(body, {'token': _token, 'password': 'brand-new-secret'});
      expect(find.byKey(const Key('reset-success')), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byKey(const Key('auth-go-register')), findsOneWidget);
    });

    testWidgets('an expired token turns into the request-a-new-link state', (
      tester,
    ) async {
      await _pump(
        tester,
        const ResetPasswordPage(token: _token),
        _session((_) async {
          return http.Response(
            jsonEncode({'status': 'error', 'code': 'invalid_token'}),
            400,
          );
        }),
      );
      await _type(tester, 'reset-password', 'brand-new-secret');
      await _type(tester, 'reset-confirm', 'brand-new-secret');
      await _tap(tester, 'auth-submit');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reset-invalid')), findsOneWidget);
      await tester.tap(find.byKey(const Key('reset-request-new')));
      await tester.pumpAndSettle();
      expect(find.text('Forgot your password?'), findsOneWidget);
    });

    testWidgets('the emailed deep link opens the reset page', (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          '/reset-password?token=$_token';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaseefApp(session: _session((_) async => _ok())));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reset-password')), findsOneWidget);
      expect(find.byKey(const Key('reset-confirm')), findsOneWidget);
    });
  });

  group('layout', () {
    final pages = <String, Widget Function()>{
      'sign in': () => const LoginPage(),
      'create account': () => const RegisterPage(),
      'forgot': () => const ForgotPasswordPage(),
      'reset': () => const ResetPasswordPage(token: _token),
    };

    for (final entry in pages.entries) {
      for (final width in const [360.0, 390.0, 768.0, 1024.0, 1440.0]) {
        for (final arabic in const [false, true]) {
          testWidgets('${entry.key} fits at ${width.toInt()} px '
              '(${arabic ? 'ar' : 'en'})', (tester) async {
            await _pump(
              tester,
              entry.value(),
              _session((_) async => _ok()),
              size: Size(width, 900),
            );
            if (arabic) {
              await tester.tap(find.byKey(const Key('lang-ar')));
              await tester.pumpAndSettle();
            }
            expect(tester.takeException(), isNull);

            final split = width >= 720;
            expect(
              find.byKey(const Key('auth-hero')),
              split ? findsOneWidget : findsNothing,
            );
            expect(
              find.byKey(const Key('auth-sheet')),
              split ? findsNothing : findsOneWidget,
            );
            expect(find.byKey(const Key('auth-hero-tagline')), findsOneWidget);

            // Nothing pokes out of the screen horizontally.
            final title = tester.getRect(find.byKey(const Key('auth-title')));
            expect(title.left, greaterThanOrEqualTo(0));
            expect(title.right, lessThanOrEqualTo(width));

            if (width >= 1000) {
              final hero = tester.getRect(find.byKey(const Key('auth-hero')));
              expect(hero.width, closeTo(width / 2, 1));
              // The hero sits on the start side: left in English, right in
              // Arabic.
              if (arabic) {
                expect(hero.right, closeTo(width, 1));
              } else {
                expect(hero.left, closeTo(0, 1));
              }
            }
            if (width >= 720 && width < 1000) {
              final hero = tester.getRect(find.byKey(const Key('auth-hero')));
              expect(hero.width, lessThan(width * 0.45));
              expect(hero.width, greaterThanOrEqualTo(280));
            }
            if (arabic) {
              expect(
                Directionality.of(
                  tester.element(find.byKey(const Key('auth-title'))),
                ),
                TextDirection.rtl,
              );
            }
          });
        }
      }
    }

    testWidgets('the photo is cropped, never stretched', (tester) async {
      await _pump(tester, const LoginPage(), _session((_) async => _ok()));
      final image = tester.widget<Image>(find.byType(Image).first);
      expect(image.fit, BoxFit.cover);
    });
  });
}
