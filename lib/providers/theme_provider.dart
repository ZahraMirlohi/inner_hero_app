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

  ThemeProvider() {
    _loadSavedValues();
  }

  // ==================== Getterها ====================
  Color get primaryColor => _primaryColor;
  Color get primaryDark => _primaryDark; // ✅ جدید
  Color get primaryLight => _primaryLight; // ✅ جدید
  Color get secondaryColor => _secondaryColor;
  Color get backgroundColor => _backgroundColor;
  Color get surfaceColor => _surfaceColor;
  Color get textColor => _textColor;
  Color get textSecondaryColor => _textSecondaryColor;
  bool get isDarkMode => _isDarkMode;

  Color primaryWithOpacity(double opacity) =>
      _primaryColor.withValues(alpha: opacity);

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

  /// ✅ محاسبه رنگ‌های مشتق‌شده از primaryColor
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

    // ─── رنگ‌های پایه بر اساس Dark/Light Mode ───
    if (_isDarkMode) {
      _backgroundColor = const Color(0xFF121212);
      _surfaceColor = const Color(0xFF1E1E1E);
      _textColor = Colors.white;
      _textSecondaryColor = Colors.white70;
      _secondaryColor = Colors.white;
    } else {
      _backgroundColor = const Color(0xFFF7FCEB);
      _surfaceColor = Colors.white;
      _textColor = const Color(0xFF090909);
      _textSecondaryColor = const Color(0xFF73786B);
      _secondaryColor = const Color(0xFF090909);
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
