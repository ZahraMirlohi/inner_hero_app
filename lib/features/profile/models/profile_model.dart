class UserProfile {
  final String userId;
  String name;
  String? uniqueId;
  String? username; // ✅ جدید: نام کاربری یکتا
  String? avatarUrl; // ✅ جدید: لینک عکس پروفایل
  DateTime? usernameUpdatedAt; // ✅ جدید: زمان آخرین تغییر
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

  UserProfile copyWith({
    String? name,
    String? uniqueId,
    String? username,
    String? avatarUrl,
    DateTime? usernameUpdatedAt,
    String? phone,
    String? email,
    DateTime? birthDate,
    int? realAge,
    String? gender,
    DateTime? registeredAt,
    String? avatarStyle,
    String? skinColor,
    String? hairStyle,
    String? hairColor,
    String? eyeStyle,
    String? eyeColor,
    String? mouthStyle,
    String? accessoryType,
    String? outfitStyle,
    String? backgroundStyle,
    int? totalXp,
    int? weeklyStreak,
    DateTime? lastStreakUpdate,
    int? currentStreak,
    int? bestStreak,
  }) {
    return UserProfile(
      userId: userId,
      name: name ?? this.name,
      uniqueId: uniqueId ?? this.uniqueId,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      usernameUpdatedAt: usernameUpdatedAt ?? this.usernameUpdatedAt,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      birthDate: birthDate ?? this.birthDate,
      realAge: realAge ?? this.realAge,
      gender: gender ?? this.gender,
      registeredAt: registeredAt ?? this.registeredAt,
      avatarStyle: avatarStyle ?? this.avatarStyle,
      skinColor: skinColor ?? this.skinColor,
      hairStyle: hairStyle ?? this.hairStyle,
      hairColor: hairColor ?? this.hairColor,
      eyeStyle: eyeStyle ?? this.eyeStyle,
      eyeColor: eyeColor ?? this.eyeColor,
      mouthStyle: mouthStyle ?? this.mouthStyle,
      accessoryType: accessoryType ?? this.accessoryType,
      outfitStyle: outfitStyle ?? this.outfitStyle,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      totalXp: totalXp ?? this.totalXp,
      weeklyStreak: weeklyStreak ?? this.weeklyStreak,
      lastStreakUpdate: lastStreakUpdate ?? this.lastStreakUpdate,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
    );
  }

  UserProfile({
    required this.userId,
    required this.name,
    this.uniqueId,
    this.username,
    this.avatarUrl,
    this.usernameUpdatedAt,
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

  int get level {
    return (totalXp / 100).floor() + 1;
  }

  int get xpNeededForNextLevel {
    final currentLevelXp = (level - 1) * 100;
    return currentLevelXp + 100 - totalXp;
  }

  double get levelProgress {
    final currentLevelXp = (level - 1) * 100;
    final xpInCurrentLevel = totalXp - currentLevelXp;
    return xpInCurrentLevel / 100;
  }

  int get avatarAge {
    final now = DateTime.now();
    final days = now.difference(registeredAt).inDays;
    return days + 1;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'unique_id': uniqueId,
      'username': username, // ✅ جدید
      'avatar_url': avatarUrl, // ✅ جدید
      'username_updated_at': usernameUpdatedAt // ✅ جدید
          ?.toIso8601String(),
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
      'last_streak_update':
          lastStreakUpdate?.toIso8601String().split('T').first,
      'current_streak': currentStreak,
      'best_streak': bestStreak,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map, String userId) {
    return UserProfile(
      userId: userId,
      name: map['name'] ?? 'کاربر',
      uniqueId: map['unique_id'],
      username: map['username'], // ✅ جدید
      avatarUrl: map['avatar_url'], // ✅ جدید
      usernameUpdatedAt: map['username_updated_at'] != null // ✅ جدید
          ? DateTime.tryParse(map['username_updated_at'])
          : null,
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

  /// آیا کاربر نام کاربری دارد؟
  bool get hasUsername => username != null && username!.isNotEmpty;

  /// آیا کاربر عکس پروفایل دارد؟
  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;

  /// نام نمایشی (با @)
  String get displayUsername => hasUsername ? '@$username' : '';

  /// ✅ جدید: آیا می‌تواند username را عوض کند؟ (۱ دقیقه بین هر تغییر)
  bool get canChangeUsername {
    if (usernameUpdatedAt == null) return true;
    final secondsSinceChange =
        DateTime.now().difference(usernameUpdatedAt!).inSeconds;
    return secondsSinceChange >= 60; // ۶۰ ثانیه
  }

  /// ✅ جدید: ثانیه‌های باقی‌مانده تا تغییر بعدی
  int get secondsUntilUsernameChange {
    if (usernameUpdatedAt == null) return 0;
    final secondsSinceChange =
        DateTime.now().difference(usernameUpdatedAt!).inSeconds;
    if (secondsSinceChange >= 60) return 0;
    return 60 - secondsSinceChange;
  }
}
