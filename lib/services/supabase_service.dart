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
import 'package:shamsi_date/shamsi_date.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    return await client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'email': email},
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

  // ==================== Profiles ====================

  Future<void> createProfile(String userId, String email, String name) async {
    await client.from('profiles').insert({
      'user_id': userId,
      'email': email,
      'name': name,
      'total_xp': 0,
    });
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
      return;
    }

    try {
      // ✅ دریافت تعداد روزهای تکمیل شده از challenge_completions
      final completions = await client
          .from('challenge_completions')
          .select('date')
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);

      final completedDays = completions.length;

      // ✅ دریافت اطلاعات چالش برای totalDays
      final challenge = await client
          .from('challenges')
          .select('challenge_duration')
          .eq('id', challengeId)
          .maybeSingle();

      final totalDays = challenge?['challenge_duration'] as int? ?? 7;

      // ✅ به‌روزرسانی progress
      await client
          .from('user_challenges')
          .update({
            'progress': completedDays > totalDays ? totalDays : completedDays,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);

      print('📊 Challenge progress updated: $completedDays / $totalDays');
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
            .update({'total_xp': newXP})
            .eq('user_id', userId);
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
              .update({'total_xp': currentXP + amount})
              .eq('user_id', userId);
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

  Future<void> removeXP(String userId, int amount) async {
    try {
      final response = await client
          .from('user_progress')
          .select('id, total_xp')
          .eq('user_id', userId);

      if (response.isNotEmpty) {
        final currentXP = response[0]['total_xp'] ?? 0;
        final newXP = (currentXP - amount).clamp(0, double.infinity).toInt();

        await client
            .from('user_progress')
            .update({'total_xp': newXP})
            .eq('id', response[0]['id']);
      } else {
        await client.from('user_progress').insert({
          'user_id': userId,
          'total_xp': 0,
        });
      }

      try {
        final profileResponse = await client
            .from('profiles')
            .select('total_xp')
            .eq('user_id', userId);

        if (profileResponse.isNotEmpty) {
          final currentXP = profileResponse[0]['total_xp'] ?? 0;
          final newXP = (currentXP - amount).clamp(0, double.infinity).toInt();
          await client
              .from('profiles')
              .update({'total_xp': newXP})
              .eq('user_id', userId);
        }
      } catch (e) {
        // ignore
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==================== Challenges ====================

  Future<List<Map<String, dynamic>>> getChallenges() async {
    if (!await isOnline()) {
      return [];
    }

    try {
      final now = DateTime.now().toIso8601String();
      final response = await client
          .from('challenges')
          .select()
          .eq('is_active', true)
          .gte('registration_end_date', now)
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

      // ✅ دریافت عادت‌های چالش
      final challengeHabits = await getChallengeHabits(challengeId);
      List<String> subHabits = [];
      for (var habit in challengeHabits) {
        subHabits.add(habit['title']);
      }

      // ✅ فقط برای روزهای باقیمانده (از امروز تا پایان چالش) عادت ایجاد کن
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);

      // ✅ محاسبه روزهای باقیمانده
      final remainingDays = end.difference(today).inDays + 1;

      // ✅ فقط اگر روزهای باقیمانده بیشتر از 0 باشد
      if (remainingDays > 0) {
        // ✅ فقط یک عادت برای کل چالش ایجاد کن (نه برای هر روز جداگانه)
        // عادت به صورت daily است و کاربر باید هر روز آن را انجام دهد
        final newHabit = Habit(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: userId,
          title: '🏆 چالش: ${challenge['title']}',
          description:
              '${challenge['description']} - $duration روز (${remainingDays} روز باقیمانده)',
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
          startDate: today, // ✅ از امروز شروع میشه
          endDate: end, // ✅ تا پایان چالش
          challengeId: challengeId,
          questId: null,
        );

        await createHabit(newHabit);
        print('✅ Challenge habit created: ${newHabit.title}');
      } else {
        print('⚠️ No remaining days for challenge, habit not created');
      }
    } catch (e) {
      print('❌ Error adding challenge habit: $e');
      rethrow;
    }
  }

  // ✅ ثبت تکمیل روزانه چالش (بدون last_completed_date)
  Future<void> completeChallengeDay({
    required String userId,
    required String challengeId,
    required DateTime date,
  }) async {
    try {
      // 1. بررسی اینکه آیا کاربر این چالش رو دارد
      final userChallenge = await client
          .from('user_challenges')
          .select('id, is_active, is_completed, progress')
          .eq('user_id', userId)
          .eq('challenge_id', challengeId)
          .eq('is_active', true)
          .eq('is_completed', false)
          .maybeSingle();

      if (userChallenge == null) {
        print('⚠️ User is not active in this challenge: $challengeId');
        return;
      }

      // 2. بررسی اینکه آیا امروز قبلاً ثبت شده
      final dateStr = date.toIso8601String().split('T').first;
      final existing = await client
          .from('challenge_completions')
          .select('id')
          .eq('user_id', userId)
          .eq('challenge_id', challengeId)
          .eq('date', dateStr)
          .maybeSingle();

      if (existing != null) {
        print('📅 Already completed for today: $dateStr');
        return;
      }

      // 3. ثبت تکمیل روزانه
      await client.from('challenge_completions').insert({
        'user_id': userId,
        'challenge_id': challengeId,
        'date': dateStr,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 4. به‌روزرسانی progress در user_challenges
      final completionsCount = await client
          .from('challenge_completions')
          .select('date')
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);

      final completedDays = completionsCount.length;

      await client
          .from('user_challenges')
          .update({
            'progress': completedDays,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userChallenge['id']);

      print('✅ Challenge day completed: $challengeId - Day $completedDays');
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

  // ✅ انصراف کاربر از چالش (نسخه کامل)
  Future<void> leaveChallenge(String userId, String challengeId) async {
    try {
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

        // 3. حذف رکوردهای challenge_completions
        await client
            .from('challenge_completions')
            .delete()
            .eq('user_id', userId)
            .eq('challenge_id', challengeId);

        // 4. حذف عادت‌های مرتبط با چالش
        await removeChallengeHabitByChallengeId(userId, challengeId);

        // 5. حذف از LocalStorage (برای همگام‌سازی آفلاین)
        try {
          final localStorage = LocalStorageService();
          final userChallenges = localStorage.getUserChallenges();
          final updatedChallenges = userChallenges
              .where((c) => c['id'] != challengeId)
              .toList();
          await localStorage.saveUserChallenges(updatedChallenges);

          // ✅ حذف عادت‌های چالش از localStorage
          final localHabits = localStorage.getHabits();
          final updatedHabits = localHabits
              .where((h) => h.challengeId != challengeId)
              .toList();
          await localStorage.saveHabits(updatedHabits);
        } catch (e) {
          // ignore
        }

        print('🗑️ User left challenge: $challengeId');
      }
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
      final response = await client
          .from('user_challenges')
          .select()
          .eq('user_id', userId);

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
            'joined_at, challenge_start_date, challenge_end_date, progress, is_completed, status',
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

      // 4. دریافت تاریخ‌های تکمیل شده از جدول challenge_completions
      final completions = await client
          .from('challenge_completions')
          .select('date')
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);

      // 5. محاسبه روزهای تکمیل شده
      int completedDays = completions.length;

      // 6. اگر کاربر تمام روزها رو انجام داده، مقدار رو برابر totalDays کن
      if (completedDays >= totalDays) {
        completedDays = totalDays;
      }

      print('📊 Challenge progress: $completedDays / $totalDays days');
      print('📅 Total completions: ${completions.length}');

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
          await client
              .from('user_challenges')
              .update({
                'is_active': false,
                'status': 'expired',
                'updated_at': now.toIso8601String(),
              })
              .eq('id', userChallenge['id']);

          print('⏰ Challenge expired: ${challenge['title']}');
        }

        // اگر تاریخ پایان چالش گذشته باشد و کامل نشده
        if (challengeEnd != null &&
            challengeEnd.isBefore(now) &&
            userChallenge['is_completed'] == false) {
          await client
              .from('user_challenges')
              .update({
                'is_active': false,
                'status': 'failed',
                'completed_at': now.toIso8601String(),
                'updated_at': now.toIso8601String(),
              })
              .eq('id', userChallenge['id']);

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

      await client
          .from('user_challenges')
          .update({
            'progress': completedDays,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userChallenge['id']);

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

  // ✅ تکمیل موفق چالش
  Future<void> _completeChallenge(
    String userId,
    String userChallengeId,
    Map<String, dynamic> challenge,
  ) async {
    try {
      final now = DateTime.now();
      final xpReward = challenge['xp_reward'] as int? ?? 50;
      final challengeDuration = challenge['challenge_duration'] as int? ?? 7;

      await client
          .from('user_challenges')
          .update({
            'is_completed': true,
            'is_active': false,
            'status': 'completed',
            'progress': challengeDuration,
            'completed_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .eq('id', userChallengeId);

      // اضافه کردن XP
      try {
        await client.rpc(
          'add_xp',
          params: {'user_id': userId, 'amount': xpReward},
        );
      } catch (e) {
        print('⚠️ RPC add_xp not found');
      }

      print('✅ Challenge completed successfully: ${challenge['title']}');
    } catch (e) {
      print('❌ Error completing challenge: $e');
    }
  }

  // ❌ شکست چالش
  Future<void> _failChallenge(
    String userId,
    String userChallengeId,
    Map<String, dynamic> challenge,
  ) async {
    try {
      final now = DateTime.now();

      await client
          .from('user_challenges')
          .update({
            'is_active': false,
            'status': 'failed',
            'completed_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .eq('id', userChallengeId);

      print('❌ Challenge failed: ${challenge['title']}');
    } catch (e) {
      print('❌ Error failing challenge: $e');
    }
  }

  // lib/services/supabase_service.dart

  // ✅ ثبت‌نام در چالش (با ریفرش خودکار)
  Future<void> joinChallenge(String userId, String challengeId) async {
    try {
      final now = DateTime.now();

      // بررسی وجود کاربر در چالش
      final existing = await client
          .from('user_challenges')
          .select('id')
          .eq('user_id', userId)
          .eq('challenge_id', challengeId)
          .maybeSingle();

      if (existing != null) {
        // اگر قبلاً ثبت‌نام کرده، دوباره فعالش کن
        await client
            .from('user_challenges')
            .update({
              'is_active': true,
              'status': 'active',
              'is_completed': false,
              'progress': 0,
              'updated_at': now.toIso8601String(),
            })
            .eq('id', existing['id']);
        return;
      }

      // دریافت اطلاعات چالش
      final challengeResponse = await client
          .from('challenges')
          .select('*')
          .eq('id', challengeId)
          .maybeSingle();

      if (challengeResponse == null) {
        throw Exception('چالش یافت نشد');
      }

      final duration = challengeResponse['challenge_duration'] as int? ?? 7;
      final endDate = now.add(Duration(days: duration));

      // ثبت‌نام جدید در user_challenges
      await client.from('user_challenges').insert({
        'user_id': userId,
        'challenge_id': challengeId,
        'joined_at': now.toIso8601String(),
        'challenge_start_date': now.toIso8601String(),
        'challenge_end_date': endDate.toIso8601String(),
        'progress': 0,
        'is_completed': false,
        'is_active': true,
        'status': 'active',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // ✅ اضافه کردن عادت‌های چالش به کاربر
      await addChallengeHabitToUser(userId, challengeResponse, now, endDate);

      print('✅ User joined challenge: $challengeId');
    } catch (e) {
      print('❌ Error joining challenge: $e');
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
      final packageResponse = await client
          .from('packages')
          .select()
          .eq('id', packageId)
          .single();

      final package = Package.fromMap(packageResponse, packageId);

      final existing = await client
          .from('user_packages')
          .select()
          .eq('user_id', userId)
          .eq('package_id', packageId);

      if (existing.isNotEmpty) {
        await client
            .from('user_packages')
            .update({'is_active': true, 'removed_at': null})
            .eq('id', existing[0]['id']);
      } else {
        await client.from('user_packages').insert({
          'user_id': userId,
          'package_id': packageId,
          'is_active': true,
          'added_at': DateTime.now().toIso8601String(),
        });
      }

      for (var packageHabit in package.habits) {
        final habit = packageHabit.toHabit(userId, packageId);
        await createHabit(habit);
      }

      await addXP(userId, package.xpReward);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deactivatePackage(String userId, String packageId) async {
    try {
      final packageResponse = await client
          .from('packages')
          .select()
          .eq('id', packageId)
          .single();

      final package = Package.fromMap(packageResponse, packageId);

      await client
          .from('user_packages')
          .update({
            'is_active': false,
            'removed_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('package_id', packageId);

      final habits = await getHabits(userId);
      for (var habit in habits) {
        if (habit.title.startsWith('📦')) {
          for (var packageHabit in package.habits) {
            if (habit.title.contains(packageHabit.title)) {
              await deleteHabit(habit.id);
              break;
            }
          }
        }
      }
    } catch (e) {
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
        final packageResponse = await client
            .from('packages')
            .select()
            .eq('id', packageId)
            .single();

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
      final existing = await client
          .from('user_progress')
          .select('id')
          .eq('user_id', userId);

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

  Future<List<UserQuest>> getUserQuests(String userId) async {
    try {
      final response = await client
          .from('user_quests')
          .select()
          .eq('user_id', userId);

      return response
          .map((data) => UserQuest.fromMap(data, data['id']))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> startQuest(String userId, Quest quest) async {
    try {
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

      final today = DateTime.now();

      final originalTitle = quest.title;

      final habit = Habit(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        title: '🎯 $originalTitle (0/${quest.targetCount})',
        description: '${quest.description} - ${quest.targetCount} روز مانده',
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
        endDate: today.add(Duration(days: quest.targetCount - 1)),
        challengeId: null,
        questId: quest.id,
      );

      await createHabit(habit);

      await client.from('user_quests').insert({
        'user_id': userId,
        'quest_id': quest.id,
        'habit_id': habit.id,
        'progress': 0,
        'is_completed': false,
        'started_at': today.toIso8601String(),
        'is_active': true,
      });
    } catch (e) {
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

  Future<Quest?> updateQuestProgress(String userId, String habitId) async {
    try {
      final habitCheck = await client
          .from('habits')
          .select()
          .eq('id', habitId)
          .eq('user_id', userId)
          .maybeSingle();

      if (habitCheck == null) {
        return null;
      }

      var userQuestResponse = await client
          .from('user_quests')
          .select()
          .eq('user_id', userId)
          .eq('habit_id', habitId)
          .eq('is_active', true);

      if (userQuestResponse.isEmpty) {
        final questId = habitCheck['quest_id'];
        if (questId == null) {
          return null;
        }

        userQuestResponse = await client
            .from('user_quests')
            .select()
            .eq('user_id', userId)
            .eq('quest_id', questId)
            .eq('is_active', true);
      }

      if (userQuestResponse.isEmpty) {
        return null;
      }

      final userQuest = userQuestResponse.first;
      final questId = userQuest['quest_id'];
      final currentProgress = userQuest['progress'] as int? ?? 0;
      final newProgress = currentProgress + 1;

      final questResponse = await client
          .from('quests')
          .select()
          .eq('id', questId)
          .single();

      final targetCount = questResponse['target_count'] as int;

      if (newProgress >= targetCount) {
        final quest = await _completeQuest(
          userId,
          userQuest['id'],
          habitId,
          questResponse,
        );
        return quest;
      } else {
        await client
            .from('user_quests')
            .update({'progress': newProgress})
            .eq('id', userQuest['id']);

        await _updateQuestHabitTitle(habitId, newProgress, targetCount);
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<Quest> _completeQuest(
    String userId,
    String userQuestId,
    String habitId,
    Map<String, dynamic> questData,
  ) async {
    try {
      await client
          .from('user_quests')
          .update({
            'progress': questData['target_count'],
            'is_completed': true,
            'completed_at': DateTime.now().toIso8601String(),
            'is_active': false,
          })
          .eq('id', userQuestId);

      await deleteHabit(habitId);

      await addXP(userId, questData['xp_reward'] as int);

      await _addBadgeToUser(userId, questData['badge']);

      try {
        final localStorage = LocalStorageService();
        await localStorage.deleteHabit(habitId);
      } catch (e) {
        // ignore
      }

      final quest = Quest.fromMap(questData, questData['id']);
      return quest;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _updateQuestHabitTitle(
    String habitId,
    int progress,
    int target,
  ) async {
    try {
      final habit = await client
          .from('habits')
          .select('title')
          .eq('id', habitId)
          .maybeSingle();

      if (habit == null) {
        return;
      }

      String originalTitle = habit['title'] ?? 'ماموریت';
      final regex = RegExp(r'\s*\(\d+/\d+\)\s*$');
      originalTitle = originalTitle.replaceAll(regex, '').trim();

      final newTitle = '$originalTitle ($progress/$target)';

      await client.from('habits').update({'title': newTitle}).eq('id', habitId);

      await _updateLocalHabitTitle(habitId, newTitle);
    } catch (e) {
      // ignore
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

  Future<void> _addBadgeToUser(String userId, String badge) async {
    // این بخش به سیستم افتخارات متصل میشه
  }

  Future<void> cancelQuest(String userId, String questId) async {
    try {
      final userQuestResponse = await client
          .from('user_quests')
          .select()
          .eq('user_id', userId)
          .eq('quest_id', questId)
          .eq('is_active', true);

      if (userQuestResponse.isEmpty) {
        return;
      }

      final userQuest = userQuestResponse.first;
      final habitId = userQuest['habit_id'];
      final userQuestId = userQuest['id'];

      await client.from('user_quests').delete().eq('id', userQuestId);

      if (habitId != null && habitId.isNotEmpty) {
        await client
            .from('habits')
            .delete()
            .eq('id', habitId)
            .eq('user_id', userId);
      }

      await client
          .from('habits')
          .delete()
          .eq('user_id', userId)
          .eq('quest_id', questId);
    } catch (e) {
      rethrow;
    }
  }

  // ==================== Daily Spark ====================

  Future<List<Map<String, dynamic>>> getDailySpark() async {
    try {
      final response = await client
          .from('daily_spark')
          .select()
          .eq('is_active', true);

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
    if (!await isOnline()) {
      return null;
    }

    try {
      final challenge = await getChallengeById(challengeId);
      if (challenge == null) {
        return null;
      }

      final userChallenge = await client
          .from('user_challenges')
          .select()
          .eq('user_id', userId)
          .eq('challenge_id', challengeId)
          .maybeSingle();

      if (userChallenge == null) {
        return null;
      }

      if (userChallenge['is_completed'] == true) {
        return challenge;
      }
      if (userChallenge['status'] == 'failed') {
        return null;
      }

      // ✅ دریافت تعداد روزهای تکمیل شده از challenge_completions
      final completions = await client
          .from('challenge_completions')
          .select('date')
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);

      final completedDays = completions.length;
      final totalDays = challenge['challenge_duration'] as int? ?? 7;

      print('📊 Challenge progress: $completedDays / $totalDays');

      // ✅ اگر تمام روزها انجام شده
      if (completedDays >= totalDays) {
        print('🎉 Challenge completed!');

        await addXP(userId, challenge['xp_reward'] as int? ?? 0);

        await client
            .from('user_challenges')
            .update({
              'is_completed': true,
              'completed_at': DateTime.now().toIso8601String(),
              'progress': totalDays,
              'status': 'completed',
              'is_active': false,
            })
            .eq('id', userChallenge['id']);

        // حذف عادت‌های چالش
        final habits = await getHabits(userId);
        final challengeHabits = habits
            .where((h) => h.challengeId == challengeId)
            .toList();

        for (var habit in challengeHabits) {
          await deleteHabit(habit.id);
        }

        return challenge;
      }

      // ✅ اگر تاریخ پایان گذشته و کامل نشده
      if (userChallenge['challenge_end_date'] != null) {
        final endDate = DateTime.parse(userChallenge['challenge_end_date']);
        final now = DateTime.now();

        if (now.isAfter(endDate) && completedDays < totalDays) {
          print('⏰ Challenge failed - time expired');

          await client
              .from('user_challenges')
              .update({
                'is_completed': false,
                'is_active': false,
                'status': 'failed',
                'completed_at': now.toIso8601String(),
              })
              .eq('id', userChallenge['id']);

          // حذف عادت‌های چالش
          final habits = await getHabits(userId);
          final challengeHabits = habits
              .where((h) => h.challengeId == challengeId)
              .toList();

          for (var habit in challengeHabits) {
            await deleteHabit(habit.id);
          }
        }
      }

      return null;
    } catch (e) {
      print('❌ Error checking challenge: $e');
      return null;
    }
  }

  Future<List<Package>> getUserActivePackages(String userId) async {
    try {
      final response = await client
          .from('user_packages')
          .select('''
          package_id,
          packages (*)
        ''')
          .eq('user_id', userId)
          .eq('is_active', true);

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

      await client
          .from('profiles')
          .update({
            'current_streak': currentStreak,
            'best_streak': bestStreak,
            'last_streak_date': todayStr,
            'weekly_streak': weeklyStreak,
          })
          .eq('user_id', userId);
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
        await client
            .from('user_daily_activity')
            .update({
              'habits_completed': habitsCompleted,
              'tasks_completed': tasksCompleted,
              'xp_earned': xpEarned,
              'is_active': isActive,
            })
            .eq('id', existing['id']);
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
