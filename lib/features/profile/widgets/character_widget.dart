// lib/features/profile/widgets/character_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';
import '../models/character_model.dart';
import '../models/hero_class_model.dart';

class CharacterWidget extends StatefulWidget {
  final Character character;
  final double size;

  const CharacterWidget({super.key, required this.character, this.size = 200});

  @override
  State<CharacterWidget> createState() => _CharacterWidgetState();
}

class _CharacterWidgetState extends State<CharacterWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _floatAnimation;
  String _currentAnimation = 'idle';
  final List<String> _animationSequence = ['idle', 'idle', 'idle', 'dance'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0, end: 20).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _floatAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // شروع انیمیشن با کمی تاخیر
    Future.delayed(const Duration(milliseconds: 500), () {
      _startRandomAnimation();
    });
  }

  void _startRandomAnimation() {
    if (!mounted) return;

    // انتخاب رندوم بین انیمیشن‌های موجود
    final heroClass = HeroClass.getClass(widget.character.heroClass);
    final animations = heroClass.animations;
    final randomIndex = DateTime.now().millisecond % animations.length;
    final newAnimation = animations[randomIndex];

    setState(() {
      _currentAnimation = newAnimation;
    });

    // بعد از 3-5 ثانیه انیمیشن عوض کن
    final delay = Duration(seconds: 3 + (DateTime.now().second % 3));
    Future.delayed(delay, () {
      if (mounted) _startRandomAnimation();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heroClass = HeroClass.getClass(widget.character.heroClass);
    final color = _parseColor(heroClass.primaryColor);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // سایه
                Positioned(
                  bottom: 10,
                  child: Container(
                    width: widget.size * 0.6,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                ),
                // بدنه کاراکتر
                Transform.scale(
                  scale: 1 + (_bounceAnimation.value / 200),
                  child: _buildCharacter(heroClass, color),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCharacter(HeroClass heroClass, Color color) {
    final isIdle = _currentAnimation == 'idle';

    return Container(
      width: widget.size * 0.8,
      height: widget.size * 0.9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.3), Colors.white],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // سر
          Container(
            width: widget.size * 0.4,
            height: widget.size * 0.4,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.2), blurRadius: 10),
              ],
            ),
            child: Center(
              child: Text(
                heroClass.icon,
                style: TextStyle(fontSize: widget.size * 0.25),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // لباس
          Container(
            width: widget.size * 0.6,
            height: widget.size * 0.2,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.3), blurRadius: 10),
              ],
            ),
            child: Center(
              child: Text(
                _currentAnimation == 'dance'
                    ? '💃'
                    : _currentAnimation == 'victory'
                    ? '🏆'
                    : _currentAnimation == 'attack'
                    ? '⚔️'
                    : _currentAnimation == 'heal'
                    ? '💚'
                    : _currentAnimation == 'run'
                    ? '🏃'
                    : '💪',
                style: TextStyle(fontSize: widget.size * 0.15),
              ),
            ),
          ),
          // تکه‌کلام
          if (widget.character.catchphrase.isNotEmpty && isIdle)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                widget.character.catchphrase,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _parseColor(String colorStr) {
    try {
      if (colorStr.startsWith('#')) {
        return Color(int.parse('FF${colorStr.substring(1)}', radix: 16));
      }
      return const Color(0xFF4A90E2);
    } catch (e) {
      return const Color(0xFF4A90E2);
    }
  }
}
