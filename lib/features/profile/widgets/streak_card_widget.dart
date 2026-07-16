// lib/features/profile/widgets/streak_card_widget.dart

import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

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
    final bool isOnFire = currentStreak >= 7;
    final String streakEmoji = _getStreakEmoji(currentStreak);

    // ✅ روزهای هفته شمسی (شنبه تا جمعه)
    final weekDaysLabels = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

    // ✅ محاسبه روز امروز در تقویم شمسی
    final jalaliToday = Jalali.fromDateTime(DateTime.now());
    final todayIndex = jalaliToday.weekDay - 1; // 0=شنبه, 1=یکشنبه, ..., 6=جمعه

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isOnFire
              ? [
                  const Color(0xFFFF6B6B),
                  const Color(0xFFFFA500),
                  const Color(0xFFFFD93D),
                ]
              : [const Color(0xFF2563EB), const Color(0xFF7C3AED)],
          stops: isOnFire ? const [0.0, 0.5, 1.0] : null,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
                (isOnFire ? const Color(0xFFFF6B6B) : const Color(0xFF2563EB))
                    .withValues(alpha: 0.25),
            blurRadius: 15,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Column(
        children: [
          // هدر
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    isOnFire ? '🔥' : '⚡',
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOnFire ? 'در آتش!' : 'استریک روزانه',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        isOnFire
                            ? '$currentStreak روز پیاپی! 💪'
                            : 'هر روز یک قدم به قهرمانی',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$bestStreak',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // عدد استریک
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                currentStreak.toString(),
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 0.9,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'روز',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Center(
            child: Text(streakEmoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(height: 12),

          // ✅ روزهای هفته شمسی
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final bool isActive = weekDays[index];
              final bool isToday = index == todayIndex;

              return Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? Colors.white
                          : isToday
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.1),
                      border: isToday && !isActive
                          ? Border.all(color: Colors.white, width: 1.5)
                          : null,
                    ),
                    child: Center(
                      child: isActive
                          ? const Icon(
                              Icons.check,
                              color: Color(0xFF2563EB),
                              size: 14,
                            )
                          : isToday
                          ? const Icon(
                              Icons.circle,
                              color: Colors.white,
                              size: 6,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    weekDaysLabels[index],
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isActive
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              );
            }),
          ),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getMotivationalMessage(currentStreak),
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
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
