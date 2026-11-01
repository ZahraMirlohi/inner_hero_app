// lib/features/arena/widgets/task_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '/core/app_palette.dart';
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

    // در تم شب، تسک‌ها کارت تیره می‌گیرند
    // تسک‌ها آبی پاستلی می‌گیرند تا از عادت‌ها (رنگ خود کاربر) جدا باشند
    final Color cardColor =
        widget.isCompleted ? theme.cardSecondaryColor : theme.tone(Tone.sky).bg;

    // رنگ متن روی کارت
    final Color textColor =
        theme.isDarkMode ? Colors.white : const Color(0xFF090909);

    // رنگ آیکون دکمه انجام
    final Color checkButtonBg = widget.isCompleted
        ? theme.disabledButtonBackground
        : theme.checkButtonBackground;

    final Color checkIconColor = widget.isCompleted
        ? (theme.isDarkMode ? Colors.grey.shade400 : Colors.white)
        : theme.onCheckButton;

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
                            : Icons.assignment_outlined,
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
                        Text(
                          widget.task.title,
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
                        if (!widget.isCompleted) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _chip('+${widget.task.xpReward}', null),
                              if (widget.task.dueDate != null)
                                _chip(
                                  _formatDate(widget.task.dueDate!, calendar),
                                  Icons.calendar_today_rounded,
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

                  // لیست زیرتسک‌ها
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

  Widget _chip(String label, IconData? icon) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: const Color(0xFF090909)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF090909),
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
