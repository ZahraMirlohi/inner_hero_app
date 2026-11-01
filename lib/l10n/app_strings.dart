// lib/l10n/app_strings.dart
//
// سیستم ترجمهٔ سبک و بدون تولید کد (بدون نیاز به build_runner).
// استفاده:  context.tr('settings.title')   یا   context.tr('x', {'name': 'زهرا'})
// کلیدهای نبوده در هر زبان، از فارسی و سپس خود کلید برمی‌گردند (برنامه هیچ‌وقت کرش نمی‌کند).
//
// قانون نوشتن متن:
//  - فارسی: خودمونی، شوخ و تشویق‌کننده، بدون ایموجی (حداکثر :( یا ;) )
//  - انگلیسی: ساده و معمولی

import 'package:flutter/material.dart';

import 'strings_auth.dart';

class AppStrings {
  AppStrings._();

  static const Locale faLocale = Locale('fa', 'IR');
  static const Locale enLocale = Locale('en', 'US');
  static const List<Locale> supportedLocales = [faLocale, enLocale];

  static Locale localeFor(String languageCode) =>
      languageCode == 'en' ? enLocale : faLocale;

  static String t(String lang, String key, [Map<String, String>? args]) {
    final table = lang == 'en' ? _en : _fa;
    var text = table[key] ?? _fa[key] ?? key;
    if (args != null) {
      args.forEach((k, v) => text = text.replaceAll('{$k}', v));
    }
    return text;
  }

  // ───────────────────────── فارسی (طنز) ─────────────────────────
  static const Map<String, String> _fa = {
    ...authFa,
    // عمومی
    'app.name': 'قهرمان درون',
    'common.cancel': 'بی‌خیال',
    'common.ok': 'باشه',
    'common.save': 'ذخیره',
    'common.delete': 'حذف',
    'common.retry': 'یه بار دیگه',
    'common.close': 'بستن',
    'common.confirm': 'تایید',
    'common.loading': 'یه لحظه، داریم هولش می‌دیم...',
    'common.loading_data': 'داریم کارهات رو جمع‌وجور می‌کنیم...',
    'common.error_generic': 'یه چیزی جایی ترکید، ولی تقصیر تو نبود :(',
    'common.soon': 'به‌زودی',
    'common.soon_note': 'این یکی هنوز تو آشپزخونه‌ست، به‌زودی می‌رسه.',
    'common.offline_banner': 'نت نداری؛ کارت رو بکن، بعداً خودش همگام می‌شه.',
    'common.synced': 'همه‌چی همگام شد',
    'common.on': 'روشن',
    'common.off': 'خاموش',

    // تنظیمات
    'settings.title': 'تنظیمات',
    'settings.section_look': 'ظاهر',
    'settings.theme_mode': 'حالت نمایش',
    'settings.theme_system': 'مثل گوشی',
    'settings.theme_light': 'روز',
    'settings.theme_dark': 'شب',
    'settings.theme_mode_hint': 'چشمات مال خودته، ما فقط تم می‌دیم.',
    'settings.color': 'رنگ برنامه',
    'settings.color_hint': 'هر رنگی بخوای، کل برنامه باهاش ست می‌شه.',
    'settings.calendar': 'نوع تقویم',
    'settings.calendar_jalali': 'شمسی',
    'settings.calendar_gregorian': 'میلادی',
    'settings.section_language': 'زبان',
    'settings.language': 'زبان برنامه',
    'settings.language_hint': 'فارسی یا انگلیسی؛ هر دو رو می‌فهمیم.',
    'settings.lang_fa': 'فارسی',
    'settings.lang_en': 'English',
    'settings.section_feedback': 'صدا و لرزش',
    'settings.sound': 'افکت‌های صوتی',
    'settings.sound_hint': 'یه صدای خوشگل وقتی کاری رو تموم می‌کنی.',
    'settings.vibration': 'لرزش',
    'settings.vibration_hint': 'گوشی یه قلقلکی بهت می‌ده.',
    'settings.section_notifications': 'اعلان‌ها',
    'settings.notifications': 'اعلان‌ها',
    'settings.notifications_hint': 'اگه خاموش کنی، دیگه کسی سراغت نمیاد (ما هم دلمون می‌گیره).',
    'settings.notif_habits': 'یادآوری عادت‌ها و کارها',
    'settings.notif_chat': 'پیام‌های جدید',
    'settings.notif_challenges': 'چالش‌ها و دعوت‌ها',
    'settings.notif_xp': 'هدیه و امتیاز',
    'settings.notif_note': 'فعلاً یادآور روزانهٔ عادت‌ها کار می‌کنه؛ بقیه اعلان‌ها با آماده شدن سرورشون روشن می‌شن.',
    'settings.section_privacy': 'حریم خصوصی',
    'settings.private_profile': 'پروفایل خصوصی',
    'settings.private_profile_hint': 'فقط وقتی سرورش آماده شد روشن می‌شه.',
    'settings.section_account': 'حساب کاربری',
    'settings.logout': 'خروج از حساب',
    'settings.logout_title': 'می‌خوای بری؟',
    'settings.logout_body': 'عادت‌هات همین‌جا منتظرت می‌مونن، قول می‌دیم.',
    'settings.logout_unsynced':
        '{count} تغییر هنوز به سرور نرسیده. اگه الان بری، گم می‌شن :( بازم می‌خوای بری؟',
    'settings.logout_syncing': 'داریم آخرین تغییرات رو می‌فرستیم...',
    'settings.logout_error': 'خروج نشد، یه بار دیگه امتحان کن.',
    'settings.delete_account': 'حذف حساب کاربری',
    'settings.delete_title': 'حذف همیشگی حساب',
    'settings.delete_body':
        'همه‌چی پاک می‌شه: عادت‌ها، امتیازها، چت‌ها و حتی استریکی که با اون همه زحمت ساختی. این کار برگشت نداره.',
    'settings.delete_type_hint': 'برای تایید بنویس: {word}',
    'settings.delete_word': 'حذف',
    'settings.delete_confirm_btn': 'برو حذفش کن',
    'settings.delete_loading': 'داریم خداحافظی می‌کنیم...',
    'settings.delete_done': 'حسابت حذف شد. ممنون که بودی، در همیشه به روی قهرمان‌ها بازه.',
    'settings.delete_error': 'حذف حساب نشد: {error}',
    'settings.section_about': 'درباره',
    'settings.version': 'نسخه برنامه',
    'settings.team': 'تیم سازنده',
    'settings.team_support': 'پشتیبانی',
    'settings.team_ok': 'خوش باشید',

    'settings.remind_time': 'ساعت یادآور روزانه',
    'notif.channel': 'یادآور روزانه',
    'notif.title': 'قهرمان درون',
    'notif.body1': 'عادت‌هات دلشون برات تنگ شده. یه سر بزن.',
    'notif.body2': 'استریکت بدون تو غذا نمی‌خوره. بیا نجاتش بده.',
    'notif.body3': 'پنج دقیقه وقت داری؟ قهرمان‌ها از همین پنج دقیقه‌ها ساخته می‌شن.',
    'notif.body4': 'امروز هنوز تیکی نخوردی؛ ما که قضاوت نمی‌کنیم ;)',

    // استریک
    'streak.title': 'استریک روزانه',
    'streak.record': 'رکورد {n}',
    'streak.days': 'روز',
    'streak.start': 'امروز رو شروع کن!',
    'streak.keep': 'استریکت منتظرته؛ یه تیک بزن.',
    'streak.today_done': 'امروز رو گرفتی. فردا هم بیا!',

    'profile.gallery': 'گالری من',
    'profile.personality': 'شخصیت من',
    'profile.terms': 'قوانین و مقررات',
    'profile.settings': 'تنظیمات',

    'xp.title': 'سکه‌ها و سطح',
    'xp.total': 'کل سکه‌ها',
    'xp.level': 'سطح',
    'xp.needed': 'تا سطح بعدی',
    'xp.progress': 'پیشرفت به سطح {n}',

    // تم و رنگ
    'color.title': 'رنگ برنامه',
    'color.reset': 'برگردون به حالت اول',
  };

  // ───────────────────────── English ─────────────────────────
  static const Map<String, String> _en = {
    ...authEn,
    'app.name': 'Inner Hero',
    'common.cancel': 'Cancel',
    'common.ok': 'OK',
    'common.save': 'Save',
    'common.delete': 'Delete',
    'common.retry': 'Try again',
    'common.close': 'Close',
    'common.confirm': 'Confirm',
    'common.loading': 'Loading...',
    'common.loading_data': 'Getting your data ready...',
    'common.error_generic': 'Something went wrong. It is not your fault.',
    'common.soon': 'Coming soon',
    'common.soon_note': 'This one is still being built and will arrive soon.',
    'common.offline_banner':
        'You are offline. Keep going, we will sync later.',
    'common.synced': 'Everything is synced',
    'common.on': 'On',
    'common.off': 'Off',

    'settings.title': 'Settings',
    'settings.section_look': 'Appearance',
    'settings.theme_mode': 'Display mode',
    'settings.theme_system': 'System',
    'settings.theme_light': 'Light',
    'settings.theme_dark': 'Dark',
    'settings.theme_mode_hint': 'Choose how the app looks.',
    'settings.color': 'App color',
    'settings.color_hint': 'The whole app follows the color you pick.',
    'settings.calendar': 'Calendar type',
    'settings.calendar_jalali': 'Jalali',
    'settings.calendar_gregorian': 'Gregorian',
    'settings.section_language': 'Language',
    'settings.language': 'App language',
    'settings.language_hint': 'Persian or English.',
    'settings.lang_fa': 'فارسی',
    'settings.lang_en': 'English',
    'settings.section_feedback': 'Sound and haptics',
    'settings.sound': 'Sound effects',
    'settings.sound_hint': 'A small sound when you complete something.',
    'settings.vibration': 'Vibration',
    'settings.vibration_hint': 'Gentle haptic feedback.',
    'settings.section_notifications': 'Notifications',
    'settings.notifications': 'Notifications',
    'settings.notifications_hint': 'Turn this off to silence everything.',
    'settings.notif_habits': 'Habit and task reminders',
    'settings.notif_chat': 'New messages',
    'settings.notif_challenges': 'Challenges and invites',
    'settings.notif_xp': 'Gifts and points',
    'settings.notif_note':
        'The daily habit reminder works now; other notifications turn on as their servers get ready.',
    'settings.section_privacy': 'Privacy',
    'settings.private_profile': 'Private profile',
    'settings.private_profile_hint': 'Available once the server side is ready.',
    'settings.section_account': 'Account',
    'settings.logout': 'Log out',
    'settings.logout_title': 'Leaving already?',
    'settings.logout_body': 'Your habits will be waiting for you.',
    'settings.logout_unsynced':
        '{count} changes have not reached the server yet. If you leave now they will be lost. Leave anyway?',
    'settings.logout_syncing': 'Sending your latest changes...',
    'settings.logout_error': 'Could not log out. Please try again.',
    'settings.delete_account': 'Delete account',
    'settings.delete_title': 'Delete account forever',
    'settings.delete_body':
        'Everything will be erased: habits, points, chats and your streak. This cannot be undone.',
    'settings.delete_type_hint': 'To confirm, type: {word}',
    'settings.delete_word': 'DELETE',
    'settings.delete_confirm_btn': 'Delete my account',
    'settings.delete_loading': 'Deleting your account...',
    'settings.delete_done': 'Your account was deleted. Thanks for being here.',
    'settings.delete_error': 'Could not delete the account: {error}',
    'settings.section_about': 'About',
    'settings.version': 'App version',
    'settings.team': 'Team',
    'settings.team_support': 'Support',
    'settings.team_ok': 'Got it',

    'settings.remind_time': 'Daily reminder time',
    'notif.channel': 'Daily reminder',
    'notif.title': 'Inner Hero',
    'notif.body1': 'Your habits miss you. Come say hi.',
    'notif.body2': 'Your streak needs you. Do not let it down.',
    'notif.body3': 'Got five minutes? Heroes are made of those.',
    'notif.body4': 'No check-ins today yet. No judgment, promise.',

    'streak.title': 'Daily streak',
    'streak.record': 'Record {n}',
    'streak.days': 'days',
    'streak.start': 'Start today!',
    'streak.keep': 'Your streak is waiting. Tick one off.',
    'streak.today_done': 'Today is done. See you tomorrow!',

    'profile.gallery': 'My gallery',
    'profile.personality': 'My personality',
    'profile.terms': 'Terms',
    'profile.settings': 'Settings',

    'xp.title': 'Coins and level',
    'xp.total': 'Total coins',
    'xp.level': 'Level',
    'xp.needed': 'To next level',
    'xp.progress': 'Progress to level {n}',

    'color.title': 'App color',
    'color.reset': 'Reset to default',
  };
}

extension TrContext on BuildContext {
  /// ترجمه بر اساس زبان فعلی MaterialApp. هر ویجتی که این را در build صدا بزند،
  /// با تغییر زبان خودکار دوباره ساخته می‌شود.
  String tr(String key, [Map<String, String>? args]) {
    final lang = Localizations.localeOf(this).languageCode;
    return AppStrings.t(lang, key, args);
  }

  bool get isEnglish => Localizations.localeOf(this).languageCode == 'en';
}
