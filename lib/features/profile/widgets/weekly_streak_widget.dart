// lib/features/profile/widgets/weekly_streak_widget.dart

import 'package:flutter/material.dart';
import '/services/supabase_service.dart';
import 'package:shamsi_date/shamsi_date.dart';

class WeeklyStreakWidget extends StatefulWidget {
  final String userId;
  final int weeklyStreak;

  const WeeklyStreakWidget({
    super.key,
    required this.userId,
    required this.weeklyStreak,
  });

  @override
  State<WeeklyStreakWidget> createState() => _WeeklyStreakWidgetState();
}

class _WeeklyStreakWidgetState extends State<WeeklyStreakWidget> {
  final SupabaseService _supabase = SupabaseService();
  List<bool> _weekDays = List.filled(7, false);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeekDays();
  }

  Future<void> _loadWeekDays() async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));

      for (int i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        final dateStr = date.toIso8601String().split('T').first;

        final activity = await _supabase.client
            .from('user_daily_activity')
            .select('is_active')
            .eq('user_id', widget.userId)
            .eq('activity_date', dateStr)
            .maybeSingle();

        if (activity != null && activity['is_active'] == true) {
          _weekDays[i] = true;
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekDays = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
    final today = DateTime.now().weekday - 1;
    final isTodayActive = _weekDays[today];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'استریک هفتگی',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.weeklyStreak} روز',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final isActive = _weekDays[index];
              final isToday = index == today;

              return Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? const Color(0xFF2563EB)
                          : isToday
                          ? const Color(0xFF2563EB).withOpacity(0.2)
                          : Colors.grey.shade200,
                      border: isToday && !isActive
                          ? Border.all(color: const Color(0xFF2563EB), width: 2)
                          : null,
                    ),
                    child: Center(
                      child: isActive
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : isToday
                          ? const Icon(
                              Icons.circle,
                              color: Color(0xFF2563EB),
                              size: 8,
                            )
                          : const SizedBox(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    weekDays[index],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isActive
                          ? const Color(0xFF2563EB)
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getStreakColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(_getStreakIcon(), color: _getStreakColor(), size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getStreakMessage(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _getStreakColor(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakNumber() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _getStreakColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStreakIcon(),
            color: _getStreakColor(),
            size: 28, // بزرگتر
          ),
          const SizedBox(width: 8),
          Text(
            '${widget.weeklyStreak}',
            style: TextStyle(
              fontSize: 32, // از 14 به 32
              fontWeight: FontWeight.bold,
              color: _getStreakColor(),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'روز',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _getStreakColor(),
            ),
          ),
        ],
      ),
    );
  }

  String _getStreakMessage() {
    if (widget.weeklyStreak == 0) {
      return 'امروز رو شروع کن! هر روز یک قدم به قهرمانی نزدیک‌تر میشی 💪';
    } else if (widget.weeklyStreak < 3) {
      return '${widget.weeklyStreak} روز پیاپی! عالی ادامه بده 🔥';
    } else if (widget.weeklyStreak < 5) {
      return '${widget.weeklyStreak} روز پیاپی! تو یک قهرمان واقعی هستی 🏆';
    } else if (widget.weeklyStreak < 7) {
      return '${widget.weeklyStreak} روز پیاپی! فقط ${7 - widget.weeklyStreak} روز دیگه تا هفته کامل 💎';
    } else {
      return '🎉 هفته کامل! تو یک افسانه هستی! 🌟';
    }
  }

  Color _getStreakColor() {
    if (widget.weeklyStreak == 0) {
      return Colors.grey.shade600;
    } else if (widget.weeklyStreak < 3) {
      return const Color(0xFFFFA500);
    } else if (widget.weeklyStreak < 5) {
      return const Color(0xFF2563EB);
    } else {
      return const Color(0xFF7C3AED);
    }
  }

  IconData _getStreakIcon() {
    if (widget.weeklyStreak == 0) {
      return Icons.emoji_emotions_outlined;
    } else if (widget.weeklyStreak < 3) {
      return Icons.local_fire_department;
    } else if (widget.weeklyStreak < 5) {
      return Icons.emoji_events;
    } else {
      return Icons.stars;
    }
  }
}
