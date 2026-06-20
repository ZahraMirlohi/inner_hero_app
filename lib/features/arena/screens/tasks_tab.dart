import 'package:flutter/material.dart';
import '/services/appwrite_service.dart';
import '/services/date_service.dart';
import '/features/arena/models/task_model.dart';
import 'package:appwrite/models.dart' as models;
import '../add_task_screen.dart';
import '../edit_task_screen.dart';

class TasksTab extends StatefulWidget {
  const TasksTab({super.key});

  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> with TickerProviderStateMixin {
  final AppwriteService _appwrite = AppwriteService();
  List<Task> _tasks = [];
  bool _isLoading = true;
  models.User? _currentUser;
  String? _expandedItemId;
  String? _expandedSubItemId;

  final Map<String, AnimationController> _animationControllers = {};
  final Map<String, Animation<double>> _animations = {};

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    for (var controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initAnimation(String id) {
    if (!_animationControllers.containsKey(id)) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      );
      final animation = CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutBack,
      );
      _animationControllers[id] = controller;
      _animations[id] = animation;
    }
  }

  void _toggleExpanded(String id) {
    setState(() {
      if (_expandedItemId == id) {
        if (_animationControllers.containsKey(id)) {
          _animationControllers[id]!.reverse();
        }
        _expandedItemId = null;
        _expandedSubItemId = null;
      } else {
        if (_expandedItemId != null &&
            _animationControllers.containsKey(_expandedItemId)) {
          _animationControllers[_expandedItemId]!.reverse();
        }
        _initAnimation(id);
        _animationControllers[id]!.forward();
        _expandedItemId = id;
        _expandedSubItemId = null;
      }
    });
  }

  Future<void> _loadTasks() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    _currentUser = await _appwrite.getCurrentUser();
    if (_currentUser != null && mounted) {
      _tasks = await _appwrite.getTasks(_currentUser!.$id);
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markTaskCompleted(Task task) async {
    setState(() {
      task.isCompleted = !task.isCompleted;
    });
    await _appwrite.updateTask(task);
    if (task.isCompleted && mounted) {
      await _appwrite.addXP(_currentUser!.$id, task.xpReward);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('+${task.xpReward} XP دریافت کردید!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
    _loadTasks();
  }

  Future<void> _markTaskFailed(Task task) async {
    setState(() {
      task.isCompleted = false;
    });
    await _appwrite.updateTask(task);
    _loadTasks();
  }

  void _showTaskDetailsDialog(Task task) async {
    String dueDateStr = '';
    if (task.dueDate != null) {
      dueDateStr = await DateService.formatDate(task.dueDate!);
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: task.isCompleted
                          ? Colors.green
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      task.isCompleted ? Icons.check_circle : Icons.assignment,
                      color: task.isCompleted
                          ? Colors.white
                          : Colors.grey.shade500,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        Text(
                          task.description.isEmpty
                              ? 'بدون توضیحات'
                              : task.description,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              if (task.dueDate != null) ...[
                _buildDetailRow(
                  Icons.calendar_today,
                  'تاریخ سررسید',
                  dueDateStr,
                ),
                const SizedBox(height: 12),
              ],
              _buildDetailRow(Icons.stars, 'امتیاز', '${task.xpReward} XP'),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFA500).withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFFFFA500), size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }

  Future<void> _toggleSubTask(Task task, String subTask) async {
    List<String> newCompletedSubTasks = List.from(task.completedSubTasks);
    if (newCompletedSubTasks.contains(subTask)) {
      newCompletedSubTasks.remove(subTask);
    } else {
      newCompletedSubTasks.add(subTask);
    }

    final updatedTask = Task(
      id: task.id,
      userId: task.userId,
      title: task.title,
      description: task.description,
      subTasks: task.subTasks,
      completedSubTasks: newCompletedSubTasks,
      dueDate: task.dueDate,
      isCompleted: task.isCompleted,
      xpReward: task.xpReward,
      createdAt: task.createdAt,
      updatedAt: DateTime.now(),
    );

    await _appwrite.updateTask(updatedTask);

    setState(() {
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = updatedTask;
      }
    });
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  // ==================== متدهای ویرایش و حذف ====================

  void _editTask(Task task) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditTaskScreen(task: task)),
    );
    if (result == true && mounted) {
      _loadTasks();
    }
    _toggleExpanded(task.id);
  }

  void _deleteTask(Task task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف تسک'),
        content: const Text('آیا از حذف این تسک مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _appwrite.deleteTask(task.id);
      _loadTasks();
    }
    _toggleExpanded(task.id);
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Icon(
          icon,
          color: onTap == null ? Colors.grey.shade400 : Colors.grey.shade600,
          size: 24,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTaskScreen()),
          );
          if (result == true && mounted) {
            _loadTasks();
          }
        },
        backgroundColor: const Color(0xFF4A90E2),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTasks,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF4A90E2)),
              )
            : _tasks.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 80,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'هیچ تسکی ندارید',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'روی دکمه + در پایین صفحه کلیک کنید',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _tasks.length,
                itemBuilder: (context, index) {
                  final task = _tasks[index];
                  return _buildTaskItem(task);
                },
              ),
      ),
    );
  }

  Widget _buildTaskItem(Task task) {
    final isChallengeTask = task.title.startsWith('🎯');
    final hasSubTasks = task.subTasks.isNotEmpty;
    final isExpanded = _expandedItemId == task.id;
    final isSubExpanded = _expandedSubItemId == task.id;

    _initAnimation(task.id);

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.horizontal,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.check, color: Colors.white, size: 28),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.close, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _markTaskCompleted(task);
        } else if (direction == DismissDirection.endToStart) {
          await _markTaskFailed(task);
        }
        return false;
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Column(
          children: [
            InkWell(
              onTap: () => _toggleExpanded(task.id),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: task.isCompleted
                            ? Colors.green
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        task.isCompleted
                            ? Icons.check_circle
                            : Icons.assignment,
                        color: task.isCompleted
                            ? Colors.white
                            : Colors.grey.shade500,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: task.isCompleted
                                  ? Colors.grey
                                  : const Color(0xFF1A1A2E),
                            ),
                          ),
                          if (task.dueDate != null)
                            FutureBuilder(
                              future: DateService.formatDate(task.dueDate!),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Text(
                                    'زمان: ${snapshot.data}',
                                    style: const TextStyle(fontSize: 12),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                        ],
                      ),
                    ),
                    if (hasSubTasks && task.completedSubTasks.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFA500).withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${task.completedSubTasks.length}/${task.subTasks.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFA500),
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: task.isCompleted
                            ? Colors.green.withAlpha(25)
                            : const Color(0xFFFFA500).withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '+${task.xpReward} XP',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: task.isCompleted
                              ? Colors.green
                              : const Color(0xFFFFA500),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (isExpanded)
              SizeTransition(
                sizeFactor: _animations[task.id]!,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade200,
                            width: isSubExpanded ? 0 : 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildActionButton(
                            icon: Icons.check_circle,
                            onTap: () => _markTaskCompleted(task),
                          ),
                          if (hasSubTasks)
                            _buildActionButton(
                              icon: isSubExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.list_alt,
                              onTap: () {
                                setState(() {
                                  if (_expandedSubItemId == task.id) {
                                    _expandedSubItemId = null;
                                  } else {
                                    _expandedSubItemId = task.id;
                                  }
                                });
                              },
                            ),
                          _buildActionButton(
                            icon: Icons.info_outline,
                            onTap: () => _showTaskDetailsDialog(task),
                          ),
                          _buildActionButton(
                            icon: Icons.edit,
                            onTap: isChallengeTask
                                ? null
                                : () => _editTask(task),
                          ),
                          _buildActionButton(
                            icon: Icons.delete,
                            onTap: isChallengeTask
                                ? null
                                : () => _deleteTask(task),
                          ),
                        ],
                      ),
                    ),

                    if (isSubExpanded && hasSubTasks)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                        ),
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
                            ...task.subTasks.map(
                              (subTask) => CheckboxListTile(
                                value: task.completedSubTasks.contains(subTask),
                                onChanged: (value) async {
                                  await _toggleSubTask(task, subTask);
                                  setState(() {});
                                },
                                title: Text(subTask),
                                activeColor: const Color(0xFFFFA500),
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            ),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: task.subTasks.isEmpty
                                  ? 0
                                  : task.completedSubTasks.length /
                                        task.subTasks.length,
                              backgroundColor: Colors.grey.shade200,
                              color: const Color(0xFFFFA500),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'پیشرفت: ${task.subTasks.isEmpty ? 0 : ((task.completedSubTasks.length / task.subTasks.length) * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
