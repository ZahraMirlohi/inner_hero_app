// lib/app.dart

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/features/auth/screens/login_screen.dart';
import '/features/home/screens/main_screen.dart';
import '/providers/sync_provider.dart';

class HeroApp extends StatefulWidget {
  const HeroApp({super.key});

  @override
  State<HeroApp> createState() => _HeroAppState();
}

class _HeroAppState extends State<HeroApp> {
  bool _isLoggedIn = false;
  bool _isLoading = true;
  String _debugInfo = '';

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      setState(() {
        _isLoggedIn = userId != null && userId.isNotEmpty;
        _isLoading = false;
        _debugInfo = 'userId: $userId, isLoggedIn: $_isLoggedIn';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _debugInfo = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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

    return MaterialApp(
      title: 'قهرمان درون',
      debugShowCheckedModeBanner: false,

      // ✅ تنظیمات locale فارسی
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [
        Locale('fa', 'IR'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // ✅ اجبار کل اپلیکیشن به RTL
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },

      theme: ThemeData(
        fontFamily: 'Vazir',
        scaffoldBackgroundColor: Colors.grey.shade50,
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF4A90E2),
          secondary: Color(0xFFFFA500),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Vazir',
          ),
          iconTheme: IconThemeData(color: Color(0xFF1A1A2E)),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontFamily: 'Vazir'),
          bodyMedium: TextStyle(fontFamily: 'Vazir'),
          titleLarge: TextStyle(fontFamily: 'Vazir'),
        ),
      ),
      home: _isLoggedIn
          ? Consumer<SyncProvider>(
              builder: (context, syncProvider, child) {
                if (!syncProvider.isInitialized) {
                  return const Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
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
            )
          : const LoginScreen(),
    );
  }
}
