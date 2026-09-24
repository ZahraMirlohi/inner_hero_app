// lib/features/chat/widgets/active_challenge_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../models/challenge_invite.dart';
import '/providers/theme_provider.dart';

class ActiveChallengeWidget extends StatefulWidget {
  final ChallengeInvite challenge;
  final String currentUserId;
  final Function(String, String) onToggleHabit;
  final VoidCallback onCancel;
  final VoidCallback onSendReminder;

  const ActiveChallengeWidget({
    super.key,
    required this.challenge,
    required this.currentUserId,
    required this.onToggleHabit,
    required this.onCancel,
    required this.onSendReminder,
  });

  @override
  State<ActiveChallengeWidget> createState() => _ActiveChallengeWidgetState();
}

class _ActiveChallengeWidgetState extends State<ActiveChallengeWidget> {
  bool _isToggling = false;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final primaryColor = theme.primaryColor;

    final isCreator = widget.challenge.creatorId == widget.currentUserId;
    final opponentId =
        isCreator ? widget.challenge.opponentId : widget.challenge.creatorId;
    final opponentName = isCreator
        ? widget.challenge.opponentName
        : widget.challenge.creatorName;
    final myName = isCreator
        ? widget.challenge.creatorName
        : widget.challenge.opponentName;

    final currentDay = widget.challenge.currentDay;
    final totalDays = widget.challenge.duration;
    final progress = widget.challenge.overallProgress;

    final myCompletedDays = widget.challenge.getUserCompletedDays(
      widget.currentUserId,
    );
    final opponentCompletedDays = widget.challenge.getUserCompletedDays(
      opponentId,
    );

    final isMyDayCompleted = widget.challenge.isUserCompletedToday(
      widget.currentUserId,
    );

    final canComplete = widget.challenge.canUserCompleteToday(
      widget.currentUserId,
    );
    final canUncomplete = widget.challenge.canUserUncompleteToday(
      widget.currentUserId,
    );

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ==================== هدر ====================
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.emoji_events,
                  color: primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.challenge.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Text(
                          'روز $currentDay از $totalDays',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textSecondaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${(progress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // نوار پیشرفت دایره‌ای
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey.shade200,
                      color: primaryColor,
                      strokeWidth: 4,
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ==================== نوار پیشرفت خطی ====================
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              color: primaryColor,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),

          // ==================== لیست عادت‌های امروز ====================
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '📋 امروز',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: theme.textColor,
                      ),
                    ),
                    const Spacer(),
                    if (isMyDayCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '✅ انجام شد',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      )
                    else if (canComplete)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '⏳ در انتظار',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ...widget.challenge.habits.map((habit) {
                  final isCompletedByMe = _isHabitCompletedByUser(
                    habit.id,
                    widget.currentUserId,
                  );
                  final isCompletedByOpponent = _isHabitCompletedByUser(
                    habit.id,
                    opponentId,
                  );
                  final iconColor = primaryColor;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _getIconData(habit.iconName),
                            color: iconColor,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            habit.title,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.textColor,
                              decoration: isCompletedByMe
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        _buildUserCheck(
                          isCompleted: isCompletedByMe,
                          isMe: true,
                          canToggle: canComplete || canUncomplete,
                          onTap: () => _toggleHabit(habit.id),
                          primaryColor: primaryColor,
                        ),
                        const SizedBox(width: 6),
                        _buildUserCheck(
                          isCompleted: isCompletedByOpponent,
                          isMe: false,
                          canToggle: false,
                          onTap: null,
                          primaryColor: primaryColor,
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ==================== آمار مقایسه‌ای ====================
          Row(
            children: [
              Flexible(
                flex: 1,
                child: _buildUserStat(
                  name: myName,
                  completedDays: myCompletedDays,
                  totalDays: totalDays,
                  isMe: true,
                  primaryColor: primaryColor,
                  theme: theme,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 1,
                child: _buildUserStat(
                  name: opponentName,
                  completedDays: opponentCompletedDays,
                  totalDays: totalDays,
                  isMe: false,
                  primaryColor: primaryColor,
                  theme: theme,
                ),
              ),
            ],
          ),

          // ==================== دکمه‌های اقدام ====================
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showReminderDialog(primaryColor);
                  },
                  icon: Icon(Icons.alarm, size: 18, color: primaryColor),
                  label: Text(
                    'یادآوری',
                    style: TextStyle(fontSize: 12, color: primaryColor),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(color: primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showCancelDialog();
                  },
                  icon: const Icon(
                    Icons.exit_to_app,
                    size: 18,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'انصراف',
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== ویجت‌های کمکی ====================

  Widget _buildUserCheck({
    required bool isCompleted,
    required bool isMe,
    required bool canToggle,
    required VoidCallback? onTap,
    required Color primaryColor,
  }) {
    return GestureDetector(
      onTap: canToggle ? onTap : null,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCompleted
              ? primaryColor
              : (isMe ? Colors.grey.shade200 : Colors.grey.shade100),
          border: isMe && !isCompleted && canToggle
              ? Border.all(
                  color: primaryColor.withValues(alpha: 0.5),
                  width: 1.5,
                )
              : null,
        ),
        child: isCompleted
            ? const Icon(Icons.check, size: 14, color: Colors.white)
            : isMe && canToggle
                ? Icon(Icons.add, size: 14, color: primaryColor)
                : null,
      ),
    );
  }

  Widget _buildUserStat({
    required String name,
    required int completedDays,
    required int totalDays,
    required bool isMe,
    required Color primaryColor,
    required ThemeProvider theme,
  }) {
    final isCompleted = completedDays >= totalDays;
    final displayName = isMe ? 'من' : name;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color:
            isMe ? primaryColor.withValues(alpha: 0.08) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe
              ? (isCompleted
                  ? primaryColor
                  : primaryColor.withValues(alpha: 0.3))
              : Colors.grey.shade200,
          width: isMe ? 1.5 : 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 70),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isMe ? '👤' : '👥',
                  style: const TextStyle(fontSize: 9),
                ),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                      color: isMe ? primaryColor : theme.textSecondaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$completedDays/$totalDays',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isCompleted ? primaryColor : theme.textColor,
            ),
          ),
          if (isCompleted)
            Icon(Icons.emoji_events, size: 10, color: primaryColor),
        ],
      ),
    );
  }

  // ==================== متدهای کمکی ====================

  bool _isHabitCompletedByUser(String habitId, String userId) {
    final progress = widget.challenge.progress[userId];
    if (progress == null) return false;

    final todayIndex = widget.challenge.currentDay - 1;
    if (todayIndex < 0 || todayIndex >= progress.length) return false;

    return progress[todayIndex].completedHabitIds.contains(habitId);
  }

  void _toggleHabit(String habitId) async {
    if (_isToggling) return;

    setState(() {
      _isToggling = true;
    });

    final isCompleted = _isHabitCompletedByUser(habitId, widget.currentUserId);

    await widget.onToggleHabit(
      habitId,
      isCompleted ? 'uncomplete' : 'complete',
    );

    if (mounted) {
      setState(() {
        _isToggling = false;
      });
    }
  }

  void _showCancelDialog() {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final primaryColor = theme.primaryColor;
    final penalty = (widget.challenge.xpReward * 0.2).toInt();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('انصراف از چالش'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('آیا از انصراف از این چالش مطمئن هستید؟'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'با انصراف، $penalty XP از امتیاز شما کسر خواهد شد',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onCancel();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('بله، انصراف'),
          ),
        ],
      ),
    );
  }

  void _showReminderDialog(Color primaryColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('⏰ یادآوری'),
        content: const Text(
          'یادآوری برای هم‌مسیر شما ارسال خواهد شد.\n\n'
          'آیا مطمئن هستید؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onSendReminder();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('ارسال یادآوری'),
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
}
