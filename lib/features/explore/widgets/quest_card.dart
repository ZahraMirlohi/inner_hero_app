// lib/features/explore/widgets/quest_card.dart

import '/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/quest_model.dart';
import '/providers/theme_provider.dart';
import '/core/app_palette.dart';
import 'card_image.dart';

class QuestCard extends StatelessWidget {
  final Quest quest;
  final bool isActive;
  final bool isCompleted;
  final int? progress;
  final VoidCallback? onTap;
  final VoidCallback? onStart;
  final VoidCallback? onCancel;
  final Color primaryColor;

  const QuestCard({
    super.key,
    required this.quest,
    this.isActive = false,
    this.isCompleted = false,
    this.progress,
    this.onTap,
    this.onStart,
    this.onCancel,
    required this.primaryColor,
  });

  static const _ink = Color(0xFF090909);

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final Color bg = isCompleted
        ? theme.tone(Tone.mint).bg
        : isActive
            ? theme.effectivePrimary
            : theme.cardColor;
    final Color textOn = isActive ? theme.onPrimaryColor : _ink;
    final Color body = isActive ? theme.onPrimaryColor : const Color(0xFF3C4034);
    final chipBg = isActive ? Colors.white.withValues(alpha: 0.6) : const Color(0x0F090909);
    final p = (progress ?? 0).clamp(0, quest.targetCount);
    final ratio = quest.targetCount > 0 ? p / quest.targetCount : 0.0;

    // ماموریت انجام‌شده: فقط عنوان، XP و نشان تکمیل
    if (isCompleted) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              if (CardImage.has(quest.imageUrl))
                CardImage(
                  url: quest.imageUrl,
                  width: 52,
                  height: 52,
                  borderRadius: BorderRadius.circular(16),
                )
              else
                Container(
                  width: 40,
                  height: 40,
                  decoration:
                      const BoxDecoration(color: _ink, shape: BoxShape.circle),
                  child: Icon(_getIconData(quest.icon),
                      size: 20, color: theme.effectivePrimary),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(quest.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800, color: _ink)),
              ),
              const SizedBox(width: 8),
              _chip('+${quest.xpReward} XP', Icons.star_rounded, chipBg,
                  bold: true),
              const SizedBox(width: 6),
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF2ECC71), size: 24),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(28),
          boxShadow: (!isActive && !isCompleted) ? theme.softShadow : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _withImage(
              context,
              quest.imageUrl,
              Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                            color: _ink, shape: BoxShape.circle),
                        child: Icon(_getIconData(quest.icon),
                            size: 24, color: theme.effectivePrimary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(quest.title,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isActive || isCompleted
                                    ? textOn
                                    : theme.textColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(quest.description,
                      style: TextStyle(fontSize: 13, height: 1.8, color: body)),
                  if (isActive) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio.toDouble(),
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.6),
                        valueColor: const AlwaysStoppedAnimation(_ink),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(context.tr('ex.quest.progress', {'n': '$p', 'm': '${quest.targetCount}'}),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textOn)),
                        Text('${(ratio * 100).round()}٪',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: textOn)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _chip(context.tr('ex.days_n', {'n': '${quest.targetCount}'}),
                          Icons.calendar_today_rounded, chipBg),
                      _chip('+${quest.xpReward} XP', Icons.star_rounded, chipBg,
                          bold: true),
                      if (isCompleted && quest.badge.isNotEmpty)
                        _chip(quest.badge, null,
                            Colors.white.withValues(alpha: 0.75)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (isCompleted)
                        _pill(context.tr('ex.quest.done'), Icons.check_circle_rounded,
                            const Color(0xFF2ECC71), _ink, null)
                      else if (isActive) ...[
                        _pill(context.tr('ex.view'), Icons.visibility_outlined, _ink,
                            Colors.white, onTap),
                        if (onCancel != null)
                          _pill(context.tr('ex.quest.cancel'), Icons.close_rounded, Colors.white, _ink,
                              onCancel),
                      ] else if (quest.isActive)
                        _pill(context.tr('ex.quest.start'), Icons.play_arrow_rounded,
                            theme.effectivePrimary, theme.onPrimaryColor, onStart)
                      else
                        _pill(context.tr('ex.inactive'), Icons.block_rounded,
                            const Color(0xFFCFD3C4), const Color(0xFF555B4B), null),
                    ],
                  ),
                ],
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }

  // تصویر در سمت چپ کارت و تمام ارتفاع آن؛ اطلاعات سمت راست (کراپ کناره‌ها اشکال ندارد)
  Widget _withImage(BuildContext context, String? url, Widget info) {
    if (!CardImage.has(url)) return info;
    final dir = Directionality.of(context);
    return IntrinsicHeight(
      child: Row(
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 118,
            child: Image.network(
              url!.trim(),
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => const SizedBox.shrink(),
            ),
          ),
          Expanded(child: Directionality(textDirection: dir, child: info)),
        ],
      ),
    );
  }

  Widget _chip(String text, IconData? icon, Color bg, {bool bold = false}) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: _ink),
            const SizedBox(width: 4),
          ],
          Text(text,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                  color: _ink)),
        ],
      ),
    );
  }

  Widget _pill(
      String label, IconData icon, Color bg, Color fg, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
          ],
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'fitness_center':
        return Icons.fitness_center;
      case 'book':
        return Icons.book;
      case 'wb_sunny':
        return Icons.wb_sunny;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'water_drop':
        return Icons.water_drop;
      case 'no_food':
        return Icons.no_food;
      case 'language':
        return Icons.language;
      case 'directions_walk':
        return Icons.directions_walk;
      case 'whatshot':
        return Icons.whatshot;
      case 'flag':
        return Icons.flag;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'sports_martial_arts':
        return Icons.sports_martial_arts;
      case 'school':
        return Icons.school;
      case 'psychology':
        return Icons.psychology;
      case 'favorite':
        return Icons.favorite;
      case 'star':
        return Icons.star;
      default:
        return Icons.flag;
    }
  }
}
