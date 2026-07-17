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
    print('🔵 [Supabase] isOnline() called');
    try {
      // ✅ در وب، همیشه آنلاین فرض کن
      if (kIsWeb) {
        print('🔵 [Supabase] isOnline() - Web platform, returning true');
        return true;
      }

      final result = await InternetConnectionChecker().hasConnection;
      print('🔵 [Supabase] isOnline() - Result: $result');
      return result;
    } catch (e) {
      print('🟡 [Supabase] isOnline() - Error, returning true: $e');
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
    // ✅ پاک کردن userId از SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    _cachedUser = null;
    _userCacheTime = null;
  }

  Future<User?> getCurrentUser() async {
    try {
      // ✅ اگر کش معتبر است، از آن استفاده کن
      if (_cachedUser != null &&
          _userCacheTime != null &&
          DateTime.now().difference(_userCacheTime!) < _userCacheDuration) {
        return _cachedUser;
      }

      // ✅ دریافت کاربر از Supabase
      try {
        final user = client.auth.currentUser;
        if (user != null) {
          _cachedUser = user;
          _userCacheTime = DateTime.now();
          return user;
        }
      } catch (e) {
        // اگر خطا داشت، کش را برگردان
        if (_cachedUser != null) {
          return _cachedUser;
        }
      }

      // ✅ اگر در Supabase پیدا نشد، از SharedPreferences بررسی کن
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedUserId = prefs.getString('user_id');
        if (savedUserId != null) {
          // ✅ بررسی وجود کاربر در دیتابیس
          final response = await client
              .from('profiles')
              .select('user_id, created_at')
              .eq('user_id', savedUserId)
              .maybeSingle();

          if (response != null) {
            // ✅ یک User با پارامترهای صحیح بساز
            _cachedUser = User(
              id: savedUserId,
              appMetadata: {}, // ✅ required
              userMetadata: {}, // ✅ required
              aud: 'authenticated', // ✅ required
              createdAt: DateTime.now().toIso8601String(), // ✅ String
            );
            _userCacheTime = DateTime.now();
            return _cachedUser;
          }
        }
      } catch (e) {
        // خطا را نادیده بگیر
      }

      return null;
    } catch (e) {
      print('⚠️ Error getting current user: $e');
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
      print('⚠️ Offline - skipping getHabits');
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
      print('⚠️ Offline - skipping getTasks');
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

          // ✅ فقط اگر آنلاین هستیم، پیشرفت چالش را به‌روزرسانی کن
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

        // ✅ فقط اگر آنلاین هستیم، پیشرفت چالش را به‌روزرسانی کن
        if (await isOnline()) {
          await _updateChallengeProgressForHabit(userId, habitId);
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateChallengeProgress(
    String userId,
    String challengeId,
  ) async {
    // ✅ اگر آفلاین هستیم، هیچ کاری نکن
    if (!await isOnline()) {
      print('⚠️ Offline - skipping updateChallengeProgress');
      return;
    }

    try {
      final progress = await getUserChallengeProgressDetails(
        userId,
        challengeId,
      );
      final completedDays = progress['completedDays'] ?? 0;

      await client
          .from('user_challenges')
          .update({'progress': completedDays})
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);
    } catch (e) {
      print('❌ Error updating challenge progress: $e');
    }
  }

  /// به‌روزرسانی پیشرفت چالش پس از انجام عادت
  Future<void> _updateChallengeProgressForHabit(
    String userId,
    String habitId,
  ) async {
    try {
      // ✅ اگر آفلاین هستیم، هیچ کاری نکن
      if (!await isOnline()) {
        print('⚠️ Offline - skipping challenge progress update');
        return;
      }

      // دریافت challengeId از عادت
      final habit = await client
          .from('habits')
          .select('challenge_id')
          .eq('id', habitId)
          .eq('user_id', userId)
          .maybeSingle();

      if (habit == null) {
        print('⚠️ Habit not found: $habitId');
        return;
      }

      final challengeId = habit['challenge_id'];
      if (challengeId == null) {
        print('⚠️ No challenge_id for habit: $habitId');
        return;
      }

      // محاسبه و به‌روزرسانی پیشرفت
      await updateChallengeProgress(userId, challengeId);
    } catch (e) {
      print('⚠️ Error updating challenge progress for habit $habitId: $e');
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

      // همچنین در profiles هم ذخیره کن
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
        // خطا را نادیده بگیر
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
        // خطا را نادیده بگیر
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==================== Challenges ====================
  Future<List<Map<String, dynamic>>> getChallenges() async {
    if (!await isOnline()) {
      print('⚠️ Offline - skipping getChallenges');
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

  Future<void> addChallengeHabitToUser(
    String userId,
    Map<String, dynamic> challenge,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final duration = challenge['challenge_duration'] as int;
      final xpPerDay = (challenge['xp_reward'] as int) ~/ duration;

      final challengeHabits = await getChallengeHabits(challenge['id']);
      List<String> subHabits = [];
      for (var habit in challengeHabits) {
        subHabits.add(habit['title']);
      }

      final newHabit = Habit(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        title: '🏆 چالش: ${challenge['title']}',
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
        challengeId: challenge['id'],
        questId: null,
      );

      await createHabit(newHabit);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> joinChallenge(String userId, String challengeId) async {
    try {
      final currentUser = await getCurrentUser();
      if (currentUser == null) {
        throw Exception('لطفاً دوباره وارد حساب کاربری خود شوید');
      }

      final challenge = await getChallengeById(challengeId);
      if (challenge == null) {
        throw Exception('چالش پیدا نشد');
      }

      final now = DateTime.now();
      final registrationEnd = DateTime.parse(
        challenge['registration_end_date'],
      );

      if (now.isAfter(registrationEnd)) {
        throw Exception('مهلت ثبت‌نام این چالش به اتمام رسیده است');
      }

      final existing = await client
          .from('user_challenges')
          .select()
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);

      if (existing.isNotEmpty) {
        final userChallenge = existing.first;
        if (userChallenge['is_completed'] == true) {
          throw Exception('شما قبلاً این چالش را تکمیل کرده‌اید! 🏆');
        }

        if (userChallenge['is_active'] == false &&
            userChallenge['status'] == 'failed') {
          await client
              .from('user_challenges')
              .delete()
              .eq('id', userChallenge['id']);
        } else {
          return;
        }
      }

      final duration = challenge['challenge_duration'] as int;
      final challengeStartDate = DateTime.now();
      final challengeEndDate = challengeStartDate.add(
        Duration(days: duration - 1),
      );

      await client.from('user_challenges').insert({
        'user_id': userId,
        'challenge_id': challengeId,
        'joined_at': DateTime.now().toIso8601String(),
        'challenge_start_date': challengeStartDate.toIso8601String(),
        'challenge_end_date': challengeEndDate.toIso8601String(),
        'progress': 0,
        'is_completed': false,
        'is_active': true,
        'status': 'active',
      });

      await addChallengeHabitToUser(
        userId,
        challenge,
        challengeStartDate,
        challengeEndDate,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> leaveChallenge(String userId, String challengeId) async {
    try {
      final response = await client
          .from('user_challenges')
          .select()
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);

      if (response.isNotEmpty) {
        await client
            .from('user_challenges')
            .delete()
            .eq('id', response[0]['id']);

        await removeChallengeHabitByChallengeId(userId, challengeId);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeChallengeHabitByChallengeId(
    String userId,
    String challengeId,
  ) async {
    try {
      final habits = await getHabits(userId);
      for (var habit in habits) {
        if (habit.challengeId == challengeId) {
          await deleteHabit(habit.id);
        }
      }
    } catch (e) {
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
      final response = await client
          .from('user_challenges')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true);

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
            data['challenge_start_date'] = item['challenge_start_date'];
            data['challenge_end_date'] = item['challenge_end_date'];
            result.add(data);
          }
        }
      }

      return result;
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, int>> getUserChallengeProgressDetails(
    String userId,
    String challengeId,
  ) async {
    // ✅ اگر آفلاین هستیم، مقدار پیش‌فرض برگردان
    if (!await isOnline()) {
      print('⚠️ Offline - returning default progress for challenge');
      return {'completedDays': 0, 'totalDays': 7};
    }

    try {
      // ✅ 1. ابتدا از user_challenges دریافت کن
      final userChallenge = await client
          .from('user_challenges')
          .select('progress, challenge_start_date, challenge_end_date')
          .eq('user_id', userId)
          .eq('challenge_id', challengeId)
          .maybeSingle();

      if (userChallenge != null) {
        final progress = userChallenge['progress'] as int? ?? 0;

        // ✅ محاسبه totalDays از تاریخ‌ها با مدیریت null
        int duration = 7;
        if (userChallenge['challenge_end_date'] != null &&
            userChallenge['challenge_start_date'] != null) {
          try {
            final start = DateTime.parse(
              userChallenge['challenge_start_date'].toString(),
            );
            final end = DateTime.parse(
              userChallenge['challenge_end_date'].toString(),
            );
            duration = end.difference(start).inDays + 1;
          } catch (e) {
            duration = 7;
          }
        }

        // ✅ اگر progress وجود دارد، سریع برگردان
        if (progress > 0) {
          return {'completedDays': progress, 'totalDays': duration};
        }
      }

      // ✅ 2. دریافت عادت‌های مربوط به چالش
      final habits = await client
          .from('habits')
          .select()
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);

      if (habits.isEmpty) {
        return {'completedDays': 0, 'totalDays': 7};
      }

      final habit = habits.first;

      // ✅ مدیریت null برای start_date و end_date
      if (habit['start_date'] == null || habit['end_date'] == null) {
        print(
          '⚠️ Habit start_date or end_date is null for challenge: $challengeId',
        );
        return {'completedDays': 0, 'totalDays': 7};
      }

      // ✅ پارس تاریخ‌ها با مدیریت خطا
      DateTime startDate;
      DateTime endDate;
      try {
        startDate = DateTime.parse(habit['start_date'].toString());
        endDate = DateTime.parse(habit['end_date'].toString());
      } catch (e) {
        print('❌ Error parsing dates: $e');
        return {'completedDays': 0, 'totalDays': 7};
      }

      final totalDays = endDate.difference(startDate).inDays + 1;

      // ✅ دریافت همه تاریخ‌های تکمیل شده در یک کوئری
      int completedDays = 0;
      try {
        final completions = await client
            .from('habit_completions')
            .select('date')
            .eq('habit_id', habit['id'])
            .eq('user_id', userId)
            .gte('date', startDate.toIso8601String().split('T').first)
            .lte('date', endDate.toIso8601String().split('T').first);

        completedDays = completions.length;
      } catch (e) {
        print('⚠️ Error getting completions: $e');
        // روش جایگزین - فقط روزهایی که در محدوده هستند
        final now = DateTime.now();
        for (int i = 0; i < totalDays && i < 31; i++) {
          final date = startDate.add(Duration(days: i));
          if (date.isAfter(now)) break;
          try {
            final isCompleted = await isHabitCompletedOnDate(
              habit['id'],
              userId,
              date,
            );
            if (isCompleted) completedDays++;
          } catch (e) {
            // خطا را نادیده بگیر
          }
        }
      }

      // ✅ ذخیره progress در user_challenges برای استفاده بعدی
      if (userChallenge != null) {
        try {
          await client
              .from('user_challenges')
              .update({'progress': completedDays})
              .eq('id', userChallenge['id']);
        } catch (e) {
          print('⚠️ Error updating challenge progress: $e');
        }
      }

      return {
        'completedDays': completedDays.clamp(0, totalDays),
        'totalDays': totalDays,
      };
    } catch (e) {
      print('❌ Error getting challenge progress: $e');
      return {'completedDays': 0, 'totalDays': 7};
    }
  }

  // ==================== Packages ====================
  Future<List<Package>> getPackages() async {
    if (!await isOnline()) {
      print('⚠️ Offline - skipping getPackages');
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
        // خطا را نادیده بگیر
      }
    }
  }

  // ==================== Quests ====================

  Future<List<Quest>> getQuests() async {
    if (!await isOnline()) {
      print('⚠️ Offline - skipping getQuests');
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

      // ✅ عنوان اصلی ماموریت را ذخیره کن
      final originalTitle = quest.title;

      final habit = Habit(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        title:
            '🎯 $originalTitle (0/${quest.targetCount})', // ✅ عنوان کامل با شمارنده
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

      print('✅ Quest started: $originalTitle from $today');
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

        userQuestResponse = await client
            .from('user_quests')
            .select()
            .eq('user_id', userId)
            .eq('quest_id', questId)
            .eq('is_active', true);
      }

      if (userQuestResponse.isEmpty) {
        print('⚠️ No active user_quest found');
        return null;
      }

      final userQuest = userQuestResponse.first;
      final questId = userQuest['quest_id'];
      final currentProgress = userQuest['progress'] as int? ?? 0;
      final newProgress = currentProgress + 1;

      // ✅ 3. دریافت quest
      final questResponse = await client
          .from('quests')
          .select()
          .eq('id', questId)
          .single();

      final targetCount = questResponse['target_count'] as int;
      print('📊 Quest progress: $newProgress / $targetCount');

      // ✅ 4. اگر کامل شد
      if (newProgress >= targetCount) {
        final quest = await _completeQuest(
          userId,
          userQuest['id'],
          habitId,
          questResponse,
        );
        print('✅ Quest completed: ${quest.title}');
        return quest;
      } else {
        // ✅ 5. به‌روزرسانی پیشرفت
        await client
            .from('user_quests')
            .update({'progress': newProgress})
            .eq('id', userQuest['id']);

        // ✅ 6. به‌روزرسانی عنوان عادت با عنوان اصلی
        await _updateQuestHabitTitle(habitId, newProgress, targetCount);
        print('📊 Quest progress updated to $newProgress/$targetCount');
        return null;
      }
    } catch (e) {
      print('❌ Error in updateQuestProgress: $e');
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
      // ✅ 1. به‌روزرسانی user_quests
      await client
          .from('user_quests')
          .update({
            'progress': questData['target_count'],
            'is_completed': true,
            'completed_at': DateTime.now().toIso8601String(),
            'is_active': false,
          })
          .eq('id', userQuestId);

      // ✅ 2. حذف عادت ماموریت
      await deleteHabit(habitId);

      // ✅ 3. افزودن XP
      await addXP(userId, questData['xp_reward'] as int);

      // ✅ 4. افزودن نشان (Badge)
      await _addBadgeToUser(userId, questData['badge']);

      // ✅ 5. حذف از LocalStorage
      try {
        final localStorage = LocalStorageService();
        await localStorage.deleteHabit(habitId);
        print('✅ Local habit deleted after quest completion');
      } catch (e) {
        print('⚠️ Error deleting local habit: $e');
      }

      final quest = Quest.fromMap(questData, questData['id']);
      return quest;
    } catch (e) {
      print('❌ Error completing quest: $e');
      rethrow;
    }
  }

  // ✅ اصلاح متد _updateQuestHabitTitle - بدون استفاده از Provider
  Future<void> _updateQuestHabitTitle(
    String habitId,
    int progress,
    int target,
  ) async {
    try {
      // ✅ 1. ابتدا عادت را دریافت کن
      final habit = await client
          .from('habits')
          .select('title')
          .eq('id', habitId)
          .maybeSingle();

      if (habit == null) {
        print('⚠️ Habit not found for updating title: $habitId');
        return;
      }

      // ✅ 2. عنوان اصلی را استخراج کن (بدون شمارنده قبلی)
      String originalTitle = habit['title'] ?? 'ماموریت';

      // ✅ 3. اگر عنوان شامل شمارنده است، آن را حذف کن
      // مثال: "🎯 یادگیری زبان (0/4)" -> "🎯 یادگیری زبان"
      final regex = RegExp(r'\s*\(\d+/\d+\)\s*$');
      originalTitle = originalTitle.replaceAll(regex, '').trim();

      // ✅ 4. عنوان جدید را با شمارنده بساز
      final newTitle = '$originalTitle ($progress/$target)';

      // ✅ 5. به‌روزرسانی در دیتابیس
      await client.from('habits').update({'title': newTitle}).eq('id', habitId);

      print('✅ Habit title updated: "$newTitle"');

      // ✅ 6. LocalStorage را به‌روزرسانی کن (بدون استفاده از Provider)
      await _updateLocalHabitTitle(habitId, newTitle);
    } catch (e) {
      print('❌ Error updating habit title: $e');
    }
  }

  // ✅ متد جدید برای به‌روزرسانی LocalStorage
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
        print('✅ Local habit title updated: "$newTitle"');
      }
    } catch (e) {
      print('⚠️ Error updating local habit title: $e');
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

  /// بررسی و تکمیل چالش
  Future<Map<String, dynamic>?> checkAndCompleteChallenge(
    String userId,
    String challengeId,
  ) async {
    // ✅ اگر آفلاین هستیم، null برگردان
    if (!await isOnline()) {
      print('⚠️ Offline - skipping checkAndCompleteChallenge');
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

      final habits = await getHabits(userId);
      final challengeHabits = habits
          .where((h) => h.challengeId == challengeId)
          .toList();

      if (challengeHabits.isEmpty) {
        return null;
      }

      // ✅ مدیریت null برای تاریخ‌ها
      if (userChallenge['challenge_start_date'] == null ||
          userChallenge['challenge_end_date'] == null) {
        return null;
      }

      final startDate = DateTime.parse(
        userChallenge['challenge_start_date'].toString(),
      );
      final endDate = DateTime.parse(
        userChallenge['challenge_end_date'].toString(),
      );
      final duration = challenge['challenge_duration'] as int? ?? 7;

      final maxDays = duration > 365 ? 365 : duration;
      final now = DateTime.now();

      int completedDays = 0;
      for (int i = 0; i < maxDays; i++) {
        final date = startDate.add(Duration(days: i));
        if (date.isAfter(now)) continue;

        bool allHabitsCompleted = true;
        for (var habit in challengeHabits) {
          try {
            final isCompleted = await isHabitCompletedOnDate(
              habit.id,
              userId,
              date,
            );
            if (!isCompleted) {
              allHabitsCompleted = false;
              break;
            }
          } catch (e) {
            allHabitsCompleted = false;
            break;
          }
        }
        if (allHabitsCompleted) {
          completedDays++;
        }
      }

      if (completedDays >= duration) {
        await addXP(userId, challenge['xp_reward'] as int? ?? 0);

        await client
            .from('user_challenges')
            .update({
              'is_completed': true,
              'completed_at': DateTime.now().toIso8601String(),
              'progress': 100,
              'status': 'completed',
              'is_active': false,
            })
            .eq('id', userChallenge['id']);

        for (var habit in challengeHabits) {
          await deleteHabit(habit.id);
        }

        return challenge;
      }

      if (now.isAfter(endDate) && completedDays < duration) {
        await client
            .from('user_challenges')
            .update({
              'is_completed': false,
              'is_active': false,
              'status': 'failed',
              'completed_at': now.toIso8601String(),
            })
            .eq('id', userChallenge['id']);

        for (var habit in challengeHabits) {
          await deleteHabit(habit.id);
        }
      }

      return null;
    } catch (e) {
      print('❌ Error checking challenge completion: $e');
      return null;
    }
  }

  Future<void> checkExpiredChallenges(String userId) async {
    try {
      final now = DateTime.now();

      final userChallenges = await client
          .from('user_challenges')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .eq('is_completed', false);

      for (var uc in userChallenges) {
        final challengeId = uc['challenge_id'];
        if (challengeId == null) continue;

        final challenge = await getChallengeById(challengeId);
        if (challenge == null) continue;

        final endDate = DateTime.parse(uc['challenge_end_date']);

        if (now.isAfter(endDate)) {
          final habits = await getHabits(userId);
          final challengeHabits = habits
              .where((h) => h.challengeId == challengeId)
              .toList();

          final startDate = DateTime.parse(uc['challenge_start_date']);
          final duration = challenge['challenge_duration'] as int;

          int completedDays = 0;
          for (int i = 0; i < duration; i++) {
            final date = startDate.add(Duration(days: i));
            if (date.isAfter(now)) continue;

            bool allHabitsCompleted = true;
            for (var habit in challengeHabits) {
              final isCompleted = await isHabitCompletedOnDate(
                habit.id,
                userId,
                date,
              );
              if (!isCompleted) {
                allHabitsCompleted = false;
                break;
              }
            }
            if (allHabitsCompleted) completedDays++;
          }

          if (completedDays < duration) {
            await client
                .from('user_challenges')
                .update({
                  'is_active': false,
                  'status': 'failed',
                  'completed_at': now.toIso8601String(),
                })
                .eq('id', uc['id']);

            for (var habit in challengeHabits) {
              await deleteHabit(habit.id);
            }
          }
        }
      }
    } catch (e) {
      // خطا را نادیده بگیر
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

      // ✅ محاسبه استریک هفتگی شمسی با استفاده از DateTime
      final weekday = today.weekday; // 1=Monday, 7=Sunday
      int daysToSubtract;
      if (weekday == 1) {
        // Monday
        daysToSubtract = 2; // برای رسیدن به شنبه
      } else {
        daysToSubtract = weekday - 1;
      }

      final weekStart = today.subtract(Duration(days: daysToSubtract));

      int weeklyStreak = 0;
      for (int i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        final dateStr = date.toIso8601String().split('T').first;
        final activity = await client
            .from('user_daily_activity')
            .select('is_active')
            .eq('user_id', userId)
            .eq('activity_date', dateStr)
            .maybeSingle();
        if (activity != null && activity['is_active'] == true) {
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
      // خطا را نادیده بگیر
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
    // ✅ اگر آفلاین هستیم، در صف ذخیره کن
    if (!await isOnline()) {
      print('⚠️ Offline - saving daily activity to queue');
      // می‌توانید این را در صف آفلاین ذخیره کنید
      return;
    }
    try {
      final dateStr = _getDateString(date);

      print(
        '📝 Recording daily activity: userId=$userId, date=$dateStr, isActive=$isActive',
      );

      // بررسی وجود رکورد
      final existing = await client
          .from('user_daily_activity')
          .select()
          .eq('user_id', userId)
          .eq('activity_date', dateStr)
          .maybeSingle();

      if (existing != null) {
        // ✅ به‌روزرسانی - مهم: is_active را true کن
        await client
            .from('user_daily_activity')
            .update({
              'habits_completed': habitsCompleted,
              'tasks_completed': tasksCompleted,
              'xp_earned': xpEarned,
              'is_active': isActive, // true
            })
            .eq('id', existing['id']);
        print('✅ Updated existing activity for $dateStr');
      } else {
        // ✅ ایجاد جدید
        await client.from('user_daily_activity').insert({
          'user_id': userId,
          'activity_date': dateStr,
          'habits_completed': habitsCompleted,
          'tasks_completed': tasksCompleted,
          'xp_earned': xpEarned,
          'is_active': isActive, // true
        });
        print('✅ Created new activity for $dateStr');
      }

      // بعد از ثبت فعالیت، استریک را به‌روزرسانی کن
      await updateUserStreak(userId);
    } catch (e) {
      print('❌ Error recording daily activity: $e');
      // خطا را نادیده نگیریم - برای دیباگ
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

  // ✅ متد _convertKeys
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
