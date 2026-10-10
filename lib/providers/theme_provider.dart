// lib/providers/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _primaryColorKey = 'primary_color';
  static const String _isDarkModeKey = 'is_dark_mode';

  Color _primaryColor = const Color(0xFFB0CC5D);
  bool _isDarkMode = false;

  // ✅ رنگ‌های مشتق‌شده
  Color _primaryDark = const Color.fromARGB(255, 113, 143, 48);
  Color _primaryLight = const Color(0xFFD4E5A8);

  // ✅ رنگ‌های پایه
  Color _backgroundColor = const Color(0xFFF7FCEB);
  Color _surfaceColor = Colors.white;
  Color _textColor = const Color(0xFF090909);
  Color _textSecondaryColor = const Color(0xFF73786B);
  Color _secondaryColor = const Color(0xFF090909);

  // ✅ رنگ‌های کارت و باکس‌ها
  Color _cardColor = Colors.white;
  Color _cardSecondaryColor = const Color(0xFFF5F5F5);
  Color _borderColor = const Color(0xFFE8EDF2);
  Color _chipBackground = const Color(0xFFFFFFFF);
  Color _iconButtonBackground = const Color(0xFFF5F5F5);
  Color _overlayBackground = const Color(0xFFFFFFFF);

  // ✅ رنگ دکمه انجام (تیک)
  Color _checkButtonBackground = const Color(0xFF090909);
  Color _onCheckButton = Colors.white;

  ThemeProvider() {
    _loadSavedValues();
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
  bool get isDarkMode => _isDarkMode;

  // ✅ Getterهای جدید برای کارت‌ها و باکس‌ها
  Color get cardColor => _cardColor;
  Color get cardSecondaryColor => _cardSecondaryColor;
  Color get borderColor => _borderColor;
  Color get chipBackground => _chipBackground;
  Color get iconButtonBackground => _iconButtonBackground;
  Color get overlayBackground => _overlayBackground;
  Color get checkButtonBackground => _checkButtonBackground;
  Color get onCheckButton => _onCheckButton;
  Color get accentGold => const Color(0xFFFFA500);
  Color get accentGoldLight => _isDarkMode
      ? const Color(0xFFFFA500).withValues(alpha: 0.2)
      : const Color(0xFFFFA500).withValues(alpha: 0.1);
  Color get successColor => const Color.fromARGB(255, 61, 207, 159);
  Color get successBg =>
      _isDarkMode ? const Color(0xFF1B4332) : const Color(0xFFF0FDF4);
  Color get errorColor => const Color.fromARGB(255, 239, 88, 68);
  Color get errorBg =>
      _isDarkMode ? const Color(0xFF4A1C1C) : const Color(0xFFFEF2F2);
  Color get inputBackground =>
      _isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade50;

  Color get systemBubble =>
      _isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade200;

  Color get disabledButtonBackground =>
      _isDarkMode ? const Color(0xFF3A3A3A) : Colors.grey.shade300;

  Color get neutralChipBackground =>
      _isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade100;

  // ✅ رنگ‌های نیمه‌شفاف
  Color primaryWithOpacity(double opacity) =>
      _primaryColor.withValues(alpha: opacity);
  Color textWithOpacity(double opacity) =>
      _textColor.withValues(alpha: opacity);
  Color cardWithOpacity(double opacity) =>
      _cardColor.withValues(alpha: opacity);

  // ==================== متدها ====================
  Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;
    _updateDerivedColors();
    await _saveColor(color);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    _updateDerivedColors();
    await _saveDarkMode(value);
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    await setDarkMode(!_isDarkMode);
  }

  /// ✅ محاسبه رنگ‌های مشتق‌شده از primaryColor و حالت تم
  void _updateDerivedColors() {
    // ─── تولید توناژ تیره‌تر ───
    final hsl = HSLColor.fromColor(_primaryColor);

    _primaryDark = hsl
        .withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation + 0.05).clamp(0.0, 1.0))
        .toColor();

    // ─── تولید توناژ روشن‌تر ───
    _primaryLight = hsl
        .withLightness((hsl.lightness + 0.25).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation - 0.1).clamp(0.0, 1.0))
        .toColor();

    if (_isDarkMode) {
      // ✅ تم شب
      _backgroundColor = const Color(0xFF121212);
      _surfaceColor = const Color(0xFF1E1E1E);
      _textColor = Colors.white;
      _textSecondaryColor = Colors.white70;
      _secondaryColor = Colors.white;

      _cardColor = const Color(0xFF1E1E1E);
      _cardSecondaryColor = const Color(0xFF2A2A2A);
      _borderColor = const Color(0xFF333333);
      _chipBackground = const Color(0xFF2A2A2A);
      _iconButtonBackground = const Color(0xFF2A2A2A);
      _overlayBackground = const Color(0xFF1E1E1E);

      _checkButtonBackground = _primaryColor;
      _onCheckButton = const Color(0xFF090909);
    } else {
      // ✅ تم روز — رنگ‌ها بر اساس primaryColor محاسبه می‌شوند

      // پس‌زمینه: یک توناژ خیلی روشن از رنگ اصلی
      // (اشباع کم، روشنایی بالا)
      final bgHsl = HSLColor.fromColor(_primaryColor);
      _backgroundColor = bgHsl
          .withSaturation((bgHsl.saturation * 0.35).clamp(0.0, 1.0))
          .withLightness(0.97)
          .toColor();

      // سطح (کارت‌ها): یک توناژ روشن‌تر از پس‌زمینه
      _surfaceColor = bgHsl
          .withSaturation((bgHsl.saturation * 0.15).clamp(0.0, 1.0))
          .withLightness(0.99)
          .toColor();

      // ─── رنگ متن ───
      _textColor = const Color(0xFF090909);
      _textSecondaryColor = const Color(0xFF73786B);
      _secondaryColor = const Color(0xFF090909);

      // ─── کارت‌ها و باکس‌ها ───
      _cardColor = _surfaceColor;
      _cardSecondaryColor = bgHsl
          .withSaturation((bgHsl.saturation * 0.2).clamp(0.0, 1.0))
          .withLightness(0.96)
          .toColor();
      _borderColor = bgHsl
          .withSaturation((bgHsl.saturation * 0.25).clamp(0.0, 1.0))
          .withLightness(0.92)
          .toColor();
      _chipBackground = _surfaceColor;
      _iconButtonBackground = _cardSecondaryColor;
      _overlayBackground = _surfaceColor;

      // ─── دکمه انجام ───
      _checkButtonBackground = const Color(0xFF090909);
      _onCheckButton = Colors.white;
    }
  }

  Future<void> _saveColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_primaryColorKey, color.value);
  }

  Future<void> _saveDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isDarkModeKey, value);
  }

  Future<void> _loadSavedValues() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final colorValue = prefs.getInt(_primaryColorKey);
      final darkModeValue = prefs.getBool(_isDarkModeKey);

      if (colorValue != null) {
        _primaryColor = Color(colorValue);
      }
      if (darkModeValue != null) {
        _isDarkMode = darkModeValue;
      }
      _updateDerivedColors();
      notifyListeners();
    } catch (e) {
      // ignore
    }
  }

  Future<void> resetToDefault() async {
    await setPrimaryColor(const Color(0xFFB0CC5D));
    await setDarkMode(false);
  }
}
