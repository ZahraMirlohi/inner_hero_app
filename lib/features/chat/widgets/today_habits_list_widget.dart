// lib/features/chat/widgets/today_habits_list_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../models/today_habits_list.dart';
import '/providers/theme_provider.dart';

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
    final theme = Provider.of<ThemeProvider>(context);
    final primaryColor = theme.primaryColor;

    final jalaliDate = Jalali.fromDateTime(data.date);
    final dateString =
        '${jalaliDate.day} ${_getMonthName(jalaliDate.month)} ${jalaliDate.year}';
    final rate = (data.completionRate * 100).toInt();

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
          color: primaryColor.withValues(alpha: 0.2),
          width: 1,
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
                  Icons.checklist,
                  color: primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'لیست امروز',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: theme.textColor,
                      ),
                    ),
                    Text(
                      dateString,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textSecondaryColor,
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
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '$rate%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ==================== آمار ====================
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(
                  label: 'کل',
                  value: '${data.totalItems}',
                  theme: theme,
                ),
                _buildStatItem(
                  label: 'انجام شده',
                  value: '${data.completedItems}',
                  theme: theme,
                ),
                _buildStatItem(
                  label: 'باقیمانده',
                  value: '${data.totalItems - data.completedItems}',
                  theme: theme,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ==================== لیست عادت‌ها ====================
          if (data.habits.isNotEmpty) ...[
            _buildSectionLabel('📌 عادت‌ها', theme),
            const SizedBox(height: 4),
            ...data.habits.map(
              (habit) => _buildHabitItem(habit, theme, primaryColor),
            ),
            const SizedBox(height: 8),
          ],

          // ==================== لیست تسک‌ها ====================
          if (data.tasks.isNotEmpty) ...[
            _buildSectionLabel('📌 تسک‌ها', theme),
            const SizedBox(height: 4),
            ...data.tasks.map(
              (task) => _buildTaskItem(task, theme, primaryColor),
            ),
            const SizedBox(height: 8),
          ],

          // ==================== لیست چالش‌ها ====================
          if (data.challenges.isNotEmpty) ...[
            _buildSectionLabel('🏆 چالش‌ها', theme),
            const SizedBox(height: 4),
            ...data.challenges.map(
              (challenge) =>
                  _buildChallengeItem(challenge, theme, primaryColor),
            ),
            const SizedBox(height: 8),
          ],

          // ==================== لیست ماموریت‌ها ====================
          if (data.quests.isNotEmpty) ...[
            _buildSectionLabel('🎯 ماموریت‌ها', theme),
            const SizedBox(height: 4),
            ...data.quests.map(
              (quest) => _buildQuestItem(quest, theme, primaryColor),
            ),
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
                  color: theme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, ThemeProvider theme) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: theme.textSecondaryColor,
      ),
    );
  }

  // ==================== ویجت‌های آیتم‌ها ====================

  Widget _buildHabitItem(
    TodayHabitItem habit,
    ThemeProvider theme,
    Color primaryColor,
  ) {
    final isCompleted = habit.isCompleted;
    final isChallenge = habit.isChallenge;
    final isQuest = habit.isQuest;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: isCompleted
                  ? primaryColor.withValues(alpha: 0.12)
                  : primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getIconData(habit.iconName),
              color: primaryColor,
              size: 15,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              habit.title,
              style: TextStyle(
                fontSize: 13,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? theme.textSecondaryColor : theme.textColor,
                fontWeight: isCompleted ? FontWeight.normal : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isChallenge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '🏆',
                style: TextStyle(fontSize: 10, color: primaryColor),
              ),
            ),
          if (isQuest)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '🎯',
                style: TextStyle(fontSize: 10, color: primaryColor),
              ),
            ),
          const SizedBox(width: 4),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted ? primaryColor : Colors.grey.shade200,
            ),
            child: isCompleted
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(
    TodayTaskItem task,
    ThemeProvider theme,
    Color primaryColor,
  ) {
    final isCompleted = task.isCompleted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: isCompleted
                  ? primaryColor.withValues(alpha: 0.12)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.assignment,
              color: isCompleted ? primaryColor : theme.textSecondaryColor,
              size: 15,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                fontSize: 13,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? theme.textSecondaryColor : theme.textColor,
                fontWeight: isCompleted ? FontWeight.normal : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted ? primaryColor : Colors.grey.shade200,
            ),
            child: isCompleted
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeItem(
    TodayChallengeItem challenge,
    ThemeProvider theme,
    Color primaryColor,
  ) {
    final isCompleted = challenge.isCompleted;
    final progress = challenge.progress;
    final totalDays = challenge.totalDays;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.flag,
              color: primaryColor,
              size: 15,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '🏆 ${challenge.title}',
              style: TextStyle(
                fontSize: 13,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? theme.textSecondaryColor : theme.textColor,
                fontWeight: isCompleted ? FontWeight.normal : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isCompleted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$progress/$totalDays',
                style: TextStyle(
                  fontSize: 10,
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: 4),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted ? primaryColor : Colors.grey.shade200,
            ),
            child: isCompleted
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildQuestItem(
    TodayQuestItem quest,
    ThemeProvider theme,
    Color primaryColor,
  ) {
    final isCompleted = quest.isCompleted;
    final progress = quest.progress;
    final targetCount = quest.targetCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.stars,
              color: primaryColor,
              size: 15,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '🎯 ${quest.title}',
              style: TextStyle(
                fontSize: 13,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? theme.textSecondaryColor : theme.textColor,
                fontWeight: isCompleted ? FontWeight.normal : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isCompleted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$progress/$targetCount',
                style: TextStyle(
                  fontSize: 10,
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: 4),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted ? primaryColor : Colors.grey.shade200,
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
    required ThemeProvider theme,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.textColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: theme.textSecondaryColor,
          ),
        ),
      ],
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
}
