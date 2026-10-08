// lib/features/arena/widgets/animated_check_overlay.dart

import 'package:flutter/material.dart';

/// ✅ ویجت انیمیشن تیک که روی دایره آیکون ظاهر می‌شود
/// هنگام کلیک، یک تیک با انیمیشن scale + fade ظاهر و محو می‌شود
class AnimatedCheckOverlay extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color checkColor;

  const AnimatedCheckOverlay({
    super.key,
    required this.child,
    this.onTap,
    this.checkColor = Colors.white,
  });

  @override
  State<AnimatedCheckOverlay> createState() => _AnimatedCheckOverlayState();
}

class _AnimatedCheckOverlayState extends State<AnimatedCheckOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween:
            Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween:
            Tween(begin: 1.0, end: 1.0).chain(CurveTween(curve: Curves.linear)),
        weight: 40,
      ),
    ]).animate(_controller);

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _playAnimation() {
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _playAnimation();
        widget.onTap?.call();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,
          // ✅ تیک انیمیشنی
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                if (_controller.isDismissed) {
                  return const SizedBox.shrink();
                }
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.checkColor.withValues(alpha: 0.85),
                        boxShadow: [
                          BoxShadow(
                            color: widget.checkColor.withValues(alpha: 0.5),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.check,
                        // ✅ رنگ تیک به صورت هوشمند انتخاب می‌شه:
                        // - اگه checkColor سفید باشه، تیک سبز (روی دکمه تیره)
                        // - اگه checkColor مشکی/رنگی باشه، تیک سفید (روی دکمه روشن)
                        color: widget.checkColor == Colors.white
                            ? Colors.green
                            : Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
