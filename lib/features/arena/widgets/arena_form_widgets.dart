// lib/features/arena/widgets/arena_form_widgets.dart
//
// قطعه‌های مشترک فرم‌های عادت و تسک (افزودن/ویرایش) و دیالوگ انتخاب تاریخ،
// مطابق آرت‌بوردهای AddHabit / AddTask / EditHabit / EditTask / DateDialog.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '/l10n/app_strings.dart';
import '/providers/calendar_provider.dart';
import '/providers/theme_provider.dart';
import '/core/app_palette.dart';

// ───────────────────────── صفحه و سربرگ ─────────────────────────

/// اسکلت صفحهٔ فرم: دکمهٔ بازگشت گرد + عنوان ۲۰/۸۰۰ + بدنهٔ اسکرول‌شونده.
class ArenaFormPage extends StatelessWidget {
  final String title;
  final GlobalKey<FormState>? formKey;
  final List<Widget> children;

  const ArenaFormPage({
    super.key,
    required this.title,
    required this.children,
    this.formKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.maybePop(context),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          shape: BoxShape.circle,
                          boxShadow: theme.softShadow,
                        ),
                        child: Icon(Icons.arrow_back_rounded,
                            size: 22, color: theme.textColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: theme.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < children.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        children[i],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// کارت سفید گرد (شعاع ۲۸) با فاصلهٔ ۱۲ بین فرزندها.
class ArenaSection extends StatelessWidget {
  final List<Widget> children;

  /// اگر داده شود به‌جای کارت سفید و با سایه، کارت رنگی بدون سایه می‌شود.
  final Color? color;

  const ArenaSection({super.key, required this.children, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: color == null ? theme.softShadow : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// تیتر بخش: آیکن ۲۰ + متن ۱۶/۸۰۰
class ArenaSectionHeader extends StatelessWidget {
  final IconData icon;
  final String text;

  const ArenaSectionHeader({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.textColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: theme.textColor,
            ),
          ),
        ),
      ],
    );
  }
}

class ArenaLabel extends StatelessWidget {
  final String text;
  final IconData? icon;

  const ArenaLabel(this.text, {super.key, this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final style = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: theme.textSecondaryColor,
    );
    if (icon == null) return Text(text, style: style);
    return Row(
      children: [
        Icon(icon, size: 15, color: theme.textSecondaryColor),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: style)),
      ],
    );
  }
}

// ───────────────────────── ورودی‌ها ─────────────────────────

InputDecoration arenaPillDecoration(
  ThemeProvider theme, {
  String? hint,
  double radius = 26,
  double verticalPadding = 15,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(radius),
    borderSide: BorderSide.none,
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      fontSize: 14,
      color: theme.textSecondaryColor.withValues(alpha: 0.8),
    ),
    filled: true,
    fillColor: theme.cardSecondaryColor,
    isDense: true,
    contentPadding:
        EdgeInsets.symmetric(horizontal: 18, vertical: verticalPadding),
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: theme.effectivePrimary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: theme.errorColor, width: 1.2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: theme.errorColor, width: 1.5),
    ),
  );
}

/// برچسب ۱۳/۶۰۰ + ورودی قرص‌مانند (شعاع ۲۶، پس‌زمینهٔ cardSecondary)
class ArenaTextField extends StatelessWidget {
  final String? label;
  final IconData? labelIcon;
  final String? hint;
  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final int minLines;
  final int maxLines;

  const ArenaTextField({
    super.key,
    this.label,
    this.labelIcon,
    this.hint,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.validator,
    this.minLines = 1,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final multi = maxLines > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          ArenaLabel(label!, icon: labelIcon),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          onChanged: onChanged,
          validator: validator,
          minLines: minLines,
          maxLines: maxLines,
          style: TextStyle(fontSize: 14, color: theme.textColor),
          cursorColor: theme.effectivePrimary,
          textAlignVertical: multi ? TextAlignVertical.top : null,
          decoration: arenaPillDecoration(
            theme,
            hint: hint,
            verticalPadding: multi ? 14 : 15,
          ),
        ),
      ],
    );
  }
}

/// فیلد تاریخ: متن + آیکن تقویم، با لمس باز می‌شود.
class ArenaDateField extends StatelessWidget {
  final String text;
  final bool hasValue;
  final VoidCallback onTap;

  const ArenaDateField({
    super.key,
    required this.text,
    required this.hasValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: theme.cardSecondaryColor,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: hasValue
                      ? theme.textColor
                      : theme.textSecondaryColor.withValues(alpha: 0.8),
                ),
              ),
            ),
            Icon(Icons.calendar_month_rounded,
                size: 20, color: theme.textSecondaryColor),
          ],
        ),
      ),
    );
  }
}

/// دایرهٔ «+» رنگ اصلی ۴۸ پیکسلی
class ArenaAddCircle extends StatelessWidget {
  final VoidCallback onTap;

  const ArenaAddCircle({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: theme.effectivePrimary,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.add_rounded, size: 22, color: theme.onPrimaryColor),
      ),
    );
  }
}

/// ردیف «ورودی + دکمهٔ افزودن» برای زیرعادت/زیرتسک
class ArenaAddItemRow extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onAdd;

  const ArenaAddItemRow({
    super.key,
    required this.controller,
    required this.hint,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            style: TextStyle(fontSize: 14, color: theme.textColor),
            cursorColor: theme.effectivePrimary,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onAdd(),
            decoration: arenaPillDecoration(theme, hint: hint, verticalPadding: 16),
          ),
        ),
        const SizedBox(width: 10),
        ArenaAddCircle(onTap: onAdd),
      ],
    );
  }
}

/// چیپ‌های قابل حذف (زیرعادت/زیرتسک)
class ArenaRemovableChips extends StatelessWidget {
  final List<String> items;
  final ValueChanged<String> onRemove;

  const ArenaRemovableChips(
      {super.key, required this.items, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Container(
            height: 34,
            padding: const EdgeInsetsDirectional.only(start: 14, end: 6),
            decoration: BoxDecoration(
              color: theme.primarySoft,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    item,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.textColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => onRemove(item),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: theme.cardColor.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded,
                        size: 12, color: theme.textColor),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ───────────────────────── کنترل‌ها ─────────────────────────

/// سوییچ بخش‌بندی‌شده (روزانه | هفتگی | ماهانه) با ارتفاع ثابت و گوشهٔ گرد
class ArenaSegmented extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final double height;

  const ArenaSegmented({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.cardSecondaryColor,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected
                        ? theme.effectivePrimary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular((height - 8) / 2),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          i == selected ? FontWeight.w700 : FontWeight.w500,
                      color: i == selected
                          ? theme.onPrimaryColor
                          : theme.textSecondaryColor,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// «هر [−] n [+] روز» (مرحله‌دهنده)
class ArenaStepper extends StatelessWidget {
  final String prefix;
  final String suffix;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const ArenaStepper({
    super.key,
    required this.prefix,
    required this.suffix,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    Widget btn(IconData icon, Color bg, Color fg, VoidCallback? onTap) {
      return InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: fg),
        ),
      );
    }

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ArenaLabel(prefix),
          const SizedBox(width: 10),
          btn(Icons.remove_rounded, theme.cardSecondaryColor, theme.textColor,
              value > min ? () => onChanged(value - 1) : null),
          const SizedBox(width: 10),
          Container(
            constraints: const BoxConstraints(minWidth: 44),
            height: 40,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: theme.primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: theme.textColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          btn(Icons.add_rounded, theme.effectivePrimary, theme.onPrimaryColor,
              value < max ? () => onChanged(value + 1) : null),
          const SizedBox(width: 10),
          ArenaLabel(suffix),
        ],
      ),
    );
  }
}

/// دایرهٔ قابل انتخاب (روز هفته/روز ماه)
class ArenaDayCircle extends StatelessWidget {
  final String text;
  final bool selected;
  final double fontSize;
  final VoidCallback onTap;

  const ArenaDayCircle({
    super.key,
    required this.text,
    required this.selected,
    required this.onTap,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? theme.effectivePrimary : theme.cardSecondaryColor,
          shape: BoxShape.circle,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: selected ? theme.onPrimaryColor : theme.textColor,
          ),
        ),
      ),
    );
  }
}

/// شبکهٔ دایره‌های ثابت‌اندازه
class ArenaCircleGrid extends StatelessWidget {
  final int columns;
  final double spacing;
  final List<Widget> children;

  const ArenaCircleGrid({
    super.key,
    required this.columns,
    required this.spacing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: columns,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}

/// دکمهٔ اصلی ۵۶ پیکسلی قرصی (رنگ اصلی + سایهٔ رنگی)
class ArenaPrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback? onPressed;

  const ArenaPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final fg = theme.onPrimaryColor;
    return GestureDetector(
      onTap: loading ? null : onPressed,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: theme.effectivePrimary,
          borderRadius: BorderRadius.circular(28),
          boxShadow: theme.isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: theme.effectivePrimary.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: loading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 22, color: fg),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ───────────────────────── اسلایدر XP ─────────────────────────

class _XpThumbShape extends SliderComponentShape {
  final Color color;
  const _XpThumbShape(this.color);

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(28, 28);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    context.canvas.drawCircle(center, 14, Paint()..color = color);
  }
}

/// بخش امتیاز XP: اسلایدر با دستگیرهٔ مشکی + قرص «n XP» + نوشتهٔ حداقل/حداکثر
class ArenaXpSlider extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final int divisions;
  final ValueChanged<int> onChanged;

  const ArenaXpSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 5,
    this.max = 200,
    this.divisions = 39,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final tone = theme.tone(Tone.apricot);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 10,
                  activeTrackColor: theme.effectivePrimary,
                  inactiveTrackColor: theme.cardSecondaryColor,
                  thumbShape: _XpThumbShape(theme.checkButtonBackground),
                  overlayShape: SliderComponentShape.noOverlay,
                  tickMarkShape: SliderTickMarkShape.noTickMark,
                  trackShape: const RoundedRectSliderTrackShape(),
                ),
                child: Slider(
                  value: value.clamp(min, max).toDouble(),
                  min: min.toDouble(),
                  max: max.toDouble(),
                  divisions: divisions,
                  onChanged: (v) => onChanged(v.round()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              constraints: const BoxConstraints(minWidth: 72),
              height: 34,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: tone.bg,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Text(
                '$value XP',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: theme.isDarkMode ? tone.fg : const Color(0xFF090909),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$min',
                  style: TextStyle(
                      fontSize: 12, color: theme.textSecondaryColor)),
              Text('$max',
                  style: TextStyle(
                      fontSize: 12, color: theme.textSecondaryColor)),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── دیالوگ انتخاب تاریخ ─────────────────────────

const List<String> _jalaliMonthsFa = [
  'فروردین',
  'اردیبهشت',
  'خرداد',
  'تیر',
  'مرداد',
  'شهریور',
  'مهر',
  'آبان',
  'آذر',
  'دی',
  'بهمن',
  'اسفند',
];
const List<String> _jalaliMonthsEn = [
  'Farvardin',
  'Ordibehesht',
  'Khordad',
  'Tir',
  'Mordad',
  'Shahrivar',
  'Mehr',
  'Aban',
  'Azar',
  'Dey',
  'Bahman',
  'Esfand',
];
const List<String> _gregorianMonthsFa = [
  'ژانویه',
  'فوریه',
  'مارس',
  'آوریل',
  'مه',
  'ژوئن',
  'ژوئیه',
  'اوت',
  'سپتامبر',
  'اکتبر',
  'نوامبر',
  'دسامبر',
];
const List<String> _gregorianMonthsEn = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// دیالوگ انتخاب تاریخ با چرخ‌های سال/ماه/روز و کلید شمسی/میلادی.
/// تاریخ انتخاب‌شده را (میلادی، فقط روز) برمی‌گرداند؛ با انصراف null.
Future<DateTime?> showArenaDateDialog(
  BuildContext context, {
  DateTime? initial,
}) {
  final calendar = Provider.of<CalendarProvider>(context, listen: false);
  return showDialog<DateTime>(
    context: context,
    barrierColor: const Color(0xFF090909).withValues(alpha: 0.42),
    builder: (_) => _ArenaDateDialog(
      initial: initial ?? DateTime.now(),
      startJalali: calendar.isJalali,
    ),
  );
}

class _ArenaDateDialog extends StatefulWidget {
  final DateTime initial;
  final bool startJalali;

  const _ArenaDateDialog({required this.initial, required this.startJalali});

  @override
  State<_ArenaDateDialog> createState() => _ArenaDateDialogState();
}

class _ArenaDateDialogState extends State<_ArenaDateDialog> {
  late bool _jalali;
  late int _year;
  late int _month;
  late int _day;

  @override
  void initState() {
    super.initState();
    _jalali = widget.startJalali;
    _setFrom(widget.initial);
  }

  void _setFrom(DateTime d) {
    if (_jalali) {
      final j = Jalali.fromDateTime(d);
      _year = j.year;
      _month = j.month;
      _day = j.day;
    } else {
      _year = d.year;
      _month = d.month;
      _day = d.day;
    }
  }

  int _daysIn(int year, int month) {
    if (_jalali) return Jalali(year, month, 1).monthLength;
    return DateTime(year, month + 1, 0).day;
  }

  DateTime _current() {
    final day = _day.clamp(1, _daysIn(_year, _month));
    return _jalali
        ? Jalali(_year, _month, day).toDateTime()
        : DateTime(_year, _month, day);
  }

  void _switchMode(bool jalali) {
    if (jalali == _jalali) return;
    final d = _current();
    setState(() {
      _jalali = jalali;
      _setFrom(d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final en = context.isEnglish;

    final nowYear = _jalali ? Jalali.now().year : DateTime.now().year;
    final firstYear = (nowYear - 2) < _year ? nowYear - 2 : _year;
    final lastYear = (nowYear + 10) > _year ? nowYear + 10 : _year;
    final years = [for (int y = firstYear; y <= lastYear; y++) y];

    final monthNames = _jalali
        ? (en ? _jalaliMonthsEn : _jalaliMonthsFa)
        : (en ? _gregorianMonthsEn : _gregorianMonthsFa);

    final daysCount = _daysIn(_year, _month);
    if (_day > daysCount) _day = daysCount;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF090909).withValues(alpha: 0.25),
              blurRadius: 50,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('af.date.title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 14),
            ArenaSegmented(
              height: 44,
              labels: [
                context.tr('af.date.jalali'),
                context.tr('af.date.gregorian'),
              ],
              selected: _jalali ? 0 : 1,
              onChanged: (i) => _switchMode(i == 0),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: theme.backgroundColor,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _DateWheel(
                      key: ValueKey('y_$_jalali'),
                      title: context.tr('af.date.year'),
                      labels: [for (final y in years) '$y'],
                      selectedIndex: years.indexOf(_year),
                      onChanged: (i) => setState(() => _year = years[i]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DateWheel(
                      key: ValueKey('m_$_jalali'),
                      title: context.tr('af.date.month'),
                      labels: monthNames,
                      selectedIndex: _month - 1,
                      onChanged: (i) => setState(() => _month = i + 1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DateWheel(
                      key: ValueKey('d_${_jalali}_$daysCount'),
                      title: context.tr('af.date.day'),
                      labels: [for (int d = 1; d <= daysCount; d++) '$d'],
                      selectedIndex: _day - 1,
                      onChanged: (i) => setState(() => _day = i + 1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 10,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.cardSecondaryColor,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Text(
                        context.tr('af.date.cancel'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: theme.textColor,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 13,
                  child: GestureDetector(
                    onTap: () {
                      try {
                        final d = _current();
                        Navigator.pop(context, DateTime(d.year, d.month, d.day));
                      } catch (_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.tr('af.date.invalid')),
                            backgroundColor: theme.errorColor,
                          ),
                        );
                      }
                    },
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.checkButtonBackground,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Text(
                        context.tr('af.date.confirm'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: theme.onCheckButton,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// یک چرخ انتخاب (۵ ردیف قابل‌دیدن؛ ردیف وسط با قرص رنگی مشخص می‌شود)
class _DateWheel extends StatefulWidget {
  final String title;
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _DateWheel({
    super.key,
    required this.title,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  State<_DateWheel> createState() => _DateWheelState();
}

class _DateWheelState extends State<_DateWheel> {
  static const double _itemExtent = 40;
  late FixedExtentScrollController _controller;
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedIndex.clamp(0, widget.labels.length - 1);
    _controller = FixedExtentScrollController(initialItem: _selected);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Column(
      children: [
        ArenaLabel(widget.title),
        const SizedBox(height: 6),
        SizedBox(
          height: _itemExtent * 5,
          child: Stack(
            alignment: Alignment.center,
            children: [
              IgnorePointer(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: theme.primarySoft,
                    borderRadius: BorderRadius.circular(23),
                  ),
                ),
              ),
              ListWheelScrollView.useDelegate(
                controller: _controller,
                itemExtent: _itemExtent,
                diameterRatio: 100,
                perspective: 0.0001,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (i) {
                  setState(() => _selected = i);
                  widget.onChanged(i);
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: widget.labels.length,
                  builder: (context, i) {
                    final dist = (i - _selected).abs();
                    final isSel = dist == 0;
                    return Center(
                      child: Opacity(
                        opacity: isSel ? 1 : (dist == 1 ? 0.5 : 0.22),
                        child: Text(
                          widget.labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isSel ? 18 : 15,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                            color: theme.textColor,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
