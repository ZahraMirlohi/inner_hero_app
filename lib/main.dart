// lib/main.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'providers/auth_provider.dart';
import 'providers/calendar_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/theme_provider.dart';
import 'services/audio_player_service.dart';
import 'services/download_service.dart';
import 'services/local_storage_service.dart';

void main() {
  // همهٔ print های برنامه فقط در حالت دیباگ چاپ می‌شن (در نسخهٔ نهایی ساکتند و کند نمی‌کنن)
  runZonedGuarded(
    _bootstrap,
    (error, stack) {
      if (kDebugMode) debugPrint('Uncaught: $error\n$stack');
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        if (kDebugMode) parent.print(zone, line);
      },
    ),
  );
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // خواندن همزمان مواردی که به هم وابسته نیستن
    final results = await Future.wait<Object?>([
      _initSupabase(),
      LocalStorageService().init(),
      SettingsProvider.load(),
      ThemeProvider.load(),
    ]);
    final settings = results[2] as SettingsProvider;
    final themeProvider = results[3] as ThemeProvider;

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => SyncProvider()),
          ChangeNotifierProvider(create: (_) => AudioPlayerService()),
          ChangeNotifierProvider(create: (_) => DownloadService()),
          ChangeNotifierProvider.value(value: themeProvider),
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider(create: (_) => CalendarProvider()),
        ],
        child: const HeroApp(),
      ),
    );
  } catch (e) {
    if (kDebugMode) debugPrint('Startup error: $e');
    runApp(_StartupError(error: e.toString(), onRetry: main));
  }
}

Future<void> _initSupabase() async {
  var supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
  var supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    await dotenv.load(fileName: '.env');
    supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  }

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw Exception('SUPABASE_URL / SUPABASE_ANON_KEY not found (.env or --dart-define)');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true,
    ),
  );
  // نشست منقضی‌شده را اینجا signOut نمی‌کنیم: autoRefreshToken خودش تمدید می‌کند
  // و اگر آفلاین باشیم نباید کاربر را بیرون بیندازیم (برنامه باید آفلاین هم کار کند).
}

class _StartupError extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _StartupError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'خطا در اجرای اپلیکیشن / App failed to start',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('تلاش مجدد / Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
