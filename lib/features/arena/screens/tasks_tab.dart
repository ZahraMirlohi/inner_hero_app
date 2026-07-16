import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/services/supabase_service.dart';
import '/services/date_service.dart';
import '/features/arena/models/task_model.dart';
import '../add_task_screen.dart';
import '../edit_task_screen.dart';
import '/../providers/sync_provider.dart';
import '/models/offline_operation.dart';

class TasksTab extends StatefulWidget {
  const TasksTab({super.key});

  @override
  State<TasksTab> createState() => TasksTabState();
}

class TasksTabState extends State<TasksTab> with TickerProviderStateMixin {
  final SupabaseService _supabase = SupabaseService();
  List<Task> _tasks = [];
  bool _isLoading = true;
  String? _currentUserId;
  String? _expandedItemId;
  String? _expandedSubItemId;

  final Map<String, AnimationController> _animationControllers = {};
  final Map<String, Animation<double>> _animations = {};
  void refreshData() {
    if (!_isLoading) {
      _loadTasks();
    }
  }

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

    final user = await _supabase.getCurrentUser();
    if (user != null && mounted) {
      _currentUserId = user.id;

      // ✅ دریافت از SyncProvider
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);

      // ✅ ابتدا از داده‌های محلی استفاده کن
      _tasks = syncProvider.tasks.isNotEmpty
          ? syncProvider.tasks
          : await _supabase.getTasks(_currentUserId!);
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
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
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);

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

    setState(() {
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = updatedTask;
      }
    });

    // ✅ ذخیره در LocalStorage
    await syncProvider.saveTaskToLocal(updatedTask);

    // ✅ اگر آنلاین هستیم، به دیتابیس هم بفرست
    if (syncProvider.isOnline) {
      await _supabase.updateTask(updatedTask);
    } else {
      await syncProvider.addOfflineOperation(
        type: OperationType.updateTask,
        data: updatedTask.toMap(),
      );
      print('📝 Task update saved offline: ${updatedTask.title}');
    }
  }

  // ✅ اصلاح متد _deleteTask

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
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);

      setState(() {
        _tasks.removeWhere((t) => t.id == task.id);
      });

      // ✅ حذف از LocalStorage
      await _supabase.deleteTask(task.id);

      if (syncProvider.isOnline) {
        await _supabase.deleteTask(task.id);
      } else {
        await syncProvider.addOfflineOperation(
          type: OperationType.deleteTask,
          data: {'id': task.id},
        );
        print('📝 Task deletion saved offline: ${task.title}');
      }
    }
    _toggleExpanded(task.id);
  }

  // ✅ اصلاح متد _editTask

  void _editTask(Task task) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditTaskScreen(task: task)),
    );

    if (result == true && mounted) {
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);

      if (syncProvider.isOnline) {
        _loadTasks();
      } else {
        final updatedTasks = syncProvider.tasks;
        setState(() {
          _tasks = updatedTasks;
        });
      }
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

  // lib/features/arena/screens/tasks_tab.dart

  // ✅ حذف متدهای _markTaskCompleted و _markTaskFailed
  // ✅ حذف Dismissible از _buildTaskItem

  Widget _buildTaskItem(Task task) {
    final isChallengeTask = task.title.startsWith('🎯');
    final hasSubTasks = task.subTasks.isNotEmpty;
    final isExpanded = _expandedItemId == task.id;
    final isSubExpanded = _expandedSubItemId == task.id;

    _initAnimation(task.id);

    // ✅ حذف Dismissible و استفاده از Card ساده
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleExpanded(task.id),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      task.isCompleted ? Icons.check_circle : Icons.assignment,
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
                      task.isCompleted ? '✅ انجام شده' : '+${task.xpReward} XP',
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
                        // ✅ حذف دکمه check_circle
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
                          onTap: isChallengeTask ? null : () => _editTask(task),
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
                              controlAffinity: ListTileControlAffinity.leading,
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
    );
  }
}
