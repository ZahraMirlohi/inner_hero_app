// lib/features/profile/models/profile_model.dart

class UserProfile {
  final String userId;
  String name;
  String? phone;
  String? email;
  DateTime? birthDate;
  int? realAge;
  String? gender;
  DateTime registeredAt;

  // ویژگی‌های آواتار
  String avatarStyle;
  String skinColor;
  String hairStyle;
  String hairColor;
  String eyeStyle;
  String eyeColor;
  String mouthStyle;
  String accessoryType;
  String outfitStyle;
  String backgroundStyle;

  // آمار
  int totalXp;
  int weeklyStreak;
  DateTime? lastStreakUpdate;
  int currentStreak;
  int bestStreak;

  UserProfile({
    required this.userId,
    required this.name,
    this.phone,
    this.email,
    this.birthDate,
    this.realAge,
    this.gender,
    required this.registeredAt,
    this.avatarStyle = 'default',
    this.skinColor = '#F5D0B8',
    this.hairStyle = 'default',
    this.hairColor = '#4A3728',
    this.eyeStyle = 'default',
    this.eyeColor = '#4A90E2',
    this.mouthStyle = 'default',
    this.accessoryType = 'none',
    this.outfitStyle = 'default',
    this.backgroundStyle = 'default',
    this.totalXp = 0,
    this.weeklyStreak = 0,
    this.lastStreakUpdate,
    this.currentStreak = 0,
    this.bestStreak = 0,
  });

  // ✅ محاسبه لول بر اساس کل XP (هر ۱۰۰ XP یک لول)
  int get level {
    return (totalXp / 100).floor() + 1;
  }

  // ✅ محاسبه XP مورد نیاز برای لول بعدی
  int get xpNeededForNextLevel {
    final currentLevelXp = (level - 1) * 100;
    return currentLevelXp + 100 - totalXp;
  }

  // ✅ درصد پیشرفت به لول بعدی
  double get levelProgress {
    final currentLevelXp = (level - 1) * 100;
    final xpInCurrentLevel = totalXp - currentLevelXp;
    return xpInCurrentLevel / 100;
  }

  // محاسبه سن آواتار (بر اساس تاریخ ثبت‌نام)
  int get avatarAge {
    final now = DateTime.now();
    final days = now.difference(registeredAt).inDays;
    return days + 1;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'birth_date': birthDate?.toIso8601String().split('T').first,
      'real_age': realAge,
      'gender': gender,
      'avatar_style': avatarStyle,
      'skin_color': skinColor,
      'hair_style': hairStyle,
      'hair_color': hairColor,
      'eye_style': eyeStyle,
      'eye_color': eyeColor,
      'mouth_style': mouthStyle,
      'accessory_type': accessoryType,
      'outfit_style': outfitStyle,
      'background_style': backgroundStyle,
      'total_xp': totalXp,
      'weekly_streak': weeklyStreak,
      'last_streak_update': lastStreakUpdate
          ?.toIso8601String()
          .split('T')
          .first,
      'current_streak': currentStreak,
      'best_streak': bestStreak,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map, String userId) {
    return UserProfile(
      userId: userId,
      name: map['name'] ?? 'کاربر',
      phone: map['phone'],
      email: map['email'],
      birthDate: map['birth_date'] != null
          ? DateTime.tryParse(map['birth_date'])
          : null,
      realAge: map['real_age'],
      gender: map['gender'],
      registeredAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      avatarStyle: map['avatar_style'] ?? 'default',
      skinColor: map['skin_color'] ?? '#F5D0B8',
      hairStyle: map['hair_style'] ?? 'default',
      hairColor: map['hair_color'] ?? '#4A3728',
      eyeStyle: map['eye_style'] ?? 'default',
      eyeColor: map['eye_color'] ?? '#4A90E2',
      mouthStyle: map['mouth_style'] ?? 'default',
      accessoryType: map['accessory_type'] ?? 'none',
      outfitStyle: map['outfit_style'] ?? 'default',
      backgroundStyle: map['background_style'] ?? 'default',
      totalXp: map['total_xp'] ?? 0,
      weeklyStreak: map['weekly_streak'] ?? 0,
      lastStreakUpdate: map['last_streak_update'] != null
          ? DateTime.tryParse(map['last_streak_update'])
          : null,
      currentStreak: map['current_streak'] ?? 0,
      bestStreak: map['best_streak'] ?? 0,
    );
  }
}
