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

  final List<String> _tabs = ['امروز', 'عادت‌ها', 'وظیفه‌ها'];
  final List<IconData> _icons = [
    Icons.today_outlined,
    Icons.fitness_center_outlined,
    Icons.assignment_outlined,
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
    _updateProgressAnimated(0.65);
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
    final Color primaryColor = themeProvider.primaryColor;

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
              if (!syncProvider.isOnline || syncProvider.hasOfflineOperations) {
                return _buildOfflineStatusBar(syncProvider, themeProvider);
              }
              return const SizedBox.shrink();
            },
          ),

          // پروگرس بار
          _buildHorizontalProgressBar(themeProvider),

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
          // دکمهٔ افزودن بالای نوار ناوبری
          Positioned(
            left: 0,
            right: 0,
            bottom: 98 + MediaQuery.of(context).padding.bottom,
            child: Center(child: _buildFloatingMenuButton(themeProvider)),
          ),
        ],
      ),
    );
  }

  // ==================== پروگرس بار افقی ====================

  Widget _buildHorizontalProgressBar(ThemeProvider theme) {
    final int percent = (_currentProgress * 100).toInt();
    final bool done = _currentProgress >= 1.0;
    final Color fill = theme.primaryColor;
    final trackColor = theme.cardSecondaryColor;
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: theme.softShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              badge(Icons.bolt_rounded, _currentProgress > 0),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Stack(
                    children: [
                      Container(height: 14, color: trackColor),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: _currentProgress.clamp(0.0, 1.0)),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => FractionallySizedBox(
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
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: done ? mint.bg : theme.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  done ? Icons.emoji_events_rounded : Icons.trending_up_rounded,
                  size: 16,
                  color: done ? mint.fg : theme.textColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: theme.textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== تب‌بار گرد ====================

  Widget _buildPillTabBar(ThemeProvider theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.all(4),
      height: 56,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: theme.softShadow,
      ),
      child: Row(
        children: [
          for (var i = 0; i < _tabs.length; i++)
            Expanded(
              flex: _selectedIndex == i ? 13 : 10,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _onTabChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _selectedIndex == i
                        ? theme.primaryColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _icons[i],
                        size: 20,
                        color: _selectedIndex == i
                            ? theme.onPrimaryColor
                            : theme.textSecondaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _tabs[i],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _selectedIndex == i
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _selectedIndex == i
                              ? theme.onPrimaryColor
                              : theme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== Floating Menu Button ====================

  Widget _buildFloatingMenuButton(ThemeProvider theme) {
    final Color primaryColor = theme.primaryColor;
    final double totalWidth = 320;
    final double buttonSize = 56;

    return SizedBox(
      width: totalWidth,
      height: 50,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            left: _isMenuOpen ? 0 : (totalWidth / 2) - 40,
            bottom: _isMenuOpen ? 0 : -30,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isMenuOpen ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_isMenuOpen,
                child: _buildSideMenuItem(
                  icon: Icons.fitness_center,
                  label: 'عادت جدید',
                  color: primaryColor,
                  theme: theme,
                  onTap: _openAddHabit,
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            right: _isMenuOpen ? 0 : (totalWidth / 2) - 40,
            bottom: _isMenuOpen ? 0 : -30,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isMenuOpen ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_isMenuOpen,
                child: _buildSideMenuItem(
                  icon: Icons.assignment,
                  label: 'وظیفه جدید',
                  color: primaryColor,
                  theme: theme,
                  onTap: _openAddTask,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                onTap: _toggleMenu,
                child: AnimatedRotation(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  turns: _isMenuOpen ? 0.125 : 0.0,
                  child: Container(
                    width: buttonSize,
                    height: buttonSize,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(
                          scale: animation,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: Icon(
                        _isMenuOpen ? Icons.close : Icons.add,
                        key: ValueKey(_isMenuOpen),
                        color: theme.isDarkMode
                            ? const Color(0xFF090909)
                            : const Color(0xFF090909),
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ویجت دکمه‌های کناری ====================

  Widget _buildSideMenuItem({
    required IconData icon,
    required String label,
    required Color color,
    required ThemeProvider theme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(alpha: theme.isDarkMode ? 0.3 : 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
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
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFB0CC5D),
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

// ==================== ویجت‌های کمکی تب‌بار ====================

class _TabBarItem {
  final IconData icon;
  final String label;

  const _TabBarItem({
    required this.icon,
    required this.label,
  });
}

class _CustomTabBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<_TabBarItem> items;
  final Color primaryColor;
  final ThemeProvider themeProvider;

  final double spacing;
  final double height;
  final double selectedCircleSize;

  const _CustomTabBar({
    required this.currentIndex,
    required this.onTap,
    required this.items,
    required this.primaryColor,
    required this.themeProvider,
    this.spacing = 8.0,
    this.height = 62.0,
    this.selectedCircleSize = 46.0,
  });

  @override
  State<_CustomTabBar> createState() => _CustomTabBarState();
}

class _CustomTabBarState extends State<_CustomTabBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;

  static const double _horizontalPadding = 8;
  static const double _iconSize = 20;
  static const double _selectedIconSize = 20;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: widget.currentIndex.toDouble(),
      end: widget.currentIndex.toDouble(),
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void didUpdateWidget(_CustomTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentIndex != widget.currentIndex) {
      _slideAnimation = Tween<double>(
        begin: oldWidget.currentIndex.toDouble(),
        end: widget.currentIndex.toDouble(),
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeInOutCubic,
        ),
      );
      _scaleAnimation = Tween<double>(
        begin: 0.6,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOutBack,
        ),
      );
      _animationController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.themeProvider;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: LayoutBuilder(
          builder: (context, outerConstraints) {
            final double availableWidth =
                outerConstraints.maxWidth - (_horizontalPadding * 2);

            final double totalSpacing =
                widget.spacing * (widget.items.length - 1);
            final double itemWidth =
                (availableWidth - totalSpacing) / widget.items.length;

            return Container(
              height: widget.height,
              padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(widget.height / 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: theme.isDarkMode ? 0.3 : 0.06,
                    ),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: theme.isDarkMode ? 0.4 : 0.10,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: theme.isDarkMode ? 0.3 : 0.08,
                    ),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _slideAnimation,
                    builder: (context, child) {
                      final double progress = _slideAnimation.value;
                      final double leftPosition =
                          progress * (itemWidth + widget.spacing);

                      return Positioned(
                        left: leftPosition,
                        top: (widget.height - widget.selectedCircleSize) / 2,
                        child: AnimatedBuilder(
                          animation: _scaleAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _scaleAnimation.value,
                              child: Container(
                                width: itemWidth,
                                height: widget.selectedCircleSize,
                                decoration: BoxDecoration(
                                  color: widget.primaryColor,
                                  borderRadius: BorderRadius.circular(
                                    widget.selectedCircleSize / 2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      widget.items[widget.currentIndex].icon,
                                      color: const Color(0xFF090909),
                                      size: _selectedIconSize,
                                    ),
                                    const SizedBox(width: 5),
                                    Directionality(
                                      textDirection: TextDirection.rtl,
                                      child: Text(
                                        widget.items[widget.currentIndex].label,
                                        style: const TextStyle(
                                          color: Color(0xFF090909),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: List.generate(widget.items.length, (index) {
                      final isActive = index == widget.currentIndex;

                      return Padding(
                        padding: EdgeInsets.only(
                          right: index < widget.items.length - 1
                              ? widget.spacing
                              : 0,
                        ),
                        child: GestureDetector(
                          onTap: () {
                            if (widget.currentIndex != index) {
                              widget.onTap(index);
                            }
                          },
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox(
                            width: itemWidth,
                            height: widget.height,
                            child: isActive
                                ? const SizedBox()
                                : Center(
                                    child: Icon(
                                      widget.items[index].icon,
                                      color: theme.textSecondaryColor,
                                      size: _iconSize,
                                    ),
                                  ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BottomNotchClipper extends CustomClipper<Path> {
  const _BottomNotchClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    final double notchRadius = 40;
    final double notchCenterX = size.width / 2;

    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.quadraticBezierTo(size.width, 0, size.width, 16);
    path.lineTo(size.width, size.height - 16);
    path.quadraticBezierTo(
        size.width, size.height, size.width - 16, size.height);
    path.lineTo(notchCenterX + notchRadius + 8, size.height);
    path.arcToPoint(
      Offset(notchCenterX - notchRadius - 8, size.height),
      radius: Radius.circular(notchRadius + 8),
      clockwise: false,
    );
    path.lineTo(16, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - 16);
    path.lineTo(0, 16);
    path.quadraticBezierTo(0, 0, 0, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) {
    return true;
  }
}
