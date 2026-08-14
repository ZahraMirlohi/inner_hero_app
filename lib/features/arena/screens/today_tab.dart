// lib/features/arena/screens/today_tab.dart

// ✅ حذف importهای تکراری - فقط اینها را نگه دارید
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
import '/providers/sync_provider.dart';
import 'dart:async';
import '/models/offline_operation.dart';
import '../models/habit_time_tracking.dart'; // ✅ اضافه کنید
import '../widgets/habit_timer_widget.dart'; // ✅ اضافه کنید
import '../models/timer_setting.dart'; // اگر نیاز دارید
import '../widgets/timer_picker_widget.dart';
import '../widgets/completion_level_picker.dart';
import '../models/habit_completion.dart';
import '/features/arena/screens/habit_detail_screen.dart';

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

    // ✅ بارگذاری با کمی تأخیر برای اطمینان از آماده بودن SyncProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  // ✅ متد ریفرش عمومی
  void refreshData() {
    if (!_isLoading) {
      // ✅ ریفرش کامل با پاک کردن کش
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

    // ✅ فقط عادت‌ها و تسک‌ها رو بررسی کن (چالش‌ها عادت دارن)
    final hadAnyTaskForToday = _initialTodayItemsCount > 0;
    final allPendingEmpty = _todayHabits.isEmpty && _todayTasks.isEmpty;

    final hasFailedItems = false;

    if (hadAnyTaskForToday && allPendingEmpty && !hasFailedItems) {
      final hasAnyCompleted =
          _completedHabits.isNotEmpty || _completedTasks.isNotEmpty;
      if (!hasAnyCompleted) {
        print('📊 No completed activities - skipping congratulation');
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

    // ✅ فقط اگر قبلاً بارگذاری نشده یا نیاز به ریفرش دارد
    setState(() => _isLoading = true);

    try {
      final user = await _supabase.getCurrentUser();
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      _currentUserId = user.id;

      final syncProvider = Provider.of<SyncProvider>(context, listen: false);

      // ✅ دریافت داده‌ها
      List<Habit> allHabits = [];
      List<Task> allTasks = [];

      if (syncProvider.habits.isNotEmpty) {
        allHabits = syncProvider.habits;
      } else if (syncProvider.isOnline) {
        allHabits = await _supabase.getHabits(_currentUserId!);
      }

      if (syncProvider.tasks.isNotEmpty) {
        allTasks = syncProvider.tasks;
      } else if (syncProvider.isOnline) {
        allTasks = await _supabase.getTasks(_currentUserId!);
      }

      // ✅ پردازش عادت‌ها
      final List<Habit> pendingHabits = [];
      final List<Habit> completedHabits = [];
      // ❌ حذف failedHabits

      for (var habit in allHabits) {
        if (!habit.isActive) continue;

        if (habit.questId != null) {
          if (!habit.shouldShowQuestOnDate(widget.selectedDate)) {
            continue;
          }
        } else {
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
      // ❌ حذف failedTasks

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

  // lib/features/arena/screens/today_tab.dart

  Future<void> _markHabitCompleted(Habit habit) async {
    if (!mounted) return;

    // ✅ نمایش دیالوگ انتخاب سطح
    final level = await showDialog<CompletionLevel>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CompletionLevelPicker(
        habitTitle: habit.title,
        habitXpReward: habit.xpReward,
        onSelected: (selectedLevel) {
          Navigator.pop(context, selectedLevel);
        },
      ),
    );

    if (level == null || !mounted) return;

    final syncProvider = Provider.of<SyncProvider>(context, listen: false);

    // ✅ **STEP 1: به‌روزرسانی فوری UI (قبل از هر عملیات دیتابیس)**
    setState(() {
      _habitCompletionStatus[habit.id] = true;
      _todayHabits.remove(habit);
      if (!_completedHabits.contains(habit)) {
        _completedHabits.add(habit);
      }
      _initialTodayItemsCount = _todayHabits.length + _todayTasks.length;
    });

    // ✅ **STEP 2: محاسبه XP و نمایش پیام فوری**
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

    // ✅ **STEP 3: انجام عملیات دیتابیس در پس‌زمینه (بدون منتظر ماندن)**
    try {
      if (syncProvider.isOnline) {
        // ✅ اجرای بدون await برای عدم تاخیر
        _supabase
            .markHabitCompletedWithLevel(
          habitId: habit.id,
          userId: _currentUserId!,
          date: widget.selectedDate,
          level: level,
        )
            .then((_) async {
          // ✅ بعد از ثبت، استریک و پروفایل را به‌روزرسانی کن
          await _supabase.recordDailyActivity(
            userId: _currentUserId!,
            date: widget.selectedDate,
            habitsCompleted: _completedHabits.length,
            tasksCompleted: _completedTasks.length,
            xpEarned: _calculateTodayXP(),
            isActive: true,
          );
          _scheduleProfileRefresh();
        }).catchError((e) {
          print('❌ Error completing habit in background: $e');
        });
      } else {
        // ✅ حالت آفلاین
        syncProvider.addOfflineOperation(
          type: OperationType.completeHabitWithLevel,
          data: {
            'habitId': habit.id,
            'date': widget.selectedDate.toIso8601String(),
            'xpReward': habit.xpReward,
            'level': level.toString().split('.').last,
          },
        );
      }
    } catch (e) {
      // ✅ در صورت خطا، وضعیت را برگردان
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

    // ✅ **STEP 4: بررسی تکمیل همه و نمایش تبریک (بدون await)**
    _checkAllCompletedAndShowCongratulation();
  }

  Future<void> _markHabitCompletedWithLevel(
      Habit habit, CompletionLevel level) async {
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);

    // ✅ بررسی mounted قبل از setState
    if (mounted) {
      setState(() {
        _habitCompletionStatus[habit.id] = true;
        _todayHabits.remove(habit);
        if (!_completedHabits.contains(habit)) {
          _completedHabits.add(habit);
        }
        _initialTodayItemsCount = _todayHabits.length + _todayTasks.length;
      });
    }

    try {
      if (syncProvider.isOnline) {
        await _supabase.markHabitCompletedWithLevel(
          habitId: habit.id,
          userId: _currentUserId!,
          date: widget.selectedDate,
          level: level,
        );

        final xpEarned = (habit.xpReward * level.xpMultiplier / 100).round();
        await _supabase.recordDailyActivity(
          userId: _currentUserId!,
          date: widget.selectedDate,
          habitsCompleted: 1,
          xpEarned: xpEarned,
          isActive: true,
        );

        _scheduleProfileRefresh();

        // ✅ بررسی mounted قبل از نمایش SnackBar
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${level.emoji} +$xpEarned XP دریافت کردید!'),
              backgroundColor: level.color,
              duration: const Duration(milliseconds: 800),
            ),
          );
        }
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

        // ✅ بررسی mounted قبل از نمایش SnackBar
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ انجام شد (آفلاین)'),
              backgroundColor: Colors.orange,
              duration: Duration(milliseconds: 600),
            ),
          );
        }
      }

      _checkAllCompletedAndShowCongratulation();
    } catch (e) {
      // ✅ بررسی mounted قبل از setState
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

  // lib/features/arena/screens/today_tab.dart

  Future<void> _handleChallengeCompletion(Habit habit) async {
    try {
      print('🔍 Checking challenge completion for habit: ${habit.id}');
      print('📝 Challenge ID: ${habit.challengeId}');

      if (habit.challengeId == null) return;

      // ✅ اول روز چالش رو ثبت کن
      await _supabase.completeChallengeDay(
        userId: _currentUserId!,
        challengeId: habit.challengeId!,
        date: widget.selectedDate,
      );

      // ✅ بعد چک کن که چالش کامل شده یا نه
      final completedChallenge = await _supabase
          .checkAndCompleteChallenge(_currentUserId!, habit.challengeId!)
          .timeout(const Duration(seconds: 5));

      if (completedChallenge != null && mounted) {
        print('✅ Challenge completed: ${completedChallenge['title']}');

        // دریافت تعداد روزهای تکمیل شده
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
        await _loadData();
      } else {
        // ✅ حتی اگر چالش کامل نشده، پیشرفت رو به‌روزرسانی کن
        print('📊 Challenge progress updated but not completed yet');
        await _loadData();
      }
    } catch (e) {
      print('⚠️ Challenge completion error: $e');
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
          // ✅ افزایش مقدار notifier برای ریفرش پروفایل
          widget.profileRefreshNotifier!.value++;
          print(
              '🔄 Profile refresh triggered with value: ${widget.profileRefreshNotifier!.value}');
        }
      } catch (e) {
        print('⚠️ Profile refresh error: $e');
      }
    }
  }

  Future<void> _unmarkHabit(Habit habit) async {
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);

    setState(() {
      _habitCompletionStatus[habit.id] = false;
      _completedHabits.remove(habit);
      if (habit.shouldDoOnDate(widget.selectedDate) &&
          !_todayHabits.contains(habit)) {
        _todayHabits.add(habit);
      }
      _initialTodayItemsCount = _todayHabits.length + _todayTasks.length;
    });

    Future.microtask(() async {
      try {
        if (syncProvider.isOnline) {
          print('🗑️ Unmarking habit: ${habit.title}');

          // ✅ 1. لغو تکمیل عادت
          await _supabase.markHabitCompletedOnDate(
            habit.id,
            _currentUserId!,
            widget.selectedDate,
            false,
          );

          // ✅ 2. کم کردن XP
          await _supabase.removeXP(_currentUserId!, habit.xpReward);
          print('🗑️ XP removed: ${habit.xpReward} from habit: ${habit.title}');

          // ✅ 3. اگر عادت مربوط به چالش است، روز چالش رو لغو کن
          if (habit.challengeId != null) {
            print('📝 Removing challenge day for: ${habit.challengeId}');
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

          // ✅ 4. بررسی کن که آیا امروز هیچ فعالیت دیگه‌ای باقی مونده یا نه
          final hasOtherActivities = await _checkIfTodayHasOtherActivities();
          print('📊 Has other activities: $hasOtherActivities');
          print('📊 Completed habits: ${_completedHabits.length}');
          print('📊 Completed tasks: ${_completedTasks.length}');

          if (!hasOtherActivities) {
            print('📊 No activities left - setting isActive = false');
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
            print('📊 Other activities exist - keeping isActive = true');
            await _supabase.recordDailyActivity(
              userId: _currentUserId!,
              date: widget.selectedDate,
              habitsCompleted: _completedHabits.length,
              tasksCompleted: _completedTasks.length,
              xpEarned: _calculateTodayXP(),
              isActive: true,
            );
          }

          // ✅ 5. ریفرش پروفایل (با تاخیر برای اطمینان از ذخیره شدن)
          _scheduleProfileRefresh();

          // ✅ 6. یک بار دیگر ریفرش با تاخیر بیشتر
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _scheduleProfileRefresh();
            }
          });

          _hasShownCongratulationToday = false;
          _checkAllCompletedAndShowCongratulation();

          // ✅ 7. بارگذاری مجدد داده‌ها برای به‌روزرسانی UI
          await _loadData();
        } else {
          // ✅ حالت آفلاین
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

    // ✅ اگر در حافظه چیزی هست، true برگردان
    if (hasCompletedHabits || hasCompletedTasks) {
      print('📊 Has completed habits or tasks in memory');
      return true;
    }

    // ✅ اگر در حافظه چیزی نیست، از دیتابیس چک کن
    try {
      final todayStr = widget.selectedDate.toIso8601String().split('T').first;

      // 1. چک کردن habit_completions (فقط عادت‌های معمولی، نه چالش‌ها)
      final habitCompletions = await _supabase.client
          .from('habit_completions')
          .select('id, habit_id')
          .eq('user_id', _currentUserId!)
          .eq('date', todayStr);

      if (habitCompletions.isNotEmpty) {
        // ✅ بررسی کن که آیا این عادت‌ها مربوط به چالش هستند یا نه
        for (var completion in habitCompletions) {
          final habitId = completion['habit_id'];
          // دریافت عادت از دیتابیس
          final habit = await _supabase.client
              .from('habits')
              .select('challenge_id, quest_id')
              .eq('id', habitId)
              .maybeSingle();

          // ✅ اگر عادت مربوط به چالش یا ماموریت نبود، true برگردان
          if (habit != null &&
              habit['challenge_id'] == null &&
              habit['quest_id'] == null) {
            print('📊 Found regular habit completion in database');
            return true;
          }
        }
      }

      // 2. چک کردن tasks (تسک‌های کامل شده)
      final tasks = await _supabase.client
          .from('tasks')
          .select('id')
          .eq('user_id', _currentUserId!)
          .eq('is_completed', true)
          .eq('due_date', todayStr)
          .limit(1);

      if (tasks.isNotEmpty) {
        print('📊 Found completed tasks in database');
        return true;
      }

      // 3. ✅ چک کردن challenge_completions
      final challengeCompletions = await _supabase.client
          .from('challenge_completions')
          .select('id')
          .eq('user_id', _currentUserId!)
          .eq('date', todayStr)
          .limit(1);

      if (challengeCompletions.isNotEmpty) {
        print('📊 Found challenge completions in database');
        return true;
      }

      print('📊 No regular activities found in database');
      return false;
    } catch (e) {
      print('⚠️ Error checking activities: $e');
      return false;
    }
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

        // ✅ بررسی کن که آیا امروز هیچ فعالیت دیگه‌ای باقی مونده یا نه
        final hasOtherActivities = await _checkIfTodayHasOtherActivities();

        print('📊 Has other activities: $hasOtherActivities');
        print('📊 Completed habits: ${_completedHabits.length}');
        print('📊 Completed tasks: ${_completedTasks.length}');

        if (!hasOtherActivities) {
          print('📊 No activities left - setting isActive = false');
          await _supabase.recordDailyActivity(
            userId: _currentUserId!,
            date: widget.selectedDate,
            habitsCompleted: 0,
            tasksCompleted: 0,
            xpEarned: 0,
            isActive: false,
          );

          // ✅ استریک رو مجبور به بازمحاسبه کن
          await _supabase.updateUserStreak(_currentUserId!);

          _scheduleProfileRefresh();
        } else {
          print('📊 Other activities exist - keeping isActive = true');
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

// ✅ اصلاح متد _showHabitDetailsDialog
  void _showHabitDetailsDialog(Habit habit) {
    // ✅ باز کردن صفحه کامل HabitDetailScreen
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

// lib/features/arena/screens/today_tab.dart

  Future<void> _toggleSubHabit(Habit habit, String subHabit) async {
    // 1. ایجاد لیست جدید از زیرعادت‌های انجام شده
    List<String> newCompletedSubHabits = List.from(habit.completedSubHabits);

    // 2. اگر زیرعادت قبلاً انجام شده، حذف کن، در غیر این صورت اضافه کن
    if (newCompletedSubHabits.contains(subHabit)) {
      newCompletedSubHabits.remove(subHabit);
    } else {
      newCompletedSubHabits.add(subHabit);
    }

    // 3. ایجاد عادت به‌روزرسانی شده
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

    // 4. ذخیره در دیتابیس (با مدیریت آفلاین)
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);

    // به‌روزرسانی UI (تمام لیست‌ها)
    setState(() {
      // به‌روزرسانی در لیست امروز
      final todayIndex = _todayHabits.indexWhere((h) => h.id == habit.id);
      if (todayIndex != -1) {
        _todayHabits[todayIndex] = updatedHabit;
      }

      // به‌روزرسانی در لیست انجام شده
      final completedIndex =
          _completedHabits.indexWhere((h) => h.id == habit.id);
      if (completedIndex != -1) {
        _completedHabits[completedIndex] = updatedHabit;
      }
    });

    // 5. ذخیره در LocalStorage
    await syncProvider.saveHabitToLocal(updatedHabit);

    // 6. اگر آنلاین هستیم، به دیتابیس هم بفرست
    if (syncProvider.isOnline) {
      await _supabase.updateHabit(updatedHabit);
    } else {
      // آفلاین: ذخیره در صف
      await syncProvider.addOfflineOperation(
        type: OperationType.updateHabit,
        data: updatedHabit.toMap(),
      );
      print('📝 Habit update saved offline: ${updatedHabit.title}');
    }
  }

// lib/features/arena/screens/today_tab.dart

  Future<void> _toggleSubTask(Task task, String subTask) async {
    // 1. ایجاد لیست جدید از زیرتسک‌های انجام شده
    List<String> newCompletedSubTasks = List.from(task.completedSubTasks);

    // 2. اگر زیرتسک قبلاً انجام شده، حذف کن، در غیر این صورت اضافه کن
    if (newCompletedSubTasks.contains(subTask)) {
      newCompletedSubTasks.remove(subTask);
    } else {
      newCompletedSubTasks.add(subTask);
    }

    // 3. ایجاد تسک به‌روزرسانی شده
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

    // 4. ذخیره در دیتابیس (با مدیریت آفلاین)
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);

    // به‌روزرسانی UI (تمام لیست‌ها)
    setState(() {
      // به‌روزرسانی در لیست امروز
      final todayIndex = _todayTasks.indexWhere((t) => t.id == task.id);
      if (todayIndex != -1) {
        _todayTasks[todayIndex] = updatedTask;
      }

      // به‌روزرسانی در لیست انجام شده
      final completedIndex = _completedTasks.indexWhere((t) => t.id == task.id);
      if (completedIndex != -1) {
        _completedTasks[completedIndex] = updatedTask;
      }
    });

    // 5. ذخیره در LocalStorage
    await syncProvider.saveTaskToLocal(updatedTask);

    // 6. اگر آنلاین هستیم، به دیتابیس هم بفرست
    if (syncProvider.isOnline) {
      await _supabase.updateTask(updatedTask);
    } else {
      // آفلاین: ذخیره در صف
      await syncProvider.addOfflineOperation(
        type: OperationType.updateTask,
        data: updatedTask.toMap(),
      );
      print('📝 Task update saved offline: ${updatedTask.title}');
    }
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

// lib/features/arena/screens/today_tab.dart

  Widget _buildTodayContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ============================================================
        // بخش عادت‌ها و تسک‌های امروز (انجام نشده)
        // ============================================================
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

        // ============================================================
        // بخش عادت‌ها و تسک‌های انجام شده
        // ============================================================
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

        // ============================================================
        // ❌ بخش شکست خورده - کاملاً حذف شده
        // ============================================================

        // ============================================================
        // حالت خالی (هیچ کاری برای امروز)
        // ============================================================
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

  Widget _buildFloatingMenuButton() {
    return Positioned(
      bottom: 20,
      right: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ============================================================
          // آیتم‌های منو (عادت جدید و وظیفه جدید)
          // ============================================================
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
                      // ✅ دکمه افزودن عادت
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

                      // ✅ دکمه افزودن تسک
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

          // ============================================================
          // دکمه اصلی (FloatingActionButton)
          // ============================================================
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isMenuOpen
                  ? const Color(0xFFE74C3C) // رنگ قرمز برای بستن
                  : const Color(0xFF4A90E2), // رنگ آبی برای باز کردن
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
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
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

  // lib/features/arena/screens/today_tab.dart

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
          color: Colors.green,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.check, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        await _markHabitCompleted(habit);
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // ==================== آیکون عادت ====================
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

                    // ==================== عنوان و توضیحات ====================
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

                    // ==================== نمایش زیرعادت‌ها ====================
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

                    // lib/features/arena/screens/today_tab.dart

// ✅ نمایش زمان ثبت شده امروز
                    FutureBuilder<HabitTimeTracking?>(
                      future: _getHabitTimeToday(habit.id),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A90E2).withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.timer,
                                    size: 12, color: Color(0xFF4A90E2)),
                                const SizedBox(width: 4),
                                Text(
                                  snapshot.data!.formattedTime,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF4A90E2),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),

                    // ==================== برچسب چالش/ماموریت ====================
                    if (isChallengeHabit || isQuestHabit)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isChallengeHabit
                              ? Colors.orange.withAlpha(25)
                              : Colors.purple.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isChallengeHabit ? '🏆 چالش' : '🎯 ماموریت',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isChallengeHabit
                                ? Colors.orange.shade700
                                : Colors.purple.shade700,
                          ),
                        ),
                      ),

                    // ==================== XP ====================
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

            // ==================== بخش Expanded (باز شده) ====================
            if (isExpanded)
              SizeTransition(
                sizeFactor: _animations[habit.id]!,
                child: Column(
                  children: [
                    // ... دکمه‌های اکشن (بدون تغییر)
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
                          if (!isChallengeHabit && !isQuestHabit)
                            _buildActionButton(
                              icon: Icons.timer,
                              onTap: () => _showTimerDialog(habit),
                            ),
                          _buildActionButton(
                            icon: Icons.edit,
                            onTap: (isChallengeHabit || isQuestHabit)
                                ? null
                                : () => _editHabit(habit),
                          ),
                          _buildActionButton(
                            icon: Icons.delete,
                            onTap: (isChallengeHabit || isQuestHabit)
                                ? null
                                : () => _deleteHabit(habit),
                          ),
                        ],
                      ),
                    ),

                    // ==================== زیرعادت‌ها ====================
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

// lib/features/arena/screens/today_tab.dart

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
      print('❌ Error getting habit time: $e');
      return null;
    }
  }

  // lib/features/arena/screens/today_tab.dart

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
                  const Text(
                    '⏱️ تایمر عادت',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    habit.title,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  HabitTimerWidget(
                    habitId: habit.id,
                    habitTitle: habit.title,
                    onTimeSaved: () {
                      Navigator.pop(context);
                      // ✅ ریفرش صفحه برای نمایش تایمر
                      if (mounted) {
                        setState(() {});
                        // ✅ ریفرش داده‌ها
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
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('بستن'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ✅ متد ذخیره تنظیمات تایمر با دقیقه و ثانیه
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

      // ✅ ایجاد TimerSetting جدید با دقیقه و ثانیه
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
      print('❌ Error saving timer setting: $e');
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
            child: const Text('بله، انجام شد ✅'),
          ),
        ],
      ),
    );
  }

// lib/features/arena/screens/today_tab.dart

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
          subtitle: Row(
            children: [
              Expanded(
                child: Text(
                  '${_getFrequencyText(habit)} • ${_getTimeOfDayText(habit.timeOfDay)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              // ✅ **نمایش تگ سطح فقط در بخش "انجام شده"**
              FutureBuilder<CompletionLevel>(
                future: _getHabitCompletionLevel(habit.id),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final level = snapshot.data!;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: level.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: level.color.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            level.emoji,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            level.displayName,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: level.color,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  // ✅ اگر در حال بارگذاری است، یک placeholder کوچک نشان بده
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.grey,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
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

  /// ✅ دریافت سطح انجام عادت برای تاریخ انتخاب شده
  Future<CompletionLevel> _getHabitCompletionLevel(String habitId) async {
    try {
      // تاریخ انتخاب شده در تقویم
      final date = widget.selectedDate;
      final dateStr = date.toIso8601String().split('T').first;

      // دریافت سطح از دیتابیس
      final response = await _supabase.client
          .from('habit_completions')
          .select('completion_level')
          .eq('habit_id', habitId)
          .eq('user_id', _currentUserId!)
          .eq('date', dateStr)
          .maybeSingle();

      // اگر سطح وجود داشت، آن را برگردان
      if (response != null && response['completion_level'] != null) {
        final levelStr = response['completion_level'] as String;
        return CompletionLevelExtension.fromString(levelStr);
      }

      // اگر سطحی وجود نداشت، مقدار پیش‌فرض "کامل" را برگردان
      return CompletionLevel.full;
    } catch (e) {
      print('❌ Error getting completion level: $e');
      // در صورت خطا، مقدار پیش‌فرض را برگردان
      return CompletionLevel.full;
    }
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
          color: Colors.green, // ✅ تغییر از قرمز به سبز
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.check,
            color: Colors.white, size: 28), // ✅ تغییر آیکون
      ),
      confirmDismiss: (direction) async {
        // ✅ هر دو جهت = انجام شده
        await _markTaskCompleted(task);
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
                            onTap:
                                isChallengeTask ? null : () => _editTask(task),
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
}

// lib/features/arena/screens/today_tab.dart

// ✅ اصلاح کامل بخش _TimerDialogContent
class _TimerDialogContent extends StatefulWidget {
  final Habit habit;
  final int initialMinutes;
  final int initialSeconds;
  final Function(int, int, bool) onSave;
  final VoidCallback onComplete;

  const _TimerDialogContent({
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
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '⏱️ تایمر عادت',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.habit.title,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // ✅ انتخاب دقیقه و ثانیه
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

          // ✅ نمایش زمان کل
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_minutes.toString().padLeft(2, '0')}:${_seconds.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A90E2),
                fontFamily: 'monospace',
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ✅ ویجت تایمر با پارامترهای جدید
          HabitTimerWidget(
            habitId: widget.habit.id,
            habitTitle: widget.habit.title,
            onTimeSaved: () {
              Navigator.pop(context);
              widget.onComplete();
            },
          ),

          const SizedBox(height: 8),

          // ✅ دکمه ذخیره تنظیمات تایمر (اختیاری)
          ElevatedButton.icon(
            onPressed: () {
              widget.onSave(_minutes, _seconds, _isCountdown);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.save, size: 18),
            label: const Text('ذخیره تنظیمات تایمر'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
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
