// lib/services/download_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
    // ✅ در Web، فقط لینک رو باز کن
    if (kIsWeb) {
      _handleWebDownload(url, fileName, onComplete, onError);
      return;
    }

    if (_tasks.containsKey(url) && _tasks[url]!.isDownloading) {
      print('⏳ Already downloading: $fileName');
      return;
    }

    if (_tasks.containsKey(url) && _tasks[url]!.isDownloaded) {
      print('✅ Already downloaded: $fileName');
      onComplete?.call();
      return;
    }

    // ✅ درخواست دسترسی (فقط در موبایل)
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

        print('📁 File saved to: $localPath');
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

  // ✅ Web download: لینک رو در تب جدید باز کن
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
      print('❌ Web download error: $e');
      onError?.call();
    }
  }

  Future<String> _getDownloadsPath() async {
    try {
      if (Platform.isAndroid) {
        // Android: مسیر Download
        final Directory downloadsDir =
            Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) {
          print('📁 Using downloads path: /storage/emulated/0/Download');
          return '/storage/emulated/0/Download';
        }
      }

      if (Platform.isIOS) {
        // iOS: Documents/Downloads
        final directory = await getApplicationDocumentsDirectory();
        final String iosPath = '${directory.path}/Downloads';
        final Directory iosDir = Directory(iosPath);
        if (!await iosDir.exists()) {
          await iosDir.create(recursive: true);
        }
        print('📁 Using iOS path: $iosPath');
        return iosPath;
      }

      // Fallback
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

  Future<bool> _requestStoragePermission() async {
    // ✅ در Web نیازی نیست
    if (kIsWeb) {
      return true;
    }

    try {
      if (Platform.isAndroid) {
        // ✅ در Android، از Permission.storage استفاده کن
        // در Android 13+، برای ذخیره در Downloads نیازی به permission نیست
        final status = await Permission.storage.request();
        return status.isGranted;
      }

      if (Platform.isIOS) {
        // iOS نیازی به permission برای Documents نداره
        return true;
      }

      return true;
    } catch (e) {
      print('❌ Permission error: $e');
      return true; // اگر خطا داد، اجازه بده ادامه بده
    }
  }

  String _sanitizeFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[^\w\-.]'), '_');
  }

  Future<bool> checkIfDownloaded(String url, String fileName) async {
    if (kIsWeb) return false;

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
