// lib/features/arena/widgets/completion_level_picker.dart

import 'package:flutter/material.dart';
import '../models/habit_completion.dart';

class CompletionLevelPicker extends StatefulWidget {
  final String habitTitle;
  final int habitXpReward;
  final Function(CompletionLevel) onSelected;

  // ✅ فیلدهای جدید برای نمایش اطلاعات واقعی
  final String? fullDescription;
  final String? halfDescription;
  final String? basicDescription;
  final String? targetValue;
  final String? habitId;
  final bool? isQuest;
  final bool? isChallenge;

  const CompletionLevelPicker({
    super.key,
    required this.habitTitle,
    required this.habitXpReward,
    required this.onSelected,
    this.fullDescription,
    this.halfDescription,
    this.basicDescription,
    this.targetValue,
    this.habitId,
    this.isQuest,
    this.isChallenge,
  });

  @override
  State<CompletionLevelPicker> createState() => _CompletionLevelPickerState();
}

class _CompletionLevelPickerState extends State<CompletionLevelPicker> {
  CompletionLevel? _selectedLevel;

  @override
  Widget build(BuildContext context) {
    // ✅ تشخیص نوع عادت
    final bool isQuest = widget.isQuest ?? false;
    final bool isChallenge = widget.isChallenge ?? false;

    // ✅ تعیین توضیحات پیش‌فرض بر اساس نوع
    String defaultFull = isQuest ? 'انجام کامل ماموریت' : 'انجام کامل عادت';
    String defaultHalf =
        isQuest ? 'انجام نیمی از ماموریت' : 'انجام نیمی از عادت';
    String defaultBasic = isQuest ? 'انجام حداقل ماموریت' : 'انجام حداقل عادت';

    // ✅ استفاده از مقادیر واقعی یا پیش‌فرض
    final fullDesc = widget.fullDescription ?? defaultFull;
    final halfDesc = widget.halfDescription ?? defaultHalf;
    final basicDesc = widget.basicDescription ?? defaultBasic;

    // ✅ بررسی اینکه آیا تنظیمات سفارشی است
    final bool isCustomFull =
        widget.fullDescription != null && widget.fullDescription != defaultFull;
    final bool isCustomHalf =
        widget.halfDescription != null && widget.halfDescription != defaultHalf;
    final bool isCustomBasic = widget.basicDescription != null &&
        widget.basicDescription != defaultBasic;

    // ✅ برچسب نوع عادت
    String typeLabel = '';
    if (isQuest) {
      typeLabel = 'ماموریت';
    } else if (isChallenge) {
      typeLabel = 'چالش';
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================== هدر ====================
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90E2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    color: Color(0xFF4A90E2),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'چگونه انجام دادی؟',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.habitTitle,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (typeLabel.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isQuest
                                    ? Colors.purple.withOpacity(0.1)
                                    : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                typeLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isQuest ? Colors.purple : Colors.orange,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (widget.targetValue != null &&
                          widget.targetValue!.isNotEmpty)
                        Text(
                          '🎯 هدف: ${widget.targetValue}',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF4A90E2),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ==================== گزینه‌ها ====================
            _buildLevelOption(
              CompletionLevel.full,
              fullDesc,
              isCustom: isCustomFull,
            ),
            const SizedBox(height: 12),

            _buildLevelOption(
              CompletionLevel.half,
              halfDesc,
              isCustom: isCustomHalf,
            ),
            const SizedBox(height: 12),

            _buildLevelOption(
              CompletionLevel.basic,
              basicDesc,
              isCustom: isCustomBasic,
            ),

            const SizedBox(height: 20),

            // ✅ دکمه تایید
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedLevel == null
                    ? null
                    : () {
                        widget.onSelected(_selectedLevel!);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _selectedLevel == null
                      ? 'یک گزینه را انتخاب کنید'
                      : 'تایید ${_selectedLevel!.emoji}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // ✅ دکمه انصراف
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'انصراف',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelOption(
    CompletionLevel level,
    String description, {
    bool isCustom = false,
  }) {
    final isSelected = _selectedLevel == level;
    final xpEarned = (widget.habitXpReward * level.xpMultiplier / 100).round();

    // ✅ محاسبه مقدار هدف برای هر سطح
    String? levelValue;
    if (widget.targetValue != null && widget.targetValue!.isNotEmpty) {
      levelValue = _calculateLevelValue(widget.targetValue!, level);
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLevel = level;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? level.color.withOpacity(0.1)
              : isCustom
                  ? level.color.withOpacity(0.04)
                  : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? level.color
                : isCustom
                    ? level.color.withOpacity(0.2)
                    : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              level.emoji,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        level.displayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? level.color
                              : const Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isCustom)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: level.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'سفارشی',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: level.color,
                            ),
                          ),
                        ),
                      if (!isCustom)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'پیش‌فرض',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected
                          ? Colors.grey.shade800
                          : Colors.grey.shade600,
                    ),
                  ),
                  // ✅ نمایش مقدار هدف برای هر سطح
                  if (levelValue != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: level.color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.flag,
                            size: 12,
                            color: level.color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'نیاز: $levelValue',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: level.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: level.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '+$xpEarned XP',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: level.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ متد محاسبه مقدار هدف برای هر سطح
  String? _calculateLevelValue(String targetValue, CompletionLevel level) {
    if (targetValue.isEmpty) return null;

    // پشتیبانی از فرمت‌های مختلف
    final numberMatch = RegExp(r'(\d+)').firstMatch(targetValue);
    if (numberMatch == null) {
      return targetValue;
    }

    final int number = int.parse(numberMatch.group(1)!);
    final String unit = targetValue.replaceAll(RegExp(r'[\d\s]+'), '').trim();

    int result;
    String prefix;

    switch (level) {
      case CompletionLevel.full:
        result = number;
        prefix = '';
        break;
      case CompletionLevel.half:
        result = (number / 2).ceil();
        prefix = '~';
        break;
      case CompletionLevel.basic:
        result = (number / 4).ceil();
        prefix = '~';
        break;
    }

    if (unit.isNotEmpty) {
      return '$prefix$result $unit';
    }
    return '$prefix$result';
  }
}
