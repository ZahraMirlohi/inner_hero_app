// lib/services/download_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class DownloadService extends ChangeNotifier {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final Map<String, _DownloadTask> _tasks = {};

  bool isDownloading(String url) => _tasks[url]?.isDownloading ?? false;
  double getProgress(String url) => _tasks[url]?.progress ?? 0.0;
  bool isDownloaded(String url) => _tasks[url]?.isDownloaded ?? false;
  String? getLocalPath(String url) => _tasks[url]?.localPath;
  String? getErrorMessage(String url) => _tasks[url]?.errorMessage;

  Future<void> downloadFile({
    required String url,
    required String fileName,
    VoidCallback? onComplete,
    VoidCallback? onError,
  }) async {
    // در Web، فقط لینک رو باز کن
    if (kIsWeb) {
      _handleWebDownload(url, fileName, onComplete, onError);
      return;
    }

    if (_tasks.containsKey(url) && _tasks[url]!.isDownloading) {
      print('Already downloading: $fileName');
      return;
    }

    if (_tasks.containsKey(url) && _tasks[url]!.isDownloaded) {
      print('Already downloaded: $fileName');
      onComplete?.call();
      return;
    }

    final task = _DownloadTask(url: url, fileName: fileName);
    _tasks[url] = task;
    notifyListeners();

    try {
      final String downloadPath = await _getDownloadsPath();
      final String localPath = _localPathFor(downloadPath, url, fileName);

      task.isDownloading = true;
      task.progress = 0.0;
      notifyListeners();

      final client = http.Client();
      final response = await client.send(http.Request('GET', Uri.parse(url)));
      if (response.statusCode == 200) {
        final file = File('$localPath.part');
        final sink = file.openWrite();
        final total = response.contentLength ?? 0;
        var received = 0;
        var lastNotify = 0;
        try {
          await for (final chunk in response.stream) {
            sink.add(chunk);
            received += chunk.length;
            if (total > 0 && received - lastNotify > total ~/ 50) {
              lastNotify = received;
              task.progress = received / total;
              notifyListeners();
            }
          }
        } finally {
          await sink.close();
          client.close();
        }
        await file.rename(localPath); // فایل نیمه‌کاره هرگز کامل حساب نمی‌شود

        task.isDownloading = false;
        task.isDownloaded = true;
        task.localPath = localPath;
        task.progress = 1.0;
        task.errorMessage = null;
        notifyListeners();

        print('File saved to: $localPath');
        onComplete?.call();
      } else {
        client.close();
        task.isDownloading = false;
        task.progress = 0.0;
        task.errorMessage = 'Download failed: ${response.statusCode}';
        notifyListeners();
        onError?.call();
      }
    } catch (e) {
      task.isDownloading = false;
      task.progress = 0.0;
      task.errorMessage = e.toString();
      notifyListeners();
      onError?.call();
    }
  }

  // Web download: لینک رو در تب جدید باز کن
  void _handleWebDownload(
    String url,
    String fileName,
    VoidCallback? onComplete,
    VoidCallback? onError,
  ) {
    try {
      // در Web، بهترین راه اینه که لینک رو باز کنی
      // مرورگر خودش فایل رو دانلود می‌کنه
      // این کار رو در UI انجام بدید با url_launcher
      _tasks[url] = _DownloadTask(
        url: url,
        fileName: fileName,
        isDownloaded: true,
        progress: 1.0,
      );
      notifyListeners();
      onComplete?.call();
    } catch (e) {
      print('Web download error: $e');
      onError?.call();
    }
  }

  // پوشه‌ی اختصاصی برنامه: روی اندروید ۱۰+ بدون نیاز به مجوز کار می‌کند
  Future<String> _getDownloadsPath() async {
    Directory? base;
    try {
      if (Platform.isAndroid) base = await getExternalStorageDirectory();
    } catch (_) {}
    base ??= await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/chat_files');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  // نام یکتا برای هر لینک تا دو فایل هم‌نام روی هم نیفتند
  String _localPathFor(String dir, String url, String fileName) =>
      '$dir/${url.hashCode.abs()}_${_sanitizeFileName(fileName)}';

  String _sanitizeFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[^\w\-.]'), '_');
  }

  Future<bool> checkIfDownloaded(String url, String fileName) async {
    if (kIsWeb) return false;

    if (_tasks.containsKey(url) && _tasks[url]!.isDownloaded) return true;

    try {
      final String downloadPath = await _getDownloadsPath();
      final String localPath = _localPathFor(downloadPath, url, fileName);
      final File file = File(localPath);
      if (await file.exists()) {
        _tasks[url] = _DownloadTask(
          url: url,
          fileName: fileName,
          isDownloaded: true,
          localPath: localPath,
          progress: 1.0,
        );
        notifyListeners();
        return true;
      }
    } catch (e) {
      // ignore
    }
    return false;
  }

  void clearTask(String url) {
    _tasks.remove(url);
    notifyListeners();
  }
}

class _DownloadTask {
  final String url;
  final String fileName;
  bool isDownloading;
  bool isDownloaded;
  double progress;
  String? localPath;
  String? errorMessage;

  _DownloadTask({
    required this.url,
    required this.fileName,
    this.isDownloading = false,
    this.isDownloaded = false,
    this.progress = 0.0,
    this.localPath,
    this.errorMessage,
  });
}
