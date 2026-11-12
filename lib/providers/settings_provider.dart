// lib/providers/settings_provider.dart
//
// تنظیمات کاربر که روی خود گوشی ذخیره می‌شن (زبان، صدا، لرزش، اعلان‌ها).
// قبل از runApp با SettingsProvider.load() بارگذاری می‌شه تا اولین فریم درست رسم بشه.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

import '../l10n/app_strings.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider._(this._prefs) {
    current = this;
    _read();
  }

  /// دسترسی سراسری برای سرویس‌هایی که context ندارن (مثل SoundService)
  static SettingsProvider? current;

  final SharedPreferences? _prefs;

  static const _kLang = 'settings_language';
  static const _kSound = 'settings_sound';
  static const _kVibration = 'settings_vibration';
  static const _kNotif = 'settings_notifications';
  static const _kNotifHabits = 'settings_notif_habits';
  static const _kNotifChat = 'settings_notif_chat';
  static const _kNotifChallenges = 'settings_notif_challenges';
  static const _kNotifXp = 'settings_notif_xp';
  static const _kNotifRequests = 'settings_notif_requests';
  static const _kNotifStreak = 'settings_notif_streak';
  static const _kNotifTimer = 'settings_notif_timer';
  static const _kPrivate = 'settings_private_profile';

  String _language = 'fa';
  bool _sound = true;
  bool _vibration = true;
  bool _notifications = true;
  bool _notifHabits = true;
  bool _notifChat = true;
  bool _notifChallenges = true;
  bool _notifXp = true;
  bool _notifRequests = true;
  bool _notifStreak = true;
  bool _notifTimer = true;
  bool _privateProfile = false;

  static Future<SettingsProvider> load() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}
    return SettingsProvider._(prefs);
  }

  void _read() {
    final p = _prefs;
    if (p == null) return;
    _language = p.getString(_kLang) ?? 'fa';
    _sound = p.getBool(_kSound) ?? true;
    _vibration = p.getBool(_kVibration) ?? true;
    _notifications = p.getBool(_kNotif) ?? true;
    _notifHabits = p.getBool(_kNotifHabits) ?? true;
    _notifChat = p.getBool(_kNotifChat) ?? true;
    _notifChallenges = p.getBool(_kNotifChallenges) ?? true;
    _notifXp = p.getBool(_kNotifXp) ?? true;
    _notifRequests = p.getBool(_kNotifRequests) ?? true;
    _notifStreak = p.getBool(_kNotifStreak) ?? true;
    _notifTimer = p.getBool(_kNotifTimer) ?? true;
    _privateProfile = p.getBool(_kPrivate) ?? false;
  }

  // ── getterها ──
  String get language => _language;
  bool get isEnglish => _language == 'en';
  Locale get locale => AppStrings.localeFor(_language);
  bool get soundEnabled => _sound;
  bool get vibrationEnabled => _vibration;
  bool get notificationsEnabled => _notifications;
  bool get notifHabits => _notifications && _notifHabits;
  bool get notifChat => _notifications && _notifChat;
  bool get notifChallenges => _notifications && _notifChallenges;
  bool get notifXp => _notifications && _notifXp;
  bool get notifRequests => _notifications && _notifRequests;
  bool get notifStreak => _notifications && _notifStreak;
  bool get notifTimer => _notifications && _notifTimer;
  bool get rawNotifRequests => _notifRequests;
  bool get rawNotifStreak => _notifStreak;
  bool get rawNotifTimer => _notifTimer;
  bool get rawNotifHabits => _notifHabits;
  bool get rawNotifChat => _notifChat;
  bool get rawNotifChallenges => _notifChallenges;
  bool get rawNotifXp => _notifXp;
  bool get privateProfile => _privateProfile;

  // ── setterها (اول UI آپدیت می‌شه، بعد ذخیره) ──
  Future<void> setLanguage(String code) =>
      _set(_kLang, code == 'en' ? 'en' : 'fa', () => _language = code == 'en' ? 'en' : 'fa');
  Future<void> setSound(bool v) => _set(_kSound, v, () => _sound = v);
  Future<void> setVibration(bool v) =>
      _set(_kVibration, v, () => _vibration = v);
  Future<void> setNotifications(bool v) async {
    await _set(_kNotif, v, () => _notifications = v);
    if (v) await NotificationService.instance.requestPermission();
    await NotificationService.instance.reschedule();
  }

  Future<void> setNotifHabits(bool v) async {
    await _set(_kNotifHabits, v, () => _notifHabits = v);
    if (v) await NotificationService.instance.requestPermission();
    await NotificationService.instance.reschedule();
  }
  Future<void> setNotifChat(bool v) =>
      _set(_kNotifChat, v, () => _notifChat = v);
  Future<void> setNotifChallenges(bool v) =>
      _set(_kNotifChallenges, v, () => _notifChallenges = v);
  Future<void> setNotifXp(bool v) => _set(_kNotifXp, v, () => _notifXp = v);
  Future<void> setNotifRequests(bool v) =>
      _set(_kNotifRequests, v, () => _notifRequests = v);
  Future<void> setNotifStreak(bool v) async {
    await _set(_kNotifStreak, v, () => _notifStreak = v);
    if (v) await NotificationService.instance.requestPermission();
    await NotificationService.instance.reschedule();
  }

  Future<void> setNotifTimer(bool v) =>
      _set(_kNotifTimer, v, () => _notifTimer = v);
  Future<void> setPrivateProfile(bool v) =>
      _set(_kPrivate, v, () => _privateProfile = v);

  Future<void> _set(String key, Object value, VoidCallback apply) async {
    apply();
    notifyListeners();
    try {
      final p = _prefs;
      if (p == null) return;
      if (value is bool) {
        await p.setBool(key, value);
      } else if (value is String) {
        await p.setString(key, value);
      }
    } catch (_) {
      // ذخیره نشد؛ تنظیم تا آخر همین اجرا کار می‌کنه
    }
  }
}
