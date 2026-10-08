// lib/features/arena/widgets/task_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '/providers/theme_provider.dart';
import 'animated_check_overlay.dart';
import '/providers/calendar_provider.dart';

class TaskCard extends StatefulWidget {
  final Task task;
  final bool isCompleted;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(String)? onToggleSubTask;

  const TaskCard({
    super.key,
    required this.task,
    required this.isCompleted,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.onToggleSubTask,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard>
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
    final calendar = Provider.of<CalendarProvider>(context);
    final Color primaryColor = theme.primaryColor;

    // ✅ در تم شب، تسک‌ها کارت تیره می‌گیرند
    final Color cardColor = widget.isCompleted
        ? (theme.isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5))
        : primaryColor;

    // ✅ رنگ متن روی کارت
    final Color textColor =
        theme.isDarkMode ? Colors.white : const Color(0xFF090909);

    // ✅ رنگ آیکون دکمه انجام
    final Color checkButtonBg = widget.isCompleted
        ? (theme.isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0))
        : theme.checkButtonBackground;

    final Color checkIconColor = widget.isCompleted
        ? (theme.isDarkMode ? Colors.grey.shade400 : Colors.white)
        : theme.onCheckButton;

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
                                Expanded(
                                  child: Text(
                                    widget.task.title,
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
                                      color: theme.isDarkMode
                                          ? Colors.white.withOpacity(0.2)
                                          : Colors.white.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '+${widget.task.xpReward}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                const Spacer(),
                                if (widget.task.dueDate != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.isDarkMode
                                          ? Colors.white.withOpacity(0.2)
                                          : Colors.white.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _formatDate(
                                              widget.task.dueDate!, calendar),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Icon(
                                          Icons.calendar_today,
                                          size: 10,
                                          color: textColor,
                                        ),
                                      ],
                                    ),
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
                            widget.isCompleted
                                ? Icons.check
                                : Icons.assignment_outlined,
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
                        color: widget.isCompleted
                            ? Colors.orange
                            : const Color(0xFF090909),
                        onTap: widget.onToggle,
                        isCompleted: widget.isCompleted,
                      ),
                      _buildActionButton(
                        icon: Icons.edit_outlined,
                        label: 'ویرایش',
                        color: const Color(0xFFF59E0B),
                        onTap: widget.onEdit,
                        isCompleted: widget.isCompleted,
                      ),
                      _buildActionButton(
                        icon: Icons.delete_outline,
                        label: 'حذف',
                        color: const Color(0xFFEF4444),
                        onTap: widget.onDelete,
                        isCompleted: widget.isCompleted,
                      ),
                    ],
                  ),

                  // ✅ لیست زیرتسک‌ها
                  if (widget.task.subTasks.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Divider(height: 1, color: theme.borderColor),
                    const SizedBox(height: 8),
                    ...widget.task.subTasks.map((subTask) {
                      final isChecked =
                          widget.task.completedSubTasks.contains(subTask);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: InkWell(
                          onTap: widget.isCompleted
                              ? null
                              : () => widget.onToggleSubTask?.call(subTask),
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
                                        ? (theme.isDarkMode
                                            ? theme.primaryColor
                                            : const Color(0xFF090909))
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isChecked
                                          ? (theme.isDarkMode
                                              ? theme.primaryColor
                                              : const Color(0xFF090909))
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
                                    subTask,
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

  String _formatDate(DateTime date, CalendarProvider calendar) {
    return calendar.formatShort(date);
  }
}
