import 'package:flutter/material.dart';
import '/features/arena/models/task_model.dart';
import '/services/supabase_service.dart'; // ← تغییر

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

  final _supabase = SupabaseService(); // ← اضافه شده

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

    await _supabase.updateTask(updatedTask); // ← تغییر
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.task.subTasks.isEmpty
        ? 0.0
        : _completedSubTasks.length / widget.task.subTasks.length;

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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: widget.task.isCompleted
                    ? Colors.green
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                widget.task.isCompleted ? Icons.check_circle : Icons.assignment,
                color: widget.task.isCompleted
                    ? Colors.white
                    : Colors.grey.shade500,
              ),
            ),
            title: Text(
              widget.task.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                decoration: widget.task.isCompleted
                    ? TextDecoration.lineThrough
                    : null,
                color: widget.task.isCompleted
                    ? Colors.grey
                    : const Color(0xFF1A1A2E),
              ),
            ),
            subtitle: widget.task.dueDate != null
                ? Text(
                    'زمان: ${_formatDate(widget.task.dueDate!)}',
                    style: const TextStyle(fontSize: 12),
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
                      color: const Color(0xFFFFA500).withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_completedSubTasks.length}/${widget.task.subTasks.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFA500),
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

          // بخش توسعه یافته (زیرتسک‌ها)
          if (_isExpanded && widget.task.subTasks.isNotEmpty)
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
                          'زیرتسک‌ها',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
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
                              style: const TextStyle(fontSize: 14),
                            ),
                            activeColor: const Color(0xFFFFA500),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),

                        // نوار پیشرفت
                        if (widget.task.subTasks.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey.shade200,
                            color: const Color(0xFFFFA500),
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

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}
