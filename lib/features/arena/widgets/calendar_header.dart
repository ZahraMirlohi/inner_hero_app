// lib/features/arena/widgets/calendar_header.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';
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
        final double itemWidth = 56 + 8;
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
    final Color primaryColor = theme.primaryColor;

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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          // ✅ هدر تقویم
          GestureDetector(
            onTap: _toggleExpanded,
            child: Padding(
              padding: const EdgeInsets.only(
                top: 8,
                bottom: 4,
                left: 4,
                right: 4,
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _getDayNumber(widget.selectedDate, calendar),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.textColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          calendar.getWeekdayName(widget.selectedDate),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
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
                    turns: _isExpanded ? 0.5 : 0.0,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: theme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ✅ کشوی تقویم
          if (_isExpanded)
            SizeTransition(
              sizeFactor: _scaleAnimation,
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: _goToPreviousMonth,
                            icon: const Icon(Icons.chevron_left),
                            iconSize: 28,
                            color: theme.textColor,
                          ),
                          Text(
                            calendar.getMonthYearLabel(_currentMonth),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.textColor,
                            ),
                          ),
                          IconButton(
                            onPressed: _goToNextMonth,
                            icon: const Icon(Icons.chevron_right),
                            iconSize: 28,
                            color: theme.textColor,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 80,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        child: Row(
                          children: _monthDates.map((date) {
                            final isToday = _isToday(date, calendar);
                            final isSelected = _isSelectedDate(date, calendar);

                            return GestureDetector(
                              onTap: () {
                                final cleanDate = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                );
                                widget.onDateSelected(cleanDate);
                                _toggleExpanded();
                              },
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Container(
                                  width: 56,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? primaryColor
                                        : isToday
                                            ? primaryColor.withValues(
                                                alpha: 0.10,
                                              )
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(24),
                                    border: isToday && !isSelected
                                        ? Border.all(
                                            color: primaryColor.withValues(
                                              alpha: 0.30,
                                            ),
                                            width: 1,
                                          )
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        calendar.getWeekdayShort(date),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: isSelected
                                              ? Colors.white
                                              : theme.textSecondaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _getDayNumber(date, calendar),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Colors.white
                                              : isToday
                                                  ? primaryColor
                                                  : theme.textColor,
                                        ),
                                      ),
                                      if (isToday)
                                        Container(
                                          width: 4,
                                          height: 4,
                                          margin: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Colors.white
                                                : primaryColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
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
