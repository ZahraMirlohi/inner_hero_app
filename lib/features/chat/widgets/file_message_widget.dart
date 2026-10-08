// lib/features/chat/widgets/file_message_widget.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:open_file/open_file.dart';

import '/services/audio_player_service.dart';
import '/services/download_service.dart';
import '/providers/theme_provider.dart';
import '../utils/chat_colors.dart';

class FileMessageWidget extends StatefulWidget {
  final String fileUrl;
  final String fileName;
  final String fileType;
  final int fileSize;
  final bool isMe;

  const FileMessageWidget({
    super.key,
    required this.fileUrl,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.isMe,
  });

  @override
  State<FileMessageWidget> createState() => _FileMessageWidgetState();
}

class _FileMessageWidgetState extends State<FileMessageWidget> {
  late AudioPlayerService _audioService;
  late DownloadService _downloadService;

  bool _isDownloaded = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _localFilePath;

  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isBuffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  bool _isDisposed = false;
  bool _isInitialized = false;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _audioService = Provider.of<AudioPlayerService>(context, listen: false);
    _downloadService = Provider.of<DownloadService>(context, listen: false);

    _downloadService.addListener(_onDownloadServiceChanged);
    _checkIfDownloaded();
    _audioService.addListener(_onAudioServiceChanged);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _downloadService.removeListener(_onDownloadServiceChanged);
    _audioService.removeListener(_onAudioServiceChanged);
    super.dispose();
  }

  void _onDownloadServiceChanged() {
    if (_isDisposed || !mounted) return;

    final isDownloading = _downloadService.isDownloading(widget.fileUrl);
    final isDownloaded = _downloadService.isDownloaded(widget.fileUrl);
    final progress = _downloadService.getProgress(widget.fileUrl);
    final localPath = _downloadService.getLocalPath(widget.fileUrl);

    setState(() {
      _isDownloading = isDownloading;
      _isDownloaded = isDownloaded;
      _downloadProgress = progress;
      if (localPath != null) {
        _localFilePath = localPath;
      }
    });
  }

  Future<void> _checkIfDownloaded() async {
    if (_isDisposed || kIsWeb) return;

    final isDownloaded = await _downloadService.checkIfDownloaded(
      widget.fileUrl,
      widget.fileName,
    );

    if (mounted) {
      setState(() {
        _isDownloaded = isDownloaded;
        if (isDownloaded) {
          _localFilePath = _downloadService.getLocalPath(widget.fileUrl);
        }
      });
    }
  }

  Future<void> _downloadFile() async {
    if (_isDownloading || _isDisposed) return;

    if (mounted) {
      final theme = Provider.of<ThemeProvider>(context, listen: false);
      final textColor = widget.isMe
          ? ChatColors.myBubbleText(theme)
          : ChatColors.otherBubbleText(theme);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⬇️ شروع دانلود ${widget.fileName}'),
          backgroundColor: textColor,
          duration: const Duration(seconds: 1),
        ),
      );
    }

    await _downloadService.downloadFile(
      url: widget.fileUrl,
      fileName: widget.fileName,
      onComplete: () {
        if (mounted) {
          final theme = Provider.of<ThemeProvider>(context, listen: false);
          final textColor = widget.isMe
              ? ChatColors.myBubbleText(theme)
              : ChatColors.otherBubbleText(theme);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${widget.fileName} دانلود شد'),
              backgroundColor: textColor,
              duration: const Duration(seconds: 2),
            ),
          );
          setState(() {});
        }
      },
      onError: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ خطا در دانلود'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
          setState(() {});
        }
      },
    );
  }

  void _onAudioServiceChanged() {
    if (_isDisposed || !mounted) return;
    _updateStateFromService();
  }

  void _updateStateFromService() {
    if (_isDisposed || !mounted) return;

    final playUrl = _getPlayUrl();
    final bool isThisPlaying = _audioService.isPlayingUrl(playUrl);
    final bool isSameUrl = _audioService.currentUrl == playUrl;

    setState(() {
      if (isSameUrl || isThisPlaying) {
        _isPlaying = isThisPlaying;
        _isLoading = _audioService.isLoading;
        _isBuffering = _audioService.isBuffering;
        _position = _audioService.position;
        _duration = _audioService.duration;
      } else {
        if (_isPlaying || _isLoading || _isBuffering) {
          _isPlaying = false;
          _isLoading = false;
          _isBuffering = false;
          _position = Duration.zero;
        }
      }
    });
  }

  String _getPlayUrl() {
    return _localFilePath ?? widget.fileUrl;
  }

  Future<void> _openFile() async {
    try {
      if (!_isDownloaded) {
        await _downloadFile();
        if (!_isDownloaded) {
          _showMessage('فایل دانلود نشد');
          return;
        }
      }

      if (_localFilePath != null) {
        final file = File(_localFilePath!);
        if (await file.exists()) {
          final result = await OpenFile.open(_localFilePath!);
          if (result.type != ResultType.done) {
            _showMessage('خطا در باز کردن فایل: ${result.message}');
          }
        } else {
          _showMessage('فایل یافت نشد');
        }
      } else {
        _showMessage('مسیر فایل موجود نیست');
      }
    } catch (e) {
      _showMessage('خطا در باز کردن فایل: ${e.toString()}');
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      final theme = Provider.of<ThemeProvider>(context, listen: false);
      final textColor = widget.isMe
          ? ChatColors.myBubbleText(theme)
          : ChatColors.otherBubbleText(theme);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: textColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _togglePlayback() async {
    if (_isDisposed) return;
    if (_isLoading || _isBuffering) return;

    if (!_isDownloaded) {
      await _downloadFile();
      return;
    }

    final playUrl = _localFilePath ?? widget.fileUrl;

    setState(() {
      _isLoading = true;
      _isPlaying = !_isPlaying;
    });

    await _audioService.togglePlayback(playUrl, fileName: widget.fileName);

    Future.delayed(const Duration(milliseconds: 200), () {
      _updateStateFromService();
    });
  }

  void _seekTo(double value) {
    if (_duration.inMilliseconds <= 0 || _isDisposed) return;
    final newPosition = Duration(
      milliseconds: (value * _duration.inMilliseconds).toInt(),
    );
    _audioService.seek(newPosition);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    // ✅ رنگ‌های پویا بر اساس تم روز/شب و اینکه پیام من است یا مقابل
    final Color bgColor = widget.isMe
        ? ChatColors.myBubble(theme)
        : ChatColors.otherBubble(theme);
    final Color textColor = widget.isMe
        ? ChatColors.myBubbleText(theme)
        : ChatColors.otherBubbleText(theme);
    final Color textSecondary = widget.isMe
        ? ChatColors.myBubbleTextSecondary(theme)
        : ChatColors.otherBubbleTextSecondary(theme);

    if (widget.fileType == 'audio') {
      if (_isDownloading) {
        return _buildDownloadingCard(bgColor, textColor, textSecondary);
      }
      if (!_isDownloaded) {
        return _buildDownloadCard(bgColor, textColor, textSecondary);
      }
      return _buildAudioPlayer(bgColor, textColor, textSecondary);
    }

    return _buildFileCard(bgColor, textColor, textSecondary);
  }

  // ✅ کارت فایل
  Widget _buildFileCard(
    Color bgColor,
    Color textColor,
    Color textSecondary,
  ) {
    final bool isDownloading = _downloadService.isDownloading(widget.fileUrl);
    final bool isDownloaded = _downloadService.isDownloaded(widget.fileUrl);
    final double progress = _downloadService.getProgress(widget.fileUrl);

    return GestureDetector(
      onTap: isDownloaded ? _openFile : null,
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isDownloading
                  ? Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: textColor,
                        ),
                      ),
                    )
                  : Icon(
                      _getFileIcon(),
                      color: textColor,
                      size: 22,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.fileName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isDownloading
                        ? 'در حال دانلود... ${(progress * 100).toInt()}%'
                        : _formatFileSize(widget.fileSize),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDownloading ? textColor : textSecondary,
                      fontWeight:
                          isDownloading ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: isDownloading ? null : _downloadFile,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: textColor.withValues(alpha: 0.2),
                  ),
                ),
                child: isDownloading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: textColor,
                        ),
                      )
                    : Icon(
                        Icons.download_rounded,
                        color: textColor,
                        size: 16,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ کارت دانلود
  Widget _buildDownloadCard(
    Color bgColor,
    Color textColor,
    Color textSecondary,
  ) {
    return GestureDetector(
      onTap: _downloadFile,
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.download,
                color: textColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.fileName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${_formatFileSize(widget.fileSize)} • برای باز کردن دانلود کنید',
                    style: TextStyle(
                      fontSize: 10,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: textColor.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                'دانلود',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ کارت در حال دانلود
  Widget _buildDownloadingCard(
    Color bgColor,
    Color textColor,
    Color textSecondary,
  ) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.download,
                  color: textColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.fileName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'در حال دانلود...',
                      style: TextStyle(
                        fontSize: 10,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: _downloadProgress > 0 ? _downloadProgress : null,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _downloadProgress > 0 ? _downloadProgress : null,
              backgroundColor: textColor.withValues(alpha: 0.15),
              color: textColor,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ پلیر موزیک
  Widget _buildAudioPlayer(
    Color bgColor,
    Color textColor,
    Color textSecondary,
  ) {
    final bool showLoading = _isLoading || _isBuffering;
    final bool isThisPlaying = _isPlaying;
    final bool isCurrent = _audioService.currentUrl == _getPlayUrl();

    Duration displayPosition = isCurrent ? _audioService.position : _position;
    Duration displayDuration = isCurrent ? _audioService.duration : _duration;

    if (displayDuration.inMilliseconds <= 0 && _isDownloaded) {
      displayDuration = const Duration(seconds: 180);
    }

    return GestureDetector(
      onTap: _openFile,
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: showLoading
                      ? Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: textColor,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.music_note,
                          color: textColor,
                          size: 20,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.fileName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _formatFileSize(widget.fileSize),
                        style: TextStyle(
                          fontSize: 10,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _downloadFile,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: textColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Icon(
                      Icons.download_rounded,
                      color: textColor,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: showLoading ? null : _togglePlayback,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: showLoading
                          ? textColor.withValues(alpha: 0.2)
                          : textColor,
                      shape: BoxShape.circle,
                    ),
                    child: showLoading
                        ? Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: textColor,
                              ),
                            ),
                          )
                        : Icon(
                            isThisPlaying ? Icons.pause : Icons.play_arrow,
                            color: bgColor,
                            size: 18,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 5,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 9,
                          ),
                          activeTrackColor: textColor,
                          inactiveTrackColor: textColor.withValues(alpha: 0.15),
                          thumbColor: textColor,
                          overlayColor: textColor.withValues(alpha: 0.2),
                        ),
                        child: Slider(
                          value: displayDuration.inMilliseconds > 0
                              ? (displayPosition.inMilliseconds /
                                      displayDuration.inMilliseconds)
                                  .clamp(0.0, 1.0)
                              : 0.0,
                          onChanged: showLoading
                              ? null
                              : (displayDuration.inMilliseconds > 0
                                  ? _seekTo
                                  : null),
                          min: 0,
                          max: 1,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(displayPosition),
                            style: TextStyle(
                              fontSize: 9,
                              color: textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _formatDuration(displayDuration),
                            style: TextStyle(
                              fontSize: 9,
                              color: textSecondary,
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
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon() {
    final extension = widget.fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_library;
      case 'mp3':
      case 'wav':
      case 'aac':
        return Icons.audiotrack;
      case 'zip':
      case 'rar':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }
}
