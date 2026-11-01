// lib/core/app_palette.dart
//
// پالت رنگی ثابت برنامه: هشت «تُن» پاستلی که برای آیکون‌ها، کارت‌ها و بخش‌های مختلف به کار می‌روند
// تا برنامه تک‌رنگ و خسته‌کننده نشود. رنگ اصلی کاربر (primaryColor) همچنان برای دکمهٔ اصلی،
// حالت انتخاب و نوار پایین است.
//
// استفاده:   final t = context.watch<ThemeProvider>().tone(Tone.mint);
//            Container(color: t.bg, child: Icon(Icons.lock, color: t.fg))
//
// راهنمای مصرف تن‌ها در هر بخش: docs/PALETTE.md

import 'package:flutter/material.dart';

enum Tone { lilac, sky, peach, butter, mint, rose, lime, apricot }

class ToneColors {
  /// پس‌زمینهٔ ملایم (جعبهٔ آیکون، چیپ، کارت)
  final Color bg;

  /// رنگ پررنگ‌تر همان تن (آیکون، متن روی bg، حالت انتخاب‌شده)
  final Color fg;

  /// رنگ متن/آیکون روی fg
  final Color onFg;

  const ToneColors(this.bg, this.fg, this.onFg);
}

class AppPalette {
  AppPalette._();

  static const Map<Tone, Color> _pastel = {
    Tone.lilac: Color(0xFFDCD3FF),
    Tone.sky: Color(0xFFCFE6FF),
    Tone.peach: Color(0xFFFFD9C2),
    Tone.butter: Color(0xFFFFEFB0),
    Tone.mint: Color(0xFFC8F0DE),
    Tone.rose: Color(0xFFFFE0DC),
    Tone.lime: Color(0xFFE3F2C1),
    Tone.apricot: Color(0xFFFFE0B2),
  };

  static ToneColors of(Tone tone, {required bool dark}) {
    final base = _pastel[tone]!;
    final hsl = HSLColor.fromColor(base);

    if (dark) {
      return ToneColors(
        HSLColor.fromAHSL(1, hsl.hue, 0.30, 0.20).toColor(),
        HSLColor.fromAHSL(1, hsl.hue, 0.70, 0.78).toColor(),
        const Color(0xFF111111),
      );
    }
    return ToneColors(
      base,
      HSLColor.fromAHSL(1, hsl.hue, 0.58, 0.30).toColor(),
      Colors.white,
    );
  }
}
