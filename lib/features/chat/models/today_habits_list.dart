// lib/features/chat/models/today_habits_list.dart

class TodayHabitsList {
  final String userId;
  final String userName;
  final DateTime date;
  final List<TodayHabitItem> habits;
  final List<TodayTaskItem> tasks;
  final List<TodayChallengeItem> challenges;
  final List<TodayQuestItem> quests;
  final int totalItems;
  final int completedItems;

  TodayHabitsList({
    required this.userId,
    required this.userName,
    required this.date,
    required this.habits,
    required this.tasks,
    required this.challenges,
    required this.quests,
    required this.totalItems,
    required this.completedItems,
  });

  Map<String, dynamic> toMetadata() {
    return {
      'userId': userId,
      'userName': userName,
      'date': date.toIso8601String(),
      'habits': habits.map((h) => h.toMap()).toList(),
      'tasks': tasks.map((t) => t.toMap()).toList(),
      'challenges': challenges.map((c) => c.toMap()).toList(),
      'quests': quests.map((q) => q.toMap()).toList(),
      'totalItems': totalItems,
      'completedItems': completedItems,
      'type': 'today_habits_list',
    };
  }

  factory TodayHabitsList.fromMetadata(Map<String, dynamic> metadata) {
    return TodayHabitsList(
      userId: metadata['userId'] ?? '',
      userName: metadata['userName'] ?? 'کاربر',
      date: DateTime.parse(metadata['date']),
      habits: (metadata['habits'] as List? ?? [])
          .map((h) => TodayHabitItem.fromMap(h))
          .toList(),
      tasks: (metadata['tasks'] as List? ?? [])
          .map((t) => TodayTaskItem.fromMap(t))
          .toList(),
      challenges: (metadata['challenges'] as List? ?? [])
          .map((c) => TodayChallengeItem.fromMap(c))
          .toList(),
      quests: (metadata['quests'] as List? ?? [])
          .map((q) => TodayQuestItem.fromMap(q))
          .toList(),
      totalItems: metadata['totalItems'] ?? 0,
      completedItems: metadata['completedItems'] ?? 0,
    );
  }

  double get completionRate {
    return totalItems > 0 ? completedItems / totalItems : 0.0;
  }

  String get completionMessage {
    final rate = completionRate;
    if (rate >= 0.9) return '🔥 عالی! تقریباً همه کارها رو انجام دادی!';
    if (rate >= 0.7) return '💪 خیلی خوب! ادامه بده!';
    if (rate >= 0.5) return '📈 نصف کارها رو انجام دادی!';
    if (rate >= 0.3) return '🌱 شروع خوبی داری!';
    if (rate > 0) return '🚀 هر قدم کوچک مهمه!';
    return '💪 امروز رو شروع کن!';
  }
}

class TodayHabitItem {
  final String id;
  final String title;
  final String iconName;
  final int iconColor;
  final bool isCompleted;
  final String? challengeId;
  final String? questId;

  TodayHabitItem({
    required this.id,
    required this.title,
    required this.iconName,
    required this.iconColor,
    required this.isCompleted,
    this.challengeId,
    this.questId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'iconName': iconName,
      'iconColor': iconColor,
      'isCompleted': isCompleted,
      'challengeId': challengeId,
      'questId': questId,
    };
  }

  factory TodayHabitItem.fromMap(Map<String, dynamic> map) {
    return TodayHabitItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      iconName: map['iconName'] ?? 'fitness_center',
      iconColor: map['iconColor'] ?? 0xFF4A90E2,
      isCompleted: map['isCompleted'] ?? false,
      challengeId: map['challengeId'],
      questId: map['questId'],
    );
  }

  bool get isChallenge => challengeId != null;
  bool get isQuest => questId != null;
}

class TodayTaskItem {
  final String id;
  final String title;
  final bool isCompleted;

  TodayTaskItem({
    required this.id,
    required this.title,
    required this.isCompleted,
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'title': title, 'isCompleted': isCompleted};
  }

  factory TodayTaskItem.fromMap(Map<String, dynamic> map) {
    return TodayTaskItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}

class TodayChallengeItem {
  final String id;
  final String title;
  final int progress;
  final int totalDays;
  final bool isCompleted;

  TodayChallengeItem({
    required this.id,
    required this.title,
    required this.progress,
    required this.totalDays,
    required this.isCompleted,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'progress': progress,
      'totalDays': totalDays,
      'isCompleted': isCompleted,
    };
  }

  factory TodayChallengeItem.fromMap(Map<String, dynamic> map) {
    return TodayChallengeItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      progress: map['progress'] ?? 0,
      totalDays: map['totalDays'] ?? 0,
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}

class TodayQuestItem {
  final String id;
  final String title;
  final int progress;
  final int targetCount;
  final bool isCompleted;

  TodayQuestItem({
    required this.id,
    required this.title,
    required this.progress,
    required this.targetCount,
    required this.isCompleted,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'progress': progress,
      'targetCount': targetCount,
      'isCompleted': isCompleted,
    };
  }

  factory TodayQuestItem.fromMap(Map<String, dynamic> map) {
    return TodayQuestItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      progress: map['progress'] ?? 0,
      targetCount: map['targetCount'] ?? 0,
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}
