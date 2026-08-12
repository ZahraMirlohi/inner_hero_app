// lib/features/chat/models/challenge_invite.dart

enum ChallengeStatus {
  pending, // منتظر پاسخ
  accepted, // پذیرفته شده
  active, // در حال انجام ✅ این باید وجود داشته باشد
  completed, // کامل شده
  cancelled, // لغو شده
  rejected, // رد شده
}

enum ChallengeDayStatus { not_started, in_progress, completed, failed }

class ChallengeInvite {
  final String id;
  final String creatorId;
  final String creatorName;
  final String opponentId;
  final String opponentName;
  final String title;
  final String description;
  final List<ChallengeHabit> habits;
  final int duration; // تعداد روزها
  final int xpReward;
  final DateTime startDate;
  final DateTime? endDate;
  final ChallengeStatus status;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final Map<String, List<ChallengeDayProgress>>
  progress; // userId -> List<ChallengeDayProgress>

  ChallengeInvite({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.opponentId,
    required this.opponentName,
    required this.title,
    this.description = '',
    required this.habits,
    required this.duration,
    required this.xpReward,
    required this.startDate,
    this.endDate,
    this.status = ChallengeStatus.pending,
    required this.createdAt,
    this.acceptedAt,
    this.completedAt,
    this.progress = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'creator_id': creatorId,
      'creator_name': creatorName,
      'opponent_id': opponentId,
      'opponent_name': opponentName,
      'title': title,
      'description': description,
      'habits': habits.map((h) => h.toMap()).toList(),
      'duration': duration,
      'xp_reward': xpReward,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'status': status.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'progress': progress.map((userId, days) {
        return MapEntry(userId, days.map((d) => d.toMap()).toList());
      }),
    };
  }

  factory ChallengeInvite.fromMap(Map<String, dynamic> map) {
    return ChallengeInvite(
      id: map['id'] ?? '',
      creatorId: map['creator_id'] ?? '',
      creatorName: map['creator_name'] ?? 'کاربر',
      opponentId: map['opponent_id'] ?? '',
      opponentName: map['opponent_name'] ?? 'کاربر',
      title: map['title'] ?? 'چالش جدید',
      description: map['description'] ?? '',
      habits: (map['habits'] as List? ?? [])
          .map((h) => ChallengeHabit.fromMap(h))
          .toList(),
      duration: map['duration'] ?? 7,
      xpReward: map['xp_reward'] ?? 100,
      startDate: DateTime.parse(map['start_date']),
      endDate: map['end_date'] != null ? DateTime.parse(map['end_date']) : null,
      status: ChallengeStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => ChallengeStatus.pending,
      ),
      createdAt: DateTime.parse(map['created_at']),
      acceptedAt: map['accepted_at'] != null
          ? DateTime.parse(map['accepted_at'])
          : null,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'])
          : null,
      progress: (map['progress'] as Map? ?? {}).map((userId, days) {
        return MapEntry(
          userId as String,
          (days as List).map((d) => ChallengeDayProgress.fromMap(d)).toList(),
        );
      }),
    );
  }

  // محاسبه روز جاری چالش (از ۱ شروع می‌شه)
  int get currentDay {
    final now = DateTime.now();
    final diff = now.difference(startDate).inDays;
    return diff.clamp(0, duration) + 1;
  }

  // آیا چالش امروز فعال است؟
  bool get isActiveToday {
    if (status != ChallengeStatus.active) return false;
    final day = currentDay;
    return day >= 1 && day <= duration;
  }

  // درصد پیشرفت کلی
  double get overallProgress {
    if (status == ChallengeStatus.completed) return 1.0;
    if (status != ChallengeStatus.active) return 0.0;
    return currentDay / duration;
  }

  // دریافت وضعیت روز جاری برای یک کاربر
  ChallengeDayStatus? getDayStatus(String userId) {
    final userProgress = progress[userId];
    if (userProgress == null) return null;
    final todayIndex = currentDay - 1;
    if (todayIndex < 0 || todayIndex >= userProgress.length) return null;
    return userProgress[todayIndex].status;
  }

  // آیا کاربر امروز رو کامل کرده؟
  bool isUserCompletedToday(String userId) {
    final status = getDayStatus(userId);
    return status == ChallengeDayStatus.completed;
  }

  // چند روز از چالش توسط کاربر کامل شده؟
  int getUserCompletedDays(String userId) {
    final userProgress = progress[userId] ?? [];
    return userProgress
        .where((d) => d.status == ChallengeDayStatus.completed)
        .length;
  }

  // آیا چالش توسط کاربر کامل شده؟
  bool isUserCompletedChallenge(String userId) {
    return getUserCompletedDays(userId) >= duration;
  }

  // دریافت پیام انگیزشی
  String getMotivationalMessage(String userId, String opponentId) {
    final myDays = getUserCompletedDays(userId);
    final opponentDays = getUserCompletedDays(opponentId);

    if (myDays >= duration && opponentDays >= duration) {
      return '🎉 هر دو قهرمان! شما با هم چالش رو کامل کردید!';
    } else if (myDays >= duration) {
      return '🏆 تبریک! شما چالش رو کامل کردید!';
    } else if (opponentDays >= duration) {
      return '💪 ${opponentName} چالش رو کامل کرد! شما هم ادامه بده!';
    } else if (myDays > opponentDays) {
      return '🔥 شما جلوتر هستید! ادامه بده!';
    } else if (opponentDays > myDays) {
      return '💪 ${opponentName} جلوتر هست! شما هم عقب نیفت!';
    } else {
      return '🤝 با هم پیش میرید! ادامه بدید!';
    }
  }

  // آیا کاربر می‌تونه امروز رو تیک بزنه؟
  bool canUserCompleteToday(String userId) {
    if (status != ChallengeStatus.active) return false;
    if (isUserCompletedToday(userId)) return false;
    final day = currentDay;
    return day >= 1 && day <= duration;
  }

  // آیا کاربر می‌تونه تیک امروز رو برداره؟
  bool canUserUncompleteToday(String userId) {
    if (status != ChallengeStatus.active) return false;
    if (!isUserCompletedToday(userId)) return false;
    final day = currentDay;
    // فقط روز جاری قابل تغییره
    return day >= 1 && day <= duration;
  }
}

class ChallengeHabit {
  final String id;
  final String title;
  final String description;
  final String iconName;
  final int iconColor;
  final int backgroundColor;

  ChallengeHabit({
    required this.id,
    required this.title,
    this.description = '',
    this.iconName = 'fitness_center',
    this.iconColor = 0xFF4A90E2,
    this.backgroundColor = 0xFFF5F5F5,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'icon_name': iconName,
      'icon_color': iconColor,
      'background_color': backgroundColor,
    };
  }

  factory ChallengeHabit.fromMap(Map<String, dynamic> map) {
    return ChallengeHabit(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      iconName: map['icon_name'] ?? 'fitness_center',
      iconColor: map['icon_color'] ?? 0xFF4A90E2,
      backgroundColor: map['background_color'] ?? 0xFFF5F5F5,
    );
  }
}

class ChallengeDayProgress {
  final int day;
  final ChallengeDayStatus status;
  final List<String> completedHabitIds;
  final DateTime? completedAt;

  ChallengeDayProgress({
    required this.day,
    this.status = ChallengeDayStatus.not_started,
    this.completedHabitIds = const [],
    this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'status': status.toString().split('.').last,
      'completed_habit_ids': completedHabitIds,
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  factory ChallengeDayProgress.fromMap(Map<String, dynamic> map) {
    return ChallengeDayProgress(
      day: map['day'] ?? 0,
      status: ChallengeDayStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => ChallengeDayStatus.not_started,
      ),
      completedHabitIds: List<String>.from(map['completed_habit_ids'] ?? []),
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'])
          : null,
    );
  }
}
