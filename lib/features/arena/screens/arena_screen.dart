// lib/features/arena/screens/arena_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dash_curved_tab_bar/dash_curved_tab_bar.dart';
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

  // ✅ انیمیشن پروگرس بار افقی
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
      backgroundColor: const Color(0xFFF7FCEB),
      body: SafeArea(
        child: Column(
          children: [
            // ============ هدر تقویم ============
            CalendarHeader(
              onDateSelected: _onDateSelected,
              selectedDate: _selectedDate,
            ),

            const SizedBox(height: 8),

            // ============ نوار وضعیت آفلاین/آنلاین ============
            Consumer<SyncProvider>(
              builder: (context, syncProvider, child) {
                if (!syncProvider.isOnline ||
                    syncProvider.hasOfflineOperations) {
                  return _buildOfflineStatusBar(syncProvider, primaryColor);
                }
                return const SizedBox.shrink();
              },
            ),

            // ============ پروگرس بار افقی زیبا ============
            _buildHorizontalProgressBar(primaryColor),

            const SizedBox(height: 12),

            // ============ تب‌ها ============
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DashCurvedTabBar(
                tabs: _tabs,
                icons: _tabs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final isSelected = _selectedIndex == index;
                  return Icon(
                    _icons[index],
                    color: isSelected
                        ? const Color(0xFF090909)
                        : const Color(0xFF73786B),
                    size: 20,
                  );
                }).toList(),
                selectedIndex: _selectedIndex,
                onTap: _onTabChanged,
                tabBarHeight: 54,
                tabBarBorderRadius: 30,
                selectedTabColor: primaryColor,
                selectedTabTextStyle: const TextStyle(
                  color: Color(0xFF090909),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                unselectedTabTextStyle: const TextStyle(
                  color: Color(0xFF73786B),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                iconPosition: IconPosition.left,
                hideTabText: false,
                hideBorders: true,
                showDivider: false,
              ),
            ),

            const SizedBox(height: 12),

            // ============ کادر سفید تب‌ها ============
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipPath(
                  clipper: const _BottomNotchClipper(),
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          primaryColor, // ✅ تغییر از Colors.white به primaryColor
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(
                              alpha: 0.25), // ✅ سایه با رنگ تم
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: IndexedStack(
                            index: _selectedIndex,
                            children: [
                              TodayTab(
                                key: _todayTabKey,
                                selectedDate: _selectedDate,
                                profileRefreshNotifier:
                                    widget.profileRefreshNotifier,
                                onProgressUpdate: updateProgress,
                              ),
                              HabitsTab(key: _habitsTabKey),
                              TasksTab(key: _tasksTabKey),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 1),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildFloatingMenuButton(primaryColor),
      bottomNavigationBar: const SizedBox(height: 100),
    );
  }

  // ==================== پروگرس بار افقی زیبا ====================

  Widget _buildHorizontalProgressBar(Color primaryColor) {
    // ✅ رنگ پروگرس بار - همیشه مشکی
    final Color progressColor = const Color(0xFF090909);

    // ✅ محاسبه درصد
    final int percent = (_currentProgress * 100).toInt();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ============================================================
          // پروگرس بار
          // ============================================================
          Stack(
            children: [
              // ریل پشتی (Track)
              Container(
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              // نوار پروگرس با انیمیشن
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double progressWidth =
                          constraints.maxWidth * _currentProgress;

                      return Stack(
                        children: [
                          // نوار پروگرس با گرادیانت مشکی
                          Container(
                            width: progressWidth,
                            height: 24,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF2A2A2A),
                                  const Color(0xFF090909),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                          ),

                          // درخشش روی نوک پروگرس
                          if (_currentProgress > 0.05 &&
                              _currentProgress < 0.98)
                            Positioned(
                              left: progressWidth - 20,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 40,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.0),
                                      Colors.white.withValues(alpha: 0.4),
                                      Colors.white.withValues(alpha: 0.0),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                ),
                              ),
                            ),

                          // نقطه درخشان متحرک روی نوک پروگرس
                          if (_currentProgress > 0.02 &&
                              _currentProgress < 0.98)
                            Positioned(
                              left: progressWidth - 20,
                              top: 6,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.6),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // آیکون‌های تزئینی روی نوار
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      // آیکون سمت چپ
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _currentProgress > 0.1
                              ? Colors.white.withValues(alpha: 0.9)
                              : Colors.grey.shade400,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.bolt,
                          size: 10,
                          color: _currentProgress > 0.1
                              ? const Color(0xFF090909)
                              : Colors.grey.shade600,
                        ),
                      ),
                      const Spacer(),
                      // آیکون سمت راست
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _currentProgress >= 1.0
                              ? Colors.white
                              : Colors.grey.shade400,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.emoji_events,
                          size: 10,
                          color: _currentProgress >= 1.0
                              ? const Color(0xFF090909)
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ============================================================
          // ✅ درصد پیشرفت زیر پروگرس بار
          // ============================================================
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // آیکون کوچک انگیزشی
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _currentProgress >= 1.0
                      ? Colors.green.withValues(alpha: 0.15)
                      : progressColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _currentProgress >= 1.0
                      ? Icons.emoji_events
                      : Icons.trending_up,
                  size: 14,
                  color: _currentProgress >= 1.0 ? Colors.green : progressColor,
                ),
              ),
              const SizedBox(width: 6),

              // درصد با رنگ برجسته
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _currentProgress >= 1.0 ? Colors.green : progressColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== Floating Menu Button ====================

  Widget _buildFloatingMenuButton(Color primaryColor) {
    // ✅ عرض کل فضا برای منوی افقی
    final double totalWidth = 320;
    final double buttonSize = 56;

    return SizedBox(
      width: totalWidth,
      height: 50, // ✅ ارتفاع ثابت برای جلوگیری از جابه‌جایی
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // ============================================================
          // دکمه "عادت جدید" - سمت چپ
          // ============================================================
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            // وقتی باز است: سمت چپ | وقتی بسته است: پشت دکمه + می‌ره مخفی
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
                  onTap: _openAddHabit,
                ),
              ),
            ),
          ),

          // ============================================================
          // دکمه "وظیفه جدید" - سمت راست
          // ============================================================
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            // وقتی باز است: سمت راست | وقتی بسته است: پشت دکمه + می‌ره مخفی
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
                  onTap: _openAddTask,
                ),
              ),
            ),
          ),

          // ============================================================
          // دکمه اصلی (+) - همیشه در پایین وسط
          // ============================================================
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
                        color: const Color(0xFF090909),
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
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          // ✅ استروک رنگی
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ آیکون رنگی در دایره کم‌رنگ
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
            // ✅ متن مشکی
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF090909), // ✅ مشکی
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

  Widget _buildOfflineStatusBar(SyncProvider syncProvider, Color primaryColor) {
    String statusText;
    IconData statusIcon;
    Color statusColor = primaryColor;

    if (!syncProvider.isOnline) {
      statusText = '📡 آفلاین - تغییرات در صف ذخیره می‌شوند';
      statusIcon = Icons.wifi_off;
      statusColor = primaryColor;
    } else if (syncProvider.hasOfflineOperations) {
      statusText =
          '🔄 ${syncProvider.offlineOperationsCount} تغییرات در حال همگام‌سازی...';
      statusIcon = Icons.sync;
      statusColor = primaryColor;
    } else {
      statusText = '✅ آنلاین';
      statusIcon = Icons.wifi;
      statusColor = primaryColor;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF090909),
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
              color: const Color(0xFFB0CC5D),
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
