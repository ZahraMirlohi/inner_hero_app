// lib/features/chat/widgets/file_message_widget.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';

import '/services/audio_player_service.dart';

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

  @override
  void initState() {
    super.initState();
    _audioService = Provider.of<AudioPlayerService>(context, listen: false);
    _checkIfDownloaded();
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

  Future<void> _checkIfDownloaded() async {
    if (_isDisposed) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = _getLocalFileName(widget.fileUrl);
      final localPath = '${directory.path}/$fileName';
      final file = File(localPath);

      if (await file.exists()) {
        setState(() {
          _isDownloaded = true;
          _localFilePath = localPath;
        });
        debugPrint('✅ File already downloaded: $localPath');
        _updateStateFromService();
      } else {
        setState(() {
          _isDownloaded = false;
          _localFilePath = null;
        });
        debugPrint('📥 File not downloaded: $fileName');
      }
    } catch (e) {
      debugPrint('❌ Error checking file: $e');
      setState(() {
        _isDownloaded = false;
      });
    }
  }

  String _getLocalFileName(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        return segments.last;
      }
      return widget.fileName;
    } catch (e) {
      return widget.fileName;
    }
  }

  // ✅ دانلود فایل
  Future<void> _downloadFile() async {
    if (_isDownloading || _isDisposed) {
      debugPrint('⚠️ Download skipped: isDownloading=$_isDownloading');
      return;
    }

    debugPrint('📥 Starting download for: ${widget.fileName}');

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = _getLocalFileName(widget.fileUrl);
      final localPath = '${directory.path}/$fileName';

      final response = await http.get(Uri.parse(widget.fileUrl));
      if (response.statusCode == 200) {
        final file = File(localPath);
        await file.writeAsBytes(response.bodyBytes);

        setState(() {
          _isDownloaded = true;
          _localFilePath = localPath;
          _isDownloading = false;
          _downloadProgress = 1.0;
        });

        debugPrint('✅ File downloaded successfully: $localPath');
        _updateStateFromService();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${widget.fileName} دانلود شد'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Download failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Download error: $e');
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطا در دانلود: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ باز کردن فایل
  Future<void> _openFile() async {
    try {
      debugPrint('📂 Opening file: ${widget.fileName}');

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
      debugPrint('❌ Error opening file: $e');
      _showMessage('خطا در باز کردن فایل: ${e.toString()}');
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ✅ پخش/مکث آهنگ
  Future<void> _togglePlayback() async {
    if (_isDisposed) return;
    if (_isLoading || _isBuffering) return;

    if (!_isDownloaded) {
      await _downloadFile();
      return;
    }

    final playUrl = _localFilePath ?? widget.fileUrl;
    debugPrint('🎵 Toggling playback: $playUrl');

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

  // ==================== متدهای نمایشی ====================

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

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    if (widget.fileType == 'audio') {
      if (_isDownloading) {
        return _buildDownloadingCard();
      }
      if (!_isDownloaded) {
        return _buildDownloadCard();
      }
      return _buildAudioPlayer();
    }

    return _buildFileCard();
  }

  // ✅ کارت فایل معمولی
  Widget _buildFileCard() {
    return GestureDetector(
      onTap: _openFile,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isMe ? Colors.blue.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isMe ? Colors.blue.shade200 : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getFileColor().withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_getFileIcon(), color: _getFileColor(), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.fileName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.isMe ? Colors.black87 : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _formatFileSize(widget.fileSize),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _downloadFile,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: const Icon(
                  Icons.download_rounded,
                  color: Colors.blue,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ کارت دانلود
  Widget _buildDownloadCard() {
    return GestureDetector(
      onTap: _downloadFile,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isMe ? Colors.blue.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isMe ? Colors.blue.shade200 : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.download, color: Colors.orange, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.fileName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: widget.isMe ? Colors.black87 : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${_formatFileSize(widget.fileSize)} • برای باز کردن دانلود کنید',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'دانلود',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ کارت در حال دانلود
  Widget _buildDownloadingCard() {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isMe ? Colors.blue.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isMe ? Colors.blue.shade200 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.download, color: Colors.blue, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.fileName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: widget.isMe ? Colors.black87 : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'در حال دانلود...',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: _downloadProgress > 0 ? _downloadProgress : null,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _downloadProgress > 0 ? _downloadProgress : null,
              backgroundColor: Colors.grey.shade200,
              color: Colors.blue,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ پلیر آهنگ
  Widget _buildAudioPlayer() {
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
        width: 280,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isMe ? Colors.purple.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isMe ? Colors.purple.shade200 : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: showLoading
                        ? Colors.grey.shade300
                        : Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: showLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.purple,
                          ),
                        )
                      : Icon(
                          isThisPlaying ? Icons.music_note : Icons.music_note,
                          color: isThisPlaying
                              ? Colors.purple
                              : Colors.grey.shade500,
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
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.isMe ? Colors.black87 : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _formatFileSize(widget.fileSize),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _downloadFile,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(
                      Icons.download_rounded,
                      color: Colors.blue,
                      size: 18,
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
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: showLoading
                          ? Colors.grey.shade400
                          : isThisPlaying
                          ? Colors.purple
                          : Colors.purple,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: showLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isThisPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 20,
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
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 10,
                          ),
                          activeTrackColor: showLoading
                              ? Colors.grey.shade400
                              : Colors.purple,
                          inactiveTrackColor: Colors.grey.shade300,
                          thumbColor: showLoading
                              ? Colors.grey.shade400
                              : Colors.purple,
                          overlayColor: Colors.purple.withValues(alpha: 0.2),
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
                              color: showLoading
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _formatDuration(displayDuration),
                            style: TextStyle(
                              fontSize: 9,
                              color: showLoading
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
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

            if (showLoading)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Center(
                  child: Text(
                    _isBuffering
                        ? '⏳ در حال بافرینگ...'
                        : '⏳ در حال بارگذاری...',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==================== متدهای کمکی ====================

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

  Color _getFileColor() {
    final extension = widget.fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Colors.purple;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Colors.red;
      case 'mp3':
      case 'wav':
      case 'aac':
        return Colors.purple;
      case 'zip':
      case 'rar':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }
}
