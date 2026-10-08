// lib/features/profile/widgets/hero_stats.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/character_model.dart';
import '/providers/theme_provider.dart';

class HeroStats extends StatelessWidget {
  final Character character;

  const HeroStats({super.key, required this.character});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final primaryColor = theme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.isDarkMode ? 0.3 : 0.05,
            ),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'آمار قهرمان',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.cake,
                  label: 'سن قهرمان',
                  value: '${character.characterAge} روز',
                  color: primaryColor,
                  theme: theme, // ✅
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.stars,
                  label: 'لول',
                  value: '${character.level}',
                  color: primaryColor,
                  theme: theme, // ✅
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.local_fire_department,
                  label: 'استریک جاری',
                  value: '${character.streak} روز',
                  color: primaryColor,
                  theme: theme, // ✅
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.emoji_events,
                  label: 'مدال‌ها',
                  value: '${character.badges}',
                  color: primaryColor,
                  theme: theme, // ✅
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildXpBar(primaryColor, theme), // ✅
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required ThemeProvider theme, // ✅
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: theme.textSecondaryColor, // ✅
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildXpBar(Color primaryColor, ThemeProvider theme) {
    final progress = character.levelProgress;
    final xpNeeded = character.level * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'پیشرفت به لول بعدی',
              style: TextStyle(
                fontSize: 12,
                color: theme.textSecondaryColor, // ✅
              ),
            ),
            Text(
              '${character.xp} / $xpNeeded XP',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.textColor, // ✅
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: theme.isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.shade200, // ✅
            color: primaryColor,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
