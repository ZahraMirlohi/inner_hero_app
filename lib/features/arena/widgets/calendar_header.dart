// lib/features/arena/widgets/calendar_header.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '/l10n/app_strings.dart';
import '/providers/theme_provider.dart';
import '/providers/calendar_provider.dart';

class CalendarHeader extends StatefulWidget {
  final Function(DateTime) onDateSelected;
  final DateTime selectedDate;

  const CalendarHeader({
    super.key,
    required this.onDateSelected,
    required this.selectedDate,
  });

  @override
  State<CalendarHeader> createState() => _CalendarHeaderState();
}

class _CalendarHeaderState extends State<CalendarHeader>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late List<DateTime> _monthDates;
  final ScrollController _scrollController = ScrollController();

  DateTime _currentMonth = DateTime.now();
  CalendarType? _lastCalendarType;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _monthDates = [];
    _currentMonth = widget.selectedDate;
    _generateMonthDates();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final calendar = Provider.of<CalendarProvider>(context);
    if (_lastCalendarType != calendar.calendarType) {
      _lastCalendarType = calendar.calendarType;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _generateMonthDates();
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _generateMonthDates() {
    _monthDates.clear();
    final calendar = Provider.of<CalendarProvider>(context, listen: false);

    if (calendar.isJalali) {
      final jalali = Jalali.fromDateTime(_currentMonth);
      final firstDayJalali = Jalali(jalali.year, jalali.month, 1);
      final daysCount = calendar.daysInMonth(jalali.year, jalali.month);
      final firstDayMiladi = firstDayJalali.toDateTime();

      for (int i = 0; i < daysCount; i++) {
        _monthDates.add(firstDayMiladi.add(Duration(days: i)));
      }
    } else {
      final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
      final daysCount = DateTime(
        _currentMonth.year,
        _currentMonth.month + 1,
        0,
      ).day;

      for (int i = 0; i < daysCount; i++) {
        _monthDates.add(firstDay.add(Duration(days: i)));
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final now = DateTime.now();
      int targetIndex = _monthDates.indexWhere(
        (date) =>
            date.year == now.year &&
            date.month == now.month &&
            date.day == now.day,
      );

      if (targetIndex == -1) {
        targetIndex = _monthDates.indexWhere(
          (date) =>
              date.year == widget.selectedDate.year &&
              date.month == widget.selectedDate.month &&
              date.day == widget.selectedDate.day,
        );
      }

      if (targetIndex != -1) {
        final double itemWidth = 52 + 8;
        final double screenWidth = MediaQuery.of(context).size.width;
        final double targetOffset =
            (targetIndex * itemWidth) - (screenWidth / 2) + (itemWidth / 2);

        _scrollController.animateTo(
          targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _goToPreviousMonth() {
    final calendar = Provider.of<CalendarProvider>(context, listen: false);
    setState(() {
      if (calendar.isJalali) {
        final j = Jalali.fromDateTime(_currentMonth);
        int newYear = j.year;
        int newMonth = j.month - 1;
        if (newMonth < 1) {
          newMonth = 12;
          newYear--;
        }
        _currentMonth = Jalali(newYear, newMonth, 1).toDateTime();
      } else {
        _currentMonth = DateTime(
          _currentMonth.year,
          _currentMonth.month - 1,
          1,
        );
      }
      _generateMonthDates();
    });
  }

  void _goToNextMonth() {
    final calendar = Provider.of<CalendarProvider>(context, listen: false);
    setState(() {
      if (calendar.isJalali) {
        final j = Jalali.fromDateTime(_currentMonth);
        int newYear = j.year;
        int newMonth = j.month + 1;
        if (newMonth > 12) {
          newMonth = 1;
          newYear++;
        }
        _currentMonth = Jalali(newYear, newMonth, 1).toDateTime();
      } else {
        _currentMonth = DateTime(
          _currentMonth.year,
          _currentMonth.month + 1,
          1,
        );
      }
      _generateMonthDates();
    });
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
        _generateMonthDates();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final calendar = Provider.of<CalendarProvider>(context);
    if (_lastCalendarType != calendar.calendarType) {
      _lastCalendarType = calendar.calendarType;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _generateMonthDates();
          });
        }
      });
    }

    final rtl = Directionality.of(context) == TextDirection.rtl;

    Widget circleBtn(IconData icon, VoidCallback onTap,
        {Color? bg, bool shadow = true}) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: bg ?? theme.cardColor,
            shape: BoxShape.circle,
            boxShadow: shadow ? theme.softShadow : null,
          ),
          child: Icon(icon, size: 22, color: theme.textColor),
        ),
      );
    }

    return Column(
      children: [
        // هدر: دایرهٔ روز + نام روز و تاریخ + دکمهٔ باز و بسته کردن تقویم
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.primarySoft,
                      Color.alphaBlend(
                        theme.primaryColor.withValues(alpha: 0.35),
                        theme.primarySoft,
                      ),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  _getDayNumber(widget.selectedDate, calendar),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: theme.textColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isToday(widget.selectedDate, calendar))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          context.tr(_greetingKey()),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: theme.textSecondaryColor,
                          ),
                        ),
                      ),
                    Text(
                      calendar.getWeekdayName(widget.selectedDate),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: theme.textColor,
                      ),
                    ),
                    Text(
                      calendar.formatWithMonthName(widget.selectedDate),
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedRotation(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                turns: _isExpanded ? 0.5 : 0.0,
                child: circleBtn(
                    Icons.keyboard_arrow_down_rounded, _toggleExpanded),
              ),
            ],
          ),
        ),

        // تقویم باز: کارت سفید با ناوبری ماه و نوار روزها
        AnimatedSize(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !_isExpanded
              ? const SizedBox(width: double.infinity)
              : Container(
                  margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: theme.softShadow,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          circleBtn(
                            rtl
                                ? Icons.chevron_right_rounded
                                : Icons.chevron_left_rounded,
                            _goToPreviousMonth,
                            bg: theme.cardSecondaryColor,
                            shadow: false,
                          ),
                          Text(
                            calendar.getMonthYearLabel(_currentMonth),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: theme.textColor,
                            ),
                          ),
                          circleBtn(
                            rtl
                                ? Icons.chevron_left_rounded
                                : Icons.chevron_right_rounded,
                            _goToNextMonth,
                            bg: theme.cardSecondaryColor,
                            shadow: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 78,
                        child: ListView.separated(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          itemCount: _monthDates.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final date = _monthDates[index];
                            final isToday = _isToday(date, calendar);
                            final isSelected = _isSelectedDate(date, calendar);
                            final fg = isSelected
                                ? theme.onPrimaryColor
                                : theme.textColor;
                            return GestureDetector(
                              onTap: () {
                                widget.onDateSelected(
                                    DateTime(date.year, date.month, date.day));
                                _toggleExpanded();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                width: 52,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? theme.primaryColor
                                      : theme.cardSecondaryColor,
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      calendar.getWeekdayShort(date),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? theme.onPrimaryColor
                                            : theme.textSecondaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _getDayNumber(date, calendar),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: fg,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: isToday
                                            ? (isSelected
                                                ? theme.onPrimaryColor
                                                : theme.textColor)
                                            : Colors.transparent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  String _greetingKey() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'ah.greet.morning';
    if (h >= 12 && h < 17) return 'ah.greet.noon';
    if (h >= 17 && h < 21) return 'ah.greet.evening';
    return 'ah.greet.night';
  }

  String _getDayNumber(DateTime date, CalendarProvider calendar) {
    if (calendar.isJalali) {
      return Jalali.fromDateTime(date).day.toString();
    }
    return date.day.toString();
  }

  bool _isToday(DateTime date, CalendarProvider calendar) {
    final now = DateTime.now();
    if (calendar.isJalali) {
      final todayJ = Jalali.fromDateTime(now);
      final dateJ = Jalali.fromDateTime(date);
      return todayJ.year == dateJ.year &&
          todayJ.month == dateJ.month &&
          todayJ.day == dateJ.day;
    }
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isSelectedDate(DateTime date, CalendarProvider calendar) {
    if (calendar.isJalali) {
      final selectedJ = Jalali.fromDateTime(widget.selectedDate);
      final dateJ = Jalali.fromDateTime(date);
      return selectedJ.year == dateJ.year &&
          selectedJ.month == dateJ.month &&
          selectedJ.day == dateJ.day;
    }
    return widget.selectedDate.year == date.year &&
        widget.selectedDate.month == date.month &&
        widget.selectedDate.day == date.day;
  }
}
