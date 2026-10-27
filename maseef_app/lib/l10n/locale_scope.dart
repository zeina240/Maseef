import 'package:flutter/material.dart';
import 'package:maseef_app/l10n/app_strings.dart';

class LocaleController extends ChangeNotifier {
  AppLanguage _language = AppLanguage.english;

  AppLanguage get language => _language;

  AppStrings get strings => AppStrings.of(_language);

  TextDirection get direction =>
      _language == AppLanguage.arabic ? TextDirection.rtl : TextDirection.ltr;

  void setLanguage(AppLanguage language) {
    if (_language == language) return;
    _language = language;
    notifyListeners();
  }
}

class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({
    super.key,
    required LocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static LocaleController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    assert(scope != null, 'LocaleScope was not found above this widget.');
    return scope!.notifier!;
  }
}
