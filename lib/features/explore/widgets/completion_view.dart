import '/l10n/app_strings.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/providers/theme_provider.dart';
import '/core/app_palette.dart';

/// صفحه تبریک مشترک (چالش و ماموریت) طبق طراحی.
class CompletionView extends StatefulWidget {
  final IconData icon;
  final String subtitle;
  final String name;
  final String progressText;
  final String badgeText;
  final int xp;

  const CompletionView({
    super.key,
    this.icon = Icons.emoji_events_rounded,
    required this.subtitle,
    required this.name,
    required this.progressText,
    required this.badgeText,
    required this.xp,
  });

  @override
  State<CompletionView> createState() => _CompletionViewState();
}

class _CompletionViewState extends State<CompletionView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      duration: const Duration(milliseconds: 800), vsync: this)
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final accent = theme.effectivePrimary;
    const ink = Color(0xFF090909);
    final rnd = math.Random(7);
    final tones = [Tone.peach, Tone.lilac, Tone.butter, Tone.mint, Tone.sky];
    final size = MediaQuery.of(context).size;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, true);
        return false;
      },
      child: Scaffold(
        backgroundColor: theme.backgroundColor,
        body: Stack(
          children: [
            // کنفتی
            for (var i = 0; i < 30; i++)
              Positioned(
                left: rnd.nextDouble() * (size.width - 16),
                top: 20 + rnd.nextDouble() * 340,
                child: Transform.rotate(
                  angle: rnd.nextDouble() * 1.4,
                  child: Container(
                    width: 8 + rnd.nextInt(7).toDouble(),
                    height: 8 + rnd.nextInt(7).toDouble(),
                    decoration: BoxDecoration(
                      color: i % 4 == 0
                          ? accent
                          : theme.tone(tones[i % tones.length]).bg,
                      borderRadius: BorderRadius.circular(i % 2 == 0 ? 8 : 3),
                    ),
                  ),
                ),
              ),
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 70, 20, 20),
                      child: Column(
                        children: [
                          ScaleTransition(
                            scale: CurvedAnimation(
                                parent: _c, curve: Curves.elasticOut),
                            child: Container(
                              width: 132,
                              height: 132,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.35),
                                    blurRadius: 36,
                                    offset: const Offset(0, 16),
                                  ),
                                ],
                              ),
                              child: Icon(widget.icon, size: 64, color: ink),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(context.tr('ex.cv.congrats'),
                              style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: theme.textColor)),
                          const SizedBox(height: 10),
                          Text(widget.subtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 16,
                                  color: theme.textSecondaryColor)),
                          const SizedBox(height: 30),
                          Text(widget.name,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: theme.textColor)),
                          const SizedBox(height: 10),
                          _pill(widget.progressText, theme.primarySoft, 14),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              _pill('+${widget.xp} XP',
                                  theme.tone(Tone.peach).bg, 15),
                              _pill(widget.badgeText,
                                  theme.tone(Tone.butter).bg, 15),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, true),
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
                        child: Text(context.tr('ex.cv.continue'),
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: theme.onPrimaryColor)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String t, Color bg, double size) => Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
        child: Text(t,
            style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF090909))),
      );
}
