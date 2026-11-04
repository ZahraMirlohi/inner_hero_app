// lib/features/arena/widgets/arena_form_widgets.dart
//
// قطعه‌های مشترک فرم‌های عادت و تسک (افزودن/ویرایش) و دیالوگ انتخاب تاریخ،
// مطابق آرت‌بوردهای AddHabit / AddTask / EditHabit / EditTask / DateDialog.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '/features/arena/models/habit_model.dart';
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

/// شبکهٔ دایره‌های ثابت‌اندازه (بدون بریدگی؛ حلقهٔ انتخاب از لبه بیرون می‌زند)
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final c in children) SizedBox(width: size, height: size, child: c),
          ],
        );
      },
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
    final day = _day.clamp(1, _daysIn(_year, _month)).toInt();
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
    _selected = widget.selectedIndex.clamp(0, widget.labels.length - 1).toInt();
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

// ───────────────────────── کمک‌های مشترک ─────────────────────────

/// اسنک‌بار هماهنگ با تم (موفق/خطا)
void showArenaSnack(BuildContext context, String message, {bool error = false}) {
  final theme = Provider.of<ThemeProvider>(context, listen: false);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? theme.errorColor : theme.successColor,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}

/// ساعت‌شمار یادآور با ظاهر هماهنگ با برنامه
Future<TimeOfDay?> showArenaTimePicker(
  BuildContext context, {
  TimeOfDay? initial,
}) {
  final theme = Provider.of<ThemeProvider>(context, listen: false);
  return showTimePicker(
    context: context,
    initialTime: initial ?? TimeOfDay.now(),
    builder: (ctx, child) {
      final base = Theme.of(ctx);
      return Theme(
        data: base.copyWith(
          colorScheme: base.colorScheme.copyWith(
            primary: theme.effectivePrimary,
            onPrimary: theme.onPrimaryColor,
            surface: theme.cardColor,
            onSurface: theme.textColor,
          ),
          timePickerTheme: TimePickerThemeData(
            backgroundColor: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            hourMinuteShape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            hourMinuteColor: theme.cardSecondaryColor,
            dialBackgroundColor: theme.cardSecondaryColor,
            dialHandColor: theme.effectivePrimary,
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      );
    },
  );
}

/// سوییچ ۴۸×۲۸ مطابق طراحی (دکمهٔ گرد داخل کپسول)
class ArenaToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const ArenaToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? theme.effectivePrimary : theme.borderColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: value
              ? AlignmentDirectional.centerStart
              : AlignmentDirectional.centerEnd,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: value ? theme.onPrimaryColor : theme.cardColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── بخش‌های فرم عادت ─────────────────────────

/// بخش «تنظیمات سطوح انجام عادت»: کارت رنگ ملایم + چهار ورودی
class ArenaLevelSection extends StatelessWidget {
  final String? targetValue;
  final String? fullDescription;
  final String? halfDescription;
  final String? basicDescription;
  final ValueChanged<String> onTarget;
  final ValueChanged<String> onFull;
  final ValueChanged<String> onHalf;
  final ValueChanged<String> onBasic;

  const ArenaLevelSection({
    super.key,
    required this.targetValue,
    required this.fullDescription,
    required this.halfDescription,
    required this.basicDescription,
    required this.onTarget,
    required this.onFull,
    required this.onHalf,
    required this.onBasic,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return ArenaSection(
      color: theme.primarySoft,
      children: [
        ArenaSectionHeader(
          icon: Icons.track_changes_rounded,
          text: context.tr('af.level.title'),
        ),
        Text(
          context.tr('af.level.desc'),
          style: TextStyle(
            fontSize: 12,
            height: 1.8,
            color: theme.textColor.withValues(alpha: 0.75),
          ),
        ),
        ArenaTextField(
          label: context.tr('af.level.target'),
          hint: context.tr('af.level.target_hint'),
          initialValue: targetValue,
          onChanged: onTarget,
        ),
        ArenaTextField(
          label: context.tr('af.level.full'),
          labelIcon: Icons.stars_rounded,
          hint: context.tr('af.level.full_hint'),
          initialValue: fullDescription,
          onChanged: onFull,
        ),
        ArenaTextField(
          label: context.tr('af.level.half'),
          labelIcon: Icons.star_half_rounded,
          hint: context.tr('af.level.half_hint'),
          initialValue: halfDescription,
          onChanged: onHalf,
        ),
        ArenaTextField(
          label: context.tr('af.level.basic'),
          labelIcon: Icons.auto_awesome_rounded,
          hint: context.tr('af.level.basic_hint'),
          initialValue: basicDescription,
          onChanged: onBasic,
        ),
      ],
    );
  }
}

/// بخش زیرعادت/زیرتسک: تیتر + ورودی با دکمهٔ «+» + چیپ‌های قابل حذف
class ArenaSubItemsSection extends StatelessWidget {
  final String title;
  final String hint;
  final TextEditingController controller;
  final List<String> items;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  const ArenaSubItemsSection({
    super.key,
    required this.title,
    required this.hint,
    required this.controller,
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });

  void _submit() {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    onAdd(text);
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ArenaSection(
      children: [
        ArenaSectionHeader(icon: Icons.format_list_bulleted_rounded, text: title),
        ArenaAddItemRow(controller: controller, hint: hint, onAdd: _submit),
        if (items.isNotEmpty)
          ArenaRemovableChips(items: items, onRemove: onRemove),
      ],
    );
  }
}

class ArenaHabitIcon {
  final String name;
  final IconData icon;
  const ArenaHabitIcon(this.name, this.icon);
}

/// آیکن‌های قابل‌انتخاب عادت (نام ذخیره‌شده در مدل همان قبلی است)
const List<ArenaHabitIcon> kArenaHabitIcons = [
  ArenaHabitIcon('fitness_center', Icons.fitness_center_rounded),
  ArenaHabitIcon('self_improvement', Icons.self_improvement_rounded),
  ArenaHabitIcon('book', Icons.menu_book_rounded),
  ArenaHabitIcon('science', Icons.science_rounded),
  ArenaHabitIcon('restaurant', Icons.restaurant_rounded),
  ArenaHabitIcon('bedtime', Icons.bedtime_rounded),
  ArenaHabitIcon('water_drop', Icons.water_drop_rounded),
  ArenaHabitIcon('directions_walk', Icons.directions_walk_rounded),
  ArenaHabitIcon('run_circle', Icons.run_circle_rounded),
  ArenaHabitIcon('emoji_events', Icons.emoji_events_rounded),
];

/// رنگ‌های باکس عادت (داده‌اند، نه توکن تم)
const List<int> kArenaHabitBgColors = [
  0xFFFFF8E7,
  0xFFFFE0B2,
  0xFFFFCC80,
  0xFFFFAB91,
  0xFFB0CC5D,
  0xFF81D4FA,
  0xFFCE93D8,
  0xFFA5D6A7,
];

/// بخش «آیکن و رنگ»
class ArenaIconColorSection extends StatelessWidget {
  final String selectedIcon;
  final int selectedColor;
  final ValueChanged<String> onIcon;
  final ValueChanged<int> onColor;

  const ArenaIconColorSection({
    super.key,
    required this.selectedIcon,
    required this.selectedColor,
    required this.onIcon,
    required this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return ArenaSection(
      children: [
        ArenaSectionHeader(
          icon: Icons.star_outline_rounded,
          text: context.tr('af.icon.title'),
        ),
        ArenaLabel(context.tr('af.icon.icon')),
        ArenaCircleGrid(
          columns: 5,
          spacing: 10,
          children: [
            for (final item in kArenaHabitIcons)
              GestureDetector(
                onTap: () => onIcon(item.name),
                child: Container(
                  decoration: BoxDecoration(
                    color: selectedIcon == item.name
                        ? theme.effectivePrimary
                        : theme.cardSecondaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item.icon,
                    size: 22,
                    color: selectedIcon == item.name
                        ? theme.onPrimaryColor
                        : theme.textColor,
                  ),
                ),
              ),
          ],
        ),
        ArenaLabel(context.tr('af.icon.color')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: ArenaCircleGrid(
            columns: 8,
            spacing: 8,
            children: [
              for (final value in kArenaHabitBgColors)
                GestureDetector(
                  onTap: () => onColor(value),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(value),
                      shape: BoxShape.circle,
                      boxShadow: selectedColor == value
                          ? [
                              BoxShadow(color: theme.cardColor, spreadRadius: 3),
                              BoxShadow(color: theme.textColor, spreadRadius: 6),
                            ]
                          : null,
                    ),
                    child: selectedColor == value
                        ? const Icon(Icons.check_rounded,
                            size: 18, color: Color(0xFF090909))
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// بخش «تکرار»: روزانه / هفتگی / ماهانه (شنبه=۰ … جمعه=۶)
class ArenaFrequencySection extends StatelessWidget {
  final String frequencyType; // daily | weekly | monthly
  final int dailyInterval;
  final List<int> weeklyDays;
  final int weeklyInterval;
  final List<int> monthlyDays;
  final int monthlyInterval;
  final ValueChanged<String> onType;
  final ValueChanged<int> onDailyInterval;
  final ValueChanged<int> onToggleWeekday;
  final ValueChanged<int> onWeeklyInterval;
  final ValueChanged<int> onToggleMonthDay;
  final ValueChanged<int> onMonthlyInterval;

  const ArenaFrequencySection({
    super.key,
    required this.frequencyType,
    required this.dailyInterval,
    required this.weeklyDays,
    required this.weeklyInterval,
    required this.monthlyDays,
    required this.monthlyInterval,
    required this.onType,
    required this.onDailyInterval,
    required this.onToggleWeekday,
    required this.onWeeklyInterval,
    required this.onToggleMonthDay,
    required this.onMonthlyInterval,
  });

  static const List<String> _types = ['daily', 'weekly', 'monthly'];
  static const List<String> _lettersFa = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
  static const List<String> _lettersEn = ['S', 'S', 'M', 'T', 'W', 'T', 'F'];

  @override
  Widget build(BuildContext context) {
    final letters = context.isEnglish ? _lettersEn : _lettersFa;
    final selected = _types.indexOf(frequencyType).clamp(0, 2).toInt();
    final every = context.tr('af.freq.every');

    final List<Widget> content;
    switch (frequencyType) {
      case 'weekly':
        content = [
          ArenaCircleGrid(
            columns: 7,
            spacing: 6,
            children: [
              for (int i = 0; i < 7; i++)
                ArenaDayCircle(
                  text: letters[i],
                  selected: weeklyDays.contains(i),
                  onTap: () => onToggleWeekday(i),
                ),
            ],
          ),
          ArenaStepper(
            prefix: every,
            suffix: context.tr('af.freq.week'),
            value: weeklyInterval,
            min: 1,
            max: 12,
            onChanged: onWeeklyInterval,
          ),
        ];
        break;
      case 'monthly':
        content = [
          ArenaCircleGrid(
            columns: 8,
            spacing: 6,
            children: [
              for (int d = 1; d <= 31; d++)
                ArenaDayCircle(
                  text: '$d',
                  fontSize: 12,
                  selected: monthlyDays.contains(d),
                  onTap: () => onToggleMonthDay(d),
                ),
            ],
          ),
          ArenaStepper(
            prefix: every,
            suffix: context.tr('af.freq.month'),
            value: monthlyInterval,
            min: 1,
            max: 12,
            onChanged: onMonthlyInterval,
          ),
        ];
        break;
      default:
        content = [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ArenaStepper(
              prefix: every,
              suffix: context.tr('af.freq.day'),
              value: dailyInterval,
              min: 1,
              max: 30,
              onChanged: onDailyInterval,
            ),
          ),
        ];
    }

    return ArenaSection(
      children: [
        ArenaSectionHeader(
          icon: Icons.repeat_rounded,
          text: context.tr('af.freq.title'),
        ),
        ArenaSegmented(
          labels: [
            context.tr('af.freq.daily'),
            context.tr('af.freq.weekly'),
            context.tr('af.freq.monthly'),
          ],
          selected: selected,
          onChanged: (i) => onType(_types[i]),
        ),
        ...content,
      ],
    );
  }
}

/// بخش «زمان»: صبح / ظهر / بعدازظهر / شب
class ArenaTimeOfDaySection extends StatelessWidget {
  final String value; // morning | noon | afternoon | night
  final ValueChanged<String> onChanged;

  const ArenaTimeOfDaySection({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final items = <List<Object>>[
      ['morning', 'af.time.morning', Icons.wb_sunny_rounded],
      ['noon', 'af.time.noon', Icons.light_mode_rounded],
      ['afternoon', 'af.time.afternoon', Icons.wb_twilight_rounded],
      ['night', 'af.time.night', Icons.bedtime_rounded],
    ];
    return ArenaSection(
      children: [
        ArenaSectionHeader(
          icon: Icons.schedule_rounded,
          text: context.tr('af.time.title'),
        ),
        Row(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(items[i][0] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 72,
                    decoration: BoxDecoration(
                      color: value == items[i][0]
                          ? theme.effectivePrimary
                          : theme.cardSecondaryColor,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          items[i][2] as IconData,
                          size: 22,
                          color: value == items[i][0]
                              ? theme.onPrimaryColor
                              : theme.textColor,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr(items[i][1] as String),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: value == items[i][0]
                                ? theme.onPrimaryColor
                                : theme.textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// بخش «یادآور»: دکمهٔ افزودن + فهرست یادآورها (سوییچ فعال/غیرفعال + حذف)
class ArenaRemindersSection extends StatelessWidget {
  final List<Reminder> reminders;
  final VoidCallback onAdd;
  final ValueChanged<Reminder> onRemove;
  final void Function(Reminder reminder, bool enabled) onToggle;

  const ArenaRemindersSection({
    super.key,
    required this.reminders,
    required this.onAdd,
    required this.onRemove,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return ArenaSection(
      children: [
        Row(
          children: [
            Expanded(
              child: ArenaSectionHeader(
                icon: Icons.alarm_rounded,
                text: context.tr('af.rem.title'),
              ),
            ),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: theme.effectivePrimary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 16, color: theme.onPrimaryColor),
                    const SizedBox(width: 6),
                    Text(
                      context.tr('af.rem.add'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.onPrimaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (reminders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              context.tr('af.rem.empty'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: theme.textSecondaryColor),
            ),
          )
        else
          for (final r in reminders)
            Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsetsDirectional.only(start: 18, end: 6),
              decoration: BoxDecoration(
                color: theme.cardSecondaryColor,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      r.getTimeString(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: theme.textColor,
                      ),
                    ),
                  ),
                  ArenaToggle(
                    value: r.isEnabled,
                    onChanged: (v) => onToggle(r, v),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => onRemove(r),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.errorColor.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.delete_outline_rounded,
                          size: 18, color: theme.errorColor),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// کارت «تاریخ» (شروع/سررسید): تیتر + فیلد تاریخ
class ArenaDateSection extends StatelessWidget {
  final String title;
  final String text;
  final bool hasValue;
  final VoidCallback onTap;

  const ArenaDateSection({
    super.key,
    required this.title,
    required this.text,
    required this.hasValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ArenaSection(
      children: [
        ArenaSectionHeader(icon: Icons.calendar_month_rounded, text: title),
        ArenaDateField(text: text, hasValue: hasValue, onTap: onTap),
      ],
    );
  }
}

/// کارت «امتیاز XP»
class ArenaXpSection extends StatelessWidget {
  final String title;
  final int value;
  final ValueChanged<int> onChanged;

  const ArenaXpSection({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ArenaSection(
      children: [
        ArenaSectionHeader(icon: Icons.star_outline_rounded, text: title),
        ArenaXpSlider(value: value, onChanged: onChanged),
      ],
    );
  }
}
