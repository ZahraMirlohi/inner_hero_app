// lib/features/arena/screens/congratulation_screen.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/providers/theme_provider.dart';
import '/core/app_palette.dart';
import '/l10n/app_strings.dart';

class _Confetto {
  final double left;
  final double top;
  final double size;
  final double radius;
  final Tone tone;
  final double rotate;
  const _Confetto(this.left, this.top, this.size, this.radius, this.tone,
      this.rotate);
}

const List<_Confetto> _confetti = [
    _Confetto(130, 175, 8, 3, Tone.mint, 61),
    _Confetto(89, 66, 8, 3, Tone.lime, 70),
    _Confetto(158, 50, 8, 3, Tone.butter, 35),
    _Confetto(98, 74, 10, 5, Tone.lilac, 33),
    _Confetto(149, 119, 8, 3, Tone.peach, 80),
    _Confetto(200, 64, 14, 3, Tone.peach, 64),
    _Confetto(137, 111, 8, 3, Tone.sky, 11),
    _Confetto(290, 173, 8, 3, Tone.peach, 65),
    _Confetto(109, 231, 10, 3, Tone.butter, 55),
    _Confetto(241, 102, 8, 3, Tone.peach, 5),
    _Confetto(51, 43, 10, 3, Tone.mint, 66),
    _Confetto(283, 261, 14, 7, Tone.peach, 25),
    _Confetto(44, 231, 8, 3, Tone.mint, 35),
    _Confetto(104, 202, 10, 3, Tone.mint, 71),
    _Confetto(111, 185, 8, 4, Tone.lime, 35),
    _Confetto(308, 141, 8, 4, Tone.peach, 37),
    _Confetto(245, 33, 8, 4, Tone.peach, 36),
    _Confetto(355, 187, 8, 3, Tone.peach, 41),
    _Confetto(88, 230, 14, 7, Tone.mint, 37),
    _Confetto(326, 118, 10, 5, Tone.peach, 32),
    _Confetto(205, 326, 8, 4, Tone.peach, 46),
    _Confetto(32, 252, 8, 3, Tone.peach, 37),
    _Confetto(302, 69, 10, 3, Tone.lilac, 26),
    _Confetto(68, 50, 8, 4, Tone.lime, 76),
    _Confetto(356, 96, 14, 3, Tone.lime, 74),
    _Confetto(137, 184, 8, 3, Tone.lime, 52),
];

class CongratulationScreen extends StatefulWidget {
  final int todayXP;
  final int totalTasksCompleted;
  final int totalHabitsCompleted;
  final String? avatarImageUrl;

  const CongratulationScreen({
    super.key,
    required this.todayXP,
    required this.totalTasksCompleted,
    required this.totalHabitsCompleted,
    this.avatarImageUrl,
  });

  @override
  State<CongratulationScreen> createState() => _CongratulationScreenState();
}

class _CongratulationScreenState extends State<CongratulationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  int _quoteIndex = 0;

  static const int _quoteCount = 3;

  @override
  void initState() {
    super.initState();
    _selectDailyQuote();
    _initAnimations();
  }

  void _selectDailyQuote() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    _quoteIndex = dayOfYear % _quoteCount;
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final Color accent = theme.effectivePrimary;
    final mint = theme.tone(Tone.mint);
    final sky = theme.tone(Tone.sky);
    final apricot = theme.tone(Tone.apricot);
    final lilac = theme.tone(Tone.lilac);
    final Color onTone =
        theme.isDarkMode ? theme.textColor : const Color(0xFF090909);

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: theme.backgroundColor,
        body: Stack(
          children: [
            _buildConfetti(theme),
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          ScaleTransition(
                            scale: _scaleAnimation,
                            child: _buildAvatar(accent),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            context.tr('ad.cg.title'),
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: theme.textColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.tr('ad.cg.subtitle'),
                            style: TextStyle(
                              fontSize: 16,
                              color: theme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: theme.softShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              context.tr('ad.cg.achievements'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: theme.textColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildStatItem(
                                  icon: Icons.fitness_center_rounded,
                                  value: widget.totalHabitsCompleted,
                                  label: context.tr('ad.cg.habits'),
                                  tone: mint,
                                  fg: onTone,
                                ),
                                const SizedBox(width: 10),
                                _buildStatItem(
                                  icon: Icons.assignment_outlined,
                                  value: widget.totalTasksCompleted,
                                  label: context.tr('ad.cg.tasks'),
                                  tone: sky,
                                  fg: onTone,
                                ),
                                const SizedBox(width: 10),
                                _buildStatItem(
                                  icon: Icons.star_outline_rounded,
                                  value: widget.todayXP,
                                  label: context.tr('ad.cg.xp'),
                                  tone: apricot,
                                  fg: onTone,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: lilac.bg,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(
                          children: [
                            Text(
                              context.tr('ad.cg.dailyMessage'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: onTone,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.tr('ad.quote.$_quoteIndex'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                height: 2,
                                fontWeight: FontWeight.w600,
                                color: onTone,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '— ${context.tr('ad.quoteAuthor.$_quoteIndex')} —',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: onTone.withValues(alpha: 0.75),
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
            Positioned(
              left: 20,
              right: 20,
              bottom: 34,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          context.tr('ad.cg.continue'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: theme.onPrimaryColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.rocket_launch_rounded,
                            size: 20, color: theme.onPrimaryColor),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// کانفتی‌های پس‌زمینه؛ مختصات در طراحی برای عرض ۳۹۰ است.
  Widget _buildConfetti(ThemeProvider theme) {
    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double k = constraints.maxWidth / 390;
            return Stack(
              children: [
                for (final c in _confetti)
                  Positioned(
                    left: c.left * k,
                    top: c.top,
                    child: Transform.rotate(
                      angle: c.rotate * math.pi / 180,
                      child: Container(
                        width: c.size,
                        height: c.size,
                        decoration: BoxDecoration(
                          color: theme.tone(c.tone).bg,
                          borderRadius: BorderRadius.circular(c.radius),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAvatar(Color accent) {
    final Color ink = const Color(0xFF090909);
    final Widget trophy = Icon(Icons.emoji_events_outlined, size: 60, color: ink);
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent,
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.3),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: widget.avatarImageUrl != null
          ? ClipOval(
              child: Image.network(
                widget.avatarImageUrl!,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Center(child: trophy),
              ),
            )
          : Center(child: trophy),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required int value,
    required String label,
    required ToneColors tone,
    required Color fg,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: tone.bg,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF090909)),
            ),
            const SizedBox(height: 6),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
