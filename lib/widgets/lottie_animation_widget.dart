// lib/widgets/lottie_animation_widget.dart

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LottieAnimationWidget extends StatefulWidget {
  final String animationPath;
  final bool isPlaying;
  final double size;

  const LottieAnimationWidget({
    super.key,
    required this.animationPath,
    this.isPlaying = false,
    this.size = 80,
  });

  @override
  State<LottieAnimationWidget> createState() => _LottieAnimationWidgetState();
}

class _LottieAnimationWidgetState extends State<LottieAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3), // ✅ از ۲ به ۳ ثانیه افزایش
      vsync: this,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.value = 0.0;
        _controller.stop();
      }
    });
  }

  @override
  void didUpdateWidget(LottieAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      if (widget.isPlaying) {
        // ✅ از اول پلی کن
        _controller.forward(from: 0.0);
      } else {
        // ✅ متوقف کن و به فریم اول برگرد
        _controller.value = 0.0;
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Lottie.asset(
        widget.animationPath,
        controller: _controller,
        fit: BoxFit.contain,
      ),
    );
  }
}
