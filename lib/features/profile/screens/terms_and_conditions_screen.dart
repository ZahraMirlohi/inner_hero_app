// lib/features/profile/widgets/terms_and_conditions_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/core/app_palette.dart';
import '/l10n/app_strings.dart';
import '/providers/theme_provider.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    // هر بخش: شمارهٔ کلید، تن رنگی و تعداد بندها
    final sections = <_TermsSection>[
      const _TermsSection(1, Tone.sky, 4),
      const _TermsSection(2, Tone.lilac, 4),
      const _TermsSection(3, Tone.butter, 4),
      const _TermsSection(4, Tone.mint, 4),
      const _TermsSection(5, Tone.peach, 4),
      const _TermsSection(6, Tone.rose, 3),
      const _TermsSection(7, Tone.lime, 2),
    ];

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        shape: BoxShape.circle,
                        boxShadow: theme.softShadow,
                      ),
                      child: Icon(Icons.arrow_back_rounded, textDirection: TextDirection.ltr,
                          size: 22, color: theme.textColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr('pm.terms.title'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: theme.textColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildIntro(context, theme),
              for (final s in sections) ...[
                const SizedBox(height: 12),
                _buildSection(context, theme, s),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.isDarkMode
                        ? theme.primaryColor
                        : const Color(0xFF090909),
                    foregroundColor: theme.isDarkMode
                        ? theme.onPrimaryColor
                        : theme.effectivePrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(
                    context.tr('pm.terms.ok'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntro(BuildContext context, ThemeProvider theme) {
    final dark = theme.isDarkMode ? theme.cardSecondaryColor : const Color(0xFF090909);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: dark,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('pm.terms.intro.title'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: theme.effectivePrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('pm.terms.intro.body'),
            style: TextStyle(
              fontSize: 13,
              height: 1.9,
              color: theme.isDarkMode
                  ? theme.textSecondaryColor
                  : const Color(0xFFD5DAC8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
      BuildContext context, ThemeProvider theme, _TermsSection s) {
    final tone = theme.tone(s.tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: theme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  context.tr('pm.terms.num.${s.index}'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: tone.fg,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('pm.terms.s${s.index}.title'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: theme.textColor,
                  ),
                ),
              ),
            ],
          ),
          for (int i = 1; i <= s.count; i++)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      color: theme.effectivePrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr('pm.terms.s${s.index}.b$i'),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.8,
                        color: theme.textSecondaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TermsSection {
  final int index;
  final Tone tone;
  final int count;
  const _TermsSection(this.index, this.tone, this.count);
}
