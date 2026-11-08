// lib/features/arena/screens/arena_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '/core/app_palette.dart';
import '/l10n/app_strings.dart';
import '../widgets/calendar_header.dart';
import 'today_tab.dart';
import 'habits_tab.dart';
import 'tasks_tab.dart';
import '../category_selection_screen.dart';
import '../add_task_screen.dart';
import '/providers/sync_provider.dart';
import '/providers/theme_provider.dart';
import '/providers/calendar_provider.dart';

class ArenaScreen extends StatefulWidget {
  final ValueNotifier<int>? profileRefreshNotifier;

  const ArenaScreen({super.key, this.profileRefreshNotifier});

  @override
  State<ArenaScreen> createState() => _ArenaScreenState();
}

class _ArenaScreenState extends State<ArenaScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  DateTime _selectedDate = DateTime.now();

  final GlobalKey<TodayTabState> _todayTabKey = GlobalKey<TodayTabState>();
  final GlobalKey<HabitsTabState> _habitsTabKey = GlobalKey<HabitsTabState>();
  final GlobalKey<TasksTabState> _tasksTabKey = GlobalKey<TasksTabState>();

  bool _isRefreshing = false;
  DateTime? _lastRefreshTime;
  static const Duration _minRefreshInterval = Duration(milliseconds: 500);

  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;
  double _currentProgress = 0.0;
  double _targetProgress = 0.0;

  static const List<String> _tabKeys = [
    'ah.tab.today',
    'ah.tab.habits',
    'ah.tab.tasks',
  ];
  static const List<IconData> _icons = [
    Icons.today_rounded,
    Icons.fitness_center_rounded,
    Icons.assignment_rounded,
  ];

  // وضعیت جمع‌شدن هدر هنگام اسکرول لیست
  bool _collapsed = false;
  int _doneCount = 0;
  int _totalCount = 0;

  static const double _horizontalMargin = 16.0;

  @override
  void initState() {
    super.initState();
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _progressAnimationController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _progressAnimation.addListener(() {
      if (mounted) {
        setState(() {
          _currentProgress = _progressAnimation.value;
        });
      }
    });

    _loadProgress();
  }

  Future<void> _loadProgress() async {
    _updateProgressAnimated(0.0);
  }

  void _updateProgressAnimated(double newProgress) {
    _targetProgress = newProgress.clamp(0.0, 1.0);
    _progressAnimation = Tween<double>(
      begin: _currentProgress,
      end: _targetProgress,
    ).animate(
      CurvedAnimation(
        parent: _progressAnimationController,
        curve: Curves.easeInOutCubic,
      ),
    );
    _progressAnimationController.forward(from: 0.0);
  }

  void updateProgress(double newProgress) {
    _updateProgressAnimated(newProgress);
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    super.dispose();
  }

  void _onDateSelected(DateTime date) {
    final selectedDate = DateTime(date.year, date.month, date.day);
    setState(() {
      _selectedDate = selectedDate;
    });
  }

  void _onTabChanged(int index) {
    setState(() {
      _selectedIndex = index;
      _collapsed = false;
    });
  }

  void _onStatsUpdate(int done, int total) {
    if (!mounted) return;
    if (done == _doneCount && total == _totalCount) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _doneCount = done;
        _totalCount = total;
      });
    });
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final double y = n.metrics.pixels;
    // فقط وقتی لیست آن‌قدر بلند است که با جمع‌شدن هدر نوسان نکند
    if (!_collapsed && y > 24 && n.metrics.maxScrollExtent > 260) {
      setState(() => _collapsed = true);
    } else if (_collapsed && y <= 0) {
      setState(() => _collapsed = false);
    }
    return false;
  }

  void _refreshAllTabs() {
    final now = DateTime.now();
    if (_lastRefreshTime != null &&
        now.difference(_lastRefreshTime!) < _minRefreshInterval) {
      return;
    }
    _lastRefreshTime = now;

    if (_isRefreshing) return;
    _isRefreshing = true;

    setState(() {});

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _isRefreshing = false;
      }
    });
  }

  void _openAddHabit() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CategorySelectionScreen()),
    ).then((_) {
      _refreshCurrentTab();
    });
  }

  void _openAddTask() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTaskScreen()),
    ).then((_) {
      _refreshCurrentTab();
    });
  }

  void _refreshCurrentTab() {
    switch (_selectedIndex) {
      case 0:
        _todayTabKey.currentState?.refreshData();
        break;
      case 1:
        _habitsTabKey.currentState?.refreshData();
        break;
      case 2:
        _tasksTabKey.currentState?.refreshData();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final Color bg = themeProvider.primaryColor;
    final bool darkBg = ThemeData.estimateBrightnessForColor(bg) ==
        Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: darkBg ? Brightness.light : Brightness.dark,
        statusBarBrightness: darkBg ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: bg,
        body: Column(
          children: [
            // هدر روی پس‌زمینهٔ رنگ تم
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _collapsed
                  ? _buildCompactBar(themeProvider)
                  : Column(
                      children: [
                        CalendarHeader(
                          onDateSelected: _onDateSelected,
                          selectedDate: _selectedDate,
                          action: _buildAddButton(themeProvider, 44),
                        ),
                        const SizedBox(height: 2),
                        _buildArcProgress(themeProvider),
                      ],
                    ),
            ),

            // نوار وضعیت
            Consumer<SyncProvider>(
              builder: (context, syncProvider, child) {
                if (!syncProvider.isOnline ||
                    syncProvider.hasOfflineOperations) {
                  return _buildOfflineStatusBar(syncProvider, themeProvider);
                }
                return const SizedBox.shrink();
              },
            ),

            const SizedBox(height: 8),

            // تب‌های مستقل + باکس سفید (با حاشیهٔ رنگ پس‌زمینه دور تا دور)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: _selectedIndex.toDouble()),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeInOutCubic,
                  builder: (context, pos, _) {
                    final bool rtl =
                        Directionality.of(context) == TextDirection.rtl;
                    // مقدار نزدیکی به سمت چپ/راست فیزیکی (۰ تا ۱)
                    final double toStart = pos.clamp(0.0, 1.0);
                    final double toEnd = (2 - pos).clamp(0.0, 1.0);
                    final double left = rtl ? toEnd : toStart;
                    final double right = rtl ? toStart : toEnd;
                    return Column(
                      children: [
                        _buildTabs(themeProvider, pos, left, right),
                        Expanded(
                          child: Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: themeProvider.cardColor,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(32 * left),
                                topRight: Radius.circular(32 * right),
                                bottomLeft: const Radius.circular(32),
                                bottomRight: const Radius.circular(32),
                              ),
                            ),
                            child: NotificationListener<ScrollNotification>(
                              onNotification: _onScroll,
                              child: _buildAnimatedPages(),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // صفحه‌ها همه زنده می‌مانند؛ جابه‌جایی با لغزش و محو نرم انجام می‌شود
  Widget _buildAnimatedPages() {
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final pages = <Widget>[
      TodayTab(
        key: _todayTabKey,
        selectedDate: _selectedDate,
        profileRefreshNotifier: widget.profileRefreshNotifier,
        onProgressUpdate: updateProgress,
        onStatsUpdate: _onStatsUpdate,
      ),
      HabitsTab(key: _habitsTabKey),
      TasksTab(key: _tasksTabKey),
    ];
    return Stack(
      children: [
        for (var i = 0; i < pages.length; i++)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: i != _selectedIndex,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                offset: Offset(
                    (i - _selectedIndex) * 0.14 * (rtl ? -1.0 : 1.0), 0),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOut,
                  opacity: i == _selectedIndex ? 1.0 : 0.0,
                  child: pages[i],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ==================== دکمهٔ افزودن (بالا سمت چپ، زیر تقویم) ====================

  Widget _buildAddButton(ThemeProvider theme, double size) {
    return Semantics(
      button: true,
      label: context.tr('ah.fab.add'),
      child: GestureDetector(
        onTap: _showAddSheet,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Color(0xFF090909),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.add_rounded,
              size: size * 0.52, color: theme.primaryColor),
        ),
      ),
    );
  }

  void _showAddSheet() {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    Widget option(Tone tone, IconData icon, String label, VoidCallback onTap) {
      final t = theme.tone(tone);
      return GestureDetector(
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: t.bg,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFF090909),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: theme.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: theme.textColor,
                  ),
                ),
              ),
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: theme.textSecondaryColor,
              ),
            ],
          ),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xFF090909).withValues(alpha: 0.5),
      builder: (ctx) => SafeArea(top: false, child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.cardSecondaryColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  context.tr('ah.fab.add'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: theme.textColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              option(Tone.sky, Icons.fitness_center_rounded,
                  context.tr('ah.fab.habit'), _openAddHabit),
              const SizedBox(height: 10),
              option(Tone.peach, Icons.assignment_turned_in_rounded,
                  context.tr('ah.fab.task'), _openAddTask),
            ],
          ),
        ),
      )),
    );
  }

  // ==================== هدر جمع‌شده ====================

  Widget _buildCompactBar(ThemeProvider theme) {
    final calendar = Provider.of<CalendarProvider>(context);
    final Color fg = theme.onPrimaryColor;
    final double p = _currentProgress.clamp(0.0, 1.0);
    final int percent = (p * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CustomPaint(
              painter: _ProgressRingPainter(
                progress: p,
                color: fg,
                track: fg.withValues(alpha: 0.18),
                strokeWidth: 5,
              ),
              child: Center(
                child: Text(
                  '$percent%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${calendar.getWeekdayName(_selectedDate)}، '
                  '${calendar.formatWithMonthName(_selectedDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
                Text(
                  context.tr('ah.hero.count', {
                    'd': '$_doneCount',
                    't': '$_totalCount',
                  }),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: fg.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _collapsed = false),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.cardColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.calendar_month_rounded,
                  size: 20, color: theme.textColor),
            ),
          ),
          const SizedBox(width: 8),
          _buildAddButton(theme, 42),
        ],
      ),
    );
  }

  // ==================== نیم‌دایرهٔ پیشرفت (روی پس‌زمینه) ====================

  String _motivationKey(double p) {
    if (p >= 1.0) return 'ah.hero.t3';
    if (p >= 0.5) return 'ah.hero.t2';
    if (p > 0) return 'ah.hero.t1';
    return 'ah.hero.t0';
  }

  Widget _buildArcProgress(ThemeProvider theme) {
    final Color fg = theme.onPrimaryColor;
    final double p = _currentProgress.clamp(0.0, 1.0);
    final int percent = (p * 100).round();

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Column(
        children: [
          SizedBox(
            width: 224,
            height: 112,
            child: Stack(
              children: [
                CustomPaint(
                  size: const Size(224, 112),
                  painter: _ArcPainter(
                    progress: p,
                    color: fg,
                    track: fg.withValues(alpha: 0.18),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 46,
                  child: Column(
                    children: [
                      Text(
                        '$percent%',
                        style: TextStyle(
                          fontSize: 34,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: fg,
                        ),
                      ),
                      Text(
                        context.tr('ah.hero.count', {
                          'd': '$_doneCount',
                          't': '$_totalCount',
                        }),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: fg.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 4, 32, 0),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                context.tr(_motivationKey(p)),
                key: ValueKey(_motivationKey(p)),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ==================== تب‌های چسبنده ====================

  static const double _tabFillerSize = 16;

  /// [pos] موقعیت پیوستهٔ تب انتخاب‌شده (۰..۲)، [left] و [right] میزان وجود
  /// همسایه در سمت چپ/راست فیزیکی (۰..۱). تب سفید یک نشانگر واحد است که
  /// روی تب‌ها می‌لغزد؛ پس هیچ لبهٔ تیزی در میانهٔ انیمیشن ساخته نمی‌شود.
  Widget _buildTabs(ThemeProvider theme, double pos, double left, double right) {
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    const double gap = 8;
    final int n = _tabKeys.length;

    return SizedBox(
      height: 56,
      child: LayoutBuilder(
        builder: (context, box) {
          final double sw = (box.maxWidth - gap * (n - 1)) / n;
          double xOf(double i) =>
              rtl ? box.maxWidth - (i + 1) * sw - i * gap : i * (sw + gap);
          final double indX = xOf(pos);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // قرص‌های شفاف تب‌های غیرفعال
              for (var i = 0; i < n; i++)
                Positioned(
                  left: xOf(i.toDouble()),
                  top: 0,
                  width: sw,
                  height: 42,
                  child: Opacity(
                    opacity: (pos - i).abs().clamp(0.0, 1.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.cardColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(21),
                      ),
                    ),
                  ),
                ),

              // نشانگر سفید متصل به باکس
              Positioned(
                left: indX,
                top: 0,
                width: sw,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(26)),
                  ),
                ),
              ),
              // گوشه‌های وارونه، همراه نشانگر و محو در لبه‌ها
              Positioned(
                left: indX - _tabFillerSize,
                bottom: 0,
                child: Opacity(
                  opacity: left,
                  child: CustomPaint(
                    size: const Size(_tabFillerSize, _tabFillerSize),
                    painter: _InverseCornerPainter(
                        color: theme.cardColor, circleOnRight: false),
                  ),
                ),
              ),
              Positioned(
                left: indX + sw,
                bottom: 0,
                child: Opacity(
                  opacity: right,
                  child: CustomPaint(
                    size: const Size(_tabFillerSize, _tabFillerSize),
                    painter: _InverseCornerPainter(
                        color: theme.cardColor, circleOnRight: true),
                  ),
                ),
              ),

              // برچسب‌ها و لمس
              for (var i = 0; i < n; i++)
                Positioned(
                  left: xOf(i.toDouble()),
                  top: 0,
                  width: sw,
                  height: 56,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _onTabChanged(i),
                    child: Center(
                      child: _tabLabel(
                        theme,
                        i,
                        Color.lerp(
                          theme.onPrimaryColor,
                          theme.textColor,
                          (1 - (pos - i).abs()).clamp(0.0, 1.0),
                        )!,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _tabLabel(ThemeProvider theme, int i, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_icons[i], size: 19, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            context.tr(_tabKeys[i]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              height: 1.0,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  // ==================== نوار وضعیت آفلاین/آنلاین ====================

  Widget _buildOfflineStatusBar(
      SyncProvider syncProvider, ThemeProvider theme) {
    final Color primaryColor = theme.primaryColor;
    String statusText;
    IconData statusIcon;
    Tone tone;

    if (!syncProvider.isOnline) {
      statusText = context.tr('arena.offline');
      statusIcon = Icons.wifi_off_rounded;
      tone = Tone.peach;
    } else if (syncProvider.hasOfflineOperations) {
      statusText = context.tr(
          'arena.syncing', {'n': '${syncProvider.offlineOperationsCount}'});
      statusIcon = Icons.sync_rounded;
      tone = Tone.sky;
    } else {
      statusText = context.tr('arena.online');
      statusIcon = Icons.wifi_rounded;
      tone = Tone.mint;
    }
    final t = theme.tone(tone);
    final Color statusColor = t.fg;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.symmetric(
        horizontal: _horizontalMargin,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 12,
                color: theme.textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (syncProvider.hasOfflineOperations && syncProvider.isOnline)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: statusColor,
              ),
            ),
          if (syncProvider.isOnline)
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              color: primaryColor,
              onPressed: _refreshAllTabs,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 20,
            ),
        ],
      ),
    );
  }
}

// ==================== حلقهٔ پیشرفت ====================

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;
  final double strokeWidth;

  const _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);
    if (progress <= 0) return;
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -1.5707963, 6.2831853 * progress, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.track != track ||
      old.strokeWidth != strokeWidth;
}

// ==================== نیم‌دایرهٔ پیشرفت ====================

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;

  const _ArcPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double stroke = 16;
    final double radius = size.width / 2 - stroke / 2 - 2;
    final Offset center = Offset(size.width / 2, size.height - stroke / 2);
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, 3.1415927, 3.1415927, false, trackPaint);
    if (progress <= 0) return;
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, 3.1415927, 3.1415927 * progress, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

// ==================== گوشهٔ وارونهٔ چسبندگی تب ====================

class _InverseCornerPainter extends CustomPainter {
  final Color color;
  final bool circleOnRight;

  const _InverseCornerPainter({
    required this.color,
    required this.circleOnRight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final square = Path()..addRect(Offset.zero & size);
    final center = circleOnRight ? Offset(size.width, 0) : Offset.zero;
    final hole = Path()
      ..addOval(Rect.fromCircle(center: center, radius: size.width));
    canvas.drawPath(
      Path.combine(PathOperation.difference, square, hole),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _InverseCornerPainter old) =>
      old.color != color || old.circleOnRight != circleOnRight;
}
