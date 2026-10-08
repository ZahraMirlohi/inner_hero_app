// lib/services/audio_player_service.dart

import 'dart:async';
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

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<ProcessingState>? _processingStateSubscription;

  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  bool get isBuffering => _isBuffering;
  Duration get position => _position;
  Duration get duration => _duration;
  String? get currentUrl => _currentUrl;
  String? get currentFileName => _currentFileName;

  void _init() {
    _positionSubscription = _player.positionStream.listen((position) {
      if (_isDisposed) return;
      _position = position;
      notifyListeners();
    });

    _durationSubscription = _player.durationStream.listen((duration) {
      if (_isDisposed) return;
      if (duration != null && duration.inMilliseconds > 0) {
        _duration = duration;
        _isLoading = false;
        _isBuffering = false;
        notifyListeners();
      }
    });

    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (_isDisposed) return;
      _isPlaying = state.playing;

      if (_isPlaying && _duration.inMilliseconds == 0) {
        _isLoading = true;
      } else if (_duration.inMilliseconds > 0) {
        _isLoading = false;
      }

      notifyListeners();
    });

    _processingStateSubscription = _player.processingStateStream.listen((
      state,
    ) {
      if (_isDisposed) return;

      _isBuffering = state == ProcessingState.buffering;

      if (state == ProcessingState.completed) {
        _isPlaying = false;
        _position = Duration.zero;
        _isLoading = false;
        _isBuffering = false;
        notifyListeners();
      }

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

    if (_currentUrl == url && _isPlaying) {
      debugPrint('🎵 Already playing this URL');
      return;
    }

    if (_currentUrl != url) {
      await stop();
    }

    try {
      _isLoading = true;
      _isBuffering = false;
      _currentUrl = url;
      _currentFileName = fileName;
      _position = Duration.zero;
      _duration = Duration.zero;
      notifyListeners();

      debugPrint('🎵 Setting audio source...');

      // ✅ Timeout 30 ثانیه‌ای برای جلوگیری از گیر کردن
      await _player.setAudioSource(AudioSource.uri(Uri.parse(url))).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('❌ [AudioPlayerService] Timeout loading audio');
          throw TimeoutException('Audio loading timeout');
        },
      );

      debugPrint('🎵 Starting playback...');
      await _player.play();

      debugPrint('🎵 Playback started successfully');

      // ✅ بعد از 5 ثانیه اگر still loading، false کن
      Future.delayed(const Duration(seconds: 5), () {
        if (_isLoading && !_isDisposed) {
          debugPrint('⚠️ Force loading=false after timeout');
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

      // ✅ اگه خطا داد، دوباره به کاربر اطلاع بده
      rethrow;
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
      _duration = Duration.zero; // ✅ حالا duration هم صفر میشه
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

    if (_currentUrl == url && _isPlaying) {
      await pause();
    } else if (_currentUrl == url && !_isPlaying) {
      try {
        await _player.play();
        _isPlaying = true;
        notifyListeners();
      } catch (e) {
        debugPrint('❌ Resume error: $e');
        await play(url, fileName: fileName);
      }
    } else {
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

  bool isPlayingUrl(String url) {
    return _currentUrl == url && _isPlaying;
  }

  /// ✅ آزادسازی منابع
  Future<void> releasePlayer() async {
    if (_isDisposed) return;
    try {
      await _player.stop();
      _isPlaying = false;
      _isLoading = false;
      _isBuffering = false;
      _position = Duration.zero;
      _duration = Duration.zero;
      _currentUrl = null;
      _currentFileName = null;
      notifyListeners();
      debugPrint('🎵 Player released');
    } catch (e) {
      debugPrint('❌ Release error: $e');
    }
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
