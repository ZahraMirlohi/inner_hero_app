// lib/features/profile/screens/profile_screen.dart

import '/l10n/app_strings.dart';
import '/core/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/services/supabase_service.dart';
import '../models/profile_model.dart';
import 'avatar_customization_screen.dart';
import 'analytics_detail_screen.dart';
import '../widgets/xp_stats_widget.dart';
import '../widgets/analytics_overview_widget.dart';
import 'terms_and_conditions_screen.dart';
import 'settings_screen.dart';
import '../widgets/streak_card_widget.dart';
import '/../providers/sync_provider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:flutter/services.dart';
import '/../utils/unique_id_generator.dart';
import 'personality_screen.dart';
import '/providers/theme_provider.dart';
import '/providers/calendar_provider.dart';
import 'username_setup_screen.dart';
import 'gallery_screen.dart';
import 'user_avatar.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '/services/storage_service.dart';
import 'dart:io' show File;
import '/services/image_crop_service.dart';

class ProfileScreen extends StatefulWidget {
  final ValueNotifier<int>? refreshNotifier;

  const ProfileScreen({super.key, this.refreshNotifier});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey<AnalyticsOverviewWidgetState> _analyticsKey =
      GlobalKey<AnalyticsOverviewWidgetState>();
  final SupabaseService _supabase = SupabaseService();
  UserProfile? _profile;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  bool _isUserInfoExpanded = false;

  int _currentStreak = 0;
  int _bestStreak = 0;
  int _weeklyStreak = 0;
  final ImagePicker _imagePicker = ImagePicker(); // جدید
  final StorageService _storage = StorageService(); // جدید
  bool _isUploadingAvatar = false; // جدید

  DateTime? _lastRefreshTime;
  static const Duration _minRefreshInterval = Duration(seconds: 1);

  // برای جلوگیری از بارگذاری مجدد در حین بارگذاری
  bool _isLoadingInProgress = false;

  // رنگ‌های تم اپلیکیشن (از ThemeProvider) — فقط برای ظاهر، در منطق استفاده نمی‌شه
  late ThemeProvider _theme;

  @override
  void initState() {
    super.initState();
    _loadProfile();

    // گوش دادن به تغییرات notifier
    widget.refreshNotifier?.addListener(_onRefreshTriggered);

    // اگر notifier مقداردهی شده، یکبار ریفرش کن (برای همگام‌سازی اولیه)
    if (widget.refreshNotifier != null && widget.refreshNotifier!.value > 0) {
      _onRefreshTriggered();
    }
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_onRefreshTriggered);
    super.dispose();
  }

  void _onRefreshTriggered() {
    print(
      'Profile refresh triggered from notifier: ${widget.refreshNotifier?.value}',
    );

    final now = DateTime.now();
    if (_lastRefreshTime != null &&
        now.difference(_lastRefreshTime!) < _minRefreshInterval) {
      print('Skip refresh: too soon');
      return;
    }
    _lastRefreshTime = now;

    if (_isRefreshing) {
      print('Skip refresh: already refreshing');
      return;
    }

    _isRefreshing = true;
    print('Refreshing profile...');

    // فقط کش weekDays را پاک کن (چون _cachedHabits و _cachedTasks وجود ندارند)
    _cachedWeekDays = null;

    // اجباری کردن بارگذاری از دیتابیس
    _isLoadingInProgress = false;

    _loadProfile().then((_) {
      _analyticsKey.currentState?.refreshData();
      _isRefreshing = false;
      debugPrint('Profile refresh completed');
    }).catchError((e) {
      debugPrint('Profile refresh error: $e');
      _isRefreshing = false;
    });
  }
  // ==================== متد اصلی بارگذاری پروفایل ====================

  Future<void> _loadProfile() async {
    // چک کن SyncProvider پاک شده
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);
    if (syncProvider.isCleared) {
      print('Skip _loadProfile: SyncProvider is cleared');
      return;
    }

    if (!mounted) return;

    _isLoadingInProgress = true;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);

      // همیشه از دیتابیس بخوان
      if (syncProvider.isOnline) {
        print('Online - loading from Supabase...');
        final success = await _loadFromSupabase(syncProvider);
        if (success) {
          _isLoadingInProgress = false;
          final calendar =
              Provider.of<CalendarProvider>(context, listen: false);
          await _recalculateWeeklyStreak(calendar); // با calendar
          if (mounted) {
            setState(() {});
          }
          return;
        }
      }

      // اگر آنلاین نبود، از localStorage بخوان
      print('Loading from LocalStorage...');
      final localSuccess = await _loadFromLocal(syncProvider);

      if (!localSuccess && mounted) {
        setState(() {
          _errorMessage = 'خطا در بارگذاری اطلاعات';
          _isLoading = false;
        });
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'خطا در بارگذاری: ${e.toString()}';
          _isLoading = false;
        });
      }
    } finally {
      _isLoadingInProgress = false;
    }
  }
  // ==================== به‌روزرسانی استریک هفتگی ====================

  Future<void> _recalculateWeeklyStreak(CalendarProvider calendar) async {
    try {
      if (_profile == null) return;

      final now = DateTime.now();

      // محاسبه شروع هفته بر اساس تقویم انتخابی
      int daysToSubtract;
      if (calendar.isJalali) {
        final jalaliToday = Jalali.fromDateTime(now);
        daysToSubtract = jalaliToday.weekDay - 1;
      } else {
        daysToSubtract = now.weekday % 7;
      }
      final weekStart = now.subtract(Duration(days: daysToSubtract));

      int newWeeklyStreak = 0;
      List<bool> weekStatus = [];

      for (int i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        final dateStr = date.toIso8601String().split('T').first;

        final activity = await _supabase.client
            .from('user_daily_activity')
            .select('is_active')
            .eq('user_id', _profile!.userId)
            .eq('activity_date', dateStr)
            .maybeSingle();

        final isActive = activity != null && activity['is_active'] == true;
        weekStatus.add(isActive);

        if (isActive) {
          newWeeklyStreak++;
        }
      }

      _cachedWeekDays = weekStatus;

      if (_profile!.weeklyStreak != newWeeklyStreak) {
        await _supabase.client.from('profiles').update(
            {'weekly_streak': newWeeklyStreak}).eq('user_id', _profile!.userId);

        setState(() {
          _weeklyStreak = newWeeklyStreak;
          _profile = _profile!.copyWith(
            weeklyStreak: newWeeklyStreak,
            lastStreakUpdate: DateTime.now(),
          );
        });
      }
    } catch (e) {
      debugPrint('Error recalculating weekly streak: $e');
    }
  }
  // ==================== بارگذاری از LocalStorage ====================

  // lib/features/profile/screens/profile_screen.dart

  Future<bool> _loadFromLocal(SyncProvider syncProvider) async {
    try {
      final localProfile = syncProvider.profile;

      if (localProfile != null) {
        _profile = UserProfile.fromMap(
          localProfile,
          localProfile['user_id'] ?? '',
        );
        _currentStreak = localProfile['current_streak'] ?? 0;
        _bestStreak = localProfile['best_streak'] ?? 0;
        _weeklyStreak = localProfile['weekly_streak'] ?? 0;

        // اطمینان از اینکه total_xp از localStorage صحیح است
        _profile!.totalXp = localProfile['total_xp'] ?? 0;
        print(
          'Profile loaded from LOCAL storage with XP: ${_profile!.totalXp}',
        );

        print('Profile loaded from LOCAL storage');
        print('   - Name: ${_profile?.name}');
        print('   - XP: ${_profile?.totalXp}');
        print('   - Streak: $_currentStreak');

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return true;
      }

      print('No profile found in LOCAL storage');
      return false;
    } catch (e) {
      print('Error loading from local: $e');
      return false;
    }
  }

  // ==================== بارگذاری از Supabase ====================

  // lib/features/profile/screens/profile_screen.dart

  Future<bool> _loadFromSupabase(SyncProvider syncProvider) async {
    try {
      final currentUser = await _supabase.getCurrentUser();
      if (currentUser == null) {
        print('No user logged in');
        if (mounted) {
          setState(() {
            _errorMessage = 'لطفاً وارد حساب کاربری خود شوید';
            _isLoading = false;
          });
        }
        return false;
      }

      print('Loading profile for user: ${currentUser.id}');

      // دریافت پروفایل با XP از دیتابیس
      final response = await _supabase.client
          .from('profiles')
          .select()
          .eq('user_id', currentUser.id)
          .maybeSingle();

      if (response != null) {
        // اطمینان از وجود unique_id
        if (response['unique_id'] == null || response['unique_id'].isEmpty) {
          final newUniqueId = UniqueIdGenerator.generateSecure();
          await _supabase.client
              .from('profiles')
              .update({'unique_id': newUniqueId}).eq('user_id', currentUser.id);
          response['unique_id'] = newUniqueId;
          print('Unique ID generated for user: $newUniqueId');
        }

        // دریافت XP از user_progress (منبع اصلی)
        int totalXP = response['total_xp'] ?? 0;
        try {
          final progressResponse = await _supabase.client
              .from('user_progress')
              .select('total_xp')
              .eq('user_id', currentUser.id)
              .maybeSingle();

          if (progressResponse != null) {
            final progressXP = progressResponse['total_xp'] as int? ?? 0;
            // از user_progress استفاده کن چون منبع اصلی است
            totalXP = progressXP;
            print('XP from user_progress: $totalXP');

            // اگر profiles با user_progress هماهنگ نیست، آن را به‌روزرسانی کن
            if (response['total_xp'] != totalXP) {
              await _supabase.client
                  .from('profiles')
                  .update({'total_xp': totalXP}).eq('user_id', currentUser.id);
              print('Profile XP updated to match user_progress: $totalXP');
            }
          }
        } catch (e) {
          print('Error getting user_progress: $e');
        }

        // ساخت پروفایل با XP صحیح
        _profile = UserProfile.fromMap(response, currentUser.id);
        _currentStreak = response['current_streak'] ?? 0;
        _bestStreak = response['best_streak'] ?? 0;
        _weeklyStreak = response['weekly_streak'] ?? 0;

        // تنظیم total_xp با مقدار صحیح
        _profile!.totalXp = totalXP;
        print('Profile XP set to: ${_profile!.totalXp}');

        final calendar = Provider.of<CalendarProvider>(context, listen: false);
        _cachedWeekDays = await _calculateWeekDaysFromDatabase(
          currentUser.id,
          calendar,
        );
        // ذخیره در LocalStorage با مقدار صحیح
        final profileMap = _profile!.toMap();
        profileMap['user_id'] = currentUser.id;
        profileMap['current_streak'] = _currentStreak;
        profileMap['best_streak'] = _bestStreak;
        profileMap['weekly_streak'] = _weeklyStreak;
        profileMap['total_xp'] = totalXP;
        await syncProvider.saveProfileToLocal(profileMap);

        print('Profile loaded from SUPABASE');
        print('   - Name: ${_profile?.name}');
        print('   - XP: ${_profile?.totalXp}');
        print('   - Streak: $_currentStreak');

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return true;
      }

      print('No profile found, creating new...');
      await _createNewProfile();
      return true;
    } catch (e) {
      print('Error loading from Supabase: $e');
      return false;
    }
  }

  // کش برای weekDays
  List<bool>? _cachedWeekDays;

  // متد محاسبه weekDays از دیتابیس (با await)
  Future<List<bool>> _calculateWeekDaysFromDatabase(
    String userId,
    CalendarProvider calendar,
  ) async {
    List<bool> weekDays = List.filled(7, false);

    try {
      final now = DateTime.now();

      // محاسبه شروع هفته بر اساس تقویم
      int daysToSubtract;
      if (calendar.isJalali) {
        final jalaliNow = Jalali.fromDateTime(now);
        daysToSubtract = jalaliNow.weekDay - 1;
      } else {
        daysToSubtract = now.weekday % 7;
      }
      final weekStart = now.subtract(Duration(days: daysToSubtract));

      // دریافت فعالیت‌های هفته
      for (int i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        final dateStr = date.toIso8601String().split('T').first;

        final activity = await _supabase.client
            .from('user_daily_activity')
            .select('is_active')
            .eq('user_id', userId)
            .eq('activity_date', dateStr)
            .maybeSingle();

        weekDays[i] = activity != null && activity['is_active'] == true;
      }

      return weekDays;
    } catch (e) {
      debugPrint('Error calculating weekDays: $e');
      return weekDays;
    }
  }

  // ==================== ساخت پروفایل جدید ====================

  // lib/features/profile/screens/profile_screen.dart

  Future<void> _createNewProfile() async {
    try {
      final currentUser = await _supabase.getCurrentUser();
      if (currentUser == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'لطفاً وارد حساب کاربری خود شوید';
            _isLoading = false;
          });
        }
        return;
      }

      // تولید ID یکتا
      final uniqueId = UniqueIdGenerator.generateSecure();

      final newProfile = UserProfile(
        userId: currentUser.id,
        name: currentUser.email?.split('@').first.isNotEmpty == true
            ? currentUser.email!.split('@').first
            : 'کاربر',
        uniqueId: uniqueId, // اضافه کردن uniqueId
        email: currentUser.email,
        registeredAt: DateTime.now(),
        totalXp: 0,
      );

      // ذخیره در Supabase با unique_id
      await _supabase.client.from('profiles').insert({
        'user_id': currentUser.id,
        'name': newProfile.name,
        'email': newProfile.email,
        'unique_id': uniqueId, // ذخیره unique_id
        'total_xp': 0,
        'current_streak': 0,
        'best_streak': 0,
        'weekly_streak': 0,
      });

      // ایجاد user_progress
      await _supabase.createUserProgress(currentUser.id);

      // تنظیم پروفایل محلی
      _profile = newProfile;
      _currentStreak = 0;
      _bestStreak = 0;
      _weeklyStreak = 0;

      // ذخیره در LocalStorage
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);
      final profileMap = newProfile.toMap();
      profileMap['user_id'] = currentUser.id;
      profileMap['current_streak'] = 0;
      profileMap['best_streak'] = 0;
      profileMap['weekly_streak'] = 0;
      await syncProvider.saveProfileToLocal(profileMap);

      print('New profile created with Unique ID: $uniqueId');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error creating profile: $e');
      await _createFallbackProfile();
    }
  }
  // ==================== پروفایل پیش‌فرض (Fallback) ====================

  Future<void> _createFallbackProfile() async {
    try {
      final currentUser = await _supabase.getCurrentUser();
      if (currentUser != null && _profile == null) {
        _profile = UserProfile(
          userId: currentUser.id,
          name: currentUser.email?.split('@').first ?? 'کاربر',
          email: currentUser.email,
          registeredAt: DateTime.now(),
          totalXp: 0,
        );
        _currentStreak = 0;
        _bestStreak = 0;
        _weeklyStreak = 0;

        // ذخیره در LocalStorage
        final syncProvider = Provider.of<SyncProvider>(context, listen: false);
        final profileMap = _profile!.toMap();
        profileMap['user_id'] = _profile!.userId;
        profileMap['current_streak'] = 0;
        profileMap['best_streak'] = 0;
        profileMap['weekly_streak'] = 0;
        await syncProvider.saveProfileToLocal(profileMap);

        print('Fallback profile created');

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error creating fallback profile: $e');
    }
  }

  // ==================== ذخیره پروفایل ====================

  Future<void> _saveProfile() async {
    if (_profile == null) return;

    try {
      final data = _profile!.toMap();
      data.remove('registered_at');

      await _supabase.client
          .from('profiles')
          .update(data)
          .eq('user_id', _profile!.userId);

      // ذخیره در LocalStorage
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);
      final profileMap = _profile!.toMap();
      profileMap['user_id'] = _profile!.userId;
      profileMap['current_streak'] = _currentStreak;
      profileMap['best_streak'] = _bestStreak;
      profileMap['weekly_streak'] = _weeklyStreak;
      await syncProvider.saveProfileToLocal(profileMap);

      print('Profile saved to Supabase and LocalStorage');
    } catch (e) {
      print('Error saving profile: $e');
    }
  }

  // ==================== محاسبه استریک هفتگی ====================

  Future<void> _calculateWeeklyStreak() async {
    if (_profile == null) return;

    try {
      final now = DateTime.now();
      final todayGregorian = now;
      final weekdayGregorian = now.weekday;

      int daysToSubtract;
      if (weekdayGregorian == 1) {
        daysToSubtract = 2;
      } else {
        daysToSubtract = weekdayGregorian - 1;
      }

      final weekStart = todayGregorian.subtract(Duration(days: daysToSubtract));

      int streak = 0;
      for (int i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        final dateStr = date.toIso8601String().split('T').first;

        try {
          final activity = await _supabase.client
              .from('user_daily_activity')
              .select('is_active')
              .eq('user_id', _profile!.userId)
              .eq('activity_date', dateStr)
              .maybeSingle();

          final bool isActive =
              activity != null && activity['is_active'] == true;

          if (isActive) {
            streak++;
          }
        } catch (e) {
          // اگر جدول وجود نداشت، از داده‌های موجود استفاده کن
          break;
        }
      }

      if (_profile!.weeklyStreak != streak) {
        _profile = _profile!.copyWith(
          weeklyStreak: streak,
          lastStreakUpdate: DateTime.now(),
        );
        await _saveProfile();

        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      print('Error calculating weekly streak: $e');
    }
  }

  // ==================== Widget Build ====================

  @override
  Widget build(BuildContext context) {
    _theme = context.watch<ThemeProvider>();
    final bool darkBg =
        ThemeData.estimateBrightnessForColor(_theme.backgroundColor) ==
            Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: darkBg ? Brightness.light : Brightness.dark,
        statusBarBrightness: darkBg ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
      backgroundColor: _theme.backgroundColor,
      body: Consumer<SyncProvider>(
        builder: (context, syncProvider, child) {
          // حالت بارگذاری
          if (_isLoading && _profile == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _theme.primaryColor),
                  const SizedBox(height: 16),
                  const Text(
                    'در حال بارگذاری پروفایل...',
                    style: TextStyle(color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            );
          }

          // حالت خطا
          if (_errorMessage != null && _profile == null) {
            return _buildErrorState();
          }

          // حالت خالی
          if (_profile == null) {
            return _buildEmptyState();
          }

          // نمایش محتوا
          return _buildProfileContent();
        },
      ),
      ),
    );
  }

  // ==================== حالت خطا ====================

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadProfile,
            icon: const Icon(Icons.refresh),
            label: const Text('تلاش مجدد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _theme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== حالت خالی ====================

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('پروفایل وجود ندارد'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadProfile,
            icon: const Icon(Icons.refresh),
            label: const Text('بارگذاری مجدد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _theme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== میانبرهای رنگی ====================

  Widget _buildShortcuts() {
    Widget tile(Tone tone, IconData icon, String label, VoidCallback onTap) {
      final c = _theme.tone(tone);
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 84,
            decoration: BoxDecoration(
              color: _theme.cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: _theme.softShadow,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration:
                      BoxDecoration(color: c.bg, shape: BoxShape.circle),
                  child: Icon(icon, color: c.fg, size: 20),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _theme.textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tile(Tone.mint, Icons.bar_chart_rounded, context.tr('profile.analytics'),
            () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AnalyticsDetailScreen(userId: _profile!.userId),
            ),
          );
        }),
        const SizedBox(width: 10),
        tile(Tone.lilac, Icons.auto_awesome_rounded,
            context.tr('profile.personality_short'), () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PersonalityScreen()),
          ).then((_) => _loadProfile());
        }),
        const SizedBox(width: 10),
        tile(Tone.sky, Icons.photo_library_rounded,
            context.tr('profile.gallery_short'), _openGallery),
      ],
    );
  }

  // ==================== محتوای اصلی پروفایل ====================
  // در بخش دکمه‌های profile_screen.dart

  Widget _buildPersonalityButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PersonalityScreen()),
          ).then((_) => _loadProfile());
        },
        icon: const Icon(Icons.person_outline, size: 20),
        label: const Text(
          'شخصیت من',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _theme.surfaceColor,
          foregroundColor: _theme.textColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  // ==================== محتوای اصلی پروفایل ====================

  Widget _buildProfileContent() {
    final weekDays = _cachedWeekDays ?? List.filled(7, false);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 170),
      child: Column(
        children: [
          _buildTopBar(),
          _buildHeroCard(),
          const SizedBox(height: 12),
          _buildStatsGrid(),
          const SizedBox(height: 12),
          StreakCardWidget(
            currentStreak: _currentStreak,
            bestStreak: _bestStreak,
            weeklyStreak: _weeklyStreak,
            weekDays: weekDays,
          ),
          const SizedBox(height: 12),
          _buildShortcuts(),
          const SizedBox(height: 12),
          _buildUserInfoSection(),
          const SizedBox(height: 12),
          _buildListRow(Tone.butter, Icons.description_rounded,
              context.tr('profile.terms'), () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const TermsAndConditionsScreen()),
            );
          }),
        ],
      ),
    );
  }

  /// عنوان صفحه + دکمهٔ تنظیمات (مثل طراحی)
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 28, 0, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.tr('profile.title'),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: _theme.textColor,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _theme.cardColor,
                shape: BoxShape.circle,
                boxShadow: _theme.softShadow,
              ),
              child: Icon(Icons.tune_rounded, color: _theme.textColor),
            ),
          ),
        ],
      ),
    );
  }

  /// کارت قهرمان: عکس، نام، نام کاربری و پیشرفت تا سطح بعدی
  Widget _buildHeroCard() {
    final p = _profile!;
    final progress = p.levelProgress.clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: _theme.cardColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: _theme.softShadow,
      ),
      child: Column(
        children: [
          UserAvatar(
            avatarUrl: p.avatarUrl,
            name: p.name,
            size: 84,
            showBorder: false,
            showEditBadge: true,
            onEditTap: _showAvatarEditOptions,
            onTap: _showAvatarEditOptions,
          ),
          const SizedBox(height: 8),
          Text(
            p.name,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: _theme.textColor,
            ),
          ),
          const SizedBox(height: 6),
          _buildUsernameDisplay(),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('xp.progress', {'n': '${p.level + 1}'}),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _theme.textColor,
                ),
              ),
              Text(
                '${p.totalXp % 100} / 100 XP',
                style: TextStyle(
                  fontSize: 12,
                  color: _theme.textSecondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Stack(
              children: [
                Container(height: 10, color: _theme.cardSecondaryColor),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => FractionallySizedBox(
                    widthFactor: v,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: _theme.primaryColor,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// چهار آمار پاستلی دو در دو
  Widget _buildStatsGrid() {
    final p = _profile!;
    Widget cell(Tone tone, IconData icon, String value, String label) {
      final c = _theme.tone(tone);
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: c.bg,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: c.fg),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _theme.textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: _theme.textColor.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final days = context.tr('streak.days');
    return Column(
      children: [
        Row(
          children: [
            cell(Tone.butter, Icons.stars_rounded,
                '${p.totalXp}', context.tr('profile.stat_age')),
            const SizedBox(width: 10),
            cell(Tone.lilac, Icons.bolt_rounded, '${p.level}',
                context.tr('profile.stat_level')),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            cell(Tone.peach, Icons.local_fire_department_rounded,
                '$_currentStreak $days', context.tr('profile.stat_streak')),
            const SizedBox(width: 10),
            cell(Tone.sky, Icons.emoji_events_rounded, '$_bestStreak $days',
                context.tr('profile.stat_best')),
          ],
        ),
      ],
    );
  }

  Widget _buildListRow(Tone tone, IconData icon, String label, VoidCallback onTap) {
    final c = _theme.tone(tone);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _theme.cardColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: _theme.softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle),
              child: Icon(icon, color: c.fg, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _theme.textColor,
                ),
              ),
            ),
            Icon(Icons.chevron_left_rounded, color: _theme.textSecondaryColor),
          ],
        ),
      ),
    );
  }

// ═══════════════════════════════════════════════════════════
// دکمه گالری
// ═══════════════════════════════════════════════════════════
  Widget _buildGalleryButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _openGallery,
        icon: const Icon(Icons.photo_library, size: 20),
        label: const Text(
          'گالری من',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _theme.surfaceColor,
          foregroundColor: _theme.textColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  // متد جدید برای دریافت weekDays از دیتابیس
  List<bool> _getWeekDaysFromDatabase() {
    // مقدار پیش‌فرض (همه false)
    List<bool> weekDays = List.filled(7, false);

    try {
      final now = DateTime.now();
      final jalaliNow = Jalali.fromDateTime(now);
      final daysToSubtract = jalaliNow.weekDay - 1; // 0=شنبه
      final weekStart = now.subtract(Duration(days: daysToSubtract));

      // دریافت فعالیت‌های هفته از دیتابیس
      // این کار باید به صورت async انجام شود، اما در build نمی‌توانیم async باشیم
      // بنابراین از داده‌های موجود در _profile استفاده می‌کنیم

      // روش 1: اگر weeklyStreak داریم، به ترتیب از شنبه شروع می‌کنیم
      // اما این روش دقیق نیست چون فقط تعداد روزها را می‌دانیم نه اینکه کدام روزها

      // روش 2: استفاده از داده‌های cached شده
      // بهتر است weekDays را در یک متغیر کش نگه داریم

      // فعلاً از روش ساده استفاده می‌کنیم:
      // اگر weeklyStreak > 0 باشد، از امروز به عقب پر می‌کنیم
      if (_weeklyStreak > 0) {
        int remaining = _weeklyStreak;
        for (int i = 0; i < 7 && remaining > 0; i++) {
          // از امروز به عقب برو
          final date = now.subtract(Duration(days: i));
          final jalaliDate = Jalali.fromDateTime(date);
          final weekdayIndex = jalaliDate.weekDay - 1;
          weekDays[weekdayIndex] = true;
          remaining--;
        }
      }

      print('Generated weekDays: $weekDays');
      return weekDays;
    } catch (e) {
      print('Error getting weekDays: $e');
      return weekDays;
    }
  }

  // ==================== بخش آواتار ====================

// ==================== بخش آواتار ====================

  Widget _buildAvatarSection() {
    return Column(
      children: [
        Center(
          child: UserAvatar(
            avatarUrl: _profile?.avatarUrl,
            name: _profile?.name,
            size: 160,
            showBorder: true,
            showEditBadge: true,
            onEditTap: _showAvatarEditOptions,
            onTap: _showAvatarEditOptions,
          ),
        ),
        const SizedBox(height: 16),
        // نام کاربری
        _buildUsernameDisplay(),
      ],
    );
  }

// ═══════════════════════════════════════════════════════════
// نمایش نام کاربری
// ═══════════════════════════════════════════════════════════
  Widget _buildUsernameDisplay() {
    final hasUsername = _profile?.hasUsername ?? false;

    print(
        '🎨 _buildUsernameDisplay: hasUsername=$hasUsername, username=${_profile?.username}');

    if (!hasUsername) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UsernameSetupScreen(
                userId: _profile!.userId,
                currentUsername: null,
                isFirstTime: false,
              ),
            ),
          ).then((result) async {
            if (result == true && mounted) {
              await _loadProfile();
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _theme.cardSecondaryColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.alternate_email,
                color: _theme.textColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'انتخاب نام کاربری',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _theme.textColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // کاربر username دارد
    return GestureDetector(
      onTap: _showUsernameOptions,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _theme.cardSecondaryColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '@${_profile!.username}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _theme.textColor,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.edit,
              size: 14,
              color: _theme.textColor,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
// نمایش گزینه‌های ویرایش آواتار
// ═══════════════════════════════════════════════════════════
  void _showAvatarEditOptions() {
    // مستقیم به انتخاب عکس برو
    _showAvatarSourcePicker();
  }

  void _showAvatarSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _theme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(top: false, child: Builder(builder: (_) {
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
                    color: _theme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'تغییر عکس پروفایل',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _theme.textColor,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildSourceButton(
                        icon: Icons.camera_alt,
                        label: 'دوربین',
                        onTap: () {
                          Navigator.pop(context);
                          _pickAndUploadAvatar(ImageSource.camera);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSourceButton(
                        icon: Icons.photo_library,
                        label: 'گالری',
                        onTap: () {
                          Navigator.pop(context);
                          _pickAndUploadAvatar(ImageSource.gallery);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // اگر آواتار داشت، حذف
                if (_profile?.hasAvatar == true)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _removeAvatar();
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text(
                      'حذف عکس پروفایل',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        );
      })),
    );
  }

  Widget _buildSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: _theme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _theme.primaryColor.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: _theme.primaryColor, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _theme.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1920,
      );

      if (picked == null) return;

      // حالا کراپ کن
      if (!mounted) return;

      final cropService = ImageCropService();
      final croppedFile = await cropService.cropAvatar(
        imageFile: File(picked.path),
        context: context,
        primaryColor: _theme.primaryColor,
      );

      if (croppedFile == null) {
        // کاربر لغو کرد
        return;
      }

      setState(() => _isUploadingAvatar = true);

      // خواندن bytes از فایل کراپ‌شده
      final bytes = await croppedFile.readAsBytes();

      // آپلود
      final avatarUrl = await _storage.uploadAvatar(
        userId: _profile!.userId,
        bytes: bytes,
        originalFileName:
            'avatar.jpg', // همیشه jpg چون image_cropper jpg می‌دهد
      );

      // ذخیره در DB
      await _supabase.updateAvatarUrl(_profile!.userId, avatarUrl);

      // Reload
      await _loadProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('عکس پروفایل با موفقیت آپلود شد'),
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
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _removeAvatar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _theme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'حذف عکس پروفایل',
          style: TextStyle(color: _theme.textColor),
        ),
        content: Text(
          'آیا مطمئن هستی؟',
          style: TextStyle(color: _theme.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase.updateAvatarUrl(_profile!.userId, null);
      await _loadProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('عکس پروفایل حذف شد'),
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

// ═══════════════════════════════════════════════════════════
// نمایش گزینه‌های username
// ═══════════════════════════════════════════════════════════
  void _showUsernameOptions() {
    if (_profile?.hasUsername != true) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: _theme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (dialogContext) => SafeArea(top: false, child: Builder(builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _theme.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // نمایش فعلی
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _theme.primaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _theme.primaryColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.alternate_email,
                      color: _theme.primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'نام کاربری فعلی',
                            style: TextStyle(
                              fontSize: 11,
                              color: _theme.textSecondaryColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@${_profile!.username}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _theme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: _profile!.username!),
                        );
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('کپی شد'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: Icon(Icons.copy, color: _theme.primaryColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.edit, color: _theme.primaryColor),
                title: Text(
                  'ویرایش نام کاربری',
                  style: TextStyle(color: _theme.textColor),
                ),
                subtitle: Text(
                  'بین هر تغییر ۱ دقیقه فاصله لازم است',
                  style: TextStyle(
                    fontSize: 12,
                    color: _theme.textSecondaryColor,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(dialogContext);

                  // حالا برو به UsernameSetupScreen با username فعلی
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UsernameSetupScreen(
                        userId: _profile!.userId,
                        currentUsername: _profile!.username, // مهم!
                      ),
                    ),
                  );

                  if (result == true && mounted) {
                    await _loadProfile();
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      })),
    );
  }

// ═══════════════════════════════════════════════════════════
// متدهای ناوبری
// ═══════════════════════════════════════════════════════════
  Future<void> _openGallery() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GalleryScreen(
          userId: _profile!.userId,
          userName: _profile!.name,
        ),
      ),
    );
    // بعد از بازگشت، profile را reload کن (ممکن است آواتار عوض شده باشد)
    await _loadProfile();
  }

  Future<void> _openUsernameSetup() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UsernameSetupScreen(
          userId: _profile!.userId,
          currentUsername: _profile!.username,
        ),
      ),
    );

    if (result == true) {
      await _loadProfile();
    }
  }

  Future<void> _openAvatarCustomization() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AvatarCustomizationScreen(
          userId: _profile!.userId,
          currentProfile: _profile!,
        ),
      ),
    );
    await _loadProfile();
  }

  // ==================== بخش اطلاعات کاربر ====================

// ═══════════════════════════════════════════════════════════
// ویجت اطلاعات کاربر (کشویی)
// ═══════════════════════════════════════════════════════════
  Widget _buildUserInfoSection() {
    final calendar = Provider.of<CalendarProvider>(context, listen: false);
    return Container(
      decoration: BoxDecoration(
        color: _theme.cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: _theme.softShadow,
      ),
      child: Column(
        children: [
          // ═══════════════════════════════════════════════════════
          // ─── هدر کشو (همیشه قابل مشاهده) ───
          // ═══════════════════════════════════════════════════════
          GestureDetector(
            onTap: () {
              setState(() {
                _isUserInfoExpanded = !_isUserInfoExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  // آیکون کاربر
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _theme.tone(Tone.lilac).bg,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: _theme.tone(Tone.lilac).fg,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // نام کاربر
                  Expanded(
                    child: Text(
                      _profile?.name ?? 'کاربر',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _theme.textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // فلش کشو
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 300),
                    turns: _isUserInfoExpanded ? 0.5 : 0.0,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: _theme.textSecondaryColor,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ═══════════════════════════════════════════════════════
          // ─── محتوای کشو (فقط وقتی باز است) ───
          // ═══════════════════════════════════════════════════════
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _isUserInfoExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // ─── ردیف اطلاعات ───
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _buildMinimalInfoItem(
                              label: 'نام',
                              value: _profile!.name,
                              icon: Icons.person_outline_rounded,
                            ),
                            const SizedBox(height: 14),
                            _buildMinimalInfoItem(
                              label: 'ایمیل',
                              value: _profile?.email?.split('@').first ?? '---',
                              icon: Icons.email_outlined,
                            ),
                            const SizedBox(height: 14),
                            _buildMinimalInfoItem(
                              label: 'شماره تماس',
                              value: _profile?.phone ?? '---',
                              icon: Icons.phone_outlined,
                            ),
                            const SizedBox(height: 14),
                            _buildMinimalInfoItem(
                              label: 'تاریخ تولد',
                              value: _formatDateShort(
                                  _profile?.birthDate, calendar), // 
                              icon: Icons.cake_outlined,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            _buildMinimalInfoItem(
                              label: 'سن',
                              value: _profile?.realAge?.toString() ?? '---',
                              icon: Icons.calendar_today_outlined,
                            ),
                            const SizedBox(height: 14),
                            _buildMinimalInfoItem(
                              label: 'جنسیت',
                              value: _getGenderText(_profile?.gender),
                              icon: Icons.people_outline,
                            ),
                            const SizedBox(height: 14),
                            _buildMinimalInfoItem(
                              label: 'عضو از',
                              value: _formatDateShort(
                                  _profile?.registeredAt, calendar), // 
                              icon: Icons.history_outlined,
                            ),
                            const SizedBox(height: 14),
                            _buildMinimalInfoItem(
                              label: 'سن آواتار',
                              value: '${_profile?.avatarAge ?? 0} روز',
                              icon: Icons.emoji_people_outlined,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ─── دکمه ویرایش ───
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showEditProfileDialog,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text(
                        'ویرایش اطلاعات',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _theme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // متد کپی کردن ID
  void _copyToClipboard(String text) {
    // استفاده از Clipboard
    Clipboard.setData(ClipboardData(text: text));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID یکتا کپی شد'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ==================== ویجت آیتم اطلاعات مینیمال ====================

  Widget _buildMinimalInfoItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _theme.backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _theme.primaryColor.withValues(alpha: 0.12),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _theme.primaryColor.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(icon, size: 16, color: _theme.primaryColor),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: _theme.textSecondaryColor,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: value == '---'
                        ? _theme.textSecondaryColor
                        : _theme.textColor,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== متدهای کمکی ====================

  String _formatDateShort(DateTime? date, CalendarProvider calendar) {
    if (date == null) return '---';
    return calendar.formatShort(date);
  }

  String _getGenderText(String? gender) {
    switch (gender) {
      case 'male':
        return 'مرد';
      case 'female':
        return 'زن';
      case 'other':
        return 'سایر';
      default:
        return 'وارد نشده';
    }
  }

  String _getGenderValue(String genderText) {
    switch (genderText) {
      case 'مرد':
        return 'male';
      case 'زن':
        return 'female';
      case 'سایر':
        return 'other';
      default:
        return 'other';
    }
  }

  // ==================== دکمه‌ها ====================

  Widget _buildTermsButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TermsAndConditionsScreen(),
            ),
          );
        },
        icon: const Icon(Icons.description, size: 20),
        label: const Text(
          'قوانین و مقررات',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _theme.surfaceColor,
          foregroundColor: _theme.textColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildSettingsButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          );
        },
        icon: const Icon(Icons.settings, size: 20),
        label: const Text(
          'تنظیمات',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _theme.primaryColor,
          foregroundColor: _theme.secondaryColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  // ==================== دیالوگ ویرایش پروفایل ====================

  void _showEditProfileDialog() {
    final calendar = Provider.of<CalendarProvider>(context, listen: false);
    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController(text: _profile!.name);
    final phoneController = TextEditingController(text: _profile?.phone ?? '');
    final emailController = TextEditingController(text: _profile?.email ?? '');
    final ageController = TextEditingController(
      text: _profile?.realAge?.toString() ?? '',
    );
    final genderController = TextEditingController(
      text: _getGenderText(_profile?.gender),
    );

    DateTime? selectedDate = _profile?.birthDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(top: false, child: Builder(builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ویرایش اطلاعات',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _theme.textColor,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildEditField(
                          label: 'نام کاربری',
                          controller: nameController,
                          icon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'لطفاً نام کاربری را وارد کنید';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildEditField(
                          label: 'شماره تلفن',
                          controller: phoneController,
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        _buildEditField(
                          label: 'ایمیل',
                          controller: emailController,
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          enabled: false,
                        ),
                        const SizedBox(height: 12),
                        _buildEditField(
                          label: 'سن',
                          controller: ageController,
                          icon: Icons.cake_outlined,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedDate ?? DateTime.now(),
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() {
                                selectedDate = date;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: _theme.isDarkMode
                                  ? const Color(0xFF2A2A2A)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _theme.borderColor),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  color: _theme.primaryColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    selectedDate != null
                                        ? _formatDate(selectedDate!, calendar)
                                        : 'تاریخ تولد را انتخاب کنید',
                                    style: TextStyle(
                                      color: selectedDate != null
                                          ? _theme.textColor
                                          : _theme.textSecondaryColor, // 
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: _theme.textSecondaryColor, // 
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _getGenderValue(genderController.text),
                          style: TextStyle(color: _theme.textColor), // 
                          dropdownColor: _theme.surfaceColor, // 
                          decoration: InputDecoration(
                            labelText: 'جنسیت',
                            labelStyle: TextStyle(
                                color: _theme.textSecondaryColor), // 
                            prefixIcon: Icon(
                              Icons.people_outline,
                              color: _theme.primaryColor,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            // تم‌محور
                            fillColor: _theme.isDarkMode
                                ? const Color(0xFF2A2A2A)
                                : Colors.grey.shade50,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'male', child: Text('مرد')),
                            DropdownMenuItem(
                                value: 'female', child: Text('زن')),
                            DropdownMenuItem(
                                value: 'other', child: Text('سایر')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              genderController.text = _getGenderText(value);
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;

                              // Capture context قبل از await
                              final navigator = Navigator.of(context);

                              await _updateProfile(
                                name: nameController.text,
                                phone: phoneController.text,
                                email: emailController.text,
                                realAge: int.tryParse(ageController.text),
                                birthDate: selectedDate,
                                gender: _getGenderValue(genderController.text),
                              );

                              // چک کن هنوز mounted است
                              if (mounted && navigator.canPop()) {
                                navigator.pop();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _theme.primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'ذخیره تغییرات',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _theme.secondaryColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      })),
    );
  }

  // ==================== ویجت فیلد ویرایش ====================

  Widget _buildEditField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: _theme.textColor), // 
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _theme.textSecondaryColor), // 
        prefixIcon: Icon(icon, color: _theme.primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        // تم‌محور
        fillColor:
            _theme.isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
  // ==================== به‌روزرسانی پروفایل ====================

  Future<void> _updateProfile({
    required String name,
    required String phone,
    required String email,
    int? realAge,
    DateTime? birthDate,
    String? gender,
  }) async {
    try {
      final data = {
        'name': name,
        'phone': phone,
        'email': email,
        'real_age': realAge,
        'birth_date': birthDate?.toIso8601String().split('T').first,
        'gender': gender,
      };

      await _supabase.client
          .from('profiles')
          .update(data)
          .eq('user_id', _profile!.userId);

      // فقط profile را reload کن (نه ساخت دستی)
      await _loadProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('pm.pi.updated')),
            backgroundColor: _theme.successColor,
            duration: const Duration(seconds: 2),
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

  // ==================== متدهای کمکی دیگر ====================

  void _showEditDialog(String label, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    const Color ink = Color(0xFF090909);

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: _theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('pm.pi.edit_field', {'label': label}),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _theme.textColor,
                ),
              ),
              const SizedBox(height: 14),
              _buildEditField(
                label: label,
                controller: controller,
                icon: Icons.edit_outlined,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(dialogContext),
                      child: Container(
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _theme.cardSecondaryColor,
                          borderRadius: BorderRadius.circular(27),
                        ),
                        child: Text(
                          context.tr('pm.pi.cancel'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _theme.textColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(dialogContext);
                        await _updateField(label, controller.text);
                      },
                      child: Container(
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: ink,
                          borderRadius: BorderRadius.circular(27),
                        ),
                        child: Text(
                          context.tr('pm.pi.save_short'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _theme.effectivePrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateField(String label, String value) async {
    final fields = {
      'نام کاربری': 'name',
      'شماره تلفن': 'phone',
      'سن': 'real_age',
      'تاریخ تولد': 'birth_date',
      'جنسیت': 'gender',
    };

    final field = fields[label];
    if (field == null) return;

    try {
      final data = {field: value};
      await _supabase.client
          .from('profiles')
          .update(data)
          .eq('user_id', _profile!.userId);

      setState(() {
        _profile = _profile!.copyWith(
          name: field == 'name' ? value : null,
          phone: field == 'phone' ? value : null,
          realAge: field == 'real_age' ? int.tryParse(value) : null,
          gender: field == 'gender' ? value : null,
        );
      });

      // ذخیره در LocalStorage
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);
      final profileMap = _profile!.toMap();
      profileMap['user_id'] = _profile!.userId;
      await syncProvider.saveProfileToLocal(profileMap);
    } catch (e) {
      print('Error updating field: $e');
    }
  }

  String _formatDate(DateTime? date, CalendarProvider calendar) {
    if (date == null) return 'وارد نشده';
    return calendar.formatShort(date);
  }
}
