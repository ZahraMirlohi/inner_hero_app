// lib/features/chat/widgets/create_challenge_sheet.dart

import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../models/challenge_invite.dart';

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

  final List<Color> _iconColors = [
    const Color(0xFF4A90E2),
    const Color(0xFFE74C3C),
    const Color(0xFF2ECC71),
    const Color(0xFFF39C12),
    const Color(0xFF9B59B6),
    const Color(0xFF1ABC9C),
    const Color(0xFFE67E22),
    const Color(0xFF3498DB),
  ];

  final List<Color> _bgColors = [
    const Color(0xFFF5F5F5),
    const Color(0xFFE8F4FD),
    const Color(0xFFFDE8E8),
    const Color(0xFFE8FDE8),
    const Color(0xFFFDF5E8),
    const Color(0xFFF0E8FD),
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
    return Container(
      padding: const EdgeInsets.all(20),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // هدر
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.emoji_events,
                      color: Colors.orange,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'چالش جدید',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ارسال چالش برای ${widget.buddyName}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          // فرم
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
                        prefixIcon: const Icon(Icons.title),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                        prefixIcon: const Icon(Icons.description),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // مدت زمان
                    Row(
                      children: [
                        const Text(
                          'مدت زمان:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Slider(
                            value: _duration.toDouble(),
                            min: 3,
                            max: 30,
                            divisions: 27,
                            activeColor: Colors.orange,
                            onChanged: (value) {
                              setState(() {
                                _duration = value.toInt();
                              });
                            },
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$_duration روز',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // پاداش XP
                    Row(
                      children: [
                        const Text(
                          'پاداش:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Slider(
                            value: _xpReward.toDouble(),
                            min: 50,
                            max: 500,
                            divisions: 45,
                            activeColor: Colors.orange,
                            onChanged: (value) {
                              setState(() {
                                _xpReward = value.toInt();
                              });
                            },
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$_xpReward XP',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // تاریخ شروع
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('تاریخ شروع'),
                      subtitle: Text(_formatDate(_startDate)),
                      onTap: _selectStartDate,
                    ),
                    const SizedBox(height: 12),

                    // عادت‌ها
                    const Text(
                      'عادت‌های چالش (حداکثر ۵ عدد)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // لیست عادت‌ها
                    if (_habits.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: _habits.map((habit) {
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                _getIconData(habit.iconName),
                                color: Color(habit.iconColor),
                                size: 20,
                              ),
                              title: Text(
                                habit.title,
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: habit.description.isNotEmpty
                                  ? Text(
                                      habit.description,
                                      style: const TextStyle(fontSize: 12),
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
                            color: Colors.grey.shade300,
                            style: BorderStyle.solid,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _habitTitleController,
                              decoration: const InputDecoration(
                                hintText: 'عنوان عادت...',
                                border: InputBorder.none,
                              ),
                            ),
                            TextField(
                              controller: _habitDescController,
                              decoration: const InputDecoration(
                                hintText: 'توضیحات (اختیاری)...',
                                border: InputBorder.none,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text(
                                  'آیکون:',
                                  style: TextStyle(fontSize: 12),
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
                                            ? Color(
                                                _selectedIconColor,
                                              ).withValues(alpha: 0.2)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        border: isSelected
                                            ? Border.all(
                                                color: Color(
                                                  _selectedIconColor,
                                                ),
                                                width: 1.5,
                                              )
                                            : null,
                                      ),
                                      child: Icon(
                                        icon['icon'],
                                        color: isSelected
                                            ? Color(_selectedIconColor)
                                            : Colors.grey,
                                        size: 18,
                                      ),
                                    ),
                                  );
                                }),
                                const Spacer(),
                                IconButton(
                                  onPressed: _addHabit,
                                  icon: const Icon(Icons.add),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
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
              onPressed: _submitChallenge,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'ارسال چالش 🚀',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== متدها ====================

  void _addHabit() {
    final title = _habitTitleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لطفاً عنوان عادت را وارد کنید'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_habits.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حداکثر ۵ عادت می‌توانید اضافه کنید'),
          backgroundColor: Colors.orange,
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

  // lib/features/chat/widgets/create_challenge_sheet.dart

  void _submitChallenge() {
    if (!_formKey.currentState!.validate()) return;
    if (_habits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حداقل یک عادت برای چالش اضافه کنید'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final challenge = ChallengeInvite(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      creatorId: widget.userId,
      creatorName: widget.userName, // ✅ نام فرستنده (خود کاربر)
      opponentId: widget.buddyId,
      opponentName: widget.buddyName, // ✅ نام گیرنده (هم‌مسیر)
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
