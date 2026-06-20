import 'package:flutter/material.dart';
import '/features/arena/models/habit_model.dart';

class HabitDetailScreen extends StatelessWidget {
  final Habit habit;
  const HabitDetailScreen({super.key, required this.habit});

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'fitness_center':
        return Icons.fitness_center;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'book':
        return Icons.book;
      case 'science':
        return Icons.science;
      case 'restaurant':
        return Icons.restaurant;
      case 'bedtime':
        return Icons.bedtime;
      case 'water_drop':
        return Icons.water_drop;
      case 'directions_walk':
        return Icons.directions_walk;
      case 'run_circle':
        return Icons.run_circle;
      case 'emoji_events':
        return Icons.emoji_events;
      default:
        return Icons.fitness_center;
    }
  }

  String _getTimeOfDayText(String timeOfDay) {
    switch (timeOfDay) {
      case 'morning':
        return 'صبح';
      case 'noon':
        return 'ظهر';
      case 'afternoon':
        return 'بعدازظهر';
      case 'night':
        return 'شب';
      default:
        return 'صبح';
    }
  }

  String _getFrequencyText(Habit habit) {
    switch (habit.frequencyType) {
      case 'daily':
        if (habit.dailyIntervalDays != null &&
            habit.dailyIntervalDays!.isNotEmpty) {
          return 'هر ${habit.dailyIntervalDays!.first} روز';
        }
        return 'روزانه';
      case 'weekly':
        final weekdays = [
          'دوشنبه',
          'سه‌شنبه',
          'چهارشنبه',
          'پنج‌شنبه',
          'جمعه',
          'شنبه',
          'یک‌شنبه',
        ];
        if (habit.weeklyDays != null && habit.weeklyDays!.isNotEmpty) {
          final days = habit.weeklyDays!.map((d) => weekdays[d]).join('، ');
          return 'هر هفته $days';
        }
        return 'هفتگی';
      case 'monthly':
        if (habit.monthlyDays != null && habit.monthlyDays!.isNotEmpty) {
          return 'روزهای ${habit.monthlyDays!.join("، ")} هر ماه';
        }
        return 'ماهانه';
      default:
        return 'روزانه';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(habit.title),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A2E),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // کارت اصلی
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // آیکن و عنوان
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Color(habit.backgroundColor).withAlpha(255),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            _getIconData(habit.iconName),
                            color: Color(habit.iconColor),
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                habit.title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A2E),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                habit.description.isEmpty
                                    ? 'توضیحاتی وارد نشده'
                                    : habit.description,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),

                    // جزئیات
                    _buildDetailRow(
                      Icons.repeat,
                      'زمانبندی',
                      _getFrequencyText(habit),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.access_time,
                      'زمان',
                      _getTimeOfDayText(habit.timeOfDay),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.stars,
                      'امتیاز',
                      '${habit.xpReward} XP به ازای هر بار',
                    ),

                    if (habit.reminders.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.alarm,
                        'یادآورها',
                        '${habit.reminders.length} یادآور',
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // زیرعادت‌ها
            if (habit.subHabits.isNotEmpty) ...[
              const SizedBox(height: 20),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'زیرعادت‌ها',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...habit.subHabits.map(
                        (sh) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                size: 20,
                                color: Color(0xFF4A90E2),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(sh)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // یادآورها
            if (habit.reminders.isNotEmpty) ...[
              const SizedBox(height: 20),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'یادآورها',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...habit.reminders.map(
                        (reminder) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.alarm,
                                size: 20,
                                color: Color(0xFF4A90E2),
                              ),
                              const SizedBox(width: 12),
                              Text(reminder.getTimeString()),
                              const Spacer(),
                              Icon(
                                reminder.isEnabled
                                    ? Icons.notifications_active
                                    : Icons.notifications_off,
                                color: reminder.isEnabled
                                    ? Colors.green
                                    : Colors.grey,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF4A90E2).withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF4A90E2), size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
