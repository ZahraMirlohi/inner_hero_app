// lib/features/arena/screens/arena_screen.dart

import 'package:flutter/material.dart';
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

  bool _isMenuOpen = false;

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
    });
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
    setState(() {
      _isMenuOpen = false;
    });
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CategorySelectionScreen()),
    ).then((_) {
      _refreshCurrentTab();
    });
  }

  void _openAddTask() {
    setState(() {
      _isMenuOpen = false;
    });
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

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: themeProvider.backgroundColor,
      body: Stack(
        children: [
          Column(
            children: [
              // هدر تقویم
              CalendarHeader(
                onDateSelected: _onDateSelected,
                selectedDate: _selectedDate,
              ),

              const SizedBox(height: 4),

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

              // کارت پیشرفت
              _buildHeroProgressCard(themeProvider),

              // تب‌بار
              _buildPillTabBar(themeProvider),

              const SizedBox(height: 4),

              // فهرست‌ها مستقیم روی پس‌زمینه (طراحی: بدون کادر بزرگ)
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    TodayTab(
                      key: _todayTabKey,
                      selectedDate: _selectedDate,
                      profileRefreshNotifier: widget.profileRefreshNotifier,
                      onProgressUpdate: updateProgress,
                    ),
                    HabitsTab(key: _habitsTabKey),
                    TasksTab(key: _tasksTabKey),
                  ],
                ),
              ),
            ],
          ),
          // محو شدن پایین لیست زیر نوار ناوبری (مثل طراحی)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 150,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      themeProvider.backgroundColor.withValues(alpha: 0),
                      themeProvider.backgroundColor,
                    ],
                    stops: const [0.0, 0.65],
                  ),
                ),
              ),
            ),
          ),
          // پردهٔ تیره پشت منوی افزودن
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_isMenuOpen,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleMenu,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  opacity: _isMenuOpen ? 1.0 : 0.0,
                  child: Container(
                    color: const Color(0xFF090909).withValues(alpha: 0.42),
                  ),
                ),
              ),
            ),
          ),
          // گزینه‌های منوی افزودن (بالای دکمه)
          Positioned(
            left: 0,
            right: 0,
            bottom: 72 + bottomInset + 98,
            child: _buildFabOptions(themeProvider),
          ),
          // دکمهٔ افزودن بالای نوار ناوبری
          Positioned(
            left: 0,
            right: 0,
            bottom: 98 + bottomInset,
            child: Center(child: _buildFloatingMenuButton(themeProvider)),
          ),
        ],
      ),
    );
  }

  // ==================== کارت پیشرفت ====================

  String _motivationKey(double p) {
    if (p >= 1.0) return 'ah.hero.t3';
    if (p >= 0.5) return 'ah.hero.t2';
    if (p > 0) return 'ah.hero.t1';
    return 'ah.hero.t0';
  }

  Widget _buildHeroProgressCard(ThemeProvider theme) {
    final double p = _currentProgress.clamp(0.0, 1.0);
    final int percent = (p * 100).round();
    final bool done = p >= 1.0;
    final Color fill = theme.primaryColor;
    final Color trackColor = theme.cardSecondaryColor;
    final mint = theme.tone(Tone.mint);

    Widget badge(IconData icon, bool active) => Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: active ? fill : trackColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon,
              size: 14,
              color: active ? theme.onPrimaryColor : theme.textSecondaryColor),
        );

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            Color.alphaBlend(fill.withValues(alpha: 0.16), theme.cardColor),
            theme.cardColor,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: theme.softShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CustomPaint(
                  painter: _ProgressRingPainter(
                    progress: p,
                    color: done ? mint.fg : fill,
                    track: trackColor,
                    strokeWidth: 8,
                  ),
                  child: Center(
                    child: Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: theme.textColor,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('ah.hero.sub'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        context.tr(_motivationKey(p)),
                        key: ValueKey(_motivationKey(p)),
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          fontWeight: FontWeight.w800,
                          color: theme.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              badge(Icons.bolt_rounded, p > 0),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Stack(
                    children: [
                      Container(height: 14, color: trackColor),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: p),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => FractionallySizedBox(
                          alignment: AlignmentDirectional.centerStart,
                          widthFactor: v,
                          child: Container(
                            height: 14,
                            decoration: BoxDecoration(
                              color: fill,
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              badge(Icons.emoji_events_rounded, done),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== تب‌بار گرد ====================

  Widget _buildPillTabBar(ThemeProvider theme) {
    final int n = _tabKeys.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.all(4),
      height: 56,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: theme.softShadow,
      ),
      child: Stack(
        children: [
          // نشانگر متحرک
          AnimatedAlign(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: AlignmentDirectional(
                -1.0 + (2.0 * _selectedIndex / (n - 1)), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / n,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < n; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _onTabChanged(i),
                    child: TweenAnimationBuilder<Color?>(
                      tween: ColorTween(
                        end: _selectedIndex == i
                            ? theme.onPrimaryColor
                            : theme.textSecondaryColor,
                      ),
                      duration: const Duration(milliseconds: 260),
                      builder: (context, color, _) => Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_icons[i], size: 20, color: color),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              context.tr(_tabKeys[i]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _selectedIndex == i
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== منوی افزودن (FAB) ====================

  Widget _buildFabOptions(ThemeProvider theme) {
    Widget option({
      required int order,
      required IconData icon,
      required String label,
      required Color bg,
      required Color fg,
      required VoidCallback onTap,
    }) {
      return AnimatedSlide(
        duration: Duration(milliseconds: 240 + order * 60),
        curve: Curves.easeOutBack,
        offset: _isMenuOpen ? Offset.zero : const Offset(0, 0.6),
        child: AnimatedOpacity(
          duration: Duration(milliseconds: 180 + order * 60),
          opacity: _isMenuOpen ? 1.0 : 0.0,
          child: IgnorePointer(
            ignoring: !_isMenuOpen,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                height: 60,
                padding: const EdgeInsetsDirectional.only(start: 22, end: 10),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF090909).withValues(alpha: 0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.textColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                      child: Icon(icon, size: 22, color: fg),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final taskTone = theme.tone(Tone.peach);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        option(
          order: 1,
          icon: Icons.fitness_center_rounded,
          label: context.tr('ah.fab.habit'),
          bg: theme.primarySoft,
          fg: theme.textColor,
          onTap: _openAddHabit,
        ),
        const SizedBox(height: 12),
        option(
          order: 0,
          icon: Icons.assignment_turned_in_rounded,
          label: context.tr('ah.fab.task'),
          bg: taskTone.bg,
          fg: taskTone.fg,
          onTap: _openAddTask,
        ),
      ],
    );
  }

  Widget _buildFloatingMenuButton(ThemeProvider theme) {
    final Color primaryColor = theme.primaryColor;
    return Semantics(
      button: true,
      label: context.tr('ah.fab.add'),
      child: GestureDetector(
        onTap: _toggleMenu,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: primaryColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: AnimatedRotation(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            turns: _isMenuOpen ? 0.125 : 0.0,
            child: Icon(
              Icons.add_rounded,
              color: theme.onPrimaryColor,
              size: 32,
            ),
          ),
        ),
      ),
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
