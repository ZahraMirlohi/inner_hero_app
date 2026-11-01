// lib/services/notification_service.dart
//
// یادآور روزانهٔ عادت‌ها (اعلان محلی). با تنظیمات «اعلان‌ها» و «یادآوری عادت‌ها» کنترل می‌شود
// و ساعتش را کاربر تعیین می‌کند. روی وب کاری نمی‌کند (بدون خطا).

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_strings.dart';
import '../providers/settings_provider.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String _kHour = 'reminder_hour';
  static const String _kMinute = 'reminder_minute';
  static const int _dailyId = 1001;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  bool get _supported => !kIsWeb;

  Future<void> init() async {
    if (!_supported || _ready) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final name = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(name));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Asia/Tehran'));
      }
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );
      _ready = true;
    } catch (e) {
      if (kDebugMode) debugPrint('NotificationService init failed: $e');
    }
  }

  Future<TimeOfDayLite> reminderTime() async {
    try {
      final p = await SharedPreferences.getInstance();
      return TimeOfDayLite(p.getInt(_kHour) ?? 20, p.getInt(_kMinute) ?? 0);
    } catch (_) {
      return const TimeOfDayLite(20, 0);
    }
  }

  Future<void> setReminderTime(int hour, int minute) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_kHour, hour);
      await p.setInt(_kMinute, minute);
    } catch (_) {}
    await reschedule();
  }

  /// درخواست اجازه (اندروید ۱۳+ و iOS). false یعنی کاربر نداد.
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    await init();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final a = await android?.requestNotificationsPermission();
      final i = await ios?.requestPermissions(alert: true, sound: true);
      return (a ?? i ?? true);
    } catch (_) {
      return false;
    }
  }

  /// بر اساس تنظیمات فعلی، یادآور را می‌گذارد یا برمی‌دارد
  Future<void> reschedule() async {
    if (!_supported) return;
    await init();
    if (!_ready) return;
    try {
      await _plugin.cancel(_dailyId);
      final settings = SettingsProvider.current;
      if (settings == null || !settings.notifHabits) return;

      final lang = settings.language;
      final t = await reminderTime();
      final now = tz.TZDateTime.now(tz.local);
      var when =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, t.hour, t.minute);
      if (!when.isAfter(now)) when = when.add(const Duration(days: 1));

      final n = Random().nextInt(4) + 1;
      await _plugin.zonedSchedule(
        _dailyId,
        AppStrings.t(lang, 'notif.title'),
        AppStrings.t(lang, 'notif.body$n'),
        when,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder',
            AppStrings.t(lang, 'notif.channel'),
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('NotificationService schedule failed: $e');
    }
  }

  Future<void> cancelAll() async {
    if (!_supported || !_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}

class TimeOfDayLite {
  final int hour;
  final int minute;
  const TimeOfDayLite(this.hour, this.minute);
}
