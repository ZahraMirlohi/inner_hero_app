// lib/features/arena/screens/add_habit_screen.dart

import 'package:flutter/material.dart';
import 'package:inner_hero_app/providers/sync_provider.dart';
import 'package:provider/provider.dart';
import '/services/supabase_service.dart';
import '/services/sound_service.dart';
import '/features/arena/models/habit_model.dart';
import '/l10n/app_strings.dart';
import '/providers/calendar_provider.dart';
import 'widgets/arena_form_widgets.dart';

class AddHabitScreen extends StatefulWidget {
  final String? preSelectedTitle;
  final String? preSelectedIcon;
  final int? preSelectedColor;

  const AddHabitScreen({
    super.key,
    this.preSelectedTitle,
    this.preSelectedIcon,
    this.preSelectedColor,
  });

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<String> _subHabits = [];
  final _subHabitController = TextEditingController();

  String _selectedIcon = 'fitness_center';
  int _selectedIconColor = 0xFF4A90E2;
  int _selectedBgColor = 0xFFB0CC5D;

  String _frequencyType = 'daily';
  int _dailyIntervalDays = 1;
  final List<int> _weeklyDays = [];
  int _weeklyIntervalWeeks = 1;
  final List<int> _monthlyDays = [];
  int _monthlyIntervalMonths = 1;

  String _timeOfDay = 'morning';
  final List<Reminder> _reminders = [];

  DateTime? _startDate;
  int _xpReward = 10;
  bool _isLoading = false;

  String? _targetValue;
  String? _fullDescription;
  String? _halfDescription;
  String? _basicDescription;

  final _supabase = SupabaseService();

  @override
  void initState() {
    super.initState();
    if (widget.preSelectedTitle != null) {
      _titleController.text = widget.preSelectedTitle!;
    }
    if (widget.preSelectedIcon != null) {
      _selectedIcon = widget.preSelectedIcon!;
    }
    if (widget.preSelectedColor != null) {
      _selectedIconColor = widget.preSelectedColor!;
      _selectedBgColor = 0xFFB0CC5D;
    }
  }

  Future<void> _selectStartDate() async {
    final date = await showArenaDateDialog(context, initial: _startDate);
    if (date != null && mounted) {
      setState(() => _startDate = date);
    }
  }

  String _getDisplayStartDate(CalendarProvider calendar) {
    if (_startDate == null) return context.tr('af.date.pick');
    return calendar.formatShort(_startDate!);
  }

  Future<void> _addReminder() async {
    final selectedTime = await showArenaTimePicker(context);
    if (selectedTime != null && mounted) {
      setState(() {
        _reminders.add(
          Reminder(
            id: SyncProvider.newId(),
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
      title: context.tr('af.habit.add_title'),
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
          onRemove: (v) => setState(() => _subHabits.remove(v)),
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
          text: _getDisplayStartDate(calendar),
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
          label: context.tr('af.habit.create'),
          icon: Icons.check_rounded,
          loading: _isLoading,
          onPressed: _saveHabit,
        ),
      ],
    );
  }

  /// اگر کاربر چیزی ننوشته باشد، همان متن پیش‌فرض سطح ذخیره می‌شود (مثل قبل).
  String _orDefault(String? value, String hintKey) =>
      (value == null || value.trim().isEmpty) ? context.tr(hintKey) : value;

  Future<void> _saveHabit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_frequencyType == 'monthly' && _monthlyDays.isNotEmpty) {
      _monthlyDays.removeWhere((day) => day < 1 || day > 31);
      if (_monthlyDays.isEmpty) {
        showArenaSnack(context, context.tr('af.habit.err_month_day'), error: true);
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final user = await _supabase.getCurrentUser();

      if (user != null && mounted) {
        final habit = Habit(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: user.id,
          title: _titleController.text,
          description: _descriptionController.text,
          subHabits: _subHabits,
          completedSubHabits: [],
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
          startDate: _startDate,
          xpReward: _xpReward,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          targetValue: _targetValue,
          fullDescription: _orDefault(_fullDescription, 'af.level.full_hint'),
          halfDescription: _orDefault(_halfDescription, 'af.level.half_hint'),
          basicDescription: _orDefault(_basicDescription, 'af.level.basic_hint'),
        );

        // ذخیرهٔ آفلاین‌پسند: اول گوشی، بعد سرور (یا صف)
        await Provider.of<SyncProvider>(context, listen: false)
            .createHabitSmart(habit);
        SoundService.instance.play(Sfx.check);

        if (mounted) {
          showArenaSnack(context, context.tr('af.habit.created'));
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        showArenaSnack(
          context,
          context.tr('af.habit.err_save', {'error': e.toString()}),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subHabitController.dispose();
    super.dispose();
  }
}
