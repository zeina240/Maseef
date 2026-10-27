import 'package:flutter/material.dart';

/// MASEEF palette: a calm pale-water page background, rich navy and royal blues,
/// and a restrained gold used only for small accents (icons, hairlines, focus).
///
/// The older names (`deep`, `ocean`, `sky`, `mist`) are kept as aliases so the
/// sign-in and account screens pick up the same palette without code changes.
class MaseefColors {
  static const navy = Color(0xFF123A68);
  static const blue = Color(0xFF2A62A6);
  static const skyBlue = Color(0xFF9DBDE3);
  static const gold = Color(0xFFB8975A);
  static const goldSoft = Color(0xFFF3EAD3);
  static const page = Color(0xFFEEF6FA);
  static const aqua = Color(0xFFE2F0F7);
  static const ink = Color(0xFF1B2433);
  static const muted = Color(0xFF5A6575);
  static const line = Color(0xFFD3E3EC);

  static const deep = navy;
  static const ocean = blue;
  static const sky = skyBlue;
  static const mist = aqua;
}

/// Layered, low-contrast shadow shared by cards and sections.
List<BoxShadow> maseefShadow({bool raised = false}) => [
  BoxShadow(
    color: MaseefColors.navy.withValues(alpha: raised ? 0.16 : 0.06),
    blurRadius: raised ? 30 : 18,
    offset: Offset(0, raised ? 14 : 8),
  ),
  BoxShadow(
    color: MaseefColors.navy.withValues(alpha: raised ? 0.08 : 0.04),
    blurRadius: 2,
    offset: const Offset(0, 1),
  ),
];

ThemeData buildMaseefTheme() {
  const border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
    borderSide: BorderSide(color: MaseefColors.line),
  );

  const textTheme = TextTheme(
    headlineMedium: TextStyle(
      fontSize: 40,
      height: 1.15,
      fontWeight: FontWeight.w700,
      color: MaseefColors.deep,
    ),
    headlineSmall: TextStyle(
      fontSize: 28,
      height: 1.2,
      fontWeight: FontWeight.w700,
      color: MaseefColors.ink,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: MaseefColors.deep,
    ),
    titleMedium: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: MaseefColors.ink,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.6, color: MaseefColors.muted),
    bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: MaseefColors.muted),
  );

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: MaseefColors.page,
    fontFamily: 'Tajawal',
    fontFamilyFallback: const ['Segoe UI', 'Tahoma', 'Arial'],
    colorScheme: ColorScheme.fromSeed(
      seedColor: MaseefColors.deep,
      primary: MaseefColors.deep,
      onPrimary: Colors.white,
      secondary: MaseefColors.blue,
      tertiary: MaseefColors.gold,
      surface: Colors.white,
    ),
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: MaseefColors.page,
      foregroundColor: MaseefColors.deep,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: MaseefColors.page,
      centerTitle: false,
      titleTextStyle: textTheme.titleMedium?.copyWith(color: MaseefColors.deep),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: MaseefColors.deep,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: MaseefColors.deep,
      selectionColor: MaseefColors.sky.withValues(alpha: 0.28),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: MaseefColors.deep,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'],
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: MaseefColors.deep,
        textStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontFamilyFallback: ['Segoe UI', 'Tahoma', 'Arial'],
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: TextStyle(color: MaseefColors.muted, fontSize: 15),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: MaseefColors.deep, width: 1.6),
      ),
    ),
  );
}
