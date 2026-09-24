// lib/features/arena/widgets/task_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '/services/date_service.dart';
import '/providers/theme_provider.dart';

class TaskCard extends StatefulWidget {
  final Task task;
  final bool isCompleted;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TaskCard({
    super.key,
    required this.task,
    required this.isCompleted,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final Color primaryColor = themeProvider.primaryColor;
    final Color primaryLight = themeProvider.primaryLight; // ✅ اضافه شد

    // ✅ رنگ کارت تسک - مشتق روشن رنگ اصلی
    final Color cardColor = widget.isCompleted
        ? const Color(0xFFF5F5F5)
        : primaryLight; // ✅ از primaryLight استفاده می‌کند

    // ✅ رنگ آیکون داخل دایره مشکی = هم‌رنگ باکس کارت
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
              // ✅ اجبار به LTR برای اینکه دایره در راست قرار گیرد
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ✅ MAIN PILL - سمت چپ
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
                                // ✅ عنوان - راست‌چین
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
                                    // ✅ اجبار به RTL برای متن فارسی
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
                                    child: const Text(
                                      '+10',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF090909),
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
                                      color: Colors.white.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _formatDate(widget.task.dueDate!),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF090909),
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        const Icon(
                                          Icons.calendar_today,
                                          size: 10,
                                          color: Color(0xFF090909),
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

                    // ✅ فاصله بین باکس کارت و دایره آیکون
                    const SizedBox(width: 10),

                    // ✅ دایره آیکون - سمت راست
                    GestureDetector(
                      onTap: widget.onToggle,
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
                            widget.isCompleted
                                ? Icons.check
                                : Icons.assignment_outlined,
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
                    color: primaryColor.withOpacity(0.15),
                    width: 1,
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
                    color: widget.isCompleted ? Colors.orange : primaryColor,
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
            child: Icon(
              icon,
              size: 16,
              color: Colors.white,
            ),
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

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}
