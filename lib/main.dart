// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'providers/sync_provider.dart';
import 'services/local_storage_service.dart';

void main() async {
  print('🔵 [MAIN] Application starting...');
  WidgetsFlutterBinding.ensureInitialized();
  print('🔵 [MAIN] WidgetsFlutterBinding ensured');

  try {
    print('🔵 [MAIN] Loading .env file...');
    await dotenv.load(fileName: ".env");
    print('✅ [MAIN] .env loaded successfully');

    print('🔵 [MAIN] Initializing Supabase...');
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
    print('✅ [MAIN] Supabase initialized');

    print('🔵 [MAIN] Initializing LocalStorage...');
    await LocalStorageService().init();
    print('✅ [MAIN] LocalStorage initialized');

    print('🔵 [MAIN] Running app...');
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (context) => SyncProvider(),
            lazy: false,
          ),
        ],
        child: const HeroApp(),
      ),
    );
    print('✅ [MAIN] App is running');
  } catch (e) {
    print('🔴 [MAIN] Critical error: $e');
    // اجرای اپلیکیشن با یک صفحه خطا
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'خطا در اجرای اپلیکیشن',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
