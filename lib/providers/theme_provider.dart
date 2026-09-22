// lib/providers/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _primaryColorKey = 'primary_color';

  Color _primaryColor = const Color(0xFFB0CC5D);
  Color _secondaryColor = const Color(0xFF090909);
  Color _backgroundColor = const Color(0xFFF7FCEB);
  Color _surfaceColor = Colors.white;
  Color _textColor = const Color(0xFF090909);
  Color _textSecondaryColor = const Color(0xFF73786B);

  ThemeProvider() {
    _loadSavedColor();
  }

  Color get primaryColor => _primaryColor;
  Color get secondaryColor => _secondaryColor;
  Color get backgroundColor => _backgroundColor;
  Color get surfaceColor => _surfaceColor;
  Color get textColor => _textColor;
  Color get textSecondaryColor => _textSecondaryColor;

  Color primaryWithOpacity(double opacity) =>
      _primaryColor.withValues(alpha: opacity);

  Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;
    _updateDerivedColors();
    await _saveColor(color);
    notifyListeners();
  }

  void _updateDerivedColors() {
    final luminance = _primaryColor.computeLuminance();

    _secondaryColor = luminance > 0.5 ? const Color(0xFF090909) : Colors.white;

    _backgroundColor = _primaryColor.withValues(alpha: 0.08);

    _surfaceColor = luminance > 0.5 ? Colors.white : const Color(0xFF1A1A2E);

    _textColor = luminance > 0.5 ? const Color(0xFF090909) : Colors.white;

    _textSecondaryColor =
        luminance > 0.5 ? const Color(0xFF73786B) : Colors.white70;
  }

  Future<void> _saveColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_primaryColorKey, color.value);
  }

  Future<void> _loadSavedColor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final colorValue = prefs.getInt(_primaryColorKey);
      if (colorValue != null) {
        _primaryColor = Color(colorValue);
        _updateDerivedColors();
        notifyListeners();
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> resetToDefault() async {
    await setPrimaryColor(const Color(0xFFB0CC5D));
  }
}
