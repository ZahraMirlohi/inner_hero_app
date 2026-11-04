// lib/features/arena/screens/add_task_screen.dart

import 'package:flutter/material.dart';
import 'package:inner_hero_app/providers/sync_provider.dart';
import 'package:provider/provider.dart';
import '/services/supabase_service.dart';
import '/services/sound_service.dart';
import '/features/arena/models/task_model.dart';
import '/l10n/app_strings.dart';
import '/providers/calendar_provider.dart';
import 'widgets/arena_form_widgets.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<String> _subTasks = [];
  final _subTaskController = TextEditingController();
  DateTime? _dueDate;
  int _xpReward = 10;
  bool _isLoading = false;

  final _supabase = SupabaseService();

  Future<void> _selectDate() async {
    final date = await showArenaDateDialog(context, initial: _dueDate);
    if (date != null && mounted) {
      setState(() => _dueDate = date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final calendar = Provider.of<CalendarProvider>(context);

    return ArenaFormPage(
      title: context.tr('af.task.add_title'),
      formKey: _formKey,
      children: [
        ArenaSection(
          children: [
            ArenaTextField(
              label: context.tr('af.task.title'),
              hint: context.tr('af.task.title_hint'),
              controller: _titleController,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? context.tr('af.val.title')
                  : null,
            ),
            ArenaTextField(
              label: context.tr('af.field.desc'),
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
            ),
          ],
        ),
        ArenaSubItemsSection(
          title: context.tr('af.task.subs'),
          hint: context.tr('af.task.subs_hint'),
          controller: _subTaskController,
          items: _subTasks,
          onAdd: (v) => setState(() => _subTasks.add(v)),
          onRemove: (v) => setState(() => _subTasks.remove(v)),
        ),
        ArenaDateSection(
          title: context.tr('af.task.due'),
          text: _dueDate == null
              ? context.tr('af.date.pick')
              : calendar.formatShort(_dueDate!),
          hasValue: _dueDate != null,
          onTap: _selectDate,
        ),
        ArenaXpSection(
          title: context.tr('af.task.xp'),
          value: _xpReward,
          onChanged: (v) => setState(() => _xpReward = v),
        ),
        ArenaPrimaryButton(
          label: context.tr('af.task.save'),
          icon: Icons.check_rounded,
          loading: _isLoading,
          onPressed: _saveTask,
        ),
      ],
    );
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = await _supabase.getCurrentUser();
      if (user != null && mounted) {
        final task = Task(
          id: SyncProvider.newId(),
          userId: user.id,
          title: _titleController.text,
          description: _descriptionController.text,
          subTasks: _subTasks,
          completedSubTasks: [],
          dueDate: _dueDate,
          isCompleted: false,
          xpReward: _xpReward,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await Provider.of<SyncProvider>(context, listen: false)
            .createTaskSmart(task);
        SoundService.instance.play(Sfx.check);

        if (mounted) {
          showArenaSnack(context, context.tr('af.task.created'));
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        showArenaSnack(
          context,
          context.tr('af.task.err_save', {'error': e.toString()}),
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
    _subTaskController.dispose();
    super.dispose();
  }
}
