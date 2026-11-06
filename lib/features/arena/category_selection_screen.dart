// lib/features/arena/category_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'add_habit_screen.dart';
import 'widgets/arena_form_widgets.dart';
import '/core/app_palette.dart';
import '/l10n/app_strings.dart';
import '/providers/theme_provider.dart';

class CategorySelectionScreen extends StatelessWidget {
  const CategorySelectionScreen({super.key});

  final categories = const [
    {
      'id': 'sport',
      'name': 'af.cat.sport',
      'icon': Icons.fitness_center_rounded,
      'color': 0xFF4A90E2,
      'tone': Tone.peach,
      'habits': [
        {'name': 'af.cat.sport.workout', 'icon': 'fitness_center', 'color': 0xFF4A90E2},
        {'name': 'af.cat.sport.run', 'icon': 'directions_walk', 'color': 0xFF4A90E2},
        {'name': 'af.cat.sport.yoga', 'icon': 'self_improvement', 'color': 0xFF9B59B6},
        {'name': 'af.cat.sport.swim', 'icon': 'pool', 'color': 0xFF3498DB},
        {'name': 'af.cat.sport.walk', 'icon': 'directions_walk', 'color': 0xFF2ECC71},
      ],
    },
    {
      'id': 'health',
      'name': 'af.cat.health',
      'icon': Icons.health_and_safety_rounded,
      'color': 0xFF2ECC71,
      'tone': Tone.sky,
      'habits': [
        {'name': 'af.cat.health.water', 'icon': 'water_drop', 'color': 0xFF3498DB},
        {'name': 'af.cat.health.meditate', 'icon': 'self_improvement', 'color': 0xFF9B59B6},
        {'name': 'af.cat.health.sleep', 'icon': 'bedtime', 'color': 0xFF5D6D7E},
        {'name': 'af.cat.health.breath', 'icon': 'air', 'color': 0xFF1ABC9C},
        {'name': 'af.cat.health.checkup', 'icon': 'health_and_safety', 'color': 0xFFE74C3C},
      ],
    },
    {
      'id': 'study',
      'name': 'af.cat.study',
      'icon': Icons.menu_book_rounded,
      'color': 0xFFF39C12,
      'tone': Tone.lilac,
      'habits': [
        {'name': 'af.cat.study.book', 'icon': 'book', 'color': 0xFFF39C12},
        {'name': 'af.cat.study.lang', 'icon': 'language', 'color': 0xFFE67E22},
        {'name': 'af.cat.study.solve', 'icon': 'science', 'color': 0xFF9B59B6},
        {'name': 'af.cat.study.journal', 'icon': 'edit_note', 'color': 0xFF3498DB},
        {'name': 'af.cat.study.article', 'icon': 'article', 'color': 0xFF1ABC9C},
      ],
    },
    {
      'id': 'food',
      'name': 'af.cat.food',
      'icon': Icons.restaurant_rounded,
      'color': 0xFFE74C3C,
      'tone': Tone.mint,
      'habits': [
        {'name': 'af.cat.food.breakfast', 'icon': 'breakfast_dining', 'color': 0xFFF39C12},
        {'name': 'af.cat.food.home', 'icon': 'restaurant', 'color': 0xFFE74C3C},
        {'name': 'af.cat.food.fruit', 'icon': 'apple', 'color': 0xFF2ECC71},
        {'name': 'af.cat.food.sugar', 'icon': 'no_food', 'color': 0xFFE74C3C},
        {'name': 'af.cat.food.cook', 'icon': 'kitchen', 'color': 0xFF3498DB},
      ],
    },
    {
      'id': 'prod',
      'name': 'af.cat.prod',
      'icon': Icons.timer_rounded,
      'color': 0xFF1ABC9C,
      'tone': Tone.butter,
      'habits': [
        {'name': 'af.cat.prod.plan', 'icon': 'calendar_today', 'color': 0xFF3498DB},
        {'name': 'af.cat.prod.time', 'icon': 'timer', 'color': 0xFF1ABC9C},
        {'name': 'af.cat.prod.todo', 'icon': 'checklist', 'color': 0xFFF39C12},
        {'name': 'af.cat.prod.focus', 'icon': 'tune', 'color': 0xFF9B59B6},
        {'name': 'af.cat.prod.priority', 'icon': 'sort', 'color': 0xFFE74C3C},
      ],
    },
    {
      'id': 'growth',
      'name': 'af.cat.growth',
      'icon': Icons.emoji_events_rounded,
      'color': 0xFF9B59B6,
      'tone': Tone.rose,
      'habits': [
        {'name': 'af.cat.growth.grateful', 'icon': 'favorite', 'color': 0xFFE74C3C},
        {'name': 'af.cat.growth.goal', 'icon': 'flag', 'color': 0xFFF39C12},
        {'name': 'af.cat.growth.positive', 'icon': 'lightbulb', 'color': 0xFFF1C40F},
        {'name': 'af.cat.growth.stress', 'icon': 'spa', 'color': 0xFF2ECC71},
        {'name': 'af.cat.growth.skill', 'icon': 'school', 'color': 0xFF3498DB},
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return ArenaFormPage(
      title: context.tr('af.cat.title'),
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddHabitScreen()),
            );
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: theme.effectivePrimary,
              borderRadius: BorderRadius.circular(30),
              boxShadow: theme.isDarkMode
                  ? null
                  : [
                      BoxShadow(
                        color: theme.effectivePrimary.withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 24, color: theme.onPrimaryColor),
                const SizedBox(width: 10),
                Text(
                  context.tr('af.cat.create'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: theme.onPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
          child: Text(
            context.tr('af.cat.suggested'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: theme.textColor,
            ),
          ),
        ),
        for (final category in categories)
          _buildCategoryCard(
            context,
            name: context.tr(category['name'] as String),
            icon: category['icon'] as IconData,
            tone: category['tone'] as Tone,
            habits: category['habits'] as List<Map<String, dynamic>>,
            theme: theme,
          ),
      ],
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required String name,
    required IconData icon,
    required Tone tone,
    required List<Map<String, dynamic>> habits,
    required ThemeProvider theme,
  }) {
    final toneColors = theme.tone(tone);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: toneColors.bg,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.isDarkMode
                      ? const Color(0xFF26262A)
                      : const Color(0xFF090909),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: theme.isDarkMode ? toneColors.fg : toneColors.bg,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: theme.textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final habit in habits)
                _buildHabitChip(
                  context,
                  name: context.tr(habit['name'] as String),
                  iconName: habit['icon'] as String,
                  color: habit['color'] as int,
                  theme: theme,
                ),
            ],
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
    required ThemeProvider theme,
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
        height: 38,
        padding: const EdgeInsetsDirectional.only(start: 12, end: 14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(19),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getIconData(iconName), color: theme.textColor, size: 16),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
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
        return Icons.fitness_center_rounded;
      case 'self_improvement':
        return Icons.self_improvement_rounded;
      case 'book':
        return Icons.menu_book_rounded;
      case 'science':
        return Icons.science_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'bedtime':
        return Icons.bedtime_rounded;
      case 'water_drop':
        return Icons.water_drop_rounded;
      case 'directions_walk':
        return Icons.directions_walk_rounded;
      case 'run_circle':
        return Icons.run_circle_rounded;
      case 'emoji_events':
        return Icons.emoji_events_rounded;
      case 'pool':
        return Icons.pool_rounded;
      case 'health_and_safety':
        return Icons.health_and_safety_rounded;
      case 'air':
        return Icons.air_rounded;
      case 'language':
        return Icons.language_rounded;
      case 'edit_note':
        return Icons.edit_note_rounded;
      case 'article':
        return Icons.article_rounded;
      case 'breakfast_dining':
        return Icons.breakfast_dining_rounded;
      case 'apple':
        return Icons.apple;
      case 'no_food':
        return Icons.no_food_rounded;
      case 'kitchen':
        return Icons.kitchen_rounded;
      case 'calendar_today':
        return Icons.calendar_today_rounded;
      case 'timer':
        return Icons.timer_rounded;
      case 'checklist':
        return Icons.checklist_rounded;
      case 'tune':
        return Icons.tune_rounded;
      case 'sort':
        return Icons.sort_rounded;
      case 'favorite':
        return Icons.favorite_rounded;
      case 'flag':
        return Icons.flag_rounded;
      case 'lightbulb':
        return Icons.lightbulb_rounded;
      case 'spa':
        return Icons.spa_rounded;
      case 'school':
        return Icons.school_rounded;
      default:
        return Icons.fitness_center_rounded;
    }
  }
}
