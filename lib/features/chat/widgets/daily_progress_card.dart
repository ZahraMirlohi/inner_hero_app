// lib/features/chat/widgets/daily_progress_card.dart

import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

class DailyProgressCard extends StatelessWidget {
  final int currentStreak;
  final int completedHabitsToday;
  final int totalHabitsToday;
  final List<bool> weekDays; // 7 روز هفته (شنبه تا جمعه)

  const DailyProgressCard({
    super.key,
    required this.currentStreak,
    required this.completedHabitsToday,
    required this.totalHabitsToday,
    required this.weekDays,
  });

  @override
  Widget build(BuildContext context) {
    // محاسبه درصد پیشرفت امروز
    final double progress = totalHabitsToday > 0
        ? completedHabitsToday / totalHabitsToday
        : 0.0;
    final int progressPercent = (progress * 100).toInt();

    // روزهای هفته شمسی
    final weekDaysLabels = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
    final todayIndex = Jalali.now().weekDay - 1; // 0 = شنبه

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ============== هدر ==============
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'پیشرفت روزانه',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.local_fire_department,
                    size: 16,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$currentStreak روز پیاپی',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
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
                          ? const Color(0xFF4A90E2)
                          : isToday
                          ? const Color(0xFF4A90E2).withValues(alpha: 0.15)
                          : Colors.grey.shade100,
                      border: isToday && !isActive
                          ? Border.all(color: const Color(0xFF4A90E2), width: 2)
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
                          ? const Icon(
                              Icons.circle,
                              size: 6,
                              color: Color(0xFF4A90E2),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    weekDaysLabels[index],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isActive
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isActive
                          ? const Color(0xFF4A90E2)
                          : Colors.grey.shade400,
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
                  const Text(
                    'عادت‌های امروز',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  Text(
                    '$completedHabitsToday از $totalHabitsToday',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.shade200,
                  color: progressPercent >= 80
                      ? const Color(0xFF2ECC71)
                      : progressPercent >= 50
                      ? const Color(0xFFFFA500)
                      : const Color(0xFF4A90E2),
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
                    color: Colors.grey.shade500,
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
