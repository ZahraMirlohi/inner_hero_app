// lib/features/arena/widgets/habit_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/habit_model.dart';
import '../screens/habit_detail_screen.dart';
import '/core/app_palette.dart';
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

  // پارامتر جدید
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
    this.recordedTimeSeconds, // 
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

    // رنگ کارت عادت - دست‌نخورده باقی می‌مونه (همون رنگ ذخیره‌شده کاربر)
    // فقط در صورت تکمیل شدن، خنثی (خاکستری) میشه
    Color getCardColor() {
      if (widget.isCompleted) {
        // کارت تکمیل‌شده: در تم شب تیره، در تم روز روشن
        return theme.cardSecondaryColor;
      }
      // چالش و ماموریت هرکدام رنگ پاستلی خودشان را دارند تا از عادت‌های معمولی جدا باشند
      if (isChallenge) return theme.tone(Tone.butter).bg;
      if (isQuest) return theme.tone(Tone.lilac).bg;
      final savedColor = widget.habit.backgroundColor;
      if (savedColor != 0) return Color(savedColor);
      return primaryColor;
    }

    final Color cardColor = getCardColor();

    // رنگ متن روی کارت
    // - کارت رنگی (فعال): متن مشکی (چون پس‌زمینه رنگیه)
    // - کارت تکمیل‌شده: در تم شب روشن، در تم روز مشکی
    final Color textColor;
    if (widget.isCompleted) {
      textColor = theme.textColor;
    } else {
      // روی کارت رنگی، متن همیشه مشکی
      textColor = const Color(0xFF090909);
    }

    // رنگ دکمه انجام (دایره سمت چپ)
    final Color checkButtonBg = widget.isCompleted
        ? theme.disabledButtonBackground
        : const Color(0xFF090909);

    final Color checkIconColor = widget.isCompleted
        ? (theme.isDarkMode ? Colors.grey.shade400 : Colors.white)
        : (isChallenge || isQuest
            ? const Color(0xFF090909) // روی کارت رنگی، آیکون مشکی
            : cardColor); // روی کارت مشکی، آیکون هم‌رنگ کارت

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          // ============================================================
          // HEADER
          // ============================================================
          GestureDetector(
            onTap: _toggleExpansion,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.all(widget.isCompleted ? 10 : 14),
              decoration: BoxDecoration(
                color: widget.isCompleted ? theme.cardColor : cardColor,
                borderRadius: BorderRadius.circular(28),
                boxShadow: widget.isCompleted ? theme.softShadow : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // دایرهٔ سیاه آیکون؛ لمس = انجام دادن
                  AnimatedCheckOverlay(
                    onTap: widget.onToggle,
                    checkColor: checkIconColor,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: widget.isCompleted ? 40 : 48,
                      height: widget.isCompleted ? 40 : 48,
                      decoration: BoxDecoration(
                        color: widget.isCompleted
                            ? theme.cardSecondaryColor
                            : const Color(0xFF090909),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.isCompleted
                            ? Icons.check_rounded
                            : _getIconData(widget.habit.iconName),
                        color: widget.isCompleted
                            ? theme.textSecondaryColor
                            : cardColor,
                        size: widget.isCompleted ? 20 : 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (isChallenge || isQuest) ...[
                              _chip(
                                icon: isChallenge
                                    ? Icons.emoji_events_rounded
                                    : Icons.flag_rounded,
                                label: isChallenge ? 'چالش' : 'ماموریت',
                                bg: const Color(0xFF090909),
                                fg: Colors.white,
                                height: 24,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                widget.habit.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: widget.isCompleted
                                      ? FontWeight.w600
                                      : FontWeight.w700,
                                  color: widget.isCompleted
                                      ? theme.textSecondaryColor
                                      : textColor,
                                  decoration: widget.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (!widget.isCompleted) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _chip(label: '+${widget.habit.xpReward}'),
                              if (widget.recordedTimeSeconds != null &&
                                  widget.recordedTimeSeconds! > 0)
                                _chip(
                                  icon: Icons.timer_outlined,
                                  label: _formatRecordedTime(
                                      widget.recordedTimeSeconds!),
                                  bg: theme.tone(Tone.lilac).bg,
                                ),
                              _chip(
                                icon: Icons.access_time_rounded,
                                label:
                                    _getTimeOfDayText(widget.habit.timeOfDay),
                              ),
                              if (widget.habit.reminders.isNotEmpty)
                                _chip(
                                  icon: Icons.alarm_rounded,
                                  label: '${widget.habit.reminders.length}',
                                ),
                              if (widget.habit.currentStreak > 0)
                                _chip(
                                  icon: Icons.local_fire_department_rounded,
                                  label: '${widget.habit.currentStreak}',
                                  bg: theme.tone(Tone.apricot).bg,
                                  iconColor: const Color(0xFFE8890C),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ============================================================
          // EXPANDED DRAWER
          // ============================================================
          SizeTransition(
            sizeFactor: _expansionAnimation,
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: theme.softShadow,
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

                  // لیست زیرعادت‌ها
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

  /// فرمت زمان به صورت خوانا
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
    // روی کارت رنگی (فعال)، چیپ همیشه روشن با متن مشکی
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

  /// چیپ کوچک گرد؛ پیش‌فرض سفید نیمه‌شفاف روی کارت رنگی
  Widget _chip({
    IconData? icon,
    required String label,
    Color? bg,
    Color fg = const Color(0xFF090909),
    Color? iconColor,
    double height = 26,
  }) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg ?? Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: iconColor ?? fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
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
