import 'package_habit_model.dart';

class Package {
  final String id;
  final String title;
  final String description;
  final String icon;
  final String color;
  final String backgroundColor;
  final String category;
  final List<PackageHabit> habits;
  final bool isActive;
  final int xpReward;
  final String badge;
  final DateTime createdAt;

  Package({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.category,
    required this.habits,
    this.isActive = true,
    this.xpReward = 50,
    this.badge = '📦',
    required this.createdAt,
  });

  factory Package.fromMap(Map<String, dynamic> map, String id) {
    List<PackageHabit> habitList = [];
    try {
      final habitsData = map['habits'] as List? ?? [];
      habitList = habitsData.map((h) => PackageHabit.fromMap(h)).toList();
    } catch (e) {
      // خطا در parsing
    }

    return Package(
      id: id,
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      icon: map['icon']?.toString() ?? 'fitness_center',
      color: map['color']?.toString() ?? '#4A90E2',
      backgroundColor: map['background_color']?.toString() ?? '#F5F5F5',
      category: map['category']?.toString() ?? 'other',
      habits: habitList,
      isActive: map['is_active'] ?? true,
      xpReward: map['xp_reward'] ?? 50,
      badge: map['badge']?.toString() ?? '📦',
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
      'background_color': backgroundColor,
      'category': category,
      'habits': habits.map((h) => h.toMap()).toList(),
      'is_active': isActive,
      'xp_reward': xpReward,
      'badge': badge,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
