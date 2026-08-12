// lib/features/chat/widgets/audio_player_header.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/services/audio_player_service.dart';

class AudioPlayerHeader extends StatefulWidget {
  const AudioPlayerHeader({super.key});

  @override
  State<AudioPlayerHeader> createState() => _AudioPlayerHeaderState();
}

class _AudioPlayerHeaderState extends State<AudioPlayerHeader> {
  late AudioPlayerService _audioService;

  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isBuffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _fileName;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _audioService = Provider.of<AudioPlayerService>(context, listen: false);
    _updateState();
    _audioService.addListener(_onAudioServiceChanged);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _audioService.removeListener(_onAudioServiceChanged);
    super.dispose();
  }

  void _onAudioServiceChanged() {
    if (_isDisposed || !mounted) return;
    _updateState();
  }

  void _updateState() {
    if (_isDisposed || !mounted) return;

    setState(() {
      _isPlaying = _audioService.isPlaying;
      _isLoading = _audioService.isLoading;
      _isBuffering = _audioService.isBuffering;
      _position = _audioService.position;
      _duration = _audioService.duration;
      _fileName = _audioService.currentFileName;
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _togglePlayback() {
    if (_audioService.currentUrl == null) return;
    _audioService.togglePlayback(
      _audioService.currentUrl!,
      fileName: _audioService.currentFileName,
    );
  }

  void _seekTo(double value) {
    if (_duration.inMilliseconds <= 0) return;
    final newPosition = Duration(
      milliseconds: (value * _duration.inMilliseconds).toInt(),
    );
    _audioService.seek(newPosition);
  }

  @override
  Widget build(BuildContext context) {
    if (_audioService.currentUrl == null) {
      return const SizedBox.shrink();
    }

    final bool isActive = _isPlaying || _isLoading || _isBuffering;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: isActive ? 56 : 0,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade800, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // ✅ آیکون
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _isBuffering
                    ? Colors.orange.shade700
                    : _isLoading
                    ? Colors.grey.shade700
                    : Colors.purple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _isBuffering
                  ? const Icon(
                      Icons.hourglass_empty,
                      color: Colors.orange,
                      size: 16,
                    )
                  : _isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _isPlaying ? Icons.music_note : Icons.music_note,
                      color: _isPlaying ? Colors.purple : Colors.grey.shade400,
                      size: 16,
                    ),
            ),
            const SizedBox(width: 8),

            // ✅ اطلاعات آهنگ
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _fileName ?? 'در حال بارگذاری...',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            Expanded(
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 2,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 4,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 6,
                                  ),
                                  activeTrackColor: _isLoading || _isBuffering
                                      ? Colors.grey.shade600
                                      : Colors.purple,
                                  inactiveTrackColor: Colors.grey.shade600,
                                  thumbColor: _isLoading || _isBuffering
                                      ? Colors.grey.shade600
                                      : Colors.purple,
                                  overlayColor: Colors.purple.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                                child: Slider(
                                  value: _duration.inMilliseconds > 0
                                      ? (_position.inMilliseconds /
                                                _duration.inMilliseconds)
                                            .clamp(0.0, 1.0)
                                      : 0.0,
                                  onChanged: (_isLoading || _isBuffering)
                                      ? null
                                      : (_duration.inMilliseconds > 0
                                            ? _seekTo
                                            : null),
                                  min: 0,
                                  max: 1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDuration(_position),
                              style: TextStyle(
                                fontSize: 8,
                                color: _isLoading || _isBuffering
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade400,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ✅ دکمه‌ها
            Row(
              children: [
                // دکمه بستن
                IconButton(
                  onPressed: () => _audioService.stop(),
                  icon: const Icon(Icons.close, color: Colors.grey, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 2),

                // دکمه پلی/مکث
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: (_isLoading || _isBuffering)
                        ? Colors.grey.shade600
                        : Colors.purple,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: (_isLoading || _isBuffering)
                        ? null
                        : _togglePlayback,
                    icon: _isLoading || _isBuffering
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 14,
                          ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
