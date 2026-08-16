// lib/features/explore/models/quest_model.dart

class Quest {
  final String id;
  final String title;
  final String description;
  final String icon;
  final String color;
  final int xpReward;
  final String badge;
  final int targetCount;
  final bool isActive;
  final DateTime createdAt;

  // ✅ فیلدهای جدید برای سطوح
  final String? fullDescription;
  final String? halfDescription;
  final String? basicDescription;
  final String? targetValue;

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
    this.fullDescription,
    this.halfDescription,
    this.basicDescription,
    this.targetValue,
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
      // ✅ خواندن فیلدهای سطح
      fullDescription: map['full_description']?.toString(),
      halfDescription: map['half_description']?.toString(),
      basicDescription: map['basic_description']?.toString(),
      targetValue: map['target_value']?.toString(),
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
      'full_description': fullDescription,
      'half_description': halfDescription,
      'basic_description': basicDescription,
      'target_value': targetValue,
    };
  }
}
