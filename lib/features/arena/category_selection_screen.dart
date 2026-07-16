import 'package:flutter/material.dart';
import 'add_habit_screen.dart';

class CategorySelectionScreen extends StatelessWidget {
  const CategorySelectionScreen({super.key});

  final categories = const [
    {
      'name': 'ورزش و تناسب اندام',
      'icon': Icons.fitness_center,
      'color': 0xFF4A90E2,
      'habits': [
        {'name': 'تمرین ورزشی', 'icon': 'fitness_center', 'color': 0xFF4A90E2},
        {'name': 'دویدن', 'icon': 'directions_walk', 'color': 0xFF4A90E2},
        {'name': 'یوگا', 'icon': 'self_improvement', 'color': 0xFF9B59B6},
        {'name': 'شنا', 'icon': 'pool', 'color': 0xFF3498DB},
        {'name': 'پیاده‌روی', 'icon': 'directions_walk', 'color': 0xFF2ECC71},
      ],
    },
    {
      'name': 'سلامت و تندرستی',
      'icon': Icons.health_and_safety,
      'color': 0xFF2ECC71,
      'habits': [
        {'name': 'نوشیدن آب', 'icon': 'water_drop', 'color': 0xFF3498DB},
        {'name': 'مدیتیشن', 'icon': 'self_improvement', 'color': 0xFF9B59B6},
        {'name': 'خواب کافی', 'icon': 'bedtime', 'color': 0xFF5D6D7E},
        {'name': 'تنفس عمیق', 'icon': 'air', 'color': 0xFF1ABC9C},
        {
          'name': 'چکاپ سلامت',
          'icon': 'health_and_safety',
          'color': 0xFFE74C3C,
        },
      ],
    },
    {
      'name': 'مطالعه و یادگیری',
      'icon': Icons.book,
      'color': 0xFFF39C12,
      'habits': [
        {'name': 'مطالعه کتاب', 'icon': 'book', 'color': 0xFFF39C12},
        {'name': 'یادگیری زبان', 'icon': 'language', 'color': 0xFFE67E22},
        {'name': 'حل مسئله', 'icon': 'science', 'color': 0xFF9B59B6},
        {'name': 'یادداشت روزانه', 'icon': 'edit_note', 'color': 0xFF3498DB},
        {'name': 'مطالعه مقاله', 'icon': 'article', 'color': 0xFF1ABC9C},
      ],
    },
    {
      'name': 'تغذیه سالم',
      'icon': Icons.restaurant,
      'color': 0xFFE74C3C,
      'habits': [
        {
          'name': 'صبحانه سالم',
          'icon': 'breakfast_dining',
          'color': 0xFFF39C12,
        },
        {'name': 'غذای خانگی', 'icon': 'restaurant', 'color': 0xFFE74C3C},
        {'name': 'میوه و سبزیجات', 'icon': 'apple', 'color': 0xFF2ECC71},
        {'name': 'کاهش قند', 'icon': 'no_food', 'color': 0xFFE74C3C},
        {'name': 'آشپزی سالم', 'icon': 'kitchen', 'color': 0xFF3498DB},
      ],
    },
    {
      'name': 'بهره‌وری',
      'icon': Icons.timer,
      'color': 0xFF1ABC9C,
      'habits': [
        {
          'name': 'برنامه ریزی روزانه',
          'icon': 'calendar_today',
          'color': 0xFF3498DB,
        },
        {'name': 'مدیریت زمان', 'icon': 'timer', 'color': 0xFF1ABC9C},
        {'name': 'لیست کارها', 'icon': 'checklist', 'color': 0xFFF39C12},
        {'name': 'تمرکز عمیق', 'icon': 'tune', 'color': 0xFF9B59B6},
        {'name': 'اولویت بندی', 'icon': 'sort', 'color': 0xFFE74C3C},
      ],
    },
    {
      'name': 'رشد شخصی',
      'icon': Icons.emoji_events,
      'color': 0xFF9B59B6,
      'habits': [
        {'name': 'قدردانی', 'icon': 'favorite', 'color': 0xFFE74C3C},
        {
          'name': 'هدف‌گذاری',
          'icon': 'flag',
          'color': 0xFFF39C12,
        }, // تغییر از target به flag
        {'name': 'تفکر مثبت', 'icon': 'lightbulb', 'color': 0xFFF1C40F},
        {'name': 'مدیریت استرس', 'icon': 'spa', 'color': 0xFF2ECC71},
        {'name': 'مهارت جدید', 'icon': 'school', 'color': 0xFF3498DB},
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('انتخاب عادت جدید'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A2E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddHabitScreen()),
                );
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'ایجاد عادت جدید',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'دسته‌بندی‌های پیشنهادی',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return _buildCategoryCard(
                  context,
                  name: category['name'] as String,
                  icon: category['icon'] as IconData,
                  color: category['color'] as int,
                  habits: category['habits'] as List<Map<String, dynamic>>,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required String name,
    required IconData icon,
    required int color,
    required List<Map<String, dynamic>> habits,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Color(color).withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Color(color), size: 24),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: habits.map((habit) {
                return _buildHabitChip(
                  context,
                  name: habit['name'] as String,
                  iconName: habit['icon'] as String,
                  color: habit['color'] as int,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitChip(
    BuildContext context, {
    required String name,
    required String iconName,
    required int color,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddHabitScreen(
              preSelectedTitle: name,
              preSelectedIcon: iconName,
              preSelectedColor: color,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Color(color).withAlpha(15),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Color(color).withAlpha(50), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getIconData(iconName), color: Color(color), size: 20),
            const SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                color: Color(color),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
      case 'pool':
        return Icons.pool;
      case 'health_and_safety':
        return Icons.health_and_safety;
      case 'air':
        return Icons.air;
      case 'language':
        return Icons.language;
      case 'edit_note':
        return Icons.edit_note;
      case 'article':
        return Icons.article;
      case 'breakfast_dining':
        return Icons.breakfast_dining;
      case 'apple':
        return Icons.apple;
      case 'no_food':
        return Icons.no_food;
      case 'kitchen':
        return Icons.kitchen;
      case 'calendar_today':
        return Icons.calendar_today;
      case 'timer':
        return Icons.timer;
      case 'checklist':
        return Icons.checklist;
      case 'tune':
        return Icons.tune;
      case 'sort':
        return Icons.sort;
      case 'favorite':
        return Icons.favorite;
      case 'flag':
        return Icons.flag;
      case 'lightbulb':
        return Icons.lightbulb;
      case 'spa':
        return Icons.spa;
      case 'school':
        return Icons.school;
      default:
        return Icons.fitness_center;
    }
  }
}
