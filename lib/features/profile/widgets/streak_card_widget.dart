// lib/features/profile/widgets/streak_card_widget.dart

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '/providers/theme_provider.dart';
import '/providers/calendar_provider.dart';

class StreakCardWidget extends StatelessWidget {
  final int currentStreak;
  final int bestStreak;
  final int weeklyStreak;
  final List<bool> weekDays;

  const StreakCardWidget({
    super.key,
    required this.currentStreak,
    required this.bestStreak,
    required this.weeklyStreak,
    required this.weekDays,
  });

  @override
  Widget build(BuildContext context) {
    final calendar = Provider.of<CalendarProvider>(context);
    final theme = context.watch<ThemeProvider>();

    final bool isOnFire = currentStreak >= 7;
    final String streakEmoji = _getStreakEmoji(currentStreak);

    final weekDaysLabels = calendar.weekDayHeaders;

    final int todayIndex;
    if (calendar.isJalali) {
      final jalaliToday = Jalali.fromDateTime(DateTime.now());
      todayIndex = jalaliToday.weekDay - 1;
    } else {
      todayIndex = DateTime.now().weekday % 7;
    }

    final Color kGreen = theme.primaryColor;
    final Color kBlack =
        theme.isDarkMode ? Colors.white : const Color(0xFF090909);
    final Color kTextSecondary = theme.textSecondaryColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.surfaceColor, // ✅ از تم
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: theme.isDarkMode ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // هدر
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isOnFire ? '🔥' : '⚡',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 6),
                Text(
                  'استریک روزانه',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor, // ✅ از تم
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // بج رکورد
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: kGreen.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.emoji_events,
                    size: 14,
                    color: theme.textColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$bestStreak رکورد',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 22),

          // دایره‌ی استریک
          _buildStreakOrb(
            kGreen: kGreen,
            streakEmoji: streakEmoji,
            weekDaysLabels: weekDaysLabels,
            todayIndex: todayIndex,
            textColor: theme.textColor,
            theme: theme,
          ),

          const SizedBox(height: 16),

          // پیام انگیزشی
          Text(
            _getMotivationalMessage(currentStreak),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: theme.textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakOrb({
    required Color kGreen,
    required String streakEmoji,
    required List<String> weekDaysLabels,
    required int todayIndex,
    required Color textColor,
    required ThemeProvider theme,
  }) {
    const double bigDiameter = 176;
    const double smallDiameter = 30;
    const double bigRadius = bigDiameter / 2;
    const double smallRadius = smallDiameter / 2;
    const double arcRadius = bigRadius + 38;
    const double startAngleDeg = 202;
    const double endAngleDeg = 338;
    const double angleStep = (endAngleDeg - startAngleDeg) / 6;
    const double stackWidth = 2 * arcRadius + smallDiameter;
    const double labelHeight = 16;
    const double stackHeight =
        bigDiameter + (arcRadius - bigRadius) + smallDiameter + labelHeight;

    final double centerX = stackWidth / 2;
    final double bigCircleCenterY = stackHeight - bigRadius;

    // ✅ رنگ دایره بزرگ: در تم شب از primary استفاده می‌کنیم، در تم روز مشکی
    final Color bigCircleColor =
        theme.isDarkMode ? theme.primaryColor : const Color(0xFF090909);
    final Color bigCircleTextColor =
        theme.isDarkMode ? const Color(0xFF090909) : Colors.white;

    return SizedBox(
      width: stackWidth,
      height: stackHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // دایره بزرگ
          Positioned(
            bottom: 0,
            left: (stackWidth - bigDiameter) / 2,
            child: Container(
              width: bigDiameter,
              height: bigDiameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bigCircleColor,
                boxShadow: [
                  BoxShadow(
                    color: kGreen.withValues(alpha: 0.35),
                    blurRadius: 22,
                    spreadRadius: 1,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(streakEmoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currentStreak.toString(),
                        style: TextStyle(
                          fontSize: 54,
                          fontWeight: FontWeight.bold,
                          color: bigCircleTextColor,
                          height: 0.95,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          'روز',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: bigCircleTextColor.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // دایره‌های کوچک
          ...List.generate(7, (index) {
            final bool isActive = weekDays.length > index && weekDays[index];
            final bool isToday = index == todayIndex;

            final double angleDeg = startAngleDeg + (index * angleStep);
            final double angleRad = angleDeg * pi / 180;

            final double dotX = centerX + arcRadius * cos(angleRad);
            final double dotY = bigCircleCenterY + arcRadius * sin(angleRad);

            // ✅ رنگ دایره‌های کوچک: تیک‌خورده = سبز، تیک‌نخورده = رنگ متن تم
            final Color dotColor = isActive
                ? kGreen
                : (theme.isDarkMode
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFF090909));
            final Color checkColor =
                theme.isDarkMode ? const Color(0xFF090909) : Colors.white;

            return Positioned(
              left: dotX - smallRadius,
              top: dotY - smallRadius,
              child: SizedBox(
                width: smallDiameter + 10,
                child: Column(
                  children: [
                    Container(
                      width: smallDiameter,
                      height: smallDiameter,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dotColor,
                        border: isToday && !isActive
                            ? Border.all(color: kGreen, width: 1.4)
                            : null,
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: kGreen.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: isActive
                            ? Icon(
                                Icons.check,
                                color: checkColor,
                                size: 13,
                              )
                            : isToday
                                ? Icon(
                                    Icons.circle,
                                    color: kGreen,
                                    size: 6,
                                  )
                                : null,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      weekDaysLabels[index],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? textColor : theme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _getStreakEmoji(int streak) {
    if (streak >= 100) return '👑';
    if (streak >= 50) return '🌟';
    if (streak >= 30) return '💎';
    if (streak >= 14) return '🔥';
    if (streak >= 7) return '⚡';
    if (streak >= 3) return '💪';
    if (streak >= 1) return '✨';
    return '🌱';
  }

  String _getMotivationalMessage(int streak) {
    if (streak >= 100) return 'افسانه‌ای! 🌟';
    if (streak >= 50) return 'فوق‌العاده‌ای! 💎';
    if (streak >= 30) return 'یک ماه کامل! 🔥';
    if (streak >= 14) return 'دو هفته! قوی میشی 💪';
    if (streak >= 7) return 'یک هفته کامل! ⚡';
    if (streak >= 3) return 'عالی ادامه بده! ✨';
    if (streak >= 1) return 'اولین قدم رو برداشتی! 🌱';
    return 'امروز رو شروع کن! 🚀';
  }
}
