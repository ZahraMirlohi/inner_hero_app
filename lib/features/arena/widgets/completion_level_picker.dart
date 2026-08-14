// lib/features/arena/widgets/completion_level_picker.dart

import 'package:flutter/material.dart';
import '../models/habit_completion.dart';

class CompletionLevelPicker extends StatefulWidget {
  final String habitTitle;
  final int habitXpReward;
  final Function(CompletionLevel) onSelected;

  const CompletionLevelPicker({
    super.key,
    required this.habitTitle,
    required this.habitXpReward,
    required this.onSelected,
  });

  @override
  State<CompletionLevelPicker> createState() => _CompletionLevelPickerState();
}

class _CompletionLevelPickerState extends State<CompletionLevelPicker> {
  CompletionLevel? _selectedLevel;

  @override
  Widget build(BuildContext context) {
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
                      const Text(
                        'چگونه انجام دادی؟',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.habitTitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ==================== گزینه‌ها ====================
            _buildLevelOption(CompletionLevel.full),
            const SizedBox(height: 12),
            _buildLevelOption(CompletionLevel.half),
            const SizedBox(height: 12),
            _buildLevelOption(CompletionLevel.basic),

            const SizedBox(height: 20),

            // ✅ دکمه تایید
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedLevel == null
                    ? null
                    : () {
                        // ✅ صدا زدن onSelected و بستن دیالوگ
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
                Navigator.pop(context); // بدون مقدار (انصراف)
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

  Widget _buildLevelOption(CompletionLevel level) {
    final isSelected = _selectedLevel == level;
    final xpEarned = (widget.habitXpReward * level.xpMultiplier / 100).round();

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLevel = level;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected ? level.color.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? level.color : Colors.grey.shade200,
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
                  Text(
                    level.displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? level.color : const Color(0xFF1A1A2E),
                    ),
                  ),
                  Text(
                    level.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
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
}
