// lib/features/arena/screens/arena_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/calendar_header.dart';
import 'today_tab.dart';
import 'habits_tab.dart';
import 'tasks_tab.dart';
import '/providers/sync_provider.dart';

class ArenaScreen extends StatefulWidget {
  final ValueNotifier<int>? profileRefreshNotifier;

  const ArenaScreen({super.key, this.profileRefreshNotifier});

  @override
  State<ArenaScreen> createState() => _ArenaScreenState();
}

class _ArenaScreenState extends State<ArenaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();

  // ✅ استفاده از GlobalKey به صورت بدون نوع یا با نوع State
  final GlobalKey _todayTabKey = GlobalKey();
  final GlobalKey _habitsTabKey = GlobalKey();
  final GlobalKey _tasksTabKey = GlobalKey();

  // ✅ برای جلوگیری از ریفرش‌های مکرر
  bool _isRefreshing = false;
  DateTime? _lastRefreshTime;
  static const Duration _minRefreshInterval = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // ✅ گوش دادن به تغییرات تب
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _onTabChanged(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ✅ متد برای ریفرش پروفایل از داخل میدان
  void _refreshProfile() {
    if (widget.profileRefreshNotifier != null) {
      widget.profileRefreshNotifier!.value++;
      print(
        '🔄 Profile refresh triggered from Arena: ${widget.profileRefreshNotifier!.value}',
      );
    }
  }

  // ✅ متد برای تغییر تاریخ
  void _onDateSelected(DateTime date) {
    // ✅ اطمینان از اینکه تاریخ بدون ساعت است
    final selectedDate = DateTime(date.year, date.month, date.day);

    setState(() {
      _selectedDate = selectedDate;
    });

    // ✅ ریفرش تب Today با تاریخ جدید
    final todayTabState = _todayTabKey.currentState as TodayTabState?;
    todayTabState?.refreshData();
  }

  // ✅ متد برای تغییر تب
  void _onTabChanged(int index) {
    // ✅ وقتی به تب امروز می‌رویم، داده‌ها را به‌روزرسانی کن
    if (index == 0) {
      final todayTabState = _todayTabKey.currentState as TodayTabState?;
      todayTabState?.refreshData();
    } else if (index == 1) {
      final habitsTabState = _habitsTabKey.currentState as HabitsTabState?;
      habitsTabState?.refreshData();
    } else if (index == 2) {
      final tasksTabState = _tasksTabKey.currentState as TasksTabState?;
      tasksTabState?.refreshData();
    }
  }

  // ✅ متد برای ریفرش همه تب‌ها
  void _refreshAllTabs() {
    final now = DateTime.now();
    if (_lastRefreshTime != null &&
        now.difference(_lastRefreshTime!) < _minRefreshInterval) {
      return;
    }
    _lastRefreshTime = now;

    if (_isRefreshing) return;
    _isRefreshing = true;

    final todayTabState = _todayTabKey.currentState as TodayTabState?;
    todayTabState?.refreshData();

    final habitsTabState = _habitsTabKey.currentState as HabitsTabState?;
    habitsTabState?.refreshData();

    final tasksTabState = _tasksTabKey.currentState as TasksTabState?;
    tasksTabState?.refreshData();

    Future.delayed(const Duration(milliseconds: 300), () {
      _isRefreshing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // ✅ نشانگر وضعیت آفلاین و تعداد عملیات در صف
          Consumer<SyncProvider>(
            builder: (context, syncProvider, child) {
              if (!syncProvider.isOnline || syncProvider.hasOfflineOperations) {
                return _buildOfflineStatusBar(syncProvider);
              }
              return const SizedBox.shrink();
            },
          ),

          // ✅ هدر تقویم
          CalendarHeader(
            onDateSelected: _onDateSelected,
            selectedDate: _selectedDate,
          ),

          // ✅ تب‌ها
          Expanded(
            child: Column(
              children: [
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFF4A90E2),
                    indicatorWeight: 3,
                    labelColor: const Color(0xFF4A90E2),
                    unselectedLabelColor: Colors.grey.shade500,
                    labelStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: const [
                      Tab(text: 'امروز'),
                      Tab(text: 'عادت‌ها'),
                      Tab(text: 'تسک‌ها'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      TodayTab(
                        key: _todayTabKey,
                        selectedDate: _selectedDate,
                        profileRefreshNotifier: widget.profileRefreshNotifier,
                      ),
                      HabitsTab(key: _habitsTabKey),
                      TasksTab(key: _tasksTabKey),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== نوار وضعیت آفلاین ====================

  Widget _buildOfflineStatusBar(SyncProvider syncProvider) {
    String statusText;
    IconData statusIcon;
    Color statusColor;

    if (!syncProvider.isOnline) {
      statusText = '📡 آفلاین - تغییرات در صف ذخیره می‌شوند';
      statusIcon = Icons.wifi_off;
      statusColor = Colors.orange;
    } else if (syncProvider.hasOfflineOperations) {
      statusText =
          '🔄 ${syncProvider.offlineOperationsCount} تغییرات در حال همگام‌سازی...';
      statusIcon = Icons.sync;
      statusColor = Colors.blue;
    } else {
      statusText = '✅ آنلاین';
      statusIcon = Icons.wifi;
      statusColor = Colors.green;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: statusColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
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
                color: statusColor,
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
          // ✅ دکمه ریفرش دستی
          if (syncProvider.isOnline)
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              color: statusColor,
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
