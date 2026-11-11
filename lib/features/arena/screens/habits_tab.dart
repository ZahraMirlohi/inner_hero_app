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
import '../widgets/task_card.dart';
import '/l10n/app_strings.dart';
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

      // اگه LocalStorage خالیه، از سرور بخون
      if (syncProvider.habits.isEmpty && syncProvider.isOnline) {
        await syncProvider.forceRefresh();
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// لیست عادت‌های فعال (از SyncProvider مستقیم خونده می‌شه)
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
        showArenaSnack(context, context.tr('ah.habits.noEdit'),
            kind: ArenaSnackKind.warning);
      }
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => edit_habit.EditHabitScreen(habit: habit)),
    );

    if (result == true && mounted) {
      print('Habit edited, reloading data...');
      // SyncProvider خودش notifyListeners می‌کنه و Consumer آپدیت میشه
    }
  }

  Future<void> _deleteHabit(Habit habit) async {
    final isChallengeHabit = habit.title.startsWith('🏆');
    final isQuestHabit = habit.questId != null;

    if (isChallengeHabit || isQuestHabit) {
      if (mounted) {
        showArenaSnack(context, context.tr('ah.habits.noDelete'),
            kind: ArenaSnackKind.warning);
      }
      return;
    }

    final confirm = await showArenaDeleteDialog(
      context,
      title: context.tr('ah.habits.delTitle'),
      message: context.tr('ah.habits.delMsg'),
    );

    if (confirm == true && mounted) {
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);

      // 1. حذف فوری از LocalStorage
      syncProvider.removeHabit(habit.id);

      try {
        // 2. حذف از Supabase
        if (syncProvider.isOnline) {
          await _supabase.deleteHabit(habit.id);

          // 3. رفرش از سرور تا مطمئن بشیم کش هم آپدیت شد
          await syncProvider.refreshHabitsAndTasks();

          print('Habit deleted and refreshed');
        } else {
          // حالت آفلاین
          await syncProvider.addOfflineOperation(
            type: OperationType.deleteHabit,
            data: {'id': habit.id},
          );
          print('Habit deletion saved offline: ${habit.title}');
        }

        if (mounted) {
          showArenaSnack(context, context.tr('ah.habits.deleted'),
              kind: ArenaSnackKind.dark);
        }
      } catch (e) {
        print('Error deleting habit: $e');
        if (mounted) {
          showArenaSnack(context,
              context.tr('ah.habits.delError', {'e': e.toString()}),
              kind: ArenaSnackKind.error);
        }
      }
    }
  }

  void _showTimerDialog(Habit habit) {
    showArenaSnack(context, context.tr('ah.habits.timerSoon'),
        kind: ArenaSnackKind.info, duration: const Duration(seconds: 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final Color primaryColor = theme.primaryColor;

    // Consumer باعث میشه هر بار SyncProvider آپدیت شد، UI رفرش بشه
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
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 170),
                    children: const [ArenaLoadingView()],
                  )
                : habits.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 170),
                        children: [
                          ArenaStateView(
                            icon: Icons.fitness_center_rounded,
                            title: context.tr('ah.habits.emptyTitle'),
                            subtitle: context.tr('ah.empty.sub'),
                            actionLabel: context.tr('ah.fab.habit'),
                            actionIcon: Icons.add_rounded,
                            onAction: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const CategorySelectionScreen()),
                            ).then((_) => refreshData()),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 170),
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
                              showArenaSnack(context, context.tr('ah.habits.toastToday'),
                                  kind: ArenaSnackKind.info,
                                  duration: const Duration(seconds: 1),
                                  clearPrevious: true);
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
