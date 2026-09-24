// lib/features/chat/widgets/create_challenge_sheet.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../models/challenge_invite.dart';
import '/providers/theme_provider.dart';

class CreateChallengeSheet extends StatefulWidget {
  final String buddyName;
  final String buddyId;
  final String userId;
  final String userName;
  final Function(ChallengeInvite) onSubmit;

  const CreateChallengeSheet({
    super.key,
    required this.buddyName,
    required this.buddyId,
    required this.userId,
    required this.userName,
    required this.onSubmit,
  });

  @override
  State<CreateChallengeSheet> createState() => _CreateChallengeSheetState();
}

class _CreateChallengeSheetState extends State<CreateChallengeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _habitTitleController = TextEditingController();
  final _habitDescController = TextEditingController();

  List<ChallengeHabit> _habits = [];
  int _duration = 7;
  int _xpReward = 100;
  DateTime _startDate = DateTime.now();

  String _selectedIcon = 'fitness_center';
  int _selectedIconColor = 0xFF4A90E2;
  int _selectedBgColor = 0xFFF5F5F5;

  final List<Map<String, dynamic>> _icons = [
    {'name': 'fitness_center', 'icon': Icons.fitness_center},
    {'name': 'self_improvement', 'icon': Icons.self_improvement},
    {'name': 'book', 'icon': Icons.book},
    {'name': 'science', 'icon': Icons.science},
    {'name': 'restaurant', 'icon': Icons.restaurant},
    {'name': 'bedtime', 'icon': Icons.bedtime},
    {'name': 'water_drop', 'icon': Icons.water_drop},
    {'name': 'directions_walk', 'icon': Icons.directions_walk},
    {'name': 'run_circle', 'icon': Icons.run_circle},
    {'name': 'emoji_events', 'icon': Icons.emoji_events},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _habitTitleController.dispose();
    _habitDescController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final primaryColor = theme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(20),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ==================== هدر ====================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.emoji_events,
                      color: primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'چالش جدید',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.textColor,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: theme.textSecondaryColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ارسال چالش برای ${widget.buddyName}',
            style: TextStyle(
              fontSize: 13,
              color: theme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 16),

          // ==================== فرم ====================
          Expanded(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // عنوان
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'عنوان چالش',
                        hintText: 'مثال: چالش ۷ روزه ورزش',
                        prefixIcon: Icon(Icons.title, color: primaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      validator: (value) => value?.isEmpty ?? true
                          ? 'لطفاً عنوان را وارد کنید'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // توضیحات
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'توضیحات (اختیاری)',
                        hintText: 'توضیحاتی درباره چالش...',
                        prefixIcon:
                            Icon(Icons.description, color: primaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // مدت زمان
                    _buildSliderRow(
                      label: 'مدت زمان:',
                      value: _duration.toDouble(),
                      min: 3,
                      max: 30,
                      divisions: 27,
                      displayText: '$_duration روز',
                      primaryColor: primaryColor,
                      theme: theme,
                      onChanged: (value) {
                        setState(() {
                          _duration = value.toInt();
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // پاداش XP
                    _buildSliderRow(
                      label: 'پاداش:',
                      value: _xpReward.toDouble(),
                      min: 50,
                      max: 500,
                      divisions: 45,
                      displayText: '$_xpReward XP',
                      primaryColor: primaryColor,
                      theme: theme,
                      onChanged: (value) {
                        setState(() {
                          _xpReward = value.toInt();
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // تاریخ شروع
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      tileColor: primaryColor.withValues(alpha: 0.06),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Icon(Icons.calendar_today, color: primaryColor),
                      title: Text(
                        'تاریخ شروع',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.textColor,
                        ),
                      ),
                      subtitle: Text(
                        _formatDate(_startDate),
                        style: TextStyle(
                          color: theme.textSecondaryColor,
                        ),
                      ),
                      onTap: _selectStartDate,
                    ),
                    const SizedBox(height: 16),

                    // عادت‌ها
                    Text(
                      'عادت‌های چالش (حداکثر ۵ عدد)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: theme.textColor,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // لیست عادت‌ها
                    if (_habits.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Column(
                          children: _habits.map((habit) {
                            return ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                _getIconData(habit.iconName),
                                color: primaryColor,
                                size: 20,
                              ),
                              title: Text(
                                habit.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.textColor,
                                ),
                              ),
                              subtitle: habit.description.isNotEmpty
                                  ? Text(
                                      habit.description,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.textSecondaryColor,
                                      ),
                                    )
                                  : null,
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _habits.remove(habit);
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                    const SizedBox(height: 8),

                    // اضافه کردن عادت جدید
                    if (_habits.length < 5)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.2),
                            style: BorderStyle.solid,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _habitTitleController,
                              decoration: InputDecoration(
                                hintText: 'عنوان عادت...',
                                hintStyle: TextStyle(
                                  color: theme.textSecondaryColor,
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                            TextField(
                              controller: _habitDescController,
                              decoration: InputDecoration(
                                hintText: 'توضیحات (اختیاری)...',
                                hintStyle: TextStyle(
                                  color: theme.textSecondaryColor,
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  'آیکون:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.textSecondaryColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ..._icons.take(6).map((icon) {
                                  final isSelected =
                                      _selectedIcon == icon['name'];
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedIcon = icon['name'];
                                      });
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 4),
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? primaryColor.withValues(
                                                alpha: 0.15)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        border: isSelected
                                            ? Border.all(
                                                color: primaryColor,
                                                width: 1.5,
                                              )
                                            : null,
                                      ),
                                      child: Icon(
                                        icon['icon'],
                                        color: isSelected
                                            ? primaryColor
                                            : Colors.grey,
                                        size: 18,
                                      ),
                                    ),
                                  );
                                }),
                                const Spacer(),
                                IconButton(
                                  onPressed: () => _addHabit(primaryColor),
                                  icon: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                  ),
                                  style: IconButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),

          // دکمه ارسال
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _submitChallenge(primaryColor),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'ارسال چالش 🚀',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayText,
    required Color primaryColor,
    required ThemeProvider theme,
    required Function(double) onChanged,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: theme.textColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: primaryColor,
            onChanged: onChanged,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            displayText,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  // ==================== متدها ====================

  void _addHabit(Color primaryColor) {
    final title = _habitTitleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('لطفاً عنوان عادت را وارد کنید'),
          backgroundColor: primaryColor,
        ),
      );
      return;
    }

    if (_habits.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('حداکثر ۵ عادت می‌توانید اضافه کنید'),
          backgroundColor: primaryColor,
        ),
      );
      return;
    }

    setState(() {
      _habits.add(
        ChallengeHabit(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          description: _habitDescController.text.trim(),
          iconName: _selectedIcon,
          iconColor: _selectedIconColor,
          backgroundColor: _selectedBgColor,
        ),
      );
      _habitTitleController.clear();
      _habitDescController.clear();
    });
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date != null) {
      setState(() {
        _startDate = date;
      });
    }
  }

  void _submitChallenge(Color primaryColor) {
    if (!_formKey.currentState!.validate()) return;
    if (_habits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('حداقل یک عادت برای چالش اضافه کنید'),
          backgroundColor: primaryColor,
        ),
      );
      return;
    }

    final challenge = ChallengeInvite(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      creatorId: widget.userId,
      creatorName: widget.userName,
      opponentId: widget.buddyId,
      opponentName: widget.buddyName,
      title: _titleController.text,
      description: _descriptionController.text,
      habits: _habits,
      duration: _duration,
      xpReward: _xpReward,
      startDate: _startDate,
      createdAt: DateTime.now(),
    );

    widget.onSubmit(challenge);
    Navigator.pop(context);
  }

  String _formatDate(DateTime date) {
    final jalali = Jalali.fromDateTime(date);
    return '${jalali.year}/${jalali.month}/${jalali.day}';
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
      default:
        return Icons.fitness_center;
    }
  }
}
