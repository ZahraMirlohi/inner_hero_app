// lib/services/local_storage_service.dart

import 'package:hive_flutter/hive_flutter.dart';
import '../features/arena/models/habit_model.dart';
import '../features/arena/models/task_model.dart';
import '../features/explore/models/quest_model.dart';
import '../features/explore/models/package_model.dart';
import '../features/explore/models/package_habit_model.dart';
import '../models/offline_operation.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  static const String _habitsBoxName = 'habits';
  static const String _tasksBoxName = 'tasks';
  static const String _questsBoxName = 'quests';
  static const String _packagesBoxName = 'packages';
  static const String _settingsBoxName = 'settings';
  static const String _userProfileBoxName = 'user_profile';
  static const String _offlineBoxName = 'offline_operations';
  static const String _challengesBoxName = 'challenges';
  static const String _userChallengesBoxName = 'user_challenges';

  late Box _habitsBox;
  late Box _tasksBox;
  late Box _questsBox;
  late Box _packagesBox;
  late Box _settingsBox;
  late Box _userProfileBox;
  late Box _offlineBox;
  late Box _challengesBox;
  late Box _userChallengesBox;

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await Hive.initFlutter();

      // ✅ ثبت Adapterها با مدیریت خطا
      try {
        Hive.registerAdapter(HabitAdapter());
      } catch (e) {
        // Adapter قبلاً ثبت شده
      }
      try {
        Hive.registerAdapter(TaskAdapter());
      } catch (e) {}
      try {
        Hive.registerAdapter(QuestAdapter());
      } catch (e) {}
      try {
        Hive.registerAdapter(PackageAdapter());
      } catch (e) {}
      try {
        Hive.registerAdapter(PackageHabitAdapter());
      } catch (e) {}
      try {
        Hive.registerAdapter(ReminderAdapter());
      } catch (e) {}
      try {
        Hive.registerAdapter(OfflineOperationAdapter());
      } catch (e) {}

      // باز کردن Boxها
      _habitsBox = await Hive.openBox(_habitsBoxName);
      _tasksBox = await Hive.openBox(_tasksBoxName);
      _questsBox = await Hive.openBox(_questsBoxName);
      _packagesBox = await Hive.openBox(_packagesBoxName);
      _settingsBox = await Hive.openBox(_settingsBoxName);
      _userProfileBox = await Hive.openBox(_userProfileBoxName);
      _offlineBox = await Hive.openBox(_offlineBoxName);
      _challengesBox = await Hive.openBox(_challengesBoxName);
      _userChallengesBox = await Hive.openBox(_userChallengesBoxName);

      _isInitialized = true;
      print('✅ LocalStorageService initialized successfully');
      print('   - Offline operations: ${_offlineBox.length}');
    } catch (e) {
      print('❌ LocalStorageService init error: $e');
      _isInitialized = true;
      rethrow;
    }
  }

  bool get isInitialized => _isInitialized;

  // ==================== Habit Operations ====================

  Future<void> saveHabits(List<Habit> habits) async {
    try {
      await _habitsBox.put('user_habits', habits);
    } catch (e) {
      print('❌ Error saving habits: $e');
      rethrow;
    }
  }

  List<Habit> getHabits() {
    try {
      if (!_isInitialized) return [];
      final data = _habitsBox.get('user_habits');
      if (data == null) return [];
      return (data as List).cast<Habit>();
    } catch (e) {
      print('❌ Error getting habits: $e');
      return [];
    }
  }

  Future<void> saveHabit(Habit habit) async {
    try {
      final habits = getHabits();
      final index = habits.indexWhere((h) => h.id == habit.id);
      if (index != -1) {
        habits[index] = habit;
      } else {
        habits.add(habit);
      }
      await saveHabits(habits);
    } catch (e) {
      print('❌ Error saving habit: $e');
      rethrow;
    }
  }

  Future<void> deleteHabit(String habitId) async {
    try {
      final habits = getHabits();
      habits.removeWhere((h) => h.id == habitId);
      await saveHabits(habits);
    } catch (e) {
      print('❌ Error deleting habit: $e');
      rethrow;
    }
  }

  // ==================== Task Operations ====================

  Future<void> saveTasks(List<Task> tasks) async {
    try {
      await _tasksBox.put('user_tasks', tasks);
    } catch (e) {
      print('❌ Error saving tasks: $e');
      rethrow;
    }
  }

  List<Task> getTasks() {
    try {
      if (!_isInitialized) return [];
      final data = _tasksBox.get('user_tasks');
      if (data == null) return [];
      return (data as List).cast<Task>();
    } catch (e) {
      print('❌ Error getting tasks: $e');
      return [];
    }
  }

  Future<void> saveTask(Task task) async {
    try {
      final tasks = getTasks();
      final index = tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        tasks[index] = task;
      } else {
        tasks.add(task);
      }
      await saveTasks(tasks);
    } catch (e) {
      print('❌ Error saving task: $e');
      rethrow;
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      final tasks = getTasks();
      tasks.removeWhere((t) => t.id == taskId);
      await saveTasks(tasks);
    } catch (e) {
      print('❌ Error deleting task: $e');
      rethrow;
    }
  }

  // ==================== Quest Operations ====================

  Future<void> saveQuests(List<Quest> quests) async {
    try {
      await _questsBox.put('available_quests', quests);
    } catch (e) {
      print('❌ Error saving quests: $e');
      rethrow;
    }
  }

  List<Quest> getQuests() {
    try {
      if (!_isInitialized) return [];
      final data = _questsBox.get('available_quests');
      if (data == null) return [];
      return (data as List).cast<Quest>();
    } catch (e) {
      print('❌ Error getting quests: $e');
      return [];
    }
  }

  // ==================== Package Operations ====================

  Future<void> savePackages(List<Package> packages) async {
    try {
      await _packagesBox.put('available_packages', packages);
    } catch (e) {
      print('❌ Error saving packages: $e');
      rethrow;
    }
  }

  List<Package> getPackages() {
    try {
      if (!_isInitialized) return [];
      final data = _packagesBox.get('available_packages');
      if (data == null) return [];
      return (data as List).cast<Package>();
    } catch (e) {
      print('❌ Error getting packages: $e');
      return [];
    }
  }

  // ==================== Profile Operations ====================

  Future<void> saveUserProfile(Map<String, dynamic> profile) async {
    try {
      await _userProfileBox.put('profile', profile);
    } catch (e) {
      print('❌ Error saving profile: $e');
      rethrow;
    }
  }

  Map<String, dynamic>? getUserProfile() {
    try {
      if (!_isInitialized) return null;
      return _userProfileBox.get('profile');
    } catch (e) {
      print('❌ Error getting profile: $e');
      return null;
    }
  }

  Future<void> deleteUserProfile() async {
    try {
      await _userProfileBox.delete('profile');
    } catch (e) {
      print('❌ Error deleting profile: $e');
      rethrow;
    }
  }

  // ==================== Challenges Operations ====================

  Future<void> saveChallenges(List<Map<String, dynamic>> challenges) async {
    try {
      await _challengesBox.put('challenges', challenges);
    } catch (e) {
      print('❌ Error saving challenges: $e');
      rethrow;
    }
  }

  List<Map<String, dynamic>> getChallenges() {
    try {
      if (!_isInitialized) return [];
      final data = _challengesBox.get('challenges');
      if (data == null) return [];
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('❌ Error getting challenges: $e');
      return [];
    }
  }

  Future<void> saveUserChallenges(
    List<Map<String, dynamic>> userChallenges,
  ) async {
    try {
      await _userChallengesBox.put('user_challenges', userChallenges);
    } catch (e) {
      print('❌ Error saving user challenges: $e');
      rethrow;
    }
  }

  List<Map<String, dynamic>> getUserChallenges() {
    try {
      if (!_isInitialized) return [];
      final data = _userChallengesBox.get('user_challenges');
      if (data == null) return [];
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('❌ Error getting user challenges: $e');
      return [];
    }
  }

  Future<void> updateChallengeStatus(String challengeId, bool isJoined) async {
    try {
      final challenges = getChallenges();
      final index = challenges.indexWhere((c) => c['id'] == challengeId);
      if (index != -1) {
        challenges[index]['isJoined'] = isJoined;
        await saveChallenges(challenges);
      }
    } catch (e) {
      print('❌ Error updating challenge status: $e');
      rethrow;
    }
  }

  // ==================== Offline Operations ====================

  Future<void> addOfflineOperation(OfflineOperation operation) async {
    try {
      if (!_isInitialized) {
        await init();
      }
      await _offlineBox.add(operation.toMap());
      print('📝 Offline operation added: ${operation.type} (${operation.id})');
      print('   - Total operations: ${_offlineBox.length}');
    } catch (e) {
      print('❌ Error adding offline operation: $e');
      rethrow;
    }
  }

  List<OfflineOperation> getOfflineOperations() {
    try {
      if (!_isInitialized) return [];
      final List<OfflineOperation> operations = [];
      for (var key in _offlineBox.keys) {
        final data = _offlineBox.get(key);
        if (data != null) {
          try {
            operations.add(OfflineOperation.fromMap(data));
          } catch (e) {
            print('⚠️ Error parsing offline operation: $e');
          }
        }
      }
      return operations;
    } catch (e) {
      print('❌ Error getting offline operations: $e');
      return [];
    }
  }

  Future<void> removeOfflineOperation(String id) async {
    try {
      for (var key in _offlineBox.keys) {
        final data = _offlineBox.get(key);
        if (data != null && data['id'] == id) {
          await _offlineBox.delete(key);
          print('🗑️ Offline operation removed: $id');
          break;
        }
      }
    } catch (e) {
      print('❌ Error removing offline operation: $e');
      rethrow;
    }
  }

  Future<void> clearOfflineOperations() async {
    try {
      await _offlineBox.clear();
      print('🗑️ All offline operations cleared');
    } catch (e) {
      print('❌ Error clearing offline operations: $e');
      rethrow;
    }
  }

  Future<void> removeOfflineOperationsByType(OperationType type) async {
    try {
      final List<dynamic> keysToRemove = [];
      for (var key in _offlineBox.keys) {
        final data = _offlineBox.get(key);
        if (data != null && data['type'] == type.index) {
          keysToRemove.add(key);
        }
      }
      for (var key in keysToRemove) {
        await _offlineBox.delete(key);
      }
      print('🗑️ Removed ${keysToRemove.length} operations of type $type');
    } catch (e) {
      print('❌ Error removing operations by type: $e');
      rethrow;
    }
  }

  int get offlineOperationsCount {
    try {
      if (!_isInitialized) return 0;
      return _offlineBox.length;
    } catch (e) {
      return 0;
    }
  }

  bool hasOfflineOperations() {
    return offlineOperationsCount > 0;
  }

  // ==================== Settings ====================

  Future<void> saveSetting(String key, dynamic value) async {
    try {
      await _settingsBox.put(key, value);
    } catch (e) {
      print('❌ Error saving setting: $e');
      rethrow;
    }
  }

  T? getSetting<T>(String key, {T? defaultValue}) {
    try {
      if (!_isInitialized) return defaultValue;
      return _settingsBox.get(key, defaultValue: defaultValue);
    } catch (e) {
      print('❌ Error getting setting: $e');
      return defaultValue;
    }
  }

  Future<void> removeSetting(String key) async {
    try {
      await _settingsBox.delete(key);
    } catch (e) {
      print('❌ Error removing setting: $e');
      rethrow;
    }
  }

  // ==================== Utility ====================

  Future<void> clearAll() async {
    try {
      await _habitsBox.clear();
      await _tasksBox.clear();
      await _questsBox.clear();
      await _packagesBox.clear();
      await _settingsBox.clear();
      await _userProfileBox.clear();
      await _offlineBox.clear();
      await _challengesBox.clear();
      await _userChallengesBox.clear();
      print('🗑️ All local data cleared');
    } catch (e) {
      print('❌ Error clearing all data: $e');
      rethrow;
    }
  }

  Future<void> clearAllDataExceptProfile() async {
    try {
      final profile = getUserProfile();
      await _habitsBox.clear();
      await _tasksBox.clear();
      await _questsBox.clear();
      await _packagesBox.clear();
      await _settingsBox.clear();
      await _offlineBox.clear();
      await _challengesBox.clear();
      await _userChallengesBox.clear();
      if (profile != null) {
        await saveUserProfile(profile);
      }
      print('🗑️ All data except profile cleared');
    } catch (e) {
      print('❌ Error clearing data: $e');
      rethrow;
    }
  }

  // ==================== Debug ====================

  void printDebugInfo() {
    print('📊 LocalStorage Debug Info:');
    print('   - Initialized: $_isInitialized');
    print('   - Habits: ${getHabits().length}');
    print('   - Tasks: ${getTasks().length}');
    print('   - Quests: ${getQuests().length}');
    print('   - Packages: ${getPackages().length}');
    print('   - Profile: ${getUserProfile() != null ? "Yes" : "No"}');
    print('   - Challenges: ${getChallenges().length}');
    print('   - User Challenges: ${getUserChallenges().length}');
    print('   - Offline Operations: $offlineOperationsCount');
  }
}

// ==================== Hive Adapters ====================

class HabitAdapter extends TypeAdapter<Habit> {
  @override
  final int typeId = 0;

  @override
  Habit read(BinaryReader reader) {
    return Habit(
      id: reader.readString(),
      userId: reader.readString(),
      title: reader.readString(),
      description: reader.readString(),
      subHabits: reader.readList().cast<String>(),
      completedSubHabits: reader.readList().cast<String>(),
      iconName: reader.readString(),
      iconColor: reader.readInt(),
      backgroundColor: reader.readInt(),
      frequencyType: reader.readString(),
      dailyIntervalDays: reader.readList().cast<int>(),
      weeklyDays: reader.readList().cast<int>(),
      weeklyIntervalWeeks: reader.readInt(),
      monthlyDays: reader.readList().cast<int>(),
      monthlyIntervalMonths: reader.readInt(),
      timeOfDay: reader.readString(),
      reminders: reader.readList().cast<Reminder>(),
      xpReward: reader.readInt(),
      currentStreak: reader.readInt(),
      bestStreak: reader.readInt(),
      isActive: reader.readBool(),
      createdAt: DateTime.parse(reader.readString()),
      updatedAt: DateTime.parse(reader.readString()),
      groupId: reader.readString().isEmpty ? null : reader.readString(),
      startDate: reader.readString().isEmpty
          ? null
          : DateTime.parse(reader.readString()),
      endDate: reader.readString().isEmpty
          ? null
          : DateTime.parse(reader.readString()),
      challengeId: reader.readString().isEmpty ? null : reader.readString(),
      questId: reader.readString().isEmpty ? null : reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, Habit obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.userId);
    writer.writeString(obj.title);
    writer.writeString(obj.description);
    writer.writeList(obj.subHabits);
    writer.writeList(obj.completedSubHabits);
    writer.writeString(obj.iconName);
    writer.writeInt(obj.iconColor);
    writer.writeInt(obj.backgroundColor);
    writer.writeString(obj.frequencyType);
    writer.writeList(obj.dailyIntervalDays ?? []);
    writer.writeList(obj.weeklyDays ?? []);
    writer.writeInt(obj.weeklyIntervalWeeks ?? 1);
    writer.writeList(obj.monthlyDays ?? []);
    writer.writeInt(obj.monthlyIntervalMonths ?? 1);
    writer.writeString(obj.timeOfDay);
    writer.writeList(obj.reminders);
    writer.writeInt(obj.xpReward);
    writer.writeInt(obj.currentStreak);
    writer.writeInt(obj.bestStreak);
    writer.writeBool(obj.isActive);
    writer.writeString(obj.createdAt.toIso8601String());
    writer.writeString(obj.updatedAt.toIso8601String());
    writer.writeString(obj.groupId ?? '');
    writer.writeString(obj.startDate?.toIso8601String() ?? '');
    writer.writeString(obj.endDate?.toIso8601String() ?? '');
    writer.writeString(obj.challengeId ?? '');
    writer.writeString(obj.questId ?? '');
  }
}

class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 1;

  @override
  Task read(BinaryReader reader) {
    return Task(
      id: reader.readString(),
      userId: reader.readString(),
      title: reader.readString(),
      description: reader.readString(),
      subTasks: reader.readList().cast<String>(),
      completedSubTasks: reader.readList().cast<String>(),
      dueDate: reader.readString().isEmpty
          ? null
          : DateTime.parse(reader.readString()),
      isCompleted: reader.readBool(),
      xpReward: reader.readInt(),
      createdAt: DateTime.parse(reader.readString()),
      updatedAt: DateTime.parse(reader.readString()),
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.userId);
    writer.writeString(obj.title);
    writer.writeString(obj.description);
    writer.writeList(obj.subTasks);
    writer.writeList(obj.completedSubTasks);
    writer.writeString(obj.dueDate?.toIso8601String() ?? '');
    writer.writeBool(obj.isCompleted);
    writer.writeInt(obj.xpReward);
    writer.writeString(obj.createdAt.toIso8601String());
    writer.writeString(obj.updatedAt.toIso8601String());
  }
}

class ReminderAdapter extends TypeAdapter<Reminder> {
  @override
  final int typeId = 2;

  @override
  Reminder read(BinaryReader reader) {
    return Reminder(
      id: reader.readString(),
      hour: reader.readInt(),
      minute: reader.readInt(),
      isEnabled: reader.readBool(),
    );
  }

  @override
  void write(BinaryWriter writer, Reminder obj) {
    writer.writeString(obj.id);
    writer.writeInt(obj.hour);
    writer.writeInt(obj.minute);
    writer.writeBool(obj.isEnabled);
  }
}

class QuestAdapter extends TypeAdapter<Quest> {
  @override
  final int typeId = 3;

  @override
  Quest read(BinaryReader reader) {
    return Quest(
      id: reader.readString(),
      title: reader.readString(),
      description: reader.readString(),
      icon: reader.readString(),
      color: reader.readString(),
      xpReward: reader.readInt(),
      badge: reader.readString(),
      targetCount: reader.readInt(),
      isActive: reader.readBool(),
      createdAt: DateTime.parse(reader.readString()),
    );
  }

  @override
  void write(BinaryWriter writer, Quest obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.title);
    writer.writeString(obj.description);
    writer.writeString(obj.icon);
    writer.writeString(obj.color);
    writer.writeInt(obj.xpReward);
    writer.writeString(obj.badge);
    writer.writeInt(obj.targetCount);
    writer.writeBool(obj.isActive);
    writer.writeString(obj.createdAt.toIso8601String());
  }
}

class PackageAdapter extends TypeAdapter<Package> {
  @override
  final int typeId = 4;

  @override
  Package read(BinaryReader reader) {
    return Package(
      id: reader.readString(),
      title: reader.readString(),
      description: reader.readString(),
      icon: reader.readString(),
      color: reader.readString(),
      backgroundColor: reader.readString(),
      category: reader.readString(),
      habits: reader.readList().cast<PackageHabit>(),
      isActive: reader.readBool(),
      xpReward: reader.readInt(),
      badge: reader.readString(),
      createdAt: DateTime.parse(reader.readString()),
    );
  }

  @override
  void write(BinaryWriter writer, Package obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.title);
    writer.writeString(obj.description);
    writer.writeString(obj.icon);
    writer.writeString(obj.color);
    writer.writeString(obj.backgroundColor);
    writer.writeString(obj.category);
    writer.writeList(obj.habits);
    writer.writeBool(obj.isActive);
    writer.writeInt(obj.xpReward);
    writer.writeString(obj.badge);
    writer.writeString(obj.createdAt.toIso8601String());
  }
}

class PackageHabitAdapter extends TypeAdapter<PackageHabit> {
  @override
  final int typeId = 5;

  @override
  PackageHabit read(BinaryReader reader) {
    return PackageHabit(
      id: reader.readString(),
      title: reader.readString(),
      description: reader.readString(),
      iconName: reader.readString(),
      iconColor: reader.readInt(),
      backgroundColor: reader.readInt(),
      frequencyType: reader.readString(),
      weeklyDays: reader.readList().cast<int>(),
      monthlyDays: reader.readList().cast<int>(),
      dailyIntervalDays: reader.readInt(),
      timeOfDay: reader.readString(),
      xpReward: reader.readInt(),
      subHabits: reader.readList().cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, PackageHabit obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.title);
    writer.writeString(obj.description);
    writer.writeString(obj.iconName);
    writer.writeInt(obj.iconColor);
    writer.writeInt(obj.backgroundColor);
    writer.writeString(obj.frequencyType);
    writer.writeList(obj.weeklyDays ?? []);
    writer.writeList(obj.monthlyDays ?? []);
    writer.writeInt(obj.dailyIntervalDays ?? 1);
    writer.writeString(obj.timeOfDay);
    writer.writeInt(obj.xpReward);
    writer.writeList(obj.subHabits);
  }
}

class OfflineOperationAdapter extends TypeAdapter<OfflineOperation> {
  @override
  final int typeId = 6;

  @override
  OfflineOperation read(BinaryReader reader) {
    return OfflineOperation(
      id: reader.readString(),
      type: OperationType.values[reader.readInt()],
      data: reader.readMap().cast<String, dynamic>(),
      timestamp: DateTime.parse(reader.readString()),
      userId: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, OfflineOperation obj) {
    writer.writeString(obj.id);
    writer.writeInt(obj.type.index);
    writer.writeMap(obj.data);
    writer.writeString(obj.timestamp.toIso8601String());
    writer.writeString(obj.userId);
  }
}
