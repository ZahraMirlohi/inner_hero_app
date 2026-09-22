// lib/widgets/custom_progress_indicator.dart

import 'package:flutter/material.dart';
import 'dart:math';

class CustomProgressIndicator extends StatefulWidget {
  final double progress; // 0.0 تا 1.0
  final double size;

  const CustomProgressIndicator({
    super.key,
    required this.progress,
    this.size = 200,
  });

  @override
  State<CustomProgressIndicator> createState() =>
      _CustomProgressIndicatorState();
}

class _CustomProgressIndicatorState extends State<CustomProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  double _currentProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _currentProgress =
        widget.progress.isNaN ? 0.0 : widget.progress.clamp(0.0, 1.0);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: _currentProgress,
      end: _currentProgress,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
  }

  @override
  void didUpdateWidget(CustomProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      final newProgress =
          widget.progress.isNaN ? 0.0 : widget.progress.clamp(0.0, 1.0);
      _progressAnimation = Tween<double>(
        begin: _currentProgress,
        end: newProgress,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOutCubic,
        ),
      );
      _currentProgress = newProgress;
      _animationController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        final double progress = _progressAnimation.value;

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _ProgressPainter(
              progress: progress,
            ),
          ),
        );
      },
    );
  }
}

// ==================== Custom Painter (فقط دایره پیشرفت) ====================

class _ProgressPainter extends CustomPainter {
  final double progress;

  _ProgressPainter({
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double safeProgress = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);

    final center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2;

    // ✅ ضخامت‌ها
    final double trackStrokeWidth = radius * 0.18;
    final double progressStrokeWidth = radius * 0.10;
    final double innerRadius = radius - (trackStrokeWidth / 2);

    // ============================================================
    // 1. پس‌زمینه دایره (Track) - مشکی
    // ============================================================
    final trackPaint = Paint()
      ..color = const Color(0xFF090909)
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackStrokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, innerRadius, trackPaint);

    // ============================================================
    // 2. نوار پیشرفت سبز (ضخامت کمتر)
    // ============================================================
    if (safeProgress > 0.001) {
      final progressPaint = Paint()
        ..color = const Color(0xFFB0CC5D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = progressStrokeWidth
        ..strokeCap = StrokeCap.round;

      final sweepAngle = safeProgress * 2 * pi;
      const startAngle = -pi / 2;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }

    // ============================================================
    // 3. نقطه مرکزی (برای Rive)
    // ============================================================
    // ✅ یک نقطه کوچک سبز برای نشان دادن مرکز (اختیاری)
    final centerDotPaint = Paint()
      ..color = const Color(0xFFB0CC5D).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, trackStrokeWidth * 0.15, centerDotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
