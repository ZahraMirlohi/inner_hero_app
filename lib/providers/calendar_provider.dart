// lib/providers/calendar_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamsi_date/shamsi_date.dart';

enum CalendarType { jalali, gregorian }

class CalendarProvider extends ChangeNotifier {
  static const String _calendarTypeKey = 'calendar_type';

  CalendarType _calendarType = CalendarType.jalali;
  bool _isInitialized = false;

  CalendarType get calendarType => _calendarType;
  bool get isInitialized => _isInitialized;
  bool get isJalali => _calendarType == CalendarType.jalali;
  bool get isGregorian => _calendarType == CalendarType.gregorian;

  CalendarProvider() {
    _loadSavedValue();
  }

  Future<void> _loadSavedValue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_calendarTypeKey);
      if (saved != null) {
        _calendarType =
            saved == 'jalali' ? CalendarType.jalali : CalendarType.gregorian;
      }
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> setCalendarType(CalendarType type) async {
    if (_calendarType == type) return;
    _calendarType = type;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _calendarTypeKey,
        type == CalendarType.jalali ? 'jalali' : 'gregorian',
      );
    } catch (e) {
      debugPrint('❌ Error saving calendar type: $e');
    }
  }

  Future<void> toggle() async {
    await setCalendarType(
      _calendarType == CalendarType.jalali
          ? CalendarType.gregorian
          : CalendarType.jalali,
    );
  }

  // ==================== متدهای فرمت‌دهی ====================

  /// فرمت کوتاه: 1404/07/12 یا 2025/10/04
  String formatShort(DateTime date) {
    if (isJalali) {
      final j = Jalali.fromDateTime(date);
      return '${j.year}/${_two(j.month)}/${_two(j.day)}';
    } else {
      return '${date.year}/${_two(date.month)}/${_two(date.day)}';
    }
  }

  /// فرمت با نام ماه: 12 مهر 1404 یا 4 October 2025
  String formatWithMonthName(DateTime date) {
    if (isJalali) {
      final j = Jalali.fromDateTime(date);
      final months = [
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
      return '${j.day} ${months[j.month - 1]} ${j.year}';
    } else {
      final months = [
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
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
  }

  /// تاریخ نسبی: امروز، دیروز، ۳ روز پیش
  String formatRelative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return isJalali ? 'امروز' : 'Today';
    if (diff == 1) return isJalali ? 'دیروز' : 'Yesterday';
    if (diff == -1) return isJalali ? 'فردا' : 'Tomorrow';

    if (diff > 1 && diff < 7) {
      return isJalali ? '$diff روز پیش' : '$diff days ago';
    }
    if (diff < -1 && diff > -7) {
      return isJalali ? '${-diff} روز بعد' : 'In ${-diff} days';
    }

    return formatShort(date);
  }

  /// نام روز هفته: شنبه، یکشنبه...
  String getWeekdayName(DateTime date) {
    if (isJalali) {
      final j = Jalali.fromDateTime(date);
      // weekDay: 1=شنبه ... 7=جمعه
      const names = [
        'شنبه',
        'یکشنبه',
        'دوشنبه',
        'سه‌شنبه',
        'چهارشنبه',
        'پنجشنبه',
        'جمعه',
      ];
      return names[j.weekDay - 1];
    } else {
      // weekday: 1=Monday ... 7=Sunday
      const names = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return names[date.weekday - 1];
    }
  }

  /// حرف اول روز هفته: ش، ی، د...  یا M, T, W...
  String getWeekdayShort(DateTime date) {
    if (isJalali) {
      final j = Jalali.fromDateTime(date);
      const letters = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
      return letters[j.weekDay - 1];
    } else {
      const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      return letters[date.weekday - 1];
    }
  }

  /// حروف کوتاه روزهای هفته برای هدر تقویم
  List<String> get weekDayHeaders {
    if (isJalali) {
      return ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
    } else {
      return ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    }
  }

  /// نام ماه برای هدر: مهر 1404 یا October 2025
  String getMonthYearLabel(DateTime date) {
    if (isJalali) {
      final j = Jalali.fromDateTime(date);
      final months = [
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
      return '${months[j.month - 1]} ${j.year}';
    } else {
      final months = [
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
      return '${months[date.month - 1]} ${date.year}';
    }
  }

  /// نام ماه کوتاه
  String getMonthShortName(DateTime date) {
    if (isJalali) {
      final j = Jalali.fromDateTime(date);
      const months = [
        'فرو',
        'ارد',
        'خرد',
        'تیر',
        'مرد',
        'شهر',
        'مهر',
        'آبا',
        'آذر',
        'دی',
        'بهم',
        'اسف',
      ];
      return months[j.month - 1];
    } else {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return months[date.month - 1];
    }
  }

  /// تعداد روزهای ماه (برای ساخت گرید تقویم)
  int daysInMonth(int year, int month) {
    if (isJalali) {
      // 6 ماه اول: 31 روز
      if (month <= 6) return 31;
      // 5 ماه بعدی: 30 روز
      if (month <= 11) return 30;
      // اسفند: بستگی به کبیسه بودن داره
      return _isJalaliLeapYear(year) ? 30 : 29;
    } else {
      return DateTime(year, month + 1, 0).day;
    }
  }

  /// ✅ محاسبه سال کبیسه شمسی (بدون وابستگی به shamsi_date)
  bool _isJalaliLeapYear(int year) {
    // سال‌های کبیسه در چرخه 33 ساله:
    // 1, 5, 9, 13, 17, 22, 26, 30
    const leapYearsInCycle = [1, 5, 9, 13, 17, 22, 26, 30];
    final remainder = year % 33;
    return leapYearsInCycle.contains(remainder);
  }

  /// شماره روز هفته اول ماه (0=شنبه در شمسی، 0=دوشنبه در میلادی)
  int firstDayOfMonthWeekday(int year, int month) {
    if (isJalali) {
      final j = Jalali(year, month, 1);
      return j.weekDay - 1; // 0=شنبه
    } else {
      // برای میلادی معمولا از دوشنبه شروع می‌کنیم
      final d = DateTime(year, month, 1);
      return d.weekday - 1; // 0=Monday
    }
  }

  /// تبدیل فرمت تقویم فعلی به DateTime
  DateTime? parse(String dateStr) {
    if (isJalali) {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        try {
          final j = Jalali(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
          return j.toDateTime();
        } catch (e) {
          return null;
        }
      }
    }
    return DateTime.tryParse(dateStr);
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}
