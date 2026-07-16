// lib/features/profile/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/services/supabase_service.dart';
import '../models/profile_model.dart';
import '../widgets/avatar_customization_screen.dart';
import '../widgets/analytics_detail_screen.dart';
import '../widgets/xp_stats_widget.dart';
import '../widgets/analytics_overview_widget.dart';
import '../widgets/terms_and_conditions_screen.dart';
import '../widgets/settings_screen.dart';
import '../widgets/streak_card_widget.dart';
import '/../providers/sync_provider.dart';

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

  int _currentStreak = 0;
  int _bestStreak = 0;
  int _weeklyStreak = 0;

  DateTime? _lastRefreshTime;
  static const Duration _minRefreshInterval = Duration(seconds: 1);

  // ✅ برای جلوگیری از بارگذاری مجدد در حین بارگذاری
  bool _isLoadingInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();

    // ✅ گوش دادن به تغییرات notifier
    widget.refreshNotifier?.addListener(_onRefreshTriggered);

    // ✅ اگر notifier مقداردهی شده، یکبار ریفرش کن (برای همگام‌سازی اولیه)
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
      '🔄 Profile refresh triggered from notifier: ${widget.refreshNotifier?.value}',
    );

    final now = DateTime.now();
    if (_lastRefreshTime != null &&
        now.difference(_lastRefreshTime!) < _minRefreshInterval) {
      print('⏭️ Skip refresh: too soon');
      return;
    }
    _lastRefreshTime = now;

    if (_isRefreshing) {
      print('⏭️ Skip refresh: already refreshing');
      return;
    }

    _isRefreshing = true;
    print('🔄 Refreshing profile...');

    _loadProfile()
        .then((_) {
          // ✅ بعد از بارگذاری پروفایل، آنالytics را هم ریفرش کن
          _analyticsKey.currentState?.refreshData();
          _isRefreshing = false;
          print('✅ Profile refresh completed');
        })
        .catchError((e) {
          print('❌ Profile refresh error: $e');
          _isRefreshing = false;
        });
  }

  // ==================== متد اصلی بارگذاری پروفایل ====================

  Future<void> _loadProfile() async {
    if (_isLoadingInProgress) {
      print('⏭️ Skip loading: already in progress');
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

      // ✅ اگر آفلاین هستیم، فقط از LocalStorage بخوان
      if (!syncProvider.isOnline) {
        print('📱 OFFLINE - Loading from LocalStorage...');
        final success = await _loadFromLocal(syncProvider);
        if (!success && mounted) {
          setState(() {
            _errorMessage = 'برای بارگذاری اطلاعات به اتصال اینترنت نیاز دارید';
            _isLoading = false;
          });
        }
        _isLoadingInProgress = false;
        return;
      }

      // ✅ اگر آنلاین هستیم، از سرور بگیر
      print('🌐 Online - loading from Supabase...');
      final success = await _loadFromSupabase(syncProvider);
      if (success) {
        _isLoadingInProgress = false;
        await _calculateWeeklyStreak();
        if (mounted) {
          setState(() {});
        }
        return;
      }

      // ✅ اگر از سرور خطا خورد، از LocalStorage بخوان
      print('📱 Loading from LocalStorage...');
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
      print('❌ Error loading profile: $e');
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
  // ==================== بارگذاری از LocalStorage ====================

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

        print('✅ Profile loaded from LOCAL storage');
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

      print('⚠️ No profile found in LOCAL storage');
      return false;
    } catch (e) {
      print('❌ Error loading from local: $e');
      return false;
    }
  }

  // ==================== بارگذاری از Supabase ====================

  Future<bool> _loadFromSupabase(SyncProvider syncProvider) async {
    try {
      final currentUser = await _supabase.getCurrentUser();

      if (currentUser == null) {
        print('⚠️ No user logged in');
        if (mounted) {
          setState(() {
            _errorMessage = 'لطفاً وارد حساب کاربری خود شوید';
            _isLoading = false;
          });
        }
        return false;
      }

      print('👤 Loading profile for user: ${currentUser.id}');

      final response = await _supabase.client
          .from('profiles')
          .select()
          .eq('user_id', currentUser.id)
          .maybeSingle();

      if (response != null) {
        _profile = UserProfile.fromMap(response, currentUser.id);
        _currentStreak = response['current_streak'] ?? 0;
        _bestStreak = response['best_streak'] ?? 0;
        _weeklyStreak = response['weekly_streak'] ?? 0;

        // ✅ ذخیره در LocalStorage
        await syncProvider.saveProfileToLocal(response);

        print('✅ Profile loaded from SUPABASE');
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

      // ✅ پروفایل وجود ندارد - یک پروفایل جدید بساز
      print('🆕 No profile found, creating new...');
      await _createNewProfile();
      return true;
    } catch (e) {
      print('❌ Error loading from Supabase: $e');
      return false;
    }
  }

  // ==================== ساخت پروفایل جدید ====================

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

      final newProfile = UserProfile(
        userId: currentUser.id,
        name: currentUser.email?.split('@').first.isNotEmpty == true
            ? currentUser.email!.split('@').first
            : 'کاربر',
        email: currentUser.email,
        registeredAt: DateTime.now(),
        totalXp: 0,
      );

      // ✅ ذخیره در Supabase
      await _supabase.client.from('profiles').insert({
        'user_id': currentUser.id,
        'name': newProfile.name,
        'email': newProfile.email,
        'total_xp': 0,
        'current_streak': 0,
        'best_streak': 0,
        'weekly_streak': 0,
      });

      // ✅ ایجاد user_progress
      await _supabase.createUserProgress(currentUser.id);

      // ✅ تنظیم پروفایل محلی
      _profile = newProfile;
      _currentStreak = 0;
      _bestStreak = 0;
      _weeklyStreak = 0;

      // ✅ ذخیره در LocalStorage
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);
      final profileMap = newProfile.toMap();
      profileMap['user_id'] = currentUser.id;
      profileMap['current_streak'] = 0;
      profileMap['best_streak'] = 0;
      profileMap['weekly_streak'] = 0;
      await syncProvider.saveProfileToLocal(profileMap);

      print('✅ New profile created successfully');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error creating profile: $e');
      // ✅ در صورت خطا، یک پروفایل پیش‌فرض بساز
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

        print('✅ Fallback profile created');

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error creating fallback profile: $e');
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

      // ✅ ذخیره در LocalStorage
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);
      final profileMap = _profile!.toMap();
      profileMap['user_id'] = _profile!.userId;
      profileMap['current_streak'] = _currentStreak;
      profileMap['best_streak'] = _bestStreak;
      profileMap['weekly_streak'] = _weeklyStreak;
      await syncProvider.saveProfileToLocal(profileMap);

      print('✅ Profile saved to Supabase and LocalStorage');
    } catch (e) {
      print('❌ Error saving profile: $e');
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

      // ✅ به‌روزرسانی اگر تغییر کرده
      if (_profile!.weeklyStreak != streak) {
        _profile = UserProfile(
          userId: _profile!.userId,
          name: _profile!.name,
          phone: _profile!.phone,
          email: _profile!.email,
          birthDate: _profile!.birthDate,
          realAge: _profile!.realAge,
          gender: _profile!.gender,
          registeredAt: _profile!.registeredAt,
          avatarStyle: _profile!.avatarStyle,
          skinColor: _profile!.skinColor,
          hairStyle: _profile!.hairStyle,
          hairColor: _profile!.hairColor,
          eyeStyle: _profile!.eyeStyle,
          eyeColor: _profile!.eyeColor,
          mouthStyle: _profile!.mouthStyle,
          accessoryType: _profile!.accessoryType,
          outfitStyle: _profile!.outfitStyle,
          backgroundStyle: _profile!.backgroundStyle,
          totalXp: _profile!.totalXp,
          weeklyStreak: streak,
          lastStreakUpdate: DateTime.now(),
          currentStreak: _profile!.currentStreak,
          bestStreak: _profile!.bestStreak,
        );
        await _saveProfile();

        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      print('⚠️ Error calculating weekly streak: $e');
    }
  }

  // ==================== Widget Build ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Consumer<SyncProvider>(
        builder: (context, syncProvider, child) {
          // ✅ حالت بارگذاری
          if (_isLoading && _profile == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF2563EB)),
                  SizedBox(height: 16),
                  Text(
                    'در حال بارگذاری پروفایل...',
                    style: TextStyle(color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            );
          }

          // ✅ حالت خطا
          if (_errorMessage != null && _profile == null) {
            return _buildErrorState();
          }

          // ✅ حالت خالی
          if (_profile == null) {
            return _buildEmptyState();
          }

          // ✅ نمایش محتوا
          return _buildProfileContent();
        },
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
              backgroundColor: const Color(0xFF2563EB),
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
              backgroundColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== محتوای اصلی پروفایل ====================

  Widget _buildProfileContent() {
    final List<bool> weekDays = List.generate(7, (index) {
      return index < _weeklyStreak;
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          _buildAvatarSection(),
          const SizedBox(height: 24),
          _buildUserInfoSection(),
          const SizedBox(height: 24),

          StreakCardWidget(
            currentStreak: _currentStreak,
            bestStreak: _bestStreak,
            weeklyStreak: _weeklyStreak,
            weekDays: weekDays,
          ),
          const SizedBox(height: 24),

          XpStatsWidget(
            totalXp: _profile!.totalXp,
            level: _profile!.level,
            xpToNextLevel: _profile!.xpNeededForNextLevel,
          ),
          const SizedBox(height: 24),

          // ✅ اضافه کردن key برای ریفرش
          AnalyticsOverviewWidget(
            key: _analyticsKey, // ✅ اضافه کردن key
            userId: _profile!.userId,
            onTapMore: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AnalyticsDetailScreen(userId: _profile!.userId),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          _buildTermsButton(),
          const SizedBox(height: 12),
          _buildSettingsButton(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ==================== بخش آواتار ====================

  Widget _buildAvatarSection() {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 8,
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
                  child: Text(
                    _profile?.name.substring(0, 1).toUpperCase() ?? '?',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AvatarCustomizationScreen(
                        userId: _profile!.userId,
                        currentProfile: _profile!,
                      ),
                    ),
                  ).then((_) => _loadProfile());
                },
                icon: const Icon(
                  Icons.edit,
                  color: Color(0xFF2563EB),
                  size: 24,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== بخش اطلاعات کاربر ====================

  Widget _buildUserInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'اطلاعات کاربری',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                  letterSpacing: -0.3,
                ),
              ),
              GestureDetector(
                onTap: () => _showEditProfileDialog(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: const Color(0xFF2563EB).withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: Color(0xFF2563EB),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'ویرایش',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

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
                      value: _formatDateShort(_profile?.birthDate),
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
                      value: _formatDateShort(_profile?.registeredAt),
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
        ],
      ),
    );
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
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF2), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(icon, size: 16, color: const Color(0xFF2563EB)),
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
                    color: Colors.grey.shade500,
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
                        ? Colors.grey.shade400
                        : const Color(0xFF1A1A2E),
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

  String _formatDateShort(DateTime? date) {
    if (date == null) return '---';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
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
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1A1A2E),
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
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
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
      builder: (context) {
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
                            const Text(
                              'ویرایش اطلاعات',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A2E),
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
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  color: const Color(0xFF2563EB),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    selectedDate != null
                                        ? _formatDate(selectedDate!)
                                        : 'تاریخ تولد را انتخاب کنید',
                                    style: TextStyle(
                                      color: selectedDate != null
                                          ? const Color(0xFF1A1A2E)
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        DropdownButtonFormField<String>(
                          value: _getGenderValue(genderController.text),
                          decoration: InputDecoration(
                            labelText: 'جنسیت',
                            prefixIcon: const Icon(
                              Icons.people_outline,
                              color: Color(0xFF2563EB),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'male', child: Text('مرد')),
                            DropdownMenuItem(
                              value: 'female',
                              child: Text('زن'),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text('سایر'),
                            ),
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
                              if (formKey.currentState!.validate()) {
                                await _updateProfile(
                                  name: nameController.text,
                                  phone: phoneController.text,
                                  email: emailController.text,
                                  realAge: int.tryParse(ageController.text),
                                  birthDate: selectedDate,
                                  gender: _getGenderValue(
                                    genderController.text,
                                  ),
                                );
                                Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'ذخیره تغییرات',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
      },
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
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF2563EB)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
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

      setState(() {
        _profile = UserProfile(
          userId: _profile!.userId,
          name: name,
          phone: phone,
          email: email,
          birthDate: birthDate,
          realAge: realAge,
          gender: gender,
          registeredAt: _profile!.registeredAt,
          avatarStyle: _profile!.avatarStyle,
          skinColor: _profile!.skinColor,
          hairStyle: _profile!.hairStyle,
          hairColor: _profile!.hairColor,
          eyeStyle: _profile!.eyeStyle,
          eyeColor: _profile!.eyeColor,
          mouthStyle: _profile!.mouthStyle,
          accessoryType: _profile!.accessoryType,
          outfitStyle: _profile!.outfitStyle,
          backgroundStyle: _profile!.backgroundStyle,
          totalXp: _profile!.totalXp,
          weeklyStreak: _profile!.weeklyStreak,
          lastStreakUpdate: _profile!.lastStreakUpdate,
          currentStreak: _profile!.currentStreak,
          bestStreak: _profile!.bestStreak,
        );
      });

      // ✅ ذخیره در LocalStorage
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);
      final profileMap = _profile!.toMap();
      profileMap['user_id'] = _profile!.userId;
      await syncProvider.saveProfileToLocal(profileMap);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اطلاعات با موفقیت به‌روزرسانی شد ✅'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==================== متدهای کمکی دیگر ====================

  void _showEditDialog(String label, String currentValue) {
    final controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('ویرایش $label'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _updateField(label, controller.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('ذخیره'),
          ),
        ],
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
        _profile = UserProfile(
          userId: _profile!.userId,
          name: field == 'name' ? value : _profile!.name,
          phone: field == 'phone' ? value : _profile!.phone,
          email: _profile!.email,
          birthDate: _profile!.birthDate,
          realAge: field == 'real_age'
              ? int.tryParse(value)
              : _profile!.realAge,
          gender: field == 'gender' ? value : _profile!.gender,
          registeredAt: _profile!.registeredAt,
          avatarStyle: _profile!.avatarStyle,
          skinColor: _profile!.skinColor,
          hairStyle: _profile!.hairStyle,
          hairColor: _profile!.hairColor,
          eyeStyle: _profile!.eyeStyle,
          eyeColor: _profile!.eyeColor,
          mouthStyle: _profile!.mouthStyle,
          accessoryType: _profile!.accessoryType,
          outfitStyle: _profile!.outfitStyle,
          backgroundStyle: _profile!.backgroundStyle,
          totalXp: _profile!.totalXp,
          weeklyStreak: _profile!.weeklyStreak,
          lastStreakUpdate: _profile!.lastStreakUpdate,
          currentStreak: _profile!.currentStreak,
          bestStreak: _profile!.bestStreak,
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'وارد نشده';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}
