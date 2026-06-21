import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // بارگذاری .env
  await dotenv.load(fileName: ".env");

  // مقدارهای Supabase از .env
  final supabaseUrl = dotenv.env['SUPABASE_URL']!;
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  runApp(const HeroApp());
}
