// lib/features/profile/widgets/xp_stats_widget.dart
//
// سکه‌ها و سطح: سه آمار رنگی + نوار پیشرفت گرد.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/core/app_palette.dart';
import '/l10n/app_strings.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    final currentLevelXp = (level - 1) * 100;
    final xpInLevel = (totalXp - currentLevelXp).clamp(0, 100);
    final progress = xpInLevel / 100;
    final xpNeeded = 100 - xpInLevel;
    final bar = theme.tone(Tone.lime);

    Widget stat(Tone tone, IconData icon, String value, String label) {
      final c = theme.tone(tone);
      return Expanded(
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle),
              child: Icon(icon, color: c.fg, size: 23),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: theme.textColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textSecondaryColor, fontSize: 11.5),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          Text(
            context.tr('xp.title'),
            style: TextStyle(
              color: theme.textColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              stat(Tone.butter, Icons.stars_rounded, '$totalXp',
                  context.tr('xp.total')),
              stat(Tone.lilac, Icons.emoji_events_rounded, '$level',
                  context.tr('xp.level')),
              stat(Tone.sky, Icons.trending_up_rounded, '$xpNeeded',
                  context.tr('xp.needed')),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('xp.progress', {'n': '${level + 1}'}),
                style:
                    TextStyle(color: theme.textSecondaryColor, fontSize: 12),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 12,
                backgroundColor: bar.bg,
                color: theme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
