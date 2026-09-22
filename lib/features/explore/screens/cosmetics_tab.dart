// lib/features/explore/screens/cosmetics_tab.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/providers/theme_provider.dart';

class CosmeticsTab extends StatelessWidget {
  const CosmeticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final Color primaryColor = themeProvider.primaryColor;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_bag,
              size: 64,
              color: primaryColor.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'بازارچه آیتم‌ها',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'به زودی...',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            'با XPهای خود آیتم‌های جذاب بخرید!',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
