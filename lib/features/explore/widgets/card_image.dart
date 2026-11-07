import 'package:flutter/material.dart';

/// تصویر کارت از آدرس اینترنتی (ستون image_url). اگر آدرس خالی/خراب باشد چیزی نشان نمی‌دهد.
class CardImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const CardImage({
    super.key,
    required this.url,
    required this.height,
    this.width,
    this.borderRadius = BorderRadius.zero,
  });

  static bool has(String? url) => url != null && url.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!has(url)) return const SizedBox.shrink();
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
