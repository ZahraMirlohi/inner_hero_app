import 'package:flutter/material.dart';
import '/features/auth/screens/login_screen.dart';
import '/features/home/screens/main_screen.dart';
import '/services/supabase_service.dart'; // ← تغییر

class HeroApp extends StatefulWidget {
  const HeroApp({super.key});

  @override
  State<HeroApp> createState() => _HeroAppState();
}

class _HeroAppState extends State<HeroApp> {
  bool _isInitialized = false;
  bool _isLoggedIn = false;

  final _supabase = SupabaseService(); // ← اضافه شده

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final user = await _supabase.getCurrentUser(); // ← تغییر
    setState(() {
      _isInitialized = true;
      _isLoggedIn = user != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFF4A90E2)),
          ),
        ),
      );
    }

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
      home: _isLoggedIn ? const MainScreen() : const LoginScreen(),
    );
  }
}
