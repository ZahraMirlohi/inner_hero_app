import 'package:flutter/material.dart';
import '../models/package_model.dart';
import '/services/supabase_service.dart';

class PackageDetailDialog extends StatefulWidget {
  final Package package;
  final bool isActive;

  const PackageDetailDialog({
    super.key,
    required this.package,
    required this.isActive,
  });

  @override
  State<PackageDetailDialog> createState() => _PackageDetailDialogState();
}

class _PackageDetailDialogState extends State<PackageDetailDialog> {
  bool _isLoading = false;
  final _supabase = SupabaseService();

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(widget.package.color);
    final bgColor = _parseColor(widget.package.backgroundColor);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // هدر
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _getIconData(widget.package.icon),
                    color: color,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.package.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      Text(
                        widget.package.category,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.stars, size: 14, color: color),
                      const SizedBox(width: 4),
                      Text(
                        '+${widget.package.xpReward} XP',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // توضیحات
            Text(
              widget.package.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // لیست عادت‌ها
            const Text(
              'عادت‌های این بسته:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),

            ...widget.package.habits
                .map(
                  (habit) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getIconData(habit.iconName),
                            color: color,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            habit.title,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getFrequencyText(habit.frequencyType),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // اطلاعات تکمیلی
            Row(
              children: [
                Icon(
                  Icons.fitness_center,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  '${widget.package.habits.length} عادت',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 16),
                Icon(Icons.category, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  _getCategoryText(widget.package.category),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 16),
                Icon(Icons.stars, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${widget.package.xpReward} XP',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // دکمه فعال/غیرفعال
            SizedBox(
              width: double.infinity,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : ElevatedButton(
                      onPressed: _togglePackage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isActive
                            ? Colors.red.shade100
                            : color,
                        foregroundColor: widget.isActive
                            ? Colors.red.shade700
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        widget.isActive
                            ? 'غیرفعال کردن بسته'
                            : 'فعال کردن بسته 🚀',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: widget.isActive
                              ? Colors.red.shade700
                              : Colors.white,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePackage() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final user = await _supabase.getCurrentUser();
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لطفاً وارد حساب کاربری خود شوید'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (widget.isActive) {
        await _supabase.deactivatePackage(user.id, widget.package.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('بسته "${widget.package.title}" غیرفعال شد'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        await _supabase.activatePackage(user.id, widget.package.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('بسته "${widget.package.title}" فعال شد! 🎉'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        // ریفرش صفحه توسط onChanged در PackageCard انجام میشه
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  String _getCategoryText(String category) {
    switch (category) {
      case 'health':
        return 'سلامت';
      case 'study':
        return 'مطالعه';
      case 'productivity':
        return 'بهره‌وری';
      case 'sport':
        return 'ورزش';
      case 'nutrition':
        return 'تغذیه';
      case 'personal':
        return 'رشد شخصی';
      default:
        return category;
    }
  }

  String _getFrequencyText(String frequencyType) {
    switch (frequencyType) {
      case 'daily':
        return 'روزانه';
      case 'weekly':
        return 'هفتگی';
      case 'monthly':
        return 'ماهانه';
      default:
        return frequencyType;
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
      case 'calendar_today':
        return Icons.calendar_today;
      case 'checklist':
        return Icons.checklist;
      case 'sort':
        return Icons.sort;
      case 'timer':
        return Icons.timer;
      case 'favorite':
        return Icons.favorite;
      case 'flag':
        return Icons.flag;
      case 'edit_note':
        return Icons.edit_note;
      case 'description':
        return Icons.description;
      case 'breakfast_dining':
        return Icons.breakfast_dining;
      case 'apple':
        return Icons.apple;
      case 'no_food':
        return Icons.no_food;
      default:
        return Icons.stars;
    }
  }
}
