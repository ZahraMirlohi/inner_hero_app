import 'package:flutter/material.dart';
import '/services/supabase_service.dart'; // ← تغییر
import '/services/date_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _levelAnimationController;
  late Animation<double> _levelAnimation;

  final _supabase = SupabaseService(); // ← اضافه شده

  final int _userLevel = 27;
  final int _currentXP = 2450;
  final int _xpNeededForNextLevel = 2800;
  final int _totalXP = 12450;
  final int _activeHabits = 8;
  final int _openTasks = 3;
  final int _activeDays = 186;
  final int _currentStreak = 27;
  final int _bestStreak = 47;
  final int _totalBadges = 12;
  final int _totalBadgesAvailable = 28;

  final String _userName = 'آرمان قهرمان';
  final String _heroTitle = 'استاد تمرکز';
  final String _heroClass = 'جنگجو';
  final String _joinDate = '۱۲ فروردین ۱۴۰۴';
  final String _currentTheme = '🌲 جنگل سبز';
  final String _avatarFrame = '🥇 طلایی';
  final String _backgroundSound = '🌧️ باران';
  final int _spendableXP = 2850;

  bool _isDarkMode = false;
  bool _notificationsEnabled = true;
  String _calendarType = 'jalali';
  bool _isPrivateProfile = false;

  final List<bool> _weeklyStreak = [
    true,
    true,
    true,
    true,
    false,
    false,
    false,
  ];
  final List<String> _weekdays = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

  final List<Map<String, dynamic>> _badges = [
    {'name': '۳۰ روزه', 'icon': '🥇', 'color': 0xFFFFD700, 'earned': true},
    {'name': 'بنیان‌گذار', 'icon': '🔥', 'color': 0xFF4A90E2, 'earned': true},
    {'name': '۵۰ تسک', 'icon': '⭐', 'color': 0xFF9B59B6, 'earned': true},
    {'name': 'مدال مخفی', 'icon': '🔒', 'color': 0xFF95A5A6, 'earned': false},
    {'name': '۱۰۰ روزه', 'icon': '👑', 'color': 0xFFE74C3C, 'earned': false},
    {'name': 'الهام‌بخش', 'icon': '💡', 'color': 0xFFF39C12, 'earned': false},
  ];

  final List<Map<String, dynamic>> _milestones = [
    {'title': 'تحقیق بازار', 'completed': true, 'inProgress': false},
    {'title': 'آموزش مهارت', 'completed': true, 'inProgress': false},
    {'title': 'ساخت نمونه اولیه', 'completed': false, 'inProgress': true},
    {'title': 'جذب اولین مشتری', 'completed': false, 'inProgress': false},
    {'title': 'رسیدن به ۱۰ مشتری', 'completed': false, 'inProgress': false},
  ];

  final List<Map<String, dynamic>> _habitStats = [
    {'name': 'ورزش', 'rate': 0.82, 'color': 0xFF4A90E2},
    {'name': 'مطالعه', 'rate': 0.67, 'color': 0xFF9B59B6},
    {'name': 'مدیتیشن', 'rate': 0.45, 'color': 0xFFFFA500},
    {'name': 'نوشیدن آب', 'rate': 0.93, 'color': 0xFF2ECC71},
  ];

  @override
  void initState() {
    super.initState();
    _levelAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _levelAnimation =
        Tween<double>(
          begin: 0,
          end: _currentXP / _xpNeededForNextLevel,
        ).animate(
          CurvedAnimation(
            parent: _levelAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _levelAnimationController.forward();
    _loadSettings();
  }

  @override
  void dispose() {
    _levelAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final calendarType = await DateService.getCalendarType();
    setState(() {
      _calendarType = calendarType == 'jalali' ? 'شمسی' : 'میلادی';
    });
  }

  String _getLevelColor() {
    if (_userLevel >= 50) return 'افسانه‌ای';
    if (_userLevel >= 30) return 'الماسی';
    if (_userLevel >= 20) return 'طلایی';
    if (_userLevel >= 10) return 'نقره‌ای';
    if (_userLevel >= 5) return 'برنزی';
    return 'آهنی';
  }

  Color _getLevelColorCode() {
    if (_userLevel >= 50) return const Color(0xFF9B59B6);
    if (_userLevel >= 30) return const Color(0xFF3498DB);
    if (_userLevel >= 20) return const Color(0xFFFFD700);
    if (_userLevel >= 10) return const Color(0xFFC0C0C0);
    if (_userLevel >= 5) return const Color(0xFFCD7F32);
    return const Color(0xFF7F8C8D);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('قصر قهرمان'),
            backgroundColor: Colors.white,
            elevation: 0,
            foregroundColor: const Color(0xFF1A1A2E),
            centerTitle: true,
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildHeroHeader(),
                const SizedBox(height: 16),
                _buildQuickStatsBar(),
                const SizedBox(height: 20),
                _buildStreakFire(),
                const SizedBox(height: 20),
                _buildBadgesSection(),
                const SizedBox(height: 20),
                _buildHeroJourney(),
                const SizedBox(height: 20),
                _buildAnalyticsSection(),
                const SizedBox(height: 20),
                _buildCosmeticsSection(),
                const SizedBox(height: 20),
                _buildSettingsSection(),
                const SizedBox(height: 16),
                _buildLogoutButton(),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    final levelColor = _getLevelColorCode();
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, levelColor.withAlpha(25)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: levelColor.withAlpha(76), width: 2),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [levelColor, levelColor.withAlpha(127)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: levelColor.withAlpha(76),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.emoji_events,
                      size: 50,
                      color: Color(0xFFFFA500),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: levelColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    '$_userLevel',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _userName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: levelColor,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {},
                      child: const Icon(
                        Icons.edit,
                        size: 18,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.shield, size: 14, color: levelColor),
                    const SizedBox(width: 4),
                    Text(
                      _heroTitle,
                      style: TextStyle(fontSize: 12, color: levelColor),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: levelColor.withAlpha(51),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _heroClass == 'جنگجو'
                                ? '⚔️'
                                : _heroClass == 'کاوشگر'
                                ? '🧭'
                                : _heroClass == 'حکیم'
                                ? '📜'
                                : '🛡️',
                            style: const TextStyle(fontSize: 10),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _heroClass,
                            style: TextStyle(fontSize: 10, color: levelColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Level $_userLevel • ${_getLevelColor()}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$_currentXP / $_xpNeededForNextLevel XP',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _levelAnimation.value,
                    backgroundColor: Colors.grey.shade200,
                    color: levelColor,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'قهرمان از $_joinDate',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsBar() {
    final stats = [
      {
        'icon': Icons.fitness_center,
        'value': '$_activeHabits',
        'label': 'عادت',
        'color': 0xFF4A90E2,
      },
      {
        'icon': Icons.assignment,
        'value': '$_openTasks',
        'label': 'تسک',
        'color': 0xFFFFA500,
      },
      {
        'icon': Icons.stars,
        'value': '$_totalXP',
        'label': 'کل XP',
        'color': 0xFF9B59B6,
      },
      {
        'icon': Icons.calendar_today,
        'value': '$_activeDays',
        'label': 'روز فعال',
        'color': 0xFF2ECC71,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: stats
            .map(
              (stat) => Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        stat['icon'] as IconData,
                        color: Color(stat['color'] as int),
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stat['value'] as String,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        stat['label'] as String,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildStreakFire() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6B6B), Color(0xFFFFA500)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.local_fire_department, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'استریک جاری',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: _currentStreak),
                duration: const Duration(milliseconds: 1000),
                builder: (context, value, child) {
                  return Text(
                    value.toString(),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'بهترین: $_bestStreak روز',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _bestStreak - _currentStreak <= 3 &&
                            _bestStreak > _currentStreak
                        ? '${_bestStreak - _currentStreak} روز دیگه رکوردتو می‌شکنی! 🔥'
                        : 'امروز رو کامل کن تا استریک ${_currentStreak + 1} روزه بشی! 💪',
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final isCompleted = _weeklyStreak[index];
              return Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? Colors.white
                          : Colors.white.withAlpha(76),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        isCompleted ? Icons.check : Icons.close,
                        size: 18,
                        color: isCompleted
                            ? const Color(0xFFFF6B6B)
                            : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _weekdays[index],
                    style: TextStyle(
                      fontSize: 12,
                      color: isCompleted
                          ? Colors.white
                          : Colors.white.withAlpha(179),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.emoji_events, color: Color(0xFFFFA500)),
                  SizedBox(width: 8),
                  Text(
                    'مدال‌ها و افتخارات',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'همه ›',
                  style: TextStyle(color: Color(0xFF4A90E2)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _badges.length,
              itemBuilder: (context, index) {
                final badge = _badges[index];
                final isEarned = badge['earned'] as bool;
                return Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isEarned
                        ? Colors.white
                        : Colors.white.withAlpha(127),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        badge['icon'] as String,
                        style: const TextStyle(fontSize: 28),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        badge['name'] as String,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _totalBadges / _totalBadgesAvailable,
                    backgroundColor: Colors.grey.shade200,
                    color: const Color(0xFFFFA500),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$_totalBadges / $_totalBadgesAvailable',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroJourney() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.map, color: Color(0xFF4A90E2)),
              SizedBox(width: 8),
              Text(
                'سفر قهرمان',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'راه‌اندازی کسب‌وکار شخصی',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: 0.4,
              backgroundColor: Colors.grey.shade200,
              color: const Color(0xFF4A90E2),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          ..._milestones.map(
            (milestone) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    milestone['completed'] == true
                        ? Icons.check_circle
                        : milestone['inProgress'] == true
                        ? Icons.hourglass_empty
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: milestone['completed'] == true
                        ? Colors.green
                        : milestone['inProgress'] == true
                        ? const Color(0xFFFFA500)
                        : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      milestone['title'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: milestone['completed'] == true
                            ? Colors.grey
                            : const Color(0xFF1A1A2E),
                        decoration: milestone['completed'] == true
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                  if (milestone['inProgress'] == true)
                    const Text(
                      'در حال پیشرفت',
                      style: TextStyle(fontSize: 10, color: Color(0xFFFFA500)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('ویرایش سفر'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 36),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics, color: Color(0xFF4A90E2)),
                  SizedBox(width: 8),
                  Text(
                    'آنالیز پیشرفت',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text(
                'این هفته',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._habitStats.map(
            (habit) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: Text(
                          habit['name'] as String,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: habit['rate'] as double,
                            backgroundColor: Colors.grey.shade200,
                            color: Color(habit['color'] as int),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${((habit['rate'] as double) * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'این ماه ۲۳٪ بیشتر از ماه قبل عادت‌هات رو انجام دادی! 🎉',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {},
            child: const Text(
              'مشاهده گزارش کامل ›',
              style: TextStyle(color: Color(0xFF4A90E2)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCosmeticsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A90E2), Color(0xFF9B59B6)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shopping_bag, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'تزئینات قهرمان',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCosmeticItem('تم فعال', _currentTheme),
              _buildCosmeticItem('فریم آواتار', _avatarFrame),
              _buildCosmeticItem('صدای پس‌زمینه', _backgroundSound),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.stars, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    'XP قابل خرج: $_spendableXP',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.shopping_cart, size: 16),
                label: const Text('فروشگاه'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF4A90E2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCosmeticItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white70),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection() {
    final settings = [
      {
        'icon': Icons.calendar_today,
        'title': 'تقویم',
        'value': _calendarType,
        'color': 0xFF4A90E2,
      },
      {
        'icon': Icons.notifications,
        'title': 'اعلان‌ها',
        'value': _notificationsEnabled ? 'روشن' : 'خاموش',
        'color': 0xFFFFA500,
      },
      {
        'icon': Icons.dark_mode,
        'title': 'حالت تاریک',
        'value': _isDarkMode ? 'روشن' : 'خاموش',
        'color': 0xFF9B59B6,
      },
      {
        'icon': Icons.lock,
        'title': 'حریم خصوصی',
        'value': _isPrivateProfile ? 'خصوصی' : 'عمومی',
        'color': 0xFF2ECC71,
      },
      {
        'icon': Icons.share,
        'title': 'دعوت دوستان',
        'value': '',
        'color': 0xFFE74C3C,
      },
      {'icon': Icons.help, 'title': 'راهنما', 'value': '', 'color': 0xFF3498DB},
      {
        'icon': Icons.info,
        'title': 'درباره ما',
        'value': 'نسخه ۱.۰.۰',
        'color': 0xFF95A5A6,
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.settings, color: Color(0xFF4A90E2)),
                SizedBox(width: 8),
                Text(
                  'تنظیمات',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...settings.map(
            (setting) => ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(setting['color'] as int).withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  setting['icon'] as IconData,
                  color: Color(setting['color'] as int),
                  size: 18,
                ),
              ),
              title: Text(setting['title'] as String),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if ((setting['value'] as String).isNotEmpty)
                    Text(
                      setting['value'] as String,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                ],
              ),
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton.icon(
        onPressed: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('خروج از حساب'),
              content: const Text('آیا از خروج خود مطمئن هستید؟'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('انصراف'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'خروج',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );
          if (confirm == true) {
            await _supabase.logout(); // ← تغییر
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
          }
        },
        icon: const Icon(Icons.logout, color: Colors.red),
        label: const Text('خروج از حساب', style: TextStyle(color: Colors.red)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
