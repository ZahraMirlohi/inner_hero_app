import 'package:flutter/material.dart';
import '/services/date_service.dart';
import 'package:shamsi_date/shamsi_date.dart';

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
  double _dragStartX = 0;
  double _scrollStartX = 0;

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

  // calendar_header.dart

  int _getJalaliWeekday(DateTime date) {
    final jalali = Jalali.fromDateTime(date);
    // weekDay در کتابخانه shamsi_date:
    // 1 = شنبه, 2 = یکشنبه, 3 = دوشنبه, 4 = سه‌شنبه,
    // 5 = چهارشنبه, 6 = پنج‌شنبه, 7 = جمعه
    // برای تبدیل به ایندکس 0-6، باید 1 کم کنیم
    return jalali.weekDay - 1;
  }

  String _getWeekdayName(DateTime date) {
    if (_calendarType == 'jalali') {
      final weekdayNumber = _getJalaliWeekday(date);
      const weekdays = [
        'شنبه', // ایندکس 0
        'یک‌شنبه', // ایندکس 1
        'دوشنبه', // ایندکس 2
        'سه‌شنبه', // ایندکس 3
        'چهارشنبه', // ایندکس 4
        'پنج‌شنبه', // ایندکس 5
        'جمعه', // ایندکس 6
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

  void _onPanStart(DragStartDetails details) {
    _dragStartX = details.localPosition.dx;
    _scrollStartX = _scrollController.position.pixels;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final delta = details.localPosition.dx - _dragStartX;
    _scrollController.position.moveTo(_scrollStartX - delta);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          GestureDetector(
            onTap: _toggleExpanded,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(13),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2).withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _getDayNumber(widget.selectedDate),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A90E2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'امروز',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          _getWeekdayName(widget.selectedDate),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        Text(
                          '${_getMonthName(widget.selectedDate)} ${_getYear(widget.selectedDate)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
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
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded)
            SizeTransition(
              sizeFactor: _scaleAnimation,
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(13),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: _goToPreviousMonth,
                            icon: const Icon(Icons.chevron_left),
                            iconSize: 28,
                            color: const Color(0xFF4A90E2),
                          ),
                          Text(
                            '${_getCurrentMonthName()} ${_getCurrentYear()}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          IconButton(
                            onPressed: _goToNextMonth,
                            icon: const Icon(Icons.chevron_right),
                            iconSize: 28,
                            color: const Color(0xFF4A90E2),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    SizedBox(
                      height: 90,
                      child: Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        trackVisibility: true,
                        radius: const Radius.circular(10),
                        thickness: 6,
                        child: GestureDetector(
                          onPanStart: _onPanStart,
                          onPanUpdate: _onPanUpdate,
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
                                    widget.onDateSelected(date);
                                    _toggleExpanded();
                                  },
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: Container(
                                      width: 60,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFF4A90E2)
                                            : isToday
                                            ? const Color(
                                                0xFF4A90E2,
                                              ).withAlpha(25)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: isToday && !isSelected
                                            ? Border.all(
                                                color: const Color(0xFF4A90E2),
                                                width: 1,
                                              )
                                            : null,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            _getWeekdayName(
                                              date,
                                            ).substring(0, 1),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.grey.shade500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _getDayNumber(date),
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected
                                                  ? Colors.white
                                                  : isToday
                                                  ? const Color(0xFF4A90E2)
                                                  : const Color(0xFF1A1A2E),
                                            ),
                                          ),
                                          if (isToday)
                                            Container(
                                              width: 4,
                                              height: 4,
                                              margin: const EdgeInsets.only(
                                                top: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? Colors.white
                                                    : const Color(0xFF4A90E2),
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
