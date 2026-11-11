// lib/features/home/screens/main_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../l10n/app_strings.dart';
import '../../../services/supabase_service.dart';
import '../../arena/screens/arena_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../chat/screens/chat_screen.dart';
import '../../explore/screens/explore_screen.dart';
import '../../../widgets/custom_bottom_nav_bar.dart';
import '../../../config/nav_items.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/notification_service.dart';
import '../widgets/new_request_popup.dart';
import '../../../providers/theme_provider.dart'; // اضافه کنید

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _pendingRequests = 0;
  bool _popupDismissed = false;
  bool _inBackground = false;
  RealtimeChannel? _reqChannel;
  String? _uid;

  int _currentIndex = 0;
  final List<int> _tabHistory = []; // برای دکمه‌ی بک: یک مرحله برگشت
  DateTime? _lastBack;

  final ValueNotifier<int> _profileRefreshNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> _exploreRefreshNotifier = ValueNotifier<int>(0);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reqChannel?.unsubscribe();
    _profileRefreshNotifier.dispose();
    _exploreRefreshNotifier.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runDailyCheck();
    _initRequests();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inBackground = state != AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      _popupDismissed = false;
      _refreshPending();
    }
  }

  bool get _allowRequestAlerts =>
      SettingsProvider.current?.notifRequests ?? true;

  Future<void> _initRequests() async {
    try {
      final user = await SupabaseService().getCurrentUser();
      if (user == null) return;
      _uid = user.id;
      await _refreshPending();
      _reqChannel = Supabase.instance.client
          .channel('main_requests_${user.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'buddy_requests',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'to_user_id',
              value: user.id,
            ),
            callback: (_) async {
              _popupDismissed = false;
              await _refreshPending();
              if (_inBackground && _allowRequestAlerts && mounted) {
                NotificationService.instance.showNow(
                  3001,
                  'Dacko',
                  context.tr('mp.req.one'),
                  channel: 'buddy_requests',
                  channelName: 'Requests',
                );
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('request listener failed: $e');
    }
  }

  Future<void> _refreshPending() async {
    final id = _uid;
    if (id == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('buddy_requests')
          .select('id')
          .eq('to_user_id', id)
          .eq('status', 'pending');
      if (mounted) setState(() => _pendingRequests = (rows as List).length);
    } catch (_) {}
  }

  void _openRequests() {
    setState(() {
      _popupDismissed = true;
      if (_currentIndex != 1) _tabHistory.add(_currentIndex);
      _currentIndex = 1;
    });
    ChatScreen.openRequestsSignal.value++;
  }

  @override
  Widget build(BuildContext context) {
    // دریافت تم از Provider
    final theme = Provider.of<ThemeProvider>(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_tabHistory.isNotEmpty) {
          setState(() => _currentIndex = _tabHistory.removeLast());
          return;
        }
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return;
        }
        // روی خانه: برای خروج دو بار بک
        final now = DateTime.now();
        if (_lastBack != null &&
            now.difference(_lastBack!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
        } else {
          _lastBack = now;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('برای خروج دوباره بزنید'),
            duration: Duration(seconds: 2),
          ));
        }
      },
      child: Scaffold(
      // استفاده از رنگ پس‌زمینه تم به جای رنگ هاردکد شده
      backgroundColor:
          (_currentIndex == 0)
              ? theme.primaryColor
              : theme.backgroundColor,
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
          if (_pendingRequests > 0 &&
              !_popupDismissed &&
              _currentIndex != 1 &&
              _allowRequestAlerts)
            Positioned(
              top: 0,
              left: 24,
              right: 24,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: NewRequestPopup(
                      count: _pendingRequests,
                      onTap: _openRequests,
                      onClose: () => setState(() => _popupDismissed = true),
                    ),
                  ),
                ),
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
                    if (index != _currentIndex) {
                      _tabHistory.add(_currentIndex);
                      if (_tabHistory.length > 10) _tabHistory.removeAt(0);
                    }
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
      print('Error in daily check: $e');
    }
  }
}
