// lib/providers/auth_provider.dart
//
// مدیریت ورود/ثبت‌نام/خروج. تفاوت با نسخهٔ قبلی:
//  - نشست از خود Supabase خوانده می‌شود (نه کلید ذخیره‌شده)؛ شرط مسابقهٔ ورود از بین رفت.
//  - آفلاین هم وارد برنامه می‌شویم (نشست منقضی تا وقتی اینترنت نیست باعث خروج نمی‌شود).
//  - ثبت‌نام با تایید ایمیل، ورود با گوگل، بازیابی رمز و سوال‌های اولین ورود.
//  - کلید user_id در SharedPreferences برای سازگاری با کدهای قدیمی هنوز نوشته می‌شود.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

import '../services/supabase_service.dart';

enum SignUpResult { signedIn, needsEmailConfirmation }

/// پاسخ‌های سوال‌های معرفی (همه اختیاری)
class OnboardingAnswers {
  final String? goal;
  final String? firstTask;
  final String? energy; // intro | mixed | extro
  final String? style; // planner | mixed | flow
  final String wakeTime; // HH:mm
  final String remindTime; // HH:mm
  final String language;

  const OnboardingAnswers({
    this.goal,
    this.firstTask,
    this.energy,
    this.style,
    required this.wakeTime,
    required this.remindTime,
    required this.language,
  });

  Map<String, dynamic> toJson() => {
        'goals': goal == null ? <String>[] : [goal],
        'goal': goal,
        'first_task': firstTask,
        'energy': energy,
        'planning_style': style,
        'wake_time': wakeTime,
        'remind_time': remindTime,
        'language': language,
      };
}

class AuthProvider extends ChangeNotifier {
  /// آدرس بازگشت از گوگل / لینک بازیابی رمز (باید در Supabase هم ثبت شود)
  /// تا وقتی گوگل در Supabase فعال نشده، دکمه‌اش نمایش داده نمی‌شود
  static const bool googleEnabled = false;

  static const String redirectUrl = 'io.supabase.innerhero://login-callback/';

  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoggedIn = false;
  bool _hasUsername = true;
  bool _isLoading = true;
  bool _onboardingDone = true;
  bool _needsPasswordReset = false;
  bool _justSignedUp = false;
  bool _loadingUser = false;
  // وسط بازیابی رمز، نشستِ ساخته‌شده با کد نباید کاربر را وارد برنامه کند
  bool _holdSignIn = false;
  int _failedLogins = 0;
  DateTime? _lockUntil;
  String? _userId;
  String? _userName;
  String? _userEmail;

  StreamSubscription<AuthState>? _authSubscription;

  bool get isLoggedIn => _isLoggedIn;
  bool get hasUsername => _hasUsername;
  bool get isLoading => _isLoading;
  bool get onboardingDone => _onboardingDone;
  bool get needsPasswordReset => _needsPasswordReset;
  String? get userId => _userId;
  String? get userName => _userName;
  String? get userEmail => _userEmail;

  AuthProvider() {
    _init();
  }

  // ───────────────────────── راه‌اندازی ─────────────────────────

  Future<void> _init() async {
    _authSubscription = _client.auth.onAuthStateChange.listen(_onAuthEvent);
    await checkLoginStatus();
  }

  Future<void> _onAuthEvent(AuthState data) async {
    final event = data.event;
    if (kDebugMode) debugPrint('Auth event: $event');

    switch (event) {
      case AuthChangeEvent.signedOut:
        _resetState();
        notifyListeners();
        break;
      case AuthChangeEvent.passwordRecovery:
        _needsPasswordReset = true;
        notifyListeners();
        break;
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.initialSession:
        if (_holdSignIn) break;
        final user = data.session?.user;
        if (user != null && user.id != _userId) {
          await _loadForUser(user);
        }
        break;
      default:
        break;
    }
  }

  void _resetState() {
    _isLoggedIn = false;
    _hasUsername = false;
    _onboardingDone = true;
    _needsPasswordReset = false;
    _justSignedUp = false;
    _userId = null;
    _userName = null;
    _userEmail = null;
    _isLoading = false;
  }

  /// وضعیت ورود را از نشست فعلی می‌خواند (بدون نیاز به اینترنت)
  Future<void> checkLoginStatus() async {
    try {
      final user = _client.auth.currentSession?.user;
      if (user == null) {
        _resetState();
        notifyListeners();
        return;
      }
      await _loadForUser(user);
    } catch (e) {
      if (kDebugMode) debugPrint('checkLoginStatus error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadForUser(User user) async {
    if (_loadingUser) return;
    _loadingUser = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = user.id;

      _userId = uid;
      _userEmail = user.email;
      _isLoggedIn = true;
      await prefs.setString('user_id', uid);

      // ۱) اول از حافظهٔ محلی (فوری، بدون شبکه)
      final cachedUsername = prefs.getBool('has_username_$uid');
      final cachedOnboarding = prefs.getBool('onboarding_done_$uid');
      _userName = prefs.getString('user_name_$uid');
      _hasUsername = cachedUsername ?? true;
      _onboardingDone = _justSignedUp ? false : (cachedOnboarding ?? true);

      final needsRemoteWait = cachedUsername == null || cachedOnboarding == null;

      if (!needsRemoteWait) {
        // حالت عادی: بدون انتظار وارد می‌شویم و در پس‌زمینه تازه‌سازی می‌کنیم
        _isLoading = false;
        notifyListeners();
        unawaited(_refreshRemoteState(uid));
        return;
      }

      // ۲) ورود تازه روی این گوشی: کمی منتظر سرور می‌مانیم (حداکثر ۵ ثانیه)
      _isLoading = true;
      notifyListeners();
      await _refreshRemoteState(uid, timeout: const Duration(seconds: 5));
      _isLoading = false;
      notifyListeners();
    } finally {
      _loadingUser = false;
    }
  }

  /// خواندن username و وضعیت معرفی از سرور؛ هر خطایی فقط نادیده گرفته می‌شود (آفلاین هم کار کند)
  Future<void> _refreshRemoteState(
    String uid, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    var changed = false;

    try {
      final profile = await _client
          .from('profiles')
          .select('username, name')
          .eq('user_id', uid)
          .maybeSingle()
          .timeout(timeout);

      if (profile != null) {
        final username = profile['username'] as String?;
        final name = profile['name'] as String?;
        final has = username != null && username.isNotEmpty;
        await prefs.setBool('has_username_$uid', has);
        if (name != null) await prefs.setString('user_name_$uid', name);
        if (_userId == uid) {
          if (_hasUsername != has || _userName != name) changed = true;
          _hasUsername = has;
          _userName = name;
        }
      } else {
        // پروفایل هنوز ساخته نشده (مثلاً تریگر SQL اجرا نشده): بعد از ثبت‌نام می‌سازیمش
        await _ensureProfile(uid, _userEmail ?? '', _userName ?? '');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('profile refresh skipped: $e');
    }

    try {
      final row = await _client
          .from('user_onboarding')
          .select('user_id')
          .eq('user_id', uid)
          .maybeSingle()
          .timeout(timeout);

      if (row != null) {
        await prefs.setBool('onboarding_done_$uid', true);
        if (_userId == uid && !_onboardingDone) {
          _onboardingDone = true;
          changed = true;
        }
      } else if (prefs.getBool('onboarding_done_$uid') == null && !_justSignedUp) {
        // کاربر جدید روی این حساب: معرفی را نشان بده
        await prefs.setBool('onboarding_done_$uid', false);
        if (_userId == uid && _onboardingDone) {
          _onboardingDone = false;
          changed = true;
        }
      }
    } catch (e) {
      // جدول هنوز ساخته نشده یا آفلاین: اگر کاربر تازه ثبت‌نام نکرده، مزاحمش نمی‌شویم
      if (kDebugMode) debugPrint('onboarding refresh skipped: $e');
    }

    // پاسخ‌هایی که قبلاً به‌خاطر آفلاین بودن ارسال نشده بودند
    await _flushPendingOnboarding(uid);

    if (changed) notifyListeners();
  }

  // ───────────────────────── ورود و ثبت‌نام ─────────────────────────

  Future<void> signInWithEmail(String email, String password) async {
    // قفل کوتاه سمت برنامه (علاوه بر محدودیت سرور) برای حدس‌زدن رمز
    final lock = _lockUntil;
    if (lock != null && DateTime.now().isBefore(lock)) {
      throw AuthException('too many attempts');
    }
    try {
      await _client.auth
          .signInWithPassword(email: email.trim(), password: password);
      _failedLogins = 0;
      _lockUntil = null;
    } on AuthException catch (e) {
      if (e.code == 'invalid_credentials' ||
          e.message.toLowerCase().contains('invalid login')) {
        if (++_failedLogins >= 5) {
          _failedLogins = 0;
          _lockUntil = DateTime.now().add(const Duration(seconds: 60));
        }
      }
      rethrow;
    }
    // بقیه‌اش را رویداد signedIn انجام می‌دهد
  }

  /// تایید ایمیل ثبت‌نام با کد ۶ رقمی
  Future<void> verifySignupCode(String email, String code) async {
    _justSignedUp = true; // بعد از تایید، معرفی نشان داده شود
    try {
      await _client.auth.verifyOTP(
          type: OtpType.signup, email: email.trim(), token: code.trim());
    } catch (_) {
      _justSignedUp = false;
      rethrow;
    }
  }

  /// مرحلهٔ ۱ بازیابی: تایید کد ایمیل. نشست ساخته می‌شود ولی تا تعیین رمز جدید وارد برنامه نمی‌شویم.
  Future<void> verifyRecoveryCode(String email, String code) async {
    _holdSignIn = true;
    try {
      await _client.auth.verifyOTP(
          type: OtpType.recovery, email: email.trim(), token: code.trim());
    } catch (_) {
      _holdSignIn = false;
      rethrow;
    }
  }

  /// مرحلهٔ ۲ بازیابی: رمز جدید؛ بعدش کاربر وارد می‌شود.
  Future<void> completeRecovery(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
    _holdSignIn = false;
    await checkLoginStatus();
  }

  /// انصراف وسط بازیابی: نشست موقت بسته می‌شود
  Future<void> cancelRecovery() async {
    if (!_holdSignIn) return;
    _holdSignIn = false;
    try {
      await _client.auth.signOut();
    } catch (_) {}
  }

  Future<SignUpResult> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    _justSignedUp = true; // قبل از رویداد signedIn، تا معرفی نشان داده شود
    try {
      final res = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'name': name.trim()},
        emailRedirectTo: redirectUrl,
      );

      final user = res.user;
      // وقتی تایید ایمیل روشن است و ایمیل تکراری باشد، Supabase خطا نمی‌دهد ولی identities خالی است
      if (user != null && (user.identities?.isEmpty ?? false)) {
        _justSignedUp = false;
        throw AuthException('User already registered');
      }

      if (res.session == null) {
        _justSignedUp = false;
        return SignUpResult.needsEmailConfirmation;
      }

      if (user != null) {
        _userName = name.trim();
        await _ensureProfile(user.id, email.trim(), name.trim());
      }
      return SignUpResult.signedIn;
    } catch (_) {
      _justSignedUp = false;
      rethrow;
    }
  }

  /// اگر تریگر دیتابیس هنوز نصب نیست، پروفایل را مثل قبل از سمت برنامه می‌سازیم
  Future<void> _ensureProfile(String uid, String email, String name) async {
    try {
      final existing = await _client
          .from('profiles')
          .select('user_id')
          .eq('user_id', uid)
          .maybeSingle();
      final service = SupabaseService();
      if (existing == null) {
        await service.createProfile(uid, email, name.isEmpty ? email.split('@').first : name);
      }
      await service.createUserProgress(uid);
    } catch (e) {
      if (kDebugMode) debugPrint('ensureProfile skipped: $e');
    }
  }

  /// ورود با گوگل (مرورگر باز می‌شود و با لینک عمیق برمی‌گردد)
  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : redirectUrl,
      authScreenLaunchMode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
  }

  Future<void> sendPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim(), redirectTo: redirectUrl);
  }

  Future<void> resendConfirmation(String email) async {
    await _client.auth.resend(type: OtpType.signup, email: email.trim());
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
    _needsPasswordReset = false;
    notifyListeners();
  }

  /// کاربر صفحهٔ بازیابی رمز را بست
  void dismissPasswordReset() {
    _needsPasswordReset = false;
    notifyListeners();
  }

  // ───────────────────────── معرفی و سوال‌ها ─────────────────────────

  /// پاسخ‌ها را ذخیره می‌کند. اگر سرور در دسترس نبود، محلی نگه می‌دارد و بعداً می‌فرستد.
  /// خروجی true یعنی روی سرور هم ذخیره شد.
  Future<bool> completeOnboarding(OnboardingAnswers answers) async {
    final uid = _userId;
    if (uid == null) return false;
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('onboarding_answers_$uid', jsonEncode(answers.toJson()));
    await prefs.setBool('onboarding_done_$uid', true);
    await prefs.setBool('onboarding_pending_$uid', true);
    _justSignedUp = false;
    _onboardingDone = true;
    notifyListeners();

    return _flushPendingOnboarding(uid);
  }

  /// رد کردن سوال‌ها (فقط محلی علامت می‌خورد)
  Future<void> skipOnboarding() async {
    final uid = _userId;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done_$uid', true);
    _justSignedUp = false;
    _onboardingDone = true;
    notifyListeners();
  }

  Future<bool> _flushPendingOnboarding(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('onboarding_pending_$uid') != true) return true;
      final raw = prefs.getString('onboarding_answers_$uid');
      if (raw == null) return true;

      final data = jsonDecode(raw) as Map<String, dynamic>;
      await _client.from('user_onboarding').upsert({
        'user_id': uid,
        ...data,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).timeout(const Duration(seconds: 8));

      await prefs.remove('onboarding_pending_$uid');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('onboarding upload postponed: $e');
      return false;
    }
  }

  // ───────────────────────── خروج ─────────────────────────

  Future<void> forceLogout() async {
    _resetState();
    notifyListeners(); // UI فوراً به صفحهٔ ورود می‌رود

    try {
      await _client.auth.signOut();
    } catch (e) {
      if (kDebugMode) debugPrint('signOut error: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
    } catch (_) {}
  }

  void setHasUsername(bool value) {
    _hasUsername = value;
    final uid = _userId;
    if (uid != null) {
      SharedPreferences.getInstance()
          .then((p) => p.setBool('has_username_$uid', value))
          .catchError((_) => false);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
