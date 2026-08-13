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
  String? getErrorMessage(String url) => _tasks[url]?.errorMessage;

  Future<void> downloadFile({
    required String url,
    required String fileName,
    VoidCallback? onComplete,
    VoidCallback? onError,
  }) async {
    if (_tasks.containsKey(url) && _tasks[url]!.isDownloading) {
      print('⏳ Already downloading: $fileName');
      return;
    }

    if (_tasks.containsKey(url) && _tasks[url]!.isDownloaded) {
      print('✅ Already downloaded: $fileName');
      onComplete?.call();
      return;
    }

    // ✅ درخواست دسترسی
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      _tasks[url] = _DownloadTask(
        url: url,
        fileName: fileName,
        errorMessage: 'دسترسی به حافظه داده نشد',
      );
      notifyListeners();
      onError?.call();
      return;
    }

    final task = _DownloadTask(url: url, fileName: fileName);
    _tasks[url] = task;
    notifyListeners();

    try {
      // ✅ دریافت مسیر صحیح Downloads
      final String downloadPath = await _getDownloadsPath();
      final String localPath = '$downloadPath/${_sanitizeFileName(fileName)}';

      task.isDownloading = true;
      task.progress = 0.0;
      notifyListeners();

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final file = File(localPath);
        await file.writeAsBytes(response.bodyBytes);

        task.isDownloading = false;
        task.isDownloaded = true;
        task.localPath = localPath;
        task.progress = 1.0;
        task.errorMessage = null;
        notifyListeners();

        // ✅ اطلاع رسانی به سیستم
        await _notifyDownloadManager(localPath, fileName);

        onComplete?.call();
      } else {
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

  // ✅ دریافت مسیر صحیح Downloads
  Future<String> _getDownloadsPath() async {
    try {
      // ✅ روش 1: مسیر مستقیم Downloads
      final String downloadsPath = '/storage/emulated/0/Download';
      final Directory downloadsDir = Directory(downloadsPath);

      if (await downloadsDir.exists()) {
        print('📁 Using downloads path: $downloadsPath');
        return downloadsPath;
      }

      // ✅ روش 2: استفاده از path_provider
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        final String appDownloadPath = '${directory.path}/Download';
        final Directory appDownloadDir = Directory(appDownloadPath);
        if (!await appDownloadDir.exists()) {
          await appDownloadDir.create(recursive: true);
        }
        print('📁 Using app download path: $appDownloadPath');
        return appDownloadPath;
      }

      // ✅ روش 3: Fallback به Documents
      final docDir = await getApplicationDocumentsDirectory();
      final String fallbackPath = '${docDir.path}/Downloads';
      final Directory fallbackDir = Directory(fallbackPath);
      if (!await fallbackDir.exists()) {
        await fallbackDir.create(recursive: true);
      }
      print('📁 Using fallback path: $fallbackPath');
      return fallbackPath;
    } catch (e) {
      print('❌ Error getting downloads path: $e');
      final docDir = await getApplicationDocumentsDirectory();
      final String fallbackPath = '${docDir.path}/Downloads';
      final Directory fallbackDir = Directory(fallbackPath);
      if (!await fallbackDir.exists()) {
        await fallbackDir.create(recursive: true);
      }
      return fallbackPath;
    }
  }

  Future<void> _notifyDownloadManager(String path, String fileName) async {
    try {
      print('📁 File saved to: $path');
    } catch (e) {
      print('⚠️ Could not notify download manager: $e');
    }
  }

  Future<bool> _requestStoragePermission() async {
    try {
      if (await _isAndroid13OrHigher()) {
        final status = await Permission.photos.request();
        return status.isGranted || status.isLimited;
      }

      final status = await Permission.storage.request();
      return status.isGranted;
    } catch (e) {
      print('❌ Permission error: $e');
      return false;
    }
  }

  Future<bool> _isAndroid13OrHigher() async {
    try {
      return true;
    } catch (e) {
      return false;
    }
  }

  String _sanitizeFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[^\w\-.]'), '_');
  }

  Future<bool> checkIfDownloaded(String url, String fileName) async {
    if (_tasks.containsKey(url) && _tasks[url]!.isDownloaded) return true;

    try {
      final String downloadPath = await _getDownloadsPath();
      final String localPath = '$downloadPath/${_sanitizeFileName(fileName)}';
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
