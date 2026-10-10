// lib/services/storage_service.dart

import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final SupabaseClient _client = Supabase.instance.client;

  // ═══════════════════════════════════════════════════════════
  // 📤 آپلود عکس پروفایل
  // ═══════════════════════════════════════════════════════════
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    String? originalFileName,
  }) async {
    try {
      // ۱. فشرده‌سازی
      final compressed = await _compressImage(bytes, maxSizeKB: 500);

      // ۲. مسیر در Storage
      final extension = _getExtension(originalFileName);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$extension';
      final storagePath = '$userId/$fileName';

      // ۳. آپلود
      await _client.storage.from('avatars').uploadBinary(
            storagePath,
            compressed,
            fileOptions: FileOptions(
              contentType: _getContentType(extension),
              upsert: true,
            ),
          );

      final publicUrl =
          _client.storage.from('avatars').getPublicUrl(storagePath);

      print('✅ Avatar uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Error uploading avatar: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📤 آپلود عکس گالری
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> uploadGalleryPhoto({
    required String userId,
    required Uint8List bytes,
    String? originalFileName,
  }) async {
    try {
      final compressed = await _compressImage(bytes, maxSizeKB: 1024);

      final extension = _getExtension(originalFileName);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$extension';
      final storagePath = '$userId/$fileName';

      await _client.storage.from('user_gallery').uploadBinary(
            storagePath,
            compressed,
            fileOptions: FileOptions(
              contentType: _getContentType(extension),
              upsert: false,
            ),
          );

      final publicUrl =
          _client.storage.from('user_gallery').getPublicUrl(storagePath);

      print('✅ Gallery photo uploaded: $publicUrl');

      return {
        'storage_path': storagePath,
        'photo_url': publicUrl,
        'file_size': compressed.length,
      };
    } catch (e) {
      print('❌ Error uploading gallery photo: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🗑️ حذف فایل
  // ═══════════════════════════════════════════════════════════
  Future<void> deleteFile({
    required String bucket,
    required String storagePath,
  }) async {
    try {
      await _client.storage.from(bucket).remove([storagePath]);
      print('✅ File deleted: $bucket/$storagePath');
    } catch (e) {
      print('❌ Error deleting file: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🖼️ فشرده‌سازی عکس (پشتیبانی از Web و Mobile)
  // ═══════════════════════════════════════════════════════════
  Future<Uint8List> _compressImage(
    Uint8List originalBytes, {
    int maxSizeKB = 500,
  }) async {
    try {
      // در Web، اگر پکیج image کار نکرد، مستقیم برگردان
      if (kIsWeb) {
        try {
          final decoded = img.decodeImage(originalBytes);
          if (decoded == null) {
            // نمی‌توان decode کرد → مستقیم برگردان
            return originalBytes;
          }
          return _encodeWithResize(decoded, originalBytes.length, maxSizeKB);
        } catch (e) {
          print('⚠️ Web compression failed, returning original: $e');
          return originalBytes;
        }
      }

      // Mobile / Desktop
      final decoded = img.decodeImage(originalBytes);
      if (decoded == null) {
        throw Exception('Failed to decode image');
      }

      return _encodeWithResize(decoded, originalBytes.length, maxSizeKB);
    } catch (e) {
      print('❌ Error compressing image: $e');
      rethrow;
    }
  }

  Uint8List _encodeWithResize(
    img.Image decoded,
    int originalSize,
    int maxSizeKB,
  ) {
    int quality = 85;
    Uint8List result = Uint8List.fromList(
      img.encodeJpg(decoded, quality: quality),
    );

    int attempts = 0;
    while (result.length > maxSizeKB * 1024 && attempts < 5) {
      quality -= 15;
      if (quality < 30) quality = 30;
      result = Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
      attempts++;
    }

    if (result.length > maxSizeKB * 1024) {
      final resized = img.copyResize(
        decoded,
        width: decoded.width > 1920 ? 1920 : decoded.width,
      );
      result = Uint8List.fromList(img.encodeJpg(resized, quality: 75));
    }

    print(
        '📊 Compressed: ${originalSize ~/ 1024} KB → ${result.length ~/ 1024} KB');
    return result;
  }

  String _getExtension(String? fileName) {
    if (fileName == null) return '.jpg';
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1) return '.jpg';
    return fileName.substring(dotIndex).toLowerCase();
  }

  String _getContentType(String extension) {
    switch (extension) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      case '.jpg':
      case '.jpeg':
      default:
        return 'image/jpeg';
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🧹 حذف همه‌ی عکس‌های یک کاربر
  // ═══════════════════════════════════════════════════════════
  Future<void> deleteAllUserFiles({
    required String userId,
    required String bucket,
  }) async {
    try {
      final files = await _client.storage.from(bucket).list(path: userId);

      if (files.isEmpty) return;

      final paths = files.map((f) => '$userId/${f.name}').toList();
      await _client.storage.from(bucket).remove(paths);

      print('✅ Deleted ${paths.length} files from $bucket');
    } catch (e) {
      print('❌ Error deleting user files: $e');
    }
  }
}
