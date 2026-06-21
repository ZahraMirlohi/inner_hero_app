import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/arena/models/habit_model.dart';
import '../features/arena/models/task_model.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

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
  }

  Future<User?> getCurrentUser() async {
    return client.auth.currentUser;
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

  Future<bool> isHabitCompletedOnDate(
    String habitId,
    String userId,
    DateTime date,
  ) async {
    try {
      final dateStr = date.toIso8601String().substring(0, 10);
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
      final dateStr = date.toIso8601String().substring(0, 10);

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
        }
      } else {
        await client
            .from('habit_completions')
            .delete()
            .eq('habit_id', habitId)
            .eq('user_id', userId)
            .eq('date', dateStr);
      }
    } catch (e) {
      // خطا را نادیده بگیر
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
        await client
            .from('user_progress')
            .update({'total_xp': currentXP + amount})
            .eq('user_id', userId);
      } else {
        await client.from('user_progress').insert({
          'user_id': userId,
          'total_xp': amount,
        });
      }
    } catch (e) {
      // خطا را نادیده بگیر
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
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // ==================== Challenges ====================

  Future<List<Map<String, dynamic>>> getChallenges() async {
    try {
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

  Future<void> joinChallenge(String userId, String challengeId) async {
    // بررسی اینکه کاربر قبلاً ثبت‌نام نکرده باشد
    final existing = await client
        .from('user_challenges')
        .select()
        .eq('user_id', userId)
        .eq('challenge_id', challengeId);

    if (existing.isEmpty) {
      await client.from('user_challenges').insert({
        'user_id': userId,
        'challenge_id': challengeId,
        'joined_at': DateTime.now().toIso8601String(),
        'progress': 0,
        'is_completed': false,
        'is_active': true,
      });
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
      }
    } catch (e) {
      // خطا را نادیده بگیر
    }
  }

  Future<List<Map<String, dynamic>>> getUserChallenges(String userId) async {
    try {
      final response = await client
          .from('user_challenges')
          .select('*, challenges(*)')
          .eq('user_id', userId)
          .eq('is_active', true);

      return response.map((item) {
        final data = item['challenges'] as Map<String, dynamic>;
        data['userProgressId'] = item['id'];
        data['progress'] = item['progress'] ?? 0;
        data['isCompleted'] = item['is_completed'] ?? false;
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, int>> getUserChallengeProgressDetails(
    String userId,
    String challengeId,
  ) async {
    try {
      final habits = await client
          .from('habits')
          .select()
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);

      if (habits.isEmpty) {
        return {'completedDays': 0, 'totalDays': 0};
      }

      final habit = habits.first;
      final startDate = DateTime.parse(habit['start_date']);
      final endDate = DateTime.parse(habit['end_date']);

      final totalDays = endDate.difference(startDate).inDays + 1;

      int completedDays = 0;
      final now = DateTime.now();

      for (int i = 0; i < totalDays; i++) {
        final date = startDate.add(Duration(days: i));
        if (date.isAfter(now)) continue;

        final isCompleted = await isHabitCompletedOnDate(
          habit['id'],
          userId,
          date,
        );

        if (isCompleted) completedDays++;
      }

      return {'completedDays': completedDays, 'totalDays': totalDays};
    } catch (e) {
      return {'completedDays': 0, 'totalDays': 0};
    }
  }

  Future<int> getUserTotalXP(String userId) async {
    try {
      final response = await client
          .from('user_progress')
          .select('total_xp')
          .eq('user_id', userId);

      if (response.isNotEmpty) {
        return response[0]['total_xp'] ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // ==================== User Progress ====================

  Future<void> createUserProgress(String userId) async {
    try {
      await client.from('user_progress').insert({
        'user_id': userId,
        'total_xp': 0,
      });
    } catch (e) {
      print('Error creating user progress: $e');
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
        default:
          newKey = key;
      }
      return MapEntry(newKey, value);
    });
  }
}
