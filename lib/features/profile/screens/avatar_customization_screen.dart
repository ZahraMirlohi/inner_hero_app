// lib/features/profile/widgets/avatar_customization_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/services/supabase_service.dart';
import '../models/profile_model.dart';
import '/providers/theme_provider.dart';
// ... importهای قبلی
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '/services/storage_service.dart';
import 'user_avatar.dart';
import 'dart:typed_data';

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
  final StorageService _storage = StorageService(); // ✅ جدید
  final ImagePicker _picker = ImagePicker(); // ✅ جدید

  late UserProfile _profile;
  bool _isLoading = false;
  bool _isUploadingAvatar = false; // ✅ جدید
  double _uploadProgress = 0.0;

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

  // ✅ کپی کردن profile با یک فیلد تغییر یافته
  UserProfile _copyProfileWith({
    String? skinColor,
    String? hairStyle,
    String? hairColor,
    String? eyeColor,
    String? outfitStyle,
  }) {
    return UserProfile(
      userId: _profile.userId,
      name: _profile.name,
      phone: _profile.phone,
      email: _profile.email,
      birthDate: _profile.birthDate,
      realAge: _profile.realAge,
      gender: _profile.gender,
      registeredAt: _profile.registeredAt,
      avatarStyle: _profile.avatarStyle,
      skinColor: skinColor ?? _profile.skinColor,
      hairStyle: hairStyle ?? _profile.hairStyle,
      hairColor: hairColor ?? _profile.hairColor,
      eyeStyle: _profile.eyeStyle,
      eyeColor: eyeColor ?? _profile.eyeColor,
      mouthStyle: _profile.mouthStyle,
      accessoryType: _profile.accessoryType,
      outfitStyle: outfitStyle ?? _profile.outfitStyle,
      backgroundStyle: _profile.backgroundStyle,
      totalXp: _profile.totalXp,
      weeklyStreak: _profile.weeklyStreak,
      lastStreakUpdate: _profile.lastStreakUpdate,
      currentStreak: _profile.currentStreak,
      bestStreak: _profile.bestStreak,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: const Text('شخصی‌سازی آواتار'),
        backgroundColor: theme.surfaceColor,
        elevation: 0,
        foregroundColor: theme.textColor,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveAvatar,
            child: Text(
              'ذخیره',
              style: TextStyle(color: primaryColor),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // پیش‌نمایش آواتار
            _buildAvatarPreview(theme),
            const SizedBox(height: 24),

            // گزینه‌های شخصی‌سازی
            _buildCustomizationSection(
              'رنگ پوست',
              _skinColors,
              (value) {
                setState(() {
                  _profile = _copyProfileWith(skinColor: value);
                });
              },
              theme,
              primaryColor,
            ),
            const SizedBox(height: 16),

            _buildCustomizationSection(
              'مدل مو',
              _hairStyles,
              (value) {
                setState(() {
                  _profile = _copyProfileWith(hairStyle: value);
                });
              },
              theme,
              primaryColor,
            ),
            const SizedBox(height: 16),

            _buildCustomizationSection(
              'رنگ مو',
              _hairColors,
              (value) {
                setState(() {
                  _profile = _copyProfileWith(hairColor: value);
                });
              },
              theme,
              primaryColor,
            ),
            const SizedBox(height: 16),

            _buildCustomizationSection(
              'رنگ چشم',
              _eyeColors,
              (value) {
                setState(() {
                  _profile = _copyProfileWith(eyeColor: value);
                });
              },
              theme,
              primaryColor,
            ),
            const SizedBox(height: 16),

            _buildCustomizationSection(
              'لباس',
              _outfitStyles,
              (value) {
                setState(() {
                  _profile = _copyProfileWith(outfitStyle: value);
                });
              },
              theme,
              primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPreview(ThemeProvider theme) {
    final primaryColor = theme.primaryColor;
    final hasAvatar =
        _profile.avatarUrl != null && _profile.avatarUrl!.isNotEmpty;

    return Column(
      children: [
        Center(
          child: Stack(
            children: [
              // آواتار یا حرف اول
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      primaryColor,
                      primaryColor.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.surfaceColor,
                    ),
                    child: ClipOval(
                      child: hasAvatar
                          ? Image.network(
                              _profile.avatarUrl!,
                              width: 138,
                              height: 138,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildInitialAvatar(theme),
                            )
                          : _buildInitialAvatar(theme),
                    ),
                  ),
                ),
              ),
              // دکمه دوربین
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isUploadingAvatar ? null : _showAvatarSourcePicker,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.surfaceColor,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: _isUploadingAvatar
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 22,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // نمایش وضعیت آپلود
        if (_isUploadingAvatar)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _uploadProgress,
                    minHeight: 6,
                    backgroundColor: theme.borderColor,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'در حال آپلود... ${(_uploadProgress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
        if (hasAvatar && !_isUploadingAvatar)
          TextButton.icon(
            onPressed: _removeAvatar,
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
            label: const Text(
              'حذف عکس پروفایل',
              style: TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
// 📸 انتخاب منبع عکس
// ═══════════════════════════════════════════════════════════
  void _showAvatarSourcePicker() {
    final theme = Provider.of<ThemeProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'تغییر عکس پروفایل',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildSourceOption(
                        icon: Icons.camera_alt,
                        label: 'دوربین',
                        onTap: () {
                          Navigator.pop(context);
                          _pickAndUploadAvatar(ImageSource.camera);
                        },
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSourceOption(
                        icon: Icons.photo_library,
                        label: 'گالری',
                        onTap: () {
                          Navigator.pop(context);
                          _pickAndUploadAvatar(ImageSource.gallery);
                        },
                        theme: theme,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ThemeProvider theme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: theme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.primaryColor.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: theme.primaryColor, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

// ═══════════════════════════════════════════════════════════
// 📤 آپلود عکس
// ═══════════════════════════════════════════════════════════
  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1080,
        maxHeight: 1080,
      );

      if (picked == null) return;

      setState(() {
        _isUploadingAvatar = true;
        _uploadProgress = 0.1;
      });

      // ✅ خواندن bytes از XFile
      final bytes = await picked.readAsBytes();

      if (mounted) {
        setState(() => _uploadProgress = 0.4);
      }

      // ۱. آپلود با فشرده‌سازی
      final avatarUrl = await _storage.uploadAvatar(
        userId: _profile.userId,
        bytes: bytes,
        originalFileName: picked.name,
      );

      if (mounted) {
        setState(() => _uploadProgress = 0.8);
      }

      // ۲. ذخیره در دیتابیس
      await _supabase.updateAvatarUrl(_profile.userId, avatarUrl);

      // ۳. آپدیت state محلی
      setState(() {
        _profile = UserProfile(
          userId: _profile.userId,
          name: _profile.name,
          uniqueId: _profile.uniqueId,
          username: _profile.username,
          avatarUrl: avatarUrl,
          usernameUpdatedAt: _profile.usernameUpdatedAt,
          phone: _profile.phone,
          email: _profile.email,
          birthDate: _profile.birthDate,
          realAge: _profile.realAge,
          gender: _profile.gender,
          registeredAt: _profile.registeredAt,
          avatarStyle: _profile.avatarStyle,
          skinColor: _profile.skinColor,
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
        _uploadProgress = 1.0;
      });

      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📸 عکس پروفایل با موفقیت آپلود شد'),
            backgroundColor: Colors.green,
          ),
        );
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
          _isUploadingAvatar = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

// ═══════════════════════════════════════════════════════════
// 🗑️ حذف عکس پروفایل
// ═══════════════════════════════════════════════════════════
  Future<void> _removeAvatar() async {
    final theme = Provider.of<ThemeProvider>(context, listen: false);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'حذف عکس پروفایل',
          style: TextStyle(color: theme.textColor),
        ),
        content: Text(
          'آیا مطمئن هستی؟ بعد از حذف، حرف اول نامت نمایش داده می‌شود.',
          style: TextStyle(color: theme.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'حذف',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // ۱. حذف از دیتابیس
      await _supabase.updateAvatarUrl(_profile.userId, null);

      // ۲. آپدیت state
      setState(() {
        _profile = UserProfile(
          userId: _profile.userId,
          name: _profile.name,
          uniqueId: _profile.uniqueId,
          username: _profile.username,
          avatarUrl: null, // ✅ حذف شد
          usernameUpdatedAt: _profile.usernameUpdatedAt,
          phone: _profile.phone,
          email: _profile.email,
          birthDate: _profile.birthDate,
          realAge: _profile.realAge,
          gender: _profile.gender,
          registeredAt: _profile.registeredAt,
          avatarStyle: _profile.avatarStyle,
          skinColor: _profile.skinColor,
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ عکس پروفایل حذف شد'),
            backgroundColor: Colors.green,
          ),
        );
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
    }
  }

  Widget _buildInitialAvatar(ThemeProvider theme) {
    return Center(
      child: Text(
        _profile.name.substring(0, 1).toUpperCase(),
        style: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: theme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildCustomizationSection(
    String title,
    List<Map<String, dynamic>> options,
    Function(String) onSelected,
    ThemeProvider theme,
    Color primaryColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.textColor,
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
                          ? primaryColor
                          : (theme.isDarkMode
                              ? const Color(0xFF2A2A2A)
                              : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(16),
                  border: isSelected
                      ? Border.all(color: primaryColor, width: 2)
                      : null,
                ),
                child: isColor
                    ? Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: theme.surfaceColor, width: 2)
                              : null,
                        ),
                        child: isSelected
                            ? Center(
                                child: Icon(
                                  Icons.check,
                                  color: theme.surfaceColor,
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
                              : theme.textSecondaryColor,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
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
