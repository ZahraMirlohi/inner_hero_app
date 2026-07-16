// lib/providers/sync_provider.dart

import 'package:flutter/material.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';
import '../services/local_storage_service.dart';
import '../features/arena/models/habit_model.dart';
import '../features/arena/models/task_model.dart';
import '../features/explore/models/quest_model.dart';
import '../features/explore/models/package_model.dart';
import '../models/offline_operation.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
    _init();
  }

  Future<void> _init() async {
    try {
      await _localStorage.init();
      print('✅ LocalStorage initialized');

      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getString('user_id');
      print('👤 Current user: $_currentUserId');

      _isInitialized = true;
      notifyListeners();

      _checkConnectivity();

      if (_isOnline && _currentUserId != null) {
        _syncAllData();
      }
    } catch (e) {
      print('❌ Init error: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  void _checkConnectivity() {
    // ✅ فقط در پلتفرم‌های موبایل و دسکتاپ چک کن
    if (kIsWeb) {
      // در وب، همیشه آنلاین در نظر بگیر
      _isOnline = true;
      notifyListeners();
      if (_currentUserId != null) {
        _syncAllData();
      }
      return;
    }

    try {
      InternetConnectionChecker().onStatusChange.listen((status) {
        final isOnline = status == InternetConnectionStatus.connected;
        if (_isOnline != isOnline) {
          _isOnline = isOnline;
          notifyListeners();
          if (_isOnline && _currentUserId != null) {
            _syncAllData();
          }
        }
      });
    } catch (e) {
      print('⚠️ Connectivity check error: $e');
      // در صورت خطا، آنلاین فرض کن
      _isOnline = true;
      notifyListeners();
      if (_currentUserId != null) {
        _syncAllData();
      }
    }
  }

  Future<void> _syncAllData() async {
    if (_isSyncing || _currentUserId == null || !_isOnline) return;

    _isSyncing = true;
    notifyListeners();

    try {
      print('🔄 Syncing data...');

      await _syncOfflineOperations();

      final habits = await _supabase.getHabits(_currentUserId!);
      if (habits.isNotEmpty) {
        await _localStorage.saveHabits(habits);
      }

      final tasks = await _supabase.getTasks(_currentUserId!);
      if (tasks.isNotEmpty) {
        await _localStorage.saveTasks(tasks);
      }

      final quests = await _supabase.getQuests();
      if (quests.isNotEmpty) {
        await _localStorage.saveQuests(quests);
      }

      final packages = await _supabase.getPackages();
      if (packages.isNotEmpty) {
        await _localStorage.savePackages(packages);
      }

      try {
        final profile = await _supabase.client
            .from('profiles')
            .select()
            .eq('user_id', _currentUserId!)
            .maybeSingle();
        if (profile != null) {
          await _localStorage.saveUserProfile(profile);
        }
      } catch (e) {
        print('⚠️ Profile sync error: $e');
      }

      final challenges = await _supabase.getChallenges();
      if (challenges.isNotEmpty) {
        await _localStorage.saveChallenges(challenges);
      }

      final userChallenges = await _supabase.getUserChallenges(_currentUserId!);
      if (userChallenges.isNotEmpty) {
        await _localStorage.saveUserChallenges(userChallenges);
      }

      print('✅ Sync completed');
    } catch (e) {
      print('⚠️ Sync error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _syncOfflineOperations() async {
    final operations = _localStorage.getOfflineOperations();
    if (operations.isEmpty) return;

    print('🔄 Syncing ${operations.length} offline operations...');

    for (var operation in operations) {
      try {
        await _executeOfflineOperation(operation);
        await _localStorage.removeOfflineOperation(operation.id);
      } catch (e) {
        print('⚠️ Failed to sync operation: $e');
        if (e.toString().contains('SocketException')) break;
      }
    }
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

  // ✅ متد saveProfileToLocal که در profile_screen استفاده میشه
  Future<void> saveProfileToLocal(Map<String, dynamic> profile) async {
    try {
      await _localStorage.saveUserProfile(profile);
      notifyListeners();
    } catch (e) {
      print('❌ Error saving profile to local: $e');
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
