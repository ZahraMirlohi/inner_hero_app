// lib/features/arena/utils/habit_streaks.dart
//
// استریک واقعی یک عادت از روی تاریخچهٔ انجام‌ها. فقط روزهایی که عادت طبق
// برنامه‌اش باید انجام می‌شد شمرده می‌شوند (عادت هفتگی با روز نکردن استریک را نمی‌شکند).

import '../models/habit_completion.dart';
import '../models/habit_model.dart';

class HabitStreaks {
  final int current;
  final int best;
  const HabitStreaks(this.current, this.best);

  static HabitStreaks compute(Habit habit, List<HabitCompletion> completions,
      {DateTime? now}) {
    DateTime d(DateTime x) => DateTime(x.year, x.month, x.day);
    final today = d(now ?? DateTime.now());
    final done = {for (final c in completions) d(c.date)};
    if (done.isEmpty) return const HabitStreaks(0, 0);

    final first = done.reduce((a, b) => a.isBefore(b) ? a : b);
    var run = 0, best = 0;
    // مرور از اولین انجام تا امروز؛ روزهای غیربرنامه‌ای نادیده گرفته می‌شوند
    for (var day = first;
        !day.isAfter(today);
        day = DateTime(day.year, day.month, day.day + 1)) {
      final scheduled = habit.shouldDoOnDate(day) || done.contains(day);
      if (!scheduled) continue;
      if (done.contains(day)) {
        run++;
        if (run > best) best = run;
      } else if (day == today) {
        // امروز هنوز وقت دارد؛ استریک را نمی‌شکند
      } else {
        run = 0;
      }
    }
    return HabitStreaks(run, best);
  }
}
