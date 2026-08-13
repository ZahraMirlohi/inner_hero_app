// lib/features/chat/widgets/today_habits_list_widget.dart

import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../models/today_habits_list.dart';

class TodayHabitsListWidget extends StatelessWidget {
  final TodayHabitsList data;
  final bool isMe;

  const TodayHabitsListWidget({
    super.key,
    required this.data,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    final jalaliDate = Jalali.fromDateTime(data.date);
    final dateString =
        '${jalaliDate.day} ${_getMonthName(jalaliDate.month)} ${jalaliDate.year}';
    final rate = (data.completionRate * 100).toInt();
    final message = data.completionMessage;

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF4A90E2) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
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
              const Text('📋', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'لیست امروز',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isMe ? Colors.white : const Color(0xFF1A1A2E),
                      ),
                    ),
                    Text(
                      dateString,
                      style: TextStyle(
                        fontSize: 11,
                        color: isMe ? Colors.white70 : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.2)
                      : _getRateColor(rate).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$rate%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isMe ? Colors.white : _getRateColor(rate),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ==================== آمار ====================
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              color: isMe
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(
                  label: 'کل',
                  value: '${data.totalItems}',
                  isMe: isMe,
                ),
                _buildStatItem(
                  label: 'انجام شده',
                  value: '${data.completedItems}',
                  isMe: isMe,
                ),
                _buildStatItem(
                  label: 'باقیمانده',
                  value: '${data.totalItems - data.completedItems}',
                  isMe: isMe,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ==================== لیست عادت‌ها ====================
          if (data.habits.isNotEmpty) ...[
            const Text(
              '📌 عادت‌ها',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            ...data.habits.map((habit) => _buildHabitItem(habit)),
            const SizedBox(height: 8),
          ],

          // ==================== لیست تسک‌ها ====================
          if (data.tasks.isNotEmpty) ...[
            const Text(
              '📌 تسک‌ها',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            ...data.tasks.map((task) => _buildTaskItem(task)),
            const SizedBox(height: 8),
          ],

          // ==================== لیست چالش‌ها ====================
          if (data.challenges.isNotEmpty) ...[
            const Text(
              '🏆 چالش‌ها',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            ...data.challenges.map(
              (challenge) => _buildChallengeItem(challenge),
            ),
            const SizedBox(height: 8),
          ],

          // ==================== لیست ماموریت‌ها ====================
          if (data.quests.isNotEmpty) ...[
            const Text(
              '🎯 ماموریت‌ها',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            ...data.quests.map((quest) => _buildQuestItem(quest)),
            const SizedBox(height: 8),
          ],

          // ==================== فوتر ====================
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                data.userName,
                style: TextStyle(
                  fontSize: 9,
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.6)
                      : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== ویجت‌های آیتم‌ها ====================

  Widget _buildHabitItem(TodayHabitItem habit) {
    final iconColor = Color(habit.iconColor);
    final isCompleted = habit.isCompleted;
    final isChallenge = habit.isChallenge;
    final isQuest = habit.isQuest;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          // آیکون
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.green.withValues(alpha: 0.15)
                  : iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _getIconData(habit.iconName),
              color: isCompleted ? Colors.green : iconColor,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          // عنوان
          Expanded(
            child: Text(
              habit.title,
              style: TextStyle(
                fontSize: 13,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted
                    ? (isMe ? Colors.white60 : Colors.grey)
                    : (isMe ? Colors.white : const Color(0xFF1A1A2E)),
                fontWeight: isCompleted ? FontWeight.normal : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // برچسب چالش/ماموریت
          if (isChallenge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '🏆',
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? Colors.white70 : Colors.orange,
                ),
              ),
            ),
          if (isQuest)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '🎯',
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? Colors.white70 : Colors.purple,
                ),
              ),
            ),
          const SizedBox(width: 4),
          // وضعیت
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? Colors.green
                  : (isMe
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.grey.shade200),
            ),
            child: isCompleted
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(TodayTaskItem task) {
    final isCompleted = task.isCompleted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.assignment,
              color: isCompleted ? Colors.green : Colors.grey.shade500,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                fontSize: 13,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted
                    ? (isMe ? Colors.white60 : Colors.grey)
                    : (isMe ? Colors.white : const Color(0xFF1A1A2E)),
                fontWeight: isCompleted ? FontWeight.normal : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? Colors.green
                  : (isMe
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.grey.shade200),
            ),
            child: isCompleted
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeItem(TodayChallengeItem challenge) {
    final isCompleted = challenge.isCompleted;
    final progress = challenge.progress;
    final totalDays = challenge.totalDays;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.flag,
              color: isCompleted ? Colors.green : Colors.orange,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '🏆 ${challenge.title}',
              style: TextStyle(
                fontSize: 13,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted
                    ? (isMe ? Colors.white60 : Colors.grey)
                    : (isMe ? Colors.white : const Color(0xFF1A1A2E)),
                fontWeight: isCompleted ? FontWeight.normal : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isCompleted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$progress/$totalDays',
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? Colors.white70 : Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(width: 4),
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? Colors.green
                  : (isMe
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.grey.shade200),
            ),
            child: isCompleted
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildQuestItem(TodayQuestItem quest) {
    final isCompleted = quest.isCompleted;
    final progress = quest.progress;
    final targetCount = quest.targetCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.purple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.stars,
              color: isCompleted ? Colors.green : Colors.purple,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '🎯 ${quest.title}',
              style: TextStyle(
                fontSize: 13,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted
                    ? (isMe ? Colors.white60 : Colors.grey)
                    : (isMe ? Colors.white : const Color(0xFF1A1A2E)),
                fontWeight: isCompleted ? FontWeight.normal : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isCompleted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$progress/$targetCount',
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? Colors.white70 : Colors.purple,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(width: 4),
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? Colors.green
                  : (isMe
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.grey.shade200),
            ),
            child: isCompleted
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
        ],
      ),
    );
  }

  // ==================== ویجت‌های کمکی ====================

  Widget _buildStatItem({
    required String label,
    required String value,
    required bool isMe,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isMe ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: isMe ? Colors.white70 : Colors.grey.shade500,
          ),
        ),
      ],
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

  String _getMonthName(int month) {
    const months = [
      'فروردین',
      'اردیبهشت',
      'خرداد',
      'تیر',
      'مرداد',
      'شهریور',
      'مهر',
      'آبان',
      'آذر',
      'دی',
      'بهمن',
      'اسفند',
    ];
    return months[month - 1];
  }

  Color _getRateColor(int percent) {
    if (percent >= 80) return Colors.green;
    if (percent >= 60) return Colors.orange;
    if (percent >= 40) return Colors.blue;
    return Colors.grey;
  }

  IconData _getMotivationIcon(int percent) {
    if (percent >= 80) return Icons.emoji_events;
    if (percent >= 60) return Icons.thumb_up;
    if (percent >= 40) return Icons.trending_up;
    return Icons.rocket;
  }
}
