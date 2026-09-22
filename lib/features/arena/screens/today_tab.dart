// lib/features/arena/screens/today_tab.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/services/supabase_service.dart';
import '/services/date_service.dart';
import '/features/arena/models/habit_model.dart';
import '/features/arena/models/task_model.dart';
import '../category_selection_screen.dart';
import '../add_task_screen.dart';
import '../edit_habit_screen.dart' as edit_habit;
import '../edit_task_screen.dart';
import 'congratulation_screen.dart';
import '/features/explore/models/quest_model.dart';
import '/features/explore/models/user_quest_model.dart';
import '/features/explore/screens/quest_completion_screen.dart';
import '/features/explore/screens/challenge_completion_screen.dart';
import '/providers/sync_provider.dart';
import '/providers/theme_provider.dart';
import 'dart:async';
import '/models/offline_operation.dart';
import '../models/habit_time_tracking.dart';
import '../widgets/habit_timer_widget.dart';
import '../models/timer_setting.dart';
import '../widgets/timer_picker_widget.dart';
import '../widgets/completion_level_picker.dart';
import '../models/habit_completion.dart';
import '/features/arena/screens/habit_detail_screen.dart';
import '../widgets/habit_card.dart';
import '../widgets/task_card.dart';

class TodayTab extends StatefulWidget {
  final DateTime selectedDate;
  final ValueNotifier<int>? profileRefreshNotifier;
  final Function(double)? onProgressUpdate;

  const TodayTab({
    super.key,
    required this.selectedDate,
    this.profileRefreshNotifier,
    this.onProgressUpdate,
  });

  @override
  State<TodayTab> createState() => TodayTabState();
}

class TodayTabState extends State<TodayTab> with TickerProviderStateMixin {
  final SupabaseService _supabase = SupabaseService();

  // ==================== لیست‌های داده ====================
  List<Habit> _todayHabits = [];
  List<Task> _todayTasks = [];
  List<Habit> _completedHabits = [];
  List<Task> _completedTasks = [];

  int _totalTodayItems = 0;
  int _completedItems = 0;

  // ==================== وضعیت‌ها ====================
  bool _isLoading = true;
  String? _currentUserId;
  DateTime? _lastRefreshTime;
  static const _minRefreshInterval = Duration(milliseconds: 500);

  // ==================== وضعیت‌های تکمیل ====================
  final Map<String, bool> _habitCompletionStatus = {};
  final Map<String, bool> _taskCompletedStatus = {};

  // ==================== وضعیت‌های گسترش (Expansion) ====================
  String? _expandedItemId;
  String? _expandedType;
  String? _expandedSubItemId;

  // ==================== کش برای داده‌ها (بهبود سرعت) ====================
  List<Habit>? _cachedHabits;
  List<Task>? _cachedTasks;
  DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(seconds: 30);

  // ==================== انیمیشن‌ها ====================
  final Map<String, AnimationController> _animationControllers = {};
  final Map<String, Animation<double>> _animations = {};

  // ==================== وضعیت تبریک ====================
  bool _hasShownCongratulationToday = false;
  String _lastCheckDate = '';
  int _initialTodayItemsCount = 0;
  bool _initialCountSet = false;

  // ✅ کلیدهای GlobalKey برای ویجت‌های Dismissible (با استفاده از List)
  final List<GlobalKey> _habitKeys = [];
  final List<GlobalKey> _taskKeys = [];

  @override
  void initState() {
    super.initState();
    _initialTodayItemsCount = 0;
    _initialCountSet = false;
    _hasShownCongratulationToday = false;
    _lastCheckDate = '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void refreshData() {
    if (!_isLoading) {
      _cacheTime = null;
      _cachedHabits = null;
      _cachedTasks = null;
      _loadData();
    }
  }

  @override
  void didUpdateWidget(TodayTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _resetState();
      _loadData();
    }
  }

  @override
  void dispose() {
    for (var controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // ==================== متدهای کمکی ====================

  void _resetState() {
    _initialCountSet = false;
    _hasShownCongratulationToday = false;
    _expandedItemId = null;
    _expandedType = null;
    _expandedSubItemId = null;
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

  void _calculateTotalItems() {
    final allHabits = _todayHabits + _completedHabits;
    final allTasks = _todayTasks + _completedTasks;

    final uniqueHabits = <String, Habit>{};
    for (var habit in allHabits) {
      if (!uniqueHabits.containsKey(habit.id)) {
        uniqueHabits[habit.id] = habit;
      }
    }

    _totalTodayItems = uniqueHabits.length + allTasks.length;
    _completedItems = _completedHabits.length + _completedTasks.length;
  }

  void _calculateAndUpdateProgress() {
    if (_totalTodayItems == 0) {
      _calculateTotalItems();
    }

    _completedItems = _completedHabits.length + _completedTasks.length;

    double progress =
        _totalTodayItems > 0 ? _completedItems / _totalTodayItems : 0.0;

    if (progress > 1.0) {
      progress = 1.0;
    }

    if (widget.onProgressUpdate != null) {
      widget.onProgressUpdate!(progress);
    }
  }

  void _resetTotalItems() {
    _totalTodayItems = 0;
    _calculateTotalItems();
    _calculateAndUpdateProgress();
  }

  // ==================== متد تبریک ====================

  void _checkAllCompletedAndShowCongratulation() {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    if (_lastCheckDate == today && _hasShownCongratulationToday) return;

    final hadAnyTaskForToday = _initialTodayItemsCount > 0;
    final allPendingEmpty = _todayHabits.isEmpty && _todayTasks.isEmpty;

    if (hadAnyTaskForToday && allPendingEmpty) {
      final hasAnyCompleted =
          _completedHabits.isNotEmpty || _completedTasks.isNotEmpty;
      if (!hasAnyCompleted) {
        return;
      }

      int todayXP = 0;
      for (var habit in _completedHabits) {
        todayXP += habit.xpReward;
      }
      for (var task in _completedTasks) {
        todayXP += task.xpReward;
      }

      _hasShownCongratulationToday = true;
      _lastCheckDate = today;

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CongratulationScreen(
                todayXP: todayXP,
                totalTasksCompleted: _completedTasks.length,
                totalHabitsCompleted: _completedHabits.length,
              ),
            ),
          ).then((_) {
            if (mounted) {
              _loadData();
            }
          });
        }
      });
    }
  }

  int _calculateTodayXP() {
    int totalXP = 0;
    for (var habit in _completedHabits) {
      totalXP += habit.xpReward;
    }
    for (var task in _completedTasks) {
      totalXP += task.xpReward;
    }
    return totalXP;
  }

  // ==================== بارگذاری داده‌ها ====================

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final user = await _supabase.getCurrentUser();
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      _currentUserId = user.id;

      final syncProvider = Provider.of<SyncProvider>(context, listen: false);

      List<Habit> allHabits = [];
      if (syncProvider.habits.isNotEmpty) {
        allHabits = syncProvider.habits;
      } else if (syncProvider.isOnline) {
        allHabits = await _supabase.getHabits(_currentUserId!);
      }

      List<Task> allTasks = [];
      if (syncProvider.tasks.isNotEmpty) {
        allTasks = syncProvider.tasks;
      } else if (syncProvider.isOnline) {
        allTasks = await _supabase.getTasks(_currentUserId!);
      }

      final List<Habit> pendingHabits = [];
      final List<Habit> completedHabits = [];

      for (var habit in allHabits) {
        if (!habit.isActive) continue;

        bool shouldShow = false;

        if (habit.questId != null) {
          shouldShow = habit.shouldShowQuestOnDate(widget.selectedDate);
        } else if (habit.challengeId != null) {
          shouldShow = habit.shouldDoOnDate(widget.selectedDate);
        } else {
          shouldShow = habit.shouldDoOnDate(widget.selectedDate);
        }

        if (!shouldShow) continue;

        final isCompleted = await _supabase.isHabitCompletedOnDate(
          habit.id,
          _currentUserId!,
          widget.selectedDate,
        );

        if (isCompleted) {
          completedHabits.add(habit);
          _habitCompletionStatus[habit.id] = true;
        } else {
          pendingHabits.add(habit);
        }
      }

      final List<Task> pendingTasks = [];
      final List<Task> completedTasks = [];

      for (var task in allTasks) {
        if (task.dueDate == null) continue;
        if (!task.isForDate(widget.selectedDate)) continue;

        if (task.isCompleted) {
          completedTasks.add(task);
          _taskCompletedStatus[task.id] = true;
        } else {
          pendingTasks.add(task);
        }
      }

      if (mounted) {
        setState(() {
          _todayHabits = pendingHabits;
          _todayTasks = pendingTasks;
          _completedHabits = completedHabits;
          _completedTasks = completedTasks;
          _isLoading = false;
        });
      }

      _resetTotalItems();
    } catch (e) {
      print('❌ Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ==================== متدهای تکمیل عادت و وظیفه (فشرده شده) ====================

  Future<void> _markHabitCompleted(Habit habit) async {
    if (!mounted) return;

    final level = await showDialog<CompletionLevel>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CompletionLevelPicker(
        habitTitle: habit.title,
        habitXpReward: habit.xpReward,
        habitId: habit.id,
        isQuest: habit.questId != null,
        isChallenge: habit.challengeId != null,
        fullDescription: habit.fullDescription,
        halfDescription: habit.halfDescription,
        basicDescription: habit.basicDescription,
        targetValue: habit.targetValue,
        onSelected: (selectedLevel) {
          Navigator.pop(context, selectedLevel);
        },
      ),
    );

    if (level == null || !mounted) return;

    final syncProvider = Provider.of<SyncProvider>(context, listen: false);

    setState(() {
      _todayHabits.remove(habit);
      if (!_completedHabits.contains(habit)) {
        _completedHabits.add(habit);
      }
      _habitCompletionStatus[habit.id] = true;
    });

    _calculateAndUpdateProgress();

    final xpEarned = (habit.xpReward * level.xpMultiplier / 100).round();
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${level.emoji} +$xpEarned XP دریافت شد!'),
          backgroundColor: level.color,
          duration: const Duration(milliseconds: 800),
        ),
      );
    }

    _scheduleProfileRefresh();
    _performDatabaseOperations(habit, level, xpEarned);
  }

  Future<void> _performDatabaseOperations(
      Habit habit, CompletionLevel level, int xpEarned) async {
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);

    try {
      if (syncProvider.isOnline) {
        await Future.wait([
          _supabase.markHabitCompletedWithLevel(
            habitId: habit.id,
            userId: _currentUserId!,
            date: widget.selectedDate,
            level: level,
          ),
          _supabase.recordDailyActivity(
            userId: _currentUserId!,
            date: widget.selectedDate,
            habitsCompleted: _completedHabits.length,
            tasksCompleted: _completedTasks.length,
            xpEarned: _calculateTodayXP(),
            isActive: true,
          ),
        ]);

        if (habit.challengeId != null) {
          await Future.wait([
            _supabase.completeChallengeDay(
              userId: _currentUserId!,
              challengeId: habit.challengeId!,
              date: widget.selectedDate,
            ),
            _supabase.updateChallengeProgress(
              _currentUserId!,
              habit.challengeId!,
            ),
          ]);

          if (widget.profileRefreshNotifier != null) {
            widget.profileRefreshNotifier!.value++;
          }
          unawaited(_checkAndCompleteChallenge(habit));
        }

        if (habit.questId != null) {
          unawaited(_handleQuestCompletion(habit));
        }

        _scheduleProfileRefresh();
      } else {
        await syncProvider.addOfflineOperation(
          type: OperationType.completeHabitWithLevel,
          data: {
            'habitId': habit.id,
            'date': widget.selectedDate.toIso8601String(),
            'xpReward': habit.xpReward,
            'level': level.toString().split('.').last,
          },
        );
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(' انجام شد (آفلاین)'),
              backgroundColor: Colors.orange,
              duration: Duration(milliseconds: 600),
            ),
          );
        }
      }

      _checkAllCompletedAndShowCongratulation();
    } catch (e) {
      print('❌ Error in database operations: $e');
      if (mounted) {
        setState(() {
          _habitCompletionStatus[habit.id] = false;
          _completedHabits.remove(habit);
          if (habit.shouldDoOnDate(widget.selectedDate) &&
              !_todayHabits.contains(habit)) {
            _todayHabits.add(habit);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _checkAndCompleteChallenge(Habit habit) async {
    try {
      final completedChallenge = await _supabase.checkAndCompleteChallenge(
          _currentUserId!, habit.challengeId!);

      if (completedChallenge != null && mounted) {
        if (widget.profileRefreshNotifier != null) {
          widget.profileRefreshNotifier!.value++;
        }

        final progress = await _supabase.getUserChallengeProgressDetails(
          _currentUserId!,
          habit.challengeId!,
        );

        final completedDays = progress['completedDays'] ?? 0;
        final totalDays = progress['totalDays'] ?? 3;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChallengeCompletionScreen(
              challenge: completedChallenge,
              completedDays: completedDays,
              totalDays: totalDays,
            ),
          ),
        );

        _hasShownCongratulationToday = false;
        _initialCountSet = false;

        if (mounted) {
          await _loadData();
        }
      }
    } catch (e) {
      print('⚠️ Challenge completion check error: $e');
    }
  }

  Future<void> _handleQuestCompletion(Habit habit) async {
    try {
      if (habit.questId == null) return;

      final completedQuest =
          await _supabase.updateQuestProgress(_currentUserId!, habit.id);

      if (completedQuest != null && mounted) {
        await _loadData();

        final syncProvider = Provider.of<SyncProvider>(context, listen: false);
        await syncProvider.forceRefresh();

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuestCompletionScreen(
              quest: completedQuest,
              completedDays: completedQuest.targetCount,
            ),
          ),
        );

        if (mounted) {
          await _loadData();
        }
      }
    } catch (e) {
      print('⚠️ Quest completion error: $e');
    }
  }

  void _scheduleProfileRefresh() {
    if (!mounted) return;

    final now = DateTime.now();
    if (_lastRefreshTime == null ||
        now.difference(_lastRefreshTime!) > _minRefreshInterval) {
      _lastRefreshTime = now;

      try {
        if (widget.profileRefreshNotifier != null) {
          widget.profileRefreshNotifier!.value++;
        }
      } catch (e) {
        print('⚠️ Profile refresh error: $e');
      }
    }
  }

  Future<void> _unmarkHabit(Habit habit) async {
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);

    setState(() {
      _completedHabits.remove(habit);
      if (habit.shouldDoOnDate(widget.selectedDate) &&
          !_todayHabits.contains(habit)) {
        _todayHabits.add(habit);
      }
      _habitCompletionStatus[habit.id] = false;
    });

    _calculateAndUpdateProgress();

    Future.microtask(() async {
      try {
        if (syncProvider.isOnline) {
          await _supabase.markHabitCompletedOnDate(
            habit.id,
            _currentUserId!,
            widget.selectedDate,
            false,
          );

          await _supabase.removeXP(_currentUserId!, habit.xpReward);

          if (habit.challengeId != null) {
            await _supabase.removeChallengeDay(
              userId: _currentUserId!,
              challengeId: habit.challengeId!,
              date: widget.selectedDate,
            );
            await _supabase.updateChallengeProgress(
              _currentUserId!,
              habit.challengeId!,
            );
          }

          final hasOtherActivities = await _checkIfTodayHasOtherActivities();

          if (!hasOtherActivities) {
            await _supabase.recordDailyActivity(
              userId: _currentUserId!,
              date: widget.selectedDate,
              habitsCompleted: 0,
              tasksCompleted: 0,
              xpEarned: 0,
              isActive: false,
            );
            await _supabase.updateUserStreak(_currentUserId!);
            _scheduleProfileRefresh();
          } else {
            await _supabase.recordDailyActivity(
              userId: _currentUserId!,
              date: widget.selectedDate,
              habitsCompleted: _completedHabits.length,
              tasksCompleted: _completedTasks.length,
              xpEarned: _calculateTodayXP(),
              isActive: true,
            );
          }

          _scheduleProfileRefresh();
          _hasShownCongratulationToday = false;
          _checkAllCompletedAndShowCongratulation();
          await _loadData();
        } else {
          await syncProvider.addOfflineOperation(
            type: OperationType.uncompleteHabit,
            data: {
              'habitId': habit.id,
              'date': widget.selectedDate.toIso8601String(),
              'xpReward': habit.xpReward,
              'challengeId': habit.challengeId,
            },
          );
        }

        if (habit.questId != null && syncProvider.isOnline) {
          unawaited(_recalculateQuestProgress(_currentUserId!, habit.questId!));
        }
      } catch (e) {
        print('❌ Error unmarking habit: $e');
        if (mounted) {
          setState(() {
            _habitCompletionStatus[habit.id] = true;
            _completedHabits.add(habit);
            _todayHabits.remove(habit);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطا: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  Future<bool> _checkIfTodayHasOtherActivities() async {
    final hasCompletedHabits = _completedHabits.isNotEmpty;
    final hasCompletedTasks = _completedTasks.isNotEmpty;

    if (hasCompletedHabits || hasCompletedTasks) {
      return true;
    }

    try {
      final todayStr = widget.selectedDate.toIso8601String().split('T').first;

      final habitCompletions = await _supabase.client
          .from('habit_completions')
          .select('id, habit_id')
          .eq('user_id', _currentUserId!)
          .eq('date', todayStr);

      if (habitCompletions.isNotEmpty) {
        for (var completion in habitCompletions) {
          final habitId = completion['habit_id'];
          final habit = await _supabase.client
              .from('habits')
              .select('challenge_id, quest_id')
              .eq('id', habitId)
              .maybeSingle();

          if (habit != null &&
              habit['challenge_id'] == null &&
              habit['quest_id'] == null) {
            return true;
          }
        }
      }

      final challengeCompletions = await _supabase.client
          .from('challenge_completions')
          .select('id')
          .eq('user_id', _currentUserId!)
          .eq('date', todayStr)
          .limit(1);

      if (challengeCompletions.isNotEmpty) {
        return true;
      }

      final tasks = await _supabase.client
          .from('tasks')
          .select('id')
          .eq('user_id', _currentUserId!)
          .eq('is_completed', true)
          .eq('due_date', todayStr)
          .limit(1);

      if (tasks.isNotEmpty) {
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _recalculateQuestProgress(String userId, String questId) async {
    try {
      final habits = await _supabase.getHabits(userId);
      final questHabits = habits.where((h) => h.questId == questId).toList();

      int completedCount = 0;
      for (var habit in questHabits) {
        final isCompleted = await _supabase.isHabitCompletedOnDate(
          habit.id,
          userId,
          DateTime.now(),
        );
        if (isCompleted) completedCount++;
      }

      final userQuests = await _supabase.getUserQuests(userId);
      final userQuest = userQuests.firstWhere(
        (uq) => uq.questId == questId && uq.isActive,
      );

      await _supabase.client
          .from('user_quests')
          .update({'progress': completedCount}).eq('id', userQuest.id);
    } catch (e) {
      print('❌ Error recalculating quest progress: $e');
    }
  }

  Future<void> _markTaskCompleted(Task task) async {
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);

    setState(() {
      task.isCompleted = true;
      _taskCompletedStatus[task.id] = true;
      _todayTasks.remove(task);
      if (!_completedTasks.contains(task)) {
        _completedTasks.add(task);
      }
      _initialTodayItemsCount = _todayHabits.length + _todayTasks.length;
    });

    _calculateAndUpdateProgress();

    try {
      if (syncProvider.isOnline) {
        await Future.wait([
          _supabase.updateTask(task),
          _supabase.addXP(_currentUserId!, task.xpReward),
          _supabase.recordDailyActivity(
            userId: _currentUserId!,
            date: widget.selectedDate,
            tasksCompleted: 1,
            xpEarned: task.xpReward,
            isActive: true,
          ),
        ]);
        _scheduleProfileRefresh();
      } else {
        await syncProvider.addOfflineOperation(
          type: OperationType.completeTask,
          data: {...task.toMap(), 'id': task.id, 'xpReward': task.xpReward},
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: syncProvider.isOnline
                ? Text('+${task.xpReward} XP دریافت کردید!')
                : Text(' انجام شد (آفلاین) - پس از اتصال همگام‌سازی می‌شود'),
            backgroundColor:
                syncProvider.isOnline ? Colors.green : Colors.orange,
            duration: const Duration(milliseconds: 800),
          ),
        );
      }

      _checkAllCompletedAndShowCongratulation();
    } catch (e) {
      setState(() {
        task.isCompleted = false;
        _taskCompletedStatus[task.id] = false;
        _completedTasks.remove(task);
        if (task.isForDate(widget.selectedDate) &&
            !_todayTasks.contains(task)) {
          _todayTasks.add(task);
        }
      });
    }
  }

  Future<void> _unmarkTask(Task task) async {
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);

    setState(() {
      task.isCompleted = false;
      _taskCompletedStatus[task.id] = false;
      _completedTasks.remove(task);
      if (task.isForDate(widget.selectedDate) && !_todayTasks.contains(task)) {
        _todayTasks.add(task);
      }
      _initialTodayItemsCount = _todayHabits.length + _todayTasks.length;
    });

    _calculateAndUpdateProgress();

    try {
      final updatedTask = Task(
        id: task.id,
        userId: task.userId,
        title: task.title,
        description: task.description,
        subTasks: task.subTasks,
        completedSubTasks: task.completedSubTasks,
        dueDate: task.dueDate,
        isCompleted: false,
        xpReward: task.xpReward,
        createdAt: task.createdAt,
        updatedAt: DateTime.now(),
      );

      if (syncProvider.isOnline) {
        await _supabase.updateTask(updatedTask);
        await _supabase.removeXP(_currentUserId!, task.xpReward);

        final hasOtherActivities = await _checkIfTodayHasOtherActivities();

        if (!hasOtherActivities) {
          await _supabase.recordDailyActivity(
            userId: _currentUserId!,
            date: widget.selectedDate,
            habitsCompleted: 0,
            tasksCompleted: 0,
            xpEarned: 0,
            isActive: false,
          );
          await _supabase.updateUserStreak(_currentUserId!);
          _scheduleProfileRefresh();
        } else {
          await _supabase.recordDailyActivity(
            userId: _currentUserId!,
            date: widget.selectedDate,
            habitsCompleted: _completedHabits.length,
            tasksCompleted: _completedTasks.length,
            xpEarned: _calculateTodayXP(),
            isActive: true,
          );
        }

        _scheduleProfileRefresh();
      } else {
        await syncProvider.addOfflineOperation(
          type: OperationType.uncompleteTask,
          data: {
            ...updatedTask.toMap(),
            'id': updatedTask.id,
            'xpReward': updatedTask.xpReward,
          },
        );
      }

      _hasShownCongratulationToday = false;
      _checkAllCompletedAndShowCongratulation();
    } catch (e) {
      setState(() {
        task.isCompleted = true;
        _taskCompletedStatus[task.id] = true;
        _completedTasks.add(task);
        _todayTasks.remove(task);
      });
    }
  }

  // ==================== متدهای کمکی ====================

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'fitness_center':
        return Icons.fitness_center;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'book':
        return Icons.book;
      case 'science':
        return Icons.science;
      case 'restaurant':
        return Icons.restaurant;
      case 'bedtime':
        return Icons.bedtime;
      case 'water_drop':
        return Icons.water_drop;
      case 'directions_walk':
        return Icons.directions_walk;
      case 'run_circle':
        return Icons.run_circle;
      case 'emoji_events':
        return Icons.emoji_events;
      default:
        return Icons.fitness_center;
    }
  }

  String _getTimeOfDayText(String timeOfDay) {
    switch (timeOfDay) {
      case 'morning':
        return 'صبح';
      case 'noon':
        return 'ظهر';
      case 'afternoon':
        return 'بعدازظهر';
      case 'night':
        return 'شب';
      default:
        return 'صبح';
    }
  }

  String _getFrequencyText(Habit habit) {
    switch (habit.frequencyType) {
      case 'daily':
        if (habit.dailyIntervalDays != null &&
            habit.dailyIntervalDays!.isNotEmpty) {
          return 'هر ${habit.dailyIntervalDays!.first} روز';
        }
        return 'روزانه';
      case 'weekly':
        if (habit.weeklyDays != null && habit.weeklyDays!.isNotEmpty) {
          return '${habit.weeklyDays!.length} روز در هفته';
        }
        return 'هفتگی';
      case 'monthly':
        if (habit.monthlyDays != null && habit.monthlyDays!.isNotEmpty) {
          return 'ماهانه';
        }
        return 'ماهانه';
      default:
        return 'روزانه';
    }
  }

  void _showHabitDetailsDialog(Habit habit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HabitDetailScreen(habit: habit),
      ),
    );
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
            color: const Color(0xFF4A90E2).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF4A90E2), size: 18),
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

  Future<void> _toggleSubHabit(Habit habit, String subHabit) async {
    List<String> newCompletedSubHabits = List.from(habit.completedSubHabits);

    if (newCompletedSubHabits.contains(subHabit)) {
      newCompletedSubHabits.remove(subHabit);
    } else {
      newCompletedSubHabits.add(subHabit);
    }

    final updatedHabit = Habit(
      id: habit.id,
      userId: habit.userId,
      title: habit.title,
      description: habit.description,
      subHabits: habit.subHabits,
      completedSubHabits: newCompletedSubHabits,
      iconName: habit.iconName,
      iconColor: habit.iconColor,
      backgroundColor: habit.backgroundColor,
      frequencyType: habit.frequencyType,
      dailyIntervalDays: habit.dailyIntervalDays,
      weeklyDays: habit.weeklyDays,
      weeklyIntervalWeeks: habit.weeklyIntervalWeeks,
      monthlyDays: habit.monthlyDays,
      monthlyIntervalMonths: habit.monthlyIntervalMonths,
      timeOfDay: habit.timeOfDay,
      reminders: habit.reminders,
      xpReward: habit.xpReward,
      currentStreak: habit.currentStreak,
      bestStreak: habit.bestStreak,
      isActive: habit.isActive,
      createdAt: habit.createdAt,
      updatedAt: DateTime.now(),
      groupId: habit.groupId,
      startDate: habit.startDate,
      endDate: habit.endDate,
      challengeId: habit.challengeId,
      questId: habit.questId,
      timerSetting: habit.timerSetting,
    );

    final syncProvider = Provider.of<SyncProvider>(context, listen: false);

    setState(() {
      final todayIndex = _todayHabits.indexWhere((h) => h.id == habit.id);
      if (todayIndex != -1) {
        _todayHabits[todayIndex] = updatedHabit;
      }

      final completedIndex =
          _completedHabits.indexWhere((h) => h.id == habit.id);
      if (completedIndex != -1) {
        _completedHabits[completedIndex] = updatedHabit;
      }
    });

    await syncProvider.saveHabitToLocal(updatedHabit);

    if (syncProvider.isOnline) {
      await _supabase.updateHabit(updatedHabit);
    } else {
      await syncProvider.addOfflineOperation(
        type: OperationType.updateHabit,
        data: updatedHabit.toMap(),
      );
    }
  }

  void _toggleExpanded(String id, String type) {
    setState(() {
      if (_expandedItemId == id && _expandedType == type) {
        if (_animationControllers.containsKey(id)) {
          _animationControllers[id]!.reverse();
        }
        _expandedItemId = null;
        _expandedType = null;
        _expandedSubItemId = null;
      } else {
        if (_expandedItemId != null &&
            _animationControllers.containsKey(_expandedItemId)) {
          _animationControllers[_expandedItemId]!.reverse();
        }
        _initAnimation(id);
        _animationControllers[id]!.forward();
        _expandedItemId = id;
        _expandedType = type;
        _expandedSubItemId = null;
      }
    });
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

    final syncProvider = Provider.of<SyncProvider>(context, listen: false);

    setState(() {
      final todayIndex = _todayTasks.indexWhere((t) => t.id == task.id);
      if (todayIndex != -1) {
        _todayTasks[todayIndex] = updatedTask;
      }

      final completedIndex = _completedTasks.indexWhere((t) => t.id == task.id);
      if (completedIndex != -1) {
        _completedTasks[completedIndex] = updatedTask;
      }
    });

    await syncProvider.saveTaskToLocal(updatedTask);

    if (syncProvider.isOnline) {
      await _supabase.updateTask(updatedTask);
    } else {
      await syncProvider.addOfflineOperation(
        type: OperationType.updateTask,
        data: updatedTask.toMap(),
      );
    }
  }

  void _editHabit(Habit habit) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => edit_habit.EditHabitScreen(habit: habit),
      ),
    );

    // ✅ بعد از برگشت از ویرایش، اجباری reload کن
    if (result == true && mounted) {
      print('🔄 Habit edited, reloading data...');

      // ✅ پاک کردن کش
      _cacheTime = null;
      _cachedHabits = null;
      _cachedTasks = null;

      // ✅ reload اجباری
      await _loadData();
      print('✅ Today tab data reloaded');
    }

    _toggleExpanded(habit.id, 'habit');
  }

  void _deleteHabit(Habit habit) async {
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
      await _supabase.deleteHabit(habit.id);
      _loadData();
    }
    _toggleExpanded(habit.id, 'habit');
  }

  void _editTask(Task task) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditTaskScreen(task: task)),
    );
    if (result == true && mounted) {
      // ✅ پاک کردن cache
      _cacheTime = null;
      _cachedTasks = null;
      // ✅ ریفرش اجباری
      await _loadData();
    }
    _toggleExpanded(task.id, 'task');
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
      await _supabase.deleteTask(task.id);
      _loadData();
    }
    _toggleExpanded(task.id, 'task');
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

  // ==================== ویجت‌های Swipe (Dismissible) - نسخه سازگار با Web ====================

  Widget _buildSwipeableHabitItem(Habit habit, Color primaryColor) {
    final bool isQuest = habit.questId != null;
    final bool isChallenge = habit.challengeId != null;
    final bool isEditable = !isQuest && !isChallenge;

    return Dismissible(
      key: UniqueKey(), // ✅ استفاده از UniqueKey به جای ValueKey
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.3,
        DismissDirection.endToStart: 0.3,
      },
      background: _buildSwipeBackground(
        isLeft: true,
        primaryColor: primaryColor,
        label: 'انجام شد ',
        icon: Icons.check_circle,
      ),
      secondaryBackground: _buildSwipeBackground(
        isLeft: false,
        primaryColor: primaryColor,
        label: 'انجام شد ',
        icon: Icons.check_circle,
      ),
      confirmDismiss: (direction) async {
        _markHabitCompleted(habit);
        return false;
      },
      child: HabitCard(
        habit: habit,
        isCompleted: false,
        onToggle: () => _markHabitCompleted(habit),
        onEdit: isEditable ? () => _editHabit(habit) : () {},
        onDelete: isEditable ? () => _deleteHabit(habit) : () {},
        onTimer: isEditable ? () => _showTimerDialog(habit) : null,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HabitDetailScreen(habit: habit),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSwipeableCompletedHabitItem(Habit habit, Color primaryColor) {
    final bool isQuest = habit.questId != null;
    final bool isChallenge = habit.challengeId != null;
    final bool isEditable = !isQuest && !isChallenge;

    final key = ValueKey('completed_habit_${habit.id}');

    return Dismissible(
      key: key,
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.3,
        DismissDirection.endToStart: 0.3,
      },
      background: _buildSwipeBackground(
        isLeft: true,
        primaryColor: Colors.orange,
        label: 'برگردان ',
        icon: Icons.refresh,
      ),
      secondaryBackground: _buildSwipeBackground(
        isLeft: false,
        primaryColor: Colors.orange,
        label: 'برگردان ',
        icon: Icons.refresh,
      ),
      confirmDismiss: (direction) async {
        _unmarkHabit(habit);
        return false;
      },
      child: HabitCard(
        habit: habit,
        isCompleted: true,
        onToggle: () => _unmarkHabit(habit),
        onEdit: isEditable ? () => _editHabit(habit) : () {},
        onDelete: isEditable ? () => _deleteHabit(habit) : () {},
        onTimer: isEditable ? () => _showTimerDialog(habit) : null,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HabitDetailScreen(habit: habit),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSwipeableTaskItem(Task task, Color primaryColor) {
    final key = ValueKey('task_${task.id}');

    return Dismissible(
      key: key,
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.3,
        DismissDirection.endToStart: 0.3,
      },
      background: _buildSwipeBackground(
        isLeft: true,
        primaryColor: primaryColor,
        label: 'انجام شد ',
        icon: Icons.check_circle,
      ),
      secondaryBackground: _buildSwipeBackground(
        isLeft: false,
        primaryColor: primaryColor,
        label: 'انجام شد ',
        icon: Icons.check_circle,
      ),
      confirmDismiss: (direction) async {
        _markTaskCompleted(task);
        return false;
      },
      child: TaskCard(
        task: task,
        isCompleted: false,
        onToggle: () => _markTaskCompleted(task),
        onEdit: () => _editTask(task),
        onDelete: () => _deleteTask(task),
      ),
    );
  }

  Widget _buildSwipeableCompletedTaskItem(Task task, Color primaryColor) {
    final key = ValueKey('completed_task_${task.id}');

    return Dismissible(
      key: key,
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.3,
        DismissDirection.endToStart: 0.3,
      },
      background: _buildSwipeBackground(
        isLeft: true,
        primaryColor: Colors.orange,
        label: 'برگردان ',
        icon: Icons.refresh,
      ),
      secondaryBackground: _buildSwipeBackground(
        isLeft: false,
        primaryColor: Colors.orange,
        label: 'برگردان ',
        icon: Icons.refresh,
      ),
      confirmDismiss: (direction) async {
        _unmarkTask(task);
        return false;
      },
      child: TaskCard(
        task: task,
        isCompleted: true,
        onToggle: () => _unmarkTask(task),
        onEdit: () => _editTask(task),
        onDelete: () => _deleteTask(task),
      ),
    );
  }

  Widget _buildSwipeBackground({
    required bool isLeft,
    required Color primaryColor,
    required String label,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLeft) ...[
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ] else ...[
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: Colors.white, size: 28),
          ],
        ],
      ),
    );
  }

  // ==================== سایر متدها ====================

  Future<HabitTimeTracking?> _getHabitTimeToday(String habitId) async {
    try {
      final user = await _supabase.getCurrentUser();
      if (user == null) return null;

      final today = DateTime.now();
      final dateStr = today.toIso8601String().split('T').first;

      final response = await _supabase.client
          .from('habit_time_tracking')
          .select()
          .eq('habit_id', habitId)
          .eq('user_id', user.id)
          .eq('date', dateStr)
          .maybeSingle();

      if (response != null) {
        return HabitTimeTracking.fromMap(response);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  void _showTimerDialog(Habit habit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TimerDialogContent(
                    habit: habit,
                    initialMinutes: habit.timerSetting?.minutes ?? 10,
                    initialSeconds: habit.timerSetting?.seconds ?? 0,
                    onSave: (minutes, seconds, isCountdown) {
                      _saveTimerSetting(
                          habit.id, minutes, seconds, isCountdown);
                    },
                    onComplete: () {
                      if (mounted) {
                        setState(() {});
                        _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ زمان با موفقیت ثبت شد!'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _saveTimerSetting(
    String habitId,
    int minutes,
    int seconds,
    bool isCountdown,
  ) async {
    try {
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);
      final habits = syncProvider.habits;
      final index = habits.indexWhere((h) => h.id == habitId);

      if (index == -1) return;

      final habit = habits[index];

      final timerSetting = TimerSetting(
        habitId: habitId,
        minutes: minutes,
        seconds: seconds,
        isCountdown: isCountdown,
        isEnabled: true,
      );

      final updatedHabit = Habit(
        id: habit.id,
        userId: habit.userId,
        title: habit.title,
        description: habit.description,
        subHabits: habit.subHabits,
        completedSubHabits: habit.completedSubHabits,
        iconName: habit.iconName,
        iconColor: habit.iconColor,
        backgroundColor: habit.backgroundColor,
        frequencyType: habit.frequencyType,
        dailyIntervalDays: habit.dailyIntervalDays,
        weeklyDays: habit.weeklyDays,
        weeklyIntervalWeeks: habit.weeklyIntervalWeeks,
        monthlyDays: habit.monthlyDays,
        monthlyIntervalMonths: habit.monthlyIntervalMonths,
        timeOfDay: habit.timeOfDay,
        reminders: habit.reminders,
        xpReward: habit.xpReward,
        currentStreak: habit.currentStreak,
        bestStreak: habit.bestStreak,
        isActive: habit.isActive,
        createdAt: habit.createdAt,
        updatedAt: DateTime.now(),
        groupId: habit.groupId,
        startDate: habit.startDate,
        endDate: habit.endDate,
        challengeId: habit.challengeId,
        questId: habit.questId,
        timerSetting: timerSetting,
      );

      final supabase = SupabaseService();
      await supabase.updateHabit(updatedHabit);
      await syncProvider.saveHabitToLocal(updatedHabit);

      if (mounted) {
        setState(() {
          final habitIndex = _todayHabits.indexWhere((h) => h.id == habitId);
          if (habitIndex != -1) {
            _todayHabits[habitIndex] = updatedHabit;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تنظیمات تایمر ذخیره شد'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCompleteHabitDialog(Habit habit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('🎉 تایمر به پایان رسید!'),
        content: Text('آیا عادت "${habit.title}" را انجام دادید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('هنوز نه'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _markHabitCompleted(habit);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('بله، انجام شد '),
          ),
        ],
      ),
    );
  }

  Future<CompletionLevel> _getHabitCompletionLevel(String habitId) async {
    try {
      final date = widget.selectedDate;
      final dateStr = date.toIso8601String().split('T').first;

      final response = await _supabase.client
          .from('habit_completions')
          .select('completion_level')
          .eq('habit_id', habitId)
          .eq('user_id', _currentUserId!)
          .eq('date', dateStr)
          .maybeSingle();

      if (response != null && response['completion_level'] != null) {
        final levelStr = response['completion_level'] as String;
        return CompletionLevelExtension.fromString(levelStr);
      }

      return CompletionLevel.full;
    } catch (e) {
      return CompletionLevel.full;
    }
  }

  // ==================== Main Build ====================

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final Color primaryColor = themeProvider.primaryColor;

    return Consumer<SyncProvider>(
      builder: (context, syncProvider, child) {
        if (_isLoading && !syncProvider.hasLocalData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: primaryColor),
                const SizedBox(height: 16),
                const Text(
                  'در حال بارگذاری اطلاعات...',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ],
            ),
          );
        }

        if (syncProvider.hasLocalData) {
          return RefreshIndicator(
            onRefresh: _loadData,
            color: primaryColor,
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: _buildTodayContent(primaryColor),
                  ),
          );
        }

        if (!syncProvider.hasLocalData && !syncProvider.isOnline) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'اتصال اینترنت برقرار نیست',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'برای مشاهده اطلاعات به اتصال اینترنت نیاز دارید',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('تلاش مجدد'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadData,
          color: primaryColor,
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: primaryColor),
                )
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: _buildTodayContent(primaryColor),
                ),
        );
      },
    );
  }

  Widget _buildTodayContent(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_todayHabits.isNotEmpty || _todayTasks.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._todayHabits
              .map((habit) => _buildSwipeableHabitItem(habit, primaryColor)),
          ..._todayTasks
              .map((task) => _buildSwipeableTaskItem(task, primaryColor)),
          const SizedBox(height: 24),
        ],
        if (_completedHabits.isNotEmpty || _completedTasks.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.check_circle,
                  color: const Color.fromARGB(255, 0, 0, 0), size: 20),
              const SizedBox(width: 8),
              const Text(
                'انجام شده',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 0, 0, 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._completedHabits.map((habit) =>
              _buildSwipeableCompletedHabitItem(habit, primaryColor)),
          ..._completedTasks.map(
              (task) => _buildSwipeableCompletedTaskItem(task, primaryColor)),
          const SizedBox(height: 24),
        ],
        if (_todayHabits.isEmpty &&
            _todayTasks.isEmpty &&
            _completedHabits.isEmpty &&
            _completedTasks.isEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 100),
                Icon(
                  Icons.check_circle_outline,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'هیچ کاری برای این روز ندارید!',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 8),
                Text(
                  'روی دکمه + کلیک کنید',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TimerDialogContent extends StatefulWidget {
  final Habit habit;
  final int initialMinutes;
  final int initialSeconds;
  final Function(int, int, bool) onSave;
  final VoidCallback onComplete;

  const _TimerDialogContent({
    super.key,
    required this.habit,
    required this.initialMinutes,
    required this.initialSeconds,
    required this.onSave,
    required this.onComplete,
  });

  @override
  State<_TimerDialogContent> createState() => _TimerDialogContentState();
}

class _TimerDialogContentState extends State<_TimerDialogContent> {
  late int _minutes;
  late int _seconds;
  late bool _isCountdown;

  @override
  void initState() {
    super.initState();
    _minutes = widget.initialMinutes;
    _seconds = widget.initialSeconds;
    _isCountdown = widget.habit.timerSetting?.isCountdown ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final Color primaryColor = themeProvider.primaryColor;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '⏱️ تایمر عادت',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
          ),
          const SizedBox(height: 8),
          Text(
            widget.habit.title,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TimerPickerWidget(
            initialMinutes: _minutes,
            initialSeconds: _seconds,
            onMinutesChanged: (value) {
              setState(() {
                _minutes = value;
              });
            },
            onSecondsChanged: (value) {
              setState(() {
                _seconds = value;
              });
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_minutes.toString().padLeft(2, '0')}:${_seconds.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: primaryColor,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 16),
          HabitTimerWidget(
            habitId: widget.habit.id,
            habitTitle: widget.habit.title,
            onTimeSaved: () {
              Navigator.pop(context);
              widget.onComplete();
            },
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              widget.onSave(_minutes, _seconds, _isCountdown);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.save, size: 18),
            label: const Text('ذخیره تنظیمات تایمر'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
