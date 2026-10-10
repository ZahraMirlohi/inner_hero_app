// lib/app.dart

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/features/auth/screens/login_screen.dart';
import '/features/home/screens/main_screen.dart';
import '/providers/sync_provider.dart';
import '/providers/theme_provider.dart';
import '/features/profile/screens/username_setup_screen.dart';
import '/services/supabase_service.dart';
import 'dart:async';

class HeroApp extends StatefulWidget {
  const HeroApp({super.key});

  @override
  State<HeroApp> createState() => _HeroAppState();
}

class _HeroAppState extends State<HeroApp> {
  bool _isLoggedIn = false;
  bool _isLoading = true;
  bool _hasUsername = true; // ✅ جدید
  String? _userId; // ✅ جدید
  String? _userName; // ✅ جدید

  final SupabaseService _supabase = SupabaseService();
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();

    // ✅ گوش دادن به تغییرات auth (logout/login)
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        final event = data.event;
        print('🔔 Auth state changed: $event');

        if (event == AuthChangeEvent.signedOut) {
          // کاربر خارج شد
          if (mounted) {
            setState(() {
              _isLoggedIn = false;
              _hasUsername = false;
              _userId = null;
              _userName = null;
            });
          }
        } else if (event == AuthChangeEvent.signedIn) {
          // کاربر وارد شد
          _checkLoginStatus();
        }
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    try {
      // ✅ چک کردن session معتبر Supabase
      final session = Supabase.instance.client.auth.currentSession;

      if (session == null || session.isExpired) {
        print('⚠️ Session invalid or expired, clearing local state...');
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_id');

        if (mounted) {
          setState(() {
            _isLoggedIn = false;
            _isLoading = false;
          });
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId == null || userId.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoggedIn = false;
            _isLoading = false;
          });
        }
        return;
      }

      // ✅ چک کردن username
      bool hasUsername = true;
      String? userName;

      try {
        final profile = await _supabase.client
            .from('profiles')
            .select('username, name')
            .eq('user_id', userId)
            .maybeSingle();

        if (profile != null) {
          userName = profile['name'] as String?;
          final username = profile['username'] as String?;
          hasUsername = username != null && username.isNotEmpty;
        } else {
          // پروفایل وجود ندارد → باید username انتخاب شود
          hasUsername = false;
        }
      } catch (e) {
        print('⚠️ Error checking username: $e');
        // در صورت خطا، فرض می‌کنیم username دارد تا اپ لود شود
        hasUsername = true;
      }

      if (mounted) {
        setState(() {
          _isLoggedIn = true;
          _hasUsername = hasUsername;
          _userId = userId;
          _userName = userName;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error checking login status: $e');
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircularProgressIndicator(color: Color(0xFF4A90E2)),
                SizedBox(height: 16),
                Text(
                  'در حال بارگذاری...',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'قهرمان درون',
          debugShowCheckedModeBanner: false,
          locale: const Locale('fa', 'IR'),
          supportedLocales: const [
            Locale('fa', 'IR'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            );
          },
          theme: ThemeData(
            fontFamily: 'Vazir',
            scaffoldBackgroundColor: themeProvider.backgroundColor,
            useMaterial3: true,
            colorScheme: ColorScheme.light(
              primary: themeProvider.primaryColor,
              secondary: themeProvider.primaryColor,
              surface: themeProvider.surfaceColor,
              background: themeProvider.backgroundColor,
              onPrimary: themeProvider.textColor,
              onSurface: themeProvider.textColor,
              onBackground: themeProvider.textColor,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: themeProvider.surfaceColor,
              elevation: 0,
              centerTitle: true,
              titleTextStyle: TextStyle(
                color: themeProvider.textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Vazir',
              ),
              iconTheme: IconThemeData(color: themeProvider.textColor),
            ),
            textTheme: TextTheme(
              bodyLarge: TextStyle(
                  fontFamily: 'Vazir', color: themeProvider.textColor),
              bodyMedium: TextStyle(
                  fontFamily: 'Vazir', color: themeProvider.textColor),
              titleLarge: TextStyle(
                  fontFamily: 'Vazir', color: themeProvider.textColor),
            ),
            dividerColor: themeProvider.textColor.withValues(alpha: 0.1),
            cardColor: themeProvider.surfaceColor,
            dialogBackgroundColor: themeProvider.surfaceColor,
            listTileTheme: ListTileThemeData(
              textColor: themeProvider.textColor,
              iconColor: themeProvider.textColor,
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return themeProvider.primaryColor;
                }
                return null;
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return themeProvider.primaryColor.withValues(alpha: 0.5);
                }
                return null;
              }),
            ),
          ),
          home: _buildHome(),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
// 🏠 تعیین صفحه اصلی بر اساس وضعیت کاربر
// ═══════════════════════════════════════════════════════════
  Widget _buildHome() {
    // ۱. اگر لاگین نکرده → صفحه ورود
    if (!_isLoggedIn) {
      return const LoginScreen();
    }

    // ۲. اگر username ندارد → صفحه انتخاب username
    if (!_hasUsername && _userId != null) {
      return UsernameSetupScreen(
        userId: _userId!,
        currentUsername: null,
        isFirstTime: true,
        onCompleted: () {
          // بعد از ذخیره username، state را آپدیت کن
          setState(() {
            _hasUsername = true;
          });
        },
      );
    }

    // ۳. در غیر این صورت → صفحه اصلی
    return Consumer<SyncProvider>(
      builder: (context, syncProvider, child) {
        if (!syncProvider.isInitialized) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(color: Color(0xFF4A90E2)),
                  SizedBox(height: 16),
                  Text(
                    'در حال بارگذاری اطلاعات...',
                    style: TextStyle(color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          );
        }
        return const MainScreen();
      },
    );
  }
}
