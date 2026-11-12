import 'package:flutter/material.dart';

/// نمایش عکس پروفایل به‌صورت بزرگ؛ با لمس هر جا یا دکمهٔ بستن بسته می‌شود.
void showAvatarViewer(BuildContext context, String? url) {
  if (url == null || url.trim().isEmpty) return;
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'avatar',
    barrierColor: Colors.black.withValues(alpha: 0.88),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, __) => GestureDetector(
      onTap: () => Navigator.of(ctx).pop(),
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: ClipOval(
                    child: Image.network(
                      url.trim(),
                      width: MediaQuery.of(ctx).size.width * 0.86,
                      height: MediaQuery.of(ctx).size.width * 0.86,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.person_rounded,
                          size: 120,
                          color: Colors.white54),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    transitionBuilder: (_, a, __, child) =>
        FadeTransition(opacity: a, child: child),
  );
}
