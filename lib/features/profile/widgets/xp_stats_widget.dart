// lib/features/profile/widgets/xp_stats_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/providers/theme_provider.dart';

class XpStatsWidget extends StatelessWidget {
  final int totalXp;
  final int level;
  final int xpToNextLevel;

  const XpStatsWidget({
    super.key,
    required this.totalXp,
    required this.level,
    required this.xpToNextLevel,
  });

  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final primaryColor = theme.primaryColor;

    final currentLevelXp = (level - 1) * 100;
    final xpInCurrentLevel = totalXp - currentLevelXp;
    final progressPercent = xpInCurrentLevel / 100;
    final int xpNeeded = 100 - xpInCurrentLevel;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, // ✅ سفید به جای primaryColor
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ عنوان وسط‌چین + بولد + مشکی
          const Center(
            child: Text(
              'سکه‌ها و سطح',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF090909),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildXpStat('کل سکه‌ها', '$totalXp', Icons.stars, primaryColor),
              _buildXpStat('لول', '$level', Icons.emoji_events, primaryColor),
              _buildXpStat('نیاز به لول بعدی', '$xpNeeded', Icons.trending_up,
                  primaryColor),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'پیشرفت به لول ${level + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF73786B),
                    ),
                  ),
                  Text(
                    '${(progressPercent * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progressPercent.clamp(0.0, 1.0),
                  backgroundColor: Colors.grey.shade200,
                  color: primaryColor,
                  minHeight: 8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$xpNeeded سکه تا لول بعدی',
              style: TextStyle(
                fontSize: 12,
                color: primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildXpStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF73786B),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
