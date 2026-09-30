// lib/features/chat/utils/chat_colors.dart

import 'package:flutter/material.dart';
import '/providers/theme_provider.dart';

class ChatColors {
  /// ✅ پس‌زمینه پیام/ویجت من
  /// - روز → primaryLight (#D4E5A8)
  /// - شب → primaryColor (#B0CC5D)
  static Color myBubble(ThemeProvider theme) {
    return theme.isDarkMode ? theme.primaryColor : theme.primaryLight;
  }

  /// ✅ پس‌زمینه پیام/ویجت مقابل
  /// - روز → سفید
  /// - شب → مشکی (#1E1E1E)
  static Color otherBubble(ThemeProvider theme) {
    return theme.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  }

  static Color myBubbleText(ThemeProvider theme) {
    return const Color(0xFF090909);
  }

  static Color otherBubbleText(ThemeProvider theme) {
    return theme.textColor;
  }

  static Color myBubbleTextSecondary(ThemeProvider theme) {
    return const Color(0xFF090909).withValues(alpha: 0.7);
  }

  static Color otherBubbleTextSecondary(ThemeProvider theme) {
    return theme.textSecondaryColor;
  }
}
