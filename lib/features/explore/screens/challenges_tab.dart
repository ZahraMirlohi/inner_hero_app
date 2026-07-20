// lib/features/explore/screens/challenges_tab.dart
import 'package:flutter/material.dart';
import '/services/supabase_service.dart';
import '../widgets/challenge_card.dart';

class ChallengesTab extends StatefulWidget {
  final List<Map<String, dynamic>> challenges;
  final List<Map<String, dynamic>> myChallenges;
  final String currentUserId;
  final VoidCallback onRefresh;
  final Function(Map<String, dynamic>) joinChallenge;
  final Function(Map<String, dynamic>) leaveChallenge;
  final Function(Map<String, dynamic>) showChallengeDetails;

  const ChallengesTab({
    super.key,
    required this.challenges,
    required this.myChallenges,
    required this.currentUserId,
    required this.onRefresh,
    required this.joinChallenge,
    required this.leaveChallenge,
    required this.showChallengeDetails,
  });

  @override
  State<ChallengesTab> createState() => _ChallengesTabState();
}

class _ChallengesTabState extends State<ChallengesTab> {
  final _supabase = SupabaseService();
  int _refreshCounter = 0;
  bool _isInitialized = false;

  // ✅ کش برای ذخیره پیشرفت چالش‌ها با زمان انقضا
  final Map<String, _CachedProgress> _progressCache = {};
  final Map<String, bool> _isLoadingProgress = {};

  // ✅ کش برای تعداد شرکت‌کنندگان
  final Map<String, _CachedValue<int>> _participantsCache = {};

  @override
  void initState() {
    super.initState();
    _checkExpiredChallenges();
  }

  @override
  void didUpdateWidget(ChallengesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.challenges != widget.challenges) {
      _progressCache.clear();
      _participantsCache.clear();
    }
  }

  Future<void> _checkExpiredChallenges() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await Future.delayed(const Duration(milliseconds: 500));
    await _supabase.checkExpiredChallenges(widget.currentUserId);

    if (mounted) {
      widget.onRefresh();
    }
  }

  // ✅ متد دریافت پیشرفت با کش
  Future<Map<String, int>> _getCachedProgress(String challengeId) async {
    // ✅ اگر در کش است و معتبر است (کمتر از 30 ثانیه)
    if (_progressCache.containsKey(challengeId)) {
      final cached = _progressCache[challengeId]!;
      if (DateTime.now().difference(cached.timestamp) <
          const Duration(seconds: 30)) {
        return cached.data;
      }
    }

    // ✅ اگر در حال بارگذاری است، منتظر بمان
    if (_isLoadingProgress[challengeId] == true) {
      await Future.delayed(const Duration(milliseconds: 100));
      return _getCachedProgress(challengeId);
    }

    _isLoadingProgress[challengeId] = true;

    try {
      final result = await _supabase.getUserChallengeProgressDetails(
        widget.currentUserId,
        challengeId,
      );

      // ✅ ذخیره در کش
      _progressCache[challengeId] = _CachedProgress(
        data: result,
        timestamp: DateTime.now(),
      );

      print('📊 Progress for challenge $challengeId: $result');
      return result;
    } catch (e) {
      print('❌ Error getting progress for challenge $challengeId: $e');
      return {'completedDays': 0, 'totalDays': 0};
    } finally {
      _isLoadingProgress[challengeId] = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  // ✅ متد دریافت تعداد شرکت‌کنندگان با کش
  Future<int> _getCachedParticipants(String challengeId) async {
    if (_participantsCache.containsKey(challengeId)) {
      final cached = _participantsCache[challengeId]!;
      if (DateTime.now().difference(cached.timestamp) <
          const Duration(minutes: 5)) {
        return cached.value;
      }
    }

    try {
      final count = await _supabase.getRealParticipantsCount(challengeId);
      _participantsCache[challengeId] = _CachedValue(
        value: count,
        timestamp: DateTime.now(),
      );
      return count;
    } catch (e) {
      return 0;
    }
  }

  // ✅ ریفرش کش
  void _refreshProgress(String challengeId) {
    _progressCache.remove(challengeId);
    _participantsCache.remove(challengeId);
    setState(() {
      _refreshCounter++;
    });
  }

  // lib/features/explore/screens/challenges_tab.dart

  @override
  Widget build(BuildContext context) {
    if (widget.challenges.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'هنوز چالشی وجود ندارد',
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 8),
            Text(
              'برای اضافه شدن چالش‌های جدید منتظر بمانید',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ],
        ),
      );
    }

    // ✅ چالش‌های موفق
    final successfulChallenges = widget.challenges
        .where((c) => c['isJoined'] == true && c['isCompleted'] == true)
        .toList();

    // ✅ چالش‌های ناموفق (کاربر ثبت‌نام کرده ولی موفق نشده)
    final failedChallenges = widget.challenges
        .where(
          (c) =>
              c['isJoined'] == true &&
              c['isCompleted'] == false &&
              c['status'] == 'failed',
        )
        .toList();

    // ✅ چالش‌های فعال (کاربر ثبت‌نام کرده و در حال انجام)
    final activeChallenges = widget.challenges
        .where(
          (c) =>
              c['isJoined'] == true &&
              c['isCompleted'] != true &&
              c['status'] != 'failed',
        )
        .toList();

    // ✅ چالش‌های جدید (کاربر ثبت‌نام نکرده)
    final otherChallenges = widget.challenges
        .where((c) => c['isJoined'] != true)
        .toList();

    // ✅ تفکیک چالش‌های جدید به دو دسته:
    // 1. چالش‌های با مهلت ثبت‌نام فعال (رنگی)
    // 2. چالش‌های با مهلت ثبت‌نام تمام شده (خاکستری)
    final availableChallenges = otherChallenges
        .where((c) => c['isRegistrationClosed'] != true)
        .toList();

    final expiredChallenges = otherChallenges
        .where((c) => c['isRegistrationClosed'] == true)
        .toList();

    // ✅ مرتب‌سازی: چالش‌های فعال اول، سپس منقضی شده
    final sortedChallenges = [...availableChallenges, ...expiredChallenges];

    // تقسیم به دو ستون برای نمایش
    List<Map<String, dynamic>> leftColumn = [];
    List<Map<String, dynamic>> rightColumn = [];

    for (int i = 0; i < sortedChallenges.length; i++) {
      if (i % 2 == 0) {
        leftColumn.add(sortedChallenges[i]);
      } else {
        rightColumn.add(sortedChallenges[i]);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ جرقه روزانه
          const DailySpark(),
          const SizedBox(height: 20),

          // ✅ پیام‌های سیستم (چالش‌های شکست خورده)
          _buildSystemMessages(),
          const SizedBox(height: 12),

          // ✅ چالش‌های موفق
          if (successfulChallenges.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.emoji_events,
              title: '🏆 چالش‌های موفق',
              color: Colors.green,
            ),
            const SizedBox(height: 12),
            ...successfulChallenges.map(
              (challenge) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildChallengeCard(challenge, status: 'success'),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ✅ چالش‌های ناموفق
          if (failedChallenges.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.cancel,
              title: '⛔ چالش‌های ناموفق',
              color: Colors.red,
            ),
            const SizedBox(height: 12),
            ...failedChallenges.map(
              (challenge) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildChallengeCard(challenge, status: 'failed'),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ✅ چالش‌های فعال
          if (activeChallenges.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.play_circle,
              title: '⚡ چالش‌های فعال من',
              color: const Color(0xFF4A90E2),
            ),
            const SizedBox(height: 12),
            ...activeChallenges.map(
              (challenge) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildActiveChallengeCard(challenge),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ✅ بخش نمایش چالش‌های جدید
          if (otherChallenges.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.explore,
              title: '✨ چالش‌های جدید',
              color: const Color(0xFFFFA500),
            ),
            const SizedBox(height: 12),

            // ✅ نمایش چالش‌های جدید در دو ستون
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: leftColumn
                        .map(
                          (challenge) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildChallengeCard(challenge),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: rightColumn
                        .map(
                          (challenge) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildChallengeCard(challenge),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // ✅ کارت تست شخصیت
          _buildPersonalityTestCard(),
        ],
      ),
    );
  }

  // ==================== ویجت پیام‌های سیستم ====================

  Widget _buildSystemMessages() {
    // ✅ دریافت چالش‌هایی که اخیراً شکست خورده‌اند
    final failedChallenges = widget.challenges
        .where(
          (c) =>
              c['isJoined'] == true &&
              c['status'] == 'failed' &&
              c['isCompleted'] == false,
        )
        .toList();

    if (failedChallenges.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: failedChallenges.map((challenge) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200, width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ چالش "${challenge['title']}"',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade800,
                      ),
                    ),
                    Text(
                      'به دلیل شکستن زنجیره انجام روزانه، از برنامه شما حذف شد',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade600,
                      ),
                    ),
                    if (challenge['isRegistrationClosed'] != true) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () {
                          // ✅ امکان ثبت‌نام مجدد
                          widget.joinChallenge(challenge);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'ثبت‌نام مجدد',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ==================== کارت چالش فعال ====================

  // lib/features/explore/screens/challenges_tab.dart

  Widget _buildActiveChallengeCard(Map<String, dynamic> challenge) {
    final fixedColor = const Color(0xFF4A90E2);
    final totalDays = challenge['challenge_duration'] as int? ?? 7;
    final challengeId = challenge['id'];

    return GestureDetector(
      onTap: () => widget.showChallengeDetails(challenge),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [fixedColor.withOpacity(0.9), fixedColor.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: fixedColor.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.play_circle,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    challenge['title'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'چالش $totalDays روزه',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<Map<String, int>>(
                    key: ValueKey('${challengeId}_${_refreshCounter}'),
                    future: _getCachedProgress(challengeId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: 0,
                                    backgroundColor: Colors.white30,
                                    color: Colors.white,
                                    minHeight: 6,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '0%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                              'در حال محاسبه...',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        );
                      }

                      if (snapshot.hasError || !snapshot.hasData) {
                        return const Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: 0,
                                    backgroundColor: Colors.white30,
                                    color: Colors.white,
                                    minHeight: 6,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '0%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                              'خطا در محاسبه',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        );
                      }

                      final completedDays =
                          snapshot.data!['completedDays'] ?? 0;
                      final total = snapshot.data!['totalDays'] ?? totalDays;

                      // ✅ محاسبه درصد پیشرفت
                      final progress = total > 0 ? completedDays / total : 0.0;

                      // ✅ نمایش پیشرفت به صورت روز/کل
                      final displayText = '$completedDays از $total روز';

                      print(
                        '📊 Challenge: ${challenge['title']}, Progress: $completedDays/$total = ${(progress * 100).toInt()}%',
                      );

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress.clamp(0.0, 1.0),
                                    backgroundColor: Colors.white.withOpacity(
                                      0.2,
                                    ),
                                    color: Colors.white,
                                    minHeight: 6,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            displayText,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _showLeaveChallengeDialog(challenge),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.exit_to_app,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'انصراف',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== کارت چالش عمومی ====================

  Widget _buildChallengeCard(
    Map<String, dynamic> challenge, {
    String status = 'new',
  }) {
    final isRegistrationClosed = challenge['isRegistrationClosed'] ?? false;
    final isCompleted = challenge['isCompleted'] ?? false;
    final isFailed = status == 'failed';
    final isExpired = isRegistrationClosed && !isCompleted && !isFailed;

    Color getBgColor() {
      if (isFailed) return Colors.red.shade50;
      if (isCompleted) return Colors.green.shade50;
      if (isExpired) return Colors.grey.shade50;
      return _parseColor(
        challenge['color'] ?? '#FFB8B8',
      ).withValues(alpha: 0.1);
    }

    final bgColor = getBgColor();

    return GestureDetector(
      onTap: () => widget.showChallengeDetails(challenge),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16), // ✅ افزایش padding
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpired ? Colors.grey.shade300 : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ردیف بالا: وضعیت و شرکت‌کنندگان
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isFailed
                        ? Colors.red.withValues(alpha: 0.15)
                        : isCompleted
                        ? Colors.green.withValues(alpha: 0.15)
                        : isExpired
                        ? Colors.grey.withValues(alpha: 0.15)
                        : const Color(0xFFFFA500).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isFailed
                            ? Icons.close
                            : isCompleted
                            ? Icons.check_circle
                            : isExpired
                            ? Icons.lock_outline
                            : Icons.access_time,
                        size: 14,
                        color: isFailed
                            ? Colors.red
                            : isCompleted
                            ? Colors.green
                            : isExpired
                            ? Colors.grey
                            : const Color(0xFFFFA500),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isFailed
                            ? 'ناموفق'
                            : isCompleted
                            ? 'موفق'
                            : isExpired
                            ? 'پایان ثبت‌نام'
                            : '${challenge['daysLeft'] ?? 0} روز',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isFailed
                              ? Colors.red
                              : isCompleted
                              ? Colors.green
                              : isExpired
                              ? Colors.grey
                              : const Color(0xFFFFA500),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                FutureBuilder<int>(
                  key: ValueKey(
                    'participants_${challenge['id']}_$_refreshCounter',
                  ),
                  future: _getCachedParticipants(challenge['id']),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isExpired
                            ? Colors.grey.shade200
                            : Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people,
                            size: 14,
                            color: isExpired
                                ? Colors.grey.shade500
                                : Colors.grey.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isExpired
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // عنوان و توضیحات
            Text(
              challenge['title'] ?? 'بدون عنوان',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isFailed
                    ? Colors.red.shade800
                    : isCompleted
                    ? Colors.green.shade800
                    : isExpired
                    ? Colors.grey.shade600
                    : const Color(0xFF1A1A2E),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              challenge['description'] ?? '',
              style: TextStyle(
                fontSize: 12,
                color: isFailed
                    ? Colors.red.shade600
                    : isCompleted
                    ? Colors.green.shade600
                    : isExpired
                    ? Colors.grey.shade500
                    : Colors.grey.shade700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // ✅ ردیف پایین: مدت زمان، XP و دکمه (اصلاح شده با Expanded)
            Row(
              children: [
                // مدت زمان
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isExpired
                          ? Colors.grey.shade200
                          : Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer,
                          size: 14,
                          color: isExpired
                              ? Colors.grey.shade500
                              : Colors.grey.shade700,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${challenge['challenge_duration'] ?? 7} روزه',
                            style: TextStyle(
                              fontSize: 11,
                              color: isExpired
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // XP
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isExpired
                          ? Colors.grey.shade200
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.stars,
                          size: 14,
                          color: isExpired
                              ? Colors.grey.shade500
                              : const Color(0xFFFFA500),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '+${challenge['xp_reward'] ?? 0}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isExpired
                                  ? Colors.grey.shade500
                                  : const Color(0xFFFFA500),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // دکمه جزئیات
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: isExpired
                        ? null
                        : () => widget.showChallengeDetails(challenge),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isExpired
                          ? Colors.grey.shade300
                          : const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isExpired ? 'پایان' : 'جزئیات',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLeaveChallengeDialog(Map<String, dynamic> challenge) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('انصراف از چالش'),
        content: Text(
          'آیا از انصراف از چالش "${challenge['title']}" مطمئن هستید؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.leaveChallenge(challenge);
            },
            child: const Text(
              'بله، انصراف',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalityTestCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF764BA2).withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.psychology, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'کدام قهرمان درونت بیدار است؟',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'تست شخصیت ۵ سوالی',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('شروع'),
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
}

// ==================== ویجت جرقه روزانه ====================

class DailySpark extends StatelessWidget {
  const DailySpark({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> sparks = [
      {
        'type': 'quote',
        'text':
            'تنها محدودیتی که دارید، محدودیتی است که خودتان در ذهنتان ایجاد می‌کنید.',
        'author': 'نپلئون هیل',
      },
      {
        'type': 'quote',
        'text': 'موفقیت مجموع تلاش‌های کوچکی است که روز به روز تکرار می‌شوند.',
        'author': 'رابرت کالیر',
      },
      {
        'type': 'challenge',
        'text': 'امروز ۱۰ دقیقه بدون گوشی وقت بگذران',
        'author': '',
      },
      {
        'type': 'fact',
        'text': 'عادت‌های جدید به طور متوسط ۶۶ روز طول می‌کشند تا شکل بگیرند.',
        'author': 'تحقیقات دانشگاه کالج لندن',
      },
      {
        'type': 'quote',
        'text': 'با انجام کارهای کوچک هر روز، می‌توانید به نتایج بزرگ برسید.',
        'author': 'لائوتسه',
      },
    ];

    final spark = sparks[DateTime.now().day % sparks.length];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFB347).withOpacity(0.9),
            const Color(0xFFFF6B6B).withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B6B).withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              spark['type'] == 'quote'
                  ? Icons.format_quote
                  : spark['type'] == 'challenge'
                  ? Icons.bolt
                  : Icons.lightbulb,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spark['type'] == 'quote'
                      ? '✨ جرقه روزانه'
                      : spark['type'] == 'challenge'
                      ? '⚡ چالش روزانه'
                      : '💡 واقعیت علمی',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  spark['text'] ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                if (spark['author'] != null &&
                    spark['author'].toString().isNotEmpty)
                  Text(
                    '- ${spark['author']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ✅ کلاس‌های کمکی برای کش
class _CachedProgress {
  final Map<String, int> data;
  final DateTime timestamp;

  _CachedProgress({required this.data, required this.timestamp});
}

class _CachedValue<T> {
  final T value;
  final DateTime timestamp;

  _CachedValue({required this.value, required this.timestamp});
}
