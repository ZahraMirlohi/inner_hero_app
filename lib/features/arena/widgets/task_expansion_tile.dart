// lib/features/arena/widgets/task_expansion_tile.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/features/arena/models/task_model.dart';
import '/services/supabase_service.dart';
import '/core/app_palette.dart';
import '/l10n/app_strings.dart';
import '/providers/theme_provider.dart';
import '/providers/calendar_provider.dart';

class TaskExpansionTile extends StatefulWidget {
  final Task task;
  final VoidCallback onChanged;

  const TaskExpansionTile({
    super.key,
    required this.task,
    required this.onChanged,
  });

  @override
  State<TaskExpansionTile> createState() => _TaskExpansionTileState();
}

class _TaskExpansionTileState extends State<TaskExpansionTile> {
  late List<String> _completedSubTasks;
  bool _isExpanded = false;

  final _supabase = SupabaseService();

  @override
  void initState() {
    super.initState();
    _completedSubTasks = List.from(widget.task.completedSubTasks);
  }

  Future<void> _toggleSubTask(String subTask, bool? value) async {
    if (value == true) {
      if (!_completedSubTasks.contains(subTask)) {
        _completedSubTasks.add(subTask);
      }
    } else {
      _completedSubTasks.remove(subTask);
    }

    setState(() {});

    final updatedTask = Task(
      id: widget.task.id,
      userId: widget.task.userId,
      title: widget.task.title,
      description: widget.task.description,
      subTasks: widget.task.subTasks,
      completedSubTasks: _completedSubTasks,
      dueDate: widget.task.dueDate,
      isCompleted: widget.task.isCompleted,
      xpReward: widget.task.xpReward,
      createdAt: widget.task.createdAt,
      updatedAt: DateTime.now(),
    );

    await _supabase.updateTask(updatedTask);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final calendar = Provider.of<CalendarProvider>(context);
    final Color cardColor = theme.tone(Tone.apricot).bg;
    final int total = widget.task.subTasks.length;
    final progress = total == 0 ? 0.0 : _completedSubTasks.length / total;
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
                      Icons.assignment_outlined,
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
                          widget.task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        if (widget.task.dueDate != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            calendar.formatShort(widget.task.dueDate!),
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
                        '${_completedSubTasks.length}/$total',
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
                    context.tr('ah.exp.subTasks'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: theme.textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...widget.task.subTasks.map((subTask) {
                    final isChecked = _completedSubTasks.contains(subTask);
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _toggleSubTask(subTask, !isChecked),
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
                                  subTask,
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
