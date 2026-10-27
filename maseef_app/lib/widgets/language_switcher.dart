import 'package:flutter/material.dart';
import 'package:maseef_app/l10n/app_strings.dart';
import 'package:maseef_app/l10n/locale_scope.dart';
import 'package:maseef_app/theme/maseef_theme.dart';

class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = LocaleScope.of(context);
    final strings = controller.strings;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: MaseefColors.mist,
        shape: const StadiumBorder(side: BorderSide(color: MaseefColors.line)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LanguageOption(
                key: const Key('lang-en'),
                label: strings.languageShortEnglish,
                tooltip: strings.languageEnglish,
                selected: controller.language == AppLanguage.english,
                onTap: () => controller.setLanguage(AppLanguage.english),
              ),
              _LanguageOption(
                key: const Key('lang-ar'),
                label: strings.languageShortArabic,
                tooltip: strings.languageArabic,
                selected: controller.language == AppLanguage.arabic,
                onTap: () => controller.setLanguage(AppLanguage.arabic),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    super.key,
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? MaseefColors.deep : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : MaseefColors.deep,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
