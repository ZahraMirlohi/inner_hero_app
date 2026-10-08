// lib/main.dart

import 'package:flutter/material.dart';
import 'package:inner_hero_app/providers/calendar_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'providers/sync_provider.dart';
import 'services/local_storage_service.dart';
import 'services/audio_player_service.dart';
import 'services/download_service.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    String supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
    String supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

    print('🎯 SUPABASE_URL from dart-define: "$supabaseUrl"');
    print('🎯 SUPABASE_ANON_KEY length: ${supabaseAnonKey.length}');

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      print('📄 Trying to load .env file...');
      await dotenv.load(fileName: ".env");
      supabaseUrl = dotenv.env['SUPABASE_URL']!;
      supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;
      print('📄 Loaded from .env');
    } else {
      print('🎯 Using dart-define values');
    }

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw Exception('SUPABASE_URL or SUPABASE_ANON_KEY is empty!');
    }

    print('🔑 SUPABASE_URL: $supabaseUrl');

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
    );

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null && session.isExpired) {
      print('⚠️ Expired session found, signing out...');
      await Supabase.instance.client.auth.signOut();
    }

    await LocalStorageService().init();

    final themeProvider = ThemeProvider();
    await Future.delayed(const Duration(milliseconds: 100));

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SyncProvider()),
          ChangeNotifierProvider(create: (_) => AudioPlayerService()),
          ChangeNotifierProvider(create: (_) => DownloadService()),
          ChangeNotifierProvider.value(value: themeProvider),
          ChangeNotifierProvider(create: (_) => CalendarProvider()),
        ],
        child: const HeroApp(),
      ),
    );
  } catch (e) {
    print('❌ Error: $e');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'خطا در اجرای اپلیکیشن',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => main(),
                    child: const Text('تلاش مجدد'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
