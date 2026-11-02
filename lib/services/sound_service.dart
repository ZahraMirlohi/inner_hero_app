// lib/services/sound_service.dart
//
// افکت‌های صوتی و لرزش. صداها از assets/sounds/ پخش می‌شن و
// با تنظیمات «صدا» و «لرزش» کاربر هماهنگ هستن. خطاهای پخش هیچ‌وقت به UI نمی‌رسن.
//
// استفاده:  SoundService.instance.play(Sfx.check);

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../providers/settings_provider.dart';

enum Sfx { tap, check, complete, levelUp, message, error }

class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  static const Map<Sfx, String> _assets = {
    Sfx.tap: 'assets/sounds/tap.mp3',
    Sfx.check: 'assets/sounds/check.mp3',
    Sfx.complete: 'assets/sounds/complete.mp3',
    Sfx.levelUp: 'assets/sounds/level_up.mp3',
    Sfx.message: 'assets/sounds/message.mp3',
    Sfx.error: 'assets/sounds/error.mp3',
  };

  final Map<Sfx, AudioPlayer> _players = {};
  final Set<Sfx> _failed = {};

  SettingsProvider? get _settings => SettingsProvider.current;

  /// صدا + لرزش مناسب همون رویداد
  Future<void> play(Sfx sfx) async {
    unawaited(_haptic(sfx));
    await _sound(sfx);
  }

  Future<void> _sound(Sfx sfx) async {
    if (!(_settings?.soundEnabled ?? true)) return;
    if (_failed.contains(sfx)) return;
    try {
      final player = _players.putIfAbsent(sfx, () => AudioPlayer());
      if (player.audioSource == null) {
        await player.setAsset(_assets[sfx]!);
      }
      await player.seek(Duration.zero);
      unawaited(player.play());
    } catch (e) {
      _failed.add(sfx); // اگه فایل نبود یا پلتفرم پشتیبانی نکرد، دیگه تلاش نمی‌کنیم
      if (kDebugMode) debugPrint('SoundService: $sfx failed: $e');
    }
  }

  Future<void> _haptic(Sfx sfx) async {
    if (!(_settings?.vibrationEnabled ?? true)) return;
    try {
      switch (sfx) {
        case Sfx.tap:
          await HapticFeedback.selectionClick();
          break;
        case Sfx.check:
        case Sfx.message:
          await HapticFeedback.lightImpact();
          break;
        case Sfx.complete:
          await HapticFeedback.mediumImpact();
          break;
        case Sfx.levelUp:
          await HapticFeedback.heavyImpact();
          break;
        case Sfx.error:
          await HapticFeedback.vibrate();
          break;
      }
    } catch (_) {}
  }

  Future<void> dispose() async {
    for (final p in _players.values) {
      await p.dispose();
    }
    _players.clear();
  }
}
