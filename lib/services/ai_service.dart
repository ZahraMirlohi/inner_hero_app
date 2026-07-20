// lib/services/ai_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import '../features/arena/models/habit_model.dart';
import '../features/profile/models/profile_model.dart';

class AIService {
  final String? _apiKey = dotenv.env['OPENAI_API_KEY'];
  final String _apiUrl = 'https://api.openai.com/v1/chat/completions';

  AIService();

  Future<String> getWelcomeMessage(
    String userId,
    List<Habit> habits,
    Map<String, dynamic>? profile,
  ) async {
    final habitCount = habits.where((h) => h.isActive).length;
    final todayHabits = habits.where((h) => h.shouldDoToday()).length;

    String welcome = 'سلام قهرمان! 👋\n\n';

    if (habitCount == 0) {
      welcome +=
          'به نظر می‌رسد هنوز عادتی ایجاد نکرده‌اید. '
          'بیایید اولین قدم را برداریم! 🚀\n\n'
          'من می‌توانم به شما کمک کنم تا بهترین عادت‌ها را برای شروع انتخاب کنید. '
          'چه چیزی را می‌خواهید بهبود ببخشید؟';
    } else if (todayHabits > 0) {
      welcome +=
          'امروز $todayHabits عادت برای انجام دارید! 💪\n\n'
          'من اینجا هستم تا شما را در مسیر قهرمانی همراهی کنم. '
          'اگر سوال، مشکل یا نیاز به انگیزه دارید، با من در میان بگذارید.';
    } else {
      welcome +=
          'همه عادت‌های امروز را انجام داده‌اید! 🎉\n\n'
          'چه روز خوبی! اگر برای فردا برنامه خاصی دارید، '
          'می‌توانیم با هم برنامه‌ریزی کنیم.';
    }

    return welcome;
  }

  Future<String> getResponse({
    required String userId,
    required String message,
    required List<Habit> habits,
    required Map<String, dynamic>? profile,
  }) async {
    // اگر API Key وجود نداشت، از پاسخ‌های آفلاین استفاده کن
    if (_apiKey == null || _apiKey!.isEmpty) {
      return _getFallbackResponse(message, habits, profile);
    }

    try {
      final activeHabits = habits.where((h) => h.isActive).toList();
      final todayHabits = activeHabits.where((h) => h.shouldDoToday()).toList();
      final completedToday = activeHabits
          .where((h) => h.shouldDoToday() && h.completedSubHabits.isNotEmpty)
          .length;

      final systemPrompt =
          '''
شما یک مربی هوش مصنوعی انگیزشی و حامی هستید که به کاربر کمک می‌کنید عادت‌های خوب بسازد.

اطلاعات کاربر:
- تعداد عادت‌های فعال: ${activeHabits.length}
- عادت‌های امروز: ${todayHabits.length} عدد
- عادت‌های انجام شده امروز: $completedToday
- استریک: ${profile?['current_streak'] ?? 0} روز
- سطح: ${profile?['level'] ?? 1}
- کل XP: ${profile?['total_xp'] ?? 0}

سبک پاسخ‌دهی:
۱. همیشه با لحنی گرم، صمیمی و انگیزشی صحبت کن
۲. از اصطلاحات قهرمانی و حماسی استفاده کن (قهرمان، جنگجو، پیروزی، و...)
۳. پاسخ‌ها را شخصی‌سازی کن بر اساس اطلاعات کاربر
۴. پیشنهادات عملی و قابل اجرا بده
۵. اگر کاربر ناامید به نظر می‌رسد، او را تشویق کن و به موفقیت‌های گذشته‌اش یادآوری کن
۶. پیام‌ها را کوتاه و مفید نگه دار (حداکثر ۳-۴ پاراگراف)
''';

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': message},
          ],
          'temperature': 0.7,
          'max_tokens': 300,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String;
      } else {
        debugPrint('❌ AI API Error: ${response.statusCode}');
        return _getFallbackResponse(message, habits, profile);
      }
    } catch (e) {
      debugPrint('❌ AI Service Error: $e');
      return _getFallbackResponse(message, habits, profile);
    }
  }

  // ==================== پاسخ‌های آفلاین (Fallback) ====================

  String _getFallbackResponse(
    String message,
    List<Habit> habits,
    Map<String, dynamic>? profile,
  ) {
    final lowerMessage = message.toLowerCase();
    final streak = profile?['current_streak'] ?? 0;

    if (lowerMessage.contains('انگیزه') || lowerMessage.contains('انرژی')) {
      return _getMotivationResponse(streak);
    }

    if (lowerMessage.contains('برنامه') ||
        lowerMessage.contains('برنامه‌ریزی')) {
      return _getPlanningResponse(habits);
    }

    if (lowerMessage.contains('مشکل') || lowerMessage.contains('سختی')) {
      return _getSupportResponse(streak);
    }

    if (lowerMessage.contains('پیشرفت') || lowerMessage.contains('چطورم')) {
      return _getProgressResponse(habits, streak);
    }

    return _getGeneralResponse(message, streak);
  }

  String _getMotivationResponse(int streak) {
    if (streak >= 30) {
      return '🔥 ۳۰ روز پیاپی! شما یک افسانه هستید!\n\n'
          'این سطح از تعهد واقعاً الهام‌بخش است. به یاد داشته باشید که '
          'هر روزی که ادامه می‌دهید، به نسخه بهتری از خودتان تبدیل می‌شوید.\n\n'
          'امروز چه کاری می‌توانید انجام دهید که فردای شما را بهتر کند؟';
    }
    if (streak >= 7) {
      return '💪 یک هفته کامل! این عالی است!\n\n'
          'شما ثابت کرده‌اید که می‌توانید به تعهدات خود پایبند باشید. '
          'این انرژی را حفظ کنید و به یاد داشته باشید که هر روز کوچک، '
          'قدمی بزرگ به سوی قهرمانی است.\n\n'
          'آماده‌اید برای هفته دوم؟ 🚀';
    }
    if (streak >= 3) {
      return '🌟 ۳ روز پیاپی! چه شروع عالی!\n\n'
          'شما در مسیر درستی قرار دارید. این روزها را جشن بگیرید '
          'و به خودتان ثابت کنید که می‌توانید ادامه دهید.\n\n'
          'فردا هم یک روز جدید برای درخشش است! ✨';
    }
    return '🌱 هر سفر بزرگی با یک قدم شروع می‌شود.\n\n'
        'شما همین الان آن قدم را برداشته‌اید و این فوق‌العاده است! '
        'به خودتان ایمان داشته باشید و یک روز در میان پیش بروید.\n\n'
        'من اینجا هستم تا در این مسیر همراه شما باشم. 💪';
  }

  String _getPlanningResponse(List<Habit> habits) {
    final activeHabits = habits.where((h) => h.isActive).toList();
    if (activeHabits.isEmpty) {
      return '📋 بیایید با هم برنامه‌ریزی کنیم!\n\n'
          'به نظر می‌رسد هنوز عادتی انتخاب نکرده‌اید. '
          'پیشنهاد می‌کنم با یک عادت کوچک و ساده شروع کنید مثل:\n'
          '• ۵ دقیقه مدیتیشن صبحگاهی\n'
          '• ۱۰ دقیقه پیاده‌روی\n'
          '• نوشیدن یک لیوان آب بعد از بیدار شدن\n\n'
          'کدام یک را دوست دارید امتحان کنید؟';
    }

    return '📅 برنامه‌ریزی روزانه کلید موفقیت است.\n\n'
        'شما ${activeHabits.length} عادت فعال دارید. '
        'پیشنهاد می‌کنم:\n'
        '• صبح: عادت‌های انرژی‌بخش انجام دهید\n'
        '• ظهر: عادت‌های مرتبط با تمرکز\n'
        '• شب: عادت‌های آرامش‌بخش\n\n'
        'آیا می‌خواهید برای امروز یک برنامه خاص طراحی کنیم؟';
  }

  String _getSupportResponse(int streak) {
    return '💪 می‌دانم که گاهی مسیر سخت می‌شود.\n\n'
        'اما به یاد داشته باشید که ${streak > 0 ? '$streak روز' : 'از همین الان'} '
        'تلاش کرده‌اید و این یعنی شما قوی هستید.\n\n'
        'بیایید با هم راه‌حل پیدا کنیم:\n'
        '۱. مشکل را به بخش‌های کوچک‌تر تقسیم کنید\n'
        '۲. یک قدم کوچک امروز بردارید\n'
        '۳. به خودتان پاداش دهید\n\n'
        'من به شما ایمان دارم! ❤️';
  }

  String _getProgressResponse(List<Habit> habits, int streak) {
    final activeHabits = habits.where((h) => h.isActive).toList();
    final todayHabits = activeHabits.where((h) => h.shouldDoToday()).toList();

    return '📊 بیایید نگاهی به پیشرفت شما بیندازیم:\n\n'
        '• عادت‌های فعال: ${activeHabits.length}\n'
        '• عادت‌های امروز: ${todayHabits.length}\n'
        '• استریک فعلی: $streak روز\n\n'
        'شما در مسیر درستی هستید! هر روز که می‌گذرد، '
        'به قهرمانی که می‌خواهید باشید نزدیک‌تر می‌شوید.\n\n'
        'چه احساسی دارید؟ آیا از پیشرفت خود راضی هستید؟';
  }

  String _getGeneralResponse(String message, int streak) {
    return '👋 سلام قهرمان!\n\n'
        'سوال خوبی پرسیدید. من اینجا هستم تا در هر مرحله از سفر شما همراهتان باشم.\n\n'
        'اگر نیاز به برنامه‌ریزی، انگیزه یا راهنمایی دارید، حتماً بپرسید. '
        'همچنین می‌توانید درباره عادت‌ها، پیشرفت یا چالش‌ها با من صحبت کنید.\n\n'
        'چگونه می‌توانم امروز به شما کمک کنم؟ 💪';
  }
}
