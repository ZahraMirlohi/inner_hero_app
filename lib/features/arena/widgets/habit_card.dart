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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final Color primaryColor = themeProvider.primaryColor;

    final bool isChallenge = widget.habit.challengeId != null;
    final bool isQuest = widget.habit.questId != null;

    Color getCardColor() {
      if (widget.isCompleted) return const Color(0xFFF5F5F5);
      if (isChallenge || isQuest) return primaryColor;
      final savedColor = widget.habit.backgroundColor;
      if (savedColor != 0) return Color(savedColor);
      return primaryColor;
    }

    final Color cardColor = getCardColor();
    final Color iconColor =
        widget.isCompleted ? Colors.grey.shade500 : cardColor;
    const Color textColor = Color(0xFF090909);

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
                              color: Colors.black.withValues(alpha: 0.06),
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
                                    ),
                                    if (widget.habit.reminders.isNotEmpty)
                                      _buildInfoChip(
                                        icon: Icons.alarm,
                                        label:
                                            '${widget.habit.reminders.length}',
                                        isCompleted: widget.isCompleted,
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
                      checkColor: widget.isCompleted
                          ? Colors.white
                          : const Color(0xFF090909),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: widget.isCompleted
                              ? const Color(0xFFE0E0E0)
                              : const Color(0xFF090909),
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
                            color:
                                widget.isCompleted ? Colors.white : iconColor,
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
                color: widget.isCompleted ? Colors.grey.shade50 : Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade200,
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

                  // ✅ لیست زیرعادت‌ها (بدون عنوان)
                  if (widget.habit.subHabits.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
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
                                          : Colors.grey.shade400,
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
                                          ? Colors.grey.shade500
                                          : const Color(0xFF090909),
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

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    bool isCompleted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF090909),
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            icon,
            size: 11,
            color: const Color(0xFF090909).withOpacity(0.5),
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
