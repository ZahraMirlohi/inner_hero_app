// lib/features/arena/widgets/habit_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/habit_model.dart';
import '../screens/habit_detail_screen.dart';
import '/providers/theme_provider.dart';
import 'animated_check_overlay.dart';

class HabitCard extends StatefulWidget {
  final Habit habit;
  final bool isCompleted;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onTimer;
  final VoidCallback? onTap;
  final Function(String)? onToggleSubHabit;

  // ✅ پارامتر جدید
  final int? recordedTimeSeconds;

  const HabitCard({
    super.key,
    required this.habit,
    required this.isCompleted,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.onTimer,
    this.onTap,
    this.onToggleSubHabit,
    this.recordedTimeSeconds, // ✅
  });

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expansionAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expansionAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final Color primaryColor = theme.primaryColor;

    final bool isChallenge = widget.habit.challengeId != null;
    final bool isQuest = widget.habit.questId != null;

    // ✅ رنگ کارت عادت - دست‌نخورده باقی می‌مونه (همون رنگ ذخیره‌شده کاربر)
    // فقط در صورت تکمیل شدن، خنثی (خاکستری) میشه
    Color getCardColor() {
      if (widget.isCompleted) {
        // ✅ کارت تکمیل‌شده: در تم شب تیره، در تم روز روشن
        return theme.isDarkMode
            ? const Color(0xFF2A2A2A)
            : const Color(0xFFF5F5F5);
      }
      // ✅ کارت عادت فعال: همیشه رنگ اصلی خودش (چه تم روز چه شب)
      if (isChallenge || isQuest) return primaryColor;
      final savedColor = widget.habit.backgroundColor;
      if (savedColor != 0) return Color(savedColor);
      return primaryColor;
    }

    final Color cardColor = getCardColor();

    // ✅ رنگ متن روی کارت
    // - کارت رنگی (فعال): متن مشکی (چون پس‌زمینه رنگیه)
    // - کارت تکمیل‌شده: در تم شب روشن، در تم روز مشکی
    final Color textColor;
    if (widget.isCompleted) {
      textColor = theme.isDarkMode ? Colors.white : const Color(0xFF090909);
    } else {
      // ✅ روی کارت رنگی، متن همیشه مشکی
      textColor = const Color(0xFF090909);
    }

    // ✅ رنگ دکمه انجام (دایره سمت چپ)
    final Color checkButtonBg = widget.isCompleted
        ? (theme.isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFE0E0E0))
        : const Color(0xFF090909);

    final Color checkIconColor = widget.isCompleted
        ? (theme.isDarkMode ? Colors.grey.shade400 : Colors.white)
        : (isChallenge || isQuest
            ? const Color(0xFF090909) // روی کارت رنگی، آیکون مشکی
            : cardColor); // روی کارت مشکی، آیکون هم‌رنگ کارت

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Column(
        children: [
          // ============================================================
          // HEADER
          // ============================================================
          GestureDetector(
            onTap: _toggleExpansion,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: theme.isDarkMode ? 0.3 : 0.06,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                if (isChallenge || isQuest) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isChallenge ? '🏆' : '🎯',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Expanded(
                                  child: Text(
                                    widget.habit.title,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                      decoration: widget.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textDirection: TextDirection.rtl,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                // ✅ تگ XP
                                if (!widget.isCompleted)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '+${widget.habit.xpReward}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF090909),
                                      ),
                                    ),
                                  ),
                                // ✅ تگ زمان رکورد شده (اگه وجود داشته باشه)
                                if (widget.recordedTimeSeconds != null &&
                                    widget.recordedTimeSeconds! > 0) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8B5CF6)
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFF8B5CF6)
                                            .withOpacity(0.3),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.timer_outlined,
                                          size: 10,
                                          color: Color(0xFF8B5CF6),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          _formatRecordedTime(
                                              widget.recordedTimeSeconds!),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF8B5CF6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                Wrap(
                                  alignment: WrapAlignment.end,
                                  spacing: 4,
                                  runSpacing: 2,
                                  children: [
                                    _buildInfoChip(
                                      icon: Icons.access_time,
                                      label: _getTimeOfDayText(
                                          widget.habit.timeOfDay),
                                      isCompleted: widget.isCompleted,
                                      theme: theme,
                                    ),
                                    if (widget.habit.reminders.isNotEmpty)
                                      _buildInfoChip(
                                        icon: Icons.alarm,
                                        label:
                                            '${widget.habit.reminders.length}',
                                        isCompleted: widget.isCompleted,
                                        theme: theme,
                                      ),
                                    if (widget.habit.currentStreak > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              Colors.orange.withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.local_fire_department,
                                              size: 10,
                                              color: Colors.orange,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              '${widget.habit.currentStreak}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AnimatedCheckOverlay(
                      onTap: widget.onToggle,
                      checkColor: checkIconColor,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: checkButtonBg,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            _getIconData(widget.habit.iconName),
                            color: checkIconColor,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ============================================================
          // EXPANDED DRAWER
          // ============================================================
          SizeTransition(
            sizeFactor: _expansionAnimation,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: widget.isCompleted
                    ? (theme.isDarkMode
                        ? const Color(0xFF1A1A1A)
                        : Colors.grey.shade50)
                    : theme.cardColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(
                  top: BorderSide(
                    color: theme.borderColor,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── دکمه‌های عملیات ───
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        icon: widget.isCompleted
                            ? Icons.refresh
                            : Icons.check_circle_outline,
                        label: widget.isCompleted ? 'برگردان' : 'انجام',
                        color:
                            widget.isCompleted ? Colors.orange : primaryColor,
                        onTap: widget.onToggle,
                        isCompleted: widget.isCompleted,
                      ),
                      _buildActionButton(
                        icon: Icons.info_outline,
                        label: 'جزئیات',
                        color: const Color(0xFF3B82F6),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  HabitDetailScreen(habit: widget.habit),
                            ),
                          );
                        },
                        isCompleted: widget.isCompleted,
                      ),
                      if (!isChallenge && !isQuest && widget.onTimer != null)
                        _buildActionButton(
                          icon: Icons.timer_outlined,
                          label: 'تایمر',
                          color: const Color(0xFF8B5CF6),
                          onTap: widget.onTimer!,
                          isCompleted: widget.isCompleted,
                        ),
                      if (!isChallenge && !isQuest)
                        _buildActionButton(
                          icon: Icons.edit_outlined,
                          label: 'ویرایش',
                          color: const Color(0xFFF59E0B),
                          onTap: widget.onEdit,
                          isCompleted: widget.isCompleted,
                        ),
                      if (!isChallenge && !isQuest)
                        _buildActionButton(
                          icon: Icons.delete_outline,
                          label: 'حذف',
                          color: const Color(0xFFEF4444),
                          onTap: widget.onDelete,
                          isCompleted: widget.isCompleted,
                        ),
                    ],
                  ),

                  // ✅ لیست زیرعادت‌ها
                  if (widget.habit.subHabits.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Divider(height: 1, color: theme.borderColor),
                    const SizedBox(height: 8),
                    ...widget.habit.subHabits.map((subHabit) {
                      final isChecked =
                          widget.habit.completedSubHabits.contains(subHabit);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: InkWell(
                          onTap: widget.isCompleted
                              ? null
                              : () => widget.onToggleSubHabit?.call(subHabit),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isChecked
                                        ? primaryColor
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isChecked
                                          ? primaryColor
                                          : theme.textSecondaryColor,
                                      width: 1.8,
                                    ),
                                  ),
                                  child: isChecked
                                      ? const Icon(
                                          Icons.check,
                                          size: 14,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    subHabit,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isChecked
                                          ? theme.textSecondaryColor
                                          : theme.textColor,
                                      decoration: isChecked
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ فرمت زمان به صورت خوانا
  /// - کمتر از 1 دقیقه: "45s"
  /// - بین 1 تا 60 دقیقه: "5m"
  /// - بیشتر از 60 دقیقه: "1h 20m"
  String _formatRecordedTime(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    }
    final minutes = seconds ~/ 60;
    if (minutes < 60) {
      return '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '${hours}h';
    }
    return '${hours}h ${remainingMinutes}m';
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    bool isCompleted = false,
    required ThemeProvider theme,
  }) {
    // ✅ روی کارت رنگی (فعال)، چیپ همیشه روشن با متن مشکی
    // روی کارت تکمیل‌شده، چیپ با تم هماهنگ میشه
    final bool isOnColoredCard = !widget.isCompleted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isOnColoredCard
            ? Colors.white.withOpacity(0.6)
            : (theme.isDarkMode
                ? Colors.white.withOpacity(0.15)
                : Colors.white.withOpacity(0.6)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isOnColoredCard
                  ? const Color(0xFF090909)
                  : (theme.isDarkMode ? Colors.white : const Color(0xFF090909)),
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            icon,
            size: 11,
            color: (isOnColoredCard
                    ? const Color(0xFF090909)
                    : (theme.isDarkMode
                        ? Colors.white
                        : const Color(0xFF090909)))
                .withOpacity(0.6),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isCompleted = false,
  }) {
    final Color finalColor = isCompleted ? Colors.grey.shade500 : color;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: finalColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: finalColor.withOpacity(0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: finalColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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

  String _getTimeOfDayText(String timeOfDay) {
    switch (timeOfDay) {
      case 'morning':
        return 'صبح';
      case 'noon':
        return 'ظهر';
      case 'afternoon':
        return 'بعدازظهر';
      case 'night':
        return 'شب';
      default:
        return 'صبح';
    }
  }
}
