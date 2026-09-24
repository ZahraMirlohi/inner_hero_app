// lib/widgets/persian_text.dart

import 'package:flutter/material.dart';

/// ✅ ویجت متن برای نمایش صحیح متون فارسی/عربی
/// این ویجت متن را مجبور می‌کند که همیشه RTL رندر شود
class PersianText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool softWrap;
  final TextDirection textDirection;

  const PersianText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap = true,
    this.textDirection = TextDirection.rtl,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ استفاده از کاراکتر کنترلی RLM (Right-to-Left Mark)
    // این کاراکتر نامرئی باعث می‌شود Flutter جهت متن را RTL تشخیص دهد
    // حتی اگر متن با عدد یا حرف انگلیسی شروع شود
    final String processedText = '\u200F$text\u200F';

    return Text(
      processedText,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      textDirection: textDirection,
    );
  }
}

/// ✅ ویجت متن برای اعداد و متون ترکیبی
/// اگر فقط می‌خواهید یک تکه متن خاص را اصلاح کنید
class BidiText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const BidiText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ استفاده از کاراکتر کنترلی برای اصلاح جهت
    return Text(
      '\u200F$text',
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      textDirection: TextDirection.rtl,
    );
  }
}
