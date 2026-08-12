// lib/services/audio_player_service.dart

import 'dart:async'; // ✅ این خط را اضافه کنید
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';

class AudioPlayerService extends ChangeNotifier {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal() {
    _init();
  }

  final AudioPlayer _player = AudioPlayer();

  // ✅ وضعیت‌ها
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isBuffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _currentUrl;
  String? _currentFileName;
  bool _isDisposed = false;

  // ✅ Stream subscriptions برای مدیریت بهتر
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<ProcessingState>? _processingStateSubscription;

  // ✅ Getters
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  bool get isBuffering => _isBuffering;
  Duration get position => _position;
  Duration get duration => _duration;
  String? get currentUrl => _currentUrl;
  String? get currentFileName => _currentFileName;

  void _init() {
    // ✅ گوش دادن به position
    _positionSubscription = _player.positionStream.listen((position) {
      if (_isDisposed) return;
      _position = position;
      notifyListeners();
    });

    // ✅ گوش دادن به duration
    _durationSubscription = _player.durationStream.listen((duration) {
      if (_isDisposed) return;
      if (duration != null) {
        _duration = duration;
        _isLoading = false;
        _isBuffering = false;
        notifyListeners();
      }
    });

    // ✅ گوش دادن به playerState (برای isPlaying)
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (_isDisposed) return;
      _isPlaying = state.playing;

      // ✅ اگر پلی شد و duration مشخص نیست، isLoading = true
      if (_isPlaying && _duration.inMilliseconds == 0) {
        _isLoading = true;
      } else if (_duration.inMilliseconds > 0) {
        _isLoading = false;
      }

      notifyListeners();
    });

    // ✅ گوش دادن به processingState (برای buffering و خطا)
    _processingStateSubscription = _player.processingStateStream.listen((
      state,
    ) {
      if (_isDisposed) return;

      // ✅ وضعیت buffering
      _isBuffering = state == ProcessingState.buffering;

      // ✅ اگر به پایان رسید
      if (state == ProcessingState.completed) {
        _isPlaying = false;
        _position = Duration.zero;
        _isLoading = false;
        _isBuffering = false;
        notifyListeners();
      }

      // ✅ اگر خطا رخ داد
      if (state == ProcessingState.idle && _isLoading) {
        _isLoading = false;
        _isBuffering = false;
        notifyListeners();
      }
    });
  }

  // ==================== متدهای اصلی ====================

  /// ✅ پخش آهنگ جدید
  Future<void> play(String url, {String? fileName}) async {
    if (_isDisposed) return;
    if (url.isEmpty) return;

    debugPrint('🎵 [AudioPlayerService] play() called for: $url');

    // ✅ اگر همان آهنگ در حال پخش است
    if (_currentUrl == url && _isPlaying) {
      debugPrint('🎵 Already playing this URL');
      return;
    }

    // ✅ اگر آهنگ متفاوت است، متوقف کن
    if (_currentUrl != url) {
      await stop();
    }

    try {
      // ✅ تنظیم وضعیت لودینگ
      _isLoading = true;
      _isBuffering = false;
      _currentUrl = url;
      _currentFileName = fileName;
      _position = Duration.zero;
      _duration = Duration.zero;
      notifyListeners();

      debugPrint('🎵 Setting audio source...');
      await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));

      debugPrint('🎵 Starting playback...');
      await _player.play();

      debugPrint('🎵 Playback started successfully');

      // ✅ بعد از 2 ثانیه اگر still loading، false کن
      Future.delayed(const Duration(seconds: 2), () {
        if (_isLoading && !_isDisposed) {
          _isLoading = false;
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('❌ [AudioPlayerService] Play error: $e');
      _isLoading = false;
      _isBuffering = false;
      _currentUrl = null;
      _currentFileName = null;
      notifyListeners();
    }
  }

  /// ✅ مکث
  Future<void> pause() async {
    if (_isDisposed) return;
    debugPrint('🎵 [AudioPlayerService] pause() called');

    try {
      await _player.pause();
      _isPlaying = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [AudioPlayerService] Pause error: $e');
    }
  }

  /// ✅ توقف کامل
  Future<void> stop() async {
    if (_isDisposed) return;
    debugPrint('🎵 [AudioPlayerService] stop() called');

    try {
      await _player.stop();
      _isPlaying = false;
      _isLoading = false;
      _isBuffering = false;
      _position = Duration.zero;
      _currentUrl = null;
      _currentFileName = null;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [AudioPlayerService] Stop error: $e');
    }
  }

  /// ✅ تغییر وضعیت پلی/مکث
  Future<void> togglePlayback(String url, {String? fileName}) async {
    if (_isDisposed) return;
    if (url.isEmpty) return;

    debugPrint('🎵 [AudioPlayerService] togglePlayback() called');
    debugPrint(
      '🎵 currentUrl=$_currentUrl, isPlaying=$_isPlaying, targetUrl=$url',
    );

    // ✅ اگر همان آهنگ در حال پخش است → مکث
    if (_currentUrl == url && _isPlaying) {
      await pause();
    }
    // ✅ اگر همان آهنگ است ولی متوقف شده → پلی
    else if (_currentUrl == url && !_isPlaying) {
      try {
        await _player.play();
        _isPlaying = true;
        notifyListeners();
      } catch (e) {
        debugPrint('❌ Resume error: $e');
        // اگر خطا داد، از اول پلی کن
        await play(url, fileName: fileName);
      }
    }
    // ✅ آهنگ جدید → پلی
    else {
      await play(url, fileName: fileName);
    }
  }

  /// ✅ تغییر موقعیت (Seek)
  Future<void> seek(Duration position) async {
    if (_isDisposed) return;
    if (_duration.inMilliseconds == 0) return;

    try {
      await _player.seek(position);
      _position = position;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [AudioPlayerService] Seek error: $e');
    }
  }

  /// ✅ بررسی آیا آهنگ مشخصی در حال پخش است
  bool isPlayingUrl(String url) {
    return _currentUrl == url && _isPlaying;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _processingStateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }
}
