// lib/features/profile/models/user_personality.dart

enum Gender { male, female, other }

// ✅ اضافه کردن MBTI Type
enum MBTIType {
  INTJ,
  INTP,
  ENTJ,
  ENTP, // تحلیلگران
  INFJ,
  INFP,
  ENFJ,
  ENFP, // دیپلمات‌ها
  ISTJ,
  ISFJ,
  ESTJ,
  ESFJ, // نگهبانان
  ISTP,
  ISFP,
  ESTP,
  ESFP, // کاوشگران
}

extension MBTITypeExtension on MBTIType {
  String get displayName {
    switch (this) {
      case MBTIType.INTJ:
        return 'معمار (INTJ)';
      case MBTIType.INTP:
        return 'منطق‌گرا (INTP)';
      case MBTIType.ENTJ:
        return 'فرمانده (ENTJ)';
      case MBTIType.ENTP:
        return 'مباحثه‌گر (ENTP)';
      case MBTIType.INFJ:
        return 'مدافع (INFJ)';
      case MBTIType.INFP:
        return 'میانجی (INFP)';
      case MBTIType.ENFJ:
        return 'معلم (ENFJ)';
      case MBTIType.ENFP:
        return 'مبارز (ENFP)';
      case MBTIType.ISTJ:
        return 'بازرس (ISTJ)';
      case MBTIType.ISFJ:
        return 'نگهبان (ISFJ)';
      case MBTIType.ESTJ:
        return 'مدیر (ESTJ)';
      case MBTIType.ESFJ:
        return 'کنسول (ESFJ)';
      case MBTIType.ISTP:
        return 'صنعت‌گر (ISTP)';
      case MBTIType.ISFP:
        return 'ماجراجو (ISFP)';
      case MBTIType.ESTP:
        return 'کارآفرین (ESTP)';
      case MBTIType.ESFP:
        return 'سرگرم‌کننده (ESFP)';
    }
  }

  String get description {
    switch (this) {
      case MBTIType.INTJ:
        return 'استراتژیک، آینده‌نگر، مستقل';
      case MBTIType.INTP:
        return 'تحلیلی، خلاق، کنجکاو';
      case MBTIType.ENTJ:
        return 'رهبر، قاطع، هدف‌گرا';
      case MBTIType.ENTP:
        return 'نوآور، چالش‌گر، سریع‌ذهن';
      case MBTIType.INFJ:
        return 'مشاور، دلسوز، ایده‌آل‌گرا';
      case MBTIType.INFP:
        return 'شاعر، ارزش‌گرا، اصیل';
      case MBTIType.ENFJ:
        return 'الهام‌بخش، متقاعدکننده، حامی';
      case MBTIType.ENFP:
        return 'پر‌انرژی، خلاق، مشتاق';
      case MBTIType.ISTJ:
        return 'مسئول، عملی، پایبند';
      case MBTIType.ISFJ:
        return 'وفادار، مهربان، فداکار';
      case MBTIType.ESTJ:
        return 'سازمان‌دهنده، قاطع، اجرایی';
      case MBTIType.ESFJ:
        return 'اجتماعی، مراقب، هماهنگ‌کننده';
      case MBTIType.ISTP:
        return 'مهارتی، ماجراجو، مستقل';
      case MBTIType.ISFP:
        return 'هنرمند، حساس، آرام';
      case MBTIType.ESTP:
        return 'پر‌جنب‌و‌جوش، عمل‌گرا، جسور';
      case MBTIType.ESFP:
        return 'شاد، خودجوش، جذاب';
    }
  }

  String get emoji {
    switch (this) {
      case MBTIType.INTJ:
        return '🧠';
      case MBTIType.INTP:
        return '🔬';
      case MBTIType.ENTJ:
        return '👔';
      case MBTIType.ENTP:
        return '💡';
      case MBTIType.INFJ:
        return '🌿';
      case MBTIType.INFP:
        return '📝';
      case MBTIType.ENFJ:
        return '🌟';
      case MBTIType.ENFP:
        return '🎭';
      case MBTIType.ISTJ:
        return '📋';
      case MBTIType.ISFJ:
        return '🛡️';
      case MBTIType.ESTJ:
        return '🏛️';
      case MBTIType.ESFJ:
        return '🤝';
      case MBTIType.ISTP:
        return '🔧';
      case MBTIType.ISFP:
        return '🎨';
      case MBTIType.ESTP:
        return '⚡';
      case MBTIType.ESFP:
        return '🎉';
    }
  }

  // دریافت لینک تست MBTI
  String get testLink {
    return 'https://www.16personalities.com/fa';
  }
}

class UserPersonality {
  final String userId;
  final Gender gender;
  final List<PersonalityType> personalityTypes;
  final MBTIType? mbtiType; // ✅ اضافه شده
  final List<String> interests;
  final List<String> habits;
  final List<String> goals;
  final String? bio;
  final List<String> preferredTimes;
  final int experienceLevel;
  final bool isLookingForBuddy;
  final DateTime updatedAt;
  final DateTime createdAt;

  UserPersonality({
    required this.userId,
    required this.gender,
    this.personalityTypes = const [],
    this.mbtiType,
    this.interests = const [],
    this.habits = const [],
    this.goals = const [],
    this.bio,
    this.preferredTimes = const [],
    this.experienceLevel = 1,
    this.isLookingForBuddy = true,
    required this.updatedAt,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'gender': gender.toString().split('.').last,
      'personality_types': personalityTypes
          .map((e) => e.toString().split('.').last)
          .toList(),
      'mbti_type': mbtiType?.toString().split('.').last,
      'interests': interests,
      'habits': habits,
      'goals': goals,
      'bio': bio,
      'preferred_times': preferredTimes,
      'experience_level': experienceLevel,
      'is_looking_for_buddy': isLookingForBuddy,
      'updated_at': updatedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory UserPersonality.fromMap(Map<String, dynamic> map, String userId) {
    return UserPersonality(
      userId: userId,
      gender: Gender.values.firstWhere(
        (e) => e.toString().split('.').last == map['gender'],
        orElse: () => Gender.other,
      ),
      personalityTypes: (map['personality_types'] as List? ?? [])
          .map(
            (e) => PersonalityType.values.firstWhere(
              (p) => p.toString().split('.').last == e,
              orElse: () => PersonalityType.disciplined,
            ),
          )
          .toList(),
      mbtiType: map['mbti_type'] != null
          ? MBTIType.values.firstWhere(
              (e) => e.toString().split('.').last == map['mbti_type'],
              orElse: () => MBTIType.INTJ,
            )
          : null,
      interests: List<String>.from(map['interests'] ?? []),
      habits: List<String>.from(map['habits'] ?? []),
      goals: List<String>.from(map['goals'] ?? []),
      bio: map['bio'],
      preferredTimes: List<String>.from(map['preferred_times'] ?? []),
      experienceLevel: map['experience_level'] ?? 1,
      isLookingForBuddy: map['is_looking_for_buddy'] ?? true,
      updatedAt: DateTime.parse(
        map['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  // محاسبه امتیاز تطابق با کاربر دیگر
  double calculateMatchScore(UserPersonality other) {
    double score = 0.0;
    int totalFactors = 0;

    // ۱. جنسیت (وزن: ۱۵٪)
    if (gender == other.gender) {
      score += 15;
    }
    totalFactors += 15;
    print('📊 Gender score: ${score}/${totalFactors}');

    // ۲. MBTI (وزن: ۳۰٪) - اگر هیچکدام MBTI نداشته باشند، رد می‌شود
    if (mbtiType != null && other.mbtiType != null) {
      final myLetters = mbtiType.toString().split('.').last;
      final otherLetters = other.mbtiType.toString().split('.').last;
      int matches = 0;
      for (
        int i = 0;
        i < 4 && i < myLetters.length && i < otherLetters.length;
        i++
      ) {
        if (myLetters[i] == otherLetters[i]) matches++;
      }
      score += (matches / 4) * 30;
      print('📊 MBTI score: $score');
    } else {
      print('⚠️ MBTI not set for one or both users');
    }
    totalFactors += 30;

    // ۳. شخصیت‌های مشترک (وزن: ۲۰٪)
    if (personalityTypes.isNotEmpty && other.personalityTypes.isNotEmpty) {
      final common = personalityTypes
          .where((p) => other.personalityTypes.contains(p))
          .length;
      final maxCommon = personalityTypes.length > other.personalityTypes.length
          ? other.personalityTypes.length
          : personalityTypes.length;
      score += (common / maxCommon) * 20;
      print('📊 Personality score: $score');
    }
    totalFactors += 20;

    // ۴. علاقه‌مندی‌های مشترک (وزن: ۱۵٪)
    if (interests.isNotEmpty && other.interests.isNotEmpty) {
      final common = interests.where((i) => other.interests.contains(i)).length;
      final maxCommon = interests.length > other.interests.length
          ? other.interests.length
          : interests.length;
      score += (common / maxCommon) * 15;
      print('📊 Interests score: $score');
    }
    totalFactors += 15;

    // ۵. عادت‌های مشترک (وزن: ۱۵٪)
    if (habits.isNotEmpty && other.habits.isNotEmpty) {
      final common = habits.where((h) => other.habits.contains(h)).length;
      final maxCommon = habits.length > other.habits.length
          ? other.habits.length
          : habits.length;
      score += (common / maxCommon) * 15;
      print('📊 Habits score: $score');
    }
    totalFactors += 15;

    // ۶. سطح تجربه نزدیک (وزن: ۵٪)
    final levelDiff = (experienceLevel - other.experienceLevel).abs();
    if (levelDiff <= 1) {
      score += 5;
    } else if (levelDiff <= 2) {
      score += 2.5;
    }
    totalFactors += 5;

    final finalScore = (score / totalFactors) * 100;
    print('📊 Final match score: ${finalScore.toStringAsFixed(2)}%');
    return finalScore;
  }
}

// PersonalityType enum (قبلاً تعریف شده بود)
enum PersonalityType {
  disciplined, // منظم
  creative, // خلاق
  social, // اجتماعی
  calm, // آرام
  ambitious, // جاه‌طلب
  spiritual, // معنوی
  athletic, // ورزشکار
  intellectual, // روشنفکر
  adventurous, // ماجراجو
  nurturing, // مراقب
}
