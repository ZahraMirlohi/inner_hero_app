// lib/features/profile/screens/gallery_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';

import '/services/supabase_service.dart';
import '/services/storage_service.dart';
import '/providers/theme_provider.dart';
import '../models/user_photo_model.dart';
import 'dart:io' show File;
import '/services/image_crop_service.dart';

class GalleryScreen extends StatefulWidget {
  final String userId;
  final String? userName;

  const GalleryScreen({
    super.key,
    required this.userId,
    this.userName,
  });

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final SupabaseService _supabase = SupabaseService();
  final StorageService _storage = StorageService();
  final ImagePicker _picker = ImagePicker();

  List<UserPhoto> _photos = [];
  bool _isLoading = true;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    final photos = await _supabase.getUserPhotos(widget.userId);

    if (mounted) {
      setState(() {
        _photos = photos;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1920,
      );

      if (picked == null) return;

      if (!mounted) return;

      // ✅ کراپ (در Web رد می‌شود، در Mobile اجرا می‌شود)
      final theme = Provider.of<ThemeProvider>(context, listen: false);
      final cropService = ImageCropService();
      final croppedFile = await cropService.cropGallery(
        imageFile: File(picked.path),
        context: context,
        primaryColor: theme.primaryColor,
        lockAspectRatio: false,
      );

      if (croppedFile == null) return;

      if (!mounted) return;

      // ═══════════════════════════════════════════════════════════
      // ✅ دیالوگ کپشن قبل از آپلود
      // ═══════════════════════════════════════════════════════════
      final caption = await _showCaptionDialog();

      if (caption == null) {
        // کاربر لغو کرد (null یعنی انصراف کلی)
        return;
      }
      // اگر caption == '' باشد، یعنی کاربر بدون کپشن ادامه می‌دهد

      if (!mounted) return;

      setState(() {
        _isUploading = true;
        _uploadProgress = 0.2;
      });

      // خواندن bytes
      final bytes = await croppedFile.readAsBytes();

      if (mounted) {
        setState(() => _uploadProgress = 0.5);
      }

      // آپلود
      final result = await _storage.uploadGalleryPhoto(
        userId: widget.userId,
        bytes: bytes,
        originalFileName: 'photo.jpg',
      );

      if (mounted) {
        setState(() => _uploadProgress = 0.8);
      }

      // ✅ ذخیره در دیتابیس با کپشن
      await _supabase.addUserPhoto(
        userId: widget.userId,
        photoUrl: result['photo_url'],
        storagePath: result['storage_path'],
        fileSize: result['file_size'],
        caption: caption.isEmpty ? null : caption,
      );

      if (mounted) {
        setState(() => _uploadProgress = 1.0);
        await Future.delayed(const Duration(milliseconds: 300));

        await _loadPhotos();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📸 عکس با موفقیت آپلود شد'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
// 📝 دیالوگ نوشتن کپشن قبل از آپلود
// ═══════════════════════════════════════════════════════════
  Future<String?> _showCaptionDialog() async {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final controller = TextEditingController();
    final wordCountNotifier = ValueNotifier<int>(0);

    // ✅ بررسی طول
    controller.addListener(() {
      wordCountNotifier.value = controller.text.length;
    });

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.edit_note,
                color: theme.primaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'نوشتن کپشن',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'می‌توانی یک متن کوتاه زیر عکس بنویسی',
              style: TextStyle(
                fontSize: 13,
                color: theme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 4,
              minLines: 3,
              maxLength: 200,
              style: TextStyle(
                color: theme.textColor,
                fontSize: 14,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: 'امروز یه روز خاص بود...',
                hintStyle: TextStyle(
                  color: theme.textSecondaryColor,
                  fontSize: 13,
                ),
                filled: true,
                fillColor: theme.isDarkMode
                    ? const Color(0xFF2A2A2A)
                    : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: theme.primaryColor.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 4),
            // شمارنده کلمات
            ValueListenableBuilder<int>(
              valueListenable: wordCountNotifier,
              builder: (context, count, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'اختیاری',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textSecondaryColor,
                      ),
                    ),
                    Text(
                      '$count / 200',
                      style: TextStyle(
                        fontSize: 11,
                        color: count > 180
                            ? Colors.orange
                            : theme.textSecondaryColor,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, null), // لغو
            child: Text(
              'انصراف',
              style: TextStyle(color: theme.textSecondaryColor),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // ✅ اگر خالی بود، بدون کپشن ادامه بده
              Navigator.pop(dialogContext, controller.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.check, size: 18),
            label: const Text(
              'آپلود عکس',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    wordCountNotifier.dispose();
    controller.dispose();

    return result;
  }

  void _showSourcePicker() {
    final theme = Provider.of<ThemeProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'افزودن عکس',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildSourceButton(
                        icon: Icons.camera_alt,
                        label: 'دوربین',
                        onTap: () {
                          Navigator.pop(context);
                          _pickAndUpload(ImageSource.camera);
                        },
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSourceButton(
                        icon: Icons.photo_library,
                        label: 'گالری',
                        onTap: () {
                          Navigator.pop(context);
                          _pickAndUpload(ImageSource.gallery);
                        },
                        theme: theme,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ThemeProvider theme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: theme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.primaryColor.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: theme.primaryColor, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPhotoViewer(int index) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PhotoViewerScreen(
          photos: _photos,
          initialIndex: index,
          userId: widget.userId,
          userName: widget.userName,
          onDeleted: () => _loadPhotos(),
        ),
      ),
    );
  }

  Future<void> _deletePhoto(UserPhoto photo) async {
    final theme = Provider.of<ThemeProvider>(context, listen: false);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'حذف عکس',
          style: TextStyle(color: theme.textColor),
        ),
        content: Text(
          'آیا از حذف این عکس مطمئن هستید؟',
          style: TextStyle(color: theme.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'حذف',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // حذف از Storage
      try {
        await _storage.deleteFile(
          bucket: 'user_gallery',
          storagePath: photo.storagePath,
        );
      } catch (e) {
        print('⚠️ Storage delete error (ignored): $e');
      }

      // حذف از DB
      await _supabase.deleteUserPhoto(
        photoId: photo.id,
        userId: widget.userId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ عکس حذف شد'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadPhotos();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.userName != null ? 'گالری ${widget.userName}' : 'گالری من',
          style: TextStyle(color: theme.textColor),
        ),
        backgroundColor: theme.surfaceColor,
        elevation: 0,
        foregroundColor: theme.textColor,
        actions: [
          IconButton(
            onPressed: _isUploading ? null : _showSourcePicker,
            icon: const Icon(Icons.add_a_photo),
            tooltip: 'افزودن عکس',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: theme.primaryColor),
            )
          : Column(
              children: [
                if (_isUploading) _buildUploadProgress(theme),
                Expanded(
                  child: _photos.isEmpty
                      ? _buildEmptyState(theme)
                      : _buildPhotoGrid(theme),
                ),
              ],
            ),
      floatingActionButton: _photos.isNotEmpty && !_isUploading
          ? FloatingActionButton.extended(
              onPressed: _showSourcePicker,
              backgroundColor: theme.primaryColor,
              icon: const Icon(Icons.add_a_photo, color: Colors.white),
              label: const Text(
                'افزودن عکس',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildUploadProgress(ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: theme.surfaceColor,
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  value: _uploadProgress,
                  strokeWidth: 2,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'در حال آپلود...',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${(_uploadProgress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.photo_library_outlined,
                size: 60,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'هنوز عکسی نداری',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'لحظه‌های قهرمانی‌ات رو با دیگران به اشتراک بگذار',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.textSecondaryColor,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showSourcePicker,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.add_a_photo, color: Colors.white),
              label: const Text(
                'افزودن اولین عکس',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGrid(ThemeProvider theme) {
    return RefreshIndicator(
      onRefresh: _loadPhotos,
      color: theme.primaryColor,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // ✅ از ۳ به ۲ (برای کارت‌های بزرگ‌تر)
          crossAxisSpacing: 12, // ✅ از ۸ به ۱۲
          mainAxisSpacing: 12, // ✅ از ۸ به ۱۲
          childAspectRatio: 0.85, // ✅ نسبت ارتفاع
        ),
        itemCount: _photos.length,
        itemBuilder: (context, index) {
          final photo = _photos[index];
          return _buildPhotoCard(photo, index, theme);
        },
      ),
    );
  }

  Widget _buildPhotoCard(UserPhoto photo, int index, ThemeProvider theme) {
    return GestureDetector(
      onTap: () => _openPhotoViewer(index),
      onLongPress: () => _showPhotoOptions(photo, theme),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.isDarkMode ? 0.4 : 0.12,
              ),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ✅ تصویر
              CachedNetworkImage(
                imageUrl: photo.photoUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: theme.isDarkMode
                      ? const Color(0xFF2A2A2A)
                      : Colors.grey.shade200,
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: theme.isDarkMode
                      ? const Color(0xFF2A2A2A)
                      : Colors.grey.shade200,
                  child: Icon(
                    Icons.broken_image,
                    color: theme.textSecondaryColor,
                    size: 32,
                  ),
                ),
              ),

              // ✅ گرادیانت برای خوانایی کپشن
              if (photo.caption != null && photo.caption!.isNotEmpty)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                    child: Text(
                      photo.caption!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

              // ✅ گرادیانت بالایی (برای خوانایی badge ها)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // ✅ badge عکس اصلی (ستاره)
              if (photo.isPrimary)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          color: Colors.white,
                          size: 10,
                        ),
                        SizedBox(width: 2),
                        Text(
                          'اصلی',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ✅ badge لایک
              if (photo.likesCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 11,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${photo.likesCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhotoOptions(UserPhoto photo, ThemeProvider theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.edit, color: theme.primaryColor),
                title: Text(
                  'ویرایش کپشن',
                  style: TextStyle(color: theme.textColor),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showEditCaptionDialog(photo, theme);
                },
              ),
              ListTile(
                leading: Icon(
                  photo.isPrimary ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
                title: Text(
                  photo.isPrimary ? 'حذف از حالت اصلی' : 'تنظیم به عنوان اصلی',
                  style: TextStyle(color: theme.textColor),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _togglePrimary(photo);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'حذف عکس',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deletePhoto(photo);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditCaptionDialog(
      UserPhoto photo, ThemeProvider theme) async {
    final controller = TextEditingController(text: photo.caption ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'ویرایش کپشن',
          style: TextStyle(color: theme.textColor),
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 200,
          style: TextStyle(color: theme.textColor),
          decoration: InputDecoration(
            hintText: 'یک توضیح کوتاه بنویس...',
            hintStyle: TextStyle(color: theme.textSecondaryColor),
            filled: true,
            fillColor: theme.isDarkMode
                ? const Color(0xFF2A2A2A)
                : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
            ),
            child: const Text(
              'ذخیره',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await _supabase.updatePhotoCaption(
          photoId: photo.id,
          userId: widget.userId,
          caption: result,
        );
        await _loadPhotos();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطا: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _togglePrimary(UserPhoto photo) async {
    try {
      // اگر قبلاً primary بود، حذفش کن
      if (photo.isPrimary) {
        await _supabase.client
            .from('user_photos')
            .update({'is_primary': false}).eq('id', photo.id);
      } else {
        // همه primary ها را غیرفعال کن
        await _supabase.client
            .from('user_photos')
            .update({'is_primary': false}).eq('user_id', widget.userId);

        // این یکی را primary کن
        await _supabase.client
            .from('user_photos')
            .update({'is_primary': true}).eq('id', photo.id);

        // آواتار پروفایل را هم آپدیت کن
        await _supabase.updateAvatarUrl(widget.userId, photo.photoUrl);
      }

      await _loadPhotos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════
// 📷 Photo Viewer (نمایش تمام‌صفحه)
// ═══════════════════════════════════════════════════════════

class _PhotoViewerScreen extends StatefulWidget {
  final List<UserPhoto> photos;
  final int initialIndex;
  final String userId;
  final String? userName;
  final VoidCallback? onDeleted;

  const _PhotoViewerScreen({
    required this.photos,
    required this.initialIndex,
    required this.userId,
    this.userName,
    this.onDeleted,
  });

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final currentPhoto = widget.photos[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.photos.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: () {
              // حذف از اینجا
              Navigator.pop(context);
              // TODO: call delete
            },
            icon: const Icon(Icons.delete_outline, color: Colors.white),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true, // ✅ رعایت فضای امن پایین
        child: Stack(
          children: [
            // ✅ PhotoViewGallery
            PhotoViewGallery.builder(
              pageController: _pageController,
              itemCount: widget.photos.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              builder: (context, index) {
                final photo = widget.photos[index];
                return PhotoViewGalleryPageOptions(
                  imageProvider: CachedNetworkImageProvider(photo.photoUrl),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2,
                );
              },
              loadingBuilder: (context, event) => Center(
                child: CircularProgressIndicator(
                  color: theme.primaryColor,
                ),
              ),
            ),

            // ✅ کپشن با احترام به SafeArea
            if (currentPhoto.caption != null &&
                currentPhoto.caption!.isNotEmpty)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: false,
                  bottom: true,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                    child: Text(
                      currentPhoto.caption!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
