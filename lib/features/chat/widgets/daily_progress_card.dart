// lib/features/chat/widgets/daily_progress_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '/providers/theme_provider.dart';

class DailyProgressCard extends StatelessWidget {
  final int currentStreak;
  final int completedHabitsToday;
  final int totalHabitsToday;
  final List<bool> weekDays;

  const DailyProgressCard({
    super.key,
    required this.currentStreak,
    required this.completedHabitsToday,
    required this.totalHabitsToday,
    required this.weekDays,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final primaryColor = theme.primaryColor;

    final double progress =
        totalHabitsToday > 0 ? completedHabitsToday / totalHabitsToday : 0.0;
    final int progressPercent = (progress * 100).toInt();

    final weekDaysLabels = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
    final todayIndex = Jalali.now().weekDay - 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ============== هدر ==============
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'پیشرفت روزانه',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: theme.textColor,
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    size: 16,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$currentStreak روز پیاپی',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ============== نوار پیشرفت هفتگی ==============
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final isActive = weekDays[index];
              final isToday = index == todayIndex;

              return Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? primaryColor
                          : isToday
                              ? primaryColor.withValues(alpha: 0.15)
                              : Colors.grey.shade100,
                      border: isToday && !isActive
                          ? Border.all(color: primaryColor, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: isActive
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : isToday
                              ? Icon(
                                  Icons.circle,
                                  size: 6,
                                  color: primaryColor,
                                )
                              : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    weekDaysLabels[index],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
                      color: isActive ? primaryColor : theme.textSecondaryColor,
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 20),

          // ============== آمار امروز ==============
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'عادت‌های امروز',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.textColor,
                    ),
                  ),
                  Text(
                    '$completedHabitsToday از $totalHabitsToday',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.shade200,
                  color: primaryColor,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  progressPercent >= 80
                      ? '🔥 عالی!'
                      : progressPercent >= 50
                          ? '💪 ادامه بده!'
                          : '🌱 تازه شروع کردی!',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textSecondaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
