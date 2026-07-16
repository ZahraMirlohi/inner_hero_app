import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/services/supabase_service.dart';
import '/services/date_service.dart';
import '/features/arena/models/habit_model.dart';
import '/features/arena/models/task_model.dart';
import '../category_selection_screen.dart';
import '../add_task_screen.dart';
import '../edit_habit_screen.dart';
import '../edit_task_screen.dart';
import 'congratulation_screen.dart';
import '/features/explore/models/quest_model.dart';
import '/features/explore/models/user_quest_model.dart';
import '/features/explore/screens/quest_completion_screen.dart';
import '/features/explore/screens/challenge_completion_screen.dart';
import '/../providers/sync_provider.dart';
import 'dart:async';
import '/models/offline_operation.dart';

class TodayTab extends StatefulWidget {
  final DateTime selectedDate;
  final ValueNotifier<int>? profileRefreshNotifier;

  const TodayTab({
    super.key,
    required this.selectedDate,
    this.profileRefreshNotifier,
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
  List<Habit> _failedHabits = [];
  List<Task> _failedTasks = [];

  // ==================== وضعیت‌ها ====================
  bool _isLoading = true;
  String? _currentUserId;

  // ==================== وضعیت‌های تکمیل ====================
  final Map<String, bool> _habitCompletionStatus = {};
  final Map<String, bool> _habitFailedStatus = {};
  final Map<String, bool> _taskCompletedStatus = {};
  final Map<String, bool> _taskFailedStatus = {};

  // ==================== وضعیت‌های گسترش (Expansion) ====================
  String? _expandedItemId;
  String? _expandedType;
  String? _expandedSubItemId;

  // ==================== کش برای داده‌ها (بهبود سرعت) ====================
  List<Habit>? _cachedHabits;
  List<Task>? _cachedTasks;
  DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(seconds: 30);

  // ==================== منوی شناور ====================
  bool _isMenuOpen = false;
  late AnimationController _menuAnimationController;

  // ==================== انیمیشن‌ها ====================
  final Map<String, AnimationController> _animationControllers = {};
  final Map<String, Animation<double>> _animations = {};

  // ==================== وضعیت تبریک ====================
  bool _hasShownCongratulationToday = false;
  String _lastCheckDate = '';
  int _initialTodayItemsCount = 0;
  bool _initialCountSet = false;

  // ==================== متدهای چرخه حیات ====================
  void refreshData() {
    if (!_isLoading) {
      _loadData();
    }
  }

  @override
  void initState() {
    super.initState();
    _menuAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _initialTodayItemsCount = 0;
    _initialCountSet = false;
    _hasShownCongratulationToday = false;
    _lastCheckDate = '';
    _loadData();
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
    _menuAnimationController.dispose();
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

  // ==================== متد تبریک ====================

  void _checkAllCompletedAndShowCongratulation() {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    if (_lastCheckDate == today && _hasShownCongratulationToday) return;

    final hadAnyTaskForToday = _initialTodayItemsCount > 0;
    final allPendingEmpty = _todayHabits.isEmpty && _todayTasks.isEmpty;
    final hasFailedItems = _failedHabits.isNotEmpty || _failedTasks.isNotEmpty;

    if (hadAnyTaskForToday && allPendingEmpty && !hasFailedItems) {
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

      // ✅ اولویت با داده‌های محلی
      List<Habit> allHabits = [];
      List<Task> allTasks = [];

      if (syncProvider.habits.isNotEmpty) {
        allHabits = syncProvider.habits;
        print('✅ Using ${allHabits.length} habits from local storage');
      } else if (syncProvider.isOnline) {
        allHabits = await _supabase.getHabits(_currentUserId!);
        if (allHabits.isNotEmpty) {
          await syncProvider.saveProfileToLocal({'habits': allHabits});
        }
      }

      if (syncProvider.tasks.isNotEmpty) {
        allTasks = syncProvider.tasks;
        print('✅ Using ${allTasks.length} tasks from local storage');
      } else if (syncProvider.isOnline) {
        allTasks = await _supabase.getTasks(_currentUserId!);
      }

      // ✅ پردازش عادت‌ها
      final List<Habit> pendingHabits = [];
      final List<Habit> completedHabits = [];
      final List<Habit> failedHabits = [];

      for (var habit in allHabits) {
        if (!habit.isActive) continue;

        // ✅ برای ماموریت‌ها از متد shouldShowQuestOnDate استفاده کن
        if (habit.questId != null) {
          if (!habit.shouldShowQuestOnDate(widget.selectedDate)) {
            continue;
          }
        } else {
          // ✅ برای عادت‌های معمولی
          if (!habit.shouldDoOnDate(widget.selectedDate)) {
            continue;
          }
        }

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

      // ✅ پردازش تسک‌ها
      final List<Task> pendingTasks = [];
      final List<Task> completedTasks = [];
      final List<Task> failedTasks = [];

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

      // ✅ به‌روزرسانی UI
      if (mounted) {
        setState(() {
          _todayHabits = pendingHabits;
          _todayTasks = pendingTasks;
          _completedHabits = completedHabits;
          _completedTasks = completedTasks;
          _failedHabits = failedHabits;
          _failedTasks = failedTasks;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ==================== متدهای عمومی برای ریفرش ====================

  Future<void> _markHabitCompleted(Habit habit) async {
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);

    // ✅ 1. به‌روزرسانی فوری UI (همیشه اولین کار)
    setState(() {
      _habitCompletionStatus[habit.id] = true;
      _habitFailedStatus[habit.id] = false;
      _todayHabits.remove(habit);
      _failedHabits.remove(habit);
      if (!_completedHabits.contains(habit)) {
        _completedHabits.add(habit);
      }
      _initialTodayItemsCount = _todayHabits.length + _todayTasks.length;
    });

    // ✅ 2. اجرای عملیات‌های دیتابیس در پس‌زمینه با Future.microtask
    Future.microtask(() async {
      try {
        if (syncProvider.isOnline) {
          await Future.wait([
            _supabase.markHabitCompletedOnDate(
              habit.id,
              _currentUserId!,
              widget.selectedDate,
              true,
            ),
            _supabase.addXP(_currentUserId!, habit.xpReward),
            _supabase.recordDailyActivity(
              userId: _currentUserId!,
              date: widget.selectedDate,
              habitsCompleted: 1,
              xpEarned: habit.xpReward,
              isActive: true,
            ),
          ]);

          // ✅ فقط یکبار ریفرش
          _scheduleProfileRefresh();

          // ✅ بررسی ماموریت (با تاخیر)
          if (habit.questId != null) {
            unawaited(_handleQuestCompletion(habit));
          }
          if (habit.challengeId != null) {
            unawaited(_handleChallengeCompletion(habit));
          }

          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('+${habit.xpReward} XP دریافت کردید!'),
                backgroundColor: Colors.green,
                duration: const Duration(milliseconds: 600),
              ),
            );
          }
        } else {
          // ✅ آفلاین
          await syncProvider.addOfflineOperation(
            type: OperationType.completeHabit,
            data: {
              'habitId': habit.id,
              'date': widget.selectedDate.toIso8601String(),
              'xpReward': habit.xpReward,
            },
          );
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('✅ انجام شد (آفلاین)'),
                backgroundColor: Colors.orange,
                duration: const Duration(milliseconds: 600),
              ),
            );
          }
        }

        _checkAllCompletedAndShowCongratulation();
      } catch (e) {
        // ❌ برگرداندن وضعیت در صورت خطا
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
    });
  }

  Future<void> _handleQuestCompletion(Habit habit) async {
    try {
      print('🔍 Checking quest completion for habit: ${habit.id}');

      final completedQuest = await _supabase
          .updateQuestProgress(_currentUserId!, habit.id)
          .timeout(const Duration(seconds: 3));

      if (completedQuest != null && mounted) {
        print('✅ Quest completed: ${completedQuest.title}');

        // ✅ به‌روزرسانی UI
        await _loadData();

        // ✅ نمایش صفحه تبریک
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
          _loadData();
        }
      }
    } catch (e) {
      print('⚠️ Quest completion error: $e');
    }
  }

  // ✅ متد جداگانه برای چالش (با تایم‌اوت)
  Future<void> _handleChallengeCompletion(Habit habit) async {
    try {
      final completedChallenge = await _supabase
          .checkAndCompleteChallenge(_currentUserId!, habit.challengeId!)
          .timeout(const Duration(seconds: 5));

      if (completedChallenge != null && mounted) {
        final startDate = DateTime.parse(completedChallenge['start_date']);
        final endDate = DateTime.parse(completedChallenge['end_date']);
        final totalDays = endDate.difference(startDate).inDays + 1;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChallengeCompletionScreen(
              challenge: completedChallenge,
              completedDays: totalDays,
              totalDays: totalDays,
            ),
          ),
        );

        _hasShownCongratulationToday = false;
        _initialCountSet = false;
        await _loadData();
      }
    } catch (e) {
      // خطا را نادیده بگیر
    }
  }

  DateTime? _lastRefreshTime;
  static const _minRefreshInterval = Duration(milliseconds: 500);

  void _scheduleProfileRefresh() {
    final now = DateTime.now();
    if (_lastRefreshTime == null ||
        now.difference(_lastRefreshTime!) > _minRefreshInterval) {
      _lastRefreshTime = now;

      // ✅ ارسال سیگنال ریفرش با مقدار جدید
      if (widget.profileRefreshNotifier != null) {
        widget.profileRefreshNotifier!.value++;
        print(
          '🔄 Profile refresh triggered: ${widget.profileRefreshNotifier!.value}',
        );
      }
    }
  }

  Future<void> _markHabitFailed(Habit habit) async {
    setState(() {
      _habitFailedStatus[habit.id] = true;
      _habitCompletionStatus[habit.id] = false;
      _todayHabits.remove(habit);
      _completedHabits.remove(habit);
      if (!_failedHabits.contains(habit)) {
        _failedHabits.add(habit);
      }
      _initialTodayItemsCount = _todayHabits.length + _todayTasks.length;
    });

    await _supabase.markHabitCompletedOnDate(
      habit.id,
      _currentUserId!,
      widget.selectedDate,
      false,
    );
    _checkAllCompletedAndShowCongratulation();
  }

  // lib/features/arena/screens/today_tab.dart

  // ✅ اصلاح متد _unmarkHabit - با استفاده از Future.microtask
  Future<void> _unmarkHabit(Habit habit) async {
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);

    // ✅ 1. به‌روزرسانی فوری UI (همیشه اولین کار)
    setState(() {
      _habitCompletionStatus[habit.id] = false;
      _habitFailedStatus[habit.id] = false;
      _completedHabits.remove(habit);
      _failedHabits.remove(habit);
      if (habit.shouldDoOnDate(widget.selectedDate) &&
          !_todayHabits.contains(habit)) {
        _todayHabits.add(habit);
      }
      _initialTodayItemsCount = _todayHabits.length + _todayTasks.length;
    });

    // ✅ 2. اجرای عملیات‌های دیتابیس در پس‌زمینه
    Future.microtask(() async {
      try {
        if (syncProvider.isOnline) {
          await Future.wait([
            _supabase.markHabitCompletedOnDate(
              habit.id,
              _currentUserId!,
              widget.selectedDate,
              false,
            ),
            _supabase.removeXP(_currentUserId!, habit.xpReward),
          ]);
          _scheduleProfileRefresh();
        } else {
          await syncProvider.addOfflineOperation(
            type: OperationType.uncompleteHabit,
            data: {
              'habitId': habit.id,
              'date': widget.selectedDate.toIso8601String(),
              'xpReward': habit.xpReward,
            },
          );
        }

        if (habit.questId != null && syncProvider.isOnline) {
          unawaited(_recalculateQuestProgress(_currentUserId!, habit.questId!));
        }

        _hasShownCongratulationToday = false;
        _checkAllCompletedAndShowCongratulation();
      } catch (e) {
        // برگرداندن وضعیت در صورت خطا
        if (mounted) {
          setState(() {
            _habitCompletionStatus[habit.id] = true;
            _completedHabits.add(habit);
            _todayHabits.remove(habit);
          });
        }
      }
    });
  }

  /// محاسبه مجدد پیشرفت ماموریت از صفر
  Future<void> _recalculateQuestProgress(String userId, String questId) async {
    try {
      // 1. دریافت همه عادت‌های این ماموریت
      final habits = await _supabase.getHabits(userId);
      final questHabits = habits.where((h) => h.questId == questId).toList();

      // 2. شمارش روزهایی که انجام شدن
      int completedCount = 0;
      for (var habit in questHabits) {
        final isCompleted = await _supabase.isHabitCompletedOnDate(
          habit.id,
          userId,
          DateTime.now(),
        );
        if (isCompleted) completedCount++;
      }

      // 3. به‌روزرسانی progress در user_quests
      final userQuests = await _supabase.getUserQuests(userId);
      final userQuest = userQuests.firstWhere(
        (uq) => uq.questId == questId && uq.isActive,
      );

      await _supabase.client
          .from('user_quests')
          .update({'progress': completedCount})
          .eq('id', userQuest.id);
    } catch (e) {
      print('❌ Error recalculating quest progress: $e');
    }
  }

  Future<void> _markTaskCompleted(Task task) async {
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);

    setState(() {
      task.isCompleted = true;
      _taskCompletedStatus[task.id] = true;
      _taskFailedStatus[task.id] = false;
      _todayTasks.remove(task);
      _failedTasks.remove(task);
      if (!_completedTasks.contains(task)) {
        _completedTasks.add(task);
      }
      _initialTodayItemsCount = _todayHabits.length + _todayTasks.length;
    });

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
        print('📝 Task completion saved offline: ${task.title}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: syncProvider.isOnline
                ? Text('+${task.xpReward} XP دریافت کردید!')
                : Text('✅ انجام شد (آفلاین) - پس از اتصال همگام‌سازی می‌شود'),
            backgroundColor: syncProvider.isOnline
                ? Colors.green
                : Colors.orange,
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

  Future<void> _markTaskFailed(Task task) async {
    setState(() {
      task.isCompleted = false;
      _taskFailedStatus[task.id] = true;
      _taskCompletedStatus[task.id] = false;
      _todayTasks.remove(task);
      _completedTasks.remove(task);
      if (!_failedTasks.contains(task)) {
        _failedTasks.add(task);
      }
      _initialTodayItemsCount = _todayHabits.length + _todayTasks.length;
    });

    await _supabase.updateTask(task);
    _checkAllCompletedAndShowCongratulation();
  }

  Future<void> _unmarkTask(Task task) async {
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);

    setState(() {
      task.isCompleted = false;
      _taskCompletedStatus[task.id] = false;
      _taskFailedStatus[task.id] = false;
      _completedTasks.remove(task);
      _failedTasks.remove(task);
      if (task.isForDate(widget.selectedDate) && !_todayTasks.contains(task)) {
        _todayTasks.add(task);
      }
      _initialTodayItemsCount = _todayHabits.length + _todayTasks.length;
    });

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
        print('📝 Task uncompleted saved offline: ${task.title}');
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

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _menuAnimationController.forward();
      } else {
        _menuAnimationController.reverse();
      }
    });
  }

  void _openAddHabit() {
    _toggleMenu();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CategorySelectionScreen()),
    ).then((_) {
      _loadData();
    });
  }

  void _openAddTask() {
    _toggleMenu();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTaskScreen()),
    ).then((_) {
      _loadData();
    });
  }

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

  void _showHabitDetailsDialog(Habit habit) async {
    String startDateStr = '';
    if (habit.startDate != null) {
      startDateStr = await DateService.formatDate(habit.startDate!);
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
                      color: Color(habit.backgroundColor).withAlpha(255),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getIconData(habit.iconName),
                      color: Color(habit.iconColor),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        Text(
                          habit.description.isEmpty
                              ? 'بدون توضیحات'
                              : habit.description,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              _buildDetailRow(
                Icons.repeat,
                'زمانبندی',
                _getFrequencyText(habit),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                Icons.access_time,
                'زمان',
                _getTimeOfDayText(habit.timeOfDay),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.stars, 'امتیاز', '${habit.xpReward} XP'),
              if (habit.startDate != null) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.calendar_today,
                  'تاریخ شروع',
                  startDateStr,
                ),
              ],
              if (habit.reminders.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.alarm,
                  'یادآورها',
                  '${habit.reminders.length} یادآور',
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        );
      },
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
            color: const Color(0xFF4A90E2).withAlpha(20),
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
    );

    await _supabase.updateHabit(updatedHabit);

    setState(() {
      final index = _todayHabits.indexWhere((h) => h.id == habit.id);
      if (index != -1) {
        _todayHabits[index] = updatedHabit;
      }
      final completedIndex = _completedHabits.indexWhere(
        (h) => h.id == habit.id,
      );
      if (completedIndex != -1) {
        _completedHabits[completedIndex] = updatedHabit;
      }
      final failedIndex = _failedHabits.indexWhere((h) => h.id == habit.id);
      if (failedIndex != -1) {
        _failedHabits[failedIndex] = updatedHabit;
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

    await _supabase.updateTask(updatedTask);

    setState(() {
      final index = _todayTasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _todayTasks[index] = updatedTask;
      }
      final completedIndex = _completedTasks.indexWhere((t) => t.id == task.id);
      if (completedIndex != -1) {
        _completedTasks[completedIndex] = updatedTask;
      }
      final failedIndex = _failedTasks.indexWhere((t) => t.id == task.id);
      if (failedIndex != -1) {
        _failedTasks[failedIndex] = updatedTask;
      }
    });
  }

  void _editHabit(Habit habit) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditHabitScreen(habit: habit)),
    );
    if (result == true && mounted) {
      _loadData();
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
      _loadData();
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Consumer<SyncProvider>(
          builder: (context, syncProvider, child) {
            // ✅ اگر در حال بارگذاری است و داده‌ای وجود ندارد
            if (_isLoading && !syncProvider.hasLocalData) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF4A90E2)),
                    SizedBox(height: 16),
                    Text(
                      'در حال بارگذاری اطلاعات...',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              );
            }

            // ✅ اگر داده محلی وجود دارد، حتی در آفلاین نمایش بده
            if (syncProvider.hasLocalData) {
              // نمایش محتوا با داده‌های محلی
              return RefreshIndicator(
                onRefresh: _loadData,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4A90E2),
                        ),
                      )
                    : SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: _buildTodayContent(),
                      ),
              );
            }

            // ✅ فقط اگر داده محلی وجود ندارد و آفلاین هستیم
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
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            // ✅ نمایش محتوای اصلی (با داده‌های محلی یا آنلاین)
            return RefreshIndicator(
              onRefresh: _loadData,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF4A90E2),
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: _buildTodayContent(),
                    ),
            );
          },
        ),
        _buildFloatingMenuButton(),
      ],
    );
  }

  // ✅ متد جداگانه برای محتوای امروز
  Widget _buildTodayContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_todayHabits.isNotEmpty || _todayTasks.isNotEmpty) ...[
          const Text(
            'امروز',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 12),
          ..._todayHabits.map((habit) => _buildHabitItem(habit)),
          ..._todayTasks.map((task) => _buildTaskItem(task)),
          const SizedBox(height: 24),
        ],

        if (_completedHabits.isNotEmpty || _completedTasks.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              const Text(
                'انجام شده',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._completedHabits.map((habit) => _buildCompletedHabitItem(habit)),
          ..._completedTasks.map((task) => _buildCompletedTaskItem(task)),
          const SizedBox(height: 24),
        ],

        if (_failedHabits.isNotEmpty || _failedTasks.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.close, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              const Text(
                'شکست خورده',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._failedHabits.map((habit) => _buildFailedHabitItem(habit)),
          ..._failedTasks.map((task) => _buildFailedTaskItem(task)),
          const SizedBox(height: 24),
        ],

        if (_todayHabits.isEmpty &&
            _todayTasks.isEmpty &&
            _completedHabits.isEmpty &&
            _completedTasks.isEmpty &&
            _failedHabits.isEmpty &&
            _failedTasks.isEmpty)
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

  Widget _buildFloatingMenuButton() {
    return Positioned(
      bottom: 20,
      right: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isMenuOpen ? 1.0 : 0.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: _isMenuOpen ? 120 : 0,
              curve: Curves.easeOutCubic,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isMenuOpen) ...[
                      ScaleTransition(
                        scale: CurvedAnimation(
                          parent: _menuAnimationController,
                          curve: Curves.easeOutCubic,
                        ),
                        child: _buildMenuItem(
                          icon: Icons.fitness_center,
                          label: 'عادت جدید',
                          color: const Color(0xFF4A90E2),
                          onTap: _openAddHabit,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ScaleTransition(
                        scale: CurvedAnimation(
                          parent: _menuAnimationController,
                          curve: Curves.easeOutCubic,
                        ),
                        child: _buildMenuItem(
                          icon: Icons.assignment,
                          label: 'وظیفه جدید',
                          color: const Color(0xFFFFA500),
                          onTap: _openAddTask,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isMenuOpen
                  ? const Color(0xFFE74C3C)
                  : const Color(0xFF4A90E2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: GestureDetector(
              onTap: _toggleMenu,
              child: AnimatedRotation(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                turns: _isMenuOpen ? 0.125 : 0.0,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: Icon(
                    _isMenuOpen ? Icons.close : Icons.add,
                    key: ValueKey(_isMenuOpen),
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitItem(Habit habit) {
    // ✅ تشخیص عادت چالش (با 🏆 شروع میشه)
    final isChallengeHabit = habit.title.startsWith('🏆');

    // ✅ تشخیص عادت ماموریت (questId دارد)
    final isQuestHabit = habit.questId != null;

    final hasSubHabits = habit.subHabits.isNotEmpty;
    final isExpanded = _expandedItemId == habit.id && _expandedType == 'habit';
    final isSubExpanded = _expandedSubItemId == habit.id;

    _initAnimation(habit.id);

    return Dismissible(
      key: Key(habit.id),
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
          await _markHabitCompleted(habit);
        } else if (direction == DismissDirection.endToStart) {
          await _markHabitFailed(habit);
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
              onTap: () => _toggleExpanded(habit.id, 'habit'),
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
                        color: Color(habit.backgroundColor).withAlpha(255),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getIconData(habit.iconName),
                        color: Color(habit.iconColor),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            habit.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          Text(
                            '${_getFrequencyText(habit)} • ${_getTimeOfDayText(habit.timeOfDay)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (hasSubHabits && habit.completedSubHabits.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A90E2).withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${habit.completedSubHabits.length}/${habit.subHabits.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A90E2),
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFA500).withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '+${habit.xpReward} XP',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFA500),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (isExpanded)
              SizeTransition(
                sizeFactor: _animations[habit.id]!,
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
                            onTap: () => _markHabitCompleted(habit),
                          ),
                          if (hasSubHabits)
                            _buildActionButton(
                              icon: isSubExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.list_alt,
                              onTap: () {
                                setState(() {
                                  if (_expandedSubItemId == habit.id) {
                                    _expandedSubItemId = null;
                                  } else {
                                    _expandedSubItemId = habit.id;
                                  }
                                });
                              },
                            ),
                          _buildActionButton(
                            icon: Icons.info_outline,
                            onTap: () => _showHabitDetailsDialog(habit),
                          ),
                          // ✅ دکمه ویرایش - برای چالش‌ها و ماموریت‌ها غیرفعال
                          _buildActionButton(
                            icon: Icons.edit,
                            onTap: (isChallengeHabit || isQuestHabit)
                                ? null
                                : () => _editHabit(habit),
                          ),
                          // ✅ دکمه حذف - برای چالش‌ها و ماموریت‌ها غیرفعال
                          _buildActionButton(
                            icon: Icons.delete,
                            onTap: (isChallengeHabit || isQuestHabit)
                                ? null
                                : () => _deleteHabit(habit),
                          ),
                        ],
                      ),
                    ),

                    if (isSubExpanded && hasSubHabits)
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
                              'زیرعادت‌ها',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...habit.subHabits.map(
                              (subHabit) => CheckboxListTile(
                                value: habit.completedSubHabits.contains(
                                  subHabit,
                                ),
                                onChanged: (value) async {
                                  await _toggleSubHabit(habit, subHabit);
                                  setState(() {});
                                },
                                title: Text(subHabit),
                                activeColor: const Color(0xFF4A90E2),
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            ),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: habit.subHabits.isEmpty
                                  ? 0
                                  : habit.completedSubHabits.length /
                                        habit.subHabits.length,
                              backgroundColor: Colors.grey.shade200,
                              color: const Color(0xFF4A90E2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'پیشرفت: ${habit.subHabits.isEmpty ? 0 : ((habit.completedSubHabits.length / habit.subHabits.length) * 100).toInt()}%',
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

  Widget _buildCompletedHabitItem(Habit habit) {
    return Dismissible(
      key: Key(habit.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.refresh, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        await _unmarkHabit(habit);
        return false;
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        color: Colors.green.shade50,
        child: ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(50),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 24,
            ),
          ),
          title: Text(
            habit.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.lineThrough,
              color: Colors.grey,
            ),
          ),
          subtitle: Text(
            '${_getFrequencyText(habit)} • ${_getTimeOfDayText(habit.timeOfDay)}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '+${habit.xpReward} XP',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFailedHabitItem(Habit habit) {
    return Dismissible(
      key: Key(habit.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.refresh, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        await _unmarkHabit(habit);
        return false;
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        color: Colors.red.shade50,
        child: ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(50),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.close, color: Colors.red, size: 24),
          ),
          title: Text(
            habit.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          subtitle: Text(
            '${_getFrequencyText(habit)} • ${_getTimeOfDayText(habit.timeOfDay)}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '+${habit.xpReward} XP',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskItem(Task task) {
    final isChallengeTask = task.title.startsWith('🎯');
    final hasSubTasks = task.subTasks.isNotEmpty;
    final isExpanded = _expandedItemId == task.id && _expandedType == 'task';
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
              onTap: () => _toggleExpanded(task.id, 'task'),
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
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.assignment,
                        color: Colors.grey.shade500,
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A2E),
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
                        color: const Color(0xFFFFA500).withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '+${task.xpReward} XP',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFA500),
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

  Widget _buildCompletedTaskItem(Task task) {
    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.refresh, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        await _unmarkTask(task);
        return false;
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        color: Colors.green.shade50,
        child: ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(50),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 24,
            ),
          ),
          title: Text(
            task.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.lineThrough,
              color: Colors.grey,
            ),
          ),
          subtitle: task.dueDate != null
              ? FutureBuilder(
                  future: DateService.formatDate(task.dueDate!),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Text(
                        'زمان: ${snapshot.data}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                )
              : null,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '+${task.xpReward} XP',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFailedTaskItem(Task task) {
    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.refresh, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        await _unmarkTask(task);
        return false;
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        color: Colors.red.shade50,
        child: ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(50),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.close, color: Colors.red, size: 24),
          ),
          title: Text(
            task.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          subtitle: task.dueDate != null
              ? FutureBuilder(
                  future: DateService.formatDate(task.dueDate!),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Text(
                        'زمان: ${snapshot.data}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                )
              : null,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '+${task.xpReward} XP',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
