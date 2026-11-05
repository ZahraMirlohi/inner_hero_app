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
import '/l10n/app_strings.dart';
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
      print('Task edited, syncProvider notifies listeners');
    }
  }

  Future<void> _deleteTask(Task task) async {
    final confirm = await showArenaDeleteDialog(
      context,
      title: context.tr('ah.tasks.delTitle'),
      message: context.tr('ah.tasks.delMsg'),
    );

    if (confirm == true && mounted) {
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);

      // 1. حذف فوری از LocalStorage
      await syncProvider.deleteTaskFromLocal(task.id);

      try {
        // 2. حذف از Supabase
        if (syncProvider.isOnline) {
          await _supabase.deleteTask(task.id);

          // 3. رفرش از سرور تا مطمئن بشیم کش هم آپدیت شد
          await syncProvider.refreshHabitsAndTasks();

          print('Task deleted and refreshed');
        } else {
          // حالت آفلاین
          await syncProvider.addOfflineOperation(
            type: OperationType.deleteTask,
            data: {'id': task.id},
          );
          print('Task deletion saved offline: ${task.title}');
        }

        if (mounted) {
          showArenaSnack(context, context.tr('ah.tasks.deleted'),
              kind: ArenaSnackKind.dark);
        }
      } catch (e) {
        print('Error deleting task: $e');
        if (mounted) {
          showArenaSnack(context,
              context.tr('ah.tasks.delError', {'e': e.toString()}),
              kind: ArenaSnackKind.error);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final Color primaryColor = theme.primaryColor;

    // Consumer باعث میشه هر بار SyncProvider آپدیت شد، UI رفرش بشه
    return Consumer<SyncProvider>(
      builder: (context, syncProvider, child) {
        final tasks = syncProvider.tasks;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: RefreshIndicator(
            onRefresh: _loadTasks,
            color: primaryColor,
            child: _isLoading && tasks.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 170),
                    children: const [ArenaLoadingView()],
                  )
                : tasks.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 170),
                        children: [
                          ArenaStateView(
                            icon: Icons.assignment_outlined,
                            title: context.tr('ah.tasks.emptyTitle'),
                            subtitle: context.tr('ah.empty.sub'),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 170),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];

                          return TaskCard(
                            task: task,
                            isCompleted: false,
                            onToggle: () {
                              showArenaSnack(context, context.tr('ah.tasks.toastToday'),
                                  kind: ArenaSnackKind.info,
                                  duration: const Duration(seconds: 1),
                                  clearPrevious: true);
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
