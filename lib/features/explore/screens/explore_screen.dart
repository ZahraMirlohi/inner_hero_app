// lib/features/explore/screens/explore_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // ✅ اضافه کردن import
import '/services/supabase_service.dart';
import '../models/package_model.dart';
import '../models/quest_model.dart';
import '../models/user_quest_model.dart';
import 'challenges_tab.dart';
import 'packages_tab.dart';
import 'quests_tab.dart';
import 'cosmetics_tab.dart';
import 'leaderboard_tab.dart';
import '/providers/sync_provider.dart'; // ✅ اضافه کردن import

class ExploreScreen extends StatefulWidget {
  final ValueNotifier<int>? refreshNotifier;

  const ExploreScreen({super.key, this.refreshNotifier});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;

  List<Map<String, dynamic>> _challenges = [];
  List<Map<String, dynamic>> _myChallenges = [];
  List<Package> _templatePackages = [];
  List<Quest> _quests = [];
  List<Quest> _completedQuests = [];

  bool _isLoading = true;
  bool _isInitialized = false;
  bool _isLoadingInProgress = false;
  String _errorMessage = '';
  String _currentUserId = '';

  final _supabase = SupabaseService();
  final Map<String, _CachedChallengeDetails> _challengeDetailsCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    widget.refreshNotifier?.addListener(_onRefreshTriggered);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    widget.refreshNotifier?.removeListener(_onRefreshTriggered);
    super.dispose();
  }

  void _onRefreshTriggered() {
    print('🔄 Refresh triggered from notifier');
    _isInitialized = false;
    _isLoadingInProgress = false;
    _loadData();
  }

  void forceRefresh() {
    print('🔄 Force refresh called');
    _isInitialized = false;
    _isLoadingInProgress = false;
    _loadData();
  }

  // ==================== بارگذاری داده‌ها با پشتیبانی از آفلاین ====================

  Future<void> _loadData() async {
    // ✅ جلوگیری از اجرای همزمان
    if (_isInitialized || _isLoadingInProgress) {
      print('⏭️ _loadData: Skip - already initialized or in progress');
      return;
    }

    if (!mounted) {
      print('⏭️ _loadData: Skip - widget not mounted');
      return;
    }

    print('🔄 _loadData: Starting...');
    _isLoadingInProgress = true;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);
      final currentUser = await _supabase.getCurrentUser();

      // ✅ بررسی و بروزرسانی وضعیت چالش‌های کاربر
      if (_currentUserId.isNotEmpty) {
        await _supabase.checkAndUpdateUserChallenges(_currentUserId);
      }

      if (currentUser == null) {
        print('⚠️ _loadData: No user logged in');
        if (mounted) {
          setState(() {
            _errorMessage = 'لطفاً وارد حساب کاربری خود شوید';
            _isLoading = false;
            _isInitialized = true;
            _isLoadingInProgress = false;
          });
        }
        return;
      }

      _currentUserId = currentUser.id;
      print('👤 _loadData: User ID: $_currentUserId');

      // ✅ مرحله 1: همیشه اول از داده‌های محلی استفاده کن
      bool hasLocalData = false;

      if (syncProvider.hasChallenges) {
        _challenges = syncProvider.challenges;
        _myChallenges = syncProvider.userChallenges;
        hasLocalData = true;
        print('📱 Loaded ${_challenges.length} challenges from LOCAL storage');
      }

      if (syncProvider.packages.isNotEmpty) {
        _templatePackages = syncProvider.packages;
        hasLocalData = true;
        print(
          '📱 Loaded ${_templatePackages.length} packages from LOCAL storage',
        );
      }

      if (syncProvider.quests.isNotEmpty) {
        _quests = syncProvider.quests;
        hasLocalData = true;
        print('📱 Loaded ${_quests.length} quests from LOCAL storage');
      }

      // ✅ مرحله 2: اگر آنلاین هستیم، در پس‌زمینه به‌روزرسانی کن
      if (syncProvider.isOnline) {
        print('🌐 Online - updating data in background...');
        await _loadFromSupabase(syncProvider);
      } else if (!hasLocalData) {
        // ✅ اگر آفلاین هستیم و داده محلی نداریم
        setState(() {
          _errorMessage = 'برای بارگذاری اطلاعات به اتصال اینترنت نیاز دارید';
          _isLoading = false;
          _isInitialized = true;
          _isLoadingInProgress = false;
        });
        return;
      }

      // ✅ مرحله 3: پردازش داده‌های چالش
      _processChallenges();

      // ✅ مرحله 4: پردازش ماموریت‌های تکمیل شده
      _processCompletedQuests();

      print('🎬 _loadData: Starting animation...');
      if (!_animationController.isAnimating) {
        _animationController.forward();
      }

      if (mounted) {
        print('✅ _loadData: Success - Updating UI');
        setState(() {
          _isLoading = false;
          _isInitialized = true;
          _isLoadingInProgress = false;
        });
      }
    } catch (e) {
      print('❌ _loadData: Error - $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'خطا در خواندن از دیتابیس: ${e.toString()}';
          _isLoading = false;
          _isInitialized = true;
          _isLoadingInProgress = false;
        });
      }
    }
  }

  // ✅ بارگذاری از Supabase در پس‌زمینه
  Future<void> _loadFromSupabase(SyncProvider syncProvider) async {
    try {
      final results = await Future.wait([
        _supabase.getChallenges(),
        _supabase.getUserChallenges(_currentUserId),
        _supabase.getPackages(),
        _supabase.getQuests(),
        _supabase.getUserQuests(_currentUserId),
      ]);

      final newChallenges = results[0] as List<Map<String, dynamic>>;
      final newUserChallenges = results[1] as List<Map<String, dynamic>>;
      final newPackages = results[2] as List<Package>;
      final newQuests = results[3] as List<Quest>;
      final userQuests = results[4] as List<UserQuest>;

      // ✅ به‌روزرسانی داده‌ها
      if (newChallenges.isNotEmpty) {
        _challenges = newChallenges;
        await syncProvider.saveChallengesToLocal(newChallenges);
      }

      if (newUserChallenges.isNotEmpty) {
        _myChallenges = newUserChallenges;
        await syncProvider.saveUserChallengesToLocal(newUserChallenges);
      }

      if (newPackages.isNotEmpty) {
        _templatePackages = newPackages;
        await syncProvider.savePackagesToLocal(newPackages);
      }

      if (newQuests.isNotEmpty) {
        _quests = newQuests;
        await syncProvider.saveQuestsToLocal(newQuests);
      }

      // ✅ پردازش ماموریت‌های تکمیل شده
      final completedQuestIds = userQuests
          .where((uq) => uq.isCompleted == true)
          .map((uq) => uq.questId)
          .toList();

      _completedQuests = _quests
          .where((q) => completedQuestIds.contains(q.id))
          .toList();

      print(
        '📊 Loaded from Supabase: ${_challenges.length} challenges, ${_templatePackages.length} packages, ${_quests.length} quests',
      );
    } catch (e) {
      print('⚠️ Background sync error: $e');
    }
  }

  void _processChallenges() {
    final now = DateTime.now();
    for (int i = 0; i < _challenges.length; i++) {
      final challenge = _challenges[i];
      final challengeId = challenge['id'];

      // ✅ بررسی تاریخ ثبت‌نام
      if (challenge['registration_end_date'] != null) {
        try {
          final registrationEnd = DateTime.parse(
            challenge['registration_end_date'],
          );
          final daysLeft = registrationEnd.difference(now).inDays;
          _challenges[i]['daysLeft'] = daysLeft > 0 ? daysLeft : 0;
          _challenges[i]['isRegistrationClosed'] = daysLeft <= 0;
        } catch (e) {
          _challenges[i]['daysLeft'] = 0;
          _challenges[i]['isRegistrationClosed'] = true;
        }
      } else {
        _challenges[i]['isRegistrationClosed'] = false;
      }

      // ✅ بررسی وضعیت عضویت - با بررسی دقیق‌تر
      final isJoined = _myChallenges.any((c) => c['id'] == challengeId);
      _challenges[i]['isJoined'] = isJoined;

      // ✅ اگر کاربر عضو هست، وضعیت رو از _myChallenges بگیر
      if (isJoined) {
        final userChallenge = _myChallenges.firstWhere(
          (c) => c['id'] == challengeId,
          orElse: () => {},
        );
        if (userChallenge.isNotEmpty) {
          _challenges[i]['isCompleted'] = userChallenge['isCompleted'] ?? false;
          _challenges[i]['status'] = userChallenge['status'] ?? 'active';
          _challenges[i]['progress'] = userChallenge['progress'] ?? 0;
        }
      } else {
        _challenges[i]['isCompleted'] = false;
        _challenges[i]['status'] = null;
        _challenges[i]['progress'] = 0;
      }
    }
  }

  // ✅ پردازش ماموریت‌های تکمیل شده
  void _processCompletedQuests() {
    // این متد در _loadFromSupabase پردازش می‌شود
  }

  // ==================== متدهای چالش ====================

  // lib/features/explore/screens/explore_screen.dart

  Future<void> _joinChallenge(Map<String, dynamic> challenge) async {
    if (challenge['isRegistrationClosed'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('مهلت ثبت‌نام این چالش به اتمام رسیده است'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    _isLoadingInProgress = true;
    if (mounted) setState(() => _isLoading = true);

    try {
      final currentUser = await _supabase.getCurrentUser();
      if (currentUser != null) {
        // ✅ 1. ثبت در دیتابیس
        await _supabase.joinChallenge(currentUser.id, challenge['id']);

        // ✅ 2. به‌روزرسانی فوری لیست محلی
        final newChallenge = Map<String, dynamic>.from(challenge);
        newChallenge['isJoined'] = true;
        newChallenge['isCompleted'] = false;
        newChallenge['status'] = 'active';
        newChallenge['is_active'] = true;

        setState(() {
          _myChallenges.add(newChallenge);
          _challenges.removeWhere((c) => c['id'] == challenge['id']);
          _challenges.add(newChallenge);
        });

        // ✅ 3. ریفرش SyncProvider و LocalStorage
        final syncProvider = Provider.of<SyncProvider>(context, listen: false);

        // ریفرش کامل داده‌ها از دیتابیس
        await syncProvider.manualSync();

        // ریفرش پروفایل
        if (widget.refreshNotifier != null) {
          widget.refreshNotifier!.value++;
        }

        // ✅ 4. ریفرش کامل صفحه
        _isInitialized = false;
        _isLoadingInProgress = false;
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'به چالش پیوستید! عادت‌های چالش به لیست شما اضافه شد 🎉',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // lib/features/explore/screens/explore_screen.dart

  Future<void> _leaveChallenge(Map<String, dynamic> challenge) async {
    _isLoadingInProgress = true;
    if (mounted) setState(() => _isLoading = true);

    try {
      final currentUser = await _supabase.getCurrentUser();
      if (currentUser != null) {
        // ✅ 1. حذف کامل از دیتابیس
        await _supabase.leaveChallenge(currentUser.id, challenge['id']);

        // ✅ 2. حذف از لیست محلی (فوری)
        setState(() {
          _myChallenges.removeWhere((c) => c['id'] == challenge['id']);
          _challenges.removeWhere((c) => c['id'] == challenge['id']);

          // ✅ چالش رو با isJoined = false دوباره به لیست اضافه کن
          final updatedChallenge = Map<String, dynamic>.from(challenge);
          updatedChallenge['isJoined'] = false;
          updatedChallenge['isCompleted'] = false;
          updatedChallenge['status'] = null;
          updatedChallenge['is_active'] = false;
          _challenges.add(updatedChallenge);
        });

        // ✅ 3. به‌روزرسانی کش
        _challengeDetailsCache.remove(challenge['id']);

        // ✅ 4. ریفرش داده‌های SyncProvider
        if (mounted) {
          final syncProvider = Provider.of<SyncProvider>(
            context,
            listen: false,
          );
          // حذف عادت‌های چالش از کش
          syncProvider.removeHabitsByChallengeId(challenge['id']);
          // حذف از userChallenges
          syncProvider.removeUserChallenge(challenge['id']);
        }

        // ✅ 5. ریفرش کامل
        _isInitialized = false;
        _isLoadingInProgress = false;
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('از چالش "${challenge['title']}" انصراف دادید'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==================== متدهای ماموریت ====================
  Future<void> _startQuest(Quest quest) async {
    if (!mounted) return;

    _isLoadingInProgress = true;
    if (mounted) setState(() => _isLoading = true);

    try {
      final currentUser = await _supabase.getCurrentUser();
      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لطفاً وارد حساب کاربری خود شوید'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      await _supabase.startQuest(currentUser.id, quest);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ماموریت "${quest.title}" شروع شد! 🎉'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        _isInitialized = false;
        _isLoadingInProgress = false;
        await _loadData();
      }
    } catch (e) {
      print('❌ Error in _startQuest: $e');
      if (mounted) {
        String message = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelQuest(Quest quest) async {
    _isLoadingInProgress = true;
    if (mounted) setState(() => _isLoading = true);

    try {
      final currentUser = await _supabase.getCurrentUser();
      if (currentUser != null) {
        await _supabase.cancelQuest(currentUser.id, quest.id);
        _isInitialized = false;
        _isLoadingInProgress = false;
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('از ماموریت "${quest.title}" انصراف دادید'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==================== Widgetهای اصلی ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('اکسپلور'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A2E),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              forceRefresh();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            )
          : _errorMessage.isNotEmpty
          ? _buildErrorState()
          : _buildMainContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            'خطا در بارگذاری داده‌ها',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(_errorMessage, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              _isInitialized = false;
              _isLoadingInProgress = false;
              _loadData();
            },
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

  Widget _buildMainContent() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: const Color(0xFF2563EB),
            indicatorWeight: 3,
            labelColor: const Color(0xFF2563EB),
            unselectedLabelColor: Colors.grey.shade500,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(text: 'چالش‌ها'),
              Tab(text: 'بسته‌ها'),
              Tab(text: 'ماموریت‌ها'),
              Tab(text: 'افتخارات'),
              Tab(text: 'بازارچه'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              ChallengesTab(
                challenges: _challenges,
                myChallenges: _myChallenges,
                currentUserId: _currentUserId,
                onRefresh: _loadData,
                joinChallenge: _joinChallenge,
                leaveChallenge: _leaveChallenge,
                showChallengeDetails: _showChallengeDetailsDialog,
              ),
              PackagesTab(
                packages: _templatePackages,
                currentUserId: _currentUserId,
                onRefresh: _loadData,
              ),
              QuestsTab(
                quests: _quests,
                completedQuests: _completedQuests,
                currentUserId: _currentUserId,
                onRefresh: _loadData,
                showQuestDetail: _showQuestDetailDialog,
              ),
              const LeaderboardTab(),
              const CosmeticsTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== متدهای کمکی ====================

  Color _parseColor(String colorStr) {
    try {
      if (colorStr.startsWith('#')) {
        return Color(int.parse('FF${colorStr.substring(1)}', radix: 16));
      }
      return const Color(0xFF2563EB);
    } catch (e) {
      return const Color(0xFF2563EB);
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'fitness_center':
        return Icons.fitness_center;
      case 'psychology':
        return Icons.psychology;
      case 'attach_money':
        return Icons.attach_money;
      case 'favorite':
        return Icons.favorite;
      case 'forest':
        return Icons.forest;
      case 'whatshot':
        return Icons.whatshot;
      case 'emoji_events':
        return Icons.emoji_events;
      case 'diamond':
        return Icons.diamond;
      case 'beach_access':
        return Icons.beach_access;
      case 'flare':
        return Icons.flare;
      case 'star':
        return Icons.star;
      default:
        return Icons.stars;
    }
  }

  // ✅ متد کامل نمایش جزئیات چالش
  void _showChallengeDetailsDialog(Map<String, dynamic> challenge) async {
    try {
      final challengeId = challenge['id'];

      // ✅ ابتدا از کش استفاده کن
      if (_challengeDetailsCache.containsKey(challengeId)) {
        final cached = _challengeDetailsCache[challengeId]!;
        if (DateTime.now().difference(cached.timestamp) <
            const Duration(seconds: 10)) {
          _showChallengeDetailsDialogWithData(challenge, cached.data);
          return;
        }
      }

      // ✅ دریافت داده‌ها با timeout
      final results = await Future.wait([
        _supabase
            .getRealParticipantsCount(challengeId)
            .timeout(const Duration(seconds: 2), onTimeout: () => 0),
        _supabase
            .getUserChallengeProgressDetails(_currentUserId, challengeId)
            .timeout(
              const Duration(seconds: 2),
              onTimeout: () => {'completedDays': 0, 'totalDays': 0},
            ),
      ]);

      final realParticipants = results[0];
      final progressData = results[1];

      final cacheData = {
        'participants': realParticipants,
        'progress': progressData,
      };

      // ✅ ذخیره در کش
      _challengeDetailsCache[challengeId] = _CachedChallengeDetails(
        data: cacheData,
        timestamp: DateTime.now(),
      );

      // ✅ محدود کردن سایز کش
      if (_challengeDetailsCache.length > 20) {
        final keys = _challengeDetailsCache.keys.toList();
        _challengeDetailsCache.remove(keys.first);
      }

      _showChallengeDetailsDialogWithData(challenge, cacheData);
    } catch (e) {
      print('❌ Error showing challenge details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در نمایش جزئیات چالش: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // lib/features/explore/screens/explore_screen.dart

  // ✅ متد کامل نمایش دیالوگ جزئیات چالش با داده‌های آماده
  void _showChallengeDetailsDialogWithData(
    Map<String, dynamic> challenge,
    Map<String, dynamic> data,
  ) {
    try {
      final realParticipants = data['participants'] as int? ?? 0;
      final progressData =
          data['progress'] as Map<String, int>? ??
          {'completedDays': 0, 'totalDays': 0};

      final fixedColor = const Color(0xFF2563EB);
      final isJoined = _myChallenges.any((c) => c['id'] == challenge['id']);
      final isRegistrationClosed = challenge['isRegistrationClosed'] ?? false;

      final duration = challenge['challenge_duration'] as int? ?? 7;

      DateTime startDate;
      try {
        startDate = DateTime.parse(
          challenge['registration_start_date'] ??
              challenge['created_at'] ??
              DateTime.now().toIso8601String(),
        );
      } catch (e) {
        startDate = DateTime.now();
      }

      DateTime endDate;
      try {
        endDate = DateTime.parse(
          challenge['registration_end_date'] ??
              challenge['created_at'] ??
              DateTime.now().toIso8601String(),
        );
      } catch (e) {
        endDate = DateTime.now().add(Duration(days: duration));
      }

      // ✅ بررسی وضعیت چالش
      bool isCompleted = false;
      bool isFailed = false;

      if (isJoined) {
        final userChallenge = _myChallenges.firstWhere(
          (c) => c['id'] == challenge['id'],
          orElse: () => {},
        );
        if (userChallenge.isNotEmpty) {
          isCompleted = userChallenge['is_completed'] == true;
          isFailed = userChallenge['status'] == 'failed';
        }
      }

      // ✅ وضعیت چالش
      final bool isActive = isJoined && !isCompleted && !isFailed;
      final bool isNew = !isJoined && !isRegistrationClosed;
      final bool isExpired = isRegistrationClosed && !isJoined;

      // ✅ داده‌های پیشرفت
      final completedDays = progressData['completedDays'] ?? 0;
      final totalDays = progressData['totalDays'] ?? duration;
      final double progress = totalDays > 0 ? completedDays / totalDays : 0.0;

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) {
          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ✅ نشانگر کشیدن
                    Center(
                      child: Container(
                        width: 60,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ==================== هدر چالش ====================
                            Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: isCompleted
                                        ? Colors.green.withValues(alpha: 0.15)
                                        : isFailed
                                        ? Colors.red.withValues(alpha: 0.15)
                                        : isActive
                                        ? fixedColor.withValues(alpha: 0.15)
                                        : isExpired
                                        ? Colors.grey.withValues(alpha: 0.15)
                                        : Colors.orange.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    isCompleted
                                        ? Icons.emoji_events
                                        : isFailed
                                        ? Icons.cancel
                                        : challenge['is_boss'] == true
                                        ? Icons.emoji_events
                                        : isExpired
                                        ? Icons.lock_outline
                                        : Icons.flag,
                                    color: isCompleted
                                        ? Colors.green
                                        : isFailed
                                        ? Colors.red
                                        : isExpired
                                        ? Colors.grey.shade600
                                        : isActive
                                        ? fixedColor
                                        : Colors.orange,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        challenge['title'] ?? 'چالش',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: isCompleted
                                              ? Colors.green
                                              : isFailed
                                              ? Colors.red
                                              : isExpired
                                              ? Colors.grey.shade600
                                              : const Color(0xFF1A1A2E),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        challenge['description'] ?? '',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isCompleted
                                              ? Colors.green.shade700
                                              : isFailed
                                              ? Colors.red.shade700
                                              : isExpired
                                              ? Colors.grey.shade500
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // ✅ برچسب وضعیت
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCompleted
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : isFailed
                                        ? Colors.red.withValues(alpha: 0.1)
                                        : isExpired
                                        ? Colors.grey.withValues(alpha: 0.1)
                                        : isActive
                                        ? fixedColor.withValues(alpha: 0.1)
                                        : Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isCompleted
                                        ? '✅ کامل شده'
                                        : isFailed
                                        ? '❌ ناموفق'
                                        : isExpired
                                        ? '⛔ پایان ثبت‌نام'
                                        : isActive
                                        ? '⚡ در حال انجام'
                                        : '🔥 جدید',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isCompleted
                                          ? Colors.green
                                          : isFailed
                                          ? Colors.red
                                          : isExpired
                                          ? Colors.grey.shade600
                                          : isActive
                                          ? fixedColor
                                          : Colors.orange,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // ==================== وضعیت چالش ====================
                            if (isJoined) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isCompleted
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : isFailed
                                      ? Colors.red.withValues(alpha: 0.1)
                                      : Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCompleted
                                        ? Colors.green
                                        : isFailed
                                        ? Colors.red
                                        : fixedColor,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isCompleted
                                          ? Icons.check_circle
                                          : isFailed
                                          ? Icons.cancel
                                          : Icons.timer,
                                      color: isCompleted
                                          ? Colors.green
                                          : isFailed
                                          ? Colors.red
                                          : fixedColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        isCompleted
                                            ? '✅ چالش با موفقیت کامل شد!'
                                            : isFailed
                                            ? '⛔ چالش ناموفق بود'
                                            : '⏳ در حال انجام...',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isCompleted
                                              ? Colors.green
                                              : isFailed
                                              ? Colors.red
                                              : fixedColor,
                                        ),
                                      ),
                                    ),
                                    if (isActive)
                                      Text(
                                        '${(progress * 100).toInt()}%',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: fixedColor,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 16),

                            // ==================== اطلاعات چالش ====================
                            _buildDetailRowFixed(
                              Icons.timer,
                              'مدت زمان چالش',
                              '$duration روز',
                              isExpired ? Colors.grey.shade600 : fixedColor,
                            ),
                            const SizedBox(height: 12),

                            _buildDetailRowFixed(
                              Icons.people,
                              'شرکت‌کنندگان',
                              '$realParticipants نفر',
                              isExpired ? Colors.grey.shade600 : fixedColor,
                            ),
                            const SizedBox(height: 12),

                            _buildDetailRowFixed(
                              Icons.stars,
                              'پاداش نهایی',
                              '+${challenge['xp_reward'] ?? 0} XP',
                              isCompleted
                                  ? Colors.green
                                  : isFailed
                                  ? Colors.red
                                  : isExpired
                                  ? Colors.grey.shade600
                                  : fixedColor,
                            ),
                            const SizedBox(height: 12),

                            _buildDetailRowFixed(
                              Icons.calendar_today,
                              'تاریخ شروع',
                              _formatDate(startDate),
                              isExpired ? Colors.grey.shade600 : fixedColor,
                            ),
                            const SizedBox(height: 12),

                            _buildDetailRowFixed(
                              Icons.event,
                              'تاریخ پایان',
                              _formatDate(endDate),
                              isExpired ? Colors.grey.shade600 : fixedColor,
                            ),
                            const SizedBox(height: 12),

                            // ==================== نوار پیشرفت (فقط برای چالش‌های فعال) ====================
                            if (isActive) ...[
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'پیشرفت شما',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1A1A2E),
                                        ),
                                      ),
                                      Text(
                                        '$completedDays از $totalDays روز',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: fixedColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor: Colors.grey.shade200,
                                      color: fixedColor,
                                      minHeight: 10,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${(progress * 100).toInt()}% تکمیل شده',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (completedDays < totalDays) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.orange.withValues(
                                            alpha: 0.2,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.lightbulb,
                                            size: 16,
                                            color: Colors.orange,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${totalDays - completedDays} روز دیگر تا تکمیل چالش',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.orange.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],

                            // ==================== چالش کامل شده ====================
                            if (isCompleted) ...[
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green.shade50,
                                      Colors.green.shade100,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.green,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.emoji_events,
                                      color: Colors.green,
                                      size: 40,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '🎉 چالش کامل شد!',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'شما این چالش را با موفقیت به پایان رساندید',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.green.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // ==================== چالش ناموفق ====================
                            if (isFailed) ...[
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.red.shade50,
                                      Colors.red.shade100,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.red,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.cancel,
                                      color: Colors.red,
                                      size: 40,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '⛔ چالش ناموفق بود',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'شما ${completedDays} روز از $totalDays روز را انجام دادید',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.red.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),

                            // ==================== دکمه‌های اقدام ====================
                            if (isCompleted) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.green,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.emoji_events,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      '✅ چالش کامل شد!',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (isFailed) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.red,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.cancel,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      '⛔ چالش ناموفق بود',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (isActive) ...[
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _leaveChallenge(challenge);
                                  },
                                  icon: const Icon(Icons.exit_to_app, size: 20),
                                  label: const Text(
                                    'انصراف از چالش',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                            ] else if (isExpired) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.lock_outline,
                                      color: Colors.grey.shade600,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '⛔ مهلت ثبت‌نام به اتمام رسید',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _joinChallenge(challenge);
                                  },
                                  icon: const Icon(
                                    Icons.play_arrow,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    'شرکت در چالش',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: fixedColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      print('❌ Error showing challenge details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در نمایش جزئیات چالش: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ متد کامل نمایش جزئیات ماموریت با تفکیک وضعیت‌ها
  void _showQuestDetailDialog(Quest quest) async {
    try {
      final color = _parseColor(quest.color);

      // ✅ دریافت وضعیت ماموریت برای کاربر
      final userQuests = await _supabase.getUserQuests(_currentUserId);

      // ✅ جستجوی دقیق برای ماموریت
      final userQuest = userQuests.firstWhere(
        (uq) => uq.questId == quest.id,
        orElse: () => UserQuest(
          id: '',
          userId: _currentUserId,
          questId: quest.id,
          progress: 0,
          isCompleted: false,
          isActive: false, // ✅ مهم: برای ماموریت‌های جدید false است
          startedAt: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      );

      // ✅ تشخیص دقیق وضعیت ماموریت
      final bool hasStarted =
          userQuest.isActive == true && userQuest.isCompleted == false;
      final bool isCompleted = userQuest.isCompleted == true;
      final bool isNew = !hasStarted && !isCompleted;

      final int progress = userQuest.progress;
      final int targetCount = quest.targetCount;
      final double progressPercent = targetCount > 0
          ? (progress / targetCount).clamp(0.0, 1.0)
          : 0.0;

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) {
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ✅ نشانگر کشیدن
                    Center(
                      child: Container(
                        width: 60,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ==================== هدر ماموریت ====================
                            Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: isCompleted
                                        ? Colors.green.withValues(alpha: 0.2)
                                        : hasStarted
                                        ? color.withValues(alpha: 0.2)
                                        : Colors.grey.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    isCompleted
                                        ? Icons.emoji_events
                                        : hasStarted
                                        ? _getIconData(quest.icon)
                                        : Icons.flag_outlined,
                                    color: isCompleted
                                        ? Colors.green
                                        : hasStarted
                                        ? color
                                        : Colors.grey.shade500,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        quest.title,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: isCompleted
                                              ? Colors.green.shade700
                                              : hasStarted
                                              ? const Color(0xFF1A1A2E)
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        quest.badge,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isCompleted
                                              ? Colors.green.shade600
                                              : hasStarted
                                              ? Colors.grey.shade700
                                              : Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCompleted
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : hasStarted
                                        ? const Color(
                                            0xFFFFA500,
                                          ).withValues(alpha: 0.1)
                                        : Colors.grey.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isCompleted
                                            ? Icons.check_circle
                                            : Icons.stars,
                                        size: 14,
                                        color: isCompleted
                                            ? Colors.green
                                            : hasStarted
                                            ? const Color(0xFFFFA500)
                                            : Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isCompleted
                                            ? 'انجام شده'
                                            : hasStarted
                                            ? '+${quest.xpReward} XP'
                                            : 'شروع نشده',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isCompleted
                                              ? Colors.green
                                              : hasStarted
                                              ? const Color(0xFFFFA500)
                                              : Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // ==================== وضعیت ماموریت (با رنگ‌های متفاوت) ====================
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : hasStarted
                                    ? color.withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isCompleted
                                      ? Colors.green
                                      : hasStarted
                                      ? color
                                      : Colors.grey.shade300,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isCompleted
                                        ? Icons.check_circle
                                        : hasStarted
                                        ? Icons.timer
                                        : Icons.flag_outlined,
                                    color: isCompleted
                                        ? Colors.green
                                        : hasStarted
                                        ? color
                                        : Colors.grey.shade500,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      isCompleted
                                          ? '✅ ماموریت با موفقیت کامل شد!'
                                          : hasStarted
                                          ? '⏳ در حال انجام...'
                                          : '📌 ماموریت جدید - آماده شروع',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isCompleted
                                            ? Colors.green
                                            : hasStarted
                                            ? color
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                  if (hasStarted)
                                    Text(
                                      '$progress/$targetCount',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 16),

                            // ==================== توضیحات ====================
                            Text(
                              quest.description,
                              style: TextStyle(
                                fontSize: 14,
                                color: isCompleted
                                    ? Colors.green.shade700
                                    : hasStarted
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade600,
                                height: 1.5,
                              ),
                            ),

                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 16),

                            // ==================== اطلاعات ماموریت ====================
                            Row(
                              children: [
                                Expanded(
                                  child: _buildQuestInfoItem(
                                    icon: Icons.timer,
                                    label: 'مدت زمان',
                                    value: '${quest.targetCount} روز',
                                    isActive: hasStarted || isCompleted,
                                  ),
                                ),
                                Expanded(
                                  child: _buildQuestInfoItem(
                                    icon: Icons.emoji_events,
                                    label: 'نشان',
                                    value: quest.badge,
                                    isActive: hasStarted || isCompleted,
                                  ),
                                ),
                                Expanded(
                                  child: _buildQuestInfoItem(
                                    icon: Icons.stars,
                                    label: 'پاداش',
                                    value: '+${quest.xpReward} XP',
                                    isActive: hasStarted || isCompleted,
                                  ),
                                ),
                              ],
                            ),

                            // ==================== نوار پیشرفت (فقط در صورت شروع) ====================
                            if (hasStarted && !isCompleted) ...[
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'پیشرفت شما',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1A1A2E),
                                        ),
                                      ),
                                      Text(
                                        '$progress از $targetCount روز',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: progressPercent,
                                      backgroundColor: Colors.grey.shade200,
                                      color: color,
                                      minHeight: 10,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${(progressPercent * 100).toInt()}% تکمیل شده',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (progress < targetCount) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.orange.withValues(
                                            alpha: 0.2,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.lightbulb,
                                            size: 16,
                                            color: Colors.orange,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${targetCount - progress} روز دیگر تا تکمیل ماموریت',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.orange.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],

                            // ==================== ماموریت کامل شده ====================
                            if (isCompleted) ...[
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green.shade50,
                                      Colors.green.shade100,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.green,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.emoji_events,
                                      color: Colors.green,
                                      size: 40,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '🎉 ماموریت کامل شد!',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'شما این ماموریت را با موفقیت به پایان رساندید',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.green.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '🏅 ${quest.badge}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // ==================== ماموریت جدید ====================
                            if (isNew) ...[
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.shade50,
                                      Colors.blue.shade100,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.blue.shade300,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.flag,
                                      color: Colors.blue,
                                      size: 40,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '🚀 آماده شروع!',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'این ماموریت ${quest.targetCount} روزه را شروع کنید',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.blue.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.stars,
                                            size: 16,
                                            color: Colors.blue,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '+${quest.xpReward} XP',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),

                            // ==================== دکمه‌های اقدام (متفاوت برای هر وضعیت) ====================
                            if (isCompleted) ...[
                              // ✅ دکمه برای ماموریت کامل شده
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.green,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      '✅ ماموریت کامل شد!',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (hasStarted) ...[
                              // ✅ دکمه انصراف برای ماموریت در حال انجام
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        title: const Text('انصراف از ماموریت'),
                                        content: Text(
                                          'آیا از انصراف از ماموریت "${quest.title}" مطمئن هستید؟\n\nبا انصراف، تمام پیشرفت شما از دست خواهد رفت.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('انصراف'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text(
                                              'بله، انصراف',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      if (mounted) Navigator.pop(context);
                                      await _cancelQuest(quest);
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    'انصراف از ماموریت',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ] else ...[
                              // ✅ دکمه شروع برای ماموریت جدید
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await _startQuest(quest);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: color,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    'شروع ماموریت 🚀',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      print('❌ Error showing quest details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در نمایش جزئیات ماموریت: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== ویجت کمکی برای اطلاعات ماموریت (با پارامتر isActive) ====================

  Widget _buildQuestInfoItem({
    required IconData icon,
    required String label,
    required String value,
    bool isActive = true,
  }) {
    final Color textColor = isActive
        ? const Color(0xFF1A1A2E)
        : Colors.grey.shade500;
    final Color bgColor = isActive ? Colors.grey.shade50 : Colors.grey.shade100;
    final Color borderColor = isActive
        ? Colors.grey.shade200
        : Colors.grey.shade300;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: isActive ? Colors.grey.shade600 : Colors.grey.shade400,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isActive ? Colors.grey.shade500 : Colors.grey.shade400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ==================== ویجت کمکی برای نمایش جزئیات ====================

  // ✅ متدهای کمکی که در این متد استفاده شده‌اند
  Widget _buildDetailRowFixed(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year/$month/$day';
  }
}

class _CachedChallengeDetails {
  final Map<String, dynamic> data;
  final DateTime timestamp;

  _CachedChallengeDetails({required this.data, required this.timestamp});
}
