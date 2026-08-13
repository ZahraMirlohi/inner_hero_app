// lib/services/download_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

class DownloadService extends ChangeNotifier {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final Map<String, _DownloadTask> _tasks = {};

  bool isDownloading(String url) => _tasks[url]?.isDownloading ?? false;
  double getProgress(String url) => _tasks[url]?.progress ?? 0.0;
  bool isDownloaded(String url) => _tasks[url]?.isDownloaded ?? false;
  String? getLocalPath(String url) => _tasks[url]?.localPath;

  Future<void> downloadFile({
    required String url,
    required String fileName,
    VoidCallback? onComplete,
  }) async {
    if (_tasks.containsKey(url) && _tasks[url]!.isDownloading) return;
    if (_tasks.containsKey(url) && _tasks[url]!.isDownloaded) return;

    // ✅ درخواست دسترسی برای Android 13+
    if (await _requestStoragePermission() == false) {
      throw Exception('دسترسی به حافظه داده نشد');
    }

    final task = _DownloadTask(url: url, fileName: fileName);
    _tasks[url] = task;
    notifyListeners();

    try {
      // ✅ دریافت مسیر پوشه Downloads
      final directory = await _getDownloadsDirectory();
      final localPath = '${directory.path}/${_sanitizeFileName(fileName)}';

      task.isDownloading = true;
      notifyListeners();

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final file = File(localPath);
        await file.writeAsBytes(response.bodyBytes);

        task.isDownloading = false;
        task.isDownloaded = true;
        task.localPath = localPath;
        task.progress = 1.0;
        notifyListeners();

        onComplete?.call();
      } else {
        task.isDownloading = false;
        task.progress = 0.0;
        notifyListeners();
        throw Exception('Download failed: ${response.statusCode}');
      }
    } catch (e) {
      task.isDownloading = false;
      task.progress = 0.0;
      notifyListeners();
      rethrow;
    }
  }

  // ✅ دریافت مسیر پوشه Downloads
  Future<Directory> _getDownloadsDirectory() async {
    try {
      // ✅ روش 1: برای Android 10 و بالاتر
      if (await _isAndroid11OrHigher()) {
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          // ساختار: Download/com.example.inner_hero_app/
          final downloadDir = Directory('${directory.path}/Downloads');
          if (!await downloadDir.exists()) {
            await downloadDir.create(recursive: true);
          }
          return downloadDir;
        }
      }

      // ✅ روش 2: روش قدیمی برای Android 9 و پایین‌تر
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        // مسیر: /storage/emulated/0/Download/
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (!await downloadDir.exists()) {
          // اگر وجود نداشت، در پوشه اپلیکیشن ذخیره کن
          final appDir = Directory('${directory.path}/Downloads');
          if (!await appDir.exists()) {
            await appDir.create(recursive: true);
          }
          return appDir;
        }
        return downloadDir;
      }

      // ✅ روش 3: Fallback
      final fallbackDir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${fallbackDir.path}/Downloads');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return downloadDir;
    } catch (e) {
      // ✅ در صورت خطا، از Documents استفاده کن
      final fallbackDir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${fallbackDir.path}/Downloads');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return downloadDir;
    }
  }

  // ✅ بررسی نسخه Android
  Future<bool> _isAndroid11OrHigher() async {
    // در اندروید 11 (API 30) و بالاتر
    return true; // فعلاً true برگردان
  }

  // ✅ درخواست دسترسی ذخیره‌سازی
  Future<bool> _requestStoragePermission() async {
    // برای Android 13+ (API 33)
    if (await _isAndroid13OrHigher()) {
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }

    // برای Android 10-12 (API 29-32)
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  Future<bool> _isAndroid13OrHigher() async {
    // در اندروید 13 (API 33) و بالاتر
    return true; // فعلاً true برگردان
  }

  String _sanitizeFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[^\w\-.]'), '_');
  }

  Future<bool> checkIfDownloaded(String url, String fileName) async {
    if (_tasks.containsKey(url) && _tasks[url]!.isDownloaded) return true;

    try {
      final directory = await _getDownloadsDirectory();
      final localPath = '${directory.path}/${_sanitizeFileName(fileName)}';
      final file = File(localPath);
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

  _DownloadTask({
    required this.url,
    required this.fileName,
    this.isDownloading = false,
    this.isDownloaded = false,
    this.progress = 0.0,
    this.localPath,
  });
}
