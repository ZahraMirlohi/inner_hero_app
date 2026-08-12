// lib/services/challenge_invite_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/chat/models/challenge_invite.dart';
import 'supabase_service.dart';

class ChallengeInviteService {
  final SupabaseClient _client = Supabase.instance.client;
  final SupabaseService _supabase = SupabaseService();

  // ==================== ایجاد چالش جدید ====================

  Future<ChallengeInvite?> createChallenge({
    required String creatorId,
    required String creatorName,
    required String opponentId,
    required String opponentName,
    required String title,
    required String description,
    required List<ChallengeHabit> habits,
    required int duration,
    required int xpReward,
    required DateTime startDate,
  }) async {
    try {
      final challenge = ChallengeInvite(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        creatorId: creatorId,
        creatorName: creatorName,
        opponentId: opponentId,
        opponentName: opponentName,
        title: title,
        description: description,
        habits: habits,
        duration: duration,
        xpReward: xpReward,
        startDate: startDate,
        endDate: startDate.add(Duration(days: duration - 1)),
        status: ChallengeStatus.pending,
        createdAt: DateTime.now(),
        progress: {
          creatorId: List.generate(
            duration,
            (i) => ChallengeDayProgress(day: i + 1),
          ),
          opponentId: List.generate(
            duration,
            (i) => ChallengeDayProgress(day: i + 1),
          ),
        },
      );

      await _client.from('challenge_invites').insert(challenge.toMap());

      return challenge;
    } catch (e) {
      print('❌ Error creating challenge: $e');
      return null;
    }
  }

  // ==================== دریافت چالش‌های کاربر ====================

  Future<List<ChallengeInvite>> getUserChallenges(String userId) async {
    try {
      final response = await _client
          .from('challenge_invites')
          .select()
          .or('creator_id.eq.$userId,opponent_id.eq.$userId')
          .order('created_at', ascending: false);

      return response.map((data) => ChallengeInvite.fromMap(data)).toList();
    } catch (e) {
      print('❌ Error getting user challenges: $e');
      return [];
    }
  }

  Future<ChallengeInvite?> getChallengeById(String challengeId) async {
    try {
      final response = await _client
          .from('challenge_invites')
          .select()
          .eq('id', challengeId)
          .maybeSingle();

      if (response == null) return null;
      return ChallengeInvite.fromMap(response);
    } catch (e) {
      print('❌ Error getting challenge: $e');
      return null;
    }
  }

  // ==================== پاسخ به دعوت ====================

  Future<bool> respondToChallenge(String challengeId, bool accept) async {
    try {
      final status = accept ? 'accepted' : 'rejected';

      await _client
          .from('challenge_invites')
          .update({
            'status': status,
            'accepted_at': accept ? DateTime.now().toIso8601String() : null,
          })
          .eq('id', challengeId);

      // اگر قبول شده، وضعیت رو به active تغییر بده
      if (accept) {
        await _client
            .from('challenge_invites')
            .update({'status': 'active'})
            .eq('id', challengeId);
      }

      return true;
    } catch (e) {
      print('❌ Error responding to challenge: $e');
      return false;
    }
  }

  // ==================== تیک زدن عادت امروز ====================

  Future<bool> completeHabitToday({
    required String challengeId,
    required String userId,
    required String habitId,
  }) async {
    try {
      final challenge = await getChallengeById(challengeId);
      if (challenge == null) return false;

      // بررسی اینکه چالش فعال باشد
      if (challenge.status != ChallengeStatus.active) return false;

      final todayIndex = challenge.currentDay - 1;
      if (todayIndex < 0 || todayIndex >= challenge.duration) return false;

      // بررسی اینکه کاربر می‌تونه امروز رو تیک بزنه
      if (!challenge.canUserCompleteToday(userId)) return false;

      // به‌روزرسانی progress
      var progress = Map<String, List<ChallengeDayProgress>>.from(
        challenge.progress,
      );

      if (!progress.containsKey(userId)) {
        progress[userId] = List.generate(
          challenge.duration,
          (i) => ChallengeDayProgress(day: i + 1),
        );
      }

      var userProgress = List<ChallengeDayProgress>.from(progress[userId]!);
      var todayProgress = userProgress[todayIndex];

      // اضافه کردن habitId به لیست کامل شده‌ها
      var completedIds = List<String>.from(todayProgress.completedHabitIds);
      if (!completedIds.contains(habitId)) {
        completedIds.add(habitId);
      }

      // اگر همه عادت‌ها کامل شده، وضعیت رو به completed تغییر بده
      final allHabitsCompleted = completedIds.length >= challenge.habits.length;
      final newStatus = allHabitsCompleted
          ? ChallengeDayStatus.completed
          : ChallengeDayStatus.in_progress;

      userProgress[todayIndex] = ChallengeDayProgress(
        day: todayProgress.day,
        status: newStatus,
        completedHabitIds: completedIds,
        completedAt: allHabitsCompleted ? DateTime.now() : null,
      );

      progress[userId] = userProgress;

      // ذخیره در دیتابیس
      await _client
          .from('challenge_invites')
          .update({
            'progress': progress.map((userId, days) {
              return MapEntry(userId, days.map((d) => d.toMap()).toList());
            }),
          })
          .eq('id', challengeId);

      // بررسی کامل شدن کل چالش
      await _checkChallengeCompletion(challengeId);

      return true;
    } catch (e) {
      print('❌ Error completing habit today: $e');
      return false;
    }
  }

  // ==================== برداشتن تیک عادت امروز ====================

  Future<bool> uncompleteHabitToday({
    required String challengeId,
    required String userId,
    required String habitId,
  }) async {
    try {
      final challenge = await getChallengeById(challengeId);
      if (challenge == null) return false;

      // بررسی اینکه چالش فعال باشد
      if (challenge.status != ChallengeStatus.active) return false;

      final todayIndex = challenge.currentDay - 1;
      if (todayIndex < 0 || todayIndex >= challenge.duration) return false;

      // بررسی اینکه کاربر می‌تونه تیک امروز رو برداره
      if (!challenge.canUserUncompleteToday(userId)) return false;

      // به‌روزرسانی progress
      var progress = Map<String, List<ChallengeDayProgress>>.from(
        challenge.progress,
      );

      if (!progress.containsKey(userId)) {
        return false;
      }

      var userProgress = List<ChallengeDayProgress>.from(progress[userId]!);
      var todayProgress = userProgress[todayIndex];

      // حذف habitId از لیست کامل شده‌ها
      var completedIds = List<String>.from(todayProgress.completedHabitIds);
      completedIds.remove(habitId);

      final newStatus = completedIds.isEmpty
          ? ChallengeDayStatus.not_started
          : ChallengeDayStatus.in_progress;

      userProgress[todayIndex] = ChallengeDayProgress(
        day: todayProgress.day,
        status: newStatus,
        completedHabitIds: completedIds,
        completedAt: null,
      );

      progress[userId] = userProgress;

      // ذخیره در دیتابیس
      await _client
          .from('challenge_invites')
          .update({
            'progress': progress.map((userId, days) {
              return MapEntry(userId, days.map((d) => d.toMap()).toList());
            }),
          })
          .eq('id', challengeId);

      return true;
    } catch (e) {
      print('❌ Error uncompleting habit today: $e');
      return false;
    }
  }

  // ==================== بررسی کامل شدن چالش ====================

  Future<void> _checkChallengeCompletion(String challengeId) async {
    try {
      final challenge = await getChallengeById(challengeId);
      if (challenge == null) return;

      if (challenge.status != ChallengeStatus.active) return;

      final creatorCompleted = challenge.isUserCompletedChallenge(
        challenge.creatorId,
      );
      final opponentCompleted = challenge.isUserCompletedChallenge(
        challenge.opponentId,
      );

      if (creatorCompleted || opponentCompleted) {
        // حداقل یکی کامل کرده
        final status = (creatorCompleted && opponentCompleted)
            ? 'completed'
            : 'completed';

        await _client
            .from('challenge_invites')
            .update({
              'status': status,
              'completed_at': DateTime.now().toIso8601String(),
            })
            .eq('id', challengeId);

        // اضافه کردن XP به برندگان
        if (creatorCompleted) {
          await _supabase.addXP(challenge.creatorId, challenge.xpReward);
        }
        if (opponentCompleted) {
          await _supabase.addXP(challenge.opponentId, challenge.xpReward);
        }
      }
    } catch (e) {
      print('❌ Error checking challenge completion: $e');
    }
  }

  // ==================== انصراف از چالش ====================

  Future<bool> cancelChallenge({
    required String challengeId,
    required String userId,
  }) async {
    try {
      final challenge = await getChallengeById(challengeId);
      if (challenge == null) return false;

      if (challenge.status != ChallengeStatus.active) return false;
      if (challenge.creatorId != userId && challenge.opponentId != userId)
        return false;

      // جریمه: ۲۰٪ از پاداش XP
      final penalty = (challenge.xpReward * 0.2).toInt();
      await _supabase.removeXP(userId, penalty);

      await _client
          .from('challenge_invites')
          .update({'status': 'cancelled'})
          .eq('id', challengeId);

      return true;
    } catch (e) {
      print('❌ Error cancelling challenge: $e');
      return false;
    }
  }
}
