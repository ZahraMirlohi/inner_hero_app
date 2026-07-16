// lib/features/profile/widgets/avatar_customization_screen.dart

import 'package:flutter/material.dart';
import '/services/supabase_service.dart';
import '../models/profile_model.dart';

class AvatarCustomizationScreen extends StatefulWidget {
  final String userId;
  final UserProfile currentProfile;

  const AvatarCustomizationScreen({
    super.key,
    required this.userId,
    required this.currentProfile,
  });

  @override
  State<AvatarCustomizationScreen> createState() =>
      _AvatarCustomizationScreenState();
}

class _AvatarCustomizationScreenState extends State<AvatarCustomizationScreen> {
  final SupabaseService _supabase = SupabaseService();
  late UserProfile _profile;
  bool _isLoading = false;

  // گزینه‌های شخصی‌سازی
  final List<Map<String, dynamic>> _skinColors = [
    {'name': 'روشن', 'value': '#F5D0B8'},
    {'name': 'متوسط', 'value': '#E8B88A'},
    {'name': 'تیره', 'value': '#D4A076'},
    {'name': 'قهوه‌ای', 'value': '#C68642'},
  ];

  final List<Map<String, dynamic>> _hairStyles = [
    {'name': 'ساده', 'value': 'default'},
    {'name': 'بلند', 'value': 'long'},
    {'name': 'کوتاه', 'value': 'short'},
    {'name': 'مجعد', 'value': 'curly'},
    {'name': 'کلاه', 'value': 'hat'},
  ];

  final List<Map<String, dynamic>> _hairColors = [
    {'name': 'مشکی', 'value': '#1A1A1A'},
    {'name': 'قهوه‌ای', 'value': '#4A3728'},
    {'name': 'بلوند', 'value': '#D4A574'},
    {'name': 'قرمز', 'value': '#8B4513'},
  ];

  final List<Map<String, dynamic>> _eyeColors = [
    {'name': 'آبی', 'value': '#4A90E2'},
    {'name': 'قهوه‌ای', 'value': '#8B6914'},
    {'name': 'سبز', 'value': '#2ECC71'},
    {'name': 'خاکستری', 'value': '#95A5A6'},
  ];

  final List<Map<String, dynamic>> _outfitStyles = [
    {'name': 'پیش‌فرض', 'value': 'default'},
    {'name': 'ورزشی', 'value': 'sport'},
    {'name': 'رسمی', 'value': 'formal'},
    {'name': 'کازوال', 'value': 'casual'},
    {'name': 'ماجراجو', 'value': 'adventure'},
  ];

  @override
  void initState() {
    super.initState();
    _profile = widget.currentProfile;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('شخصی‌سازی آواتار'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A2E),
        actions: [
          TextButton(
            onPressed: _saveAvatar,
            child: const Text(
              'ذخیره',
              style: TextStyle(color: Color(0xFF2563EB)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // پیش‌نمایش آواتار
            _buildAvatarPreview(),
            const SizedBox(height: 24),

            // گزینه‌های شخصی‌سازی
            _buildCustomizationSection('رنگ پوست', _skinColors, (value) {
              setState(() {
                // در avatar_customization_screen.dart - تمام جاهایی که UserProfile ساخته می‌شود

                _profile = UserProfile(
                  userId: _profile.userId,
                  name: _profile.name,
                  phone: _profile.phone,
                  email: _profile.email,
                  birthDate: _profile.birthDate,
                  realAge: _profile.realAge,
                  gender: _profile.gender,
                  registeredAt: _profile.registeredAt,
                  avatarStyle: _profile.avatarStyle,
                  skinColor: value, // یا هر مقدار دیگری
                  hairStyle: _profile.hairStyle,
                  hairColor: _profile.hairColor,
                  eyeStyle: _profile.eyeStyle,
                  eyeColor: _profile.eyeColor,
                  mouthStyle: _profile.mouthStyle,
                  accessoryType: _profile.accessoryType,
                  outfitStyle: _profile.outfitStyle,
                  backgroundStyle: _profile.backgroundStyle,
                  totalXp: _profile.totalXp,
                  weeklyStreak: _profile.weeklyStreak,
                  lastStreakUpdate: _profile.lastStreakUpdate,
                  currentStreak: _profile.currentStreak,
                  bestStreak: _profile.bestStreak,
                );
              });
            }),
            const SizedBox(height: 16),

            _buildCustomizationSection('مدل مو', _hairStyles, (value) {
              setState(() {
                // در avatar_customization_screen.dart - تمام جاهایی که UserProfile ساخته می‌شود

                _profile = UserProfile(
                  userId: _profile.userId,
                  name: _profile.name,
                  phone: _profile.phone,
                  email: _profile.email,
                  birthDate: _profile.birthDate,
                  realAge: _profile.realAge,
                  gender: _profile.gender,
                  registeredAt: _profile.registeredAt,
                  avatarStyle: _profile.avatarStyle,
                  skinColor: value, // یا هر مقدار دیگری
                  hairStyle: _profile.hairStyle,
                  hairColor: _profile.hairColor,
                  eyeStyle: _profile.eyeStyle,
                  eyeColor: _profile.eyeColor,
                  mouthStyle: _profile.mouthStyle,
                  accessoryType: _profile.accessoryType,
                  outfitStyle: _profile.outfitStyle,
                  backgroundStyle: _profile.backgroundStyle,
                  totalXp: _profile.totalXp,
                  weeklyStreak: _profile.weeklyStreak,
                  lastStreakUpdate: _profile.lastStreakUpdate,
                  currentStreak: _profile.currentStreak,
                  bestStreak: _profile.bestStreak,
                );
              });
            }),
            const SizedBox(height: 16),

            _buildCustomizationSection('رنگ مو', _hairColors, (value) {
              setState(() {
                // در avatar_customization_screen.dart - تمام جاهایی که UserProfile ساخته می‌شود

                _profile = UserProfile(
                  userId: _profile.userId,
                  name: _profile.name,
                  phone: _profile.phone,
                  email: _profile.email,
                  birthDate: _profile.birthDate,
                  realAge: _profile.realAge,
                  gender: _profile.gender,
                  registeredAt: _profile.registeredAt,
                  avatarStyle: _profile.avatarStyle,
                  skinColor: value, // یا هر مقدار دیگری
                  hairStyle: _profile.hairStyle,
                  hairColor: _profile.hairColor,
                  eyeStyle: _profile.eyeStyle,
                  eyeColor: _profile.eyeColor,
                  mouthStyle: _profile.mouthStyle,
                  accessoryType: _profile.accessoryType,
                  outfitStyle: _profile.outfitStyle,
                  backgroundStyle: _profile.backgroundStyle,
                  totalXp: _profile.totalXp,
                  weeklyStreak: _profile.weeklyStreak,
                  lastStreakUpdate: _profile.lastStreakUpdate,
                  currentStreak: _profile.currentStreak,
                  bestStreak: _profile.bestStreak,
                );
              });
            }),
            const SizedBox(height: 16),

            _buildCustomizationSection('رنگ چشم', _eyeColors, (value) {
              setState(() {
                // در avatar_customization_screen.dart - تمام جاهایی که UserProfile ساخته می‌شود

                _profile = UserProfile(
                  userId: _profile.userId,
                  name: _profile.name,
                  phone: _profile.phone,
                  email: _profile.email,
                  birthDate: _profile.birthDate,
                  realAge: _profile.realAge,
                  gender: _profile.gender,
                  registeredAt: _profile.registeredAt,
                  avatarStyle: _profile.avatarStyle,
                  skinColor: value, // یا هر مقدار دیگری
                  hairStyle: _profile.hairStyle,
                  hairColor: _profile.hairColor,
                  eyeStyle: _profile.eyeStyle,
                  eyeColor: _profile.eyeColor,
                  mouthStyle: _profile.mouthStyle,
                  accessoryType: _profile.accessoryType,
                  outfitStyle: _profile.outfitStyle,
                  backgroundStyle: _profile.backgroundStyle,
                  totalXp: _profile.totalXp,
                  weeklyStreak: _profile.weeklyStreak,
                  lastStreakUpdate: _profile.lastStreakUpdate,
                  currentStreak: _profile.currentStreak,
                  bestStreak: _profile.bestStreak,
                );
              });
            }),
            const SizedBox(height: 16),

            _buildCustomizationSection('لباس', _outfitStyles, (value) {
              setState(() {
                // در avatar_customization_screen.dart - تمام جاهایی که UserProfile ساخته می‌شود

                _profile = UserProfile(
                  userId: _profile.userId,
                  name: _profile.name,
                  phone: _profile.phone,
                  email: _profile.email,
                  birthDate: _profile.birthDate,
                  realAge: _profile.realAge,
                  gender: _profile.gender,
                  registeredAt: _profile.registeredAt,
                  avatarStyle: _profile.avatarStyle,
                  skinColor: value, // یا هر مقدار دیگری
                  hairStyle: _profile.hairStyle,
                  hairColor: _profile.hairColor,
                  eyeStyle: _profile.eyeStyle,
                  eyeColor: _profile.eyeColor,
                  mouthStyle: _profile.mouthStyle,
                  accessoryType: _profile.accessoryType,
                  outfitStyle: _profile.outfitStyle,
                  backgroundStyle: _profile.backgroundStyle,
                  totalXp: _profile.totalXp,
                  weeklyStreak: _profile.weeklyStreak,
                  lastStreakUpdate: _profile.lastStreakUpdate,
                  currentStreak: _profile.currentStreak,
                  bestStreak: _profile.bestStreak,
                );
              });
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPreview() {
    return Center(
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [const Color(0xFF2563EB), const Color(0xFF7C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Color(
                        int.parse(
                          'FF${_profile.skinColor.substring(1)}',
                          radix: 16,
                        ),
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _profile.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _profile.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomizationSection(
    String title,
    List<Map<String, dynamic>> options,
    Function(String) onSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = option['value'] == _getCurrentValue(title);
            final isColor = title.contains('رنگ');

            return GestureDetector(
              onTap: () => onSelected(option['value']),
              child: Container(
                padding: isColor
                    ? const EdgeInsets.all(4)
                    : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isColor
                      ? Color(
                          int.parse(
                            'FF${option['value'].substring(1)}',
                            radix: 16,
                          ),
                        )
                      : isSelected
                      ? const Color(0xFF2563EB)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: isSelected
                      ? Border.all(color: const Color(0xFF2563EB), width: 2)
                      : null,
                ),
                child: isColor
                    ? Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                        ),
                        child: isSelected
                            ? const Center(
                                child: Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              )
                            : null,
                      )
                    : Text(
                        option['name'],
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade700,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _getCurrentValue(String title) {
    switch (title) {
      case 'رنگ پوست':
        return _profile.skinColor;
      case 'مدل مو':
        return _profile.hairStyle;
      case 'رنگ مو':
        return _profile.hairColor;
      case 'رنگ چشم':
        return _profile.eyeColor;
      case 'لباس':
        return _profile.outfitStyle;
      default:
        return '';
    }
  }

  Future<void> _saveAvatar() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = {
        'skin_color': _profile.skinColor,
        'hair_style': _profile.hairStyle,
        'hair_color': _profile.hairColor,
        'eye_style': _profile.eyeStyle,
        'eye_color': _profile.eyeColor,
        'mouth_style': _profile.mouthStyle,
        'accessory_type': _profile.accessoryType,
        'outfit_style': _profile.outfitStyle,
        'background_style': _profile.backgroundStyle,
      };

      await _supabase.client
          .from('profiles')
          .update(data)
          .eq('user_id', _profile.userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('آواتار با موفقیت به‌روزرسانی شد! 🎉'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
