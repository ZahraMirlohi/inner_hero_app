// lib/features/arena/widgets/habit_expansion_tile.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/features/arena/models/habit_model.dart';
import '/services/supabase_service.dart';
import '/l10n/app_strings.dart';
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
    final Color cardColor = widget.habit.backgroundColor != 0
        ? Color(widget.habit.backgroundColor)
        : theme.primaryColor;
    final int total = widget.habit.subHabits.length;
    final progress = total == 0 ? 0.0 : _completedSubHabits.length / total;
    const Color ink = Color(0xFF090909);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(28),
                  bottom: Radius.circular(_isExpanded ? 12 : 28),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: ink,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getIconData(widget.habit.iconName),
                      size: 22,
                      color: cardColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.habit.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        if (widget.habit.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.habit.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: ink,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (total > 0)
                    Container(
                      height: 26,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Text(
                        '${_completedSubHabits.length}/$total',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 250),
                    turns: _isExpanded ? 0.5 : 0,
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 24, color: ink),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded && total > 0)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 3, 14, 0),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(26),
                  bottomRight: Radius.circular(26),
                ),
                boxShadow: theme.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.tr('ah.exp.subHabits'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: theme.textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...widget.habit.subHabits.map((subHabit) {
                    final isChecked = _completedSubHabits.contains(subHabit);
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _toggleSubHabit(subHabit, !isChecked),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 40),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isChecked
                                      ? theme.primaryColor
                                      : theme.cardSecondaryColor,
                                ),
                                child: isChecked
                                    ? Icon(Icons.check_rounded,
                                        size: 16, color: theme.onPrimaryColor)
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  subHabit,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isChecked
                                        ? theme.textSecondaryColor
                                        : theme.textColor,
                                    decoration: isChecked
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: theme.cardSecondaryColor,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('ah.exp.progress',
                        {'p': '${(progress * 100).toInt()}'}),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textSecondaryColor,
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
