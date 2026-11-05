// lib/features/profile/screens/analytics_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:provider/provider.dart';
import '/services/supabase_service.dart';
import '/features/arena/models/habit_model.dart';
import '/providers/sync_provider.dart';
import '/providers/theme_provider.dart';
import '/providers/calendar_provider.dart';
import '/core/app_palette.dart';
import '/l10n/app_strings.dart';

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

  // آمار امروز (کارت مشکی بالای صفحه)
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);
  int _tHabitsDone = 0, _tHabitsTotal = 0;
  int _tTasksDone = 0, _tTasksTotal = 0;
  int _tChDone = 0, _tChTotal = 0;
  int _tQuDone = 0, _tQuTotal = 0;

  List<double> _successData = [0.2, 0.5, 0.3, 0.7, 0.4, 0.6, 0.1];

  int _currentSlide = 0;
  final CarouselSliderController _carouselController =
      CarouselSliderController();

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
    _loadData();
  }

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
    // داده‌ی نمونه نشان نمی‌دهیم؛ بدون فعالیت یعنی خالی
    return <DateTime>[];
  }

  Map<String, List<bool>>? _cachedWeeklyStatus;
  DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(minutes: 1);

  Future<Map<String, int>> _calculateAllHabitsStreak() async {
    final Map<String, int> habitStreaks = {};

    if (_habits.isEmpty) return habitStreaks;

    try {
      final habitIds = _habits.map((h) => h.id).toList();
      final response = await _supabase.client
          .from('habit_completions')
          .select('habit_id, date')
          .eq('user_id', widget.userId)
          .inFilter('habit_id', habitIds)
          .order('date', ascending: false);

      final Map<String, List<DateTime>> habitCompletions = {};
      for (var item in response) {
        final habitId = item['habit_id'] as String;
        final date = DateTime.parse(item['date'] as String);
        habitCompletions.putIfAbsent(habitId, () => []).add(date);
      }

      for (var habit in _habits) {
        final completions = habitCompletions[habit.id] ?? [];
        if (completions.isEmpty) {
          habitStreaks[habit.id] = 0;
          continue;
        }

        final sortedDates = completions.toList()
          ..sort((a, b) => b.compareTo(a));

        int streak = 0;
        DateTime checkDate = DateTime.now();

        for (var date in sortedDates) {
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
      return {};
    }
  }

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

    final habitStreaks = await _calculateAllHabitsStreak();

    _bestStreakHabit = null;
    int maxHabitStreak = 0;

    for (var habit in _habits) {
      if (!habit.isActive) continue;
      if (habit.challengeId != null || habit.questId != null) continue;

      final streak = habitStreaks[habit.id] ?? 0;

      if (streak > habit.bestStreak) {
        habit.bestStreak = streak;
      }

      if (streak > maxHabitStreak) {
        maxHabitStreak = streak;
        _bestStreakHabit = habit;
      }
    }
  }

  Future<void> _calculateSuccessData() async {
    final now = DateTime.now();

    final List<double> successRates = List.filled(7, 0.0);
    final activeHabits = _habits.where((h) => h.isActive).toList();

    if (activeHabits.isEmpty) {
      setState(() => _successData = successRates);
      return;
    }

    final List<String> allDates = [];
    final List<DateTime> allDateTimes = [];

    for (int dayOffset = 27; dayOffset >= 0; dayOffset--) {
      final date = now.subtract(Duration(days: dayOffset));
      allDates.add(date.toIso8601String().split('T').first);
      allDateTimes.add(date);
    }

    final habitIds = activeHabits.map((h) => h.id).toList();
    Map<String, Set<String>> completions = {};

    try {
      final response = await _supabase.client
          .from('habit_completions')
          .select('habit_id, date')
          .eq('user_id', widget.userId)
          .inFilter('habit_id', habitIds);

      for (var item in response) {
        final habitId = item['habit_id'] as String;
        final date = item['date'] as String;
        if (allDates.contains(date)) {
          completions.putIfAbsent(habitId, () => {}).add(date);
        }
      }
    } catch (e) {
      _calculateSuccessDataFallback();
      return;
    }

    final Map<int, List<DateTime>> daysByWeekday = {
      for (int i = 0; i < 7; i++) i: [],
    };

    for (var date in allDateTimes) {
      final jalali = Jalali.fromDateTime(date);
      final weekday = jalali.weekDay - 1;
      daysByWeekday[weekday]?.add(date);
    }

    for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
      int totalItems = 0;
      int completedItems = 0;

      final dates = daysByWeekday[dayIndex] ?? [];

      for (var date in dates) {
        final dateStr = date.toIso8601String().split('T').first;

        for (var habit in activeHabits) {
          if (!habit.shouldDoOnDate(date)) continue;
          // روزهای قبل از ساخته شدن عادت شکست حساب نمی‌شوند
          final created = DateTime(habit.createdAt.year, habit.createdAt.month,
              habit.createdAt.day);
          if (DateTime(date.year, date.month, date.day).isBefore(created)) {
            continue;
          }

          totalItems++;
          final isCompleted = completions[habit.id]?.contains(dateStr) ?? false;
          if (isCompleted) {
            completedItems++;
          }
        }
      }

      if (totalItems > 0) {
        successRates[dayIndex] = completedItems / totalItems;
      } else {
        successRates[dayIndex] = 0.0;
      }
    }

    setState(() {
      _successData = successRates;
    });
  }

  void _calculateSuccessDataFallback() {
    final now = DateTime.now();

    final List<double> successRates = List.filled(7, 0.0);
    final activeHabits = _habits.where((h) => h.isActive).toList();

    if (activeHabits.isEmpty) {
      setState(() => _successData = successRates);
      return;
    }

    final Map<int, int> dayCount = {for (int i = 0; i < 7; i++) i: 0};

    for (var date in _activeDays) {
      final jalali = Jalali.fromDateTime(date);
      final weekday = jalali.weekDay - 1;
      dayCount[weekday] = (dayCount[weekday] ?? 0) + 1;
    }

    for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
      int totalItems = 0;
      int completedItems = 0;

      for (int week = 0; week < 4; week++) {
        final date = now
            .subtract(Duration(days: 27))
            .add(Duration(days: (week * 7) + dayIndex));

        if (date.isAfter(now)) continue;

        for (var habit in activeHabits) {
          if (!habit.shouldDoOnDate(date)) continue;
          // روزهای قبل از ساخته شدن عادت شکست حساب نمی‌شوند
          final created = DateTime(habit.createdAt.year, habit.createdAt.month,
              habit.createdAt.day);
          if (DateTime(date.year, date.month, date.day).isBefore(created)) {
            continue;
          }
          totalItems++;

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

  // متدهای کمکی با CalendarProvider
  DateTime _getWeekStart(DateTime date, CalendarProvider calendar) {
    if (calendar.isJalali) {
      final jalali = Jalali.fromDateTime(date);
      final daysToSubtract = jalali.weekDay - 1;
      return date.subtract(Duration(days: daysToSubtract));
    } else {
      final daysToSubtract = date.weekday % 7;
      return date.subtract(Duration(days: daysToSubtract));
    }
  }

  int _getCurrentWeekdayIndex(CalendarProvider calendar) {
    if (calendar.isJalali) {
      final jalaliNow = Jalali.now();
      return jalaliNow.weekDay - 1;
    } else {
      return DateTime.now().weekday % 7;
    }
  }

  List<String> _getWeekDayLetters(CalendarProvider calendar) {
    return calendar.weekDayHeaders;
  }

  List<Map<String, dynamic>> _getBestWeekDays(CalendarProvider calendar) {
    final weekDays = calendar.isJalali
        ? [
            'شنبه',
            'یک‌شنبه',
            'دوشنبه',
            'سه‌شنبه',
            'چهارشنبه',
            'پنج‌شنبه',
            'جمعه'
          ]
        : [
            'Monday',
            'Tuesday',
            'Wednesday',
            'Thursday',
            'Friday',
            'Saturday',
            'Sunday',
          ];
    final List<Map<String, dynamic>> result = [];

    final Map<int, int> dayActivityCount = {};
    for (int i = 0; i < 7; i++) {
      dayActivityCount[i] = 0;
    }

    for (var date in _activeDays) {
      int weekday;
      if (calendar.isJalali) {
        final jalali = Jalali.fromDateTime(date);
        weekday = jalali.weekDay - 1;
      } else {
        weekday = date.weekday % 7;
      }
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


  // ==================== ابزارهای مشترک ====================
  String _n(Object v) {
    final s = v.toString();
    if (context.isEnglish) return s;
    const en = '0123456789';
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    var out = s;
    for (int i = 0; i < en.length; i++) {
      out = out.replaceAll(en[i], fa[i]);
    }
    return out;
  }

  void _rebuild(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
    _tick.value++;
  }

  static const Color _ink = Color(0xFF090909);

  Widget _header(BuildContext ctx, ThemeProvider theme, String title) {
    final rtl = Directionality.of(ctx) == TextDirection.rtl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.cardColor,
                shape: BoxShape.circle,
                boxShadow: theme.softShadow,
              ),
              child: Icon(
                rtl ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                size: 22,
                color: theme.textColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: theme.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _pushSub(
    String title,
    Widget Function(BuildContext ctx) bodyBuilder, {
    Widget Function(BuildContext ctx)? bottomBuilder,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (routeCtx) => ValueListenableBuilder<int>(
          valueListenable: _tick,
          builder: (c, _, __) {
            final theme = Provider.of<ThemeProvider>(c);
            return Scaffold(
              backgroundColor: theme.backgroundColor,
              body: SafeArea(
                child: Column(
                  children: [
                    _header(c, theme, title),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: bodyBuilder(c),
                      ),
                    ),
                    if (bottomBuilder != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: bottomBuilder(c),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _whiteCard(ThemeProvider theme,
      {required Widget child,
      EdgeInsets padding = const EdgeInsets.all(18),
      double radius = 32}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: theme.softShadow,
      ),
      child: child,
    );
  }

  Widget _soonBadge(ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        context.tr('an.soon'),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: theme.textColor,
        ),
      ),
    );
  }

  Widget _sectionTitle(ThemeProvider theme, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: theme.textColor,
      ),
    );
  }

  Widget _emptyCard(ThemeProvider theme, IconData icon, String title,
      String subtitle) {
    return _whiteCard(
      theme,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      child: Column(
        children: [
          Icon(icon, size: 56, color: theme.textSecondaryColor),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: theme.textSecondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _barChart({
    required ThemeProvider theme,
    required List<String> letters,
    required List<double> values,
    required double chartHeight,
    required double barMax,
    required Color Function(int) colorOf,
    required Set<int> bold,
    bool showPct = false,
  }) {
    return Column(
      children: [
        SizedBox(
          height: chartHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final v = values[i].clamp(0.0, 1.0);
              final h = (v * barMax).clamp(6.0, barMax);
              return SizedBox(
                width: 36,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (showPct) ...[
                      Text(
                        '${_n((v * 100).round())}٪',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              bold.contains(i) ? FontWeight.w700 : FontWeight.w400,
                          color: bold.contains(i)
                              ? theme.textColor
                              : theme.textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Container(
                      width: 36,
                      height: h,
                      decoration: BoxDecoration(
                        color: colorOf(i),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            return SizedBox(
              width: 36,
              child: Text(
                i < letters.length ? letters[i] : '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      bold.contains(i) ? FontWeight.w700 : FontWeight.w400,
                  color: bold.contains(i)
                      ? theme.textColor
                      : theme.textSecondaryColor,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ==================== صفحهٔ اصلی (هاب) ====================
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final showLoading = _isLoading && _habits.isEmpty && _activeDays.isEmpty;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _header(context, theme, context.tr('an.title')),
            Expanded(
              child: showLoading
                  ? _buildLoadingState(theme)
                  : RefreshIndicator(
                      color: theme.effectivePrimary,
                      onRefresh: _loadData,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        children: [
                          _buildTodayCard(theme),
                          const SizedBox(height: 14),
                          _buildSectionCard(
                            theme,
                            Tone.sky,
                            Icons.calendar_month_rounded,
                            context.tr('an.sec_history'),
                            context.tr('an.sec_history_sub'),
                            () => _pushSub(
                              context.tr('an.sec_history'),
                              _buildHistoryBody,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildSectionCard(
                            theme,
                            Tone.lilac,
                            Icons.bar_chart_rounded,
                            context.tr('an.sec_habits'),
                            context.tr('an.sec_habits_sub'),
                            () => _pushSub(
                              context.tr('an.sec_habits'),
                              _buildHabitsBody,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildSectionCard(
                            theme,
                            Tone.butter,
                            Icons.emoji_events_rounded,
                            context.tr('an.sec_records'),
                            context.tr('an.sec_records_sub'),
                            () => _pushSub(
                              context.tr('an.sec_records'),
                              _buildRecordsBody,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildSectionCard(
                            theme,
                            Tone.peach,
                            Icons.trending_down_rounded,
                            context.tr('an.sec_drops'),
                            context.tr('an.sec_drops_sub'),
                            () => _pushSub(
                              context.tr('an.sec_drops'),
                              _buildDropsBody,
                              bottomBuilder: _buildDropsCta,
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

  Widget _buildTodayCard(ThemeProvider theme) {
    final dark = theme.isDarkMode;
    final bg = dark ? const Color(0xFF1E2119) : _ink;
    final tileBg = dark ? const Color(0xFF2A2D24) : const Color(0xFF1E2119);
    final track = dark ? const Color(0xFF3A3E33) : const Color(0xFF2A2D24);
    const mutedText = Color(0xFFBFC5B3);

    final done = _tHabitsDone + _tTasksDone + _tChDone + _tQuDone;
    final total = _tHabitsTotal + _tTasksTotal + _tChTotal + _tQuTotal;
    final progress = total > 0 ? done / total : 0.0;

    Widget tile(String label, int d, int t) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: tileBg,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Text(
                '${_n(d)}/${_n(t)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: mutedText),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(76, 76),
                      painter: _RingPainter(
                        progress: progress,
                        color: theme.effectivePrimary,
                        track: track,
                      ),
                    ),
                    Text(
                      '${_n((progress * 100).round())}٪',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('an.today_rate'),
                      style: const TextStyle(fontSize: 13, color: mutedText),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      total > 0
                          ? context.tr('an.today_done', {
                              'done': _n(done),
                              'total': _n(total),
                            })
                          : context.tr('an.today_none'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              tile(context.tr('an.tile_habits'), _tHabitsDone, _tHabitsTotal),
              const SizedBox(width: 8),
              tile(context.tr('an.tile_tasks'), _tTasksDone, _tTasksTotal),
              const SizedBox(width: 8),
              tile(context.tr('an.tile_challenges'), _tChDone, _tChTotal),
              const SizedBox(width: 8),
              tile(context.tr('an.tile_quests'), _tQuDone, _tQuTotal),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    ThemeProvider theme,
    Tone tone,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    final t = theme.tone(tone);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.bg,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: theme.isDarkMode ? 0.1 : 0.6),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 24, color: theme.textColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: theme.textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              size: 22,
              color: theme.textColor,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== تاریخچه کلی ====================
  void _shiftMonth(CalendarProvider calendar, int delta) {
    _rebuild(() {
      if (calendar.isJalali) {
        final jalali = Jalali.fromDateTime(_currentMonth);
        int newMonth = jalali.month + delta;
        int newYear = jalali.year;
        if (newMonth < 1) {
          newMonth = 12;
          newYear--;
        } else if (newMonth > 12) {
          newMonth = 1;
          newYear++;
        }
        _currentMonth = Jalali(newYear, newMonth, 1).toDateTime();
      } else {
        _currentMonth =
            DateTime(_currentMonth.year, _currentMonth.month + delta, 1);
      }
    });
  }

  Widget _buildHistoryBody(BuildContext ctx) {
    final theme = Provider.of<ThemeProvider>(ctx);
    final calendar = Provider.of<CalendarProvider>(ctx);
    final rtl = Directionality.of(ctx) == TextDirection.rtl;

    String monthName;
    String yearText;
    int daysInMonth;
    int firstDayWeekday;

    if (calendar.isJalali) {
      final jalali = Jalali.fromDateTime(_currentMonth);
      monthName = _getJalaliMonthName(jalali.month);
      yearText = jalali.year.toString();
      daysInMonth = calendar.daysInMonth(jalali.year, jalali.month);
      firstDayWeekday = _getJalaliWeekday(jalali.year, jalali.month, 1);
    } else {
      monthName = _getGregorianMonthName(_currentMonth.month);
      yearText = _currentMonth.year.toString();
      daysInMonth =
          DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
      firstDayWeekday =
          DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7;
    }

    Widget navButton(IconData icon, String label, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          semanticLabel: label,
          decoration: BoxDecoration(
            color: theme.cardSecondaryColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: theme.textColor),
        ),
      );
    }

    Widget legendBox(Color c) => Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(7),
          ),
        );

    Widget statTile(Tone tone, String value, String label) {
      final t = theme.tone(tone);
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.bg,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: theme.textSecondaryColor),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _whiteCard(
          theme,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  navButton(
                    rtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                    ctx.tr('an.prev_month'),
                    () => _shiftMonth(calendar, -1),
                  ),
                  Text(
                    _n('$monthName $yearText'),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: theme.textColor,
                    ),
                  ),
                  navButton(
                    rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                    ctx.tr('an.next_month'),
                    () => _shiftMonth(calendar, 1),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildCalendarGrid(
                theme,
                daysInMonth,
                firstDayWeekday,
                calendar,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    ctx.tr('an.legend_less'),
                    style: TextStyle(
                        fontSize: 12, color: theme.textSecondaryColor),
                  ),
                  const SizedBox(width: 3),
                  legendBox(theme.cardSecondaryColor),
                  legendBox(theme.primarySoft),
                  legendBox(Color.lerp(
                      theme.effectivePrimary, theme.cardColor, 0.4)!),
                  legendBox(theme.effectivePrimary),
                  const SizedBox(width: 3),
                  Text(
                    ctx.tr('an.legend_more'),
                    style: TextStyle(
                        fontSize: 12, color: theme.textSecondaryColor),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            statTile(Tone.sky, _n(_totalActiveDays),
                ctx.tr('an.stat_active_days')),
            const SizedBox(width: 10),
            statTile(Tone.lilac, _n(_habits.length),
                ctx.tr('an.stat_total_habits')),
            const SizedBox(width: 10),
            statTile(
                Tone.peach, _n(_bestStreak), ctx.tr('an.stat_best_streak')),
          ],
        ),
      ],
    );
  }

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

  int _getJalaliWeekday(int year, int month, int day) {
    final jalali = Jalali(year, month, day);
    return jalali.weekDay - 1;
  }

  Widget _buildCalendarGrid(
    ThemeProvider theme,
    int daysInMonth,
    int firstDayWeekday,
    CalendarProvider calendar,
  ) {
    final weekDays = calendar.weekDayHeaders;
    final now = DateTime.now();
    final accent = theme.effectivePrimary;

    return Column(
      children: [
        Row(
          children: [
            for (int i = 0; i < weekDays.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: SizedBox(
                  height: 24,
                  child: Center(
                    child: Text(
                      weekDays[i],
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textSecondaryColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            mainAxisExtent: 40,
          ),
          itemCount: firstDayWeekday + daysInMonth,
          itemBuilder: (context, index) {
            final day = index - firstDayWeekday + 1;
            if (day < 1 || day > daysInMonth) {
              return const SizedBox();
            }

            DateTime date;
            if (calendar.isJalali) {
              final jalali = Jalali.fromDateTime(_currentMonth);
              date = Jalali(jalali.year, jalali.month, day).toDateTime();
            } else {
              date = DateTime(_currentMonth.year, _currentMonth.month, day);
            }

            final isToday = _isToday(date, calendar);
            final isActive = _activeDays.any(
              (d) =>
                  d.year == date.year &&
                  d.month == date.month &&
                  d.day == date.day,
            );
            final isFuture = date.isAfter(now) && !isToday;

            Color? bg;
            Color fg = theme.textColor;
            if (isToday) {
              bg = theme.isDarkMode ? Colors.white : _ink;
              fg = theme.isDarkMode ? _ink : Colors.white;
            } else if (isActive) {
              bg = accent;
              fg = _ink;
            } else if (isFuture) {
              fg = theme.textSecondaryColor.withValues(alpha: 0.6);
            }

            return Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  _n(day),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  bool _isToday(DateTime date, CalendarProvider calendar) {
    final now = DateTime.now();
    if (calendar.isJalali) {
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

  // ==================== جزئیات عادت‌ها ====================
  Future<Map<String, List<bool>>> _getAllHabitsWeeklyStatus(
    CalendarProvider calendar,
  ) async {
    if (_cachedWeeklyStatus != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      return _cachedWeeklyStatus!;
    }

    final Map<String, List<bool>> result = {};
    final now = DateTime.now();
    final weekStart = _getWeekStart(now, calendar);

    if (_habits.isEmpty) return result;

    final List<String> weekDates = [];
    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      weekDates.add(date.toIso8601String().split('T').first);
    }

    final List<String> habitIds = _habits.map((h) => h.id).toList();

    try {
      final response = await _supabase.client
          .from('habit_completions')
          .select('habit_id, date')
          .eq('user_id', widget.userId)
          .inFilter('habit_id', habitIds)
          .inFilter('date', weekDates);

      final Set<String> completedSet = {};
      for (var item in response) {
        final habitId = item['habit_id'] as String;
        final date = item['date'] as String;
        completedSet.add('$habitId|$date');
      }

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

      _cachedWeeklyStatus = result;
      _cacheTime = DateTime.now();

      return result;
    } catch (e) {
      for (var habit in _habits) {
        result[habit.id] = List.filled(7, false);
      }
      return result;
    }
  }

  void _clearCache() {
    _cachedWeeklyStatus = null;
    _cacheTime = null;
  }

  Future<void> _calculateHabitRates() async {
    final activeHabits = _habits.where((h) => h.isActive).toList();
    final Map<String, double> rates = {};
    if (activeHabits.isEmpty) {
      _habitRates = rates;
      return;
    }

    final now = DateTime.now();
    final List<DateTime> days = [
      for (int i = 29; i >= 0; i--) now.subtract(Duration(days: i)),
    ];
    final dateStrs = days.map((d) => d.toIso8601String().split('T').first);
    final Map<String, Set<String>> completions = {};

    try {
      final response = await _supabase.client
          .from('habit_completions')
          .select('habit_id, date')
          .eq('user_id', widget.userId)
          .inFilter('habit_id', activeHabits.map((h) => h.id).toList())
          .inFilter('date', dateStrs.toList());
      for (var item in response) {
        completions
            .putIfAbsent(item['habit_id'] as String, () => {})
            .add(item['date'] as String);
      }
    } catch (e) {
      // بدون داده‌ی تکمیل، نرخ‌ها صفر می‌مانند
    }

    for (var habit in activeHabits) {
      final created = DateTime(
          habit.createdAt.year, habit.createdAt.month, habit.createdAt.day);
      int total = 0;
      int done = 0;
      for (var d in days) {
        if (!habit.shouldDoOnDate(d)) continue;
        if (DateTime(d.year, d.month, d.day).isBefore(created)) continue;
        total++;
        final s = d.toIso8601String().split('T').first;
        if (completions[habit.id]?.contains(s) ?? false) done++;
      }
      rates[habit.id] = total > 0 ? done / total : 0.0;
    }
    _habitRates = rates;
  }

  Future<void> _calculateToday() async {
    if (!mounted) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = now.toIso8601String().split('T').first;
    final sync = Provider.of<SyncProvider>(context, listen: false);

    final scheduled = _habits.where((h) {
      if (!h.isActive || !h.shouldDoOnDate(now)) return false;
      final created =
          DateTime(h.createdAt.year, h.createdAt.month, h.createdAt.day);
      return !created.isAfter(today);
    }).toList();

    Set<String> doneIds = {};
    if (scheduled.isNotEmpty) {
      try {
        final response = await _supabase.client
            .from('habit_completions')
            .select('habit_id')
            .eq('user_id', widget.userId)
            .eq('date', todayStr)
            .inFilter('habit_id', scheduled.map((h) => h.id).toList());
        doneIds = {for (var r in response) r['habit_id'] as String};
      } catch (e) {
        // نادیده بگیر
      }
    }

    int hd = 0, ht = 0, cd = 0, ct = 0, qd = 0, qt = 0;
    for (var h in scheduled) {
      final isDone = doneIds.contains(h.id);
      if (h.challengeId != null) {
        ct++;
        if (isDone) cd++;
      } else if (h.questId != null) {
        qt++;
        if (isDone) qd++;
      } else {
        ht++;
        if (isDone) hd++;
      }
    }

    final todayTasks = sync.tasks.where((t) => t.isForToday()).toList();

    _tHabitsDone = hd;
    _tHabitsTotal = ht;
    _tChDone = cd;
    _tChTotal = ct;
    _tQuDone = qd;
    _tQuTotal = qt;
    _tTasksTotal = todayTasks.length;
    _tTasksDone = todayTasks.where((t) => t.isCompleted).length;
  }

  Widget _buildHabitsBody(BuildContext ctx) {
    final theme = Provider.of<ThemeProvider>(ctx);
    final calendar = Provider.of<CalendarProvider>(ctx);

    if (_habits.isEmpty) {
      return _emptyCard(
        theme,
        Icons.bar_chart_rounded,
        ctx.tr('an.habits_empty_title'),
        ctx.tr('an.habits_empty_sub'),
      );
    }

    final names = _getWeekDayNamesForChart();
    final letters = _getWeekDayLetters(calendar);
    int bestIdx = 0;
    for (int i = 1; i < _successData.length; i++) {
      if (_successData[i] > _successData[bestIdx]) bestIdx = i;
    }
    final hasBest = _successData[bestIdx] > 0;

    final activeHabits = _habits.where((h) => h.isActive).toList()
      ..sort((a, b) =>
          (_habitRates[b.id] ?? 0).compareTo(_habitRates[a.id] ?? 0));
    const tones = [Tone.lilac, Tone.sky, Tone.peach, Tone.butter];
    const maxShown = 6;
    final shown = activeHabits.take(maxShown).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _whiteCard(
          theme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ctx.tr('an.habits_weekday'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: theme.textColor,
                    ),
                  ),
                  if (hasBest)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: theme.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        ctx.tr('an.habits_best', {'day': names[bestIdx]}),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.textColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _barChart(
                theme: theme,
                letters: letters,
                values: _successData,
                chartHeight: 150,
                barMax: 110,
                showPct: true,
                bold: hasBest ? {bestIdx} : <int>{},
                colorOf: (i) => (hasBest && i == bestIdx)
                    ? theme.effectivePrimary
                    : theme.primarySoft,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _sectionTitle(theme, ctx.tr('an.habits_last30')),
        const SizedBox(height: 10),
        for (int i = 0; i < shown.length; i++) ...[
          _buildHabitRateRow(theme, shown[i], tones[i % tones.length]),
          const SizedBox(height: 10),
        ],
        if (activeHabits.length > maxShown)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                ctx.tr('an.habits_more',
                    {'n': _n(activeHabits.length - maxShown)}),
                style: TextStyle(fontSize: 13, color: theme.textSecondaryColor),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHabitRateRow(ThemeProvider theme, Habit habit, Tone tone) {
    final t = theme.tone(tone);
    final rate = (_habitRates[habit.id] ?? 0.0).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  habit.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: theme.textColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_n((rate * 100).round())}٪',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: theme.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 8,
            alignment: AlignmentDirectional.centerStart,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: theme.isDarkMode ? 0.12 : 0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              widthFactor: rate,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: theme.isDarkMode ? t.fg : _ink,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== رکوردهای شما ====================
  List<({Habit habit, int streak})> _getHabitsWithBestStreak() {
    List<({Habit habit, int streak})> result = [];

    if (_habits.isEmpty) return result;

    int maxStreak = 0;
    for (var habit in _habits) {
      if (!habit.isActive) continue;
      if (habit.challengeId != null || habit.questId != null) continue;

      if (habit.bestStreak > maxStreak) {
        maxStreak = habit.bestStreak;
      }
    }

    if (maxStreak == 0) return result;

    for (var habit in _habits) {
      if (!habit.isActive) continue;
      if (habit.challengeId != null || habit.questId != null) continue;

      if (habit.bestStreak == maxStreak) {
        result.add((habit: habit, streak: habit.bestStreak));
      }
    }

    return result;
  }

  Widget _buildRecordsBody(BuildContext ctx) {
    final theme = Provider.of<ThemeProvider>(ctx);
    final calendar = Provider.of<CalendarProvider>(ctx);
    final dark = theme.isDarkMode;
    final accent = theme.effectivePrimary;
    final bestDays = _getBestWeekDays(calendar);
    final topDay = bestDays.isNotEmpty ? bestDays.first : null;
    final bestHabits = _getHabitsWithBestStreak();

    Widget recTile(Tone tone, String label, String value) {
      final t = theme.tone(tone);
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.bg,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: theme.textSecondaryColor),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: theme.textColor,
              ),
            ),
          ],
        ),
      );
    }

    final noData = ctx.tr('an.rec_no_data');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Container(
            padding: const EdgeInsets.all(22),
            color: dark ? const Color(0xFF1E2119) : _ink,
            child: Stack(
              children: [
                Positioned(
                  left: -52,
                  top: -52,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      color: dark
                          ? const Color(0xFF2A2D24)
                          : const Color(0xFF1E2119),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: const Icon(Icons.emoji_events_rounded,
                          size: 36, color: _ink),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ctx.tr('an.rec_longest'),
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFFBFC5B3)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ctx.tr('an.day_unit', {'n': _n(_bestStreak)}),
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _bestStreak > 0
                                ? ctx.tr('an.rec_from_days',
                                    {'n': _n(_activeDays.length)})
                                : ctx.tr('an.rec_none'),
                            style: TextStyle(fontSize: 12, color: accent),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  recTile(
                    Tone.butter,
                    ctx.tr('an.rec_best_weekday'),
                    topDay != null ? topDay['day'] as String : noData,
                  ),
                  const SizedBox(height: 10),
                  recTile(
                    Tone.lilac,
                    ctx.tr('an.rec_most_xp'),
                    _maxXpInDay > 0 ? '${_n(_maxXpInDay)} XP' : noData,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: [
                  recTile(
                    Tone.sky,
                    ctx.tr('an.rec_most_tasks'),
                    _maxItemsInDay > 0
                        ? ctx.tr('an.n_items', {'n': _n(_maxItemsInDay)})
                        : noData,
                  ),
                  const SizedBox(height: 10),
                  recTile(
                    Tone.peach,
                    ctx.tr('an.rec_active_total'),
                    ctx.tr('an.day_unit', {'n': _n(_totalActiveDays)}),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _sectionTitle(theme, ctx.tr('an.rec_best_habits')),
        const SizedBox(height: 10),
        if (bestHabits.isEmpty)
          _whiteCard(
            theme,
            radius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Text(
              _habits.isNotEmpty
                  ? ctx.tr('an.rec_none')
                  : ctx.tr('an.habits_empty_title'),
              style: TextStyle(fontSize: 14, color: theme.textSecondaryColor),
            ),
          )
        else
          for (final item in bestHabits.take(5)) ...[
            _buildBestHabitRow(theme, item.habit, item.streak),
            const SizedBox(height: 10),
          ],
        if (bestHabits.length > 5)
          Center(
            child: Text(
              ctx.tr('an.habits_more', {'n': _n(bestHabits.length - 5)}),
              style: TextStyle(fontSize: 13, color: theme.textSecondaryColor),
            ),
          ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _sectionTitle(theme, ctx.tr('an.rec_medals'))),
            _soonBadge(theme),
          ],
        ),
        const SizedBox(height: 10),
        _whiteCard(
          theme,
          radius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.military_tech_rounded,
                    size: 22, color: theme.textColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  ctx.tr('an.rec_medals_soon'),
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.textSecondaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBestHabitRow(ThemeProvider theme, Habit habit, int streak) {
    return _whiteCard(
      theme,
      radius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.primarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(_getIconData(habit.iconName),
                size: 22, color: theme.textColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: theme.textColor,
                  ),
                ),
                Text(
                  context.tr('an.rec_streak_days', {'n': _n(streak)}),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.local_fire_department_rounded,
              size: 18, color: theme.textColor),
          const SizedBox(width: 4),
          Text(
            _n(streak),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: theme.textColor,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== نمودار شکست ====================
  List<String> _getWeekDayNamesForChart() {
    final calendar = Provider.of<CalendarProvider>(context, listen: false);
    if (calendar.isJalali) {
      return [
        'شنبه',
        'یک‌شنبه',
        'دوشنبه',
        'سه‌شنبه',
        'چهارشنبه',
        'پنج‌شنبه',
        'جمعه'
      ];
    } else {
      return [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
    }
  }

  List<int> _lowDayIndexes() {
    final idx = List<int>.generate(7, (i) => i)
      ..sort((a, b) => _successData[a].compareTo(_successData[b]));
    return idx.where((i) => _successData[i] < 0.5).take(2).toList()..sort();
  }

  Widget _buildDropsBody(BuildContext ctx) {
    final theme = Provider.of<ThemeProvider>(ctx);
    final calendar = Provider.of<CalendarProvider>(ctx);
    final maxValue = _successData.reduce((a, b) => a > b ? a : b);
    final hasData = _activeDays.isNotEmpty && maxValue > 0;

    if (!hasData) {
      return _emptyCard(
        theme,
        Icons.trending_down_rounded,
        ctx.tr('an.sec_drops'),
        ctx.tr('an.drops_need_data'),
      );
    }

    final names = _getWeekDayNamesForChart();
    final letters = _getWeekDayLetters(calendar);
    final lows = _lowDayIndexes();
    final peach = theme.tone(Tone.peach);
    final weakColor =
        theme.isDarkMode ? peach.fg : const Color(0xFFFFB48A);

    String headline;
    String hint;
    if (lows.isEmpty) {
      headline = ctx.tr('an.drops_no_low');
      hint = ctx.tr('an.drops_no_low_hint');
    } else if (lows.length == 1) {
      headline = names[lows.first];
      hint = ctx.tr('an.drops_low_hint');
    } else {
      headline =
          ctx.tr('an.drops_and', {'a': names[lows[0]], 'b': names[lows[1]]});
      hint = ctx.tr('an.drops_low_hint');
    }

    Widget tip(Tone tone, IconData icon, String text) {
      final t = theme.tone(tone);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _whiteCard(
          theme,
          radius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: t.bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 20, color: theme.textColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: peach.bg,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white
                      .withValues(alpha: theme.isDarkMode ? 0.1 : 0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.trending_down_rounded,
                    size: 26, color: theme.textColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ctx.tr('an.drops_low_days'),
                      style: TextStyle(
                          fontSize: 12, color: theme.textSecondaryColor),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      headline,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: theme.textColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hint,
                      style: TextStyle(
                          fontSize: 12, color: theme.textSecondaryColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _whiteCard(
          theme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ctx.tr('an.drops_chart'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 14),
              _barChart(
                theme: theme,
                letters: letters,
                values: _successData,
                chartHeight: 130,
                barMax: 100,
                bold: lows.toSet(),
                colorOf: (i) =>
                    lows.contains(i) ? weakColor : theme.primarySoft,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _sectionTitle(theme, ctx.tr('an.drops_tips')),
        const SizedBox(height: 10),
        tip(Tone.sky, Icons.remove_rounded, ctx.tr('an.drops_tip1')),
        tip(Tone.lilac, Icons.notifications_none_rounded,
            ctx.tr('an.drops_tip2')),
        tip(Tone.butter, Icons.person_outline_rounded, ctx.tr('an.drops_tip3')),
      ],
    );
  }

  Widget _buildDropsCta(BuildContext ctx) {
    final theme = Provider.of<ThemeProvider>(ctx);
    final dark = theme.isDarkMode;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          // یادآور اختصاصی هنوز بک‌اند ندارد؛ فعلاً پیام «به‌زودی»
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text(ctx.tr('an.soon'))),
          );
        },
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: dark ? theme.effectivePrimary : _ink,
          foregroundColor: dark ? _ink : theme.effectivePrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Text(
          ctx.tr('an.drops_cta'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  // ==================== حالت لودینگ ====================
  Widget _buildLoadingState(ThemeProvider theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: theme.effectivePrimary),
          const SizedBox(height: 16),
          Text(
            context.tr('an.loading'),
            style: TextStyle(color: theme.textSecondaryColor),
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

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 31 / 76;
    final stroke = size.width * 9 / 76;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);
    if (progress <= 0) return;
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}
