// lib/features/home/screens/main_screen.dart

import 'package:flutter/material.dart';
import '../../../services/supabase_service.dart';
import '../../arena/screens/arena_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../chat/screens/chat_screen.dart';
import '../../explore/screens/explore_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final ValueNotifier<int> _profileRefreshNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> _exploreRefreshNotifier = ValueNotifier<int>(0);

  @override
  void dispose() {
    _profileRefreshNotifier.dispose();
    _exploreRefreshNotifier.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // ✅ بررسی روزانه در زمان بیدار شدن اپ
    _runDailyCheck();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ArenaScreen(
            profileRefreshNotifier: _profileRefreshNotifier,
          ), // ✅ درست ارسال شده
          const ChatScreen(),
          ExploreScreen(refreshNotifier: _exploreRefreshNotifier),
          ProfileScreen(
            refreshNotifier: _profileRefreshNotifier,
          ), // ✅ درست ارسال شده
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });

          if (index == 3) {
            _profileRefreshNotifier.value++;
          }
          if (index == 2) {
            _exploreRefreshNotifier.value++;
          }
        },
        selectedItemColor: const Color(0xFF4A90E2),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_outlined),
            activeIcon: Icon(Icons.emoji_events),
            label: 'میدان',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_outlined),
            activeIcon: Icon(Icons.chat),
            label: 'گپ و گفتگو',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'اکسپلور',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'پروفایل',
          ),
        ],
      ),
    );
  }

  Future<void> _runDailyCheck() async {
    try {
      final supabase = SupabaseService();
      final user = await supabase.getCurrentUser();
      if (user != null) {
        await supabase.runDailyCheck(user.id);
      }
    } catch (e) {
      print('❌ Error in daily check: $e');
    }
  }
}
