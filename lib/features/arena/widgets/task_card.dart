// lib/features/arena/widgets/task_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '/core/app_palette.dart';
import '/l10n/app_strings.dart';
import '/providers/theme_provider.dart';
import 'animated_check_overlay.dart';
import '/providers/calendar_provider.dart';

// ============================================================
// ابزارهای مشترک میدان: اسنک‌بار و دیالوگ حذف (طبق ArenaStates)
// ============================================================

enum ArenaSnackKind { success, warning, error, dark, info }

/// پیام کوتاه گرد و شناور؛ بالای نوار ناوبری نمایش داده می‌شود.
void showArenaSnack(
  BuildContext context,
  String message, {
  ArenaSnackKind kind = ArenaSnackKind.success,
  Duration duration = const Duration(seconds: 2),
  String? actionLabel,
  VoidCallback? onAction,
  bool clearPrevious = false,
}) {
  final theme = Provider.of<ThemeProvider>(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);
  if (clearPrevious) messenger.clearSnackBars();

  Color bg;
  Color fg;
  Color actionColor;
  switch (kind) {
    case ArenaSnackKind.success:
      bg = theme.successColor;
      fg = const Color(0xFF090909);
      actionColor = const Color(0xFF090909);
      break;
    case ArenaSnackKind.warning:
      bg = theme.tone(Tone.apricot).bg;
      fg = theme.tone(Tone.apricot).fg;
      actionColor = fg;
      break;
    case ArenaSnackKind.error:
      bg = theme.errorColor;
      fg = Colors.white;
      actionColor = Colors.white;
      break;
    case ArenaSnackKind.info:
      bg = theme.primarySoft;
      fg = theme.textColor;
      actionColor = theme.textColor;
      break;
    case ArenaSnackKind.dark:
      bg = theme.isDarkMode
          ? theme.cardSecondaryColor
          : const Color(0xFF090909);
      fg = theme.isDarkMode ? theme.textColor : Colors.white;
      actionColor = theme.effectivePrimary;
      break;
  }

  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: bg,
      elevation: 0,
      duration: duration,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                messenger.hideCurrentSnackBar();
                onAction();
              },
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 12),
                child: Text(
                  actionLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: actionColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// دیالوگ تأیید حذف؛ true یعنی «حذف».
Future<bool?> showArenaDeleteDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: const Color(0xFF090909).withValues(alpha: 0.42),
    builder: (ctx) {
      final theme = Provider.of<ThemeProvider>(ctx, listen: false);
      final rose = theme.tone(Tone.rose);
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(32),
            boxShadow: theme.softShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(color: rose.bg, shape: BoxShape.circle),
                child: Icon(Icons.delete_outline_rounded,
                    size: 28, color: rose.fg),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: theme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.cardSecondaryColor,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Text(
                          ctx.tr('common.cancel'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: theme.textColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.errorColor,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Text(
                          ctx.tr('common.delete'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// حالت خالی یا آفلاین؛ دایرهٔ ۷۲ با آیکون، عنوان، توضیح و دکمهٔ اختیاری.
class ArenaStateView extends StatelessWidget {
  final IconData icon;
  final Tone tone;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const ArenaStateView({
    super.key,
    required this.icon,
    this.tone = Tone.lime,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final t = theme.tone(tone);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: theme.softShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: tone == Tone.lime ? theme.cardSecondaryColor : t.bg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                size: 32,
                color: tone == Tone.lime ? theme.textColor : t.fg),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.textColor,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: theme.textSecondaryColor),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onAction,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (actionIcon != null) ...[
                      Icon(actionIcon, size: 20, color: theme.onPrimaryColor),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      actionLabel!,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.onPrimaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// حالت بارگذاری: حلقهٔ ۵۶ داخل کارت سفید.
class ArenaLoadingView extends StatelessWidget {
  final String? message;
  const ArenaLoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: theme.softShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 6,
              color: theme.primaryColor,
              backgroundColor: theme.cardSecondaryColor,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            message ?? context.tr('ah.state.loading'),
            style: TextStyle(fontSize: 14, color: theme.textSecondaryColor),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// کارت وظیفه
// ============================================================

class TaskCard extends StatefulWidget {
  final Task task;
  final bool isCompleted;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(String)? onToggleSubTask;

  /// اگر داده شود، دکمهٔ «جزئیات» در کشوی کارت دیده می‌شود.
  final VoidCallback? onDetails;

  const TaskCard({
    super.key,
    required this.task,
    required this.isCompleted,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.onToggleSubTask,
    this.onDetails,
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

    // وظیفه‌ها پاستلی کهربایی‌اند تا از عادت‌ها جدا باشند
    final Color cardColor = theme.tone(Tone.apricot).bg;
    final Color onCard = cardColor.computeLuminance() > 0.4
        ? const Color(0xFF090909)
        : Colors.white;

    final Color checkIconColor = widget.isCompleted
        ? (theme.isDarkMode ? Colors.grey.shade400 : Colors.white)
        : cardColor;

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                      if (widget.onDetails != null)
                        _buildActionButton(
                          icon: Icons.info_outline_rounded,
                          label: context.tr('ah.card.details'),
                          bg: theme.tone(Tone.sky).bg,
                          fg: theme.tone(Tone.sky).fg,
                          onTap: widget.onDetails!,
                          theme: theme,
                        ),
                      _buildActionButton(
                        icon: Icons.edit_outlined,
                        label: context.tr('ah.card.edit'),
                        bg: theme.tone(Tone.apricot).bg,
                        fg: theme.tone(Tone.apricot).fg,
                        onTap: widget.onEdit,
                        theme: theme,
                      ),
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

                  // لیست زیرتسک‌ها
                  if (widget.task.subTasks.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Divider(height: 1, color: theme.cardSecondaryColor),
                    const SizedBox(height: 8),
                    ...widget.task.subTasks.map((subTask) {
                      final isChecked =
                          widget.task.completedSubTasks.contains(subTask);
                      return InkWell(
                        onTap: widget.isCompleted
                            ? null
                            : () => widget.onToggleSubTask?.call(subTask),
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
                                        ? theme.primaryColor
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
                                    subTask,
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
                            : Icons.assignment_outlined,
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
                        Text(
                          widget.task.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: widget.isCompleted
                                ? FontWeight.w600
                                : FontWeight.w700,
                            color: widget.isCompleted
                                ? theme.textSecondaryColor
                                : onCard,
                            decoration: widget.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!widget.isCompleted) ...[
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: [
                              _chip('+${widget.task.xpReward}', null),
                              if (widget.task.dueDate != null)
                                _chip(
                                  calendar.formatShort(widget.task.dueDate!),
                                  Icons.calendar_today_rounded,
                                ),
                            ],
                          ),
                          if (widget.task.subTasks.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildSubProgress(onCard),
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

  /// نوار پیشرفت زیرتسک‌ها روی کارت رنگی
  Widget _buildSubProgress(Color onCard) {
    final int total = widget.task.subTasks.length;
    final int done = widget.task.subTasks
        .where((s) => widget.task.completedSubTasks.contains(s))
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
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: onCard,
          ),
        ),
      ],
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
}
