// lib/providers/auth_provider.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoggedIn = false;
  bool _hasUsername = true;
  bool _isLoading = true;
  String? _userId;
  String? _userName;

  StreamSubscription<AuthState>? _authSubscription;

  // Getters
  bool get isLoggedIn => _isLoggedIn;
  bool get hasUsername => _hasUsername;
  bool get isLoading => _isLoading;
  String? get userId => _userId;
  String? get userName => _userName;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    await checkLoginStatus();

    // ✅ گوش دادن به تغییرات auth
    _authSubscription = _client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      print('🔔 Auth state changed: $event');

      if (event == AuthChangeEvent.signedOut) {
        _isLoggedIn = false;
        _hasUsername = false;
        _userId = null;
        _userName = null;
        _isLoading = false;
        notifyListeners();
      } else if (event == AuthChangeEvent.signedIn) {
        checkLoginStatus();
      }
    });
  }

  Future<void> checkLoginStatus() async {
    try {
      final session = _client.auth.currentSession;

      if (session == null || session.isExpired) {
        print('⚠️ Session invalid or expired');
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_id');

        _isLoggedIn = false;
        _isLoading = false;
        notifyListeners();
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId == null || userId.isEmpty) {
        _isLoggedIn = false;
        _isLoading = false;
        notifyListeners();
        return;
      }

      // چک username
      bool hasUsername = true;
      String? userName;

      try {
        final profile = await _client
            .from('profiles')
            .select('username, name')
            .eq('user_id', userId)
            .maybeSingle();

        if (profile != null) {
          userName = profile['name'] as String?;
          final username = profile['username'] as String?;
          hasUsername = username != null && username.isNotEmpty;
        } else {
          hasUsername = false;
        }
      } catch (e) {
        print('⚠️ Error checking username: $e');
        hasUsername = true;
      }

      _isLoggedIn = true;
      _hasUsername = hasUsername;
      _userId = userId;
      _userName = userName;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('❌ Error checking login status: $e');
      _isLoggedIn = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> forceLogout() async {
    print('🚪 Force logout called');

    // ✅ 1. اول state را آپدیت کن (UI سریع بره login)
    _isLoggedIn = false;
    _hasUsername = false;
    _userId = null;
    _userName = null;
    notifyListeners();

    // ✅ 2. صبر کن یک فریم تا UI عوض شود
    await Future.delayed(const Duration(milliseconds: 100));

    // ✅ 3. از Supabase خارج شو
    try {
      await _client.auth.signOut();
    } catch (e) {
      print('⚠️ Error signing out: $e');
    }

    // ✅ 4. پاک کردن user_id
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
    } catch (e) {
      print('⚠️ Error clearing prefs: $e');
    }

    print('✅ Force logout completed');
    print('   - isLoggedIn: $_isLoggedIn');
  }

  /// ✅ آپدیت کردن state پس از ذخیره username
  void setHasUsername(bool value) {
    _hasUsername = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
