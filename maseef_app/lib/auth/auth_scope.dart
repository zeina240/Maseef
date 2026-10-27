import 'package:flutter/widgets.dart';
import 'package:maseef_app/auth/auth_session.dart';

class AuthScope extends InheritedNotifier<AuthSession> {
  const AuthScope({
    super.key,
    required AuthSession session,
    required super.child,
  }) : super(notifier: session);

  static AuthSession watch(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope was not found above this widget.');
    return scope!.notifier!;
  }

  static AuthSession? read(BuildContext context) {
    return context.getInheritedWidgetOfExactType<AuthScope>()?.notifier;
  }
}
