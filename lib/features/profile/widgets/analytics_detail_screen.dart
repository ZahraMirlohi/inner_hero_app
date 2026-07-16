// lib/features/profile/widgets/analytics_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:provider/provider.dart'; // ✅ اضافه کردن import Provider
import '/services/supabase_service.dart';
import '/services/date_service.dart';
import '/features/arena/models/habit_model.dart';
import '/providers/sync_provider.dart'; // ✅ اضافه کردن import SyncProvider

class AnalyticsDetailScreen extends StatefulWidget {
  final String userId;

  const AnalyticsDetailScreen({super.key, required this.userId});

  @override
  State<AnalyticsDetailScreen> createState() => _AnalyticsDetailScreenState();
}

class _AnalyticsDetailScreenState extends State<AnalyticsDetailScreen> {
  final SupabaseService _supabase = SupabaseService();

  List<Habit> _habits = [];
  List<DateTime> _activeDays = [];
  DateTime _currentMonth = DateTime.now();
  int _totalActiveDays = 0;
  int _bestStreak = 0;
  Habit? _bestStreakHabit;
  bool _isLoading = true;
  String _calendarType = 'jalali';

  List<double> _failureData = [0.2, 0.5, 0.3, 0.7, 0.4, 0.6, 0.1];

  int _currentSlide = 0;
  final CarouselSliderController _carouselController =
      CarouselSliderController();

  final List<Map<String, dynamic>> _slides = const [
    {'icon': Icons.calendar_today, 'title': 'تاریخچه کلی', 'color': 0xFF2563EB},
    {
      'icon': Icons.fitness_center,
      'title': 'جزئیات عادت‌ها',
      'color': 0xFF7C3AED,
    },
    {'icon': Icons.emoji_events, 'title': 'رکوردهای شما', 'color': 0xFFFFA500},
    {'icon': Icons.analytics, 'title': 'نمودار شکست', 'color': 0xFFE74C3C},
  ];

  @override
  void initState() {
    super.initState();
    _loadCalendarType();
    _loadData();
  }

  Future<void> _loadCalendarType() async {
    final calendarType = await DateService.getCalendarType();
    if (mounted) {
      setState(() {
        _calendarType = calendarType;
      });
    }
  }

  // ==================== بارگذاری داده‌ها با پشتیبانی از آفلاین ====================

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // ✅ ابتدا از SyncProvider (LocalStorage) بخوان
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);

      if (syncProvider.habits.isNotEmpty) {
        _habits = syncProvider.habits;
        print('📊 Loaded ${_habits.length} habits from LOCAL storage');
      } else if (syncProvider.isOnline) {
        _habits = await _supabase.getHabits(widget.userId);
        print('📊 Loaded ${_habits.length} habits from SERVER');
      } else {
        _habits = [];
        print('⚠️ Offline and no local habits data');
      }

      // ✅ دریافت روزهای فعال - با fallback
      try {
        final activityResponse = await _supabase.client
            .from('user_daily_activity')
            .select(
              'activity_date, habits_completed, tasks_completed, xp_earned',
            )
            .eq('user_id', widget.userId)
            .eq('is_active', true)
            .order('activity_date', ascending: false);

        if (activityResponse.isNotEmpty) {
          _activeDays = activityResponse
              .map((d) => DateTime.parse(d['activity_date']))
              .toList();
          print('📊 Found ${_activeDays.length} active days');
        } else {
          // ✅ اگر داده‌ای نبود، از داده‌های نمونه استفاده کن
          _activeDays = _getSampleActiveDays();
          print('📊 Using ${_activeDays.length} sample days');
        }
      } catch (e) {
        print('⚠️ Error getting activity data: $e');
        _activeDays = _getSampleActiveDays();
      }

      _totalActiveDays = _activeDays.length;
      _calculateBestStreak();
      _calculateRealFailureData();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading analytics: $e');
      // ✅ در صورت خطا، داده‌های نمونه نمایش بده
      _activeDays = _getSampleActiveDays();
      _totalActiveDays = _activeDays.length;

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ✅ داده‌های نمونه برای حالت آفلاین یا خطا
  List<DateTime> _getSampleActiveDays() {
    final now = DateTime.now();
    final List<DateTime> days = [];
    for (int i = 0; i < 14; i++) {
      days.add(now.subtract(Duration(days: i)));
    }
    return days;
  }

  // ==================== محاسبه بهترین استریک ====================

  void _calculateBestStreak() {
    if (_activeDays.isEmpty) return;

    final sortedDays = List<DateTime>.from(_activeDays)..sort();
    int currentStreak = 1;
    int maxStreak = 1;

    for (int i = 1; i < sortedDays.length; i++) {
      final diff = sortedDays[i].difference(sortedDays[i - 1]).inDays;
      if (diff == 1) {
        currentStreak++;
        if (currentStreak > maxStreak) {
          maxStreak = currentStreak;
        }
      } else {
        currentStreak = 1;
      }
    }

    _bestStreak = maxStreak;

    // پیدا کردن عادتی که بیشترین استریک را داشته
    _bestStreakHabit = null;
    int maxHabitStreak = 0;

    for (var habit in _habits) {
      if (habit.bestStreak > maxHabitStreak) {
        maxHabitStreak = habit.bestStreak;
        _bestStreakHabit = habit;
      }
    }

    if (_bestStreakHabit == null && _bestStreak > 0 && _habits.isNotEmpty) {
      _bestStreakHabit = _habits.first;
    }
  }

  // ==================== محاسبه داده‌های شکست ====================

  void _calculateRealFailureData() {
    final now = DateTime.now();
    final weekStart = _getWeekStart(now);

    final List<int> weekDayCounts = List.filled(7, 0);
    final List<int> weekDayTotals = List.filled(7, 0);

    for (int week = 0; week < 4; week++) {
      for (int day = 0; day < 7; day++) {
        final date = weekStart.subtract(Duration(days: (week * 7) - day));
        final isActive = _activeDays.any(
          (d) =>
              d.year == date.year && d.month == date.month && d.day == date.day,
        );

        weekDayTotals[day]++;
        if (isActive) {
          weekDayCounts[day]++;
        }
      }
    }

    final List<double> failureData = List.filled(7, 0.0);
    for (int i = 0; i < 7; i++) {
      if (weekDayTotals[i] > 0) {
        failureData[i] = 1.0 - (weekDayCounts[i] / weekDayTotals[i]);
      }
    }

    setState(() {
      _failureData = failureData;
    });
  }

  // ==================== متدهای کمکی تقویم ====================

  DateTime _getWeekStart(DateTime date) {
    if (_calendarType == 'jalali') {
      final jalali = Jalali.fromDateTime(date);
      final daysToSubtract = jalali.weekDay - 1;
      return date.subtract(Duration(days: daysToSubtract));
    } else {
      final daysToSubtract = date.weekday % 7;
      return date.subtract(Duration(days: daysToSubtract));
    }
  }

  int _getCurrentWeekdayIndex() {
    if (_calendarType == 'jalali') {
      final jalaliNow = Jalali.now();
      return jalaliNow.weekDay - 1;
    } else {
      return DateTime.now().weekday % 7;
    }
  }

  List<String> _getWeekDayLetters() {
    if (_calendarType == 'jalali') {
      return ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
    } else {
      return ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    }
  }

  // ==================== دریافت بهترین روزهای هفته ====================

  List<Map<String, dynamic>> _getBestWeekDays() {
    const weekDays = [
      'شنبه',
      'یک‌شنبه',
      'دوشنبه',
      'سه‌شنبه',
      'چهارشنبه',
      'پنج‌شنبه',
      'جمعه',
    ];
    final List<Map<String, dynamic>> result = [];

    final Map<int, int> dayActivityCount = {};
    for (int i = 0; i < 7; i++) {
      dayActivityCount[i] = 0;
    }

    for (var date in _activeDays) {
      final jalali = Jalali.fromDateTime(date);
      final weekday = jalali.weekDay - 1;
      dayActivityCount[weekday] = (dayActivityCount[weekday] ?? 0) + 1;
    }

    final sortedDays = dayActivityCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (var entry in sortedDays) {
      if (entry.value > 0) {
        result.add({
          'day': weekDays[entry.key],
          'count': entry.value,
          'index': entry.key,
        });
      }
    }

    return result;
  }

  // ==================== متدهای UI ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('جزئیات پیشرفت'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A2E),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            )
          : Column(
              children: [
                _buildSlideIndicator(),
                const SizedBox(height: 12),
                Expanded(
                  child: CarouselSlider(
                    carouselController: _carouselController,
                    options: CarouselOptions(
                      height: double.infinity,
                      viewportFraction: 0.92,
                      enlargeCenterPage: true,
                      enableInfiniteScroll: false,
                      onPageChanged: (index, reason) {
                        setState(() {
                          _currentSlide = index;
                        });
                      },
                    ),
                    items: [
                      _buildCalendarSlide(),
                      _buildHabitsDetailSlide(),
                      _buildRecordsSlide(),
                      _buildFailureChartSlide(),
                    ],
                  ),
                ),
                _buildNavigationButtons(),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  // ==================== اسلاید ۱: تاریخچه کلی ====================

  Widget _buildCalendarSlide() {
    final color = Color(_slides[0]['color'] as int);

    String monthName;
    String yearText;
    int daysInMonth;
    int firstDayWeekday;

    if (_calendarType == 'jalali') {
      final jalali = Jalali.fromDateTime(_currentMonth);
      monthName = _getJalaliMonthName(jalali.month);
      yearText = jalali.year.toString();
      daysInMonth = _getJalaliDaysInMonth(jalali.year, jalali.month);
      firstDayWeekday = _getJalaliWeekday(jalali.year, jalali.month, 1);
    } else {
      monthName = _getGregorianMonthName(_currentMonth.month);
      yearText = _currentMonth.year.toString();
      daysInMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month + 1,
        0,
      ).day;
      firstDayWeekday =
          DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      if (_calendarType == 'jalali') {
                        final jalali = Jalali.fromDateTime(_currentMonth);
                        int newMonth = jalali.month - 1;
                        int newYear = jalali.year;
                        if (newMonth < 1) {
                          newMonth = 12;
                          newYear--;
                        }
                        _currentMonth = Jalali(
                          newYear,
                          newMonth,
                          1,
                        ).toDateTime();
                      } else {
                        _currentMonth = DateTime(
                          _currentMonth.year,
                          _currentMonth.month - 1,
                          1,
                        );
                      }
                    });
                  },
                  icon: const Icon(Icons.chevron_left),
                  color: color,
                ),
                Text(
                  '$monthName $yearText',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      if (_calendarType == 'jalali') {
                        final jalali = Jalali.fromDateTime(_currentMonth);
                        int newMonth = jalali.month + 1;
                        int newYear = jalali.year;
                        if (newMonth > 12) {
                          newMonth = 1;
                          newYear++;
                        }
                        _currentMonth = Jalali(
                          newYear,
                          newMonth,
                          1,
                        ).toDateTime();
                      } else {
                        _currentMonth = DateTime(
                          _currentMonth.year,
                          _currentMonth.month + 1,
                          1,
                        );
                      }
                    });
                  },
                  icon: const Icon(Icons.chevron_right),
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildCalendarGrid(color, daysInMonth, firstDayWeekday),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'روزهای فعال',
                  '$_totalActiveDays',
                  Icons.calendar_today,
                  color,
                ),
                _buildStatItem(
                  'کل عادت‌ها',
                  '${_habits.length}',
                  Icons.fitness_center,
                  color,
                ),
                _buildStatItem(
                  'بهترین استریک',
                  '$_bestStreak',
                  Icons.local_fire_department,
                  color,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== متدهای کمکی تقویم ====================

  String _getJalaliMonthName(int month) {
    const months = [
      'فروردین',
      'اردیبهشت',
      'خرداد',
      'تیر',
      'مرداد',
      'شهریور',
      'مهر',
      'آبان',
      'آذر',
      'دی',
      'بهمن',
      'اسفند',
    ];
    return months[month - 1];
  }

  String _getGregorianMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  int _getJalaliDaysInMonth(int year, int month) {
    if (month <= 6) return 31;
    if (month <= 11) return 30;
    final date = Jalali(year, month, 1);
    return (date.isLeapYear == true) ? 30 : 29;
  }

  int _getJalaliWeekday(int year, int month, int day) {
    final jalali = Jalali(year, month, day);
    return jalali.weekDay - 1;
  }

  // ==================== ویجت‌های کمکی ====================

  Widget _buildCalendarGrid(Color color, int daysInMonth, int firstDayWeekday) {
    final weekDays = _calendarType == 'jalali'
        ? ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج']
        : ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    final now = DateTime.now();

    return Column(
      children: [
        Row(
          children: weekDays.map((day) {
            return Expanded(
              child: Center(
                child: Text(
                  day,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
          ),
          itemCount: 42,
          itemBuilder: (context, index) {
            final day = index - firstDayWeekday + 1;
            if (day < 1 || day > daysInMonth) {
              return const SizedBox();
            }

            DateTime date;
            if (_calendarType == 'jalali') {
              final jalali = Jalali.fromDateTime(_currentMonth);
              date = Jalali(jalali.year, jalali.month, day).toDateTime();
            } else {
              date = DateTime(_currentMonth.year, _currentMonth.month, day);
            }

            final isToday = _isToday(date);
            final isActive = _activeDays.any(
              (d) =>
                  d.year == date.year &&
                  d.month == date.month &&
                  d.day == date.day,
            );
            final isFuture = date.isAfter(now);

            return Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? color
                    : isToday
                    ? color.withValues(alpha: 0.2)
                    : Colors.transparent,
                border: isToday && !isActive
                    ? Border.all(color: color, width: 2)
                    : null,
              ),
              child: Center(
                child: Text(
                  day.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive
                        ? Colors.white
                        : isToday
                        ? color
                        : isFuture
                        ? Colors.grey.shade300
                        : const Color(0xFF1A1A2E),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    if (_calendarType == 'jalali') {
      final todayJalali = Jalali.fromDateTime(now);
      final dateJalali = Jalali.fromDateTime(date);
      return todayJalali.year == dateJalali.year &&
          todayJalali.month == dateJalali.month &&
          todayJalali.day == dateJalali.day;
    } else {
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }

  // ==================== اسلاید ۲: جزئیات عادت‌ها ====================

  Future<Map<String, List<bool>>> _getAllHabitsWeeklyStatus() async {
    final Map<String, List<bool>> result = {};
    final now = DateTime.now();
    final weekStart = _getWeekStart(now);

    for (var habit in _habits) {
      final List<bool> weekStatus = [];
      for (int i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        final isCompleted = await _supabase.isHabitCompletedOnDate(
          habit.id,
          widget.userId,
          date,
        );
        weekStatus.add(isCompleted);
      }
      result[habit.id] = weekStatus;
    }

    return result;
  }

  Widget _buildHabitsDetailSlide() {
    final color = Color(_slides[1]['color'] as int);

    if (_habits.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.fitness_center_outlined,
                size: 64,
                color: Color(0xFFD1D5DB),
              ),
              SizedBox(height: 16),
              Text(
                'هنوز عادتی ساخته نشده',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FutureBuilder<Map<String, List<bool>>>(
        future: _getAllHabitsWeeklyStatus(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: Color(0xFF2563EB)),
              ),
            );
          }

          final statusMap = snapshot.data ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: _habits.map((habit) {
                final weekStatus = statusMap[habit.id] ?? List.filled(7, false);
                return _buildHabitDetailRowWithData(habit, weekStatus);
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHabitDetailRowWithData(Habit habit, List<bool> weekStatus) {
    final now = DateTime.now();
    final weekStart = _getWeekStart(now);
    final currentWeekdayIndex = _getCurrentWeekdayIndex();
    final weekDayLetters = _getWeekDayLetters();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color(habit.iconColor).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(habit.iconColor).withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color(habit.iconColor).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getIconData(habit.iconName),
              color: Color(habit.iconColor),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              habit.title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ...List.generate(7, (index) {
            final date = weekStart.add(Duration(days: index));
            final isActive = weekStatus[index];
            final isToday = index == currentWeekdayIndex;

            Color circleColor;
            if (isActive) {
              circleColor = const Color(0xFF4CAF50);
            } else {
              final shouldDo = habit.shouldDoOnDate(date);
              if (shouldDo) {
                circleColor = const Color(0xFFF44336);
              } else {
                circleColor = Colors.grey.shade300;
              }
            }

            final bool isTodayAndNotDone =
                isToday && !isActive && habit.shouldDoOnDate(date);

            return Container(
              margin: const EdgeInsets.only(left: 4),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: circleColor,
                border: isTodayAndNotDone
                    ? Border.all(color: const Color(0xFF2563EB), width: 2)
                    : null,
              ),
              child: Center(
                child: Text(
                  weekDayLetters[index],
                  style: TextStyle(
                    fontSize: 8,
                    color: circleColor == Colors.grey.shade300
                        ? Colors.grey.shade500
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==================== اسلاید ۳: رکوردهای شما ====================

  Widget _buildRecordsSlide() {
    final color = Color(_slides[2]['color'] as int);
    final bestDays = _getBestWeekDays();
    final topDay = bestDays.isNotEmpty ? bestDays.first : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. طولانی‌ترین استریک
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFFA500)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🔥 طولانی‌ترین استریک',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '$_bestStreak',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        ' روز',
                        style: TextStyle(fontSize: 20, color: Colors.white),
                      ),
                    ],
                  ),
                  if (_bestStreak > 0)
                    Text(
                      'از ${_activeDays.length} روز فعالیت',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    )
                  else
                    const Text(
                      'هنوز استریکی ثبت نشده!',
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. عادت با بیشترین استریک
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🏆 عادت با بیشترین استریک',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_bestStreakHabit != null &&
                      _bestStreakHabit!.bestStreak > 0) ...[
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getIconData(_bestStreakHabit!.iconName),
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _bestStreakHabit!.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${_bestStreakHabit!.bestStreak} روز پیاپی',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ] else if (_bestStreak > 0) ...[
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.fitness_center,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'استریک کلی',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${_bestStreak} روز فعالیت پیاپی',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const Text(
                      'هنوز عادتی ساخته نشده',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. بهترین روزهای هفته
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🌟 بهترین روزهای شما',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (topDay != null) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${topDay['day']}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${topDay['count']} روز فعال',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: bestDays.take(3).map((day) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${day['day']}: ${day['count']} روز',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ] else ...[
                    const Text(
                      'هنوز اطلاعاتی ثبت نشده',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== اسلاید ۴: نمودار شکست ====================

  Widget _buildFailureChartSlide() {
    final color = Color(_slides[3]['color'] as int);
    const weekDays = [
      'شنبه',
      'یک‌شنبه',
      'دوشنبه',
      'سه‌شنبه',
      'چهارشنبه',
      'پنج‌شنبه',
      'جمعه',
    ];
    final maxValue = _failureData.reduce((a, b) => a > b ? a : b);

    int maxFailureIndex = 0;
    int minFailureIndex = 0;
    double maxFailure = _failureData[0];
    double minFailure = _failureData[0];

    for (int i = 1; i < _failureData.length; i++) {
      if (_failureData[i] > maxFailure) {
        maxFailure = _failureData[i];
        maxFailureIndex = i;
      }
      if (_failureData[i] < minFailure) {
        minFailure = _failureData[i];
        minFailureIndex = i;
      }
    }

    final hasData = _activeDays.isNotEmpty && maxValue > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 روزهای شکست بیشتر',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasData
                  ? 'بر اساس ${_activeDays.length} روز فعالیت شما'
                  : 'هنوز اطلاعات کافی برای تحلیل وجود ندارد',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 20),

            if (hasData) ...[
              SizedBox(
                height: 200,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (index) {
                    final value = _failureData[index];
                    final double height = maxValue > 0
                        ? (value / maxValue) * 150
                        : 0.0;
                    final bool isHighest =
                        value == maxFailure && maxFailure > 0;
                    final bool isLowest =
                        value == minFailure && minFailure >= 0;

                    return Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (value > 0)
                            Text(
                              '${(value * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isHighest
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isHighest
                                    ? color
                                    : isLowest
                                    ? Colors.green
                                    : const Color(0xFF6B7280),
                              ),
                            ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 30,
                            height: height,
                            decoration: BoxDecoration(
                              color: isHighest
                                  ? color
                                  : isLowest
                                  ? Colors.green
                                  : color.withValues(alpha: 0.4),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            weekDays[index],
                            style: TextStyle(
                              fontSize: 10,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),

              // تحلیل و نتیجه‌گیری
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.arrow_upward, color: color, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'روز ${weekDays[maxFailureIndex]} با ${(maxFailure * 100).toInt()}% بیشترین شکست را داشته‌اید.',
                            style: TextStyle(
                              fontSize: 12,
                              color: color.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.arrow_downward,
                          color: Colors.green,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'روز ${weekDays[minFailureIndex]} با ${(minFailure * 100).toInt()}% کمترین شکست را داشته‌اید (بیشترین موفقیت).',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lightbulb,
                            color: Color(0xFF2563EB),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'پیشنهاد: روز ${weekDays[maxFailureIndex]} را با برنامه‌ریزی بهتر و عادت‌های کوچک‌تر شروع کنید 💪',
                              style: TextStyle(
                                fontSize: 11,
                                color: const Color(
                                  0xFF2563EB,
                                ).withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      size: 64,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'برای مشاهده نمودار شکست، حداقل چند روز فعالیت داشته باشید',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== ناوبری اسلایدها ====================

  Widget _buildSlideIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_slides.length, (index) {
          final isActive = index == _currentSlide;
          final color = Color(_slides[index]['color'] as int);

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 32 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? color : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              if (_currentSlide > 0) {
                _carouselController.animateToPage(_currentSlide - 1);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _currentSlide > 0
                    ? const Color(0xFF2563EB)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.arrow_back,
                    size: 18,
                    color: _currentSlide > 0
                        ? Colors.white
                        : Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'قبلی',
                    style: TextStyle(
                      color: _currentSlide > 0
                          ? Colors.white
                          : Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Text(
            _slides[_currentSlide]['title'] as String,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(_slides[_currentSlide]['color'] as int),
            ),
          ),
          GestureDetector(
            onTap: () {
              if (_currentSlide < _slides.length - 1) {
                _carouselController.animateToPage(_currentSlide + 1);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _currentSlide < _slides.length - 1
                    ? const Color(0xFF2563EB)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    'بعدی',
                    style: TextStyle(
                      color: _currentSlide < _slides.length - 1
                          ? Colors.white
                          : Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: _currentSlide < _slides.length - 1
                        ? Colors.white
                        : Colors.grey.shade500,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== متدهای کمکی ====================

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'fitness_center':
        return Icons.fitness_center;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'book':
        return Icons.book;
      case 'science':
        return Icons.science;
      case 'restaurant':
        return Icons.restaurant;
      case 'bedtime':
        return Icons.bedtime;
      case 'water_drop':
        return Icons.water_drop;
      case 'directions_walk':
        return Icons.directions_walk;
      case 'run_circle':
        return Icons.run_circle;
      case 'emoji_events':
        return Icons.emoji_events;
      default:
        return Icons.fitness_center;
    }
  }
}
