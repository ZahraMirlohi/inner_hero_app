// lib/features/profile/widgets/streak_card_widget.dart

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '/providers/theme_provider.dart';

class StreakCardWidget extends StatelessWidget {
  final int currentStreak;
  final int bestStreak;
  final int weeklyStreak;
  final List<bool>
      weekDays; // ✅ این لیست باید هفت روز رو به ترتیب شنبه تا جمعه داشته باشه

  const StreakCardWidget({
    super.key,
    required this.currentStreak,
    required this.bestStreak,
    required this.weeklyStreak,
    required this.weekDays,
  });

  @override
  Widget build(BuildContext context) {
    // ⚠️ منطق زیر دقیقاً همون منطق قبلیه — هیچ محاسبه‌ای تغییر نکرده
    final bool isOnFire = currentStreak >= 7;
    final String streakEmoji = _getStreakEmoji(currentStreak);

    // ✅ روزهای هفته شمسی (شنبه تا جمعه) - مرتبط با index 0 تا 6
    final weekDaysLabels = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

    // ✅ محاسبه روز امروز در تقویم شمسی
    final jalaliToday = Jalali.fromDateTime(DateTime.now());
    final todayIndex = jalaliToday.weekDay - 1; // 0=شنبه, 1=یکشنبه, ..., 6=جمعه

    // ✅ لاگ برای دیباگ
    print('📅 Today Index: $todayIndex (${weekDaysLabels[todayIndex]})');
    print('📊 WeekDays status: $weekDays');

    // 🎨 رنگ‌های تم اپلیکیشن
    final theme = context.watch<ThemeProvider>();
    const Color kBlack = Color(0xFF090909);
    const Color kTextSecondary = Color(0xFF73786B);
    final Color kGreen = theme.primaryColor; // قابل تغییر توسط کاربر

    // ✅ بدون باکس سفید پشت زمینه — فقط پدینگ ساده
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          // ---------- هدر ----------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    isOnFire ? '🔥' : '⚡',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'استریک روزانه',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: kBlack,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: kGreen.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      size: 14,
                      color: kBlack,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$bestStreak رکورد',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kBlack,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // ---------- دایره‌ی بزرگ استریک + ۷ دایره‌ی کوچک به‌صورت منحنی با فاصله از لبه ----------
          _buildStreakOrb(
            kBlack: kBlack,
            kGreen: kGreen,
            kTextSecondary: kTextSecondary,
            streakEmoji: streakEmoji,
            weekDaysLabels: weekDaysLabels,
            todayIndex: todayIndex,
          ),

          const SizedBox(height: 16),

          // ---------- پیام انگیزشی (بیرون از دایره) ----------
          Text(
            _getMotivationalMessage(currentStreak),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: kBlack,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakOrb({
    required Color kBlack,
    required Color kGreen,
    required Color kTextSecondary,
    required String streakEmoji,
    required List<String> weekDaysLabels,
    required int todayIndex,
  }) {
    // اندازه‌های دایره‌ی بزرگ و دایره‌های کوچک
    const double bigDiameter = 176;
    const double smallDiameter = 30;
    const double bigRadius = bigDiameter / 2;
    const double smallRadius = smallDiameter / 2;

    // شعاعی که مرکز دایره‌های کوچک روی آن قرار می‌گیرن — فاصله‌ی بیشتری
    // از لبه‌ی دایره‌ی بزرگ گرفته شده (قبلاً ۱۶ بود، الان ۳۸)
    const double arcRadius = bigRadius + 38;

    // بازه‌ی زاویه‌ای که دایره‌های کوچک روی آن چیده می‌شن (به‌صورت منحنی بالای دایره)
    const double startAngleDeg = 202;
    const double endAngleDeg = 338;
    const double angleStep = (endAngleDeg - startAngleDeg) / 6;

    // اندازه‌ی کل ناحیه‌ای که این ترکیب (دایره‌ی بزرگ + قوس دایره‌های کوچک) نیاز داره
    const double stackWidth = 2 * arcRadius + smallDiameter;
    const double labelHeight = 16; // فضای لازم برای متن زیر هر دایره‌ی کوچک
    const double stackHeight =
        bigDiameter + (arcRadius - bigRadius) + smallDiameter + labelHeight;

    final double centerX = stackWidth / 2;
    // چون دایره‌ی بزرگ به پایین استک چسبیده (bottom: 0)، مرکز عمودیش:
    final double bigCircleCenterY = stackHeight - bigRadius;

    return SizedBox(
      width: stackWidth,
      height: stackHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // دایره‌ی بزرگ (رنگ ساده - رنگ تم اپلیکیشن)
          Positioned(
            bottom: 0,
            left: (stackWidth - bigDiameter) / 2,
            child: Container(
              width: bigDiameter,
              height: bigDiameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kBlack,
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
                        style: const TextStyle(
                          fontSize: 54,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ۷ دایره‌ی کوچک، چیده‌شده روی یک منحنی با فاصله از لبه‌ی دایره‌ی بزرگ
          ...List.generate(7, (index) {
            final bool isActive = weekDays.length > index && weekDays[index];
            final bool isToday = index == todayIndex;

            final double angleDeg = startAngleDeg + (index * angleStep);
            final double angleRad = angleDeg * pi / 180;

            final double dotX = centerX + arcRadius * cos(angleRad);
            final double dotY = bigCircleCenterY + arcRadius * sin(angleRad);

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
                        // ✅ تیک‌خورده = رنگ تم (سبز)، تیک‌نخورده = مشکی
                        color: isActive ? kGreen : kBlack,
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
                                color: kBlack,
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
                        color: isActive ? kBlack : kTextSecondary,
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

  // ⚠️ این دو تابع دقیقاً همونی هستن که قبلاً بودن — بدون هیچ تغییری
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
