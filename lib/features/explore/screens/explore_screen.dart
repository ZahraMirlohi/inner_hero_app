// lib/features/explore/screens/explore_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/services/supabase_service.dart';
import '../models/package_model.dart';
import '../models/quest_model.dart';
import '../models/user_quest_model.dart';
import 'challenges_tab.dart';
import 'packages_tab.dart';
import 'quests_tab.dart';
import 'cosmetics_tab.dart';
import 'leaderboard_tab.dart';
import '/providers/sync_provider.dart';
import '/providers/theme_provider.dart';
import '/core/app_palette.dart';
import '../widgets/card_image.dart';
import '/services/local_storage_service.dart';
import 'dart:async';
import 'dart:ui';

class ExploreScreen extends StatefulWidget {
  final ValueNotifier<int>? refreshNotifier;

  const ExploreScreen({super.key, this.refreshNotifier});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _indicatorAnimationController;

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

  final List<Map<String, dynamic>> _tabs = [
    {'icon': Icons.flag_rounded, 'label': 'چالش‌ها'},
    {'icon': Icons.inventory_2_rounded, 'label': 'بسته‌ها'},
    {'icon': Icons.stars_rounded, 'label': 'ماموریت‌ها'},
    {'icon': Icons.emoji_events_rounded, 'label': 'افتخارات'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _indicatorAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
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
    _indicatorAnimationController.dispose();
    super.dispose();
  }

  void _onRefreshTriggered() {
    print('Refresh triggered from notifier');
    _challengeDetailsCache.clear();
    _isInitialized = false;
    _isLoadingInProgress = false;
    _loadData();
  }

  void forceRefresh() {
    print('Force refresh called');
    _challengeDetailsCache.clear();
    _isInitialized = false;
    _isLoadingInProgress = false;
    _loadData();
  }

  Future<void> _loadData() async {
    if (_isInitialized || _isLoadingInProgress) return;
    if (!mounted) return;

    print('_loadData: Starting...');
    _isLoadingInProgress = true;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);
      final currentUser = await _supabase.getCurrentUser();

      if (_currentUserId.isNotEmpty) {
        await _supabase.checkAndUpdateUserChallenges(_currentUserId);
      }

      if (currentUser == null) {
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

      bool hasLocalData = false;

      if (syncProvider.hasChallenges) {
        _challenges = syncProvider.challenges;
        _myChallenges = syncProvider.userChallenges;
        hasLocalData = true;
      }

      if (syncProvider.packages.isNotEmpty) {
        _templatePackages = syncProvider.packages;
        hasLocalData = true;
      }

      if (syncProvider.quests.isNotEmpty) {
        _quests = syncProvider.quests;
        hasLocalData = true;
      }

      if (_currentUserId.isNotEmpty) {
        await _supabase.checkUserChallengeStreak(_currentUserId);
      }

      if (syncProvider.isOnline) {
        await _loadFromSupabase(syncProvider);
      } else if (!hasLocalData) {
        setState(() {
          _errorMessage = 'برای بارگذاری اطلاعات به اتصال اینترنت نیاز دارید';
          _isLoading = false;
          _isInitialized = true;
          _isLoadingInProgress = false;
        });
        return;
      }

      _processChallenges();
      _processCompletedQuests();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialized = true;
          _isLoadingInProgress = false;
        });
      }
    } catch (e) {
      print('_loadData: Error - $e');
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

      final completedQuestIds = userQuests
          .where((uq) => uq.isCompleted == true)
          .map((uq) => uq.questId)
          .toList();

      _completedQuests =
          _quests.where((q) => completedQuestIds.contains(q.id)).toList();
    } catch (e) {
      print('Background sync error: $e');
    }
  }

  void _processChallenges() {
    for (int i = 0; i < _challenges.length; i++) {
      final challenge = _challenges[i];
      final challengeId = challenge['id'];

      _challenges[i]['isRegistrationClosed'] = false;
      _challenges[i]['daysLeft'] = 999;

      final isJoined = _myChallenges.any((c) => c['id'] == challengeId);
      _challenges[i]['isJoined'] = isJoined;

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

  void _processCompletedQuests() {}

  Future<void> _joinChallenge(Map<String, dynamic> challenge) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('در حال ثبت‌نام در چالش...'),
            ],
          ),
          backgroundColor: Color(0xFF4A90E2),
          duration: Duration(seconds: 1),
        ),
      );
    }

    _isLoadingInProgress = true;
    if (mounted) setState(() => _isLoading = true);

    try {
      final currentUser = await _supabase.getCurrentUser();
      if (currentUser != null) {
        await _supabase.joinChallenge(currentUser.id, challenge['id']);

        final newChallenge = Map<String, dynamic>.from(challenge);
        newChallenge['isJoined'] = true;
        newChallenge['isCompleted'] = false;
        newChallenge['status'] = 'active';
        newChallenge['is_active'] = true;

        if (mounted) {
          setState(() {
            _myChallenges.add(newChallenge);
            _challenges.removeWhere((c) => c['id'] == challenge['id']);
            _challenges.add(newChallenge);
          });
        }

        final syncProvider = Provider.of<SyncProvider>(context, listen: false);
        unawaited(syncProvider.manualSync());

        if (widget.refreshNotifier != null) {
          widget.refreshNotifier!.value++;
        }

        _isInitialized = false;
        _isLoadingInProgress = false;
        unawaited(_loadData());

        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('به چالش پیوستید! '),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
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

  Future<void> _leaveChallenge(Map<String, dynamic> challenge) async {
    _isLoadingInProgress = true;
    if (mounted) setState(() => _isLoading = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('در حال انصراف از چالش...'),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );
    }

    try {
      final currentUser = await _supabase.getCurrentUser();
      if (currentUser != null) {
        await _supabase.leaveChallenge(currentUser.id, challenge['id']);

        if (mounted) {
          setState(() {
            _myChallenges.removeWhere((c) => c['id'] == challenge['id']);
            _challenges.removeWhere((c) => c['id'] == challenge['id']);

            final updatedChallenge = Map<String, dynamic>.from(challenge);
            updatedChallenge['isJoined'] = false;
            updatedChallenge['isCompleted'] = false;
            updatedChallenge['status'] = null;
            updatedChallenge['is_active'] = false;
            _challenges.add(updatedChallenge);
          });
        }

        _challengeDetailsCache.remove(challenge['id']);

        if (mounted) {
          final syncProvider =
              Provider.of<SyncProvider>(context, listen: false);
          syncProvider.removeHabitsByChallengeId(challenge['id']);
          syncProvider.removeUserChallenge(challenge['id']);
          unawaited(syncProvider.manualSync());
        }

        _isInitialized = false;
        _isLoadingInProgress = false;
        unawaited(_loadData());

        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
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
        ScaffoldMessenger.of(context).clearSnackBars();
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

      try {
        final syncProvider = Provider.of<SyncProvider>(context, listen: false);
        await syncProvider.manualSync();
      } catch (e) {
        try {
          final habits = await _supabase.getHabits(currentUser.id);
          final localStorage = LocalStorageService();
          await localStorage.saveHabits(habits);
        } catch (e2) {
          print('Error updating LocalStorage: $e2');
        }
      }

      _isInitialized = false;
      _isLoadingInProgress = false;
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ماموریت "${quest.title}" شروع شد! '),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error in _startQuest: $e');
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

        try {
          final localStorage = LocalStorageService();
          final habits = localStorage.getHabits();
          final updatedHabits =
              habits.where((h) => h.questId != quest.id).toList();
          await localStorage.saveHabits(updatedHabits);
        } catch (e) {
          print('Error updating LocalStorage: $e');
        }

        _isInitialized = false;
        _isLoadingInProgress = false;
        await _loadData();

        if (widget.refreshNotifier != null) {
          widget.refreshNotifier!.value++;
        }

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

  // ═══════════════════════════════════════════════════════════
  // دیالوگ جزئیات چالش
  // ═══════════════════════════════════════════════════════════
  void _showChallengeDetailsDialog(Map<String, dynamic> challenge) async {
    try {
      final challengeId = challenge['id'];

      if (_challengeDetailsCache.containsKey(challengeId)) {
        final cached = _challengeDetailsCache[challengeId]!;
        if (DateTime.now().difference(cached.timestamp) <
            const Duration(seconds: 10)) {
          _showChallengeDetailsDialogWithData(challenge, cached.data);
          return;
        }
      }

      final results = await Future.wait([
        _supabase
            .getRealParticipantsCount(challengeId)
            .timeout(const Duration(seconds: 8), onTimeout: () => 0),
        _supabase
            .getUserChallengeProgressDetails(_currentUserId, challengeId)
            .timeout(
              const Duration(seconds: 8),
              onTimeout: () => {'completedDays': 0, 'totalDays': 0},
            ),
      ]);

      final realParticipants = results[0];
      final progressData = results[1];

      final cacheData = {
        'participants': realParticipants,
        'progress': progressData,
      };

      _challengeDetailsCache[challengeId] = _CachedChallengeDetails(
        data: cacheData,
        timestamp: DateTime.now(),
      );

      if (_challengeDetailsCache.length > 20) {
        final keys = _challengeDetailsCache.keys.toList();
        _challengeDetailsCache.remove(keys.first);
      }

      _showChallengeDetailsDialogWithData(challenge, cacheData);
    } catch (e) {
      print('Error showing challenge details: $e');
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

  void _showChallengeDetailsDialogWithData(
    Map<String, dynamic> challenge,
    Map<String, dynamic> data,
  ) {
    try {
      final theme = Provider.of<ThemeProvider>(context, listen: false);
      final Color primaryColor = theme.primaryColor;

      final realParticipants = data['participants'] as int? ?? 0;
      final progressData = data['progress'] as Map<String, int>? ??
          {'completedDays': 0, 'totalDays': 0};

      final isJoined = _myChallenges.any((c) => c['id'] == challenge['id']);
      final isRegistrationClosed = challenge['isRegistrationClosed'] ?? false;

      final duration = challenge['challenge_duration'] as int? ?? 7;

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

      final bool isActive = isJoined && !isCompleted && !isFailed;
      final bool isNew = !isJoined && !isRegistrationClosed;
      final bool isExpired = isRegistrationClosed && !isJoined;

      final completedDays = progressData['completedDays'] ?? 0;
      final totalDays = progressData['totalDays'] ?? duration;
      final double progress = totalDays > 0 ? completedDays / totalDays : 0.0;

      if (!mounted) return;

      final String? img = challenge['image_url'] as String?;
      final int xp = challenge['xp_reward'] as int? ?? 0;
      final status = isCompleted
          ? 'کامل شده'
          : isFailed
              ? 'ناموفق'
              : isExpired
                  ? 'پایان ثبت‌نام'
                  : isActive
                      ? 'در حال انجام'
                      : 'چالش جدید';
      final remaining = totalDays - completedDays;

      Widget banner;
      if (isActive) {
        banner = _sheetProgress(theme, completedDays, totalDays, progress,
            remaining > 0 ? '$remaining روز دیگر تا تکمیل چالش' : null);
      } else if (isCompleted) {
        banner = _sheetBanner(theme.tone(Tone.mint).bg, 'چالش کامل شد!',
            'شما این چالش را با موفقیت به پایان رساندید');
      } else if (isFailed) {
        banner = _sheetBanner(theme.tone(Tone.rose).bg, 'چالش ناموفق بود',
            'شما $completedDays روز از $totalDays روز را انجام دادید');
      } else if (isExpired) {
        banner = _sheetBanner(const Color(0xFFE3E6D8), 'مهلت ثبت‌نام تمام شد',
            'این چالش دیگر قابل شرکت نیست');
      } else {
        banner = _sheetBanner(theme.tone(Tone.butter).bg, 'آماده شروع!',
            'این چالش $duration روزه را شروع کنید');
      }

      _showDetailSheet(
        theme: theme,
        icon: Icons.flag_rounded,
        title: challenge['title'] ?? 'چالش',
        status: status,
        description: challenge['description']?.toString() ?? '',
        imageUrl: img,
        tiles: [
          _SheetTile(Icons.calendar_today_rounded, 'مدت زمان', '$duration روز',
              Tone.sky),
          _SheetTile(Icons.people_alt_rounded, 'شرکت‌کنندگان',
              '$realParticipants نفر', Tone.butter),
          _SheetTile(Icons.star_rounded, 'پاداش', '+$xp XP', Tone.peach),
        ],
        banner: banner,
        actionLabel: isActive
            ? 'انصراف از چالش'
            : (isCompleted || isFailed)
                ? 'بستن'
                : isExpired
                    ? 'پایان ثبت‌نام'
                    : 'شرکت در چالش',
        actionKind: isActive
            ? _SheetAction.danger
            : isExpired
                ? _SheetAction.disabled
                : (isCompleted || isFailed)
                    ? _SheetAction.neutral
                    : _SheetAction.primary,
        onAction: () {
          if (isActive) {
            _leaveChallenge(challenge);
          } else if (isNew) {
            _joinChallenge(challenge);
          }
        },
      );
    } catch (e) {
      print('Error showing challenge details: $e');
    }
  }

  // ═══════════ شیت جزئیات مشترک (چالش و ماموریت) ═══════════
  Widget _sheetBanner(Color bg, String title, String sub) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(28)),
        child: Column(
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF090909))),
            const SizedBox(height: 4),
            Text(sub,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF3C4034))),
          ],
        ),
      );

  Widget _sheetProgress(ThemeProvider theme, int done, int total,
      double ratio, String? remainingText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: theme.tone(Tone.sky).bg,
          borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('پیشرفت شما',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF090909))),
              Text('$done از $total روز',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF090909))),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.7),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF090909)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
              '${(ratio * 100).toInt()}٪ تکمیل شده${remainingText != null ? ' - $remainingText' : ''}',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3C4034))),
        ],
      ),
    );
  }

  void _showDetailSheet({
    required ThemeProvider theme,
    required IconData icon,
    required String title,
    required String status,
    required String description,
    required List<_SheetTile> tiles,
    required Widget banner,
    required String actionLabel,
    required _SheetAction actionKind,
    required FutureOr<void> Function() onAction,
    String? imageUrl,
  }) {
    if (!mounted) return;
    const ink = Color(0xFF090909);
    final Color btnBg = actionKind == _SheetAction.primary
        ? ink
        : actionKind == _SheetAction.danger
            ? const Color(0xFFFFD3CF)
            : actionKind == _SheetAction.neutral
                ? ink
                : const Color(0xFFCFD3C4);
    final Color btnFg = actionKind == _SheetAction.primary
        ? theme.effectivePrimary
        : actionKind == _SheetAction.danger
            ? ink
            : actionKind == _SheetAction.neutral
                ? Colors.white
                : const Color(0xFF555B4B);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: ink.withValues(alpha: 0.42),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scroll) => Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                    color: theme.borderColor,
                    borderRadius: BorderRadius.circular(3)),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                  children: [
                    if (CardImage.has(imageUrl)) ...[
                      CardImage(
                          url: imageUrl,
                          height: 150,
                          borderRadius: BorderRadius.circular(24)),
                      const SizedBox(height: 14),
                    ],
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                              color: theme.effectivePrimary,
                              shape: BoxShape.circle),
                          child: Icon(icon, size: 28, color: ink),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: theme.textColor)),
                              const SizedBox(height: 6),
                              Container(
                                height: 28,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    color: theme.tone(Tone.butter).bg,
                                    borderRadius: BorderRadius.circular(14)),
                                child: Text(status,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: ink)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(description,
                          style: TextStyle(
                              fontSize: 14,
                              height: 1.9,
                              color: theme.textSecondaryColor)),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        for (int i = 0; i < tiles.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 6),
                              decoration: BoxDecoration(
                                  color: theme.tone(tiles[i].tone).bg,
                                  borderRadius: BorderRadius.circular(24)),
                              child: Column(
                                children: [
                                  Icon(tiles[i].icon, size: 20, color: ink),
                                  const SizedBox(height: 4),
                                  Text(tiles[i].label,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF3C4034))),
                                  const SizedBox(height: 4),
                                  Text(tiles[i].value,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: ink)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    banner,
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 8, 20, MediaQuery.of(ctx).padding.bottom + 16),
                child: GestureDetector(
                  onTap: actionKind == _SheetAction.disabled
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          await onAction();
                        },
                  child: Container(
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: btnBg,
                        borderRadius: BorderRadius.circular(28)),
                    child: Text(actionLabel,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: btnFg)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    Color color,
    ThemeProvider theme,
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
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: theme.textColor,
              ),
            ),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
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

  // ═══════════════════════════════════════════════════════════
  // دیالوگ جزئیات ماموریت
  // ═══════════════════════════════════════════════════════════
  void _showQuestDetailDialog(Quest quest) async {
    try {
      final theme = Provider.of<ThemeProvider>(context, listen: false);
      final Color color = _parseColor(quest.color);

      final userQuests = await _supabase.getUserQuests(_currentUserId);

      UserQuest? userQuest;
      for (var uq in userQuests) {
        if (uq.questId == quest.id) {
          userQuest = uq;
          break;
        }
      }

      final bool hasStarted = userQuest != null &&
          userQuest.isActive == true &&
          userQuest.isCompleted == false;

      final bool isCompleted =
          userQuest != null && userQuest.isCompleted == true;

      final bool isNew = !hasStarted && !isCompleted;

      final int progress = userQuest?.progress ?? 0;
      final int targetCount = quest.targetCount;
      final double progressPercent =
          targetCount > 0 ? (progress / targetCount).clamp(0.0, 1.0) : 0.0;

      if (!mounted) return;

      final status = isCompleted
          ? 'انجام شده'
          : hasStarted
              ? 'در حال انجام'
              : 'ماموریت جدید - آماده شروع';
      final qRemaining = targetCount - progress;

      Widget banner;
      if (hasStarted && !isCompleted) {
        banner = _sheetProgress(theme, progress, targetCount, progressPercent,
            qRemaining > 0 ? '$qRemaining روز دیگر تا تکمیل ماموریت' : null);
      } else if (isCompleted) {
        banner = _sheetBanner(theme.tone(Tone.mint).bg, 'ماموریت کامل شد!',
            'شما این ماموریت را با موفقیت به پایان رساندید');
      } else {
        banner = _sheetBanner(theme.tone(Tone.butter).bg, 'آماده شروع!',
            'این ماموریت ${quest.targetCount} روزه را شروع کنید');
      }

      _showDetailSheet(
        theme: theme,
        icon: _getIconData(quest.icon),
        title: quest.title,
        status: status,
        description: quest.description,
        imageUrl: quest.imageUrl,
        tiles: [
          _SheetTile(Icons.calendar_today_rounded, 'مدت زمان',
              '${quest.targetCount} روز', Tone.sky),
          _SheetTile(Icons.military_tech_rounded, 'نشان', quest.badge,
              Tone.butter),
          _SheetTile(
              Icons.star_rounded, 'پاداش', '+${quest.xpReward} XP', Tone.peach),
        ],
        banner: banner,
        actionLabel: isCompleted
            ? 'بستن'
            : hasStarted
                ? 'انصراف از ماموریت'
                : 'شروع ماموریت',
        actionKind: isCompleted
            ? _SheetAction.neutral
            : hasStarted
                ? _SheetAction.danger
                : _SheetAction.primary,
        onAction: () async {
          if (hasStarted && !isCompleted) {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: theme.cardColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                title: const Text('انصراف از ماموریت'),
                content: Text(
                    'آیا از انصراف از ماموریت "${quest.title}" مطمئن هستید؟\n\nبا انصراف، تمام پیشرفت شما از دست خواهد رفت.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('انصراف')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('بله، انصراف',
                          style: TextStyle(color: theme.errorColor))),
                ],
              ),
            );
            if (confirm == true) await _cancelQuest(quest);
          } else if (isNew) {
            await _startQuest(quest);
          }
        },
      );
    } catch (e) {
      print('Error showing quest details: $e');
    }
  }

  Widget _buildQuestInfoItem({
    required IconData icon,
    required String label,
    required String value,
    bool isActive = true,
    required ThemeProvider theme,
  }) {
    final Color textColor =
        isActive ? theme.textColor : theme.textSecondaryColor;
    final Color bgColor = theme.isDarkMode
        ? (isActive ? const Color(0xFF2A2A2A) : const Color(0xFF1E1E1E))
        : (isActive ? Colors.grey.shade50 : Colors.grey.shade100);
    final Color borderColor = theme.borderColor;

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
            color: isActive ? theme.textSecondaryColor : theme.borderColor,
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
              color: theme.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _parseColor(String colorStr) {
    try {
      if (colorStr.startsWith('#')) {
        return Color(int.parse('FF${colorStr.substring(1)}', radix: 16));
      }
      return const Color(0xFF4A90E2);
    } catch (e) {
      return const Color(0xFF4A90E2);
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'fitness_center':
        return Icons.fitness_center;
      case 'book':
        return Icons.book;
      case 'wb_sunny':
        return Icons.wb_sunny;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'water_drop':
        return Icons.water_drop;
      case 'no_food':
        return Icons.no_food;
      case 'language':
        return Icons.language;
      case 'directions_walk':
        return Icons.directions_walk;
      case 'whatshot':
        return Icons.whatshot;
      case 'flag':
        return Icons.flag;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'sports_martial_arts':
        return Icons.sports_martial_arts;
      default:
        return Icons.flag;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final Color primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    'در حال بارگذاری...',
                    style: TextStyle(color: theme.textSecondaryColor),
                  ),
                ],
              ),
            )
          : _errorMessage.isNotEmpty
              ? _buildErrorState(primaryColor, theme)
              : _buildMainContent(primaryColor, theme),
    );
  }

  Widget _buildErrorState(Color primaryColor, ThemeProvider theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            'خطا در بارگذاری داده‌ها',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(_errorMessage,
              style: TextStyle(color: theme.textSecondaryColor)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: forceRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('تلاش مجدد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(Color primaryColor, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Container(
        height: 64,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(32),
          boxShadow: theme.softShadow,
        ),
        child: TabBar(
          controller: _tabController,
          isScrollable: false,
          labelPadding: EdgeInsets.zero,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: theme.effectivePrimary,
            borderRadius: BorderRadius.circular(26),
          ),
          dividerColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          labelColor: theme.onPrimaryColor,
          unselectedLabelColor: theme.textSecondaryColor,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          tabs: _tabs.map((tab) {
            return Tab(
              height: 56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab['icon'], size: 20),
                  const SizedBox(height: 2),
                  Text(tab['label'], maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMainContent(Color primaryColor, ThemeProvider theme) {
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: child,
                ),
              );
            },
            child: TabBarView(
              key: ValueKey(_tabController.index),
              controller: _tabController,
              children: [
                ChallengesTab(
                  challenges: _challenges,
                  myChallenges: _myChallenges,
                  currentUserId: _currentUserId,
                  onRefresh: forceRefresh,
                  joinChallenge: _joinChallenge,
                  leaveChallenge: _leaveChallenge,
                  showChallengeDetails: _showChallengeDetailsDialog,
                ),
                PackagesTab(
                  packages: _templatePackages,
                  currentUserId: _currentUserId,
                  onRefresh: forceRefresh,
                ),
                QuestsTab(
                  quests: _quests,
                  completedQuests: _completedQuests,
                  currentUserId: _currentUserId,
                  onRefresh: forceRefresh,
                  showQuestDetail: _showQuestDetailDialog,
                ),
                const LeaderboardTab(),
              ],
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildTabBar(primaryColor, theme),
        ),
      ],
    );
  }
}

class _CachedChallengeDetails {
  final Map<String, dynamic> data;
  final DateTime timestamp;

  _CachedChallengeDetails({required this.data, required this.timestamp});
}

enum _SheetAction { primary, danger, neutral, disabled }

class _SheetTile {
  final IconData icon;
  final String label;
  final String value;
  final Tone tone;
  const _SheetTile(this.icon, this.label, this.value, this.tone);
}
