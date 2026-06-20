import 'package:flutter/material.dart';
import '/services/appwrite_service.dart';
import '/services/date_service.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;

  // داده‌ها از دیتابیس
  List<Map<String, dynamic>> _challenges = [];
  List<Map<String, dynamic>> _myChallenges = [];
  List<Map<String, dynamic>> _templatePackages = [];
  List<Map<String, dynamic>> _quests = [];
  List<Map<String, dynamic>> _cosmetics = [];
  List<Map<String, dynamic>> _dailySpark = [];

  bool _isLoading = true;
  String _errorMessage = '';
  String _currentUserId = '';
  int _refreshCounter = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
    _loadData();
  }

  // ==================== بارگذاری داده‌ها ====================

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    setState(() => _errorMessage = '');

    try {
      final appwrite = AppwriteService();
      final currentUser = await appwrite.getCurrentUser();

      if (currentUser == null) {
        setState(() {
          _errorMessage = 'لطفاً وارد حساب کاربری خود شوید';
          _isLoading = false;
        });
        return;
      }

      _currentUserId = currentUser.$id;

      // ========== تغییر اینجا ==========
      // فقط چالش‌های قابل ثبت‌نام جدید
      _challenges = await appwrite.getAvailableChallenges();
      // چالش‌های فعال کاربر (حتی اگه ثبت‌نامشون بسته شده باشه)
      _myChallenges = await appwrite.getUserChallenges(currentUser.$id);
      // ================================

      // فقط برای چالش‌های جدید، isJoined رو محاسبه کن
      for (int i = 0; i < _challenges.length; i++) {
        final challengeId = _challenges[i]['id'];

        // محاسبه روزهای باقی‌مونده برای ثبت‌نام
        if (_challenges[i]['registrationEndDate'] != null) {
          try {
            final registrationEnd = DateTime.parse(
              _challenges[i]['registrationEndDate'],
            );
            final daysLeft = registrationEnd.difference(DateTime.now()).inDays;
            _challenges[i]['daysLeft'] = daysLeft > 0 ? daysLeft : 0;
          } catch (e) {
            _challenges[i]['daysLeft'] = 0;
          }
        }

        // بررسی اینکه کاربر قبلاً این چالش رو ثبت‌نام کرده یا نه
        _challenges[i]['isJoined'] = _myChallenges.any(
          (c) => c['id'] == challengeId,
        );
      }

      _animationController.forward();
    } catch (e) {
      setState(
        () => _errorMessage = 'خطا در خواندن از دیتابیس: ${e.toString()}',
      );
      debugPrint('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _joinChallenge(Map<String, dynamic> challenge) async {
    debugPrint('========== شروع شرکت در چالش ==========');
    debugPrint('challenge: ${challenge['title']}');
    debugPrint('challengeId: ${challenge['id']}');

    setState(() => _isLoading = true);

    try {
      final appwrite = AppwriteService();
      final currentUser = await appwrite.getCurrentUser();

      if (currentUser != null) {
        debugPrint('کاربر: ${currentUser.$id}');

        // 1. ثبت در user_challenges
        await appwrite.joinChallenge(currentUser.$id, challenge['id']);
        debugPrint('✅ ثبت در user_challenges انجام شد');

        // 2. اضافه کردن عادت چالش
        await appwrite.addChallengeHabitToUser(currentUser.$id, challenge);
        debugPrint('✅ عادت چالش اضافه شد');

        // 3. بارگذاری مجدد داده‌ها
        await _loadData();
        debugPrint('✅ داده‌ها بارگذاری مجدد شد');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('به چالش پیوستید! 🎉'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ خطا در _joinChallenge: $e');
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

  Future<void> _leaveChallenge(Map<String, dynamic> challenge) async {
    debugPrint('========== شروع انصراف از چالش ==========');
    debugPrint('challenge: ${challenge['title']}');
    debugPrint('challengeId: ${challenge['id']}');

    setState(() => _isLoading = true);

    try {
      final appwrite = AppwriteService();
      final currentUser = await appwrite.getCurrentUser();

      if (currentUser != null) {
        // 1. پیدا کردن userProgressId
        final userChallenge = _myChallenges.firstWhere(
          (c) => c['id'] == challenge['id'],
          orElse: () => {},
        );

        final userProgressId = userChallenge['userProgressId'];

        if (userProgressId != null && userProgressId.isNotEmpty) {
          await appwrite.leaveChallenge(
            currentUser.$id,
            challenge['id'],
            userProgressId,
          );
          debugPrint('✅ انصراف از چالش انجام شد');
        }

        // 2. حذف عادت چالش از کاربر (با استفاده از challengeId)
        await appwrite.removeChallengeHabitByChallengeId(
          currentUser.$id,
          challenge['id'],
        );
        debugPrint('✅ عادت چالش حذف شد');

        // 3. بارگذاری مجدد داده‌ها
        await _loadData();
        debugPrint('✅ داده‌ها بارگذاری مجدد شد');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('از چالش ${challenge['title']} انصراف دادید'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ خطا در _leaveChallenge: $e');
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

  // نمایش دیالوگ جزئیات چالش
  void _showChallengeDetailsDialog(Map<String, dynamic> challenge) async {
    // گرفتن تعداد واقعی شرکت‌کنندگان
    final realParticipants = await AppwriteService().getRealParticipantsCount(
      challenge['id'],
    );

    final isJoined = _myChallenges.any((c) => c['id'] == challenge['id']);

    // ========== حذف رنگ داینامیک و استفاده از رنگ ثابت ==========
    const fixedColor = Color(0xFF4A90E2); // آبی ثابت برای همه چالش‌ها
    // ============================================================

    final registrationEnd = DateTime.parse(challenge['registrationEndDate']);
    final daysLeftToRegister = registrationEnd
        .difference(DateTime.now())
        .inDays;
    final displayDaysLeft = daysLeftToRegister > 0 ? daysLeftToRegister : 0;

    final duration = challenge['challengeDuration'] as int;
    final startDate = DateTime.parse(challenge['startDate']);
    final endDate = DateTime.parse(challenge['endDate']);

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
                          // هدر چالش (اینجا می‌تونه از رنگ خود چالش استفاده کنه برای تنوع)
                          Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: fixedColor.withAlpha(38),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  challenge['isBoss'] == true
                                      ? Icons.emoji_events
                                      : Icons.flag,
                                  color: fixedColor,
                                  size: 30,
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
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A1A2E),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      challenge['description'],
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),

                          // ========== اطلاعات اصلی با رنگ ثابت آبی ==========
                          _buildDetailRowFixed(
                            Icons.access_time,
                            'مهلت ثبت‌نام',
                            '$displayDaysLeft روز باقی‌مانده',
                            fixedColor,
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRowFixed(
                            Icons.timer,
                            'مدت زمان چالش',
                            '$duration روز',
                            fixedColor,
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRowFixed(
                            Icons.people,
                            'شرکت‌کنندگان',
                            '$realParticipants نفر',
                            fixedColor,
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRowFixed(
                            Icons.stars,
                            'پاداش نهایی',
                            '+${challenge['xpReward']} XP',
                            fixedColor,
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRowFixed(
                            Icons.calendar_today,
                            'تاریخ شروع',
                            _formatDate(startDate),
                            fixedColor,
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRowFixed(
                            Icons.event,
                            'تاریخ پایان',
                            _formatDate(endDate),
                            fixedColor,
                          ),
                          // ================================================

                          // نوار پیشرفت جمعی (برای باس فایت)
                          if (challenge['isBoss'] == true &&
                              challenge['communityXP'] != null) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),
                            const Text(
                              'پیشرفت جمعی جامعه',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value:
                                          (challenge['communityXP'] as int) /
                                          (challenge['targetXP'] as int),
                                      backgroundColor: Colors.grey.shade200,
                                      color: fixedColor,
                                      minHeight: 8,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${((challenge['communityXP'] as int) / (challenge['targetXP'] as int) * 100).toInt()}%',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: fixedColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'XP جمع‌آوری شده: ${challenge['communityXP']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                Text(
                                  'هدف: ${challenge['targetXP']} XP',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // تسک‌های چالش
                          if (challenge['tasks'] != null &&
                              challenge['tasks'].toString().isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),
                            const Text(
                              'ماموریت‌های روزانه',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...(challenge['tasks'].toString().split(',')).map(
                              (task) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      size: 18,
                                      color: fixedColor,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        task.trim(),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF1A1A2E),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          // جایزه روزانه
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: fixedColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.stars, color: fixedColor, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'جایزه روزانه',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1A1A2E),
                                        ),
                                      ),
                                      Text(
                                        'با انجام هر روز چالش، +${(challenge['xpReward'] as int) ~/ (challenge['challengeDuration'] as int)} XP دریافت می‌کنید',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // دکمه اقدام با رنگ ثابت
                          if (isJoined)
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
                                  backgroundColor: const Color(0xFFE53935),
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
                            )
                          else
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
  }

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
              color: color.withAlpha(38), // آبی با 15% opacity
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
                color: Color(0xFF1A1A2E), // مشکی
              ),
            ),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: color.withAlpha(30), // آبی با 12% opacity
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color, // آبی پررنگ
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4A90E2)),
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
          Text(_errorMessage, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('تلاش مجدد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
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
            indicatorColor: const Color(0xFF4A90E2),
            indicatorWeight: 3,
            labelColor: const Color(0xFF4A90E2),
            unselectedLabelColor: Colors.grey[500],
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
              _buildChallengesTab(),
              _buildPackagesTab(),
              _buildQuestsTab(),
              _buildLeaderboardTab(),
              _buildCosmeticsTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== تب چالش‌ها ====================

  Widget _buildChallengesTab() {
    if (_challenges.isEmpty) {
      return _buildEmptyState(
        'هنوز چالشی وجود ندارد',
        Icons.emoji_events_outlined,
      );
    }

    final myActiveChallenges = _challenges
        .where((c) => c['isJoined'] == true)
        .toList();
    final otherChallenges = _challenges
        .where((c) => c['isJoined'] != true)
        .toList();

    List<Map<String, dynamic>> leftColumn = [];
    List<Map<String, dynamic>> rightColumn = [];

    for (int i = 0; i < otherChallenges.length; i++) {
      if (i % 2 == 0) {
        leftColumn.add(otherChallenges[i]);
      } else {
        rightColumn.add(otherChallenges[i]);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildDailySpark(),
          const SizedBox(height: 20),

          if (myActiveChallenges.isNotEmpty) ...[
            const Row(
              children: [
                Icon(Icons.play_circle, color: Color(0xFF4A90E2), size: 20),
                SizedBox(width: 8),
                Text(
                  'چالش‌های فعال من',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...myActiveChallenges.map(
              (challenge) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildActiveChallengeCard(challenge),
              ),
            ),
            const SizedBox(height: 24),
          ],

          const Row(
            children: [
              Icon(Icons.explore, color: Color(0xFFFFA500), size: 20),
              SizedBox(width: 8),
              Text(
                'چالش‌های جدید',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
          _buildPersonalityTestCard(),
        ],
      ),
    );
  }

  Widget _buildActiveChallengeCard(Map<String, dynamic> challenge) {
    final fixedColor = const Color(0xFF4A90E2);
    final totalDays = challenge['challengeDuration'] as int;
    final challengeId = challenge['id'];

    return GestureDetector(
      onTap: () => _showChallengeDetailsDialog(challenge),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [fixedColor.withAlpha(230), fixedColor.withAlpha(204)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: fixedColor.withAlpha(40),
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
                color: Colors.white.withAlpha(51),
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

                  // ========== FutureBuilder برای پیشرفت واقعی ==========
                  FutureBuilder<Map<String, int>>(
                    key: ValueKey('${challengeId}_${_refreshCounter}'),
                    future: AppwriteService().getUserChallengeProgressDetails(
                      _currentUserId,
                      challengeId,
                    ),
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

                      if (snapshot.hasError) {
                        debugPrint('Error: ${snapshot.error}');
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

                      if (!snapshot.hasData) {
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
                              'بدون داده',
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
                      final progress = total > 0 ? completedDays / total : 0.0;

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: Colors.white.withAlpha(51),
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
                            'انجام شده: $completedDays از $total روز',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withAlpha(179),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  // ====================================================
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    'فعال',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeCard(Map<String, dynamic> challenge) {
    final bgColor = _parseColor(challenge['color'] ?? '#FFB8B8');
    final textColor = _parseColor(challenge['textColor'] ?? '#E57373');
    final challengeId = challenge['id'];

    final registrationEnd = DateTime.parse(challenge['registrationEndDate']);
    final daysLeftToRegister = registrationEnd
        .difference(DateTime.now())
        .inDays;
    final displayDaysLeft = daysLeftToRegister > 0 ? daysLeftToRegister : 0;

    final duration = challenge['challengeDuration'] as int;

    return GestureDetector(
      onTap: () => _showChallengeDetailsDialog(challenge),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor.withAlpha(230),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: bgColor.withAlpha(40),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== هدر کارت ==========
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // روزهای باقی‌مانده برای ثبت‌نام
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(51),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 12,
                          color: Color(0xFF1A1A2E),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$displayDaysLeft روز',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // تعداد واقعی شرکت‌کنندگان
                  FutureBuilder<int>(
                    key: ValueKey(
                      'participants_${challengeId}_${_refreshCounter}',
                    ),
                    future: AppwriteService().getRealParticipantsCount(
                      challengeId,
                    ),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(51),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.people,
                              size: 12,
                              color: Color(0xFF1A1A2E),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$count نفر',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // ========== محتوای اصلی ==========
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // نشان (Badge)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      challenge['badge'] ?? '🔥 داغ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // عنوان چالش
                  Text(
                    challenge['title'],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // توضیحات
                  Text(
                    challenge['description'],
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // مدت زمان چالش
                  Row(
                    children: [
                      const Icon(
                        Icons.timer,
                        size: 14,
                        color: Color(0xFF1A1A2E),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'چالش $duration روزه',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // نوار پیشرفت جمعی (برای باس فایت)
                  if (challenge['isBoss'] == true &&
                      challenge['communityXP'] != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value:
                                  (challenge['communityXP'] as int) /
                                  (challenge['targetXP'] as int),
                              backgroundColor: Colors.white.withAlpha(51),
                              color: bgColor,
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${((challenge['communityXP'] as int) / (challenge['targetXP'] as int) * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // تسک‌های چالش (حداکثر ۲ تا)
                  if (challenge['tasks'] != null &&
                      challenge['tasks'].toString().isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (challenge['tasks'].toString().split(','))
                          .take(2)
                          .map(
                            (task) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(26),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    size: 12,
                                    color: Color(0xFF1A1A2E),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    task.trim(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ========== بخش پایین کارت ==========
                  Row(
                    children: [
                      // پاداش XP
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(26),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.stars,
                              size: 14,
                              color: Color(0xFF1A1A2E),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '+${challenge['xpReward']} XP',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),

                      // دکمه جزئیات
                      ElevatedButton(
                        onPressed: () => _showChallengeDetailsDialog(challenge),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: textColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'جزئیات',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailySpark() {
    if (_dailySpark.isEmpty) return const SizedBox();

    final spark = _dailySpark[DateTime.now().day % _dailySpark.length];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFB347).withAlpha(230),
            const Color(0xFFFF6B6B).withAlpha(230),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B6B).withAlpha(40),
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
              color: Colors.white.withAlpha(51),
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
                  spark['text'],
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
                      color: Colors.white.withAlpha(204),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
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
            color: const Color(0xFF764BA2).withAlpha(41),
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
              color: Colors.white.withAlpha(51),
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
                    color: Colors.white.withAlpha(204),
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

  // ==================== تب‌های دیگر ====================

  Widget _buildPackagesTab() {
    if (_templatePackages.isEmpty) {
      return _buildEmptyState(
        'هنوز بسته‌ای وجود ندارد',
        Icons.category_outlined,
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _templatePackages.length,
      itemBuilder: (context, index) =>
          _buildPackageCard(_templatePackages[index]),
    );
  }

  Widget _buildPackageCard(Map<String, dynamic> pkg) {
    final color = _parseColor(pkg['color'] ?? '#4A90E2');
    final bgColor = _parseColor(pkg['backgroundColor'] ?? '#D4F1F4');
    final habits = pkg['habits']?.toString().split(',') ?? [];

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getIconData(pkg['icon'] ?? 'fitness_center'),
                  color: Colors.white,
                  size: 24,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(76),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${habits.length} عادت',
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pkg['title'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pkg['description'],
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 24,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: habits.length > 3 ? 3 : habits.length,
                    itemBuilder: (context, i) => Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withAlpha(51),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        habits[i],
                        style: TextStyle(fontSize: 8, color: color),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(double.infinity, 36),
                  ),
                  child: const Text(
                    'افزودن به عادت‌ها',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestsTab() {
    if (_quests.isEmpty) {
      return _buildEmptyState('هنوز ماموریتی وجود ندارد', Icons.flag_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _quests.length,
      itemBuilder: (context, index) {
        final quest = _quests[index];
        final color = _parseColor(quest['color'] ?? '#FF9F43');

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withAlpha(51),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.flag, color: color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest['title'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      quest['description'],
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFA500).withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.stars,
                                size: 12,
                                color: Color(0xFFFFA500),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '+${quest['xpReward']} XP',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9B59B6).withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.emoji_events,
                                size: 12,
                                color: Color(0xFF9B59B6),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                quest['badge'],
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.chevron_right, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeaderboardTab() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildLeaderboardType('قهرمانان هفته', true),
              const SizedBox(width: 12),
              _buildLeaderboardType('پیوسته‌ترین', false),
              const SizedBox(width: 12),
              _buildLeaderboardType('الهام‌بخش‌ها', false),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 10,
            itemBuilder: (context, index) {
              final rank = index + 1;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: rank <= 3
                            ? const Color(0xFFFFA500).withAlpha(51)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          rank.toString(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: rank <= 3
                                ? const Color(0xFFFFA500)
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A90E2).withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          rank == 1
                              ? '🏆'
                              : rank == 2
                              ? '🥈'
                              : rank == 3
                              ? '🥉'
                              : '👤',
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'قهرمان ${rank}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          Text(
                            '${12000 - rank * 300} XP | 🔥 ${70 - rank} روز',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (rank <= 3)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: rank == 1
                              ? const Color(0xFFFFD700).withAlpha(51)
                              : rank == 2
                              ? const Color(0xFFC0C0C0).withAlpha(51)
                              : const Color(0xFFCD7F32).withAlpha(51),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          rank == 1
                              ? '🥇'
                              : rank == 2
                              ? '🥈'
                              : '🥉',
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardType(String title, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4A90E2) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCosmeticsTab() {
    if (_cosmetics.isEmpty) {
      return _buildEmptyState(
        'هنوز آیتمی در فروشگاه نیست',
        Icons.shopping_bag_outlined,
      );
    }

    int userXP = 3500;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A90E2), Color(0xFF9B59B6)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.stars, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'اعتبار شما',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    Text(
                      '$userXP XP',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add, size: 16, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      '${20000 - userXP} تا الماس',
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _cosmetics.length,
            itemBuilder: (context, index) {
              final item = _cosmetics[index];
              final color = _parseColor(item['color'] ?? '#4A90E2');
              final price = item['price'] as int;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: color.withAlpha(51),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        _getIconData(item['icon'] ?? 'star'),
                        color: color,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item['name'],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFA500).withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.stars,
                            size: 12,
                            color: Color(0xFFFFA500),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$price XP',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFFA500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: userXP >= price ? () {} : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: userXP >= price
                            ? color
                            : Colors.grey.shade300,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        minimumSize: const Size(80, 32),
                      ),
                      child: const Text('خرید', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==================== متدهای کمکی ====================

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey[500])),
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
}
