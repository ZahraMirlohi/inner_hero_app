// lib/features/arena/screens/edit_habit_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/services/supabase_service.dart';
import '/features/arena/models/habit_model.dart';
import '/l10n/app_strings.dart';
import '/providers/calendar_provider.dart';
import '/providers/sync_provider.dart';
import 'widgets/arena_form_widgets.dart';

class EditHabitScreen extends StatefulWidget {
  final Habit habit;

  const EditHabitScreen({super.key, required this.habit});

  @override
  State<EditHabitScreen> createState() => _EditHabitScreenState();
}

class _EditHabitScreenState extends State<EditHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late List<String> _subHabits;
  late List<String> _completedSubHabits;
  final _subHabitController = TextEditingController();

  late String _selectedIcon;
  late int _selectedIconColor;
  int _selectedBgColor = 0xFFB0CC5D;

  late String _frequencyType;
  late int _dailyIntervalDays;
  late List<int> _weeklyDays;
  late int _weeklyIntervalWeeks;
  late List<int> _monthlyDays;
  late int _monthlyIntervalMonths;

  late String _timeOfDay;
  late List<Reminder> _reminders;
  late String? _targetValue;
  late String? _fullDescription;
  late String? _halfDescription;
  late String? _basicDescription;
  DateTime? _startDate;

  late int _xpReward;
  bool _isLoading = false;

  final _supabase = SupabaseService();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.habit.title);
    _descriptionController = TextEditingController(
      text: widget.habit.description,
    );
    _subHabits = List.from(widget.habit.subHabits);
    _completedSubHabits = List.from(widget.habit.completedSubHabits);
    _selectedIcon = widget.habit.iconName;
    _selectedIconColor = widget.habit.iconColor;
    _selectedBgColor = widget.habit.backgroundColor;
    _frequencyType = widget.habit.frequencyType;
    _dailyIntervalDays = widget.habit.dailyIntervalDays?.first ?? 1;
    _weeklyDays = List.from(widget.habit.weeklyDays ?? []);
    _weeklyIntervalWeeks = widget.habit.weeklyIntervalWeeks ?? 1;
    _monthlyDays = List.from(widget.habit.monthlyDays ?? []);
    _monthlyIntervalMonths = widget.habit.monthlyIntervalMonths ?? 1;
    _timeOfDay = widget.habit.timeOfDay;
    _reminders = List.from(widget.habit.reminders);
    _xpReward = widget.habit.xpReward;
    _targetValue = widget.habit.targetValue;
    _fullDescription = widget.habit.fullDescription;
    _halfDescription = widget.habit.halfDescription;
    _basicDescription = widget.habit.basicDescription;
    _startDate = widget.habit.startDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subHabitController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final date = await showArenaDateDialog(context, initial: _startDate);
    if (date != null && mounted) {
      setState(() => _startDate = date);
    }
  }

  Future<void> _addReminder() async {
    final selectedTime = await showArenaTimePicker(context);
    if (selectedTime != null && mounted) {
      setState(() {
        _reminders.add(
          Reminder(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            hour: selectedTime.hour,
            minute: selectedTime.minute,
            isEnabled: true,
          ),
        );
      });
    }
  }

  void _toggleIn(List<int> list, int value) {
    setState(() {
      if (list.contains(value)) {
        list.remove(value);
      } else {
        list.add(value);
      }
      list.sort();
    });
  }

  @override
  Widget build(BuildContext context) {
    final calendar = Provider.of<CalendarProvider>(context);

    return ArenaFormPage(
      title: context.tr('af.habit.edit_title'),
      formKey: _formKey,
      children: [
        ArenaSection(
          children: [
            ArenaTextField(
              label: context.tr('af.habit.title'),
              hint: context.tr('af.habit.title_hint'),
              controller: _titleController,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? context.tr('af.val.title')
                  : null,
            ),
            ArenaTextField(
              label: context.tr('af.field.desc'),
              controller: _descriptionController,
              minLines: 3,
              maxLines: 4,
            ),
          ],
        ),
        ArenaLevelSection(
          targetValue: _targetValue,
          fullDescription: _fullDescription,
          halfDescription: _halfDescription,
          basicDescription: _basicDescription,
          onTarget: (v) => _targetValue = v,
          onFull: (v) => _fullDescription = v,
          onHalf: (v) => _halfDescription = v,
          onBasic: (v) => _basicDescription = v,
        ),
        ArenaSubItemsSection(
          title: context.tr('af.habit.subs'),
          hint: context.tr('af.habit.subs_hint'),
          controller: _subHabitController,
          items: _subHabits,
          onAdd: (v) => setState(() => _subHabits.add(v)),
          onRemove: (v) => setState(() {
            _subHabits.remove(v);
            if (!_subHabits.contains(v)) _completedSubHabits.remove(v);
          }),
        ),
        ArenaIconColorSection(
          selectedIcon: _selectedIcon,
          selectedColor: _selectedBgColor,
          onIcon: (v) => setState(() => _selectedIcon = v),
          onColor: (v) => setState(() => _selectedBgColor = v),
        ),
        ArenaFrequencySection(
          frequencyType: _frequencyType,
          dailyInterval: _dailyIntervalDays,
          weeklyDays: _weeklyDays,
          weeklyInterval: _weeklyIntervalWeeks,
          monthlyDays: _monthlyDays,
          monthlyInterval: _monthlyIntervalMonths,
          onType: (v) => setState(() => _frequencyType = v),
          onDailyInterval: (v) => setState(() => _dailyIntervalDays = v),
          onToggleWeekday: (v) => _toggleIn(_weeklyDays, v),
          onWeeklyInterval: (v) => setState(() => _weeklyIntervalWeeks = v),
          onToggleMonthDay: (v) => _toggleIn(_monthlyDays, v),
          onMonthlyInterval: (v) => setState(() => _monthlyIntervalMonths = v),
        ),
        ArenaTimeOfDaySection(
          value: _timeOfDay,
          onChanged: (v) => setState(() => _timeOfDay = v),
        ),
        ArenaDateSection(
          title: context.tr('af.habit.start_date'),
          text: _startDate == null
              ? context.tr('af.date.pick')
              : calendar.formatShort(_startDate!),
          hasValue: _startDate != null,
          onTap: _selectStartDate,
        ),
        ArenaRemindersSection(
          reminders: _reminders,
          onAdd: _addReminder,
          onRemove: (r) => setState(() => _reminders.remove(r)),
          onToggle: (r, v) => setState(() => r.isEnabled = v),
        ),
        ArenaXpSection(
          title: context.tr('af.habit.xp'),
          value: _xpReward,
          onChanged: (v) => setState(() => _xpReward = v),
        ),
        ArenaPrimaryButton(
          label: context.tr('af.habit.save'),
          icon: Icons.check_rounded,
          loading: _isLoading,
          onPressed: _updateHabit,
        ),
      ],
    );
  }

  Future<void> _updateHabit() async {
    if (!_formKey.currentState!.validate()) return;

    final validCompletedSubHabits =
        _completedSubHabits.where((c) => _subHabits.contains(c)).toList();

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedHabit = Habit(
        id: widget.habit.id,
        userId: widget.habit.userId,
        title: _titleController.text,
        description: _descriptionController.text,
        subHabits: _subHabits,
        completedSubHabits: validCompletedSubHabits,
        iconName: _selectedIcon,
        iconColor: _selectedIconColor,
        backgroundColor: _selectedBgColor,
        frequencyType: _frequencyType,
        dailyIntervalDays:
            _frequencyType == 'daily' ? [_dailyIntervalDays] : null,
        weeklyDays: _frequencyType == 'weekly' ? _weeklyDays : null,
        weeklyIntervalWeeks:
            _frequencyType == 'weekly' ? _weeklyIntervalWeeks : 1,
        monthlyDays: _frequencyType == 'monthly' ? _monthlyDays : null,
        monthlyIntervalMonths:
            _frequencyType == 'monthly' ? _monthlyIntervalMonths : 1,
        timeOfDay: _timeOfDay,
        reminders: _reminders,
        xpReward: _xpReward,
        currentStreak: widget.habit.currentStreak,
        bestStreak: widget.habit.bestStreak,
        isActive: widget.habit.isActive,
        createdAt: widget.habit.createdAt,
        updatedAt: DateTime.now(),
        groupId: widget.habit.groupId,
        startDate: _startDate,
        endDate: widget.habit.endDate,
        challengeId: widget.habit.challengeId,
        questId: widget.habit.questId,
        timerSetting: widget.habit.timerSetting,
        targetValue: _targetValue,
        fullDescription: _fullDescription,
        halfDescription: _halfDescription,
        basicDescription: _basicDescription,
      );

      await Provider.of<SyncProvider>(context, listen: false)
          .updateHabitSmart(updatedHabit);

      if (mounted) {
        showArenaSnack(context, context.tr('af.habit.updated'));
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error updating habit: $e');
      if (mounted) {
        showArenaSnack(
          context,
          context.tr('af.habit.err_update', {'error': e.toString()}),
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
