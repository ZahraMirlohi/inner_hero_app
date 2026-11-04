// lib/features/arena/screens/edit_task_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/services/supabase_service.dart';
import '/features/arena/models/task_model.dart';
import '/l10n/app_strings.dart';
import '/providers/calendar_provider.dart';
import '/providers/sync_provider.dart';
import 'widgets/arena_form_widgets.dart';

class EditTaskScreen extends StatefulWidget {
  final Task task;

  const EditTaskScreen({super.key, required this.task});

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late List<String> _subTasks;
  final _subTaskController = TextEditingController();
  DateTime? _dueDate;
  late int _xpReward;
  bool _isLoading = false;

  final _supabase = SupabaseService();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(
      text: widget.task.description,
    );
    _subTasks = List.from(widget.task.subTasks);
    _dueDate = widget.task.dueDate;
    _xpReward = widget.task.xpReward;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subTaskController.dispose();
    super.dispose();
  }

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
      title: context.tr('af.task.edit_title'),
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
          label: context.tr('af.habit.save'),
          icon: Icons.check_rounded,
          loading: _isLoading,
          onPressed: _updateTask,
        ),
      ],
    );
  }

  Future<void> _updateTask() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      DateTime? cleanDueDate;
      if (_dueDate != null) {
        cleanDueDate = DateTime(
          _dueDate!.year,
          _dueDate!.month,
          _dueDate!.day,
        );
      }

      final updatedTask = Task(
        id: widget.task.id,
        userId: widget.task.userId,
        title: _titleController.text,
        description: _descriptionController.text,
        subTasks: _subTasks,
        completedSubTasks: widget.task.completedSubTasks,
        dueDate: cleanDueDate,
        isCompleted: widget.task.isCompleted,
        xpReward: _xpReward,
        createdAt: widget.task.createdAt,
        updatedAt: DateTime.now(),
      );

      await Provider.of<SyncProvider>(context, listen: false)
          .updateTaskSmart(updatedTask);

      if (mounted) {
        showArenaSnack(context, context.tr('af.task.updated'));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showArenaSnack(
          context,
          context.tr('af.task.err_update', {'error': e.toString()}),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
