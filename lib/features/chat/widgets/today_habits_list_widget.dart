// lib/features/chat/widgets/today_habits_list_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../models/today_habits_list.dart';
import '../utils/chat_colors.dart';
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

    // ✅ رنگ‌های استاندارد بر اساس تم روز/شب
    // - من: روز → primaryLight | شب → primaryColor
    // - مقابل: روز → سفید | شب → مشکی
    final Color bgColor =
        isMe ? ChatColors.myBubble(theme) : ChatColors.otherBubble(theme);
    final Color textColor = isMe
        ? ChatColors.myBubbleText(theme)
        : ChatColors.otherBubbleText(theme);
    final Color textSecondary = isMe
        ? ChatColors.myBubbleTextSecondary(theme)
        : ChatColors.otherBubbleTextSecondary(theme);

    final jalaliDate = Jalali.fromDateTime(data.date);
    final dateString = '${jalaliDate.day} ${_getMonthName(jalaliDate.month)}';
    final rate = (data.completionRate * 100).toInt();

    return Container(
      width: 280,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor, // ✅ پس‌زمینه پویا
        borderRadius: BorderRadius.circular(18),
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
                  Icons.checklist,
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
                      'لیست امروز',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      dateString,
                      style: TextStyle(
                        fontSize: 10,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$rate%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ==================== آمار ====================
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(
                  'کل',
                  '${data.totalItems}',
                  textColor,
                  textSecondary,
                ),
                _buildStatItem(
                  'انجام شده',
                  '${data.completedItems}',
                  textColor,
                  textSecondary,
                ),
                _buildStatItem(
                  'باقیمانده',
                  '${data.totalItems - data.completedItems}',
                  textColor,
                  textSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ==================== لیست عادت‌ها ====================
          if (data.habits.isNotEmpty) ...[
            _buildSectionLabel('📌 عادت‌ها', textSecondary),
            const SizedBox(height: 4),
            ...data.habits.map(
              (h) => _buildHabitItem(h, textColor, textSecondary, bgColor),
            ),
            const SizedBox(height: 8),
          ],

          // ==================== لیست تسک‌ها ====================
          if (data.tasks.isNotEmpty) ...[
            _buildSectionLabel('📌 تسک‌ها', textSecondary),
            const SizedBox(height: 4),
            ...data.tasks.map(
              (t) => _buildTaskItem(t, textColor, textSecondary, bgColor),
            ),
            const SizedBox(height: 8),
          ],

          // ==================== لیست چالش‌ها ====================
          if (data.challenges.isNotEmpty) ...[
            _buildSectionLabel('🏆 چالش‌ها', textSecondary),
            const SizedBox(height: 4),
            ...data.challenges.map(
              (c) => _buildChallengeItem(c, textColor, textSecondary, bgColor),
            ),
            const SizedBox(height: 8),
          ],

          // ==================== لیست ماموریت‌ها ====================
          if (data.quests.isNotEmpty) ...[
            _buildSectionLabel('🎯 ماموریت‌ها', textSecondary),
            const SizedBox(height: 4),
            ...data.quests.map(
              (q) => _buildQuestItem(q, textColor, textSecondary, bgColor),
            ),
          ],

          // ==================== پیام پایانی ====================
          if (data.totalItems > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    rate >= 80
                        ? Icons.local_fire_department
                        : rate >= 50
                            ? Icons.trending_up
                            : Icons.emoji_emotions_outlined,
                    color: textColor,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      data.completionMessage,
                      style: TextStyle(
                        fontSize: 11,
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ==================== فوتر ====================
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                data.userName,
                style: TextStyle(
                  fontSize: 9,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== ویجت‌های کمکی ====================

  Widget _buildSectionLabel(String label, Color textSecondary) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: textSecondary,
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    Color textColor,
    Color textSecondary,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: textSecondary),
        ),
      ],
    );
  }

  // ==================== آیتم عادت ====================
  Widget _buildHabitItem(
    TodayHabitItem habit,
    Color textColor,
    Color textSecondary,
    Color bgColor,
  ) {
    final isCompleted = habit.isCompleted;
    final isChallenge = habit.isChallenge;
    final isQuest = habit.isQuest;

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
                fontSize: 12,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? textSecondary : textColor,
                fontWeight: isCompleted ? FontWeight.normal : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isChallenge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '🏆',
                style: TextStyle(fontSize: 9, color: textColor),
              ),
            ),
          if (isQuest)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '🎯',
                style: TextStyle(fontSize: 9, color: textColor),
              ),
            ),
          const SizedBox(width: 4),
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  isCompleted ? textColor : textColor.withValues(alpha: 0.15),
            ),
            child: isCompleted
                ? Icon(Icons.check, size: 11, color: bgColor)
                : null,
          ),
        ],
      ),
    );
  }

  // ==================== آیتم تسک ====================
  Widget _buildTaskItem(
    TodayTaskItem task,
    Color textColor,
    Color textSecondary,
    Color bgColor,
  ) {
    final isCompleted = task.isCompleted;

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
              Icons.assignment,
              color: isCompleted ? textSecondary : textColor,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                fontSize: 12,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? textSecondary : textColor,
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
              color:
                  isCompleted ? textColor : textColor.withValues(alpha: 0.15),
            ),
            child: isCompleted
                ? Icon(Icons.check, size: 11, color: bgColor)
                : null,
          ),
        ],
      ),
    );
  }

  // ==================== آیتم چالش ====================
  Widget _buildChallengeItem(
    TodayChallengeItem challenge,
    Color textColor,
    Color textSecondary,
    Color bgColor,
  ) {
    final isCompleted = challenge.isCompleted;
    final progress = challenge.progress;
    final totalDays = challenge.totalDays;

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
              Icons.flag,
              color: textColor,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '🏆 ${challenge.title}',
              style: TextStyle(
                fontSize: 12,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? textSecondary : textColor,
                fontWeight: isCompleted ? FontWeight.normal : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isCompleted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$progress/$totalDays',
                style: TextStyle(
                  fontSize: 9,
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: 4),
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  isCompleted ? textColor : textColor.withValues(alpha: 0.15),
            ),
            child: isCompleted
                ? Icon(Icons.check, size: 11, color: bgColor)
                : null,
          ),
        ],
      ),
    );
  }

  // ==================== آیتم ماموریت ====================
  Widget _buildQuestItem(
    TodayQuestItem quest,
    Color textColor,
    Color textSecondary,
    Color bgColor,
  ) {
    final isCompleted = quest.isCompleted;
    final progress = quest.progress;
    final targetCount = quest.targetCount;

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
              Icons.stars,
              color: textColor,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '🎯 ${quest.title}',
              style: TextStyle(
                fontSize: 12,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? textSecondary : textColor,
                fontWeight: isCompleted ? FontWeight.normal : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isCompleted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$progress/$targetCount',
                style: TextStyle(
                  fontSize: 9,
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: 4),
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  isCompleted ? textColor : textColor.withValues(alpha: 0.15),
            ),
            child: isCompleted
                ? Icon(Icons.check, size: 11, color: bgColor)
                : null,
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
