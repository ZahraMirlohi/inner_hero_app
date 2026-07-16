// lib/features/profile/models/character_model.dart

class Character {
  final String id;
  final String userId;
  String name;
  String heroClass; // doctor, general, athlete, scientist, warrior, mage, etc.
  String outfit; // current outfit
  String accessory; // current accessory
  String background; // current background
  String catchphrase; // تکه‌کلام
  String bgMusic; // موسیقی پس‌زمینه
  String currentAnimation; // idle, dance, action, victory, etc.
  int level;
  int xp;
  int totalXp;
  int streak;
  int bestStreak;
  int badges;
  DateTime createdAt;
  DateTime lastActive;

  Character({
    required this.id,
    required this.userId,
    this.name = 'قهرمان',
    this.heroClass = 'warrior',
    this.outfit = 'default',
    this.accessory = 'none',
    this.background = 'default',
    this.catchphrase = 'من قهرمان درونم هستم!',
    this.bgMusic = 'default',
    this.currentAnimation = 'idle',
    this.level = 1,
    this.xp = 0,
    this.totalXp = 0,
    this.streak = 0,
    this.bestStreak = 0,
    this.badges = 0,
    required this.createdAt,
    required this.lastActive,
  });

  // محاسبه سن کاراکتر بر اساس روزهای ثبت‌نام
  int get characterAge {
    final now = DateTime.now();
    final days = now.difference(createdAt).inDays;
    return days + 1; // روز اول = 1
  }

  // محاسبه درصد پیشرفت به لول بعدی
  double get levelProgress {
    final xpNeeded = level * 100;
    return (xp / xpNeeded).clamp(0.0, 1.0);
  }

  // محاسبه لول بر اساس کل XP
  static int calculateLevel(int totalXp) {
    return (totalXp / 100).floor() + 1;
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'name': name,
      'hero_class': heroClass,
      'outfit': outfit,
      'accessory': accessory,
      'background': background,
      'catchphrase': catchphrase,
      'bg_music': bgMusic,
      'current_animation': currentAnimation,
      'level': level,
      'xp': xp,
      'total_xp': totalXp,
      'streak': streak,
      'best_streak': bestStreak,
      'badges': badges,
      'created_at': createdAt.toIso8601String(),
      'last_active': lastActive.toIso8601String(),
    };
  }

  factory Character.fromMap(Map<String, dynamic> map, String id) {
    return Character(
      id: id,
      userId: map['user_id'] ?? '',
      name: map['name'] ?? 'قهرمان',
      heroClass: map['hero_class'] ?? 'warrior',
      outfit: map['outfit'] ?? 'default',
      accessory: map['accessory'] ?? 'none',
      background: map['background'] ?? 'default',
      catchphrase: map['catchphrase'] ?? 'من قهرمان درونم هستم!',
      bgMusic: map['bg_music'] ?? 'default',
      currentAnimation: map['current_animation'] ?? 'idle',
      level: map['level'] ?? 1,
      xp: map['xp'] ?? 0,
      totalXp: map['total_xp'] ?? 0,
      streak: map['streak'] ?? 0,
      bestStreak: map['best_streak'] ?? 0,
      badges: map['badges'] ?? 0,
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      lastActive: DateTime.parse(
        map['last_active'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
