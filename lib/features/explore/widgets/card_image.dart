import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// تصویر کارت از آدرس اینترنتی (ستون image_url). اگر آدرس خالی/خراب باشد چیزی نشان نمی‌دهد.
class CardImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double height;
  final BorderRadius borderRadius;
  // true: کل تصویر دیده می‌شود (contain) روی پس‌زمینه‌ی محو‌شده‌ی خود تصویر
  final bool showWhole;

  const CardImage({
    super.key,
    required this.url,
    required this.height,
    this.width,
    this.borderRadius = BorderRadius.zero,
    this.showWhole = false,
  });

  static bool has(String? url) => url != null && url.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!has(url)) return const SizedBox.shrink();
    if (showWhole) {
      final u = url!.trim();
      return ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox(
          width: width ?? double.infinity,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Image.network(u,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const SizedBox.shrink()),
              ),
              Container(color: Colors.white.withValues(alpha: 0.12)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Image.network(u,
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) => const SizedBox.shrink()),
              ),
            ],
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        url!.trim(),
        width: width ?? double.infinity,
        height: height,
        fit: BoxFit.cover,
        loadingBuilder: (c, child, p) => p == null
            ? child
            : Container(
                width: width ?? double.infinity,
                height: height,
                color: Colors.white.withValues(alpha: 0.4)),
        errorBuilder: (c, e, s) => const SizedBox.shrink(),
      ),
    );
  }
}
