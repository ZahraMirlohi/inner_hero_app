import 'package:flutter/material.dart';
import '../widgets/calendar_header.dart';
import 'today_tab.dart';
import 'habits_tab.dart';
import 'tasks_tab.dart';

class ArenaScreen extends StatefulWidget {
  const ArenaScreen({super.key});

  @override
  State<ArenaScreen> createState() => _ArenaScreenState();
}

class _ArenaScreenState extends State<ArenaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          CalendarHeader(
            onDateSelected: _onDateSelected,
            selectedDate: _selectedDate,
          ),
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
                      TodayTab(selectedDate: _selectedDate),
                      const HabitsTab(),
                      const TasksTab(),
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
}
