// lib/features/chat/widgets/active_challenge_widget.dart

import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../models/challenge_invite.dart';

class ActiveChallengeWidget extends StatefulWidget {
  final ChallengeInvite challenge;
  final String currentUserId;
  final Function(String, String) onToggleHabit; // (habitId, userId)
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
    // ✅ تشخیص درست کاربران
    final isCreator = widget.challenge.creatorId == widget.currentUserId;
    final opponentId = isCreator
        ? widget.challenge.opponentId
        : widget.challenge.creatorId;
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
    final isOpponentDayCompleted = widget.challenge.isUserCompletedToday(
      opponentId,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.orange.shade200, width: 2),
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
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: Colors.orange,
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
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
                            color: Colors.grey.shade600,
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
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${(progress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // نوار پیشرفت دایره‌ای کوچک
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey.shade200,
                      color: Colors.orange,
                      strokeWidth: 4,
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
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
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              color: Colors.orange,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),

          // ==================== لیست عادت‌های امروز ====================
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '📋 امروز',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
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
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '✅ انجام شد',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
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
                  final iconColor = Color(habit.iconColor);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        // آیکون عادت
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getIconData(habit.iconName),
                            color: iconColor,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // عنوان عادت
                        Expanded(
                          child: Text(
                            habit.title,
                            style: TextStyle(
                              fontSize: 13,
                              color: const Color(0xFF1A1A2E),
                              decoration: isCompletedByMe
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        // تیک من
                        _buildUserCheck(
                          isCompleted: isCompletedByMe,
                          isMe: true,
                          canToggle: canComplete || canUncomplete,
                          onTap: () => _toggleHabit(habit.id),
                        ),
                        const SizedBox(width: 6),
                        // تیک طرف مقابل
                        _buildUserCheck(
                          isCompleted: isCompletedByOpponent,
                          isMe: false,
                          canToggle: false,
                          onTap: null,
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
                // ✅ استفاده از Flexible به جای Expanded
                flex: 1,
                child: _buildUserStat(
                  name: myName,
                  completedDays: myCompletedDays,
                  totalDays: totalDays,
                  isMe: true,
                ),
              ),
              const SizedBox(width: 8), // ✅ کاهش فاصله
              Flexible(
                // ✅ استفاده از Flexible به جای Expanded
                flex: 1,
                child: _buildUserStat(
                  name: opponentName,
                  completedDays: opponentCompletedDays,
                  totalDays: totalDays,
                  isMe: false,
                ),
              ),
            ],
          ),

          // ==================== پیام انگیزشی ====================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _getMotivationColor(
                myCompletedDays,
                opponentCompletedDays,
                totalDays,
              ).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _getMotivationColor(
                  myCompletedDays,
                  opponentCompletedDays,
                  totalDays,
                ).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getMotivationIcon(
                    myCompletedDays,
                    opponentCompletedDays,
                    totalDays,
                  ),
                  size: 18,
                  color: _getMotivationColor(
                    myCompletedDays,
                    opponentCompletedDays,
                    totalDays,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.challenge.getMotivationalMessage(
                      widget.currentUserId,
                      opponentId,
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF1A1A2E),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ==================== دکمه‌های اقدام ====================
          Row(
            children: [
              // دکمه یادآوری
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showReminderDialog();
                  },
                  icon: const Icon(Icons.alarm, size: 18),
                  label: const Text('یادآوری', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // دکمه انصراف
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showCancelDialog();
                  },
                  icon: const Icon(Icons.exit_to_app, size: 18),
                  label: Text(
                    'انصراف (${(widget.challenge.xpReward * 0.2).toInt()} XP-)',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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
  }) {
    return GestureDetector(
      onTap: canToggle ? onTap : null,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCompleted
              ? (isMe ? Colors.green : Colors.blue)
              : (isMe ? Colors.grey.shade200 : Colors.grey.shade100),
          border: isMe && !isCompleted && canToggle
              ? Border.all(color: Colors.grey.shade400, width: 1.5)
              : null,
        ),
        child: isCompleted
            ? Icon(Icons.check, size: 14, color: Colors.white)
            : isMe && canToggle
            ? Icon(Icons.add, size: 14, color: Colors.grey.shade400)
            : null,
      ),
    );
  }

  // lib/features/chat/widgets/active_challenge_widget.dart

  /// ✅ ویجت نمایش آمار کاربر - نسخه نهایی بدون overflow و بدون خطای ParentData
  Widget _buildUserStat({
    required String name,
    required int completedDays,
    required int totalDays,
    required bool isMe,
  }) {
    final isCompleted = completedDays >= totalDays;
    final displayName = isMe ? 'من' : name;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      decoration: BoxDecoration(
        color: isMe
            ? (isCompleted
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.blue.withValues(alpha: 0.05))
            : (isCompleted
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMe
              ? (isCompleted ? Colors.green : Colors.blue)
              : Colors.grey.shade200,
          width: isMe ? 1.5 : 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ✅ نام کاربر با محدودیت عرض
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 70),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isMe ? '👤' : '👥', style: const TextStyle(fontSize: 9)),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                      color: isMe
                          ? (isCompleted ? Colors.green : Colors.blue)
                          : Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 1),
          // ✅ عدد پیشرفت
          Text(
            '$completedDays/$totalDays',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isCompleted ? Colors.green : const Color(0xFF1A1A2E),
            ),
          ),
          if (isCompleted)
            const Icon(Icons.emoji_events, size: 10, color: Colors.amber),
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
    final penalty = (widget.challenge.xpReward * 0.2).toInt();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                borderRadius: BorderRadius.circular(8),
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
            ),
            child: const Text('بله، انصراف'),
          ),
        ],
      ),
    );
  }

  // lib/features/chat/widgets/active_challenge_widget.dart

  void _showReminderDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              // ✅ صدا زدن onSendReminder
              widget.onSendReminder();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
            ),
            child: const Text('ارسال یادآوری'),
          ),
        ],
      ),
    );
  }

  Color _getMotivationColor(int myDays, int opponentDays, int totalDays) {
    if (myDays >= totalDays || opponentDays >= totalDays) return Colors.green;
    if (myDays > opponentDays) return Colors.orange;
    if (opponentDays > myDays) return Colors.blue;
    return Colors.grey;
  }

  IconData _getMotivationIcon(int myDays, int opponentDays, int totalDays) {
    if (myDays >= totalDays || opponentDays >= totalDays)
      return Icons.emoji_events;
    if (myDays > opponentDays) return Icons.trending_up;
    if (opponentDays > myDays) return Icons.bolt;
    return Icons.handshake;
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
