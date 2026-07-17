// lib/providers/sync_provider.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';
import '../services/local_storage_service.dart';
import '../features/arena/models/habit_model.dart';
import '../features/arena/models/task_model.dart';
import '../features/explore/models/quest_model.dart';
import '../features/explore/models/package_model.dart';
import '../models/offline_operation.dart';

class SyncProvider extends ChangeNotifier {
  final SupabaseService _supabase = SupabaseService();
  final LocalStorageService _localStorage = LocalStorageService();

  bool _isOnline = true;
  bool _isSyncing = false;
  bool _isInitialized = false;
  String? _currentUserId;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  bool get isInitialized => _isInitialized;

  SyncProvider() {
    print('🟣 [SyncProvider] Constructor called');
    _init();
  }

  Future<void> _init() async {
    print('🟣 [SyncProvider] _init started');

    try {
      // ✅ مرحله 1: مقداردهی LocalStorage
      print('🟣 [SyncProvider] Initializing LocalStorage...');
      await _localStorage.init();
      print('✅ [SyncProvider] LocalStorage initialized');

      // ✅ مرحله 2: دریافت userId از SharedPreferences
      print('🟣 [SyncProvider] Getting userId from SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getString('user_id');
      print('👤 [SyncProvider] Current user: $_currentUserId');

      // ✅ مرحله 3: بررسی داده‌های محلی
      final hasLocalData =
          _localStorage.getHabits().isNotEmpty ||
          _localStorage.getTasks().isNotEmpty ||
          _localStorage.getUserProfile() != null;

      print('🟣 [SyncProvider] Has local data: $hasLocalData');

      // ✅ مرحله 4: مقداردهی کامل - مهم: همیشه true کن
      _isInitialized = true;
      notifyListeners();
      print('✅ [SyncProvider] Initialized successfully (isInitialized = true)');

      // ✅ مرحله 5: بررسی اتصال اینترنت
      await _checkConnectivity();

      // ✅ مرحله 6: اگر آنلاین هستیم و کاربر داریم، داده‌ها رو همگام‌سازی کن
      if (_isOnline && _currentUserId != null) {
        print('🟣 [SyncProvider] Starting data sync...');
        _syncAllData();
      } else if (_currentUserId != null && hasLocalData) {
        print('🟢 [SyncProvider] Offline mode - using local data');
        // حتی اگر آفلاین باشیم، داده‌های محلی رو داریم
      } else {
        print('🟡 [SyncProvider] No user or no local data');
      }
    } catch (e, stackTrace) {
      print('🔴 [SyncProvider] Init error: $e');
      print('🔴 [SyncProvider] StackTrace: $stackTrace');
      // ✅ حتی در صورت خطا، مقداردهی رو کامل کن
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _checkConnectivity() async {
    print('🟣 [SyncProvider] _checkConnectivity called');

    if (kIsWeb) {
      print('🟣 [SyncProvider] Running on Web - setting isOnline = true');
      _isOnline = true;
      notifyListeners();
      return;
    }

    try {
      final isOnline = await InternetConnectionChecker().hasConnection;
      print('🟣 [SyncProvider] InternetConnectionChecker result: $isOnline');
      _isOnline = isOnline;
      notifyListeners();
    } catch (e) {
      print('🟡 [SyncProvider] Connectivity check error: $e');
      _isOnline = true;
      notifyListeners();
    }
  }

  Future<void> _syncAllData() async {
    if (_isSyncing || _currentUserId == null || !_isOnline) {
      print(
        '🟡 [SyncProvider] Skipping sync: isSyncing=$_isSyncing, userId=$_currentUserId, isOnline=$_isOnline',
      );
      return;
    }

    print('🟣 [SyncProvider] _syncAllData started');
    _isSyncing = true;
    notifyListeners();

    try {
      print('🟣 [SyncProvider] Syncing offline operations...');
      await _syncOfflineOperations();

      print('🟣 [SyncProvider] Fetching habits...');
      final habits = await _supabase.getHabits(_currentUserId!);
      print('🟣 [SyncProvider] Got ${habits.length} habits');
      if (habits.isNotEmpty) {
        await _localStorage.saveHabits(habits);
      }

      print('🟣 [SyncProvider] Fetching tasks...');
      final tasks = await _supabase.getTasks(_currentUserId!);
      print('🟣 [SyncProvider] Got ${tasks.length} tasks');
      if (tasks.isNotEmpty) {
        await _localStorage.saveTasks(tasks);
      }

      print('🟣 [SyncProvider] Fetching quests...');
      final quests = await _supabase.getQuests();
      print('🟣 [SyncProvider] Got ${quests.length} quests');
      if (quests.isNotEmpty) {
        await _localStorage.saveQuests(quests);
      }

      print('🟣 [SyncProvider] Fetching packages...');
      final packages = await _supabase.getPackages();
      print('🟣 [SyncProvider] Got ${packages.length} packages');
      if (packages.isNotEmpty) {
        await _localStorage.savePackages(packages);
      }

      print('🟣 [SyncProvider] Fetching profile...');
      try {
        final profile = await _supabase.client
            .from('profiles')
            .select()
            .eq('user_id', _currentUserId!)
            .maybeSingle();
        if (profile != null) {
          await _localStorage.saveUserProfile(profile);
          print('✅ [SyncProvider] Profile saved');
        }
      } catch (e) {
        print('🟡 [SyncProvider] Profile sync error: $e');
      }

      print('🟣 [SyncProvider] Fetching challenges...');
      final challenges = await _supabase.getChallenges();
      print('🟣 [SyncProvider] Got ${challenges.length} challenges');
      if (challenges.isNotEmpty) {
        await _localStorage.saveChallenges(challenges);
      }

      print('🟣 [SyncProvider] Fetching user challenges...');
      final userChallenges = await _supabase.getUserChallenges(_currentUserId!);
      print('🟣 [SyncProvider] Got ${userChallenges.length} user challenges');
      if (userChallenges.isNotEmpty) {
        await _localStorage.saveUserChallenges(userChallenges);
      }

      print('✅ [SyncProvider] Sync completed successfully');
    } catch (e) {
      print('🔴 [SyncProvider] Sync error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _syncOfflineOperations() async {
    print('🟣 [SyncProvider] _syncOfflineOperations started');
    final operations = _localStorage.getOfflineOperations();
    if (operations.isEmpty) {
      print('🟣 [SyncProvider] No offline operations to sync');
      return;
    }

    print(
      '🟣 [SyncProvider] Syncing ${operations.length} offline operations...',
    );

    for (var operation in operations) {
      try {
        await _executeOfflineOperation(operation);
        await _localStorage.removeOfflineOperation(operation.id);
      } catch (e) {
        print('🔴 [SyncProvider] Failed to sync operation: $e');
        if (e.toString().contains('SocketException')) break;
      }
    }
    print('✅ [SyncProvider] Offline operations sync completed');
  }

  Future<void> _executeOfflineOperation(OfflineOperation operation) async {
    final data = operation.data;

    switch (operation.type) {
      case OperationType.createHabit:
        final habit = Habit.fromMap(data['id'], data);
        await _supabase.createHabit(habit);
        break;
      case OperationType.updateHabit:
        final habit = Habit.fromMap(data['id'], data);
        await _supabase.updateHabit(habit);
        break;
      case OperationType.deleteHabit:
        await _supabase.deleteHabit(data['id']);
        break;
      case OperationType.createTask:
        final task = Task.fromMap(data['id'], data);
        await _supabase.createTask(task);
        break;
      case OperationType.updateTask:
        final task = Task.fromMap(data['id'], data);
        await _supabase.updateTask(task);
        break;
      case OperationType.deleteTask:
        await _supabase.deleteTask(data['id']);
        break;
      case OperationType.completeHabit:
        await _supabase.markHabitCompletedOnDate(
          data['habitId'],
          operation.userId,
          DateTime.parse(data['date']),
          true,
        );
        await _supabase.addXP(operation.userId, data['xpReward']);
        break;
      case OperationType.uncompleteHabit:
        await _supabase.markHabitCompletedOnDate(
          data['habitId'],
          operation.userId,
          DateTime.parse(data['date']),
          false,
        );
        await _supabase.removeXP(operation.userId, data['xpReward']);
        break;
      case OperationType.completeTask:
        final task = Task.fromMap(data['id'], data);
        await _supabase.updateTask(task);
        await _supabase.addXP(operation.userId, data['xpReward']);
        break;
      case OperationType.uncompleteTask:
        final task = Task.fromMap(data['id'], data);
        task.isCompleted = false;
        await _supabase.updateTask(task);
        await _supabase.removeXP(operation.userId, data['xpReward']);
        break;
      default:
        break;
    }
  }

  Future<void> addOfflineOperation({
    required OperationType type,
    required Map<String, dynamic> data,
  }) async {
    if (_currentUserId == null) return;

    final operation = OfflineOperation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      data: data,
      timestamp: DateTime.now(),
      userId: _currentUserId!,
    );

    await _localStorage.addOfflineOperation(operation);

    if (_isOnline) {
      try {
        await _executeOfflineOperation(operation);
        await _localStorage.removeOfflineOperation(operation.id);
      } catch (e) {
        // خطا رو نادیده بگیر
      }
    }
  }

  // ==================== Getterها ====================

  List<Habit> get habits {
    try {
      return _localStorage.getHabits();
    } catch (e) {
      return [];
    }
  }

  List<Task> get tasks {
    try {
      return _localStorage.getTasks();
    } catch (e) {
      return [];
    }
  }

  List<Quest> get quests {
    try {
      return _localStorage.getQuests();
    } catch (e) {
      return [];
    }
  }

  List<Package> get packages {
    try {
      return _localStorage.getPackages();
    } catch (e) {
      return [];
    }
  }

  Map<String, dynamic>? get profile {
    try {
      return _localStorage.getUserProfile();
    } catch (e) {
      return null;
    }
  }

  List<Map<String, dynamic>> get challenges {
    try {
      return _localStorage.getChallenges();
    } catch (e) {
      return [];
    }
  }

  List<Map<String, dynamic>> get userChallenges {
    try {
      return _localStorage.getUserChallenges();
    } catch (e) {
      return [];
    }
  }

  bool get hasChallenges {
    try {
      return _localStorage.getChallenges().isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  bool get hasLocalData {
    try {
      return habits.isNotEmpty || tasks.isNotEmpty || profile != null;
    } catch (e) {
      return false;
    }
  }

  int get offlineOperationsCount {
    try {
      return _localStorage.offlineOperationsCount;
    } catch (e) {
      return 0;
    }
  }

  bool get hasOfflineOperations => offlineOperationsCount > 0;

  // ==================== متدهای ذخیره‌سازی ====================

  Future<void> saveHabitToLocal(Habit habit) async {
    try {
      await _localStorage.saveHabit(habit);
      notifyListeners();
    } catch (e) {
      // خطا رو نادیده بگیر
    }
  }

  Future<void> saveTaskToLocal(Task task) async {
    try {
      await _localStorage.saveTask(task);
      notifyListeners();
    } catch (e) {
      // خطا رو نادیده بگیر
    }
  }

  Future<void> saveProfileToLocal(Map<String, dynamic> profile) async {
    try {
      await _localStorage.saveUserProfile(profile);
      notifyListeners();
    } catch (e) {
      print('🔴 [SyncProvider] Error saving profile to local: $e');
    }
  }

  Future<void> saveChallengesToLocal(
    List<Map<String, dynamic>> challenges,
  ) async {
    try {
      await _localStorage.saveChallenges(challenges);
      notifyListeners();
    } catch (e) {
      // خطا رو نادیده بگیر
    }
  }

  Future<void> saveUserChallengesToLocal(
    List<Map<String, dynamic>> userChallenges,
  ) async {
    try {
      await _localStorage.saveUserChallenges(userChallenges);
      notifyListeners();
    } catch (e) {
      // خطا رو نادیده بگیر
    }
  }

  Future<void> savePackagesToLocal(List<Package> packages) async {
    try {
      await _localStorage.savePackages(packages);
      notifyListeners();
    } catch (e) {
      // خطا رو نادیده بگیر
    }
  }

  Future<void> saveQuestsToLocal(List<Quest> quests) async {
    try {
      await _localStorage.saveQuests(quests);
      notifyListeners();
    } catch (e) {
      // خطا رو نادیده بگیر
    }
  }

  Future<void> manualSync() async {
    if (_isOnline) {
      await _syncAllData();
    }
  }

  Future<void> refreshProfile() async {
    if (_currentUserId == null) return;
    if (_isOnline) {
      try {
        final profile = await _supabase.client
            .from('profiles')
            .select()
            .eq('user_id', _currentUserId!)
            .maybeSingle();
        if (profile != null) {
          await _localStorage.saveUserProfile(profile);
          notifyListeners();
        }
      } catch (e) {
        // خطا رو نادیده بگیر
      }
    }
  }
}
