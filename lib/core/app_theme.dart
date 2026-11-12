// lib/core/app_theme.dart
//
// ساخت ThemeData واقعی (روشن/تیره) از ThemeProvider تا دیالوگ‌ها، دیت‌پیکر، فیلدها،
// اسنک‌بار و ... هم خودکار با رنگ برنامه و حالت شب هماهنگ باشن.
// عمداً از پارامترهای cardTheme/dialogTheme/tabBarTheme استفاده نشده تا با
// نسخه‌های مختلف Flutter مشکل نخوره.

import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';

class AppTheme {
  AppTheme._();

  static const String fontFamily = 'Vazir';

  static ThemeData build(ThemeProvider t) {
    final brightness = t.brightness;
    final primary = t.effectivePrimary;
    final onPrimary = t.onPrimaryColor;

    final base = ThemeData(brightness: brightness, useMaterial3: true);

    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      onPrimary: onPrimary,
      secondary: primary,
      onSecondary: onPrimary,
      surface: t.surfaceColor,
      onSurface: t.textColor,
      error: t.errorColor,
      outline: t.borderColor,
      surfaceContainerHighest: t.cardSecondaryColor,
    );

    final textTheme = base.textTheme.apply(
      fontFamily: fontFamily,
      bodyColor: t.textColor,
      displayColor: t.textColor,
    );

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.backgroundColor,
      canvasColor: t.surfaceColor,
      cardColor: t.cardColor,
      dividerColor: t.textColor.withValues(alpha: 0.1),
      dialogBackgroundColor: t.surfaceColor,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: IconThemeData(color: t.textColor),
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) =>
            const Icon(Icons.arrow_back,),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: t.surfaceColor,
        foregroundColor: t.textColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: t.textColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: fontFamily,
        ),
        iconTheme: IconThemeData(color: t.textColor),
      ),
      listTileTheme: ListTileThemeData(
        textColor: t.textColor,
        iconColor: t.textColor,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return onPrimary;
          return t.textSecondaryColor;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return t.cardSecondaryColor;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return null;
        }),
        checkColor: WidgetStateProperty.all(onPrimary),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return t.textSecondaryColor;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withValues(alpha: 0.3),
        selectionHandleColor: primary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.isDarkMode ? t.cardSecondaryColor : t.textColor,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: t.isDarkMode ? t.textColor : t.backgroundColor,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.textColor,
          side: BorderSide(color: t.borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }
}
