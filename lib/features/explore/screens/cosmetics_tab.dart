// lib/features/explore/screens/cosmetics_tab.dart
import 'package:flutter/material.dart';

class CosmeticsTab extends StatelessWidget {
  const CosmeticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag, size: 64, color: Colors.grey.shade300),
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
          Text('به زودی...', style: TextStyle(color: Colors.grey.shade500)),
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
