// lib/features/chat/widgets/weekly_performance_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../models/weekly_habit_performance.dart';
import '../utils/chat_colors.dart';
import '/providers/theme_provider.dart';
import '/providers/calendar_provider.dart';

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
    final theme = Provider.of<ThemeProvider>(context);
    final calendar = Provider.of<CalendarProvider>(context);

    // ✅ رنگ‌های استاندارد بر اساس تم روز/شب
    final Color bgColor =
        isMe ? ChatColors.myBubble(theme) : ChatColors.otherBubble(theme);
    final Color textColor = isMe
        ? ChatColors.myBubbleText(theme)
        : ChatColors.otherBubbleText(theme);
    final Color textSecondary = isMe
        ? ChatColors.myBubbleTextSecondary(theme)
        : ChatColors.otherBubbleTextSecondary(theme);

    // ✅ حروف روزهای هفته از CalendarProvider
    final weekDayLetters = calendar.weekDayHeaders;

    final successPercent = (data.successRate * 100).toInt();

    // ✅ ایندکس امروز بر اساس تقویم
    final int todayIndex = _getTodayIndex(calendar);

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // هدر
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.analytics,
                  color: textColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'عملکرد هفتگی',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      _formatWeekRange(
                        data.weekStart,
                        data.weekEnd,
                        calendar,
                      ),
                      style: TextStyle(
                        fontSize: 10,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$successPercent%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // آمار
          Row(
            children: [
              _buildMiniStat(
                'کل',
                '${data.totalHabits}',
                textColor,
                textSecondary,
              ),
              const SizedBox(width: 6),
              _buildMiniStat(
                'انجام شده',
                '${data.completedHabits}',
                textColor,
                textSecondary,
              ),
              const SizedBox(width: 6),
              _buildMiniStat(
                'موفقیت',
                '$successPercent%',
                textColor,
                textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // جدول
          if (data.habits.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: textColor.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                children: [
                  // هدر روزهای هفته
                  Row(
                    children: [
                      const SizedBox(width: 28),
                      ...List.generate(7, (index) {
                        final isToday = index == todayIndex;
                        return Expanded(
                          child: Center(
                            child: Text(
                              weekDayLetters[index],
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: isToday
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isToday ? textColor : textSecondary,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // جدول عادت‌ها
                  ...data.habits.take(6).map((habit) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: textColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getIconData(habit.iconName),
                              color: textColor,
                              size: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          ...List.generate(7, (index) {
                            final isActive = habit.weekStatus[index];
                            final isToday = index == todayIndex;
                            return Expanded(
                              child: Center(
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isActive
                                        ? textColor
                                        : (isToday
                                            ? textColor.withValues(alpha: 0.15)
                                            : Colors.transparent),
                                    border: isToday && !isActive
                                        ? Border.all(
                                            color: textColor,
                                            width: 1.5,
                                          )
                                        : null,
                                  ),
                                  child: isActive
                                      ? Icon(
                                          Icons.check,
                                          size: 10,
                                          color: bgColor,
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
        ],
      ),
    );
  }

  /// ✅ فرمت بازه هفته با CalendarProvider
  String _formatWeekRange(
    DateTime start,
    DateTime end,
    CalendarProvider calendar,
  ) {
    return '${calendar.formatShort(start)} - ${calendar.formatShort(end)}';
  }

  /// ✅ محاسبه ایندکس امروز در هفته
  /// شمسی: 0=شنبه، میلادی: 0=Monday
  int _getTodayIndex(CalendarProvider calendar) {
    if (calendar.isJalali) {
      final j = Jalali.now();
      return j.weekDay - 1; // 0=شنبه
    } else {
      final d = DateTime.now();
      return d.weekday - 1; // 0=Monday
    }
  }

  Widget _buildMiniStat(
    String label,
    String value,
    Color textColor,
    Color textSecondary,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: textColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                color: textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
}
