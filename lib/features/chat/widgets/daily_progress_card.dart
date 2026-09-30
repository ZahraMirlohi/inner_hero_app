// lib/features/chat/widgets/daily_progress_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../utils/chat_colors.dart';
import '/providers/theme_provider.dart';

class DailyProgressCard extends StatelessWidget {
  final int currentStreak;
  final int completedHabitsToday;
  final int totalHabitsToday;
  final List<bool> weekDays;
  final bool isMe; // ✅ اضافه شد

  const DailyProgressCard({
    super.key,
    required this.currentStreak,
    required this.completedHabitsToday,
    required this.totalHabitsToday,
    required this.weekDays,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    // ✅ رنگ‌های استاندارد
    final Color bgColor =
        isMe ? ChatColors.myBubble(theme) : ChatColors.otherBubble(theme);
    final Color textColor = isMe
        ? ChatColors.myBubbleText(theme)
        : ChatColors.otherBubbleText(theme);
    final Color textSecondary = isMe
        ? ChatColors.myBubbleTextSecondary(theme)
        : ChatColors.otherBubbleTextSecondary(theme);

    final double progress =
        totalHabitsToday > 0 ? completedHabitsToday / totalHabitsToday : 0.0;
    final int progressPercent = (progress * 100).toInt();

    final weekDaysLabels = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
    final todayIndex = Jalali.now().weekDay - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            bgColor, // ✅ پس‌زمینه: primaryLight یا primaryColor یا سفید یا مشکی
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
        children: [
          // هدر
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'پیشرفت روزانه',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor, // ✅ متن تیره روی پس‌زمینه روشن
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    size: 16,
                    color: textColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$currentStreak روز پیاپی',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // روزهای هفته
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final isActive = weekDays[index];
              final isToday = index == todayIndex;

              return Column(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? textColor.withValues(alpha: 0.15)
                          : Colors.transparent,
                      border: Border.all(
                        color: isActive
                            ? textColor
                            : textColor.withValues(alpha: 0.25),
                        width: isToday ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: isActive
                          ? Icon(Icons.check, size: 14, color: textColor)
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
                      color: textColor,
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 16),

          // آمار
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'عادت‌های امروز',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  Text(
                    '$completedHabitsToday از $totalHabitsToday',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: textColor.withValues(alpha: 0.15),
                  color: textColor,
                  minHeight: 6,
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
                    color: textSecondary,
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
