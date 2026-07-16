import 'package:flutter/material.dart';
import '../models/package_model.dart';
import 'package_detail_dialog.dart';

class PackageCard extends StatelessWidget {
  final Package package;
  final bool isActive;
  final VoidCallback onChanged;

  const PackageCard({
    super.key,
    required this.package,
    required this.isActive,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(package.color);
    final bgColor = _parseColor(package.backgroundColor);

    return GestureDetector(
      onTap: () async {
        final result = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (context) =>
              PackageDetailDialog(package: package, isActive: isActive),
        );
        if (result == true) {
          onChanged();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? bgColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(24),
          border: isActive ? Border.all(color: color, width: 2) : null,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: color.withAlpha(40),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // هدر
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isActive ? color : Colors.grey.shade300,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getIconData(package.icon),
                    color: isActive ? Colors.white : Colors.grey.shade600,
                    size: 24,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white.withAlpha(76)
                          : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${package.habits.length} عادت',
                      style: TextStyle(
                        fontSize: 11,
                        color: isActive ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // محتوا
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(package.badge, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          package.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? const Color(0xFF1A1A2E)
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    package.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isActive
                          ? Colors.grey.shade700
                          : Colors.grey.shade500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // لیست عادت‌ها (حداکثر ۳ تا)
                  SizedBox(
                    height: 24,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: package.habits.length > 3
                          ? 3
                          : package.habits.length,
                      itemBuilder: (context, index) {
                        final habit = package.habits[index];
                        return Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? color.withAlpha(51)
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            habit.title,
                            style: TextStyle(
                              fontSize: 10,
                              color: isActive ? color : Colors.grey.shade600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // دکمه فعال/غیرفعال (اکنون فقط نمایشی است)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFFFFA500).withAlpha(25)
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.stars,
                              size: 14,
                              color: isActive
                                  ? const Color(0xFFFFA500)
                                  : Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '+${package.xpReward} XP',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isActive
                                    ? const Color(0xFFFFA500)
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isActive ? color : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isActive ? 'فعال ✅' : 'مشاهده جزئیات',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? Colors.white
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String colorStr) {
    try {
      if (colorStr.startsWith('#')) {
        return Color(int.parse('FF${colorStr.substring(1)}', radix: 16));
      }
      return const Color(0xFF4A90E2);
    } catch (e) {
      return const Color(0xFF4A90E2);
    }
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
      case 'psychology':
        return Icons.psychology;
      case 'attach_money':
        return Icons.attach_money;
      case 'favorite':
        return Icons.favorite;
      case 'forest':
        return Icons.forest;
      case 'whatshot':
        return Icons.whatshot;
      case 'diamond':
        return Icons.diamond;
      case 'beach_access':
        return Icons.beach_access;
      case 'flare':
        return Icons.flare;
      case 'edit_note':
        return Icons.edit_note;
      case 'description':
        return Icons.description;
      case 'calendar_today':
        return Icons.calendar_today;
      case 'checklist':
        return Icons.checklist;
      case 'sort':
        return Icons.sort;
      case 'timer':
        return Icons.timer;
      case 'breakfast_dining':
        return Icons.breakfast_dining;
      case 'apple':
        return Icons.apple;
      case 'no_food':
        return Icons.no_food;
      case 'flag':
        return Icons.flag;
      default:
        return Icons.stars;
    }
  }
}
