// lib/features/profile/widgets/streak_card_widget.dart
//
// کارت استریک با گرافیک جدید: هفت نقطهٔ روز روی یک کمان، دور یک دایرهٔ مشکی بزرگ که تعداد روز را نشان می‌دهد.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '/core/app_palette.dart';
import '/l10n/app_strings.dart';
import '/providers/calendar_provider.dart';
import '/providers/theme_provider.dart';

class StreakCardWidget extends StatelessWidget {
  final int currentStreak;
  final int bestStreak;
  final int weeklyStreak;

  /// وضعیت روزهای هفته به ترتیب شنبه … جمعه (همان داده‌ی قبلی)
  final List<bool> weekDays;

  const StreakCardWidget({
    super.key,
    required this.currentStreak,
    required this.bestStreak,
    required this.weeklyStreak,
    required this.weekDays,
  });

  static const double _w = 310;
  static const double _h = 236;
  static const double _r = 129;
  static const double _dot = 34;
  static const Color _ink = Color(0xFF090909);

  @override
  Widget build(BuildContext context) {
    final calendar = context.watch<CalendarProvider>();
    final theme = context.watch<ThemeProvider>();
    final accent = theme.primaryColor;
    final onAccent = theme.onPrimaryColor;
    final lime = theme.tone(Tone.lime);

    final labels = calendar.weekDayHeaders;
    // ترتیب نمایش: شمسی از شنبه، میلادی از دوشنبه. داده همیشه شنبه‌محور است.
    int dataIndex(int shown) => calendar.isJalali ? shown : (shown + 2) % 7;
    final int todayShown = calendar.isJalali
        ? Jalali.fromDateTime(DateTime.now()).weekDay - 1
        : DateTime.now().weekday - 1;
    bool done(int shown) {
      final i = dataIndex(shown);
      return i < weekDays.length && weekDays[i];
    }

    final todayDone = done(todayShown);
    final String footer = currentStreak == 0 && !todayDone
        ? context.tr('streak.start')
        : (todayDone ? context.tr('streak.today_done') : context.tr('streak.keep'));
    final IconData stage = currentStreak >= 30
        ? Icons.workspace_premium_rounded
        : currentStreak >= 7
            ? Icons.local_fire_department_rounded
            : Icons.eco_rounded;

    const angles = [-69.0, -46.0, -23.0, 0.0, 23.0, 46.0, 69.0];
    const cx = _w / 2;
    const cy = 146.0;

    final dots = <Widget>[];
    for (var i = 0; i < 7; i++) {
      final a = angles[i] * pi / 180;
      final x = cx + _r * sin(a);
      final y = cy - _r * cos(a);
      final isToday = i == todayShown;
      final isDone = done(i);

      dots.add(Positioned(
        left: x - _dot / 2,
        top: y - _dot / 2,
        child: Container(
          width: _dot,
          height: _dot,
          decoration: BoxDecoration(
            color: isDone ? accent : _ink,
            shape: BoxShape.circle,
            boxShadow: isToday && !isDone
                ? [BoxShadow(color: accent, spreadRadius: 3)]
                : null,
          ),
          child: isDone
              ? Icon(Icons.check_rounded, size: 18, color: onAccent)
              : (isToday
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration:
                            BoxDecoration(color: accent, shape: BoxShape.circle),
                      ),
                    )
                  : null),
        ),
      ));
      dots.add(Positioned(
        left: x - 14,
        top: y + _dot / 2 + 3,
        width: 28,
        child: Text(
          labels[i],
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
            color: isToday ? theme.textColor : theme.textSecondaryColor,
          ),
        ),
      ));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bolt_rounded, color: accent, size: 22),
              const SizedBox(width: 6),
              Text(
                context.tr('streak.title'),
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: lime.bg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events_rounded, size: 16, color: lime.fg),
                const SizedBox(width: 6),
                Text(
                  context.tr('streak.record', {'n': '$bestStreak'}),
                  style: TextStyle(
                    color: lime.fg,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // روی صفحه‌های کوچک، کل گرافیک کوچک می‌شود (هیچ‌وقت سرریز نمی‌کند)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: _w,
              height: _h,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ...dots,
                  Positioned(
                    left: cx - 90,
                    top: cy - 90,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color: _ink,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.35),
                            blurRadius: 40,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(stage, color: accent, size: 30),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$currentStreak',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 56,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                context.tr('streak.days'),
                                style: const TextStyle(
                                  color: Color(0xFFBFC5B3),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.rocket_launch_rounded, size: 18, color: accent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  footer,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
