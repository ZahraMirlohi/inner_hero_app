import 'package:flutter/material.dart';
import '/features/arena/models/habit_model.dart';
import '/services/appwrite_service.dart';

class HabitExpansionTile extends StatefulWidget {
  final Habit habit;
  final VoidCallback onChanged;

  const HabitExpansionTile({
    super.key,
    required this.habit,
    required this.onChanged,
  });

  @override
  State<HabitExpansionTile> createState() => _HabitExpansionTileState();
}

class _HabitExpansionTileState extends State<HabitExpansionTile> {
  late List<String> _completedSubHabits;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _completedSubHabits = List.from(widget.habit.completedSubHabits);
  }

  Future<void> _toggleSubHabit(String subHabit, bool? value) async {
    if (value == true) {
      if (!_completedSubHabits.contains(subHabit)) {
        _completedSubHabits.add(subHabit);
      }
    } else {
      _completedSubHabits.remove(subHabit);
    }

    setState(() {});

    // به‌روزرسانی در دیتابیس
    final updatedHabit = Habit(
      id: widget.habit.id,
      userId: widget.habit.userId,
      title: widget.habit.title,
      description: widget.habit.description,
      subHabits: widget.habit.subHabits,
      completedSubHabits: _completedSubHabits,
      iconName: widget.habit.iconName,
      iconColor: widget.habit.iconColor,
      backgroundColor: widget.habit.backgroundColor,
      frequencyType: widget.habit.frequencyType,
      dailyIntervalDays: widget.habit.dailyIntervalDays,
      weeklyDays: widget.habit.weeklyDays,
      weeklyIntervalWeeks: widget.habit.weeklyIntervalWeeks,
      monthlyDays: widget.habit.monthlyDays,
      monthlyIntervalMonths: widget.habit.monthlyIntervalMonths,
      timeOfDay: widget.habit.timeOfDay,
      reminders: widget.habit.reminders,
      xpReward: widget.habit.xpReward,
      currentStreak: widget.habit.currentStreak,
      bestStreak: widget.habit.bestStreak,
      isActive: widget.habit.isActive,
      createdAt: widget.habit.createdAt,
      updatedAt: DateTime.now(),
      groupId: widget.habit.groupId,
    );

    await AppwriteService().updateHabit(updatedHabit);
    widget.onChanged();
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

  @override
  Widget build(BuildContext context) {
    final progress = widget.habit.subHabits.isEmpty
        ? 0.0
        : _completedSubHabits.length / widget.habit.subHabits.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Column(
        children: [
          // هدر اصلی
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Color(widget.habit.backgroundColor).withAlpha(255),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getIconData(widget.habit.iconName),
                color: Color(widget.habit.iconColor),
                size: 28,
              ),
            ),
            title: Text(
              widget.habit.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
            subtitle: Text(
              widget.habit.description.isEmpty
                  ? 'بدون توضیحات'
                  : widget.habit.description,
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.habit.subHabits.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2).withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_completedSubHabits.length}/${widget.habit.subHabits.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A90E2),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey,
                ),
              ],
            ),
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
          ),

          // بخش توسعه یافته (زیرعادت‌ها)
          if (_isExpanded && widget.habit.subHabits.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'زیرعادت‌ها',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...widget.habit.subHabits.map(
                          (subHabit) => CheckboxListTile(
                            value: _completedSubHabits.contains(subHabit),
                            onChanged: (value) =>
                                _toggleSubHabit(subHabit, value),
                            title: Text(
                              subHabit,
                              style: const TextStyle(fontSize: 14),
                            ),
                            activeColor: const Color(0xFF4A90E2),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),

                        // نوار پیشرفت
                        if (widget.habit.subHabits.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey.shade200,
                            color: const Color(0xFF4A90E2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'پیشرفت: ${(progress * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
