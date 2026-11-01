// lib/providers/theme_provider.dart
//
// تم کل برنامه: همهٔ رنگ‌ها (پس‌زمینه، کارت، متن، حاشیه، دکمه‌ها و ...) از «رنگ اصلی» که
// کاربر انتخاب می‌کنه ساخته می‌شن، هم در حالت روز و هم در حالت شب.
// حالت نمایش: مثل گوشی / روز / شب.
//
// تمام getterهای قبلی دست‌نخورده موندن، پس ویجت‌های فعلی بدون تغییر کار می‌کنن.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_palette.dart';

enum AppThemeMode { system, light, dark }

class ThemeProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const String _primaryColorKey = 'primary_color';
  static const String _isDarkModeKey = 'is_dark_mode'; // قدیمی؛ فقط برای مهاجرت
  static const String _themeModeKey = 'theme_mode_v2';
  static const Color defaultPrimary = Color(0xFFB0CC5D);

  Color _primaryColor = defaultPrimary;
  AppThemeMode _mode = AppThemeMode.light;
  bool _dark = false;

  // رنگ‌های مشتق‌شده
  Color _primaryDark = const Color.fromARGB(255, 113, 143, 48);
  Color _primaryLight = const Color(0xFFD4E5A8);
  Color _backgroundColor = const Color(0xFFF7FCEB);
  Color _surfaceColor = Colors.white;
  Color _textColor = const Color(0xFF090909);
  Color _textSecondaryColor = const Color(0xFF73786B);
  Color _secondaryColor = const Color(0xFF090909);
  Color _cardColor = Colors.white;
  Color _cardSecondaryColor = const Color(0xFFF5F5F5);
  Color _borderColor = const Color(0xFFE8EDF2);
  Color _chipBackground = const Color(0xFFFFFFFF);
  Color _iconButtonBackground = const Color(0xFFF5F5F5);
  Color _overlayBackground = const Color(0xFFFFFFFF);
  Color _checkButtonBackground = const Color(0xFF090909);
  Color _onCheckButton = Colors.white;
  Color _inputBackground = const Color(0xFFFAFAFA);
  Color _neutralChip = const Color(0xFFF5F5F5);
  Color _systemBubble = const Color(0xFFEEEEEE);
  Color _disabledButton = const Color(0xFFE0E0E0);

  /// سازندهٔ قدیمی: مقدارها را ناهمزمان می‌خواند.
  ThemeProvider() {
    _init();
    _loadSavedValues();
  }

  ThemeProvider._preloaded(this._primaryColor, this._mode) {
    _init();
  }

  /// قبل از runApp صدا بزنید تا اولین فریم با رنگ درست رسم شود (بدون پرش رنگ).
  static Future<ThemeProvider> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final colorValue = prefs.getInt(_primaryColorKey);
      AppThemeMode mode;
      final stored = prefs.getString(_themeModeKey);
      if (stored != null) {
        mode = AppThemeMode.values.firstWhere(
          (m) => m.name == stored,
          orElse: () => AppThemeMode.light,
        );
      } else {
        // مهاجرت از کلید قدیمی
        mode = (prefs.getBool(_isDarkModeKey) ?? false)
            ? AppThemeMode.dark
            : AppThemeMode.light;
      }
      return ThemeProvider._preloaded(
        colorValue != null ? Color(colorValue) : defaultPrimary,
        mode,
      );
    } catch (_) {
      return ThemeProvider._preloaded(defaultPrimary, AppThemeMode.light);
    }
  }

  void _init() {
    WidgetsBinding.instance.addObserver(this);
    _recompute();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (_mode == AppThemeMode.system) {
      _recompute();
      notifyListeners();
    }
  }

  // ==================== Getterها ====================
  Color get primaryColor => _primaryColor;
  Color get primaryDark => _primaryDark;
  Color get primaryLight => _primaryLight;
  Color get secondaryColor => _secondaryColor;
  Color get backgroundColor => _backgroundColor;
  Color get surfaceColor => _surfaceColor;
  Color get textColor => _textColor;
  Color get textSecondaryColor => _textSecondaryColor;
  bool get isDarkMode => _dark;
  AppThemeMode get themeMode => _mode;
  Brightness get brightness => _dark ? Brightness.dark : Brightness.light;

  Color get cardColor => _cardColor;
  Color get cardSecondaryColor => _cardSecondaryColor;
  Color get borderColor => _borderColor;
  Color get chipBackground => _chipBackground;
  Color get iconButtonBackground => _iconButtonBackground;
  Color get overlayBackground => _overlayBackground;
  Color get checkButtonBackground => _checkButtonBackground;
  Color get onCheckButton => _onCheckButton;

  /// رنگ متن/آیکون روی پس‌زمینهٔ رنگ اصلی (برای خوانا موندن با هر رنگی)
  Color get onPrimaryColor => _onColor(_primaryColor);

  Color get accentGold => const Color(0xFFFFA500);
  Color get accentGoldLight => _dark
      ? const Color(0xFFFFA500).withValues(alpha: 0.2)
      : const Color(0xFFFFA500).withValues(alpha: 0.1);
  Color get successColor => const Color.fromARGB(255, 61, 207, 159);
  Color get successBg =>
      _dark ? const Color(0xFF1B4332) : const Color(0xFFF0FDF4);
  Color get errorColor => const Color.fromARGB(255, 239, 88, 68);
  Color get errorBg =>
      _dark ? const Color(0xFF4A1C1C) : const Color(0xFFFEF2F2);
  Color get inputBackground => _inputBackground;
  Color get systemBubble => _systemBubble;
  Color get disabledButtonBackground => _disabledButton;
  Color get neutralChipBackground => _neutralChip;

  /// نسخهٔ ملایم رنگ اصلی (برای دایره‌ها و پس‌زمینهٔ آیکون‌ها، مثل طراحی‌ها)
  Color get primarySoft => _dark
      ? _effectivePrimary.withValues(alpha: 0.22)
      : Color.lerp(_effectivePrimary, Colors.white, 0.7)!;

  /// سایهٔ نرم کارت‌ها (طراحی: بدون حاشیه، فقط سایه)
  List<BoxShadow> get softShadow => _dark
      ? const []
      : [
          BoxShadow(
              color: const Color(0xFF090909).withValues(alpha: 0.04),
              blurRadius: 2,
              offset: const Offset(0, 1)),
          BoxShadow(
              color: const Color(0xFF3C500A).withValues(alpha: 0.07),
              blurRadius: 20,
              offset: const Offset(0, 6)),
        ];

  /// تن‌های پاستلی ثابت برنامه (برای آیکون‌ها و کارت‌های رنگارنگ)
  ToneColors tone(Tone t) => AppPalette.of(t, dark: _dark);

  Color primaryWithOpacity(double opacity) =>
      _primaryColor.withValues(alpha: opacity);
  Color textWithOpacity(double opacity) =>
      _textColor.withValues(alpha: opacity);
  Color cardWithOpacity(double opacity) =>
      _cardColor.withValues(alpha: opacity);

  // ==================== متدها ====================
  Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;
    _recompute();
    notifyListeners(); // اول UI، بعد دیسک
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_primaryColorKey, color.value);
    } catch (_) {}
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _mode = mode;
    _recompute();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode.name);
      await prefs.setBool(_isDarkModeKey, _dark);
    } catch (_) {}
  }

  Future<void> setDarkMode(bool value) =>
      setThemeMode(value ? AppThemeMode.dark : AppThemeMode.light);

  Future<void> toggleDarkMode() => setDarkMode(!_dark);

  Future<void> resetToDefault() async {
    await setPrimaryColor(defaultPrimary);
    await setThemeMode(AppThemeMode.light);
  }

  // ==================== محاسبهٔ رنگ‌ها ====================
  Color _onColor(Color c) =>
      c.computeLuminance() > 0.45 ? const Color(0xFF090909) : Colors.white;

  void _recompute() {
    final platformDark =
        ui.PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    _dark = _mode == AppThemeMode.dark ||
        (_mode == AppThemeMode.system && platformDark);

    var primary = _primaryColor;
    final hsl = HSLColor.fromColor(primary);

    // در حالت شب، رنگ‌های خیلی تیره باید روشن‌تر دیده بشن
    if (_dark && primary.computeLuminance() < 0.18) {
      primary = hsl.withLightness(0.6).toColor();
    }
    final phsl = HSLColor.fromColor(primary);

    _primaryDark = phsl
        .withLightness((phsl.lightness - 0.15).clamp(0.0, 1.0))
        .withSaturation((phsl.saturation + 0.05).clamp(0.0, 1.0))
        .toColor();
    _primaryLight = phsl
        .withLightness((phsl.lightness + 0.25).clamp(0.0, 1.0))
        .withSaturation((phsl.saturation - 0.1).clamp(0.0, 1.0))
        .toColor();

    final h = hsl.hue;
    HSLColor tone(double s, double l) => HSLColor.fromAHSL(1, h, s, l);

    if (_dark) {
      _backgroundColor = tone(0.14, 0.07).toColor();
      _surfaceColor = tone(0.13, 0.10).toColor();
      _cardColor = _surfaceColor;
      _cardSecondaryColor = tone(0.12, 0.14).toColor();
      _borderColor = tone(0.12, 0.20).toColor();
      _chipBackground = _cardSecondaryColor;
      _iconButtonBackground = _cardSecondaryColor;
      _overlayBackground = _surfaceColor;
      _textColor = tone(0.10, 0.95).toColor();
      _textSecondaryColor = tone(0.08, 0.70).toColor();
      _secondaryColor = _textColor;
      _inputBackground = _cardSecondaryColor;
      _systemBubble = _cardSecondaryColor;
      _neutralChip = _cardSecondaryColor;
      _disabledButton = tone(0.08, 0.22).toColor();
      _checkButtonBackground = primary;
      _onCheckButton = _onColor(primary);
    } else {
      _backgroundColor = hsl
          .withSaturation((hsl.saturation * 0.35).clamp(0.0, 1.0))
          .withLightness(0.97)
          .toColor();
      _surfaceColor = hsl
          .withSaturation((hsl.saturation * 0.15).clamp(0.0, 1.0))
          .withLightness(0.99)
          .toColor();
      _textColor = const Color(0xFF090909);
      _textSecondaryColor = const Color(0xFF73786B);
      _secondaryColor = const Color(0xFF090909);
      _cardColor = _surfaceColor;
      _cardSecondaryColor = hsl
          .withSaturation((hsl.saturation * 0.2).clamp(0.0, 1.0))
          .withLightness(0.96)
          .toColor();
      _borderColor = hsl
          .withSaturation((hsl.saturation * 0.25).clamp(0.0, 1.0))
          .withLightness(0.92)
          .toColor();
      _chipBackground = _surfaceColor;
      _iconButtonBackground = _cardSecondaryColor;
      _overlayBackground = _surfaceColor;
      _inputBackground = Colors.grey.shade50;
      _systemBubble = Colors.grey.shade200;
      _neutralChip = Colors.grey.shade100;
      _disabledButton = Colors.grey.shade300;
      _checkButtonBackground = const Color(0xFF090909);
      _onCheckButton = Colors.white;
    }
    _effectivePrimary = primary;
  }

  Color _effectivePrimary = defaultPrimary;

  /// رنگ اصلی بعد از اصلاح برای حالت شب (برای ساخت ThemeData)
  Color get effectivePrimary => _effectivePrimary;

  Future<void> _loadSavedValues() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final colorValue = prefs.getInt(_primaryColorKey);
      final stored = prefs.getString(_themeModeKey);
      if (colorValue != null) _primaryColor = Color(colorValue);
      if (stored != null) {
        _mode = AppThemeMode.values.firstWhere(
          (m) => m.name == stored,
          orElse: () => AppThemeMode.light,
        );
      } else if (prefs.getBool(_isDarkModeKey) == true) {
        _mode = AppThemeMode.dark;
      }
      _recompute();
      notifyListeners();
    } catch (_) {}
  }
}
