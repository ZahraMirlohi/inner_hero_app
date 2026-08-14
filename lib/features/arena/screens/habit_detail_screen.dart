// lib/features/arena/screens/habit_detail_screen.dart

import 'package:flutter/material.dart';
import '/features/arena/models/habit_model.dart';
import '/services/supabase_service.dart';
import '/features/arena/models/habit_completion.dart';
import '/features/arena/widgets/habit_chart_widget.dart'; // ✅ اضافه کردن import نمودار

class HabitDetailScreen extends StatelessWidget {
  final Habit habit;
  final SupabaseService _supabase = SupabaseService();

  HabitDetailScreen({super.key, required this.habit});

  // ==================== متدهای کمکی ====================

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

  bool _hasLevelSettings() {
    return (habit.fullDescription != null &&
            habit.fullDescription!.isNotEmpty) ||
        (habit.halfDescription != null && habit.halfDescription!.isNotEmpty) ||
        (habit.basicDescription != null && habit.basicDescription!.isNotEmpty);
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(habit.title),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A2E),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // ریفرش صفحه
              (context as Element).reassemble();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================== ۱. کارت اصلی ====================
            _buildMainCard(),
            const SizedBox(height: 20),

            // ==================== ۲. زیرعادت‌ها ====================
            if (habit.subHabits.isNotEmpty) _buildSubHabitsCard(),
            if (habit.subHabits.isNotEmpty) const SizedBox(height: 20),

            // ==================== ۳. تنظیمات سطوح ====================
            if (_hasLevelSettings()) _buildLevelSettingsCard(),
            if (_hasLevelSettings()) const SizedBox(height: 20),

            // ==================== ۴. ✅ نمودار پیشرفت ====================
            _buildChartSection(),

            // ==================== ۵. تاریخچه ۳۰ روز اخیر ====================
            _buildLevelHistorySection(),

            // ==================== ۶. یادآورها ====================
            if (habit.reminders.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildRemindersCard(),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== کارت اصلی ====================

  Widget _buildMainCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
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
            if (habit.targetValue != null && habit.targetValue!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildDetailRow(
                Icons.flag,
                'مقدار هدف',
                habit.targetValue!,
              ),
            ],
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

  // ==================== زیرعادت‌ها ====================

  Widget _buildSubHabitsCard() {
    return Card(
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
    );
  }

  // ==================== تنظیمات سطوح ====================

  Widget _buildLevelSettingsCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🎯 سطوح انجام عادت',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (habit.fullDescription != null &&
                habit.fullDescription!.isNotEmpty)
              _buildLevelRow('🌟 کامل', habit.fullDescription!),
            if (habit.halfDescription != null &&
                habit.halfDescription!.isNotEmpty)
              _buildLevelRow('⭐ نیمه', habit.halfDescription!),
            if (habit.basicDescription != null &&
                habit.basicDescription!.isNotEmpty)
              _buildLevelRow('✨ پایه', habit.basicDescription!),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelRow(String label, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ✅ نمودار پیشرفت ====================

  Widget _buildChartSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _supabase.getHabitChartData(
        habitId: habit.id,
        userId: habit.userId,
        // ✅ حذف پارامتر days - خود متد محاسبه می‌کند
      ),
      builder: (context, snapshot) {
        // ✅ حالت بارگذاری
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 250,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(height: 12),
                  Text('در حال بارگذاری نمودار...'),
                ],
              ),
            ),
          );
        }

        // ✅ حالت خطا
        if (snapshot.hasError) {
          print('❌ Error loading chart data: ${snapshot.error}');
          return const SizedBox.shrink();
        }

        // ✅ حالت بدون داده
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.show_chart, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'هنوز داده‌ای برای نمایش وجود ندارد',
                    style: TextStyle(color: Colors.grey),
                  ),
                  Text(
                    'با انجام عادت و انتخاب سطح، نمودار ساخته می‌شود',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        // ✅ نمایش نمودار
        return Padding(
          padding: const EdgeInsets.only(top: 0),
          child: HabitChartWidget(
            data: snapshot.data!,
            habitTitle: habit.title,
            targetValue: habit.targetValue,
          ),
        );
      },
    );
  }

  // ==================== تاریخچه سطح‌دار ====================

  Widget _buildLevelHistorySection() {
    return FutureBuilder<List<HabitCompletion>>(
      future: _supabase.getHabitCompletionsWithLevel(
        habitId: habit.id,
        userId: habit.userId,
        startDate: DateTime.now().subtract(const Duration(days: 30)),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final completions = snapshot.data!;

        return Column(
          children: [
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
                      '📊 تاریخچه ۳۰ روز اخیر',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: completions.take(30).map((completion) {
                        return Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: completion.level.color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Text(
                              completion.level.emoji,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    _buildLegend(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(CompletionLevel.full),
        const SizedBox(width: 12),
        _buildLegendItem(CompletionLevel.half),
        const SizedBox(width: 12),
        _buildLegendItem(CompletionLevel.basic),
      ],
    );
  }

  Widget _buildLegendItem(CompletionLevel level) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: level.color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${level.emoji} ${level.displayName}',
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }

  // ==================== یادآورها ====================

  Widget _buildRemindersCard() {
    return Card(
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
                      color: reminder.isEnabled ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
