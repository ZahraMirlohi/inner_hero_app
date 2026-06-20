import 'dart:convert';
import 'dart:io';

class ExploreSeedService {
  static const String endpoint = 'https://cloud.appwrite.io/v1';
  static const String projectId = '6a25e1ce002d7cc4bc2e';
  static const String databaseId = '6a27134f000c2f9407f0';
  static const String apiKey =
      'standard_6facac1ad0ff8f62d0ededf3b975079906ad9f0db63ae2c814e78f53a538d4efa9e43f6015b88832f49d7d2ed2d6f930b6fc0c0b77d3fff7ccac43747eaeb9d86733d833236482d80f898d66b18a226901689edc7c0640337df4c894517de7cf293d82a916b5ee393c4464b1c81d341183932da871966f1b5870e508dd182cd2';

  final HttpClient _httpClient = HttpClient();

  Future<void> seedAll() async {
    print('═══════════════════════════════════════════════════════════');
    print('           شروع فرآیند Seed داده‌های اکسپلور');
    print('═══════════════════════════════════════════════════════════\n');

    await _seedChallenges();
    await _seedTemplatePackages();
    await _seedQuests();
    await _seedCosmetics();
    await _seedDailySpark();
    await _seedQuotes();

    print('\n═══════════════════════════════════════════════════════════');
    print('           ✅ همه داده‌ها با موفقیت ذخیره شدند!');
    print('═══════════════════════════════════════════════════════════');
  }

  Future<void> _postDocument(
    String collectionId,
    Map<String, dynamic> data,
  ) async {
    final url = Uri.parse(
      '$endpoint/databases/$databaseId/collections/$collectionId/documents',
    );
    final request = await _httpClient.postUrl(url);
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('X-Appwrite-Project', projectId);
    request.headers.set('X-Appwrite-Key', apiKey);
    request.write(jsonEncode({'documentId': 'unique()', 'data': data}));

    final response = await request.close();
    if (response.statusCode != 201 && response.statusCode != 200) {
      print('   ⚠️ خطا: ${response.statusCode}');
    }
  }

  Future<void> _seedChallenges() async {
    print('📌 درج چالش‌ها...');

    final challenges = [
      {
        'title': 'صبح قهرمانانه 🌅',
        'description': '۷ روز ماجراجویی صبحگاهی',
        'daysLeft': 5,
        'participants': 234,
        'xpReward': 500,
        'color': '#FFB8B8',
        'textColor': '#E57373',
        'badge': '🔥 داغ',
        'isBoss': false,
        'startDate': DateTime.now().toIso8601String(),
        'endDate': DateTime.now().add(Duration(days: 7)).toIso8601String(),
        'isActive': true,
        'tasks': '۵ دقیقه مدیتیشن,۸ لیوان آب,۱۰ دقیقه مطالعه,تمرین صبحگاهی',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
      {
        'title': 'باس فایت آخر هفته 👾',
        'description': 'هیولای تنبلی رو شکست بده!',
        'daysLeft': 3,
        'participants': 567,
        'xpReward': 1000,
        'color': '#C8E6F9',
        'textColor': '#4A90E2',
        'badge': '👑 ویژه',
        'isBoss': true,
        'communityXP': 8450,
        'targetXP': 10000,
        'startDate': DateTime.now().toIso8601String(),
        'endDate': DateTime.now().add(Duration(days: 3)).toIso8601String(),
        'isActive': true,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
      {
        'title': 'چالش ۱۰۰۰۰ قدم 🚶',
        'description': 'هر روز ۱۰۰۰۰ قدم پیاده‌روی',
        'daysLeft': 7,
        'participants': 890,
        'xpReward': 750,
        'color': '#D5F5E3',
        'textColor': '#27AE60',
        'badge': '🏃 فعال',
        'isBoss': false,
        'startDate': DateTime.now().toIso8601String(),
        'endDate': DateTime.now().add(Duration(days: 7)).toIso8601String(),
        'isActive': true,
        'tasks': '۱۰۰۰۰ قدم پیاده‌روی,ثبت روزانه در اپ',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
      {
        'title': 'مدیتیشن عمیق 🧘',
        'description': '۲۰ دقیقه مدیتیشن روزانه',
        'daysLeft': 10,
        'participants': 456,
        'xpReward': 600,
        'color': '#FFE0C0',
        'textColor': '#E67E22',
        'badge': '🧠 ذهن آگاه',
        'isBoss': false,
        'startDate': DateTime.now().toIso8601String(),
        'endDate': DateTime.now().add(Duration(days: 10)).toIso8601String(),
        'isActive': true,
        'tasks': '۲۰ دقیقه مدیتیشن,تنفس عمیق',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
      {
        'title': 'ماه رمضان بدون عادت بد 🌙',
        'description': '۳۰ روز چالش ویژه',
        'daysLeft': 25,
        'participants': 1234,
        'xpReward': 2000,
        'color': '#E8D5F5',
        'textColor': '#9B59B6',
        'badge': '⭐ محبوب',
        'isBoss': false,
        'startDate': DateTime.now().toIso8601String(),
        'endDate': DateTime.now().add(Duration(days: 30)).toIso8601String(),
        'isActive': true,
        'tasks': 'افزایش عبادات,مدیریت زمان,تغذیه سالم',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
    ];

    for (var challenge in challenges) {
      await _postDocument('challenges', challenge);
    }
    print('   ✅ ${challenges.length} چالش با موفقیت درج شد');
  }

  Future<void> _seedTemplatePackages() async {
    print('📌 درج بسته‌های آماده...');

    final packages = [
      {
        'title': 'بسته سلامت 💪',
        'description': '۵ عادت برای تناسب اندام',
        'xpReward': 250,
        'color': '#4A90E2',
        'backgroundColor': '#D4F1F4',
        'icon': 'fitness_center',
        'habits':
            'نوشیدن ۸ لیوان آب,۳۰ دقیقه پیاده‌روی,۷ ساعت خواب,میوه روزانه,حرکات کششی',
        'isActive': true,
        'order': 1,
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'title': 'بسته تمرکز عمیق 🧠',
        'description': 'افزایش بهره‌وری ۳ برابری',
        'xpReward': 300,
        'color': '#F39C12',
        'backgroundColor': '#FFE5D9',
        'icon': 'psychology',
        'habits':
            'پومودورو ۲۵ دقیقه,خاموش کردن گوشی,لیست کارهای روزانه,۵ دقیقه مدیتیشن',
        'isActive': true,
        'order': 2,
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'title': 'بسته رشد مالی 💰',
        'description': 'مدیریت هوشمند هزینه‌ها',
        'xpReward': 350,
        'color': '#27AE60',
        'backgroundColor': '#E8EAF6',
        'icon': 'attach_money',
        'habits':
            'ثبت روزانه هزینه,پس‌انداز روزانه,مطالعه مالی ۱۰ دقیقه,برنامه بودجه هفتگی',
        'isActive': true,
        'order': 3,
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'title': 'بسته روابط ❤️',
        'description': 'ارتباطات عمیق‌تر و معنادار',
        'xpReward': 200,
        'color': '#E74C3C',
        'backgroundColor': '#FFE4E1',
        'icon': 'favorite',
        'habits':
            'تماس با خانواده,قدردانی روزانه,پیام محبت‌آمیز,زمان باکیفیت با عزیزان',
        'isActive': true,
        'order': 4,
        'createdAt': DateTime.now().toIso8601String(),
      },
    ];

    for (var pkg in packages) {
      await _postDocument('template_packages', pkg);
    }
    print('   ✅ ${packages.length} بسته با موفقیت درج شد');
  }

  Future<void> _seedQuests() async {
    print('📌 درج ماموریت‌های ویژه...');

    final quests = [
      {
        'title': 'بیداری اژدها 🐉',
        'description': '۳ روز قبل از ۷ صبح بیدار شو + ۱۰ دقیقه ورزش',
        'xpReward': 750,
        'badge': 'طلایه‌دار سحر',
        'color': '#FF9F43',
        'requirements': '۳ روز بیداری قبل ۷ صبح,۱۰ دقیقه ورزش روزانه',
        'isActive': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'title': 'سپر ذهنی 🛡️',
        'description': '۵ روز مدیتیشن + ۳ روز بدون شبکه اجتماعی',
        'xpReward': 1000,
        'badge': 'استاد ذهن',
        'color': '#5F27CD',
        'requirements': '۵ روز مدیتیشن,۳ روز بدون اینستاگرام',
        'isActive': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'title': 'گنج دانش 📚',
        'description': 'خواندن ۱۰۰ صفحه کتاب + یادداشت‌برداری',
        'xpReward': 850,
        'badge': 'کیمیاگر دانش',
        'color': '#00B894',
        'requirements': '۱۰۰ صفحه کتاب,یادداشت‌برداری',
        'isActive': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
    ];

    for (var quest in quests) {
      await _postDocument('quests', quest);
    }
    print('   ✅ ${quests.length} ماموریت با موفقیت درج شد');
  }

  Future<void> _seedCosmetics() async {
    print('📌 درج آیتم‌های بازارچه...');

    final cosmetics = [
      {
        'name': 'تم جنگل 🌲',
        'description': 'حال و هوای طبیعت',
        'category': 'theme',
        'icon': 'forest',
        'color': '#2ECC71',
        'price': 1500,
        'isActive': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'name': 'تم آتش 🔥',
        'description': 'انرژی و قدرت',
        'category': 'theme',
        'icon': 'whatshot',
        'color': '#E74C3C',
        'price': 1500,
        'isActive': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'name': 'فریم طلایی 🥇',
        'description': 'فریم آواتار ویژه',
        'category': 'frame',
        'icon': 'emoji_events',
        'color': '#F39C12',
        'price': 800,
        'isActive': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'name': 'فریم الماسی 💎',
        'description': 'فریم نادر',
        'category': 'frame',
        'icon': 'diamond',
        'color': '#3498DB',
        'price': 2000,
        'isActive': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'name': 'صدای باران 🌧️',
        'description': 'صدای آرامش‌بخش',
        'category': 'sound',
        'icon': 'beach_access',
        'color': '#3498DB',
        'price': 500,
        'isActive': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'name': 'صدای جنگل 🌲',
        'description': 'صدای طبیعت',
        'category': 'sound',
        'icon': 'forest',
        'color': '#2ECC71',
        'price': 500,
        'isActive': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'name': 'هاله نورانی ✨',
        'description': 'افکت ویژه دور آواتار',
        'category': 'effect',
        'icon': 'flare',
        'color': '#F1C40F',
        'price': 1200,
        'isActive': true,
        'createdAt': DateTime.now().toIso8601String(),
      },
    ];

    for (var item in cosmetics) {
      await _postDocument('cosmetics', item);
    }
    print('   ✅ ${cosmetics.length} آیتم با موفقیت درج شد');
  }

  Future<void> _seedDailySpark() async {
    print('📌 درج جرقه‌های روزانه...');

    final sparks = [
      {
        'text': '«قطره قطره جمع گردد، دریا شود»',
        'author': 'سعدی',
        'type': 'quote',
        'date': '2026-06-13',
        'isActive': true,
      },
      {
        'text': 'چالش ۲ دقیقه‌ای: عمیق نفس بکش و به ۵ چیز خوب امروز فکر کن',
        'type': 'challenge',
        'date': '2026-06-14',
        'isActive': true,
      },
      {
        'text': 'مغز شما هر عادت جدید را بعد از ۶۶ روز خودکار می‌کند!',
        'type': 'fact',
        'date': '2026-06-15',
        'isActive': true,
      },
      {
        'text': '«آینده از آن کسانی است که به زیبایی رویاهایشان باور دارند»',
        'author': 'النور روزولت',
        'type': 'quote',
        'date': '2026-06-16',
        'isActive': true,
      },
      {
        'text': 'چالش امروز: ۱۰ دقیقه کتاب بخوانید',
        'type': 'challenge',
        'date': '2026-06-17',
        'isActive': true,
      },
      {
        'text': 'عادت‌های کوچک، نتایج بزرگ می‌سازند!',
        'type': 'fact',
        'date': '2026-06-18',
        'isActive': true,
      },
    ];

    for (var spark in sparks) {
      await _postDocument('daily_spark', spark);
    }
    print('   ✅ ${sparks.length} جرقه با موفقیت درج شد');
  }

  Future<void> _seedQuotes() async {
    print('📌 درج جملات انگیزشی...');

    final quotes = [
      {
        'text':
            'تنها محدودیتی که دارید، محدودیتی است که خودتان در ذهنتان ایجاد می‌کنید.',
        'author': 'نپلئون هیل',
        'category': 'motivation',
        'isActive': true,
      },
      {
        'text': 'موفقیت مجموع تلاش‌های کوچکی است که روز به روز تکرار می‌شوند.',
        'author': 'رابرت کالیر',
        'category': 'motivation',
        'isActive': true,
      },
      {
        'text': 'با انجام کارهای کوچک هر روز، می‌توانید به نتایج بزرگ برسید.',
        'author': 'لائوتسه',
        'category': 'wisdom',
        'isActive': true,
      },
      {
        'text': 'عادت‌های خوب، کلید موفقیت هستند.',
        'author': 'ارسطو',
        'category': 'wisdom',
        'isActive': true,
      },
      {
        'text': 'آینده‌ای که می‌خواهید، در کارهایی است که امروز انجام می‌دهید.',
        'author': 'تونی رابینز',
        'category': 'motivation',
        'isActive': true,
      },
      {
        'text': 'هیچ چیز غیرممکن نیست، فقط نیاز به تلاش بیشتر دارد.',
        'author': 'توماس ادیسون',
        'category': 'motivation',
        'isActive': true,
      },
      {
        'text': 'هر روز یک فرصت جدید برای بهتر شدن است.',
        'author': 'آن فرانک',
        'category': 'inspiration',
        'isActive': true,
      },
      {
        'text': 'پایداری و استمرار، رمز موفقیت است.',
        'author': 'کنفوسیوس',
        'category': 'wisdom',
        'isActive': true,
      },
      {
        'text':
            'بهترین زمان برای شروع، دیروز بود. دومین بهترین زمان، امروز است.',
        'author': 'ضرب‌المثل چینی',
        'category': 'motivation',
        'isActive': true,
      },
      {
        'text': 'سفر هزار فرسنگی با یک قدم آغاز می‌شود.',
        'author': 'لائوتسه',
        'category': 'wisdom',
        'isActive': true,
      },
      {
        'text': 'هر روز شما صفحه جدیدی از کتاب زندگی‌تان است.',
        'author': 'اپکتتوس',
        'category': 'inspiration',
        'isActive': true,
      },
    ];

    for (var quote in quotes) {
      await _postDocument('quotes', quote);
    }
    print('   ✅ ${quotes.length} جمله با موفقیت درج شد');
  }
}

void main() async {
  final seedService = ExploreSeedService();
  await seedService.seedAll();
}
