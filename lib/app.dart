// lib/app.dart

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ اضافه شد

import '/features/auth/screens/login_screen.dart';
import '/features/home/screens/main_screen.dart';
import '/providers/sync_provider.dart';
import '/providers/theme_provider.dart';

class HeroApp extends StatefulWidget {
  const HeroApp({super.key});

  @override
  State<HeroApp> createState() => _HeroAppState();
}

class _HeroAppState extends State<HeroApp> {
  bool _isLoggedIn = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      // ✅ چک کردن session معتبر Supabase
      final session = Supabase.instance.client.auth.currentSession;

      if (session == null || session.isExpired) {
        // Session منقضی شده، کاربر باید دوباره لاگین کنه
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

      if (mounted) {
        setState(() {
          _isLoggedIn = userId != null && userId.isNotEmpty;
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
          home: _isLoggedIn
              ? Consumer<SyncProvider>(
                  builder: (context, syncProvider, child) {
                    if (!syncProvider.isInitialized) {
                      return Scaffold(
                        backgroundColor: themeProvider.backgroundColor,
                        body: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              CircularProgressIndicator(
                                color: Color(0xFF4A90E2),
                              ),
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
                )
              : const LoginScreen(),
        );
      },
    );
  }
}
