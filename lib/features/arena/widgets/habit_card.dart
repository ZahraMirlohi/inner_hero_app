// lib/features/arena/widgets/habit_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/habit_model.dart';
import '../screens/habit_detail_screen.dart';
import '/core/app_palette.dart';
import '/l10n/app_strings.dart';
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

    // کشو زیر کارت قرار می‌گیرد و ۱۴ پیکسل زیر آن می‌رود (طبق ArenaDrawer)؛
    // با verticalDirection.up کارت بالای کشو رسم می‌شود.
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        verticalDirection: VerticalDirection.up,
        children: [
          // ============================================================
          // EXPANDED DRAWER
          // ============================================================
          Transform.translate(
            offset: const Offset(0, -14),
            child: SizeTransition(
            sizeFactor: _expansionAnimation,
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              padding: const EdgeInsets.fromLTRB(10, 28, 10, 14),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(26),
                  bottomRight: Radius.circular(26),
                ),
                boxShadow: theme.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── دکمه‌های عملیات ───
                  Row(
                    mainAxisAlignment: (isChallenge || isQuest)
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.spaceAround,
                    children: [
                      _buildActionButton(
                        icon: widget.isCompleted
                            ? Icons.refresh_rounded
                            : Icons.check_circle_outline_rounded,
                        label: widget.isCompleted
                            ? context.tr('ah.card.undo')
                            : context.tr('ah.card.done'),
                        bg: widget.isCompleted
                            ? theme.tone(Tone.peach).bg
                            : theme.primarySoft,
                        fg: widget.isCompleted
                            ? theme.tone(Tone.peach).fg
                            : theme.textColor,
                        onTap: widget.onToggle,
                        theme: theme,
                      ),
                      if (isChallenge || isQuest) const SizedBox(width: 36),
                      _buildActionButton(
                        icon: Icons.info_outline_rounded,
                        label: context.tr('ah.card.details'),
                        bg: theme.tone(Tone.sky).bg,
                        fg: theme.tone(Tone.sky).fg,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  HabitDetailScreen(habit: widget.habit),
                            ),
                          );
                        },
                        theme: theme,
                      ),
                      if (!isChallenge && !isQuest && widget.onTimer != null)
                        _buildActionButton(
                          icon: Icons.timer_outlined,
                          label: context.tr('ah.card.timer'),
                          bg: theme.tone(Tone.lilac).bg,
                          fg: theme.tone(Tone.lilac).fg,
                          onTap: widget.onTimer!,
                          theme: theme,
                        ),
                      if (!isChallenge && !isQuest)
                        _buildActionButton(
                          icon: Icons.edit_outlined,
                          label: context.tr('ah.card.edit'),
                          bg: theme.tone(Tone.apricot).bg,
                          fg: theme.tone(Tone.apricot).fg,
                          onTap: widget.onEdit,
                          theme: theme,
                        ),
                      if (!isChallenge && !isQuest)
                        _buildActionButton(
                          icon: Icons.delete_outline_rounded,
                          label: context.tr('ah.card.delete'),
                          bg: theme.tone(Tone.rose).bg,
                          fg: theme.tone(Tone.rose).fg,
                          onTap: widget.onDelete,
                          theme: theme,
                        ),
                    ],
                  ),

                  // لیست زیرعادت‌ها
                  if (widget.habit.subHabits.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Divider(height: 1, color: theme.cardSecondaryColor),
                    const SizedBox(height: 8),
                    ...widget.habit.subHabits.map((subHabit) {
                      final isChecked =
                          widget.habit.completedSubHabits.contains(subHabit);
                      return InkWell(
                        onTap: widget.isCompleted
                            ? null
                            : () => widget.onToggleSubHabit?.call(subHabit),
                        borderRadius: BorderRadius.circular(14),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 40),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isChecked
                                        ? primaryColor
                                        : theme.cardSecondaryColor,
                                  ),
                                  child: isChecked
                                      ? Icon(
                                          Icons.check_rounded,
                                          size: 16,
                                          color: theme.onPrimaryColor,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    subHabit,
                                    style: TextStyle(
                                      fontSize: 14,
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
          ),

          // ============================================================
          // HEADER
          // ============================================================
          GestureDetector(
            onTap: _toggleExpansion,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                  horizontal: widget.isCompleted ? 10 : 12,
                  vertical: widget.isCompleted ? 8 : 10),
              decoration: BoxDecoration(
                color: widget.isCompleted ? theme.cardSecondaryColor : cardColor,
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(28),
                  bottom: Radius.circular(28),
                ),
                boxShadow: null,
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
                      width: widget.isCompleted ? 38 : 42,
                      height: widget.isCompleted ? 38 : 42,
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
                        size: widget.isCompleted ? 19 : 20,
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
                                label: isChallenge
                                    ? context.tr('ah.card.challenge')
                                    : context.tr('ah.card.quest'),
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
                                  fontSize: 14,
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
                        if (widget.isCompleted) ...[
                          const SizedBox(height: 2),
                          Text(
                            context.tr('ah.card.completed'),
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textSecondaryColor,
                            ),
                          ),
                        ],
                        if (!widget.isCompleted) ...[
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 5,
                            runSpacing: 5,
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
                          if (widget.habit.subHabits.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildSubProgress(),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// نوار پیشرفت زیرعادت‌ها روی کارت رنگی
  Widget _buildSubProgress() {
    final int total = widget.habit.subHabits.length;
    final int done = widget.habit.subHabits
        .where((s) => widget.habit.completedSubHabits.contains(s))
        .length;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Stack(
              children: [
                Container(
                  height: 6,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
                FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: total == 0 ? 0 : done / total,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFF090909),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          context.tr('ah.card.progress', {'a': '$done', 'b': '$total'}),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF090909),
          ),
        ),
      ],
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

  /// چیپ کوچک گرد؛ پیش‌فرض سفید نیمه‌شفاف روی کارت رنگی
  Widget _chip({
    IconData? icon,
    required String label,
    Color? bg,
    Color fg = const Color(0xFF090909),
    Color? iconColor,
    double height = 22,
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
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
    required ThemeProvider theme,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, size: 22, color: fg),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.textColor,
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
      case 'noon':
        return context.tr('ah.tod.noon');
      case 'afternoon':
        return context.tr('ah.tod.afternoon');
      case 'night':
        return context.tr('ah.tod.night');
      case 'morning':
      default:
        return context.tr('ah.tod.morning');
    }
  }
}
