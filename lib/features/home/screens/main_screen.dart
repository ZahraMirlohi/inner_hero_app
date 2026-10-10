// lib/features/home/screens/main_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // ✅ اضافه کنید
import '../../../services/supabase_service.dart';
import '../../arena/screens/arena_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../chat/screens/chat_screen.dart';
import '../../explore/screens/explore_screen.dart';
import '../../../widgets/custom_bottom_nav_bar.dart';
import '../../../config/nav_items.dart';
import '../../../providers/theme_provider.dart'; // ✅ اضافه کنید

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
    _runDailyCheck();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ دریافت تم از Provider
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      // ✅ استفاده از رنگ پس‌زمینه تم به جای رنگ هاردکد شده
      backgroundColor: theme.backgroundColor,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _currentIndex,
              children: [
                ArenaScreen(
                  profileRefreshNotifier: _profileRefreshNotifier,
                ),
                const ChatScreen(),
                ExploreScreen(refreshNotifier: _exploreRefreshNotifier),
                ProfileScreen(
                  refreshNotifier: _profileRefreshNotifier,
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: true,
              child: CustomBottomNavBar(
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
                items: NavItems.items,
              ),
            ),
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
