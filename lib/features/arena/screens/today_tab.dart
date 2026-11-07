// lib/features/arena/screens/today_tab.dart

import '/services/sound_service.dart';
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
import '/core/app_palette.dart';
import '/l10n/app_strings.dart';
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
  final void Function(int done, int total)? onStatsUpdate;

  const TodayTab({
    super.key,
    required this.selectedDate,
    this.profileRefreshNotifier,
    this.onProgressUpdate,
    this.onStatsUpdate,
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
  final List<Habit> pendingHabits = [];

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
  final Map<String, int> _habitRecordedTimes = {};

  // ==================== وضعیت‌های گسترش ====================
  String? _expandedItemId;
  String? _expandedType;
  String? _expandedSubItemId;

  // ==================== کش ====================
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
    widget.onStatsUpdate?.call(_completedItems, _totalTodayItems);
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

  bool _hasLoadedOnce = false;

  Future<void> _loadData() async {
    if (!mounted) return;

    // فقط بار اول «در حال بارگذاری» نشان بده؛ رفرش‌های بعدی بی‌صدا جایگزین می‌شوند
    if (!_hasLoadedOnce) setState(() => _isLoading = true);

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

      // دو درخواست برای کل روز (قبلاً دو درخواست برای هر عادت بود)
      Set<String>? completedIds;
      if (syncProvider.isOnline) {
        final results = await Future.wait([
          _supabase.getCompletedHabitIdsOnDate(
              _currentUserId!, widget.selectedDate),
          _supabase.getHabitTimesOnDate(_currentUserId!, widget.selectedDate),
        ]);
        completedIds = results[0] as Set<String>?;
        _habitRecordedTimes.addAll(results[1] as Map<String, int>);
      }

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

        // آفلاین یا خطا: به وضعیتی که قبلاً در حافظه داریم تکیه می‌کنیم
        final isCompleted = completedIds != null
            ? completedIds.contains(habit.id)
            : (_habitCompletionStatus[habit.id] == true);

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
          _hasLoadedOnce = true;
        });
      }

      _resetTotalItems();
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ==================== متدهای تکمیل عادت و وظیفه ====================

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
    SoundService.instance
        .play(level == CompletionLevel.full ? Sfx.complete : Sfx.check);
    if (mounted) {
      showArenaSnack(
        context,
        context.tr('ah.today.xpEarned', {'xp': '$xpEarned'}),
        kind: ArenaSnackKind.success,
        duration: const Duration(milliseconds: 1200),
        clearPrevious: true,
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
          // ترتیبی (نه همزمان): اول ثبت روز، بعد شمارش پیشرفت
          try {
            await _supabase.completeChallengeDay(
              userId: _currentUserId!,
              challengeId: habit.challengeId!,
              date: widget.selectedDate,
            );
          } catch (e) {
            if (mounted) {
              showArenaSnack(context, 'ثبت پیشرفت چالش ناموفق بود: $e',
                  kind: ArenaSnackKind.error);
            }
          }

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
          showArenaSnack(
            context,
            context.tr('ah.today.doneOffline'),
            kind: ArenaSnackKind.warning,
            duration: const Duration(milliseconds: 1200),
            clearPrevious: true,
          );
        }
      }

      _checkAllCompletedAndShowCongratulation();
    } catch (e) {
      print('Error in database operations: $e');
      if (mounted) {
        setState(() {
          _habitCompletionStatus[habit.id] = false;
          _completedHabits.remove(habit);
          if (habit.shouldDoOnDate(widget.selectedDate) &&
              !_todayHabits.contains(habit)) {
            _todayHabits.add(habit);
          }
        });

        showArenaSnack(context, context.tr('ad.tmr.error', {'e': e.toString()}),
            kind: ArenaSnackKind.error);
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
      print('Challenge completion check error: $e');
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
      print('Quest completion error: $e');
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
        print('Profile refresh error: $e');
      }
    }
  }

  Future<void> _unmarkHabit(Habit habit) async {
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);
    SoundService.instance.play(Sfx.tap);

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
          await _supabase.uncompleteHabitAndRefundXp(
            habitId: habit.id,
            userId: _currentUserId!,
            date: widget.selectedDate,
          );

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
        print('Error unmarking habit: $e');
        if (mounted) {
          setState(() {
            _habitCompletionStatus[habit.id] = true;
            _completedHabits.add(habit);
            _todayHabits.remove(habit);
          });
          showArenaSnack(context, context.tr('ad.tmr.error', {'e': e.toString()}),
            kind: ArenaSnackKind.error);
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
      print('Error recalculating quest progress: $e');
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

    SoundService.instance.play(Sfx.complete);

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
        showArenaSnack(
          context,
          syncProvider.isOnline
              ? context.tr('ah.today.xpEarned', {'xp': '${task.xpReward}'})
              : context.tr('ah.today.taskOffline'),
          kind: syncProvider.isOnline
              ? ArenaSnackKind.success
              : ArenaSnackKind.warning,
          duration: const Duration(milliseconds: 1200),
          clearPrevious: true,
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

  void _showHabitDetailsDialog(Habit habit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HabitDetailScreen(habit: habit),
      ),
    );
  }

  void _showTaskDetailsDialog(Task task) async {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    String dueDateStr = '';
    if (task.dueDate != null) {
      dueDateStr = await DateService.formatDate(task.dueDate!);
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xFF090909).withValues(alpha: 0.42),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.borderColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  context.tr(task.isCompleted ? 'ah.td.done' : 'ah.td.pending'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: theme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: task.isCompleted
                            ? theme.successColor
                            : theme.cardSecondaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        task.isCompleted
                            ? Icons.check_circle_outline_rounded
                            : Icons.assignment_outlined,
                        color: task.isCompleted
                            ? const Color(0xFF090909)
                            : theme.textSecondaryColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: theme.textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            task.description.isEmpty
                                ? context.tr('ah.td.noDesc')
                                : task.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(height: 1, color: theme.cardSecondaryColor),
                const SizedBox(height: 14),
                if (task.dueDate != null) ...[
                  _buildDetailRow(
                    Icons.calendar_today_rounded,
                    context.tr('ah.td.due'),
                    dueDateStr,
                    theme,
                  ),
                  const SizedBox(height: 14),
                ],
                _buildDetailRow(
                  Icons.star_outline_rounded,
                  context.tr('ah.td.xp'),
                  '${task.xpReward} XP',
                  theme,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
      IconData icon, String label, String value, ThemeProvider theme) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: theme.primarySoft,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: theme.textColor, size: 19),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.textColor,
          ),
        ),
        const Spacer(),
        Text(value,
            style: TextStyle(fontSize: 14, color: theme.textSecondaryColor)),
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
        data: {...updatedTask.toMap(), 'id': updatedTask.id},
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

    if (result == true && mounted) {
      print('Habit edited, reloading data...');

      _cacheTime = null;
      _cachedHabits = null;
      _cachedTasks = null;

      await _loadData();
      print('Today tab data reloaded');
    }

    _toggleExpanded(habit.id, 'habit');
  }

  void _deleteHabit(Habit habit) async {
    final confirm = await showArenaDeleteDialog(
      context,
      title: context.tr('ah.habits.delTitle'),
      message: context.tr('ah.habits.delMsg'),
    );

    if (confirm == true && mounted) {
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);

      // 1. حذف از state محلی
      setState(() {
        _todayHabits.removeWhere((h) => h.id == habit.id);
        _completedHabits.removeWhere((h) => h.id == habit.id);
      });

      // 2. حذف از LocalStorage
      syncProvider.removeHabit(habit.id);

      try {
        // 3. حذف از Supabase
        if (syncProvider.isOnline) {
          await _supabase.deleteHabit(habit.id);

          // 4. رفرش
          await syncProvider.refreshHabitsAndTasks();
        }

        // 5. رفرش دیتای صفحه
        await _loadData();
      } catch (e) {
        print('Error deleting habit: $e');
        if (mounted) {
          showArenaSnack(context,
              context.tr('ah.habits.delError', {'e': e.toString()}),
              kind: ArenaSnackKind.error);
        }
      }

      _toggleExpanded(habit.id, 'habit');
    }
  }

  void _editTask(Task task) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditTaskScreen(task: task)),
    );
    if (result == true && mounted) {
      _cacheTime = null;
      _cachedTasks = null;
      await _loadData();
    }
    _toggleExpanded(task.id, 'task');
  }

  void _deleteTask(Task task) async {
    final confirm = await showArenaDeleteDialog(
      context,
      title: context.tr('ah.tasks.delTitle'),
      message: context.tr('ah.tasks.delMsg'),
    );

    if (confirm == true && mounted) {
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);

      // 1. حذف از state محلی
      setState(() {
        _todayTasks.removeWhere((t) => t.id == task.id);
        _completedTasks.removeWhere((t) => t.id == task.id);
      });

      // 2. حذف از LocalStorage
      await syncProvider.deleteTaskFromLocal(task.id);

      try {
        // 3. حذف از Supabase
        if (syncProvider.isOnline) {
          await _supabase.deleteTask(task.id);

          // 4. رفرش
          await syncProvider.refreshHabitsAndTasks();
        }

        // 5. رفرش دیتای صفحه
        await _loadData();
      } catch (e) {
        print('Error deleting task: $e');
        if (mounted) {
          showArenaSnack(context,
              context.tr('ah.tasks.delError', {'e': e.toString()}),
              kind: ArenaSnackKind.error);
        }
      }

      _toggleExpanded(task.id, 'task');
    }
  }

  // ==================== ویجت‌های Swipe ====================

  Widget _buildSwipeableHabitItem(Habit habit, Color primaryColor) {
    final bool isQuest = habit.questId != null;
    final bool isChallenge = habit.challengeId != null;
    final bool isEditable = !isQuest && !isChallenge;

    return Dismissible(
      key: ValueKey('dismissible_habit_${habit.id}'),
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.3,
        DismissDirection.endToStart: 0.3,
      },
      background: _buildSwipeBackground(
        isLeft: true,
        primaryColor: primaryColor,
        label: context.tr('ah.swipe.done'),
        icon: Icons.check_circle_outline_rounded,
      ),
      secondaryBackground: _buildSwipeBackground(
        isLeft: false,
        primaryColor: primaryColor,
        label: context.tr('ah.swipe.done'),
        icon: Icons.check_circle_outline_rounded,
      ),
      confirmDismiss: (direction) async {
        _markHabitCompleted(habit);
        return false;
      },
      child: HabitCard(
        key: ValueKey('habit_card_${habit.id}'),
        habit: habit,
        isCompleted: false,
        recordedTimeSeconds: _habitRecordedTimes[habit.id], // پاس دادن زمان
        onToggle: () => _markHabitCompleted(habit),
        onEdit: isEditable ? () => _editHabit(habit) : () {},
        onDelete: isEditable ? () => _deleteHabit(habit) : () {},
        onTimer: isEditable ? () => _showTimerDialog(habit) : null,
        onToggleSubHabit: (subHabit) => _toggleSubHabit(habit, subHabit),
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

    return Dismissible(
      key: ValueKey('dismissible_completed_habit_${habit.id}'),
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.3,
        DismissDirection.endToStart: 0.3,
      },
      background: _buildSwipeBackground(
        isLeft: true,
        primaryColor: Provider.of<ThemeProvider>(context, listen: false)
            .accentGold,
        label: context.tr('ah.swipe.undo'),
        icon: Icons.refresh_rounded,
      ),
      secondaryBackground: _buildSwipeBackground(
        isLeft: false,
        primaryColor: Provider.of<ThemeProvider>(context, listen: false)
            .accentGold,
        label: context.tr('ah.swipe.undo'),
        icon: Icons.refresh_rounded,
      ),
      confirmDismiss: (direction) async {
        _unmarkHabit(habit);
        return false;
      },
      child: HabitCard(
        key: ValueKey('completed_habit_card_${habit.id}'),
        habit: habit,
        isCompleted: true,
        onToggle: () => _unmarkHabit(habit),
        onEdit: isEditable ? () => _editHabit(habit) : () {},
        onDelete: isEditable ? () => _deleteHabit(habit) : () {},
        onTimer: isEditable ? () => _showTimerDialog(habit) : null,
        onToggleSubHabit: (subHabit) => _toggleSubHabit(habit, subHabit),
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
    return Dismissible(
      key: ValueKey('dismissible_task_${task.id}'),
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.3,
        DismissDirection.endToStart: 0.3,
      },
      background: _buildSwipeBackground(
        isLeft: true,
        primaryColor: primaryColor,
        label: context.tr('ah.swipe.done'),
        icon: Icons.check_circle_outline_rounded,
      ),
      secondaryBackground: _buildSwipeBackground(
        isLeft: false,
        primaryColor: primaryColor,
        label: context.tr('ah.swipe.done'),
        icon: Icons.check_circle_outline_rounded,
      ),
      confirmDismiss: (direction) async {
        _markTaskCompleted(task);
        return false;
      },
      child: TaskCard(
        key: ValueKey('task_card_${task.id}'),
        task: task,
        isCompleted: false,
        onToggle: () => _markTaskCompleted(task),
        onEdit: () => _editTask(task),
        onDelete: () => _deleteTask(task),
        onToggleSubTask: (subTask) => _toggleSubTask(task, subTask),
        onDetails: () => _showTaskDetailsDialog(task),
      ),
    );
  }

  Widget _buildSwipeableCompletedTaskItem(Task task, Color primaryColor) {
    return Dismissible(
      key: ValueKey('dismissible_completed_task_${task.id}'),
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.3,
        DismissDirection.endToStart: 0.3,
      },
      background: _buildSwipeBackground(
        isLeft: true,
        primaryColor: Provider.of<ThemeProvider>(context, listen: false)
            .accentGold,
        label: context.tr('ah.swipe.undo'),
        icon: Icons.refresh_rounded,
      ),
      secondaryBackground: _buildSwipeBackground(
        isLeft: false,
        primaryColor: Provider.of<ThemeProvider>(context, listen: false)
            .accentGold,
        label: context.tr('ah.swipe.undo'),
        icon: Icons.refresh_rounded,
      ),
      confirmDismiss: (direction) async {
        _unmarkTask(task);
        return false;
      },
      child: TaskCard(
        key: ValueKey('completed_task_card_${task.id}'),
        task: task,
        isCompleted: true,
        onToggle: () => _unmarkTask(task),
        onEdit: () => _editTask(task),
        onDelete: () => _deleteTask(task),
        onToggleSubTask: (subTask) => _toggleSubTask(task, subTask),
        onDetails: () => _showTaskDetailsDialog(task),
      ),
    );
  }

  Widget _buildSwipeBackground({
    required bool isLeft,
    required Color primaryColor,
    required String label,
    required IconData icon,
    Color? foreground,
  }) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final Color fg = foreground ??
        (primaryColor == theme.accentGold
            ? Colors.white
            : theme.onPrimaryColor);
    final iconWidget = Icon(icon, color: fg, size: 22);
    final text = Text(
      label,
      style: TextStyle(
        color: fg,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(28),
      ),
      alignment:
          isLeft ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: isLeft
            ? [iconWidget, const SizedBox(width: 8), text]
            : [text, const SizedBox(width: 8), iconWidget],
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

// lib/features/arena/screens/today_tab.dart

  void _showTimerDialog(Habit habit) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      barrierColor: const Color(0xFF090909).withValues(alpha: 0.42),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 14, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.borderColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  _TimerDialogContent(
                    habit: habit,
                    initialMinutes: habit.timerSetting?.minutes ?? 10,
                    initialSeconds: habit.timerSetting?.seconds ?? 0,
                    onSave: (minutes, seconds, isCountdown) {
                      _saveTimerSetting(
                          habit.id, minutes, seconds, isCountdown);
                    },
                    onComplete: () {
                      // 1. اول BottomSheet رو ببند
                      Navigator.of(bottomSheetContext).pop();

                      // 2. بعد از بسته شدن، زمان رو از سرور بخون
                      Future.microtask(() async {
                        if (!mounted) return;
                        await _reloadHabitTime(habit.id);
                        // 3. refresh سبک از سرور برای همگام‌سازی
                        try {
                          final syncProvider =
                              Provider.of<SyncProvider>(context, listen: false);
                          if (syncProvider.isOnline) {
                            await syncProvider.refreshHabitsAndTasks();
                          }
                        } catch (e) {
                          print('Error refreshing after timer: $e');
                        }

                        if (mounted) {
                          showArenaSnack(context, context.tr('at.snack.timeSaved'),
                              kind: ArenaSnackKind.success);
                        }
                      });
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

  /// خوندن مجدد زمان رکورد شده یک عادت
  Future<void> _reloadHabitTime(String habitId) async {
    if (_currentUserId == null) return;

    try {
      final timeSeconds = await _supabase.getHabitTimeOnDate(
        habitId: habitId,
        userId: _currentUserId!,
        date: widget.selectedDate,
      );

      if (mounted) {
        setState(() {
          if (timeSeconds != null && timeSeconds > 0) {
            _habitRecordedTimes[habitId] = timeSeconds;
          } else {
            _habitRecordedTimes.remove(habitId);
          }
        });
      }
    } catch (e) {
      print('Error reloading habit time: $e');
    }
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

        showArenaSnack(context, context.tr('at.snack.settingsSaved'),
            kind: ArenaSnackKind.success);
      }
    } catch (e) {
      if (mounted) {
        showArenaSnack(context, context.tr('ad.tmr.error', {'e': e.toString()}),
            kind: ArenaSnackKind.error);
      }
    }
  }

  Future<void> _showCompleteHabitDialog(Habit habit) async {
    final yes = await showHabitTimerEndDialog(context, habit.title);
    if (yes == true && mounted) _markHabitCompleted(habit);
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
    final theme = Provider.of<ThemeProvider>(context);
    final Color primaryColor = theme.primaryColor;

    return Consumer<SyncProvider>(
      builder: (context, syncProvider, child) {
        if (_isLoading && !syncProvider.hasLocalData) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 170),
            children: const [ArenaLoadingView()],
          );
        }

        if (syncProvider.hasLocalData) {
          return RefreshIndicator(
            onRefresh: _loadData,
            color: primaryColor,
            child: _isLoading
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 170),
                    children: const [ArenaLoadingView()],
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 170),
                    child: _buildTodayContent(primaryColor, theme),
                  ),
          );
        }

        if (!syncProvider.hasLocalData && !syncProvider.isOnline) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 170),
            children: [
              ArenaStateView(
                icon: Icons.wifi_off_rounded,
                tone: Tone.rose,
                title: context.tr('ah.offline.title'),
                subtitle: context.tr('ah.offline.sub'),
                actionLabel: context.tr('ah.offline.retry'),
                actionIcon: Icons.refresh_rounded,
                onAction: _loadData,
              ),
            ],
          );
        }

        return RefreshIndicator(
          onRefresh: _loadData,
          color: primaryColor,
          child: _isLoading
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 170),
                  children: const [ArenaLoadingView()],
                )
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 170),
                  child: _buildTodayContent(primaryColor, theme),
                ),
        );
      },
    );
  }

  Widget _buildTodayContent(Color primaryColor, ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_todayHabits.isNotEmpty || _todayTasks.isNotEmpty) ...[
          const SizedBox(height: 8),
          ..._todayHabits
              .map((habit) => _buildSwipeableHabitItem(habit, primaryColor)),
          ..._todayTasks
              .map((task) => _buildSwipeableTaskItem(task, primaryColor)),
          const SizedBox(height: 16),
        ],
        if (_completedHabits.isNotEmpty || _completedTasks.isNotEmpty) ...[
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  color: theme.textColor,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  context.tr('ah.today.doneHeader'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.cardSecondaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_completedHabits.length + _completedTasks.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ..._completedHabits.map((habit) =>
              _buildSwipeableCompletedHabitItem(habit, primaryColor)),
          ..._completedTasks.map(
              (task) => _buildSwipeableCompletedTaskItem(task, primaryColor)),
          const SizedBox(height: 16),
        ],
        if (_todayHabits.isEmpty &&
            _todayTasks.isEmpty &&
            _completedHabits.isEmpty &&
            _completedTasks.isEmpty)
          ArenaStateView(
            icon: Icons.check_circle_outline_rounded,
            title: context.tr('ah.today.emptyTitle'),
            subtitle: context.tr('ah.today.emptySub'),
          ),
      ],
    );
  }
}

// در today_tab.dart، انتهای فایل

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
    final theme = Provider.of<ThemeProvider>(context);
    final Color primaryColor = theme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('ah.timer.title'),
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: theme.textColor),
          ),
          const SizedBox(height: 8),
          Text(
            widget.habit.title,
            style: TextStyle(fontSize: 14, color: theme.textSecondaryColor),
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
              color: theme.primarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              '${_minutes.toString().padLeft(2, '0')}:${_seconds.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: theme.textColor,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 16),
          HabitTimerWidget(
            habitId: widget.habit.id,
            habitTitle: widget.habit.title,
            onTimeSaved: () {
              // فقط callback رو صدا بزن، Navigator رو خود والد مدیریت می‌کنه
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
            label: Text(context.tr('ah.timer.save')),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: theme.onPrimaryColor,
              minimumSize: const Size.fromHeight(56),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
