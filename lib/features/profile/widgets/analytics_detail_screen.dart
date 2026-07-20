// lib/features/profile/widgets/analytics_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:provider/provider.dart';
import '/services/supabase_service.dart';
import '/services/date_service.dart';
import '/features/arena/models/habit_model.dart';
import '/providers/sync_provider.dart';

class AnalyticsDetailScreen extends StatefulWidget {
  final String userId;

  const AnalyticsDetailScreen({super.key, required this.userId});

  @override
  State<AnalyticsDetailScreen> createState() => _AnalyticsDetailScreenState();
}

class _AnalyticsDetailScreenState extends State<AnalyticsDetailScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseService _supabase = SupabaseService();

  List<Habit> _habits = [];
  List<DateTime> _activeDays = [];
  DateTime _currentMonth = DateTime.now();
  int _totalActiveDays = 0;
  int _bestStreak = 0;
  Habit? _bestStreakHabit;
  bool _isLoading = true;
  String _calendarType = 'jalali';

  List<double> _successData = [0.2, 0.5, 0.3, 0.7, 0.4, 0.6, 0.1];

  int _currentSlide = 0;
  final CarouselSliderController _carouselController =
      CarouselSliderController();

  static const List<Color> _slideColors = [
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFFFFA500),
    Color(0xFFE74C3C),
  ];

  static const List<IconData> _slideIcons = [
    Icons.calendar_today,
    Icons.fitness_center,
    Icons.emoji_events,
    Icons.analytics,
  ];

  static const List<String> _slideTitles = [
    'تاریخچه کلی',
    'جزئیات عادت‌ها',
    'رکوردهای شما',
    'نمودار شکست',
  ];

  static const List<String> _slideSubtitles = [
    'مشاهده تقویم فعالیت‌های شما',
    'بررسی عملکرد عادت‌های روزانه',
    'بهترین دستاوردهای شما',
    'تحلیل روزهای کم‌انگیزه',
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

  // lib/features/profile/widgets/analytics_detail_screen.dart

  Future<void> _loadData() async {
    _clearCache();
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);

      if (syncProvider.habits.isNotEmpty) {
        _habits = syncProvider.habits;
      } else if (syncProvider.isOnline) {
        _habits = await _supabase.getHabits(widget.userId);
      } else {
        _habits = [];
      }

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
        } else {
          _activeDays = _getSampleActiveDays();
        }
      } catch (e) {
        _activeDays = _getSampleActiveDays();
      }

      _totalActiveDays = _activeDays.length;

      // ✅ محاسبه استریک‌ها (به صورت await)
      await _calculateBestStreak();
      await _calculateSuccessData();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _activeDays = _getSampleActiveDays();
      _totalActiveDays = _activeDays.length;

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<DateTime> _getSampleActiveDays() {
    final now = DateTime.now();
    final List<DateTime> days = [];
    for (int i = 0; i < 14; i++) {
      days.add(now.subtract(Duration(days: i)));
    }
    return days;
  }

  Map<String, List<bool>>? _cachedWeeklyStatus;
  DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(minutes: 1); // کش ۱ دقیقه

  // ✅ متد جدید برای محاسبه استریک هر عادت از دیتابیس
  Future<Map<String, int>> _calculateAllHabitsStreak() async {
    final Map<String, int> habitStreaks = {};

    if (_habits.isEmpty) return habitStreaks;

    try {
      // ✅ دریافت تمام تکمیل‌های عادت‌ها از دیتابیس
      final habitIds = _habits.map((h) => h.id).toList();
      final response = await _supabase.client
          .from('habit_completions')
          .select('habit_id, date')
          .eq('user_id', widget.userId)
          .inFilter('habit_id', habitIds)
          .order('date', ascending: false);

      // ✅ گروه‌بندی بر اساس habit_id
      final Map<String, List<DateTime>> habitCompletions = {};
      for (var item in response) {
        final habitId = item['habit_id'] as String;
        final date = DateTime.parse(item['date'] as String);
        habitCompletions.putIfAbsent(habitId, () => []).add(date);
      }

      // ✅ محاسبه استریک برای هر عادت
      for (var habit in _habits) {
        final completions = habitCompletions[habit.id] ?? [];
        if (completions.isEmpty) {
          habitStreaks[habit.id] = 0;
          continue;
        }

        // ✅ مرتب‌سازی تاریخ‌ها (نزولی)
        final sortedDates = completions.toList()
          ..sort((a, b) => b.compareTo(a));

        // ✅ محاسبه استریک جاری (از امروز به عقب)
        int streak = 0;
        DateTime checkDate = DateTime.now();

        for (var date in sortedDates) {
          // ✅ فقط تاریخ‌هایی که در محدوده هستند رو بررسی کن
          if (date.year == checkDate.year &&
              date.month == checkDate.month &&
              date.day == checkDate.day) {
            streak++;
            checkDate = checkDate.subtract(const Duration(days: 1));
          } else {
            break;
          }
        }

        habitStreaks[habit.id] = streak;
      }

      return habitStreaks;
    } catch (e) {
      print('❌ Error calculating habit streaks: $e');
      return {};
    }
  }

  // lib/features/profile/widgets/analytics_detail_screen.dart

  Future<void> _calculateBestStreak() async {
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

    // ✅ محاسبه استریک هر عادت از دیتابیس
    final habitStreaks = await _calculateAllHabitsStreak();

    // ✅ پیدا کردن عادت با بیشترین استریک
    _bestStreakHabit = null;
    int maxHabitStreak = 0;

    for (var habit in _habits) {
      if (!habit.isActive) continue;
      if (habit.challengeId != null || habit.questId != null) continue;

      final streak = habitStreaks[habit.id] ?? 0;

      // ✅ به‌روزرسانی bestStreak عادت در حافظه
      if (streak > habit.bestStreak) {
        // ✅ فقط در حافظه به‌روزرسانی کن (نه در دیتابیس)
        // این کار باعث میشه کارت درست نمایش داده بشه
        habit.bestStreak = streak;
      }

      if (streak > maxHabitStreak) {
        maxHabitStreak = streak;
        _bestStreakHabit = habit;
      }
    }

    print(
      '📊 Best habit: ${_bestStreakHabit?.title} with $maxHabitStreak days',
    );
    print('📊 All habit streaks: $habitStreaks');
  }

  Future<void> _calculateSuccessData() async {
    final now = DateTime.now();

    final List<double> successRates = List.filled(7, 0.0);
    final activeHabits = _habits.where((h) => h.isActive).toList();

    if (activeHabits.isEmpty) {
      setState(() => _successData = successRates);
      return;
    }

    // ✅ ساخت لیست ۲۸ روز گذشته (از امروز به عقب)
    final List<String> allDates = [];
    final List<DateTime> allDateTimes = [];

    for (int dayOffset = 27; dayOffset >= 0; dayOffset--) {
      final date = now.subtract(Duration(days: dayOffset));
      allDates.add(date.toIso8601String().split('T').first);
      allDateTimes.add(date);
    }

    print(
      '📊 Date range: ${allDates.first} to ${allDates.last} (${allDates.length} days)',
    );

    // ✅ دریافت همه تکمیل‌های عادت‌ها از دیتابیس
    final habitIds = activeHabits.map((h) => h.id).toList();
    Map<String, Set<String>> completions = {};

    try {
      final response = await _supabase.client
          .from('habit_completions')
          .select('habit_id, date')
          .eq('user_id', widget.userId)
          .inFilter('habit_id', habitIds);

      print('📊 Found ${response.length} completions');

      for (var item in response) {
        final habitId = item['habit_id'] as String;
        final date = item['date'] as String;
        if (allDates.contains(date)) {
          completions.putIfAbsent(habitId, () => {}).add(date);
        }
      }

      print(
        '📊 Completions by habit: ${completions.keys.length} habits have completions',
      );
    } catch (e) {
      print('❌ Error fetching completions: $e');
      _calculateSuccessDataFallback();
      return;
    }

    // ✅ دسته‌بندی تاریخ‌ها بر اساس روز هفته (شمسی)
    final Map<int, List<DateTime>> daysByWeekday = {
      for (int i = 0; i < 7; i++) i: [],
    };

    for (var date in allDateTimes) {
      // ✅ تشخیص روز هفته به شمسی
      final jalali = Jalali.fromDateTime(date);
      final weekday = jalali.weekDay - 1; // 0=شنبه, 1=یکشنبه, ...
      daysByWeekday[weekday]?.add(date);
    }

    // ✅ محاسبه نرخ موفقیت برای هر روز هفته
    for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
      int totalItems = 0;
      int completedItems = 0;

      // ✅ همه تاریخ‌هایی که این روز هفته هستند رو بررسی کن
      final dates = daysByWeekday[dayIndex] ?? [];

      for (var date in dates) {
        final dateStr = date.toIso8601String().split('T').first;

        // ✅ عادت‌های این روز
        for (var habit in activeHabits) {
          if (!habit.shouldDoOnDate(date)) continue;

          totalItems++;
          final isCompleted = completions[habit.id]?.contains(dateStr) ?? false;
          if (isCompleted) {
            completedItems++;
          }
        }
      }

      if (totalItems > 0) {
        successRates[dayIndex] = completedItems / totalItems;
        print(
          '📊 Day ${_getWeekDayName(dayIndex)}: $completedItems / $totalItems = ${(successRates[dayIndex] * 100).toInt()}%',
        );
      } else {
        successRates[dayIndex] = 0.0;
        print('📊 Day ${_getWeekDayName(dayIndex)}: No items');
      }
    }

    print('📊 Final success rates: $successRates');

    setState(() {
      _successData = successRates;
    });
  }

  // ✅ متد کمکی برای نام روز
  String _getWeekDayName(int index) {
    const days = [
      'شنبه',
      'یکشنبه',
      'دوشنبه',
      'سه‌شنبه',
      'چهارشنبه',
      'پنج‌شنبه',
      'جمعه',
    ];
    return days[index];
  }

  void _calculateSuccessDataFallback() {
    final now = DateTime.now();

    final List<double> successRates = List.filled(7, 0.0);
    final activeHabits = _habits.where((h) => h.isActive).toList();

    if (activeHabits.isEmpty) {
      setState(() => _successData = successRates);
      return;
    }

    // ✅ دسته‌بندی روزهای فعال بر اساس روز هفته (شمسی)
    final Map<int, int> dayCount = {for (int i = 0; i < 7; i++) i: 0};

    for (var date in _activeDays) {
      final jalali = Jalali.fromDateTime(date);
      final weekday = jalali.weekDay - 1;
      dayCount[weekday] = (dayCount[weekday] ?? 0) + 1;
    }

    // ✅ محاسبه نرخ موفقیت
    for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
      int totalItems = 0;
      int completedItems = 0;

      // ✅ ۴ هفته گذشته رو بررسی کن
      for (int week = 0; week < 4; week++) {
        // ✅ تاریخ رو از ۲۸ روز قبل محاسبه کن
        final date = now
            .subtract(Duration(days: 27))
            .add(Duration(days: (week * 7) + dayIndex));

        if (date.isAfter(now)) continue;

        for (var habit in activeHabits) {
          if (!habit.shouldDoOnDate(date)) continue;
          totalItems++;

          // ✅ بررسی کن که آیا این روز در _activeDays هست
          final isActiveDay = _activeDays.any(
            (d) =>
                d.year == date.year &&
                d.month == date.month &&
                d.day == date.day,
          );
          if (isActiveDay) completedItems++;
        }
      }

      if (totalItems > 0) {
        successRates[dayIndex] = completedItems / totalItems;
      }
    }

    setState(() {
      _successData = successRates;
    });
  }

  // ✅ کش برای عادت‌های تکمیل شده در تاریخ‌های خاص
  Map<String, Set<String>> _completionCache = {};

  DateTime _getWeekStart(DateTime date) {
    if (_calendarType == 'jalali') {
      final jalali = Jalali.fromDateTime(date);
      // ✅ شنبه = 1، بنابراین برای رسیدن به شنبه باید (weekDay - 1) روز کم کرد
      final daysToSubtract = jalali.weekDay - 1;
      print(
        '📅 Jalali weekDay: ${jalali.weekDay}, daysToSubtract: $daysToSubtract',
      );
      final result = date.subtract(Duration(days: daysToSubtract));
      print('📅 Week start (Jalali): $result');
      return result;
    } else {
      // ✅ میلادی: یکشنبه = 1، بنابراین باید (weekday % 7) روز کم کرد
      final daysToSubtract = date.weekday % 7;
      print(
        '📅 Gregorian weekday: ${date.weekday}, daysToSubtract: $daysToSubtract',
      );
      final result = date.subtract(Duration(days: daysToSubtract));
      print('📅 Week start (Gregorian): $result');
      return result;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      body: _isLoading
          ? _buildLoadingState()
          : Column(
              children: [
                // ✅ بخش هدر با راهنمای اسکرول
                _buildSlideHeader(),
                const SizedBox(height: 4),
                // ✅ نشانگر اسلایدها (دات‌ها)
                _buildSlideDots(),
                const SizedBox(height: 12),
                // ✅ اسلایدها
                Expanded(child: _buildCarouselSlides()),
                // ✅ فقط یک فضای کوچک برای فاصله از پایین
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  // ==================== اپبار ====================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'جزئیات پیشرفت',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      foregroundColor: const Color(0xFF1A1A2E),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, size: 22),
          onPressed: _loadData,
        ),
      ],
    );
  }

  // ==================== هدر اسلایدها ====================

  Widget _buildSlideHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // ✅ آیکون اسلاید فعلی
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _slideColors[_currentSlide].withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _slideIcons[_currentSlide],
              color: _slideColors[_currentSlide],
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          // ✅ عنوان و زیرعنوان
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _slideTitles[_currentSlide],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                Text(
                  _slideSubtitles[_currentSlide],
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          // ✅ نشانگر کشیدن به چپ و راست (راهنمای اسکرول)
          Row(
            children: [
              _buildSwipeHint(Icons.chevron_left, isLeft: true),
              _buildSwipeHint(Icons.chevron_right, isLeft: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeHint(IconData icon, {required bool isLeft}) {
    final isVisible =
        (isLeft && _currentSlide > 0) || (!isLeft && _currentSlide < 3);
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200, width: 0.5),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isVisible ? Colors.grey.shade600 : Colors.grey.shade200,
        ),
      ),
    );
  }

  // ==================== نشانگر اسلایدها (دات‌ها) ====================

  Widget _buildSlideDots() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          final isActive = index == _currentSlide;
          final color = _slideColors[index];

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 32 : 8,
            height: 4,
            decoration: BoxDecoration(
              color: isActive ? color : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }

  // ==================== Carousel Slider ====================

  Widget _buildCarouselSlides() {
    return CarouselSlider(
      carouselController: _carouselController,
      options: CarouselOptions(
        height: double.infinity,
        viewportFraction: 0.92,
        enlargeCenterPage: true,
        enableInfiniteScroll: false,
        padEnds: true,
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
    );
  }

  // ==================== اسلاید ۱: تاریخچه کلی ====================

  Widget _buildCalendarSlide() {
    final color = _slideColors[0];

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
      padding: const EdgeInsets.all(20),
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
        child: Column(
          children: [
            // کنترل‌های ماه
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
            const SizedBox(height: 12),
            // تقویم
            _buildCalendarGrid(color, daysInMonth, firstDayWeekday),
            const SizedBox(height: 16),
            // آمار
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
                    fontSize: 13,
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

  // ✅ متد بهینه‌شده برای دریافت وضعیت هفتگی همه عادت‌ها با یک کوئری
  Future<Map<String, List<bool>>> _getAllHabitsWeeklyStatus() async {
    // ✅ اگر کش معتبر است، از آن استفاده کن
    if (_cachedWeeklyStatus != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      return _cachedWeeklyStatus!;
    }

    final Map<String, List<bool>> result = {};
    final now = DateTime.now();
    final weekStart = _getWeekStart(now);

    if (_habits.isEmpty) return result;

    // ✅ ساخت لیست تاریخ‌های هفته
    final List<String> weekDates = [];
    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      weekDates.add(date.toIso8601String().split('T').first);
    }

    // ✅ گرفتن ID همه عادت‌ها
    final List<String> habitIds = _habits.map((h) => h.id).toList();

    // ✅ یک کوئری بزرگ برای همه عادت‌ها و همه روزها
    try {
      final response = await _supabase.client
          .from('habit_completions')
          .select('habit_id, date')
          .eq('user_id', widget.userId)
          .inFilter('habit_id', habitIds) // ✅ درست
          .inFilter('date', weekDates); // ✅ درست

      // ✅ ساخت یک Set از ترکیب habit_id + date برای جستجوی سریع
      final Set<String> completedSet = {};
      for (var item in response) {
        final habitId = item['habit_id'] as String;
        final date = item['date'] as String;
        completedSet.add('$habitId|$date');
      }

      // ✅ پر کردن نتیجه برای هر عادت
      for (var habit in _habits) {
        final List<bool> weekStatus = [];
        for (int i = 0; i < 7; i++) {
          final date = weekStart.add(Duration(days: i));
          final dateStr = date.toIso8601String().split('T').first;
          final key = '${habit.id}|$dateStr';
          weekStatus.add(completedSet.contains(key));
        }
        result[habit.id] = weekStatus;
      }

      // ✅ ذخیره در کش
      _cachedWeeklyStatus = result;
      _cacheTime = DateTime.now();

      return result;
    } catch (e) {
      // در صورت خطا، یک Map خالی برگردان
      for (var habit in _habits) {
        result[habit.id] = List.filled(7, false);
      }
      return result;
    }
  }

  // ✅ وقتی داده‌ها ریفرش می‌شن، کش رو پاک کن
  void _clearCache() {
    _cachedWeeklyStatus = null;
    _cacheTime = null;
  }

  Widget _buildHabitsDetailSlide() {
    final color = _slideColors[1];

    if (_habits.isEmpty) {
      return _buildEmptySlide(
        icon: Icons.fitness_center_outlined,
        title: 'هنوز عادتی ساخته نشده',
        subtitle: 'برای مشاهده جزئیات، ابتدا عادت‌های خود را ایجاد کنید',
        color: color,
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
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
        key: ValueKey(_habits.length), // ✅ ریفرش با تغییر تعداد عادت‌ها
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

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade300,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'خطا در بارگذاری داده‌ها',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      _clearCache();
                      setState(() {});
                    },
                    child: const Text('تلاش مجدد'),
                  ),
                ],
              ),
            );
          }

          final statusMap = snapshot.data ?? {};
          final weekDayLetters = _getWeekDayLetters();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                // هدر جدول
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const SizedBox(width: 48),
                      Expanded(
                        child: const Text(
                          'عادت',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      ...List.generate(7, (index) {
                        return Container(
                          width: 28,
                          alignment: Alignment.center,
                          child: Text(
                            weekDayLetters[index],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ..._habits.map((habit) {
                  final weekStatus =
                      statusMap[habit.id] ?? List.filled(7, false);
                  return _buildHabitDetailRow(habit, weekStatus);
                }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHabitDetailRow(Habit habit, List<bool> weekStatus) {
    final now = DateTime.now();
    final weekStart = _getWeekStart(now);
    final currentWeekdayIndex = _getCurrentWeekdayIndex();
    final weekDayLetters = _getWeekDayLetters();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Color(habit.iconColor).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(habit.iconColor).withValues(alpha: 0.12),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Color(habit.iconColor).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getIconData(habit.iconName),
              color: Color(habit.iconColor),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              habit.title,
              style: const TextStyle(
                fontSize: 12,
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
              margin: const EdgeInsets.only(left: 3),
              width: 26,
              height: 26,
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
                    fontSize: 7,
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

  Widget _buildEmptySlide({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(20),
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
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== اسلاید ۳: رکوردهای شما ====================

  // ✅ متد کمکی برای دریافت عادت‌های با بیشترین استریک (همه)
  List<({Habit habit, int streak})> _getHabitsWithBestStreak() {
    List<({Habit habit, int streak})> result = [];

    if (_habits.isEmpty) return result;

    // ✅ پیدا کردن حداکثر استریک
    int maxStreak = 0;
    for (var habit in _habits) {
      if (!habit.isActive) continue;
      if (habit.challengeId != null || habit.questId != null) continue;

      if (habit.bestStreak > maxStreak) {
        maxStreak = habit.bestStreak;
      }
    }

    // ✅ اگر هیچ عادتی استریک نداشت، خالی برگردان
    if (maxStreak == 0) return result;

    // ✅ پیدا کردن همه عادت‌هایی که بیشترین استریک رو دارند
    for (var habit in _habits) {
      if (!habit.isActive) continue;
      if (habit.challengeId != null || habit.questId != null) continue;

      if (habit.bestStreak == maxStreak) {
        result.add((habit: habit, streak: habit.bestStreak));
      }
    }

    return result;
  }
  // lib/features/profile/widgets/analytics_detail_screen.dart

  Widget _buildRecordsSlide() {
    final color = _slideColors[2];
    final bestDays = _getBestWeekDays();
    final topDay = bestDays.isNotEmpty ? bestDays.first : null;

    // ✅ دریافت همه عادت‌های با بیشترین استریک
    final bestHabits = _getHabitsWithBestStreak();
    final hasBestHabits = bestHabits.isNotEmpty && bestHabits.first.streak > 0;

    print('📊 Best habits count: ${bestHabits.length}');
    for (var item in bestHabits) {
      print('📊 Habit: ${item.habit.title}, streak: ${item.streak}');
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(20),
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
        child: Column(
          children: [
            // 1. طولانی‌ترین استریک کلی
            _buildRecordCard(
              gradient: const [Color(0xFFFF6B6B), Color(0xFFFFA500)],
              title: '🔥 طولانی‌ترین استریک',
              value: '$_bestStreak',
              unit: ' روز',
              subtitle: _bestStreak > 0
                  ? 'از ${_activeDays.length} روز فعالیت'
                  : 'هنوز استریکی ثبت نشده!',
              icon: Icons.local_fire_department,
            ),
            const SizedBox(height: 12),

            // 2. عادت‌های با بیشترین استریک - ✅ نمایش چند عادت
            _buildBestHabitsCard(
              gradient: const [Color(0xFF7C3AED), Color(0xFF2563EB)],
              title: '🏆 عادت‌های با بیشترین استریک',
              habits: bestHabits,
              maxStreak: bestHabits.isNotEmpty ? bestHabits.first.streak : 0,
              icon: Icons.emoji_events,
            ),
            const SizedBox(height: 12),

            // 3. بهترین روزهای هفته
            _buildRecordCard(
              gradient: const [Color(0xFF2ECC71), Color(0xFF27AE60)],
              title: '🌟 بهترین روزهای شما',
              value: topDay != null ? topDay['day'] : 'اطلاعاتی ثبت نشده',
              unit: topDay != null ? ' (${topDay['count']} روز)' : '',
              subtitle: topDay != null
                  ? '${bestDays.take(3).map((d) => '${d['day']}: ${d['count']} روز').join(' • ')}'
                  : '',
              icon: Icons.emoji_events,
              isTextValue: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard({
    required List<Color> gradient,
    required String title,
    required String value,
    required String unit,
    required String subtitle,
    required IconData icon,
    bool isTextValue = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ اگر مقدار خالی یا null بود، پیام مناسب نمایش بده
                    Text(
                      value.isNotEmpty ? value : 'اطلاعاتی وجود ندارد',
                      style: TextStyle(
                        fontSize: isTextValue ? 16 : 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: isTextValue ? 2 : 1,
                    ),
                    if (unit.isNotEmpty)
                      Text(
                        unit,
                        style: TextStyle(
                          fontSize: isTextValue ? 12 : 18,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // lib/features/profile/widgets/analytics_detail_screen.dart

  Widget _buildBestHabitsCard({
    required List<Color> gradient,
    required String title,
    required List<({Habit habit, int streak})> habits,
    required int maxStreak,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عنوان
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (maxStreak > 0) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$maxStreak روز',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // محتوا
          if (habits.isEmpty || maxStreak == 0) ...[
            Row(
              children: [
                Icon(
                  icon,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _habits.isNotEmpty
                        ? 'هنوز استریکی ثبت نشده'
                        : 'هنوز عادتی ساخته نشده',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // ✅ نمایش همه عادت‌های با بیشترین استریک
            ...habits.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    // آیکون عادت
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(
                          _getIconData(item.habit.iconName),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // عنوان عادت
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.habit.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          Text(
                            '${item.streak} روز پیاپی',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // تعداد روزهای استریک (آیکون کوچک)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${item.streak}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),

            // ✅ اگر بیش از ۵ عادت با بیشترین استریک وجود داره، بقیه رو جمع کن
            if (habits.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'و ${habits.length - 5} عادت دیگر...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ==================== اسلاید ۴: نمودار شکست ====================

  // lib/features/profile/widgets/analytics_detail_screen.dart

  Widget _buildFailureChartSlide() {
    final color = _slideColors[3];
    const weekDays = [
      'شنبه',
      'یک‌شنبه',
      'دوشنبه',
      'سه‌شنبه',
      'چهارشنبه',
      'پنج‌شنبه',
      'جمعه',
    ];

    final maxValue = _successData.reduce((a, b) => a > b ? a : b);

    int bestDayIndex = 0;
    int worstDayIndex = 0;
    double bestDayValue = _successData[0];
    double worstDayValue = _successData[0];

    for (int i = 1; i < _successData.length; i++) {
      if (_successData[i] > bestDayValue) {
        bestDayValue = _successData[i];
        bestDayIndex = i;
      }
      if (_successData[i] < worstDayValue) {
        worstDayValue = _successData[i];
        worstDayIndex = i;
      }
    }

    final hasData = _activeDays.isNotEmpty && maxValue > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
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
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // هدر
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '📊 عملکرد روزهای هفته',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                if (hasData)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 12,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${(maxValue * 100).toInt()}% موفقیت',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              hasData
                  ? 'بر اساس ${_activeDays.length} روز فعالیت شما'
                  : 'هنوز اطلاعات کافی برای تحلیل وجود ندارد',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),

            if (hasData) ...[
              // ✅ نمودار با ارتفاع کمتر و محاسبه دقیق
              SizedBox(
                height: 160,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (index) {
                    final value = _successData[index];

                    // ✅ محاسبه دقیق ارتفاع (حداکثر 70% ارتفاع موجود)
                    final double maxHeight = 160 - 50; // 50 پیکسل برای متن‌ها
                    final double minHeight = 8;
                    final double height = maxValue > 0
                        ? minHeight + (value / maxValue) * maxHeight * 0.7
                        : minHeight;

                    final bool isBestDay =
                        value == bestDayValue && bestDayValue > 0;
                    final bool isZero = value == 0;

                    return Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min, // ✅ مهم
                        children: [
                          // درصد
                          Text(
                            '${(value * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: isBestDay
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isBestDay
                                  ? Colors.green
                                  : isZero
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 3),

                          // ✅ ستون با ارتفاع دقیق
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: 28,
                            height: height.clamp(minHeight, maxHeight),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isBestDay
                                    ? [Colors.green.shade400, Colors.green]
                                    : isZero
                                    ? [
                                        Colors.grey.shade300,
                                        Colors.grey.shade400,
                                      ]
                                    : [color, color.withValues(alpha: 0.6)],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: isBestDay
                                  ? [
                                      BoxShadow(
                                        color: Colors.green.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isBestDay
                                ? const Icon(
                                    Icons.star,
                                    color: Colors.white,
                                    size: 10,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 4),

                          // نام روز
                          Text(
                            weekDays[index],
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: isBestDay
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isBestDay
                                  ? Colors.green
                                  : isZero
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 12),

              // ✅ تحلیل
              _buildSuccessAnalysisCard(
                color: color,
                weekDays: weekDays,
                bestDayIndex: bestDayIndex,
                bestDayValue: bestDayValue,
                worstDayIndex: worstDayIndex,
                worstDayValue: worstDayValue,
              ),
            ] else ...[
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      size: 48,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'برای مشاهده نمودار عملکرد، حداقل چند روز فعالیت داشته باشید',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
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
  // lib/features/profile/widgets/analytics_detail_screen.dart

  Widget _buildSuccessAnalysisCard({
    required Color color,
    required List<String> weekDays,
    required int bestDayIndex,
    required double bestDayValue,
    required int worstDayIndex,
    required double worstDayValue,
  }) {
    final bestPercent = (bestDayValue * 100).toInt();
    final worstPercent = (worstDayValue * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // ✅ مهم
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.arrow_upward,
                  color: Colors.green,
                  size: 14,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '🌟 روز ${weekDays[bestDayIndex]} با $bestPercent% موفقیت',
                  style: TextStyle(fontSize: 11, color: Colors.green.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.arrow_downward,
                  color: Colors.orange,
                  size: 14,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '📉 روز ${weekDays[worstDayIndex]} با $worstPercent% کمترین موفقیت',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb, color: Color(0xFF2563EB), size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '💪 روز ${weekDays[worstDayIndex]} را با برنامه‌ریزی بهتر شروع کنید!',
                    style: TextStyle(
                      fontSize: 10,
                      color: const Color(0xFF2563EB).withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (bestDayIndex == worstDayIndex && bestDayValue > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.info, size: 12, color: Colors.blue),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'عملکرد شما در همه روزها یکسان است! 🎯',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue.shade700,
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
  // ==================== حالت لودینگ ====================

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF2563EB)),
          SizedBox(height: 16),
          Text(
            'در حال بارگذاری...',
            style: TextStyle(color: Color(0xFF6B7280)),
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
