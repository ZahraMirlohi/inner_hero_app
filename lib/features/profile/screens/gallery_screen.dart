// lib/features/profile/screens/gallery_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';

import '/core/app_palette.dart';
import '/l10n/app_strings.dart';
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

  // ارتفاع کاشی‌ها در دو ستون (مطابق طرح)
  static const List<double> _colAHeights = [200, 140, 170];
  static const List<double> _colBHeights = [150, 200, 130];
  static const List<Tone> _tileTones = [
    Tone.lilac,
    Tone.sky,
    Tone.peach,
    Tone.butter,
    Tone.mint,
    Tone.lime,
  ];

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  // ==================== ابزارهای ظاهری ====================

  Color _ink(ThemeProvider t) =>
      t.isDarkMode ? t.cardSecondaryColor : const Color(0xFF090909);

  Color _onAccent(Color accent) =>
      accent.computeLuminance() > 0.5 ? const Color(0xFF090909) : Colors.white;

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? theme.errorColor : theme.successColor,
      ),
    );
  }

  Widget _backButton(ThemeProvider t) {
    return GestureDetector(
      onTap: () => Navigator.maybePop(context),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: t.cardColor,
          shape: BoxShape.circle,
          boxShadow: t.softShadow,
        ),
        child: Icon(Icons.arrow_forward_rounded, size: 22, color: t.textColor),
      ),
    );
  }

  Widget _handle(ThemeProvider t) => Center(
        child: Container(
          width: 44,
          height: 5,
          decoration: BoxDecoration(
            color: t.cardSecondaryColor,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      );

  Widget _pillButton(
    ThemeProvider t, {
    required String label,
    required VoidCallback? onTap,
    bool primary = true,
    double height = 54,
    Color? labelColor,
  }) {
    final accent = t.effectivePrimary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary ? _ink(t) : t.cardSecondaryColor,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: primary ? FontWeight.w800 : FontWeight.w600,
            color: labelColor ?? (primary ? accent : t.textColor),
          ),
        ),
      ),
    );
  }

  // ==================== بارگذاری ====================

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

  Future<void> _pickAndUpload(ImageSource source, {String? presetCaption}) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1920,
      );

      if (picked == null) return;

      if (!mounted) return;

      // کراپ (در Web رد می‌شود، در Mobile اجرا می‌شود)
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

      // کپشن: اگر از برگه‌ی افزودن عکس آمده باشد همان است، وگرنه دیالوگ کپشن
      final caption = presetCaption ?? await _showCaptionDialog();

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

      // ذخیره در دیتابیس با کپشن
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
          _snack(context.tr('pm.gl.uploaded'));
        }
      }
    } catch (e) {
      if (mounted) {
        _snack(context.tr('pm.gl.error', {'n': e.toString()}), error: true);
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
  // دیالوگ نوشتن کپشن (فقط وقتی کپشن از قبل داده نشده باشد)
  // ═══════════════════════════════════════════════════════════
  Future<String?> _showCaptionDialog() async {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('pm.gl.caption'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.textColor,
                    ),
                  ),
                  Text(
                    context.tr('pm.gl.optional'),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _captionField(theme, controller, autofocus: true),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _pillButton(
                      theme,
                      label: context.tr('pm.gl.cancel'),
                      primary: false,
                      onTap: () => Navigator.pop(dialogContext, null),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _pillButton(
                      theme,
                      label: context.tr('pm.gl.upload'),
                      onTap: () =>
                          Navigator.pop(dialogContext, controller.text.trim()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    controller.dispose();

    return result;
  }

  Widget _captionField(
    ThemeProvider theme,
    TextEditingController controller, {
    bool autofocus = false,
    String? hint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      constraints: const BoxConstraints(minHeight: 84),
      decoration: BoxDecoration(
        color: theme.cardSecondaryColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        minLines: 3,
        maxLines: 4,
        maxLength: 200,
        style: TextStyle(fontSize: 14, height: 1.5, color: theme.textColor),
        decoration: InputDecoration(
          hintText: hint ?? context.tr('pm.gl.caption_hint'),
          hintStyle: TextStyle(fontSize: 14, color: theme.textSecondaryColor),
          border: InputBorder.none,
          counterText: '',
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  // ==================== برگه‌ی افزودن عکس (AddPhoto) ====================

  void _showSourcePicker() {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final controller = TextEditingController();
    ImageSource? selected;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _handle(theme),
                      const SizedBox(height: 16),
                      Text(
                        context.tr('pm.gl.add_photo'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: theme.textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSourceButton(
                              icon: Icons.photo_camera_outlined,
                              label: context.tr('pm.gl.camera'),
                              tone: Tone.sky,
                              selected: selected == ImageSource.camera,
                              onTap: () =>
                                  setSheet(() => selected = ImageSource.camera),
                              theme: theme,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildSourceButton(
                              icon: Icons.image_outlined,
                              label: context.tr('pm.gl.phone_gallery'),
                              tone: Tone.lilac,
                              selected: selected == ImageSource.gallery,
                              onTap: () => setSheet(
                                  () => selected = ImageSource.gallery),
                              theme: theme,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.tr('pm.gl.caption'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: theme.textColor,
                            ),
                          ),
                          Text(
                            context.tr('pm.gl.optional'),
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _captionField(theme, controller),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _pillButton(
                              theme,
                              label: context.tr('pm.gl.cancel'),
                              primary: false,
                              onTap: () => Navigator.pop(sheetContext),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: Opacity(
                              opacity: selected == null ? 0.5 : 1,
                              child: _pillButton(
                                theme,
                                label: context.tr('pm.gl.upload'),
                                onTap: selected == null
                                    ? null
                                    : () {
                                        final src = selected!;
                                        final caption = controller.text.trim();
                                        Navigator.pop(sheetContext);
                                        _pickAndUpload(src,
                                            presetCaption: caption);
                                      },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }

  Widget _buildSourceButton({
    required IconData icon,
    required String label,
    required Tone tone,
    required bool selected,
    required VoidCallback onTap,
    required ThemeProvider theme,
  }) {
    final tc = theme.tone(tone);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          color: tc.bg,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: selected ? _ink(theme) : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: theme.textColor, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: theme.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPhotoViewer(int index) {
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
      builder: (dialogContext) => Dialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('pm.gl.delete_title'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.tr('pm.gl.delete_body'),
                style: TextStyle(fontSize: 14, color: theme.textSecondaryColor),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _pillButton(
                      theme,
                      label: context.tr('pm.gl.cancel'),
                      primary: false,
                      onTap: () => Navigator.pop(dialogContext, false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(dialogContext, true),
                      child: Container(
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.errorColor,
                          borderRadius: BorderRadius.circular(27),
                        ),
                        child: Text(
                          context.tr('pm.gl.delete'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
        debugPrint('Storage delete error (ignored): $e');
      }

      // حذف از DB
      await _supabase.deleteUserPhoto(
        photoId: photo.id,
        userId: widget.userId,
      );

      if (mounted) {
        _snack(context.tr('pm.gl.deleted'));
        await _loadPhotos();
      }
    } catch (e) {
      if (mounted) {
        _snack(context.tr('pm.gl.error', {'n': e.toString()}), error: true);
      }
    }
  }

  // ==================== ساخت صفحه ====================

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final accent = theme.effectivePrimary;
    final title = widget.userName != null
        ? context.tr('pm.gl.title_other', {'name': widget.userName!})
        : context.tr('pm.gl.title');

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      _backButton(theme),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: theme.textColor,
                              ),
                            ),
                            if (!_isLoading)
                              Text(
                                context.tr('pm.gl.count',
                                    {'n': _photos.length.toString()}),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.textSecondaryColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isUploading) _buildUploadProgress(theme),
                Expanded(
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator(color: accent))
                      : (_photos.isEmpty
                          ? _buildEmptyState(theme)
                          : _buildPhotoGrid(theme)),
                ),
              ],
            ),
            if (_photos.isNotEmpty && !_isUploading && !_isLoading)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  ignoring: false,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      40,
                      20,
                      24 + MediaQuery.of(context).padding.bottom,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.backgroundColor.withValues(alpha: 0),
                          theme.backgroundColor,
                        ],
                        stops: const [0, 0.65],
                      ),
                    ),
                    child: _buildAddButton(theme, accent),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(ThemeProvider theme, Color accent) {
    return GestureDetector(
      onTap: _showSourcePicker,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: _ink(theme),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 22, color: accent),
            const SizedBox(width: 8),
            Text(
              context.tr('pm.gl.add_photo'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadProgress(ThemeProvider theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: theme.softShadow,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              value: _uploadProgress,
              strokeWidth: 2.4,
              color: theme.effectivePrimary,
              backgroundColor: theme.cardSecondaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            context.tr('pm.gl.uploading'),
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
              color: theme.textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider theme) {
    final tc = theme.tone(Tone.lilac);
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
                color: tc.bg,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                Icons.image_outlined,
                size: 52,
                color: theme.textColor.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.tr('pm.gl.empty_title'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.tr('pm.gl.empty_sub'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.textSecondaryColor,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            if (!_isUploading)
              GestureDetector(
                onTap: _showSourcePicker,
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: _ink(theme),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded,
                          size: 22, color: theme.effectivePrimary),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('pm.gl.add_first'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: theme.effectivePrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // شبکه‌ی دو ستونه (masonry) مطابق طرح
  Widget _buildPhotoGrid(ThemeProvider theme) {
    final colA = <Widget>[];
    final colB = <Widget>[];
    for (int i = 0; i < _photos.length; i++) {
      final inA = i % 2 == 0;
      final pos = i ~/ 2;
      final heights = inA ? _colAHeights : _colBHeights;
      final h = heights[pos % heights.length];
      final tile = Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _buildPhotoCard(_photos[i], i, h, theme),
      );
      (inA ? colA : colB).add(tile);
    }

    return RefreshIndicator(
      onRefresh: _loadPhotos,
      color: theme.effectivePrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(children: colA)),
            const SizedBox(width: 10),
            Expanded(child: Column(children: colB)),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoCard(
      UserPhoto photo, int index, double height, ThemeProvider theme) {
    final tc = theme.tone(_tileTones[index % _tileTones.length]);
    final accent = theme.effectivePrimary;
    final placeholder = Container(
      color: tc.bg,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 34,
          color: theme.textColor.withValues(alpha: 0.35),
        ),
      ),
    );
    final hasCaption = photo.caption != null && photo.caption!.isNotEmpty;

    return GestureDetector(
      onTap: () => _openPhotoViewer(index),
      onLongPress: () => _showPhotoOptions(photo, theme),
      child: SizedBox(
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: photo.photoUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => placeholder,
                errorWidget: (context, url, error) => placeholder,
              ),

              // نشان عکس اصلی
              if (photo.isPrimary)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      context.tr('pm.gl.primary'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _onAccent(accent),
                      ),
                    ),
                  ),
                ),

              // نشان لایک
              if (photo.likesCount > 0)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.favorite_rounded,
                            color: Colors.white, size: 12),
                        const SizedBox(width: 3),
                        Text(
                          '${photo.likesCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // کپشن
              if (hasCaption)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: AlignmentDirectional.centerStart,
                    decoration: BoxDecoration(
                      color: theme.cardColor.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      photo.caption!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.textColor,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionRow(
    ThemeProvider theme, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? theme.textColor;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 56,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: theme.cardSecondaryColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(icon, color: c, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPhotoOptions(UserPhoto photo, ThemeProvider theme) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.cardColor,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _handle(theme),
                const SizedBox(height: 18),
                _optionRow(
                  theme,
                  icon: Icons.edit_outlined,
                  label: context.tr('pm.gl.edit_caption'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showEditCaptionDialog(photo, theme);
                  },
                ),
                _optionRow(
                  theme,
                  icon: photo.isPrimary
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  label: photo.isPrimary
                      ? context.tr('pm.gl.unset_primary')
                      : context.tr('pm.gl.set_primary'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _togglePrimary(photo);
                  },
                ),
                _optionRow(
                  theme,
                  icon: Icons.delete_outline_rounded,
                  label: context.tr('pm.gl.delete_photo'),
                  color: theme.errorColor,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _deletePhoto(photo);
                  },
                ),
              ],
            ),
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
      builder: (dialogContext) => Dialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('pm.gl.edit_caption'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 12),
              _captionField(theme, controller,
                  hint: context.tr('pm.gl.edit_hint')),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _pillButton(
                      theme,
                      label: context.tr('pm.gl.cancel'),
                      primary: false,
                      onTap: () => Navigator.pop(dialogContext),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _pillButton(
                      theme,
                      label: context.tr('pm.gl.save'),
                      onTap: () =>
                          Navigator.pop(dialogContext, controller.text.trim()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    controller.dispose();

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
          _snack(context.tr('pm.gl.error', {'n': e.toString()}), error: true);
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
        _snack(context.tr('pm.gl.error', {'n': e.toString()}), error: true);
      }
    }
  }
}


// ═══════════════════════════════════════════════════════════
// Photo Viewer (نمایش تمام‌صفحه)
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
        bottom: true, // رعایت فضای امن پایین
        child: Stack(
          children: [
            // PhotoViewGallery
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
                  color: theme.effectivePrimary,
                ),
              ),
            ),

            // کپشن با احترام به SafeArea
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
