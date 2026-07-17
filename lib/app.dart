// lib/app.dart

import 'package:flutter/material.dart';
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
    print('🔵 [APP] initState called');
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    print('🔵 [APP] _checkLoginStatus started');

    try {
      final prefs = await SharedPreferences.getInstance();
      print('🔵 [APP] SharedPreferences loaded');

      final userId = prefs.getString('user_id');
      print('🔵 [APP] userId from SharedPreferences: $userId');

      setState(() {
        _isLoggedIn = userId != null && userId.isNotEmpty;
        _isLoading = false;
        _debugInfo = 'userId: $userId, isLoggedIn: $_isLoggedIn';
        print(
          '🔵 [APP] State updated: isLoggedIn=$_isLoggedIn, isLoading=$_isLoading',
        );
      });
    } catch (e) {
      print('🔴 [APP] Error in _checkLoginStatus: $e');
      setState(() {
        _isLoading = false;
        _debugInfo = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
      '🔵 [APP] build called, isLoading=$_isLoading, isLoggedIn=$_isLoggedIn',
    );

    if (_isLoading) {
      print('🟡 [APP] Showing loading screen');
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

    print('🟢 [APP] Building main app with isLoggedIn=$_isLoggedIn');

    return MaterialApp(
      title: 'قهرمان درون',
      debugShowCheckedModeBanner: false,
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
                print(
                  '🟢 [APP] Consumer builder called, syncProvider.isInitialized=${syncProvider.isInitialized}',
                );

                if (!syncProvider.isInitialized) {
                  print(
                    '🟡 [APP] SyncProvider not initialized, showing loading',
                  );
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

                print('🟢 [APP] SyncProvider initialized, showing MainScreen');
                return const MainScreen();
              },
            )
          : const LoginScreen(),
    );
  }
}
