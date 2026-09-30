// lib/features/chat/widgets/active_challenge_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../models/challenge_invite.dart';
import '../utils/chat_colors.dart';
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

    // ✅ تشخیص اینکه کاربر فعلی فرستنده است یا گیرنده
    final bool isMe = widget.challenge.creatorId == widget.currentUserId;

    // ✅ رنگ‌های استاندارد
    final Color bgColor =
        isMe ? ChatColors.myBubble(theme) : ChatColors.otherBubble(theme);
    final Color textColor = isMe
        ? ChatColors.myBubbleText(theme)
        : ChatColors.otherBubbleText(theme);
    final Color textSecondary = isMe
        ? ChatColors.myBubbleTextSecondary(theme)
        : ChatColors.otherBubbleTextSecondary(theme);

    final opponentId =
        isMe ? widget.challenge.opponentId : widget.challenge.creatorId;
    final opponentName =
        isMe ? widget.challenge.opponentName : widget.challenge.creatorName;
    final myName =
        isMe ? widget.challenge.creatorName : widget.challenge.opponentName;

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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: textColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
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
          // ==================== هدر ====================
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.emoji_events,
                  color: textColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.challenge.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Text(
                          'روز $currentDay از $totalDays',
                          style: TextStyle(
                            fontSize: 10,
                            color: textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: textColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${(progress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: textColor,
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
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      backgroundColor: textColor.withValues(alpha: 0.15),
                      color: textColor,
                      strokeWidth: 3.5,
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ==================== نوار پیشرفت خطی ====================
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: textColor.withValues(alpha: 0.15),
              color: textColor,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),

          // ==================== لیست عادت‌های امروز ====================
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: textColor.withValues(alpha: 0.12),
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
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    if (isMyDayCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: textColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '✅ انجام شد',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      )
                    else if (canComplete)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '⏳ در انتظار',
                          style: TextStyle(
                            fontSize: 9,
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

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: textColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getIconData(habit.iconName),
                            color: textColor,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            habit.title,
                            style: TextStyle(
                              fontSize: 11,
                              color: textColor,
                              decoration: isCompletedByMe
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildUserCheck(
                          isCompleted: isCompletedByMe,
                          isMe: true,
                          canToggle: canComplete || canUncomplete,
                          onTap: () => _toggleHabit(habit.id),
                          textColor: textColor,
                          bgColor: bgColor,
                        ),
                        const SizedBox(width: 4),
                        _buildUserCheck(
                          isCompleted: isCompletedByOpponent,
                          isMe: false,
                          canToggle: false,
                          onTap: null,
                          textColor: textColor,
                          bgColor: bgColor,
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 10),

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
                  textColor: textColor,
                  textSecondary: textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                flex: 1,
                child: _buildUserStat(
                  name: opponentName,
                  completedDays: opponentCompletedDays,
                  totalDays: totalDays,
                  isMe: false,
                  textColor: textColor,
                  textSecondary: textSecondary,
                ),
              ),
            ],
          ),

          // ==================== دکمه‌های اقدام ====================
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showReminderDialog(textColor);
                  },
                  icon: Icon(Icons.alarm, size: 14, color: textColor),
                  label: Text(
                    'یادآوری',
                    style: TextStyle(fontSize: 11, color: textColor),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: BorderSide(
                      color: textColor.withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showCancelDialog(textColor, bgColor);
                  },
                  icon: const Icon(
                    Icons.exit_to_app,
                    size: 14,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'انصراف',
                    style: TextStyle(fontSize: 11, color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
    required Color textColor,
    required Color bgColor,
  }) {
    return GestureDetector(
      onTap: canToggle ? onTap : null,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCompleted ? textColor : textColor.withValues(alpha: 0.15),
          border: isMe && !isCompleted && canToggle
              ? Border.all(
                  color: textColor.withValues(alpha: 0.5),
                  width: 1.5,
                )
              : null,
        ),
        child: isCompleted
            ? Icon(Icons.check, size: 12, color: bgColor)
            : isMe && canToggle
                ? Icon(Icons.add, size: 12, color: textColor)
                : null,
      ),
    );
  }

  Widget _buildUserStat({
    required String name,
    required int completedDays,
    required int totalDays,
    required bool isMe,
    required Color textColor,
    required Color textSecondary,
  }) {
    final isCompleted = completedDays >= totalDays;
    final displayName = isMe ? 'من' : name;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: isMe ? 0.1 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted ? textColor : textColor.withValues(alpha: 0.2),
          width: isMe ? 1.5 : 0.8,
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
                      color: textColor,
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
              color: textColor,
            ),
          ),
          if (isCompleted) Icon(Icons.emoji_events, size: 10, color: textColor),
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

  void _showCancelDialog(Color textColor, Color bgColor) {
    final penalty = (widget.challenge.xpReward * 0.2).toInt();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
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
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.2),
                ),
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
                        fontSize: 12,
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

  void _showReminderDialog(Color textColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
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
              backgroundColor: textColor,
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
