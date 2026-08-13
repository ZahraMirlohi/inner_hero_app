// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'providers/sync_provider.dart';
import 'services/local_storage_service.dart';
import 'services/audio_player_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // ✅ اولویت اول: dart-define
    String supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
    String supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

    print('🎯 SUPABASE_URL from dart-define: "$supabaseUrl"');
    print('🎯 SUPABASE_ANON_KEY length: ${supabaseAnonKey.length}');

    // ✅ اگر dart-define خالی بود، از .env استفاده کن
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      print('📄 Trying to load .env file...');
      await dotenv.load(fileName: ".env");
      supabaseUrl = dotenv.env['SUPABASE_URL']!;
      supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;
      print('📄 Loaded from .env');
    } else {
      print('🎯 Using dart-define values');
    }

    // ✅ بررسی نهایی
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw Exception('SUPABASE_URL or SUPABASE_ANON_KEY is empty!');
    }

    print('🔑 SUPABASE_URL: $supabaseUrl');
    print(
        '🔑 SUPABASE_ANON_KEY: ${supabaseAnonKey.substring(0, supabaseAnonKey.length > 20 ? 20 : supabaseAnonKey.length)}...');

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    await LocalStorageService().init();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SyncProvider()),
          ChangeNotifierProvider(create: (_) => AudioPlayerService()),
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
