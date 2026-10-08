// lib/features/profile/widgets/weekly_streak_widget.dart

import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:provider/provider.dart';
import '/services/supabase_service.dart';
import '/providers/theme_provider.dart';

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
      final jalaliNow = Jalali.fromDateTime(now);

      final daysToSubtract = jalaliNow.weekDay - 1;
      final weekStart = now.subtract(Duration(days: daysToSubtract));

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
    final theme = Provider.of<ThemeProvider>(context);
    final primaryColor = theme.primaryColor;

    final weekDays = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

    final jalaliToday = Jalali.fromDateTime(DateTime.now());
    final todayIndex = jalaliToday.weekDay - 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.isDarkMode ? 0.3 : 0.05,
            ),
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
              Text(
                'استریک هفتگی',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.weeklyStreak} روز',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
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
              final isToday = index == todayIndex;

              return Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? primaryColor
                          : isToday
                              ? primaryColor.withValues(alpha: 0.2)
                              : (theme.isDarkMode
                                  ? const Color(0xFF2A2A2A)
                                  : Colors.grey.shade200),
                      border: isToday && !isActive
                          ? Border.all(color: primaryColor, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: isActive
                          ? Icon(
                              Icons.check,
                              color: theme.isDarkMode
                                  ? const Color(0xFF090909)
                                  : Colors.white,
                              size: 20,
                            )
                          : isToday
                              ? Icon(
                                  Icons.circle,
                                  color: primaryColor,
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
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive ? primaryColor : theme.textSecondaryColor,
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
              color: _getStreakColor(primaryColor).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _getStreakIcon(),
                  color: _getStreakColor(primaryColor),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getStreakMessage(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _getStreakColor(primaryColor),
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

  Color _getStreakColor(Color primaryColor) {
    if (widget.weeklyStreak == 0) {
      return Colors.grey.shade600;
    } else if (widget.weeklyStreak < 3) {
      return const Color(0xFFFFA500);
    } else if (widget.weeklyStreak < 5) {
      return primaryColor;
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
