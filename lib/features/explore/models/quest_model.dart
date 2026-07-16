class Quest {
  final String id;
  final String title;
  final String description;
  final String icon;
  final String color;
  final int xpReward;
  final String badge;
  final int targetCount; // تعداد روزهای مورد نیاز
  final bool isActive;
  final DateTime createdAt;

  Quest({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.xpReward,
    required this.badge,
    required this.targetCount,
    this.isActive = true,
    required this.createdAt,
  });

  factory Quest.fromMap(Map<String, dynamic> map, String id) {
    return Quest(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      icon: map['icon'] ?? 'flag',
      color: map['color'] ?? '#FF9F43',
      xpReward: map['xp_reward'] ?? 100,
      badge: map['badge'] ?? '🎯',
      targetCount: map['target_count'] ?? 7,
      isActive: map['is_active'] ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'icon': icon,
      'color': color,
      'xp_reward': xpReward,
      'badge': badge,
      'target_count': targetCount,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
