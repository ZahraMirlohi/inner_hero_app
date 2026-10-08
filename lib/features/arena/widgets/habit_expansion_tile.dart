// lib/features/arena/widgets/habit_expansion_tile.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/features/arena/models/habit_model.dart';
import '/services/supabase_service.dart';
import '/providers/theme_provider.dart';

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
  final _supabase = SupabaseService();

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

    await _supabase.updateHabit(updatedHabit);
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
    final theme = Provider.of<ThemeProvider>(context);
    final Color primaryColor = theme.primaryColor;

    final progress = widget.habit.subHabits.isEmpty
        ? 0.0
        : _completedSubHabits.length / widget.habit.subHabits.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.cardColor,
      elevation: 2,
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getIconData(widget.habit.iconName),
                color: primaryColor,
                size: 28,
              ),
            ),
            title: Text(
              widget.habit.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.textColor,
              ),
            ),
            subtitle: Text(
              widget.habit.description.isEmpty
                  ? 'بدون توضیحات'
                  : widget.habit.description,
              style: TextStyle(
                fontSize: 12,
                color: theme.textSecondaryColor,
              ),
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
                      color: primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_completedSubHabits.length}/${widget.habit.subHabits.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: theme.textSecondaryColor,
                ),
              ],
            ),
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
          ),
          if (_isExpanded && widget.habit.subHabits.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: theme.isDarkMode
                    ? const Color(0xFF1A1A1A)
                    : const Color(0xFFF7FCEB),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  Divider(height: 1, color: theme.borderColor),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'زیرعادت‌ها',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.textColor,
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
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.textColor,
                              ),
                            ),
                            activeColor: primaryColor,
                            checkColor: theme.isDarkMode
                                ? const Color(0xFF090909)
                                : Colors.white,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                        if (widget.habit.subHabits.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: theme.borderColor,
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'پیشرفت: ${(progress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textSecondaryColor,
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
