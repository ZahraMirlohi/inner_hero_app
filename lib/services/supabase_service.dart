// lib/services/supabase_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../features/arena/models/habit_model.dart';
import '../features/arena/models/task_model.dart';
import '/features/explore/models/package_model.dart';
import '/features/explore/models/user_packages.dart';
import '/features/explore/models/quest_model.dart';
import '/features/explore/models/user_quest_model.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'local_storage_service.dart';
import '../utils/unique_id_generator.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../features/arena/models/habit_completion.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  User? _cachedUser;
  DateTime? _userCacheTime;
  static const Duration _userCacheDuration = Duration(minutes: 5);
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  Future<bool> isOnline() async {
    try {
      if (kIsWeb) {
        return true;
      }
      final result = await InternetConnectionChecker().hasConnection;
      return result;
    } catch (e) {
      return true;
    }
  }

  // ==================== Auth ====================

  Future<AuthResponse> login(String email, String password) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signup(
    String email,
    String password,
    String name,
  ) async {
    // ✅ تولید ID یکتا قبل از ثبت‌نام
    final uniqueId = UniqueIdGenerator.generateSecure();

    return await client.auth.signUp(
      email: email,
      password: password,
      data: {
        'name': name,
        'email': email,
        'unique_id': uniqueId, // ✅ ارسال unique_id به Supabase
      },
    );
  }

  Future<void> logout() async {
    await client.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    _cachedUser = null;
    _userCacheTime = null;
  }

  Future<User?> getCurrentUser() async {
    try {
      if (_cachedUser != null &&
          _userCacheTime != null &&
          DateTime.now().difference(_userCacheTime!) < _userCacheDuration) {
        return _cachedUser;
      }

      try {
        final user = client.auth.currentUser;
        if (user != null) {
          _cachedUser = user;
          _userCacheTime = DateTime.now();
          return user;
        }
      } catch (e) {
        if (_cachedUser != null) {
          return _cachedUser;
        }
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        final savedUserId = prefs.getString('user_id');
        if (savedUserId != null) {
          final response = await client
              .from('profiles')
              .select('user_id, created_at')
              .eq('user_id', savedUserId)
              .maybeSingle();

          if (response != null) {
            _cachedUser = User(
              id: savedUserId,
              appMetadata: {},
              userMetadata: {},
              aud: 'authenticated',
              createdAt: DateTime.now().toIso8601String(),
            );
            _userCacheTime = DateTime.now();
            return _cachedUser;
          }
        }
      } catch (e) {
        // ignore
      }

      return null;
    } catch (e) {
      return _cachedUser;
    }
  }

  void clearUserCache() {
    _cachedUser = null;
    _userCacheTime = null;
  }

  // lib/services/supabase_service.dart

  /// ✅ اضافه کردن متد برای رفرش توکن
  Future<bool> refreshSession() async {
    try {
      final session = client.auth.currentSession;
      if (session == null) {
        print('⚠️ No active session to refresh');
        return false;
      }

      // ✅ تلاش برای رفرش توکن
      await client.auth.refreshSession();
      print('✅ Session refreshed successfully');
      return true;
    } catch (e) {
      print('❌ Error refreshing session: $e');
      return false;
    }
  }

  /// ✅ متد بررسی و رفرش توکن در صورت نیاز
  Future<bool> ensureValidSession() async {
    try {
      final session = client.auth.currentSession;
      if (session == null) {
        print('⚠️ No active session');
        return false;
      }

      // ✅ بررسی انقضای توکن (5 دقیقه قبل از انقضا)
      final expiresAt = session.expiresAt;
      if (expiresAt != null) {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final timeLeft = expiresAt - now;

        if (timeLeft < 300) {
          // کمتر از 5 دقیقه
          print('⏰ Token expires soon, refreshing...');
          await client.auth.refreshSession();
          print('✅ Token refreshed');
        }
      }

      return true;
    } catch (e) {
      print('❌ Error ensuring valid session: $e');
      return false;
    }
  }

  // ==================== Profiles ====================

  Future<void> createProfile(String userId, String email, String name) async {
    // ✅ تولید ID یکتا برای پروفایل
    final uniqueId = UniqueIdGenerator.generateSecure();

    await client.from('profiles').insert({
      'user_id': userId,
      'email': email,
      'name': name,
      'unique_id': uniqueId, // ✅ ذخیره unique_id
      'total_xp': 0,
    });
  }

  Future<Map<String, dynamic>?> getHabit(String habitId) async {
    try {
      print('🔍 Getting habit with ID: $habitId');

      final response =
          await client.from('habits').select().eq('id', habitId).maybeSingle();

      if (response == null) {
        print('⚠️ Habit not found: $habitId');
        return null;
      }

      print('✅ Habit found: ${response['title']}');
      return response;
    } catch (e) {
      print('❌ Error getting habit: $e');
      return null;
    }
  }

// ✅ اصلاح متد markHabitCompletedWithLevel - حذف onConflict
  Future<void> markHabitCompletedWithLevel({
    required String habitId,
    required String userId,
    required DateTime date,
    required CompletionLevel level,
  }) async {
    try {
      final dateStr = _getDateString(date);
      final now = DateTime.now();

      // 1. دریافت عادت و محاسبه XP
      int xpReward = 10;
      try {
        final habit = await getHabit(habitId);
        if (habit != null) {
          xpReward = habit['xp_reward'] as int? ?? 10;
        }
      } catch (e) {
        print('⚠️ Could not get habit, using default XP: $e');
      }

      final xpEarned = (xpReward * level.xpMultiplier / 100).round();

      // 2. حذف رکورد قبلی
      await client
          .from('habit_completions')
          .delete()
          .eq('habit_id', habitId)
          .eq('user_id', userId)
          .eq('date', dateStr);

      // 3. درج رکورد جدید
      await client.from('habit_completions').insert({
        'habit_id': habitId,
        'user_id': userId,
        'date': dateStr,
        'completion_level': level.toString().split('.').last,
        'completed_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
      });

      // 4. اجرای همزمان دو عملیات
      await Future.wait([
        addXP(userId, xpEarned),
        updateUserStreak(userId),
      ]);

      print(
          '✅ Habit completed with level: ${level.displayName} (+$xpEarned XP)');
    } catch (e) {
      print('❌ Error marking habit with level: $e');
      rethrow;
    }
  }

// ✅ متد دریافت تاریخچه تکمیل عادت با سطح (اصلاح شده)
  Future<List<HabitCompletion>> getHabitCompletionsWithLevel({
    required String habitId,
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // ✅ ساخت کوئری با ترتیب صحیح
      var query = client
          .from('habit_completions')
          .select()
          .eq('habit_id', habitId)
          .eq('user_id', userId);

      // ✅ اضافه کردن فیلترهای تاریخ با استفاده از filter
      if (startDate != null) {
        final startStr = _getDateString(startDate);
        query = query.filter('date', 'gte', startStr);
      }
      if (endDate != null) {
        final endStr = _getDateString(endDate);
        query = query.filter('date', 'lte', endStr);
      }

      // ✅ مرتب‌سازی در انتها
      final response = await query.order('date', ascending: true);

      return response.map((data) => HabitCompletion.fromMap(data)).toList();
    } catch (e) {
      print('❌ Error getting habit completions with level: $e');
      return [];
    }
  }

// lib/services/supabase_service.dart

// ✅ متد دریافت داده‌های نمودار برای یک عادت (نسخه نهایی)
  Future<List<Map<String, dynamic>>> getHabitChartData({
    required String habitId,
    required String userId,
  }) async {
    try {
      // ✅ محاسبه دقیق روزهای ماه جاری
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
      final daysInMonth = lastDayOfMonth.day;

      final startDate = firstDayOfMonth;
      final endDate = lastDayOfMonth;

      print(
          '📊 Chart date range: $startDate to $endDate (${daysInMonth} days)');

      // ✅ دریافت تکمیل‌های عادت در بازه ماه جاری
      final completions = await getHabitCompletionsWithLevel(
        habitId: habitId,
        userId: userId,
        startDate: startDate,
        endDate: endDate,
      );

      print('📊 Found ${completions.length} completions for this month');

      // ✅ ساخت داده‌های نمودار
      final List<Map<String, dynamic>> chartData = [];

      for (int i = 0; i < daysInMonth; i++) {
        final date = startDate.add(Duration(days: i));
        final dateStr = _getDateString(date);

        // ✅ پیدا کردن تکمیل برای این روز
        final completion = completions.firstWhere(
          (c) =>
              c.date.year == date.year &&
              c.date.month == date.month &&
              c.date.day == date.day,
          orElse: () => HabitCompletion(
            id: '',
            habitId: habitId,
            userId: userId,
            date: date,
            level: CompletionLevel.full,
            completedAt: DateTime.now(),
            createdAt: DateTime.now(),
          ),
        );

        chartData.add({
          'date': dateStr,
          'day': i + 1,
          'level': completion.level.toString().split('.').last,
          'level_display': completion.level.displayName,
          'emoji': completion.level.emoji,
          'isCompleted': completion.id.isNotEmpty,
        });
      }

      print('📊 Chart data built with ${chartData.length} days');
      return chartData;
    } catch (e) {
      print('❌ Error getting chart data: $e');
      return [];
    }
  }

  // ==================== Habits ====================

  Future<List<Habit>> getHabits(String userId) async {
    if (!await isOnline()) {
      return [];
    }

    try {
      final response = await client
          .from('habits')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return response
          .map((data) => Habit.fromMap(data['id'], _convertKeys(data)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> createHabit(Habit habit) async {
    final data = habit.toMap();
    data.remove('id');
    await client.from('habits').insert(data);
  }

  Future<void> updateHabit(Habit habit) async {
    final data = habit.toMap();
    data.remove('id');
    await client.from('habits').update(data).eq('id', habit.id);
  }

  Future<void> deleteHabit(String habitId) async {
    await client.from('habits').delete().eq('id', habitId);
  }

  // ==================== Tasks ====================

  Future<List<Task>> getTasks(String userId) async {
    if (!await isOnline()) {
      return [];
    }

    try {
      final response = await client
          .from('tasks')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return response
          .map((data) => Task.fromMap(data['id'], _convertKeys(data)))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> createTask(Task task) async {
    final data = task.toMap();
    data.remove('id');
    await client.from('tasks').insert(data);
  }

  Future<void> updateTask(Task task) async {
    final data = task.toMap();
    data.remove('id');
    await client.from('tasks').update(data).eq('id', task.id);
  }

  Future<void> deleteTask(String taskId) async {
    await client.from('tasks').delete().eq('id', taskId);
  }

  // ==================== Habit Completions ====================

  String _getDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<bool> isHabitCompletedOnDate(
    String habitId,
    String userId,
    DateTime date,
  ) async {
    try {
      final dateStr = _getDateString(date);
      final response = await client
          .from('habit_completions')
          .select()
          .eq('habit_id', habitId)
          .eq('user_id', userId)
          .eq('date', dateStr);

      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> markHabitCompletedOnDate(
    String habitId,
    String userId,
    DateTime date,
    bool completed,
  ) async {
    try {
      final dateStr = _getDateString(date);

      if (completed) {
        final existing = await client
            .from('habit_completions')
            .select()
            .eq('habit_id', habitId)
            .eq('user_id', userId)
            .eq('date', dateStr);

        if (existing.isEmpty) {
          await client.from('habit_completions').insert({
            'habit_id': habitId,
            'user_id': userId,
            'date': dateStr,
          });

          if (await isOnline()) {
            await _updateChallengeProgressForHabit(userId, habitId);
          }
        }
      } else {
        await client
            .from('habit_completions')
            .delete()
            .eq('habit_id', habitId)
            .eq('user_id', userId)
            .eq('date', dateStr);

        if (await isOnline()) {
          await _updateChallengeProgressForHabit(userId, habitId);
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  // lib/services/supabase_service.dart

  Future<void> updateChallengeProgress(
    String userId,
    String challengeId,
  ) async {
    if (!await isOnline()) {
      print('⚠️ Offline, skipping challenge progress update');
      return;
    }

    try {
      print('📊 Updating challenge progress for: $challengeId');

      // 1. دریافت تعداد روزهای تکمیل شده
      final completions = await client
          .from('challenge_completions')
          .select('date')
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);

      print('📊 Completions count: ${completions.length}');

      // 2. دریافت اطلاعات چالش
      final challenge = await client
          .from('challenges')
          .select('challenge_duration')
          .eq('id', challengeId)
          .maybeSingle();

      final completedDays = completions.length;
      final totalDays = challenge?['challenge_duration'] as int? ?? 7;

      print('📊 Completed: $completedDays / $totalDays');

      // 3. به‌روزرسانی
      await client
          .from('user_challenges')
          .update({
            'progress': completedDays > totalDays ? totalDays : completedDays,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);

      print('✅ Challenge progress updated: $completedDays / $totalDays');
    } catch (e) {
      print('❌ Error updating challenge progress: $e');
    }
  }

  Future<void> _updateChallengeProgressForHabit(
    String userId,
    String habitId,
  ) async {
    try {
      if (!await isOnline()) {
        return;
      }

      final habit = await client
          .from('habits')
          .select('challenge_id')
          .eq('id', habitId)
          .eq('user_id', userId)
          .maybeSingle();

      if (habit == null) {
        return;
      }

      final challengeId = habit['challenge_id'];
      if (challengeId == null) {
        return;
      }

      await updateChallengeProgress(userId, challengeId);
    } catch (e) {
      // ignore
    }
  }

  // ==================== XP Management ====================

  Future<void> addXP(String userId, int amount) async {
    try {
      final response = await client
          .from('user_progress')
          .select('total_xp')
          .eq('user_id', userId);

      if (response.isNotEmpty) {
        final currentXP = response[0]['total_xp'] ?? 0;
        final newXP = currentXP + amount;
        await client
            .from('user_progress')
            .update({'total_xp': newXP}).eq('user_id', userId);
      } else {
        await client.from('user_progress').insert({
          'user_id': userId,
          'total_xp': amount,
        });
      }

      try {
        final profileResponse = await client
            .from('profiles')
            .select('total_xp')
            .eq('user_id', userId);

        if (profileResponse.isNotEmpty) {
          final currentXP = profileResponse[0]['total_xp'] ?? 0;
          await client
              .from('profiles')
              .update({'total_xp': currentXP + amount}).eq('user_id', userId);
        } else {
          await client.from('profiles').insert({
            'user_id': userId,
            'total_xp': amount,
          });
        }
      } catch (e) {
        // ignore
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<int> getUserXP(String userId) async {
    try {
      final response = await client
          .from('user_progress')
          .select('total_xp')
          .eq('user_id', userId);

      if (response.isNotEmpty) {
        return response[0]['total_xp'] ?? 0;
      }

      final profileResponse = await client
          .from('profiles')
          .select('total_xp')
          .eq('user_id', userId);

      if (profileResponse.isNotEmpty) {
        return profileResponse[0]['total_xp'] ?? 0;
      }

      return 0;
    } catch (e) {
      return 0;
    }
  }

  // lib/services/supabase_service.dart

  Future<void> removeXP(String userId, int amount) async {
    try {
      print('🗑️ Removing $amount XP from user: $userId');

      // ✅ 1. به‌روزرسانی در user_progress
      final response = await client
          .from('user_progress')
          .select('id, total_xp')
          .eq('user_id', userId);

      if (response.isNotEmpty) {
        final currentXP = response[0]['total_xp'] ?? 0;
        final newXP = (currentXP - amount).clamp(0, double.infinity).toInt();

        print('📊 Current XP: $currentXP, New XP: $newXP');

        await client
            .from('user_progress')
            .update({'total_xp': newXP}).eq('id', response[0]['id']);
      } else {
        await client.from('user_progress').insert({
          'user_id': userId,
          'total_xp': 0,
        });
      }

      // ✅ 2. به‌روزرسانی در profiles
      try {
        final profileResponse = await client
            .from('profiles')
            .select('total_xp')
            .eq('user_id', userId);

        if (profileResponse.isNotEmpty) {
          final currentXP = profileResponse[0]['total_xp'] ?? 0;
          final newXP = (currentXP - amount).clamp(0, double.infinity).toInt();

          print('📊 Profile XP: $currentXP -> $newXP');

          await client
              .from('profiles')
              .update({'total_xp': newXP}).eq('user_id', userId);
        }
      } catch (e) {
        print('⚠️ Error updating profile XP: $e');
      }

      print('✅ XP removed successfully');
    } catch (e) {
      print('❌ Error removing XP: $e');
      rethrow;
    }
  }

  // ==================== Challenges ====================

// ✅ اصلاح متد getChallenges - حذف فیلتر تاریخ
  Future<List<Map<String, dynamic>>> getChallenges() async {
    if (!await isOnline()) {
      return [];
    }

    try {
      // ✅ حذف شرط تاریخ - فقط چالش‌های فعال را بگیر
      final response = await client
          .from('challenges')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return response;
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getExpiredChallenges() async {
    try {
      final now = DateTime.now().toIso8601String();
      final response = await client
          .from('challenges')
          .select()
          .eq('is_active', true)
          .lt('registration_end_date', now)
          .order('created_at', ascending: false);

      return response;
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getChallengeById(String challengeId) async {
    try {
      final response = await client
          .from('challenges')
          .select()
          .eq('id', challengeId)
          .single();

      return response;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getChallengeHabits(
    String challengeId,
  ) async {
    try {
      final response = await client
          .from('challenge_habits')
          .select()
          .eq('challenge_id', challengeId);

      return response;
    } catch (e) {
      return [];
    }
  }

// lib/services/supabase_service.dart

  Future<void> addChallengeHabitToUser(
    String userId,
    Map<String, dynamic> challenge,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final duration = challenge['challenge_duration'] as int;
      final xpPerDay = (challenge['xp_reward'] as int) ~/ duration;
      final challengeId = challenge['id'];

      // دریافت عادت‌های چالش
      final challengeHabits = await getChallengeHabits(challengeId);

      // ✅ فقط یک عادت برای کل چالش ایجاد کن
      List<String> subHabits = [];
      for (var habit in challengeHabits) {
        subHabits.add(habit['title']);
      }

      // ✅ عنوان عادت با شمارش روزهای باقیمانده
      final remainingDays = endDate.difference(startDate).inDays + 1;
      final titleSuffix = remainingDays > 0 ? ' (${remainingDays} روز)' : '';

      final newHabit = Habit(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        title: '🏆 ${challenge['title']}$titleSuffix',
        description: '${challenge['description']} - $duration روز',
        subHabits: subHabits,
        completedSubHabits: [],
        iconName: 'emoji_events',
        iconColor: 0xFFFFA500,
        backgroundColor: 0xFFF5F5F5,
        frequencyType: 'daily',
        dailyIntervalDays: [1],
        weeklyDays: null,
        weeklyIntervalWeeks: 1,
        monthlyDays: null,
        monthlyIntervalMonths: 1,
        timeOfDay: 'morning',
        reminders: [],
        xpReward: xpPerDay > 0 ? xpPerDay : 5,
        currentStreak: 0,
        bestStreak: 0,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        groupId: null,
        startDate: startDate,
        endDate: endDate,
        challengeId: challengeId,
        questId: null,
        // ✅ اضافه کردن فیلدهای سطح از challenge
        fullDescription: challenge['full_description'] ?? 'انجام کامل چالش',
        halfDescription: challenge['half_description'] ?? 'انجام نیمی از چالش',
        basicDescription: challenge['basic_description'] ?? 'انجام حداقل چالش',
        targetValue: challenge['target_value'],
      );

      await createHabit(newHabit);
      print('✅ Challenge habit created: ${newHabit.title}');
      print('📅 Start: ${newHabit.startDate}');
      print('📅 End: ${newHabit.endDate}');
    } catch (e) {
      print('❌ Error adding challenge habit: $e');
      rethrow;
    }
  }

// lib/services/supabase_service.dart

  Future<void> completeChallengeDay({
    required String userId,
    required String challengeId,
    required DateTime date,
  }) async {
    try {
      final dateStr = date.toIso8601String().split('T').first;

      // ✅ 1. بررسی اینکه آیا تاریخ در محدوده چالش است
      final userChallenge = await client
          .from('user_challenges')
          .select('challenge_start_date, challenge_end_date')
          .eq('user_id', userId)
          .eq('challenge_id', challengeId)
          .maybeSingle();

      if (userChallenge != null) {
        final startDate = DateTime.parse(userChallenge['challenge_start_date']);
        final endDate = DateTime.parse(userChallenge['challenge_end_date']);

        final checkDate = DateTime(date.year, date.month, date.day);

        // اگر تاریخ خارج از محدوده است، ثبت نشود
        if (checkDate.isBefore(startDate) || checkDate.isAfter(endDate)) {
          print('⚠️ Date $dateStr is outside challenge range');
          return;
        }

        // اگر تاریخ آینده است، ثبت نشود
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        if (checkDate.isAfter(today)) {
          print('⚠️ Date $dateStr is in the future');
          return;
        }
      }

      // 2. حذف رکورد قبلی (اگر وجود دارد)
      await client
          .from('challenge_completions')
          .delete()
          .eq('user_id', userId)
          .eq('challenge_id', challengeId)
          .eq('date', dateStr);

      // 3. درج رکورد جدید
      await client.from('challenge_completions').insert({
        'user_id': userId,
        'challenge_id': challengeId,
        'date': dateStr,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 4. ✅ به‌روزرسانی progress در user_challenges با تعداد واقعی
      final completionsCount = await client
          .from('challenge_completions')
          .select('date')
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);

      // فقط روزهایی که در محدوده چالش هستند و از امروز گذشته نیستند
      int validCompletions = 0;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (userChallenge != null) {
        final startDate = DateTime.parse(userChallenge['challenge_start_date']);
        final endDate = DateTime.parse(userChallenge['challenge_end_date']);

        for (var completion in completionsCount) {
          final compDate = DateTime.parse(completion['date'] as String);
          final compDateOnly =
              DateTime(compDate.year, compDate.month, compDate.day);

          if (compDateOnly.isBefore(startDate) ||
              compDateOnly.isAfter(endDate)) {
            continue;
          }
          if (compDateOnly.isAfter(today)) {
            continue;
          }
          validCompletions++;
        }
      }

      await client
          .from('user_challenges')
          .update({
            'progress': validCompletions,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);

      print(
          '✅ Challenge day recorded: $challengeId - $dateStr (progress: $validCompletions)');
    } catch (e) {
      print('❌ Error completing challenge day: $e');
    }
  }

  // ✅ دریافت چالش‌های فعال یک عادت
  Future<List<Map<String, dynamic>>> getActiveChallengesForHabit(
    String userId,
    String habitId,
  ) async {
    try {
      // این متد باید چالش‌هایی که این عادت در آنها وجود دارد را پیدا کند
      // بستگی به ساختار دیتابیس شما دارد
      return [];
    } catch (e) {
      print('❌ Error getting active challenges for habit: $e');
      return [];
    }
  }

// lib/services/supabase_service.dart

  Future<void> leaveChallenge(String userId, String challengeId) async {
    try {
      print('🗑️ Leaving challenge: $challengeId for user: $userId');

      // 1. دریافت رکورد user_challenge
      final response = await client
          .from('user_challenges')
          .select()
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);

      if (response.isNotEmpty) {
        // 2. حذف از user_challenges
        await client
            .from('user_challenges')
            .delete()
            .eq('id', response[0]['id']);

        print('✅ User challenge removed from database');
      }

      // 3. ✅ حذف همه رکوردهای challenge_completions
      await client
          .from('challenge_completions')
          .delete()
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);

      print('✅ Challenge completions removed from database');

      // 4. ✅ حذف عادت‌های مرتبط با چالش
      final habits = await client
          .from('habits')
          .select('id')
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);

      if (habits.isNotEmpty) {
        final habitIds = habits.map((h) => h['id'] as String).toList();

        // حذف تکمیل‌های عادت‌ها
        await client
            .from('habit_completions')
            .delete()
            .eq('user_id', userId)
            .inFilter('habit_id', habitIds);

        // حذف خود عادت‌ها
        await client
            .from('habits')
            .delete()
            .eq('user_id', userId)
            .inFilter('id', habitIds);

        print('✅ ${habitIds.length} challenge habits removed');
      }

      // 5. ✅ حذف از LocalStorage
      try {
        final localStorage = LocalStorageService();

        // حذف عادت‌های چالش
        final localHabits = localStorage.getHabits();
        final updatedHabits =
            localHabits.where((h) => h.challengeId != challengeId).toList();
        await localStorage.saveHabits(updatedHabits);

        // حذف چالش کاربر
        final userChallenges = localStorage.getUserChallenges();
        final updatedUserChallenges =
            userChallenges.where((c) => c['id'] != challengeId).toList();
        await localStorage.saveUserChallenges(updatedUserChallenges);

        print('✅ Removed from LocalStorage');
      } catch (e) {
        print('⚠️ Error removing from LocalStorage: $e');
      }

      print('✅ User left challenge completely: $challengeId');
    } catch (e) {
      print('❌ Error leaving challenge: $e');
      rethrow;
    }
  }

  // ✅ حذف عادت‌های چالش از دیتابیس و localStorage
  Future<void> removeChallengeHabitByChallengeId(
    String userId,
    String challengeId,
  ) async {
    try {
      // 1. دریافت عادت‌های چالش از دیتابیس
      final habits = await client
          .from('habits')
          .select('id')
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);

      if (habits.isNotEmpty) {
        // 2. حذف تکمیل‌های عادت‌ها
        for (var habit in habits) {
          await client
              .from('habit_completions')
              .delete()
              .eq('habit_id', habit['id'])
              .eq('user_id', userId);
        }

        // 3. حذف خود عادت‌ها
        final habitIds = habits.map((h) => h['id'] as String).toList();
        await client
            .from('habits')
            .delete()
            .eq('user_id', userId)
            .inFilter('id', habitIds);

        print('🗑️ Deleted ${habitIds.length} challenge habits');
      }
    } catch (e) {
      print('❌ Error removing challenge habits: $e');
      rethrow;
    }
  }

  Future<int> getRealParticipantsCount(String challengeId) async {
    try {
      final response = await client
          .from('user_challenges')
          .select('id')
          .eq('challenge_id', challengeId);

      return response.length;
    } catch (e) {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getUserChallenges(String userId) async {
    if (!await isOnline()) {
      print('⚠️ Offline - skipping getUserChallenges');
      return [];
    }

    try {
      // ✅ همه چالش‌های کاربر رو بگیر (حتی اونایی که is_active = false)
      final response =
          await client.from('user_challenges').select().eq('user_id', userId);

      List<Map<String, dynamic>> result = [];
      for (var item in response) {
        final challengeId = item['challenge_id'];
        if (challengeId != null) {
          final challenge = await getChallengeById(challengeId);
          if (challenge != null) {
            final data = Map<String, dynamic>.from(challenge);
            data['userProgressId'] = item['id'];
            data['progress'] = item['progress'] ?? 0;
            data['isCompleted'] = item['is_completed'] ?? false;
            data['status'] = item['status'] ?? 'active';
            data['is_active'] = item['is_active'] ?? true;
            data['challenge_start_date'] = item['challenge_start_date'];
            data['challenge_end_date'] = item['challenge_end_date'];
            data['user_challenge_id'] = item['id'];
            result.add(data);
          }
        }
      }

      print('📊 Found ${result.length} user challenges');
      return result;
    } catch (e) {
      print('❌ Error getting user challenges: $e');
      return [];
    }
  }

// lib/services/supabase_service.dart

  Future<Map<String, int>> getUserChallengeProgressDetails(
    String userId,
    String challengeId,
  ) async {
    try {
      // 1. دریافت اطلاعات چالش
      final challengeResponse = await client
          .from('challenges')
          .select('challenge_duration')
          .eq('id', challengeId)
          .maybeSingle();

      if (challengeResponse == null) {
        return {'completedDays': 0, 'totalDays': 0};
      }

      final totalDays = challengeResponse['challenge_duration'] as int? ?? 7;

      // 2. دریافت user_challenge برای این کاربر
      final userChallenge = await client
          .from('user_challenges')
          .select(
            'challenge_start_date, challenge_end_date, progress, is_completed, status',
          )
          .eq('user_id', userId)
          .eq('challenge_id', challengeId)
          .maybeSingle();

      if (userChallenge == null) {
        return {'completedDays': 0, 'totalDays': totalDays};
      }

      // 3. اگر چالش کامل شده، progress رو برگردون
      if (userChallenge['is_completed'] == true) {
        return {
          'completedDays': userChallenge['progress'] as int? ?? totalDays,
          'totalDays': totalDays,
        };
      }

      // 4. دریافت تاریخ‌های تکمیل شده
      final completions = await client
          .from('challenge_completions')
          .select('date')
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);

      if (completions.isEmpty) {
        return {'completedDays': 0, 'totalDays': totalDays};
      }

      // 5. محاسبه روزهای تکمیل شده - فقط روزهای معتبر
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // دریافت محدوده چالش
      final startDate = DateTime.parse(userChallenge['challenge_start_date']);
      final start = DateTime(startDate.year, startDate.month, startDate.day);

      final endDate = DateTime.parse(userChallenge['challenge_end_date']);
      final end = DateTime(endDate.year, endDate.month, endDate.day);

      // ✅ فقط روزهایی که در محدوده چالش هستند و از امروز گذشته نیستند
      int completedDays = 0;
      final Set<String> uniqueDates = {};

      for (var completion in completions) {
        final completionDate = DateTime.parse(completion['date'] as String);
        final compDate = DateTime(
          completionDate.year,
          completionDate.month,
          completionDate.day,
        );

        // بررسی محدوده
        if (compDate.isBefore(start) || compDate.isAfter(end)) {
          continue;
        }

        // بررسی اینکه تاریخ آینده نباشد
        if (compDate.isAfter(today)) {
          continue;
        }

        // حذف تکراری‌ها
        final dateKey = compDate.toIso8601String().split('T').first;
        if (!uniqueDates.contains(dateKey)) {
          uniqueDates.add(dateKey);
          completedDays++;
        }
      }

      // اطمینان از اینکه از totalDays بیشتر نشود
      if (completedDays > totalDays) {
        completedDays = totalDays;
      }

      print('📊 Challenge progress: $completedDays / $totalDays days');
      print(
          '📅 Total completions: ${completions.length}, Unique: ${uniqueDates.length}');

      return {'completedDays': completedDays, 'totalDays': totalDays};
    } catch (e) {
      print('❌ Error getting challenge progress: $e');
      return {'completedDays': 0, 'totalDays': 0};
    }
  }

  // ✅ بررسی چالش‌های منقضی شده
  Future<void> checkExpiredChallenges(String userId) async {
    try {
      final now = DateTime.now();

      // دریافت چالش‌های فعال کاربر
      final userChallenges = await client
          .from('user_challenges')
          .select('*')
          .eq('user_id', userId)
          .eq('is_active', true)
          .eq('is_completed', false);

      if (userChallenges.isEmpty) return;

      for (var userChallenge in userChallenges) {
        final challengeId = userChallenge['challenge_id'];

        // دریافت اطلاعات چالش
        final challengeResponse = await client
            .from('challenges')
            .select('*')
            .eq('id', challengeId)
            .maybeSingle();

        if (challengeResponse == null) continue;

        final challenge = challengeResponse;

        // بررسی تاریخ پایان ثبت‌نام
        final registrationEnd = challenge['registration_end_date'] != null
            ? DateTime.parse(challenge['registration_end_date'])
            : null;

        // بررسی تاریخ پایان چالش
        final challengeEnd = userChallenge['challenge_end_date'] != null
            ? DateTime.parse(userChallenge['challenge_end_date'])
            : null;

        // اگر تاریخ ثبت‌نام گذشته باشد
        if (registrationEnd != null && registrationEnd.isBefore(now)) {
          await client.from('user_challenges').update({
            'is_active': false,
            'status': 'expired',
            'updated_at': now.toIso8601String(),
          }).eq('id', userChallenge['id']);

          print('⏰ Challenge expired: ${challenge['title']}');
        }

        // اگر تاریخ پایان چالش گذشته باشد و کامل نشده
        if (challengeEnd != null &&
            challengeEnd.isBefore(now) &&
            userChallenge['is_completed'] == false) {
          await client.from('user_challenges').update({
            'is_active': false,
            'status': 'failed',
            'completed_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          }).eq('id', userChallenge['id']);

          print('⏰ Challenge ended without completion: ${challenge['title']}');
        }
      }
    } catch (e) {
      print('❌ Error checking expired challenges: $e');
    }
  }
  // lib/services/supabase_service.dart

  // ✅ حذف تکمیل روزانه چالش
  Future<void> removeChallengeDay({
    required String userId,
    required String challengeId,
    required DateTime date,
  }) async {
    try {
      // 1. بررسی اینکه آیا کاربر این چالش رو دارد
      final userChallenge = await client
          .from('user_challenges')
          .select('id, is_active, is_completed')
          .eq('user_id', userId)
          .eq('challenge_id', challengeId)
          .eq('is_active', true)
          .eq('is_completed', false)
          .maybeSingle();

      if (userChallenge == null) {
        print('⚠️ User is not active in this challenge: $challengeId');
        return;
      }

      // 2. حذف تکمیل روزانه
      final dateStr = date.toIso8601String().split('T').first;
      await client
          .from('challenge_completions')
          .delete()
          .eq('user_id', userId)
          .eq('challenge_id', challengeId)
          .eq('date', dateStr);

      // 3. به‌روزرسانی progress در user_challenges
      final completionsCount = await client
          .from('challenge_completions')
          .select('date')
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);

      final completedDays = completionsCount.length;

      await client.from('user_challenges').update({
        'progress': completedDays,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userChallenge['id']);

      print('✅ Challenge day removed: $challengeId - Now $completedDays days');
    } catch (e) {
      print('❌ Error removing challenge day: $e');
    }
  }

  // ✅ بررسی و بروزرسانی وضعیت چالش‌های کاربر
  Future<void> checkAndUpdateUserChallenges(String userId) async {
    try {
      final userChallenges = await client
          .from('user_challenges')
          .select('*')
          .eq('user_id', userId)
          .eq('is_active', true)
          .eq('is_completed', false);

      if (userChallenges.isEmpty) return;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      bool needRefresh = false;

      for (var userChallenge in userChallenges) {
        final challengeId = userChallenge['challenge_id'];

        final challengeResponse = await client
            .from('challenges')
            .select('*')
            .eq('id', challengeId)
            .maybeSingle();

        if (challengeResponse == null) continue;

        final challenge = challengeResponse;
        final userChallengeId = userChallenge['id'];
        final challengeDuration = challenge['challenge_duration'] as int? ?? 7;

        // تاریخ شروع چالش
        DateTime startDate;
        if (userChallenge['challenge_start_date'] != null) {
          startDate = DateTime.parse(userChallenge['challenge_start_date']);
        } else if (userChallenge['joined_at'] != null) {
          startDate = DateTime.parse(userChallenge['joined_at']);
        } else {
          startDate = today;
        }

        final start = DateTime(startDate.year, startDate.month, startDate.day);

        // محاسبه روزهای گذشته از شروع چالش
        final daysSinceStart = today.difference(start).inDays + 1;

        // اگر کاربر تمام روزهای چالش را انجام داده باشد
        if (daysSinceStart >= challengeDuration) {
          final completedDays = await _getUserCompletedDaysForChallenge(
            userId,
            challengeId,
          );

          if (completedDays >= challengeDuration) {
            // ✅ چالش با موفقیت کامل شده
            await _completeChallenge(userId, userChallengeId, challenge);
            needRefresh = true;
          } else {
            // ❌ چالش ناموفق (همه روزها رو انجام نداده)
            await _failChallenge(userId, userChallengeId, challenge);
            needRefresh = true;
          }
          continue;
        }

        // بررسی آخرین روز انجام شده
        final lastCompletedDate = await _getLastCompletedDate(
          userId,
          challengeId,
        );

        if (lastCompletedDate != null) {
          final lastDate = DateTime(
            lastCompletedDate.year,
            lastCompletedDate.month,
            lastCompletedDate.day,
          );
          final daysGap = today.difference(lastDate).inDays;

          // اگر بیش از 1 روز از آخرین انجام گذشته باشد
          if (daysGap > 1) {
            // ❌ استریک شکسته شده، چالش ناموفق
            await _failChallenge(userId, userChallengeId, challenge);
            needRefresh = true;
          }
        }
      }

      if (needRefresh) {
        await _refreshUserChallenges(userId);
      }
    } catch (e) {
      print('❌ Error checking user challenges: $e');
    }
  }

  // ✅ دریافت آخرین روز تکمیل شده
  Future<DateTime?> _getLastCompletedDate(
    String userId,
    String challengeId,
  ) async {
    try {
      final completions = await client
          .from('challenge_completions')
          .select('date')
          .eq('user_id', userId)
          .eq('challenge_id', challengeId)
          .order('date', ascending: false)
          .limit(1);

      if (completions.isNotEmpty) {
        return DateTime.parse(completions.first['date'] as String);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ✅ دریافت تعداد روزهای تکمیل شده برای یک چالش
  Future<int> _getUserCompletedDaysForChallenge(
    String userId,
    String challengeId,
  ) async {
    try {
      final completions = await client
          .from('challenge_completions')
          .select('date')
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);

      return completions.length;
    } catch (e) {
      return 0;
    }
  }

// lib/services/supabase_service.dart

  Future<void> _failChallenge(
    String userId,
    String userChallengeId,
    Map<String, dynamic> challenge,
  ) async {
    final now = DateTime.now();
    final challengeId = challenge['id'];

    // 1. حذف کامل از user_challenges
    await client.from('user_challenges').delete().eq('id', userChallengeId);

    // 2. ✅ حذف رکوردهای challenge_completions
    await client
        .from('challenge_completions')
        .delete()
        .eq('user_id', userId)
        .eq('challenge_id', challengeId);

    print('✅ Challenge completions cleared after failure');

    // 3. حذف عادت‌های چالش
    try {
      final habits = await client
          .from('habits')
          .select('id')
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);

      if (habits.isNotEmpty) {
        final habitIds = habits.map((h) => h['id'] as String).toList();

        await client
            .from('habit_completions')
            .delete()
            .eq('user_id', userId)
            .inFilter('habit_id', habitIds);

        await client
            .from('habits')
            .delete()
            .eq('user_id', userId)
            .inFilter('id', habitIds);
      }
    } catch (e) {
      print('⚠️ Error removing challenge habits: $e');
    }

    // 4. حذف از LocalStorage
    try {
      final localStorage = LocalStorageService();

      final localHabits = localStorage.getHabits();
      final updatedHabits =
          localHabits.where((h) => h.challengeId != challengeId).toList();
      await localStorage.saveHabits(updatedHabits);

      final userChallenges = localStorage.getUserChallenges();
      final updatedUserChallenges =
          userChallenges.where((c) => c['id'] != challengeId).toList();
      await localStorage.saveUserChallenges(updatedUserChallenges);
    } catch (e) {
      print('⚠️ Error removing from local storage: $e');
    }

    print('✅ Challenge failed and removed: ${challenge['title']}');
  }

// ✅ متد جدید برای بررسی روزانه استریک چالش‌ها
  Future<void> checkUserChallengeStreak(String userId) async {
    try {
      final userChallenges = await client
          .from('user_challenges')
          .select('*')
          .eq('user_id', userId)
          .eq('is_active', true)
          .eq('is_completed', false);

      if (userChallenges.isEmpty) return;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      for (var userChallenge in userChallenges) {
        final challengeId = userChallenge['challenge_id'];

        // دریافت اطلاعات چالش
        final challenge = await getChallengeById(challengeId);
        if (challenge == null) continue;

        // دریافت آخرین روز تکمیل شده
        final lastCompleted = await _getLastCompletedDate(userId, challengeId);

        if (lastCompleted != null) {
          final lastDate = DateTime(
            lastCompleted.year,
            lastCompleted.month,
            lastCompleted.day,
          );
          final daysGap = today.difference(lastDate).inDays;

          // ✅ اگر بیش از 1 روز از آخرین انجام گذشته باشد → شکست
          if (daysGap > 1) {
            print(
                '❌ Streak broken for challenge: $challengeId (gap: $daysGap days)');
            await _failChallenge(userId, userChallenge['id'], challenge);

            // ✅ بعد از شکست، از حلقه خارج شو (چالش غیرفعال شده)
            continue;
          }
        }

        // ✅ بررسی تاریخ پایان چالش
        if (userChallenge['challenge_end_date'] != null) {
          final endDate = DateTime.parse(userChallenge['challenge_end_date']);
          if (endDate.isBefore(now)) {
            // ✅ اگر تاریخ پایان گذشته، چک کن که کامل شده یا نه
            final completedDays = await _getUserCompletedDaysForChallenge(
              userId,
              challengeId,
            );
            final totalDays = challenge['challenge_duration'] as int? ?? 7;

            if (completedDays < totalDays) {
              print('❌ Challenge expired without completion: $challengeId');
              await _failChallenge(userId, userChallenge['id'], challenge);
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error checking user challenge streak: $e');
    }
  }

  // lib/services/supabase_service.dart

// ✅ متد جدید برای بررسی عادت‌های شکست خورده در پایان روز
  Future<void> checkFailedHabits(String userId) async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayStr = yesterday.toIso8601String().split('T').first;

      // دریافت تمام عادت‌های فعال کاربر
      final habits = await getHabits(userId);
      final activeHabits = habits.where((h) => h.isActive).toList();

      for (var habit in activeHabits) {
        // بررسی اینکه آیا عادت باید در دیروز انجام می‌شده
        if (!habit.shouldDoOnDate(yesterday)) continue;

        // بررسی اینکه آیا عادت در دیروز تکمیل شده
        final isCompleted = await isHabitCompletedOnDate(
          habit.id,
          userId,
          yesterday,
        );

        if (!isCompleted) {
          // ✅ اگر تکمیل نشده، به عنوان شکست خورده ثبت کن
          // اما فقط اگر چالش یا ماموریت نباشد
          if (habit.challengeId == null && habit.questId == null) {
            // ثبت در جدول habit_failures (اگر وجود دارد)
            // یا به‌روزرسانی استریک
            print('❌ Habit failed: ${habit.title} on $yesterdayStr');

            // به‌روزرسانی استریک کاربر
            await updateUserStreak(userId);
          }
        }
      }
    } catch (e) {
      print('❌ Error checking failed habits: $e');
    }
  }

// ✅ متد برای اجرای بررسی روزانه (در زمان بیدار شدن اپ)
  Future<void> runDailyCheck(String userId) async {
    try {
      // 1. بررسی چالش‌ها
      await checkUserChallengeStreak(userId);

      // 2. بررسی عادت‌های شکست خورده
      await checkFailedHabits(userId);

      // 3. به‌روزرسانی استریک
      await updateUserStreak(userId);

      print('✅ Daily check completed for user: $userId');
    } catch (e) {
      print('❌ Error in daily check: $e');
    }
  }

// ✅ اضافه کردن تایمر برای بررسی دوره‌ای
  void startStreakCheckTimer(String userId) {
    // هر 6 ساعت یکبار بررسی کن
    Timer.periodic(const Duration(hours: 6), (timer) {
      checkUserChallengeStreak(userId);
    });
  }

// lib/services/supabase_service.dart

  Future<void> joinChallenge(String userId, String challengeId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // ✅ 1. ابتدا همه رکوردهای قبلی را پاک کن (برای شروع تمیز)
      try {
        // حذف از user_challenges
        await client
            .from('user_challenges')
            .delete()
            .eq('user_id', userId)
            .eq('challenge_id', challengeId);

        // حذف از challenge_completions
        await client
            .from('challenge_completions')
            .delete()
            .eq('user_id', userId)
            .eq('challenge_id', challengeId);

        print('🗑️ Cleaned up previous records for challenge: $challengeId');
      } catch (e) {
        print('⚠️ Cleanup error (may not have existing records): $e');
      }

      // دریافت اطلاعات چالش
      final challengeResponse = await client
          .from('challenges')
          .select()
          .eq('id', challengeId)
          .maybeSingle();

      if (challengeResponse == null) {
        throw Exception('چالش یافت نشد');
      }

      final duration = challengeResponse['challenge_duration'] as int? ?? 7;
      final endDate = today.add(Duration(days: duration - 1));

      // ثبت‌نام جدید در user_challenges
      await client.from('user_challenges').insert({
        'user_id': userId,
        'challenge_id': challengeId,
        'joined_at': now.toIso8601String(),
        'challenge_start_date': today.toIso8601String(),
        'challenge_end_date': endDate.toIso8601String(),
        'progress': 0,
        'is_completed': false,
        'is_active': true,
        'status': 'active',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // ✅ حذف عادت‌های قبلی چالش (اگر وجود داشته باشند)
      try {
        final existingHabits = await client
            .from('habits')
            .select('id')
            .eq('user_id', userId)
            .eq('challenge_id', challengeId);

        if (existingHabits.isNotEmpty) {
          final habitIds =
              existingHabits.map((h) => h['id'] as String).toList();
          await client
              .from('habits')
              .delete()
              .eq('user_id', userId)
              .inFilter('id', habitIds);
          print('🗑️ Removed ${habitIds.length} existing challenge habits');
        }
      } catch (e) {
        print('⚠️ Error removing existing habits: $e');
      }

      // اضافه کردن عادت‌های چالش به کاربر
      await addChallengeHabitToUser(
        userId,
        challengeResponse,
        today,
        endDate,
      );

      print('✅ User joined challenge: $challengeId');
      print('📅 Start date: $today');
      print('📅 End date: $endDate');
      print('📅 Duration: $duration days');
    } catch (e) {
      print('❌ Error joining challenge: $e');
      rethrow;
    }
  }

// ✅ متد جدید برای ثبت مدال چالش
  Future<void> _addChallengeBadge(
      String userId, Map<String, dynamic> challenge) async {
    try {
      final badgeName = '🏆 ${challenge['title']}';
      final badgeIcon = '🏆';

      // ✅ بررسی وجود مدال تکراری
      final existing = await client
          .from('user_badges')
          .select()
          .eq('user_id', userId)
          .eq('badge_name', badgeName)
          .maybeSingle();

      if (existing != null) {
        print('📊 Badge already exists: $badgeName');
        return;
      }

      // ✅ ثبت مدال جدید
      await client.from('user_badges').insert({
        'user_id': userId,
        'badge_name': badgeName,
        'badge_icon': badgeIcon,
        'badge_type': 'challenge',
        'challenge_id': challenge['id'],
        'earned_at': DateTime.now().toIso8601String(),
        'is_active': true,
      });

      print('✅ Challenge badge earned: $badgeName');
    } catch (e) {
      print('⚠️ Error adding challenge badge: $e');
    }
  }

// lib/services/supabase_service.dart

  Future<void> _completeChallenge(
    String userId,
    String userChallengeId,
    Map<String, dynamic> challenge,
  ) async {
    try {
      final now = DateTime.now();
      final challengeId = challenge['id'];
      final xpReward = challenge['xp_reward'] as int? ?? 50;
      final challengeDuration = challenge['challenge_duration'] as int? ?? 7;

      // 1. به‌روزرسانی وضعیت چالش
      await client.from('user_challenges').update({
        'is_completed': true,
        'is_active': false,
        'status': 'completed',
        'progress': challengeDuration,
        'completed_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      }).eq('id', userChallengeId);

      // 2. افزودن مدال چالش
      await _addChallengeBadge(userId, challenge);

      // 3. افزودن XP پاداش
      await addXP(userId, xpReward);

      // 4. حذف عادت‌های چالش
      final habits = await client
          .from('habits')
          .select('id')
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);

      if (habits.isNotEmpty) {
        final habitIds = habits.map((h) => h['id'] as String).toList();

        await client
            .from('habit_completions')
            .delete()
            .eq('user_id', userId)
            .inFilter('habit_id', habitIds);

        await client
            .from('habits')
            .delete()
            .eq('user_id', userId)
            .inFilter('id', habitIds);
      }

      // 5. ✅ حذف رکوردهای challenge_completions بعد از تکمیل
      await client
          .from('challenge_completions')
          .delete()
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);

      print('✅ Challenge completions cleared after completion');

      // 6. حذف از LocalStorage
      try {
        final localStorage = LocalStorageService();
        final localHabits = localStorage.getHabits();
        final updatedHabits =
            localHabits.where((h) => h.challengeId != challengeId).toList();
        await localStorage.saveHabits(updatedHabits);

        final userChallenges = localStorage.getUserChallenges();
        final updatedUserChallenges =
            userChallenges.where((c) => c['id'] != challengeId).toList();
        await localStorage.saveUserChallenges(updatedUserChallenges);
      } catch (e) {
        print('⚠️ Error removing from local storage: $e');
      }

      print('✅ Challenge completed successfully: ${challenge['title']}');
    } catch (e) {
      print('❌ Error completing challenge: $e');
      rethrow;
    }
  }

  // ✅ انصراف کاربر از چالش
  Future<void> leaveChallengeWithCleanup(
    String userId,
    String challengeId,
  ) async {
    try {
      // 1. حذف از user_challenges
      await client
          .from('user_challenges')
          .delete()
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);

      // 2. حذف تمام رکوردهای تکمیل برای این چالش
      await client
          .from('challenge_completions')
          .delete()
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);

      print('🗑️ User left challenge: $challengeId');
    } catch (e) {
      print('❌ Error leaving challenge: $e');
    }
  }

  // ✅ ریفرش داده‌های چالش‌های کاربر
  Future<void> _refreshUserChallenges(String userId) async {
    try {
      final userChallenges = await client
          .from('user_challenges')
          .select('*')
          .eq('user_id', userId);

      print('🔄 User challenges refreshed: ${userChallenges.length}');
    } catch (e) {
      print('❌ Error refreshing user challenges: $e');
    }
  }

  // ==================== Packages ====================

  Future<List<Package>> getPackages() async {
    if (!await isOnline()) {
      return [];
    }

    try {
      final response = await client
          .from('packages')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        return [];
      }

      return response.map((data) {
        return Package.fromMap(data, data['id']);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<UserPackage>> getUserPackages(String userId) async {
    try {
      final response = await client
          .from('user_packages')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true);

      return response
          .map((data) => UserPackage.fromMap(data, data['id']))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> activatePackage(String userId, String packageId) async {
    try {
      // 1. دریافت اطلاعات بسته
      final packageResponse =
          await client.from('packages').select().eq('id', packageId).single();

      final package = Package.fromMap(packageResponse, packageId);

      // 2. ثبت در user_packages
      final existing = await client
          .from('user_packages')
          .select()
          .eq('user_id', userId)
          .eq('package_id', packageId);

      if (existing.isNotEmpty) {
        await client.from('user_packages').update({
          'is_active': true,
          'removed_at': null,
          'added_at': DateTime.now().toIso8601String(),
        }).eq('id', existing[0]['id']);
      } else {
        await client.from('user_packages').insert({
          'user_id': userId,
          'package_id': packageId,
          'is_active': true,
          'added_at': DateTime.now().toIso8601String(),
        });
      }

      // 3. ✅ ایجاد عادت‌های بسته برای کاربر
      for (var packageHabit in package.habits) {
        final habit = packageHabit.toHabit(userId, packageId);
        await createHabit(habit);
      }

      // 4. اضافه کردن XP پاداش
      await addXP(userId, package.xpReward);

      // 5. ✅ ذخیره در LocalStorage
      try {
        final localStorage = LocalStorageService();
        final habits = await getHabits(userId);
        await localStorage.saveHabits(habits);
      } catch (e) {
        print('⚠️ Error saving to local storage: $e');
      }

      print('✅ Package activated: $packageId');
      print('📦 ${package.habits.length} habits created');
    } catch (e) {
      print('❌ Error activating package: $e');
      rethrow;
    }
  }

  Future<void> deactivatePackage(String userId, String packageId) async {
    try {
      // 1. غیرفعال کردن در user_packages
      await client
          .from('user_packages')
          .update({
            'is_active': false,
            'removed_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('package_id', packageId);

      // 2. دریافت اطلاعات بسته
      final packageResponse =
          await client.from('packages').select().eq('id', packageId).single();

      final package = Package.fromMap(packageResponse, packageId);

      // 3. ✅ حذف عادت‌های بسته از دیتابیس
      final habits = await getHabits(userId);
      for (var habit in habits) {
        // حذف عادت‌هایی که با بسته مرتبط هستند
        if (habit.title.startsWith('📦') &&
            package.habits.any((ph) => habit.title.contains(ph.title))) {
          await deleteHabit(habit.id);
        }
      }

      // 4. ✅ حذف از LocalStorage
      try {
        final localStorage = LocalStorageService();
        final localHabits = localStorage.getHabits();
        final updatedHabits = localHabits
            .where(
                (h) => !package.habits.any((ph) => h.title.contains(ph.title)))
            .toList();
        await localStorage.saveHabits(updatedHabits);
      } catch (e) {
        print('⚠️ Error removing from local storage: $e');
      }

      print('✅ Package deactivated: $packageId');
    } catch (e) {
      print('❌ Error deactivating package: $e');
      rethrow;
    }
  }

  Future<bool> isPackageActiveForUser(String userId, String packageId) async {
    try {
      final response = await client
          .from('user_packages')
          .select()
          .eq('user_id', userId)
          .eq('package_id', packageId)
          .eq('is_active', true);

      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<List<Package>> getActivePackagesForUser(String userId) async {
    try {
      final userPackagesResponse = await client
          .from('user_packages')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true);

      if (userPackagesResponse.isEmpty) return [];

      List<Package> packages = [];
      for (var up in userPackagesResponse) {
        final packageId = up['package_id'];
        final packageResponse =
            await client.from('packages').select().eq('id', packageId).single();

        packages.add(Package.fromMap(packageResponse, packageId));
      }

      return packages;
    } catch (e) {
      return [];
    }
  }

  // ==================== User Progress ====================

  Future<void> createUserProgress(String userId) async {
    try {
      final existing =
          await client.from('user_progress').select('id').eq('user_id', userId);

      if (existing.isEmpty) {
        await client.from('user_progress').insert({
          'user_id': userId,
          'total_xp': 0,
          'weekly_xp': 0,
          'monthly_xp': 0,
        });
      }
    } catch (e) {
      try {
        final profileExists = await client
            .from('profiles')
            .select('user_id')
            .eq('user_id', userId);

        if (profileExists.isEmpty) {
          await client.from('profiles').insert({
            'user_id': userId,
            'total_xp': 0,
          });
        }
      } catch (e2) {
        // ignore
      }
    }
  }

  // ==================== Quests ====================

  Future<List<Quest>> getQuests() async {
    if (!await isOnline()) {
      return [];
    }

    try {
      final response = await client
          .from('quests')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return response.map((data) => Quest.fromMap(data, data['id'])).toList();
    } catch (e) {
      return [];
    }
  }

// lib/services/supabase_service.dart

  Future<List<UserQuest>> getUserQuests(String userId) async {
    try {
      print('📊 getUserQuests called for userId: $userId');

      final response =
          await client.from('user_quests').select().eq('user_id', userId);

      print('📊 getUserQuests response count: ${response.length}');

      final result =
          response.map((data) => UserQuest.fromMap(data, data['id'])).toList();

      for (var uq in result) {
        print(
            '   - Quest ID: ${uq.questId}, isActive: ${uq.isActive}, isCompleted: ${uq.isCompleted}, progress: ${uq.progress}');
      }

      return result;
    } catch (e) {
      print('❌ Error getting user quests: $e');
      return [];
    }
  }

// lib/services/supabase_service.dart

  Future<void> startQuest(String userId, Quest quest) async {
    try {
      // ✅ 1. بررسی وجود ماموریت قبلی
      final existing = await client
          .from('user_quests')
          .select()
          .eq('user_id', userId)
          .eq('quest_id', quest.id);

      if (existing.isNotEmpty) {
        if (existing.first['is_completed'] == true) {
          throw Exception('شما قبلاً این ماموریت را تکمیل کرده‌اید! 🏆');
        }
        throw Exception('شما قبلاً این ماموریت را شروع کرده‌اید!');
      }

      // ✅ تاریخ امروز (بدون ساعت)
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // ✅ 2. ایجاد عادت ماموریت با فیلدهای سطح
      final habit = Habit(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        title: '🎯 ${quest.title} (0/${quest.targetCount})',
        description: quest.description,
        subHabits: [],
        completedSubHabits: [],
        iconName: quest.icon,
        iconColor: _parseColor(quest.color),
        backgroundColor: 0xFFF5F5F5,
        frequencyType: 'daily',
        dailyIntervalDays: [1],
        weeklyDays: null,
        weeklyIntervalWeeks: 1,
        monthlyDays: null,
        monthlyIntervalMonths: 1,
        timeOfDay: 'morning',
        reminders: [],
        xpReward: 5,
        currentStreak: 0,
        bestStreak: 0,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        groupId: null,
        startDate: today,
        endDate: null, // ✅ بدون تاریخ پایان (بی‌نهایت)
        challengeId: null,
        questId: quest.id,
        // ✅ اضافه کردن فیلدهای سطح از Quest
        fullDescription: quest.fullDescription ?? 'انجام کامل ماموریت',
        halfDescription: quest.halfDescription ?? 'انجام نیمی از ماموریت',
        basicDescription: quest.basicDescription ?? 'انجام حداقل ماموریت',
        targetValue: quest.targetValue ?? '${quest.targetCount} روز',
      );

      // ✅ 3. ذخیره عادت در دیتابیس
      await createHabit(habit);
      print('✅ Habit created for quest: ${habit.title}');
      print('📊 Full: ${habit.fullDescription}');
      print('📊 Half: ${habit.halfDescription}');
      print('📊 Basic: ${habit.basicDescription}');
      print('📊 Target: ${habit.targetValue}');

      // ✅ 4. ذخیره در LocalStorage
      try {
        final localStorage = LocalStorageService();
        await localStorage.saveHabit(habit);
        print('✅ Habit saved to local storage');
      } catch (e) {
        print('⚠️ Error saving habit to local storage: $e');
      }

      // ✅ 5. ثبت در user_quests
      await client.from('user_quests').insert({
        'user_id': userId,
        'quest_id': quest.id,
        'habit_id': habit.id,
        'progress': 0,
        'is_completed': false,
        'started_at': today.toIso8601String(),
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      });

      print('✅ User quest started: ${quest.title}');
    } catch (e) {
      print('❌ Error starting quest: $e');
      rethrow;
    }
  }

  int _parseColor(String colorStr) {
    try {
      if (colorStr.startsWith('#')) {
        return int.parse('FF${colorStr.substring(1)}', radix: 16);
      }
      return 0xFF4A90E2;
    } catch (e) {
      return 0xFF4A90E2;
    }
  }

// lib/services/supabase_service.dart

  Future<Quest?> updateQuestProgress(String userId, String habitId) async {
    try {
      print('📊 ===== updateQuestProgress START =====');
      print('📊 userId: $userId');
      print('📊 habitId: $habitId');

      // ✅ 1. دریافت عادت
      final habitCheck = await client
          .from('habits')
          .select()
          .eq('id', habitId)
          .eq('user_id', userId)
          .maybeSingle();

      if (habitCheck == null) {
        print('⚠️ Habit not found: $habitId');
        return null;
      }

      print('📊 Habit found: ${habitCheck['title']}');
      print('📊 Quest ID from habit: ${habitCheck['quest_id']}');

      // ✅ 2. دریافت user_quest
      var userQuestResponse = await client
          .from('user_quests')
          .select()
          .eq('user_id', userId)
          .eq('habit_id', habitId)
          .eq('is_active', true);

      if (userQuestResponse.isEmpty) {
        final questId = habitCheck['quest_id'];
        if (questId == null) {
          print('⚠️ No quest_id found for habit: $habitId');
          return null;
        }

        print('📊 Looking for user_quest with quest_id: $questId');
        userQuestResponse = await client
            .from('user_quests')
            .select()
            .eq('user_id', userId)
            .eq('quest_id', questId)
            .eq('is_active', true);
      }

      if (userQuestResponse.isEmpty) {
        print('⚠️ No user_quest found');
        return null;
      }

      final userQuest = userQuestResponse.first;
      final questId = userQuest['quest_id'];
      final currentProgress = userQuest['progress'] as int? ?? 0;
      final newProgress = currentProgress + 1;

      print('📊 Current progress: $currentProgress');
      print('📊 New progress: $newProgress');

      // ✅ 3. دریافت اطلاعات ماموریت
      final questResponse =
          await client.from('quests').select().eq('id', questId).single();

      final targetCount = questResponse['target_count'] as int;
      print('📊 Target count: $targetCount');

      // ✅ 4. به‌روزرسانی عنوان عادت
      await _updateQuestHabitTitle(habitId, newProgress, targetCount);

      // ✅ 5. اگر کامل شده
      if (newProgress >= targetCount) {
        print('🎉 Quest completed!');
        final quest = await _completeQuest(
          userId,
          userQuest['id'],
          habitId,
          questResponse,
        );
        return quest;
      } else {
        // ✅ 6. به‌روزرسانی progress در دیتابیس (بدون updated_at)
        print('📊 Updating progress to: $newProgress');
        await client.from('user_quests').update({
          'progress': newProgress,
          // ❌ حذف updated_at
        }).eq('id', userQuest['id']);

        // ✅ 7. به‌روزرسانی LocalStorage
        try {
          final localStorage = LocalStorageService();
          final habits = localStorage.getHabits();
          final index = habits.indexWhere((h) => h.id == habitId);
          if (index != -1) {
            final updatedHabit = Habit(
              id: habits[index].id,
              userId: habits[index].userId,
              title: '🎯 ${questResponse['title']} ($newProgress/$targetCount)',
              description: habits[index].description,
              subHabits: habits[index].subHabits,
              completedSubHabits: habits[index].completedSubHabits,
              iconName: habits[index].iconName,
              iconColor: habits[index].iconColor,
              backgroundColor: habits[index].backgroundColor,
              frequencyType: habits[index].frequencyType,
              dailyIntervalDays: habits[index].dailyIntervalDays,
              weeklyDays: habits[index].weeklyDays,
              weeklyIntervalWeeks: habits[index].weeklyIntervalWeeks,
              monthlyDays: habits[index].monthlyDays,
              monthlyIntervalMonths: habits[index].monthlyIntervalMonths,
              timeOfDay: habits[index].timeOfDay,
              reminders: habits[index].reminders,
              xpReward: habits[index].xpReward,
              currentStreak: habits[index].currentStreak,
              bestStreak: habits[index].bestStreak,
              isActive: habits[index].isActive,
              createdAt: habits[index].createdAt,
              updatedAt: DateTime.now(),
              groupId: habits[index].groupId,
              startDate: habits[index].startDate,
              endDate: habits[index].endDate,
              challengeId: habits[index].challengeId,
              questId: habits[index].questId,
            );
            await localStorage.saveHabit(updatedHabit);
            print('✅ LocalStorage updated');
          }
        } catch (e) {
          print('⚠️ Error updating local habit title: $e');
        }

        print('✅ Quest progress updated: $newProgress/$targetCount');
        return null;
      }
    } catch (e) {
      print('❌ Error updating quest progress: $e');
      return null;
    }
  }

  Future<void> _updateQuestHabitTitle(
    String habitId,
    int progress,
    int target,
  ) async {
    try {
      print(
          '📊 _updateQuestHabitTitle: habitId=$habitId, progress=$progress, target=$target');

      // ✅ 1. دریافت عادت از دیتابیس
      final habit = await client
          .from('habits')
          .select('title')
          .eq('id', habitId)
          .maybeSingle();

      if (habit == null) {
        print('⚠️ Habit not found for title update: $habitId');
        return;
      }

      // ✅ 2. استخراج عنوان اصلی (بدون اعداد)
      String originalTitle = habit['title'] ?? 'ماموریت';
      final regex = RegExp(r'\s*\(\d+/\d+\)\s*$');
      originalTitle = originalTitle.replaceAll(regex, '').trim();

      // ✅ 3. ساخت عنوان جدید
      final newTitle = '$originalTitle ($progress/$target)';
      print('📊 New title: $newTitle');

      // ✅ 4. به‌روزرسانی در دیتابیس
      await client.from('habits').update({
        'title': newTitle,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', habitId);

      print('✅ Habit title updated: $newTitle');

      // ✅ 5. به‌روزرسانی در LocalStorage
      try {
        final localStorage = LocalStorageService();
        final localHabits = localStorage.getHabits();
        final index = localHabits.indexWhere((h) => h.id == habitId);

        if (index != -1) {
          final updatedHabit = Habit(
            id: localHabits[index].id,
            userId: localHabits[index].userId,
            title: newTitle,
            description: localHabits[index].description,
            subHabits: localHabits[index].subHabits,
            completedSubHabits: localHabits[index].completedSubHabits,
            iconName: localHabits[index].iconName,
            iconColor: localHabits[index].iconColor,
            backgroundColor: localHabits[index].backgroundColor,
            frequencyType: localHabits[index].frequencyType,
            dailyIntervalDays: localHabits[index].dailyIntervalDays,
            weeklyDays: localHabits[index].weeklyDays,
            weeklyIntervalWeeks: localHabits[index].weeklyIntervalWeeks,
            monthlyDays: localHabits[index].monthlyDays,
            monthlyIntervalMonths: localHabits[index].monthlyIntervalMonths,
            timeOfDay: localHabits[index].timeOfDay,
            reminders: localHabits[index].reminders,
            xpReward: localHabits[index].xpReward,
            currentStreak: localHabits[index].currentStreak,
            bestStreak: localHabits[index].bestStreak,
            isActive: localHabits[index].isActive,
            createdAt: localHabits[index].createdAt,
            updatedAt: DateTime.now(),
            groupId: localHabits[index].groupId,
            startDate: localHabits[index].startDate,
            endDate: localHabits[index].endDate,
            challengeId: localHabits[index].challengeId,
            questId: localHabits[index].questId,
          );
          await localStorage.saveHabit(updatedHabit);
          print('✅ Habit title updated in local storage');
        }
      } catch (e) {
        print('⚠️ Error updating local habit title: $e');
      }
    } catch (e) {
      print('❌ Error updating quest habit title: $e');
    }
  }

  // lib/services/supabase_service.dart

  Future<Quest> _completeQuest(
    String userId,
    String userQuestId,
    String habitId,
    Map<String, dynamic> questData,
  ) async {
    try {
      final now = DateTime.now();

      // ✅ 1. به‌روزرسانی user_quests (بدون updated_at)
      await client.from('user_quests').update({
        'progress': questData['target_count'],
        'is_completed': true,
        'completed_at': now.toIso8601String(),
        'is_active': false,
        // ❌ حذف updated_at
      }).eq('id', userQuestId);

      // ✅ 2. حذف عادت ماموریت
      await deleteHabit(habitId);

      // ✅ 3. حذف از LocalStorage
      try {
        final localStorage = LocalStorageService();
        await localStorage.deleteHabit(habitId);
      } catch (e) {
        // خطا را نادیده بگیر
      }

      // ✅ 4. افزودن XP پاداش
      final xpReward = questData['xp_reward'] as int? ?? 0;
      await addXP(userId, xpReward);

      // ✅ 5. افزودن مدال
      final badge = questData['badge'] as String? ?? '🎯';
      await _addBadgeToUser(userId, badge);

      final quest = Quest.fromMap(questData, questData['id']);
      return quest;
    } catch (e) {
      print('❌ Error completing quest: $e');
      rethrow;
    }
  }

  Future<void> _updateLocalHabitTitle(String habitId, String newTitle) async {
    try {
      final localStorage = LocalStorageService();
      final localHabits = localStorage.getHabits();
      final index = localHabits.indexWhere((h) => h.id == habitId);

      if (index != -1) {
        final updatedHabit = Habit(
          id: localHabits[index].id,
          userId: localHabits[index].userId,
          title: newTitle,
          description: localHabits[index].description,
          subHabits: localHabits[index].subHabits,
          completedSubHabits: localHabits[index].completedSubHabits,
          iconName: localHabits[index].iconName,
          iconColor: localHabits[index].iconColor,
          backgroundColor: localHabits[index].backgroundColor,
          frequencyType: localHabits[index].frequencyType,
          dailyIntervalDays: localHabits[index].dailyIntervalDays,
          weeklyDays: localHabits[index].weeklyDays,
          weeklyIntervalWeeks: localHabits[index].weeklyIntervalWeeks,
          monthlyDays: localHabits[index].monthlyDays,
          monthlyIntervalMonths: localHabits[index].monthlyIntervalMonths,
          timeOfDay: localHabits[index].timeOfDay,
          reminders: localHabits[index].reminders,
          xpReward: localHabits[index].xpReward,
          currentStreak: localHabits[index].currentStreak,
          bestStreak: localHabits[index].bestStreak,
          isActive: localHabits[index].isActive,
          createdAt: localHabits[index].createdAt,
          updatedAt: DateTime.now(),
          groupId: localHabits[index].groupId,
          startDate: localHabits[index].startDate,
          endDate: localHabits[index].endDate,
          challengeId: localHabits[index].challengeId,
          questId: localHabits[index].questId,
        );
        await localStorage.saveHabit(updatedHabit);
      }
    } catch (e) {
      // ignore
    }
  }

// lib/services/supabase_service.dart

  Future<void> _addBadgeToUser(String userId, String badge) async {
    try {
      // ✅ بررسی وجود مدال تکراری
      final existing = await client
          .from('user_badges')
          .select()
          .eq('user_id', userId)
          .eq('badge_name', badge)
          .maybeSingle();

      if (existing != null) {
        return;
      }

      // ✅ ثبت مدال جدید
      await client.from('user_badges').insert({
        'user_id': userId,
        'badge_name': badge,
        'badge_icon': badge,
        'badge_type': 'quest',
        'earned_at': DateTime.now().toIso8601String(),
        'is_active': true,
      });
    } catch (e) {
      // اگر جدول وجود نداشت، خطا را نادیده بگیر
    }
  }

// lib/services/supabase_service.dart

  Future<void> cancelQuest(String userId, String questId) async {
    try {
      print('🗑️ Cancelling quest: $questId for user: $userId');

      // ✅ 1. دریافت user_quest
      final userQuestResponse = await client
          .from('user_quests')
          .select()
          .eq('user_id', userId)
          .eq('quest_id', questId)
          .eq('is_active', true);

      if (userQuestResponse.isEmpty) {
        print('⚠️ No active user_quest found for quest: $questId');
        return;
      }

      final userQuest = userQuestResponse.first;
      final habitId = userQuest['habit_id'];
      final userQuestId = userQuest['id'];

      // ✅ 2. حذف از user_quests
      await client.from('user_quests').delete().eq('id', userQuestId);
      print('✅ User quest removed from database');

      // ✅ 3. حذف عادت ماموریت
      if (habitId != null && habitId.isNotEmpty) {
        await deleteHabit(habitId);
        print('✅ Habit deleted from database: $habitId');
      }

      // ✅ 4. حذف همه عادت‌های مرتبط با این ماموریت
      await client
          .from('habits')
          .delete()
          .eq('user_id', userId)
          .eq('quest_id', questId);
      print('✅ All quest habits removed from database');

      // ✅ 5. حذف از LocalStorage
      try {
        final localStorage = LocalStorageService();

        // حذف عادت از LocalStorage
        if (habitId != null && habitId.isNotEmpty) {
          await localStorage.deleteHabit(habitId);
          print('✅ Habit removed from LocalStorage: $habitId');
        }

        // حذف همه عادت‌های مرتبط با این ماموریت از LocalStorage
        final localHabits = localStorage.getHabits();
        final updatedHabits =
            localHabits.where((h) => h.questId != questId).toList();
        await localStorage.saveHabits(updatedHabits);
        print('✅ All quest habits removed from LocalStorage');
      } catch (e) {
        print('⚠️ Error removing from LocalStorage: $e');
      }

      print('✅ Quest cancelled successfully: $questId');
    } catch (e) {
      print('❌ Error cancelling quest: $e');
      rethrow;
    }
  }

  // ==================== Daily Spark ====================

  Future<List<Map<String, dynamic>>> getDailySpark() async {
    try {
      final response =
          await client.from('daily_spark').select().eq('is_active', true);

      return response;
    } catch (e) {
      return [];
    }
  }

  // ==================== Challenges ====================

// lib/services/supabase_service.dart

  Future<Map<String, dynamic>?> checkAndCompleteChallenge(
    String userId,
    String challengeId,
  ) async {
    if (!await isOnline()) return null;

    try {
      // ✅ دریافت همزمان اطلاعات
      final challenge = await getChallengeById(challengeId);
      if (challenge == null) return null;

      final userChallenge = await client
          .from('user_challenges')
          .select()
          .eq('user_id', userId)
          .eq('challenge_id', challengeId)
          .maybeSingle();

      if (userChallenge == null ||
          userChallenge['is_completed'] == true ||
          userChallenge['status'] == 'failed') {
        return null;
      }

      final completions = await client
          .from('challenge_completions')
          .select('date')
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);

      final completedDays = completions.length;
      final totalDays = challenge['challenge_duration'] as int? ?? 7;

      if (completedDays < totalDays) return null;

      print('🎉 Challenge completed! $completedDays/$totalDays');

      // ✅ اجرای همزمان به‌روزرسانی‌ها
      await Future.wait([
        addXP(userId, challenge['xp_reward'] as int? ?? 0),
        client.from('user_challenges').update({
          'is_completed': true,
          'completed_at': DateTime.now().toIso8601String(),
          'progress': totalDays,
          'status': 'completed',
          'is_active': false,
        }).eq('id', userChallenge['id']),
      ]);

      // ✅ حذف عادت‌های چالش (با ignore)
      unawaited(_removeChallengeHabits(userId, challengeId));

      return challenge;
    } catch (e) {
      print('❌ Error checking challenge: $e');
      return null;
    }
  }

// ✅ متد کمکی برای حذف عادت‌ها در پس‌زمینه
  Future<void> _removeChallengeHabits(String userId, String challengeId) async {
    try {
      final habits = await client
          .from('habits')
          .select('id')
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);

      if (habits.isEmpty) return;

      final habitIds = habits.map((h) => h['id'] as String).toList();

      await Future.wait([
        client
            .from('habit_completions')
            .delete()
            .eq('user_id', userId)
            .inFilter('habit_id', habitIds),
        client
            .from('habits')
            .delete()
            .eq('user_id', userId)
            .inFilter('id', habitIds),
      ]);

      // ✅ حذف از LocalStorage
      final localStorage = LocalStorageService();
      final localHabits = localStorage.getHabits();
      final updatedHabits =
          localHabits.where((h) => h.challengeId != challengeId).toList();
      await localStorage.saveHabits(updatedHabits);

      print('🗑️ Removed ${habitIds.length} challenge habits');
    } catch (e) {
      print('⚠️ Error removing challenge habits: $e');
    }
  }

  Future<List<Package>> getUserActivePackages(String userId) async {
    try {
      final response = await client.from('user_packages').select('''
          package_id,
          packages (*)
        ''').eq('user_id', userId).eq('is_active', true);

      if (response.isEmpty) return [];

      return response.map((item) {
        final packageData = item['packages'] as Map<String, dynamic>;
        final packageId = packageData['id'] as String;
        return Package.fromMap(packageData, packageId);
      }).toList();
    } catch (e) {
      print('❌ Error getting user active packages: $e');
      return [];
    }
  }

  // ==================== Streak ====================

  Future<void> updateUserStreak(String userId) async {
    try {
      final today = DateTime.now();
      final todayStr = today.toIso8601String().split('T').first;

      final todayActivity = await client
          .from('user_daily_activity')
          .select('is_active')
          .eq('user_id', userId)
          .eq('activity_date', todayStr)
          .maybeSingle();

      final bool isActiveToday =
          todayActivity != null && todayActivity['is_active'] == true;

      int currentStreak = 0;
      int bestStreak = 0;

      if (isActiveToday) {
        currentStreak = await _calculateStreak(userId, today);
        if (currentStreak == 0) {
          currentStreak = 1;
        }
      } else {
        final lastActivity = await client
            .from('user_daily_activity')
            .select('activity_date')
            .eq('user_id', userId)
            .eq('is_active', true)
            .order('activity_date', ascending: false)
            .limit(1)
            .maybeSingle();

        if (lastActivity != null) {
          final lastDate = DateTime.parse(lastActivity['activity_date']);
          final daysDiff = today.difference(lastDate).inDays;
          if (daysDiff == 1) {
            currentStreak = 0;
          } else if (daysDiff > 1) {
            currentStreak = 0;
          }
        }
      }

      final profile = await client
          .from('profiles')
          .select('best_streak')
          .eq('user_id', userId)
          .maybeSingle();

      if (profile != null) {
        bestStreak = profile['best_streak'] ?? 0;
        if (currentStreak > bestStreak) {
          bestStreak = currentStreak;
        }
      }

      final jalaliToday = Jalali.fromDateTime(today);
      final daysToSubtract = jalaliToday.weekDay - 1;
      final weekStart = today.subtract(Duration(days: daysToSubtract));

      int weeklyStreak = 0;
      List<bool> weekStatus = [];

      for (int i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        final dateStr = date.toIso8601String().split('T').first;
        final activity = await client
            .from('user_daily_activity')
            .select('is_active')
            .eq('user_id', userId)
            .eq('activity_date', dateStr)
            .maybeSingle();

        final isActive = activity != null && activity['is_active'] == true;
        weekStatus.add(isActive);

        if (isActive) {
          weeklyStreak++;
        }
      }

      await client.from('profiles').update({
        'current_streak': currentStreak,
        'best_streak': bestStreak,
        'last_streak_date': todayStr,
        'weekly_streak': weeklyStreak,
      }).eq('user_id', userId);
    } catch (e) {
      // ignore
    }
  }

  Future<int> _calculateStreak(String userId, DateTime endDate) async {
    int streak = 0;
    DateTime currentDate = endDate;

    while (true) {
      final dateStr = currentDate.toIso8601String().split('T').first;

      final activity = await client
          .from('user_daily_activity')
          .select('is_active')
          .eq('user_id', userId)
          .eq('activity_date', dateStr)
          .maybeSingle();

      final bool isActive = activity != null && activity['is_active'] == true;

      if (isActive) {
        streak++;
        currentDate = currentDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  Future<void> recordDailyActivity({
    required String userId,
    required DateTime date,
    int habitsCompleted = 0,
    int tasksCompleted = 0,
    int xpEarned = 0,
    bool isActive = true,
  }) async {
    if (!await isOnline()) {
      return;
    }
    try {
      final dateStr = _getDateString(date);

      final existing = await client
          .from('user_daily_activity')
          .select()
          .eq('user_id', userId)
          .eq('activity_date', dateStr)
          .maybeSingle();

      if (existing != null) {
        await client.from('user_daily_activity').update({
          'habits_completed': habitsCompleted,
          'tasks_completed': tasksCompleted,
          'xp_earned': xpEarned,
          'is_active': isActive,
        }).eq('id', existing['id']);
      } else {
        await client.from('user_daily_activity').insert({
          'user_id': userId,
          'activity_date': dateStr,
          'habits_completed': habitsCompleted,
          'tasks_completed': tasksCompleted,
          'xp_earned': xpEarned,
          'is_active': isActive,
        });
      }

      await updateUserStreak(userId);
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> hasUserActivityToday(String userId) async {
    try {
      final todayStr = DateTime.now().toIso8601String().split('T').first;

      final response = await client
          .from('user_daily_activity')
          .select('is_active')
          .eq('user_id', userId)
          .eq('activity_date', todayStr)
          .maybeSingle();

      return response != null && response['is_active'] == true;
    } catch (e) {
      return false;
    }
  }

  // ==================== Helper ====================

  Map<String, dynamic> _convertKeys(Map<String, dynamic> data) {
    return data.map((key, value) {
      String newKey = key;
      switch (key) {
        case 'user_id':
          newKey = 'userId';
          break;
        case 'total_xp':
          newKey = 'totalXP';
          break;
        case 'sub_habits':
          newKey = 'subHabits';
          break;
        case 'completed_sub_habits':
          newKey = 'completedSubHabits';
          break;
        case 'icon_name':
          newKey = 'iconName';
          break;
        case 'icon_color':
          newKey = 'iconColor';
          break;
        case 'background_color':
          newKey = 'backgroundColor';
          break;
        case 'frequency_type':
          newKey = 'frequencyType';
          break;
        case 'daily_interval_days':
          newKey = 'dailyIntervalDays';
          break;
        case 'weekly_days':
          newKey = 'weeklyDays';
          break;
        case 'weekly_interval_weeks':
          newKey = 'weeklyIntervalWeeks';
          break;
        case 'monthly_days':
          newKey = 'monthlyDays';
          break;
        case 'monthly_interval_months':
          newKey = 'monthlyIntervalMonths';
          break;
        case 'time_of_day':
          newKey = 'timeOfDay';
          break;
        case 'xp_reward':
          newKey = 'xpReward';
          break;
        case 'current_streak':
          newKey = 'currentStreak';
          break;
        case 'best_streak':
          newKey = 'bestStreak';
          break;
        case 'is_active':
          newKey = 'isActive';
          break;
        case 'group_id':
          newKey = 'groupId';
          break;
        case 'start_date':
          newKey = 'startDate';
          break;
        case 'end_date':
          newKey = 'endDate';
          break;
        case 'challenge_id':
          newKey = 'challengeId';
          break;
        case 'created_at':
          newKey = 'createdAt';
          break;
        case 'updated_at':
          newKey = 'updatedAt';
          break;
        case 'is_completed':
          newKey = 'isCompleted';
          break;
        case 'sub_tasks':
          newKey = 'subTasks';
          break;
        case 'completed_sub_tasks':
          newKey = 'completedSubTasks';
          break;
        case 'due_date':
          newKey = 'dueDate';
          break;
        case 'habit_id':
          newKey = 'habitId';
          break;
        case 'completed_at':
          newKey = 'completedAt';
          break;
        case 'community_xp':
          newKey = 'communityXP';
          break;
        case 'target_xp':
          newKey = 'targetXP';
          break;
        case 'text_color':
          newKey = 'textColor';
          break;
        case 'registration_end_date':
          newKey = 'registrationEndDate';
          break;
        case 'challenge_duration':
          newKey = 'challengeDuration';
          break;
        case 'purchased_at':
          newKey = 'purchasedAt';
          break;
        case 'joined_at':
          newKey = 'joinedAt';
          break;
        case 'xp_earned':
          newKey = 'xpEarned';
          break;
        case 'preview_image':
          newKey = 'previewImage';
          break;
        case 'quest_id':
          newKey = 'questId';
          break;
        default:
          newKey = key;
      }
      return MapEntry(newKey, value);
    });
  }
}
