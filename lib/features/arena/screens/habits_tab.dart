// lib/features/arena/screens/habits_tab.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/services/supabase_service.dart';
import '/services/date_service.dart';
import '/features/arena/models/habit_model.dart';
import '../category_selection_screen.dart';
import '../edit_habit_screen.dart' as edit_habit;
import '../edit_task_screen.dart';
import '/../providers/sync_provider.dart';
import '/models/offline_operation.dart';
import '/features/arena/screens/habit_detail_screen.dart';
import '../widgets/habit_card.dart';
import '/providers/theme_provider.dart';

class HabitsTab extends StatefulWidget {
  const HabitsTab({super.key});

  @override
  State<HabitsTab> createState() => HabitsTabState();
}

class HabitsTabState extends State<HabitsTab> with TickerProviderStateMixin {
  final SupabaseService _supabase = SupabaseService();
  bool _isLoading = true;
  String? _currentUserId;

  final Map<String, AnimationController> _animationControllers = {};
  final Map<String, Animation<double>> _animations = {};

  void refreshData() {
    if (!_isLoading) {
      _loadHabits();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHabits();
    });
  }

  @override
  void dispose() {
    for (var controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadHabits() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final user = await _supabase.getCurrentUser();
    if (user != null && mounted) {
      _currentUserId = user.id;

      final syncProvider = Provider.of<SyncProvider>(context, listen: false);

      // ✅ اگه LocalStorage خالیه، از سرور بخون
      if (syncProvider.habits.isEmpty && syncProvider.isOnline) {
        await syncProvider.forceRefresh();
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// ✅ لیست عادت‌های فعال (از SyncProvider مستقیم خونده می‌شه)
  List<Habit> get _habits {
    try {
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);
      return syncProvider.habits
          .where((h) => h.isActive && h.isNotExpired())
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _editHabit(Habit habit) async {
    final isChallengeHabit = habit.title.startsWith('🏆');
    final isQuestHabit = habit.questId != null;

    if (isChallengeHabit || isQuestHabit) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'این عادت مربوط به چالش یا ماموریت است و قابل ویرایش نیست'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => edit_habit.EditHabitScreen(habit: habit)),
    );

    if (result == true && mounted) {
      print('🔄 Habit edited, reloading data...');
      // ✅ SyncProvider خودش notifyListeners می‌کنه و Consumer آپدیت میشه
    }
  }

  Future<void> _deleteHabit(Habit habit) async {
    final isChallengeHabit = habit.title.startsWith('🏆');
    final isQuestHabit = habit.questId != null;

    if (isChallengeHabit || isQuestHabit) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'این عادت مربوط به چالش یا ماموریت است و قابل حذف نیست',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف عادت'),
        content: const Text('آیا از حذف این عادت مطمئن هستید؟'),
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
      syncProvider.removeHabit(habit.id);

      try {
        // ✅ 2. حذف از Supabase
        if (syncProvider.isOnline) {
          await _supabase.deleteHabit(habit.id);

          // ✅ 3. رفرش از سرور تا مطمئن بشیم کش هم آپدیت شد
          await syncProvider.refreshHabitsAndTasks();

          print('✅ Habit deleted and refreshed');
        } else {
          // ✅ حالت آفلاین
          await syncProvider.addOfflineOperation(
            type: OperationType.deleteHabit,
            data: {'id': habit.id},
          );
          print('📝 Habit deletion saved offline: ${habit.title}');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('عادت با موفقیت حذف شد 🗑️'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('❌ Error deleting habit: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطا در حذف عادت: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showTimerDialog(Habit habit) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⏱️ تایمر به زودی اضافه می‌شود'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final Color primaryColor = theme.primaryColor;

    // ✅ Consumer باعث میشه هر بار SyncProvider آپدیت شد، UI رفرش بشه
    return Consumer<SyncProvider>(
      builder: (context, syncProvider, child) {
        final habits = syncProvider.habits
            .where((h) => h.isActive && h.isNotExpired())
            .toList();

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: RefreshIndicator(
            onRefresh: _loadHabits,
            color: primaryColor,
            child: _isLoading && habits.isEmpty
                ? Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  )
                : habits.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.fitness_center_outlined,
                              size: 64,
                              color: theme.textSecondaryColor,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'هیچ عادتی ندارید',
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        itemCount: habits.length,
                        itemBuilder: (context, index) {
                          final habit = habits[index];
                          final bool isQuest = habit.questId != null;
                          final bool isChallenge = habit.challengeId != null;
                          final bool isEditable = !isQuest && !isChallenge;

                          return HabitCard(
                            habit: habit,
                            isCompleted: false,
                            onToggle: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'برای انجام عادت به تب "امروز" بروید'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            onEdit:
                                isEditable ? () => _editHabit(habit) : () {},
                            onDelete:
                                isEditable ? () => _deleteHabit(habit) : () {},
                            onTimer: isEditable
                                ? () => _showTimerDialog(habit)
                                : null,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      HabitDetailScreen(habit: habit),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        );
      },
    );
  }
}
