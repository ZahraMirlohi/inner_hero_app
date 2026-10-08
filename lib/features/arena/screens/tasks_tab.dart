// lib/features/arena/screens/tasks_tab.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/services/supabase_service.dart';
import '/services/date_service.dart';
import '/features/arena/models/task_model.dart';
import '../add_task_screen.dart';
import '../edit_task_screen.dart';
import '/../providers/sync_provider.dart';
import '/models/offline_operation.dart';
import '../widgets/task_card.dart';
import '/providers/theme_provider.dart';

class TasksTab extends StatefulWidget {
  const TasksTab({super.key});

  @override
  State<TasksTab> createState() => TasksTabState();
}

class TasksTabState extends State<TasksTab> with TickerProviderStateMixin {
  final SupabaseService _supabase = SupabaseService();
  bool _isLoading = true;
  String? _currentUserId;

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

  Future<void> _loadTasks() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final user = await _supabase.getCurrentUser();
    if (user != null && mounted) {
      _currentUserId = user.id;

      final syncProvider = Provider.of<SyncProvider>(context, listen: false);

      if (syncProvider.tasks.isEmpty && syncProvider.isOnline) {
        await syncProvider.forceRefresh();
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editTask(Task task) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditTaskScreen(task: task)),
    );

    if (result == true && mounted) {
      print('🔄 Task edited, syncProvider notifies listeners');
    }
  }

  Future<void> _deleteTask(Task task) async {
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

      // ✅ 1. حذف فوری از LocalStorage
      await syncProvider.deleteTaskFromLocal(task.id);

      try {
        // ✅ 2. حذف از Supabase
        if (syncProvider.isOnline) {
          await _supabase.deleteTask(task.id);

          // ✅ 3. رفرش از سرور تا مطمئن بشیم کش هم آپدیت شد
          await syncProvider.refreshHabitsAndTasks();

          print('✅ Task deleted and refreshed');
        } else {
          // ✅ حالت آفلاین
          await syncProvider.addOfflineOperation(
            type: OperationType.deleteTask,
            data: {'id': task.id},
          );
          print('📝 Task deletion saved offline: ${task.title}');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تسک با موفقیت حذف شد 🗑️'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('❌ Error deleting task: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطا در حذف تسک: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final Color primaryColor = theme.primaryColor;

    // ✅ Consumer باعث میشه هر بار SyncProvider آپدیت شد، UI رفرش بشه
    return Consumer<SyncProvider>(
      builder: (context, syncProvider, child) {
        final tasks = syncProvider.tasks;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: RefreshIndicator(
            onRefresh: _loadTasks,
            color: primaryColor,
            child: _isLoading && tasks.isEmpty
                ? Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  )
                : tasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assignment_outlined,
                              size: 64,
                              color: theme.textSecondaryColor,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'هیچ وظیفه‌ای ندارید',
                              style: TextStyle(color: theme.textSecondaryColor),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'روی دکمه + در پایین صفحه کلیک کنید',
                              style: TextStyle(
                                color: theme.textSecondaryColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];

                          return TaskCard(
                            task: task,
                            isCompleted: false,
                            onToggle: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'برای انجام تسک به تب "امروز" بروید'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            onEdit: () => _editTask(task),
                            onDelete: () => _deleteTask(task),
                          );
                        },
                      ),
          ),
        );
      },
    );
  }
}
