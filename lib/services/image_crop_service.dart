// lib/services/image_crop_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

class ImageCropService {
  /// کراپ عکس برای آواتار (مربع/دایره)
  Future<File?> cropAvatar({
    required File imageFile,
    required BuildContext context,
    Color? primaryColor,
  }) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
        maxWidth: 1080,
        maxHeight: 1080,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'کراپ عکس پروفایل',
            toolbarColor: primaryColor ?? Colors.blue,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'کراپ عکس پروفایل',
            aspectRatioLockEnabled: true,
          ),
          if (kIsWeb)
            WebUiSettings(
              context: context,
              presentStyle: WebPresentStyle.dialog,
              size: const CropperSize(width: 500, height: 500),
            ),
        ],
      );

      if (croppedFile == null) return null;

      // ✅ در Web، باید bytes را بخوانیم و به File تبدیل کنیم
      // اما image_cropper در Web یک فایل موقت می‌سازد که path دارد
      return File(croppedFile.path);
    } catch (e) {
      debugPrint('❌ Error cropping: $e');
      return null;
    }
  }

  /// کراپ عکس برای گالری (می‌تواند غیر مربع باشد)
  Future<File?> cropGallery({
    required File imageFile,
    required BuildContext context,
    Color? primaryColor,
    bool lockAspectRatio = false,
    double aspectRatioX = 1,
    double aspectRatioY = 1,
  }) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: lockAspectRatio
            ? CropAspectRatio(ratioX: aspectRatioX, ratioY: aspectRatioY)
            : null,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
        maxWidth: 1920,
        maxHeight: 1920,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'کراپ عکس',
            toolbarColor: primaryColor ?? Colors.blue,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: lockAspectRatio,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'کراپ عکس',
            aspectRatioLockEnabled: lockAspectRatio,
            resetAspectRatioEnabled: !lockAspectRatio,
          ),
          if (kIsWeb)
            WebUiSettings(
              context: context,
              presentStyle: WebPresentStyle.dialog,
              size: const CropperSize(width: 500, height: 500),
            ),
        ],
      );

      if (croppedFile == null) return null;
      return File(croppedFile.path);
    } catch (e) {
      debugPrint('❌ Error cropping: $e');
      return null;
    }
  }
}
