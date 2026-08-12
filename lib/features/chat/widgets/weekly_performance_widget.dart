// lib/features/chat/widgets/weekly_performance_widget.dart

import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../models/weekly_habit_performance.dart';

class WeeklyPerformanceWidget extends StatelessWidget {
  final WeeklyHabitPerformance data;
  final bool isMe;

  const WeeklyPerformanceWidget({
    super.key,
    required this.data,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    final weekDayLetters = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
    final successPercent = (data.successRate * 100).toInt();
    final motivationalMessage = data.getMotivationalMessage();

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF4A90E2) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ==================== هدر ====================
          Row(
            children: [
              const Text('📊', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'عملکرد هفتگی عادت‌ها',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isMe ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$successPercent%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isMe ? Colors.white : const Color(0xFF4A90E2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ==================== آمار خلاصه ====================
          Row(
            children: [
              _buildMiniStat(
                label: 'کل عادت‌ها',
                value: '${data.totalHabits}',
                icon: Icons.fitness_center,
                isMe: isMe,
              ),
              const SizedBox(width: 12),
              _buildMiniStat(
                label: 'انجام شده',
                value: '${data.completedHabits}',
                icon: Icons.check_circle,
                color: Colors.green,
                isMe: isMe,
              ),
              const SizedBox(width: 12),
              _buildMiniStat(
                label: 'موفقیت',
                value: '$successPercent%',
                icon: Icons.trending_up,
                color: successPercent >= 70 ? Colors.green : Colors.orange,
                isMe: isMe,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ==================== جدول عادت‌ها ====================
          if (data.habits.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  // ✅ هدر روزهای هفته
                  Row(
                    children: [
                      const SizedBox(width: 30),
                      ...List.generate(7, (index) {
                        final isToday = index == Jalali.now().weekDay - 1;
                        return Expanded(
                          child: Center(
                            child: Text(
                              weekDayLetters[index],
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: isToday
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isToday
                                    ? (isMe
                                          ? Colors.white
                                          : const Color(0xFF4A90E2))
                                    : (isMe
                                          ? Colors.white70
                                          : Colors.grey.shade500),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // ✅ ردیف هر عادت
                  ...data.habits.take(6).map((habit) {
                    final iconColor = Color(habit.iconColor);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          // آیکون عادت
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              _getIconData(habit.iconName),
                              color: iconColor,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          // روزهای هفته
                          ...List.generate(7, (index) {
                            final isActive = habit.weekStatus[index];
                            final isToday = index == Jalali.now().weekDay - 1;

                            return Expanded(
                              child: Center(
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isActive
                                        ? (isMe
                                              ? Colors.white
                                              : const Color(0xFF4A90E2))
                                        : isToday
                                        ? (isMe
                                              ? Colors.white.withValues(
                                                  alpha: 0.2,
                                                )
                                              : Colors.grey.shade300)
                                        : Colors.transparent,
                                    border: isToday && !isActive
                                        ? Border.all(
                                            color: isMe
                                                ? Colors.white70
                                                : const Color(0xFF4A90E2),
                                            width: 1.5,
                                          )
                                        : null,
                                  ),
                                  child: isActive
                                      ? Icon(
                                          Icons.check,
                                          size: 10,
                                          color: isMe
                                              ? const Color(0xFF4A90E2)
                                              : Colors.white,
                                        )
                                      : isToday
                                      ? Container(
                                          width: 4,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: isMe
                                                ? Colors.white70
                                                : const Color(0xFF4A90E2),
                                            shape: BoxShape.circle,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // ==================== پیام انگیزشی ====================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isMe
                  ? Colors.white.withValues(alpha: 0.15)
                  : _getMotivationColor(successPercent).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _getMotivationIcon(successPercent),
                  size: 16,
                  color: isMe
                      ? Colors.white
                      : _getMotivationColor(successPercent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    motivationalMessage,
                    style: TextStyle(
                      fontSize: 12,
                      color: isMe ? Colors.white : const Color(0xFF1A1A2E),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ==================== فوتر ====================
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${data.userName} • ${_formatWeekRange(data.weekStart, data.weekEnd)}',
                style: TextStyle(
                  fontSize: 9,
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.6)
                      : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== ویجت‌های کمکی ====================

  Widget _buildMiniStat({
    required String label,
    required String value,
    required IconData icon,
    Color? color,
    required bool isMe,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: color ?? (isMe ? Colors.white70 : Colors.grey.shade600),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isMe ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                color: isMe ? Colors.white70 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== متدهای کمکی ====================

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'fitness_center':
        return Icons.fitness_center;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'book':
        return Icons.book;
      case 'science':
        return Icons.science;
      case 'restaurant':
        return Icons.restaurant;
      case 'bedtime':
        return Icons.bedtime;
      case 'water_drop':
        return Icons.water_drop;
      case 'directions_walk':
        return Icons.directions_walk;
      case 'run_circle':
        return Icons.run_circle;
      case 'emoji_events':
        return Icons.emoji_events;
      default:
        return Icons.fitness_center;
    }
  }

  Color _getMotivationColor(int percent) {
    if (percent >= 80) return Colors.green;
    if (percent >= 60) return Colors.orange;
    if (percent >= 40) return Colors.blue;
    return Colors.grey;
  }

  IconData _getMotivationIcon(int percent) {
    if (percent >= 80) return Icons.emoji_events;
    if (percent >= 60) return Icons.thumb_up;
    if (percent >= 40) return Icons.trending_up;
    return Icons.rocket;
  }

  String _formatWeekRange(DateTime start, DateTime end) {
    final jalaliStart = Jalali.fromDateTime(start);
    final jalaliEnd = Jalali.fromDateTime(end);
    return '${jalaliStart.day}/${jalaliStart.month} - ${jalaliEnd.day}/${jalaliEnd.month}';
  }
}
