// lib/features/arena/widgets/task_expansion_tile.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/features/arena/models/task_model.dart';
import '/services/supabase_service.dart';
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
    final Color primaryColor = theme.primaryColor;

    final progress = widget.task.subTasks.isEmpty
        ? 0.0
        : _completedSubTasks.length / widget.task.subTasks.length;

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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: widget.task.isCompleted
                    ? Colors.green
                    : primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                widget.task.isCompleted ? Icons.check_circle : Icons.assignment,
                color: widget.task.isCompleted ? Colors.white : primaryColor,
              ),
            ),
            title: Text(
              widget.task.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                decoration:
                    widget.task.isCompleted ? TextDecoration.lineThrough : null,
                color: widget.task.isCompleted
                    ? theme.textSecondaryColor
                    : theme.textColor,
              ),
            ),
            subtitle: widget.task.dueDate != null
                ? Text(
                    'زمان: ${calendar.formatShort(widget.task.dueDate!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textSecondaryColor,
                    ),
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.task.subTasks.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_completedSubTasks.length}/${widget.task.subTasks.length}',
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
          if (_isExpanded && widget.task.subTasks.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: theme.isDarkMode
                    ? const Color(0xFF1A1A1A)
                    : Colors.grey.shade50,
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
                          'زیرتسک‌ها',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...widget.task.subTasks.map(
                          (subTask) => CheckboxListTile(
                            value: _completedSubTasks.contains(subTask),
                            onChanged: (value) =>
                                _toggleSubTask(subTask, value),
                            title: Text(
                              subTask,
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
                        if (widget.task.subTasks.isNotEmpty) ...[
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
