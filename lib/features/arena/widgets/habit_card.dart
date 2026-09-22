// lib/features/arena/widgets/habit_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/habit_model.dart';
import '../screens/habit_detail_screen.dart';
import '/providers/theme_provider.dart';

class HabitCard extends StatefulWidget {
  final Habit habit;
  final bool isCompleted;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onTimer;
  final VoidCallback? onTap;

  const HabitCard({
    super.key,
    required this.habit,
    required this.isCompleted,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.onTimer,
    this.onTap,
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

// lib/features/arena/widgets/habit_card.dart

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final Color primaryColor = themeProvider.primaryColor;

    final bool isChallenge = widget.habit.challengeId != null;
    final bool isQuest = widget.habit.questId != null;
    final bool isEditable = !isChallenge && !isQuest;

    // ✅ رنگ accent - برای چالش/ماموریت سفید، برای عادت معمولی رنگ کاربر
    Color getAccentColor() {
      // ✅ چالش یا ماموریت → سفید
      if (isChallenge || isQuest) {
        return Colors.white;
      }

      // ✅ انجام شده → مشکی
      if (widget.isCompleted) {
        return const Color(0xFF090909);
      }

      // ✅ عادت معمولی → رنگ کاربر
      final savedColor = widget.habit.backgroundColor;
      if (savedColor != null && savedColor != 0) {
        return Color(savedColor);
      }
      return primaryColor;
    }

    final Color accentColor = getAccentColor();

    const Color textColor = Color(0xFF090909);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // ============================================================
          // HEADER
          // ============================================================
          GestureDetector(
            onTap: _toggleExpansion,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ✅ MAIN PILL
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: widget.isCompleted
                            ? Colors.grey.shade100
                            : Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        // ✅ استروک: سفید برای چالش/ماموریت، رنگی برای عادت
                        border: Border.all(
                          color: accentColor,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ردیف اول: عنوان + برچسب
                          Row(
                            children: [
                              const Spacer(),
                              Expanded(
                                flex: 5,
                                child: Text(
                                  widget.habit.title,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                    decoration: widget.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isChallenge || isQuest) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (isChallenge
                                            ? Colors.orange
                                            : Colors.purple)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    isChallenge ? '🏆 چالش' : '🎯 ماموریت',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isChallenge
                                          ? Colors.orange
                                          : Colors.purple,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          // ردیف دوم: XP + تگ‌ها
                          Row(
                            children: [
                              if (!widget.isCompleted)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    '+${widget.habit.xpReward} XP',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF090909),
                                    ),
                                  ),
                                ),
                              const Spacer(),
                              Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  _buildInfoChip(
                                    icon: Icons.access_time,
                                    label: _getTimeOfDayText(
                                        widget.habit.timeOfDay),
                                    accentColor: accentColor,
                                    isCompleted: widget.isCompleted,
                                  ),
                                  if (widget.habit.reminders.isNotEmpty)
                                    _buildInfoChip(
                                      icon: Icons.alarm,
                                      label: '${widget.habit.reminders.length}',
                                      accentColor: accentColor,
                                      isCompleted: widget.isCompleted,
                                    ),
                                  if (widget.habit.currentStreak > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.orange.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.local_fire_department,
                                            size: 12,
                                            color: Colors.orange,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${widget.habit.currentStreak}',
                                            style: const TextStyle(
                                              fontSize: 11,
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

                  // ✅ نقطه جداکننده
                  Container(
                    width: 8,
                    height: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: accentColor, // ✅ سفید/رنگی/مشکی
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: (isChallenge || isQuest)
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                  ),

                  // ✅ دایره آیکون
                  GestureDetector(
                    onTap: widget.onToggle,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: accentColor, // ✅ سفید/رنگی/مشکی
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          _getIconData(widget.habit.iconName),
                          color: const Color(0xFF090909), // ✅ مشکی
                          size: 22,
                        ),
                      ),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: widget.isCompleted ? Colors.grey.shade100 : Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border(
                  top: BorderSide(
                    color: (isChallenge || isQuest)
                        ? Colors.white.withOpacity(0.5)
                        : accentColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: widget.isCompleted
                        ? Icons.refresh
                        : Icons.check_circle_outline,
                    label: widget.isCompleted ? 'برگردان' : 'انجام',
                    color: widget.isCompleted
                        ? Colors.orange
                        : (isChallenge || isQuest)
                            ? const Color(0xFF090909)
                            : accentColor,
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
                  if (isEditable)
                    _buildActionButton(
                      icon: Icons.edit_outlined,
                      label: 'ویرایش',
                      color: const Color(0xFFF59E0B),
                      onTap: widget.onEdit,
                      isCompleted: widget.isCompleted,
                    ),
                  if (isEditable)
                    _buildActionButton(
                      icon: Icons.delete_outline,
                      label: 'حذف',
                      color: const Color(0xFFEF4444),
                      onTap: widget.onDelete,
                      isCompleted: widget.isCompleted,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ویجت‌های کمکی ====================

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color accentColor,
    bool isCompleted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color:
            isCompleted ? Colors.grey.shade200 : accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF090909),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            icon,
            size: 13,
            color: const Color(0xFF090909).withOpacity(0.7),
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
          // ✅ دایره کوچک‌تر
          Container(
            width: 36, // ← از 44 به 36
            height: 36, // ← از 44 به 36
            decoration: BoxDecoration(
              color: finalColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: finalColor.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 18, // ← از 22 به 18
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10, // ← از 11 به 10
              color: finalColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  // ==================== متدهای کمکی ====================

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
