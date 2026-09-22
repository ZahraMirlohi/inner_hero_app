// lib/features/arena/widgets/calendar_header.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/services/date_service.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '/providers/theme_provider.dart';

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
  String _calendarType = 'jalali';
  late List<DateTime> _monthDates;
  final ScrollController _scrollController = ScrollController();

  DateTime _currentMonth = DateTime.now();

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
    _loadCalendarType();
    _generateMonthDates();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCalendarType() async {
    final calendarType = await DateService.getCalendarType();
    setState(() {
      _calendarType = calendarType;
    });
  }

  void _generateMonthDates() {
    _monthDates.clear();
    final firstDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    );

    for (int i = 0; i < lastDayOfMonth.day; i++) {
      _monthDates.add(firstDayOfMonth.add(Duration(days: i)));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedIndex = _monthDates.indexWhere(
        (date) =>
            date.year == widget.selectedDate.year &&
            date.month == widget.selectedDate.month &&
            date.day == widget.selectedDate.day,
      );
      if (selectedIndex != -1 && _scrollController.hasClients) {
        _scrollController.animateTo(
          selectedIndex * 68.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _goToPreviousMonth() {
    setState(() {
      if (_calendarType == 'jalali') {
        final currentJalali = Jalali.fromDateTime(_currentMonth);
        int newYear = currentJalali.year;
        int newMonth = currentJalali.month - 1;
        if (newMonth < 1) {
          newMonth = 12;
          newYear--;
        }
        final newJalali = Jalali(newYear, newMonth, 1);
        _currentMonth = newJalali.toDateTime();
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
    setState(() {
      if (_calendarType == 'jalali') {
        final currentJalali = Jalali.fromDateTime(_currentMonth);
        int newYear = currentJalali.year;
        int newMonth = currentJalali.month + 1;
        if (newMonth > 12) {
          newMonth = 1;
          newYear++;
        }
        final newJalali = Jalali(newYear, newMonth, 1);
        _currentMonth = newJalali.toDateTime();
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

  void _onDateSelected(DateTime date) {
    final selectedDate = DateTime(date.year, date.month, date.day);
    widget.onDateSelected(selectedDate);
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

  String _getDayNumber(DateTime date) {
    if (_calendarType == 'jalali') {
      final jalali = Jalali.fromDateTime(date);
      return jalali.day.toString();
    } else {
      return date.day.toString();
    }
  }

  int _getJalaliWeekday(DateTime date) {
    final jalali = Jalali.fromDateTime(date);
    return jalali.weekDay - 1;
  }

  String _getWeekdayName(DateTime date) {
    if (_calendarType == 'jalali') {
      final weekdayNumber = _getJalaliWeekday(date);
      const weekdays = [
        'شنبه',
        'یک‌شنبه',
        'دوشنبه',
        'سه‌شنبه',
        'چهارشنبه',
        'پنج‌شنبه',
        'جمعه',
      ];
      return weekdays[weekdayNumber];
    } else {
      const weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return weekdays[date.weekday - 1];
    }
  }

  String _getMonthName(DateTime date) {
    if (_calendarType == 'jalali') {
      final jalali = Jalali.fromDateTime(date);
      const months = [
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
      return months[jalali.month - 1];
    } else {
      const months = [
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
      return months[date.month - 1];
    }
  }

  String _getYear(DateTime date) {
    if (_calendarType == 'jalali') {
      final jalali = Jalali.fromDateTime(date);
      return jalali.year.toString();
    } else {
      return date.year.toString();
    }
  }

  String _getCurrentMonthName() {
    return _getMonthName(_currentMonth);
  }

  String _getCurrentYear() {
    return _getYear(_currentMonth);
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    if (_calendarType == 'jalali') {
      final todayJalali = Jalali.fromDateTime(now);
      final dateJalali = Jalali.fromDateTime(date);
      return todayJalali.year == dateJalali.year &&
          todayJalali.month == dateJalali.month &&
          todayJalali.day == dateJalali.day;
    } else {
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }
  }

  bool _isSelectedDate(DateTime date) {
    if (_calendarType == 'jalali') {
      final selectedJalali = Jalali.fromDateTime(widget.selectedDate);
      final dateJalali = Jalali.fromDateTime(date);
      return selectedJalali.year == dateJalali.year &&
          selectedJalali.month == dateJalali.month &&
          selectedJalali.day == dateJalali.day;
    } else {
      return widget.selectedDate.year == date.year &&
          widget.selectedDate.month == date.month &&
          widget.selectedDate.day == date.day;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final Color primaryColor = themeProvider.primaryColor;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          // ✅ هدر تقویم با padding مناسب
          GestureDetector(
            onTap: _toggleExpanded,
            child: Padding(
              padding:
                  const EdgeInsets.only(top: 8, bottom: 4, left: 4, right: 4),
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
                        _getDayNumber(widget.selectedDate),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF090909),
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
                          _getWeekdayName(widget.selectedDate),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF090909),
                          ),
                        ),
                        Text(
                          '${_getMonthName(widget.selectedDate)} ${_getYear(widget.selectedDate)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: const Color(0xFF73786B),
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
                      color: const Color(0xFF73786B),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ✅ کشوی تقویم (بدون Scrollbar)
          if (_isExpanded)
            SizeTransition(
              sizeFactor: _scaleAnimation,
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    // ✅ ماه و سال
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
                            color: const Color(0xFF090909),
                          ),
                          Text(
                            '${_getCurrentMonthName()} ${_getCurrentYear()}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF090909),
                            ),
                          ),
                          IconButton(
                            onPressed: _goToNextMonth,
                            icon: const Icon(Icons.chevron_right),
                            iconSize: 28,
                            color: const Color(0xFF090909),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 4),

                    // ✅ لیست روزها (بدون Scrollbar)
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
                            final isToday = _isToday(date);
                            final isSelected = _isSelectedDate(date);

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
                                                alpha: 0.10)
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(24),
                                    border: isToday && !isSelected
                                        ? Border.all(
                                            color: primaryColor.withValues(
                                                alpha: 0.30),
                                            width: 1,
                                          )
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _getWeekdayName(date).substring(0, 1),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFF73786B),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _getDayNumber(date),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Colors.white
                                              : isToday
                                                  ? primaryColor
                                                  : const Color(0xFF090909),
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
}
