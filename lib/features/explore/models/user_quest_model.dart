class UserQuest {
  final String id;
  final String userId;
  final String questId;
  final String? habitId;
  final int progress;
  final bool isCompleted;
  final DateTime startedAt;
  final DateTime? completedAt;
  final bool isActive;
  final DateTime createdAt;

  UserQuest({
    required this.id,
    required this.userId,
    required this.questId,
    this.habitId,
    this.progress = 0,
    this.isCompleted = false,
    required this.startedAt,
    this.completedAt,
    this.isActive = true,
    required this.createdAt,
  });

  factory UserQuest.fromMap(Map<String, dynamic> map, String id) {
    return UserQuest(
      id: id,
      userId: map['user_id'] ?? '',
      questId: map['quest_id'] ?? '',
      habitId: map['habit_id'],
      progress: map['progress'] ?? 0,
      isCompleted: map['is_completed'] ?? false,
      startedAt: DateTime.parse(
        map['started_at'] ?? DateTime.now().toIso8601String(),
      ),
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'])
          : null,
      isActive: map['is_active'] ?? true,
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'quest_id': questId,
      'habit_id': habitId,
      'progress': progress,
      'is_completed': isCompleted,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
