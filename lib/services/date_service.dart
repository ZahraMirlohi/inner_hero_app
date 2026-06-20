import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamsi_date/shamsi_date.dart';

class DateService {
  static const String _calendarTypeKey = 'calendar_type';

  static Future<void> saveCalendarType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_calendarTypeKey, type);
  }

  static Future<String> getCalendarType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_calendarTypeKey) ?? 'jalali';
  }

  // تبدیل تاریخ میلادی به نمایش مناسب
  static Future<String> formatDate(DateTime date) async {
    final calendarType = await getCalendarType();

    if (calendarType == 'jalali') {
      final jalali = Jalali.fromDateTime(date);
      return '${jalali.year}/${_twoDigits(jalali.month)}/${_twoDigits(jalali.day)}';
    } else {
      return '${date.year}/${_twoDigits(date.month)}/${_twoDigits(date.day)}';
    }
  }

  // فرمت با نام ماه
  static Future<String> formatDateWithMonthName(DateTime date) async {
    final calendarType = await getCalendarType();

    if (calendarType == 'jalali') {
      final jalali = Jalali.fromDateTime(date);
      final monthNames = [
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
      return '${jalali.day} ${monthNames[jalali.month - 1]} ${jalali.year}';
    } else {
      final monthNames = [
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
      return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
    }
  }

  // برای نمایش در لیست Today (امروز، دیروز و ...)
  static Future<String> getRelativeDate(DateTime date) async {
    final now = DateTime.now();
    final calendarType = await getCalendarType();

    if (calendarType == 'jalali') {
      final todayJalali = Jalali.fromDateTime(now);
      final targetJalali = Jalali.fromDateTime(date);

      if (targetJalali.year == todayJalali.year &&
          targetJalali.month == todayJalali.month &&
          targetJalali.day == todayJalali.day) {
        return 'امروز';
      }

      // محاسبه دیروز به صورت دستی
      final yesterdayJalali = _getYesterdayJalali(todayJalali);
      if (targetJalali.year == yesterdayJalali.year &&
          targetJalali.month == yesterdayJalali.month &&
          targetJalali.day == yesterdayJalali.day) {
        return 'دیروز';
      }
    } else {
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        return 'Today';
      }

      final yesterday = now.subtract(const Duration(days: 1));
      if (date.year == yesterday.year &&
          date.month == yesterday.month &&
          date.day == yesterday.day) {
        return 'Yesterday';
      }
    }

    return await formatDate(date);
  }

  // محاسبه دیروز به صورت شمسی
  static Jalali _getYesterdayJalali(Jalali today) {
    if (today.day > 1) {
      return Jalali(today.year, today.month, today.day - 1);
    } else if (today.month > 1) {
      int prevMonth = today.month - 1;
      int daysInPrevMonth = _getDaysInMonth(today.year, prevMonth);
      return Jalali(today.year, prevMonth, daysInPrevMonth);
    } else {
      return Jalali(today.year - 1, 12, 29);
    }
  }

  // گرفتن تعداد روزهای یک ماه شمسی
  static int _getDaysInMonth(int year, int month) {
    if (month <= 6) return 31;
    if (month <= 11) return 30;
    // اسفند
    final date = Jalali(year, month, 1);
    return (date.isLeapYear == true) ? 30 : 29;
  }

  // تبدیل تاریخ از رشته به DateTime
  static DateTime? parseDateString(String dateStr, {bool isJalali = true}) {
    if (isJalali) {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final jalali = Jalali(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        return jalali.toDateTime();
      }
    } else {
      return DateTime.tryParse(dateStr);
    }
    return null;
  }

  // گرفتن تاریخ امروز
  static Future<DateTime> getToday() async {
    return DateTime.now();
  }

  // بررسی اینکه آیا تاریخ امروز است
  static Future<bool> isToday(DateTime date) async {
    final now = DateTime.now();
    final calendarType = await getCalendarType();

    if (calendarType == 'jalali') {
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

  static String _twoDigits(int n) {
    return n.toString().padLeft(2, '0');
  }
}
