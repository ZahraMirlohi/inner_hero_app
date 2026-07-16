import 'package:flutter/material.dart';
import '../models/quest_model.dart';

class QuestCard extends StatelessWidget {
  final Quest quest;
  final bool isActive;
  final bool isCompleted;
  final VoidCallback? onTap;

  const QuestCard({
    super.key,
    required this.quest,
    this.isActive = false,
    this.isCompleted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(quest.color);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isCompleted
            ? []
            : const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
        border: isCompleted
            ? Border.all(color: Colors.green, width: 2)
            : Border.all(color: color.withAlpha(51), width: 2),
      ),
      child: Row(
        children: [
          // آیکون
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.green.withAlpha(51)
                  : color.withAlpha(51),
              borderRadius: BorderRadius.circular(20),
            ),
            child: isCompleted
                ? const Icon(Icons.emoji_events, color: Colors.amber, size: 30)
                : Icon(_getIconData(quest.icon), color: color, size: 30),
          ),
          const SizedBox(width: 16),

          // اطلاعات
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        quest.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isCompleted
                              ? Colors.green.shade700
                              : const Color(0xFF1A1A2E),
                        ),
                      ),
                    ),
                    if (isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'انجام شده',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  quest.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isCompleted
                        ? Colors.green.shade600
                        : Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // برچسب‌ها
                Wrap(
                  spacing: 8,
                  children: [
                    _buildTag(
                      icon: Icons.stars,
                      label: '+${quest.xpReward} XP',
                      color: const Color(0xFFFFA500),
                    ),
                    _buildTag(
                      icon: Icons.emoji_events,
                      label: quest.badge,
                      color: const Color(0xFF9B59B6),
                    ),
                    _buildTag(
                      icon: Icons.timer,
                      label: '${quest.targetCount} روز',
                      color: color,
                    ),
                    // ✅ نشان مدال/جام برای ماموریت‌های تکمیل شده
                    if (isCompleted)
                      _buildTag(
                        icon: Icons.emoji_events,
                        label: '🏅 ${quest.badge}',
                        color: Colors.amber,
                      ),
                  ],
                ),
              ],
            ),
          ),

          // دکمه - برای ماموریت‌های تکمیل شده نمایش داده نشه
          if (!isCompleted)
            IconButton(
              onPressed: onTap,
              icon: const Icon(Icons.chevron_right, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  // ✅ متد کمکی برای ساخت برچسب
  Widget _buildTag({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ متد تبدیل رنگ
  Color _parseColor(String colorStr) {
    try {
      if (colorStr.startsWith('#')) {
        return Color(int.parse('FF${colorStr.substring(1)}', radix: 16));
      }
      return const Color(0xFF4A90E2);
    } catch (e) {
      return const Color(0xFF4A90E2);
    }
  }

  // ✅ متد دریافت آیکون
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
      default:
        return Icons.flag;
    }
  }
}
