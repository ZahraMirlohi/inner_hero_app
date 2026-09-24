// lib/features/chat/widgets/weekly_performance_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../models/weekly_habit_performance.dart';
import '/providers/theme_provider.dart';

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
    final primaryColor = theme.primaryColor;

    final weekDayLetters = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
    final successPercent = (data.successRate * 100).toInt();

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ==================== هدر ====================
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.analytics,
                  color: primaryColor,
                  size: 22,
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
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: theme.textColor,
                      ),
                    ),
                    Text(
                      _formatWeekRange(data.weekStart, data.weekEnd),
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '$successPercent%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ==================== آمار خلاصه ====================
          Row(
            children: [
              _buildMiniStat(
                label: 'کل عادت‌ها',
                value: '${data.totalHabits}',
                icon: Icons.fitness_center,
                theme: theme,
                primaryColor: primaryColor,
              ),
              const SizedBox(width: 8),
              _buildMiniStat(
                label: 'انجام شده',
                value: '${data.completedHabits}',
                icon: Icons.check_circle,
                theme: theme,
                primaryColor: primaryColor,
              ),
              const SizedBox(width: 8),
              _buildMiniStat(
                label: 'موفقیت',
                value: '$successPercent%',
                icon: Icons.trending_up,
                theme: theme,
                primaryColor: primaryColor,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ==================== جدول عادت‌ها ====================
          if (data.habits.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                children: [
                  // هدر روزهای هفته
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
                                    ? primaryColor
                                    : theme.textSecondaryColor,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // ردیف هر عادت
                  ...data.habits.take(6).map((habit) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getIconData(habit.iconName),
                              color: primaryColor,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          ...List.generate(7, (index) {
                            final isActive = habit.weekStatus[index];
                            final isToday = index == Jalali.now().weekDay - 1;

                            return Expanded(
                              child: Center(
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isActive
                                        ? primaryColor
                                        : isToday
                                            ? primaryColor.withValues(
                                                alpha: 0.15,
                                              )
                                            : Colors.transparent,
                                    border: isToday && !isActive
                                        ? Border.all(
                                            color: primaryColor,
                                            width: 1.5,
                                          )
                                        : null,
                                  ),
                                  child: isActive
                                      ? const Icon(
                                          Icons.check,
                                          size: 11,
                                          color: Colors.white,
                                        )
                                      : isToday
                                          ? Container(
                                              margin: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: primaryColor,
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

          // ==================== فوتر ====================
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                data.userName,
                style: TextStyle(
                  fontSize: 9,
                  color: theme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required String label,
    required String value,
    required IconData icon,
    required ThemeProvider theme,
    required Color primaryColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: primaryColor),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                color: theme.textSecondaryColor,
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

  String _formatWeekRange(DateTime start, DateTime end) {
    final jalaliStart = Jalali.fromDateTime(start);
    final jalaliEnd = Jalali.fromDateTime(end);
    return '${jalaliStart.day}/${jalaliStart.month} - ${jalaliEnd.day}/${jalaliEnd.month}';
  }
}
