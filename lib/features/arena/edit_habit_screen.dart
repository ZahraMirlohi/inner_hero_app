import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/services/supabase_service.dart';
import '/features/arena/models/habit_model.dart';
import '/providers/theme_provider.dart';
import '/providers/sync_provider.dart';

class EditHabitScreen extends StatefulWidget {
  final Habit habit;

  const EditHabitScreen({super.key, required this.habit});

  @override
  State<EditHabitScreen> createState() => _EditHabitScreenState();
}

class _EditHabitScreenState extends State<EditHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late List<String> _subHabits;
  late List<String> _completedSubHabits;
  final _subHabitController = TextEditingController();

  late String _selectedIcon;
  late int _selectedIconColor;
  int _selectedBgColor = 0xFFB0CC5D;

  late String _frequencyType;
  late int _dailyIntervalDays;
  late List<int> _weeklyDays;
  late int _weeklyIntervalWeeks;
  late List<int> _monthlyDays;
  late int _monthlyIntervalMonths;

  late String _timeOfDay;
  late List<Reminder> _reminders;
  late String? _targetValue;
  late String? _fullDescription;
  late String? _halfDescription;
  late String? _basicDescription;

  late int _xpReward;
  bool _isLoading = false;

  final _supabase = SupabaseService();

  final List<String> _weekdayLetters = ['د', 'س', 'چ', 'پ', 'ج', 'ش', 'ی'];

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

  final List<Color> _cardColors = [
    const Color(0xFFFFF8E7),
    const Color(0xFFFFE0B2),
    const Color(0xFFFFCC80),
    const Color(0xFFFFAB91),
    const Color(0xFFB0CC5D),
    const Color(0xFF81D4FA),
    const Color(0xFFCE93D8),
    const Color(0xFFA5D6A7),
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.habit.title);
    _descriptionController = TextEditingController(
      text: widget.habit.description,
    );
    _subHabits = List.from(widget.habit.subHabits);
    _completedSubHabits = List.from(widget.habit.completedSubHabits);
    _selectedIcon = widget.habit.iconName;
    _selectedIconColor = widget.habit.iconColor;
    _selectedBgColor = widget.habit.backgroundColor;
    _frequencyType = widget.habit.frequencyType;
    _dailyIntervalDays = widget.habit.dailyIntervalDays?.first ?? 1;
    _weeklyDays = List.from(widget.habit.weeklyDays ?? []);
    _weeklyIntervalWeeks = widget.habit.weeklyIntervalWeeks ?? 1;
    _monthlyDays = List.from(widget.habit.monthlyDays ?? []);
    _monthlyIntervalMonths = widget.habit.monthlyIntervalMonths ?? 1;
    _timeOfDay = widget.habit.timeOfDay;
    _reminders = List.from(widget.habit.reminders);
    _xpReward = widget.habit.xpReward;
    _targetValue = widget.habit.targetValue;
    _fullDescription = widget.habit.fullDescription;
    _halfDescription = widget.habit.halfDescription;
    _basicDescription = widget.habit.basicDescription;
    _selectedBgColor = widget.habit.backgroundColor ?? 0xFFB0CC5D;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subHabitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final Color primaryColor = themeProvider.primaryColor;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('ویرایش عادت'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A2E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitleField(primaryColor),
              const SizedBox(height: 16),
              _buildDescriptionField(primaryColor),
              const SizedBox(height: 16),
              _buildLevelSettingsSection(primaryColor),
              const SizedBox(height: 24),
              _buildSubHabitsSection(primaryColor),
              const SizedBox(height: 24),
              _buildIconAndColorSection(primaryColor),
              const SizedBox(height: 24),
              _buildFrequencySection(primaryColor),
              const SizedBox(height: 24),
              _buildTimeSection(primaryColor),
              const SizedBox(height: 24),
              _buildRemindersSection(primaryColor),
              const SizedBox(height: 24),
              _buildXPSection(primaryColor),
              const SizedBox(height: 32),
              _buildSubmitButton(primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelSettingsSection(Color primaryColor) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎯 تنظیمات سطوح انجام عادت',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'این تنظیمات به کاربر کمک می‌کند بداند هر سطح به چه معناست',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _targetValue,
              decoration: InputDecoration(
                labelText: 'مقدار هدف (اختیاری)',
                hintText: 'مثال: ۳۰ دقیقه، ۲۰ صفحه، ۸ لیوان',
                border: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
              ),
              onChanged: (value) => _targetValue = value,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _fullDescription,
              decoration: InputDecoration(
                labelText: '🌟 توضیح سطح کامل',
                hintText: 'انجام کامل عادت',
                border: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
              ),
              onChanged: (value) => _fullDescription = value,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _halfDescription,
              decoration: InputDecoration(
                labelText: '⭐ توضیح سطح نیمه',
                hintText: 'انجام نیمی از عادت',
                border: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
              ),
              onChanged: (value) => _halfDescription = value,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _basicDescription,
              decoration: InputDecoration(
                labelText: '✨ توضیح سطح پایه',
                hintText: 'انجام حداقل عادت',
                border: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
              ),
              onChanged: (value) => _basicDescription = value,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubHabitsSection(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'زیرعادت‌ها (ریز عادت)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _subHabitController,
                decoration: InputDecoration(
                  hintText: 'مثلاً: ۱۰ دقیقه پیاده روی',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: primaryColor, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    setState(() {
                      _subHabits.add(value);
                      _subHabitController.clear();
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                if (_subHabitController.text.isNotEmpty) {
                  setState(() {
                    _subHabits.add(_subHabitController.text);
                    _subHabitController.clear();
                  });
                }
              },
              icon: const Icon(Icons.add),
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
        if (_subHabits.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_subHabits.length, (index) {
              final sh = _subHabits[index];
              return Chip(
                label: Text(sh),
                onDeleted: () {
                  setState(() {
                    _subHabits.removeAt(index);
                    _completedSubHabits.remove(sh);
                  });
                },
                deleteIcon: const Icon(Icons.close, size: 16),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildIconAndColorSection(Color primaryColor) {
    final List<Color> _bgColors = [
      const Color(0xFFFFF8E7),
      const Color(0xFFFFE0B2),
      const Color(0xFFFFCC80),
      const Color(0xFFFFAB91),
      const Color(0xFFB0CC5D),
      const Color(0xFF81D4FA),
      const Color(0xFFCE93D8),
      const Color(0xFFA5D6A7),
    ];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'آیکن و رنگ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            const Text('انتخاب آیکن:', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _icons.map((icon) {
                final isSelected = _selectedIcon == icon['name'];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIcon = icon['name'];
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primaryColor.withAlpha(25)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(
                              color: primaryColor,
                              width: 2,
                            )
                          : null,
                    ),
                    child: Icon(
                      icon['icon'],
                      color: isSelected ? const Color(0xFF090909) : Colors.grey,
                      size: 28,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('رنگ باکس عادت:', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _bgColors.map((color) {
                final isSelected = _selectedBgColor == color.value;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedBgColor = color.value;
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.black, width: 2)
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencySection(Color primaryColor) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                _buildFrequencyTab('روزانه', 'daily', primaryColor),
                _buildFrequencyTab('هفتگی', 'weekly', primaryColor),
                _buildFrequencyTab('ماهانه', 'monthly', primaryColor),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildFrequencyContent(primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencyTab(String title, String type, Color primaryColor) {
    final isSelected = _frequencyType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _frequencyType = type;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? primaryColor : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFrequencyContent(Color primaryColor) {
    if (_frequencyType == 'daily') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('هر '),
          Container(
            width: 70,
            height: 48,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: DropdownButton<int>(
                value: _dailyIntervalDays,
                underline: const SizedBox(),
                items: List.generate(30, (i) => i + 1).map((value) {
                  return DropdownMenuItem(
                    value: value,
                    child: Center(child: Text(value.toString())),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _dailyIntervalDays = value);
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Text(' روز'),
        ],
      );
    } else if (_frequencyType == 'weekly') {
      return Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(7, (index) {
              final isSelected = _weeklyDays.contains(index);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _weeklyDays.remove(index);
                    } else {
                      _weeklyDays.add(index);
                    }
                    _weeklyDays.sort();
                  });
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected ? primaryColor : Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _weekdayLetters[index],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('هر '),
              Container(
                width: 70,
                height: 48,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: DropdownButton<int>(
                    value: _weeklyIntervalWeeks,
                    underline: const SizedBox(),
                    items: List.generate(12, (i) => i + 1).map((value) {
                      return DropdownMenuItem(
                        value: value,
                        child: Center(child: Text(value.toString())),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _weeklyIntervalWeeks = value);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Text(' هفته'),
            ],
          ),
        ],
      );
    } else {
      return Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(31, (index) {
              final day = index + 1;
              final isSelected = _monthlyDays.contains(day);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _monthlyDays.remove(day);
                    } else {
                      _monthlyDays.add(day);
                    }
                    _monthlyDays.sort();
                  });
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected ? primaryColor : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      day.toString(),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('هر '),
              Container(
                width: 70,
                height: 48,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: DropdownButton<int>(
                    value: _monthlyIntervalMonths,
                    underline: const SizedBox(),
                    items: List.generate(12, (i) => i + 1).map((value) {
                      return DropdownMenuItem(
                        value: value,
                        child: Center(child: Text(value.toString())),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _monthlyIntervalMonths = value);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Text(' ماه'),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildTimeSection(Color primaryColor) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'زمان',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildTimeButton(
                    'صبح', 'morning', Icons.wb_sunny, primaryColor),
                const SizedBox(width: 12),
                _buildTimeButton('ظهر', 'noon', Icons.sunny, primaryColor),
                const SizedBox(width: 12),
                _buildTimeButton(
                    'بعدازظهر', 'afternoon', Icons.sunny_snowing, primaryColor),
                const SizedBox(width: 12),
                _buildTimeButton(
                    'شب', 'night', Icons.nightlight_round, primaryColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeButton(
      String label, String value, IconData icon, Color primaryColor) {
    final isSelected = _timeOfDay == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _timeOfDay = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRemindersSection(Color primaryColor) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'یادآور',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _addReminder,
              icon: const Icon(Icons.alarm_add, size: 18),
              label: const Text('افزودن یادآور'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor.withAlpha(25),
                foregroundColor: primaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_reminders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'هیچ یادآوری تنظیم نشده است',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ..._reminders.map(
                  (reminder) => _buildReminderItem(reminder, primaryColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderItem(Reminder reminder, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.alarm, color: primaryColor, size: 20),
          const SizedBox(width: 12),
          Text(
            reminder.getTimeString(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Switch(
            value: reminder.isEnabled,
            onChanged: (value) {
              setState(() {
                reminder.isEnabled = value;
              });
            },
            activeColor: primaryColor,
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
            onPressed: () {
              setState(() {
                _reminders.remove(reminder);
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _addReminder() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (selectedTime != null && mounted) {
      setState(() {
        _reminders.add(
          Reminder(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            hour: selectedTime.hour,
            minute: selectedTime.minute,
            isEnabled: true,
          ),
        );
      });
    }
  }

  Widget _buildTitleField(Color primaryColor) {
    return TextFormField(
      controller: _titleController,
      decoration: InputDecoration(
        labelText: 'عنوان عادت',
        hintText: 'مثال: ورزش روزانه',
        prefixIcon: Icon(Icons.title, color: primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) =>
          (value == null || value.isEmpty) ? 'لطفاً عنوان را وارد کنید' : null,
    );
  }

  Widget _buildDescriptionField(Color primaryColor) {
    return TextFormField(
      controller: _descriptionController,
      decoration: InputDecoration(
        labelText: 'توضیحات (اختیاری)',
        prefixIcon: Icon(Icons.description, color: primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      maxLines: 2,
    );
  }

  Widget _buildXPSection(Color primaryColor) {
    return Row(
      children: [
        const Text('امتیاز XP هر بار:'),
        const SizedBox(width: 16),
        Expanded(
          child: Slider(
            value: _xpReward.toDouble(),
            min: 5,
            max: 200,
            divisions: 9,
            activeColor: primaryColor,
            inactiveColor: Colors.grey.shade300,
            onChanged: (value) => setState(() => _xpReward = value.toInt()),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFA500).withAlpha(25),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$_xpReward XP',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFFFFA500),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(Color primaryColor) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _updateHabit,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        minimumSize: const Size(double.infinity, 50),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text(
              'ذخیره تغییرات',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }

  Future<void> _updateHabit() async {
    if (!_formKey.currentState!.validate()) return;

    final validCompletedSubHabits =
        _completedSubHabits.where((c) => _subHabits.contains(c)).toList();

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedHabit = Habit(
        id: widget.habit.id,
        userId: widget.habit.userId,
        title: _titleController.text,
        description: _descriptionController.text,
        subHabits: _subHabits,
        completedSubHabits: validCompletedSubHabits,
        iconName: _selectedIcon,
        iconColor: _selectedIconColor,
        backgroundColor: _selectedBgColor, // ✅ این باید ذخیره بشه
        frequencyType: _frequencyType,
        dailyIntervalDays:
            _frequencyType == 'daily' ? [_dailyIntervalDays] : null,
        weeklyDays: _frequencyType == 'weekly' ? _weeklyDays : null,
        weeklyIntervalWeeks:
            _frequencyType == 'weekly' ? _weeklyIntervalWeeks : 1,
        monthlyDays: _frequencyType == 'monthly' ? _monthlyDays : null,
        monthlyIntervalMonths:
            _frequencyType == 'monthly' ? _monthlyIntervalMonths : 1,
        timeOfDay: _timeOfDay,
        reminders: _reminders,
        xpReward: _xpReward,
        currentStreak: widget.habit.currentStreak,
        bestStreak: widget.habit.bestStreak,
        isActive: widget.habit.isActive,
        createdAt: widget.habit.createdAt,
        updatedAt: DateTime.now(),
        groupId: widget.habit.groupId,
        startDate: widget.habit.startDate,
        endDate: widget.habit.endDate,
        challengeId: widget.habit.challengeId,
        questId: widget.habit.questId,
        timerSetting: widget.habit.timerSetting,
        targetValue: _targetValue,
        fullDescription: _fullDescription,
        halfDescription: _halfDescription,
        basicDescription: _basicDescription,
      );

      // ✅ 1. آپدیت در Supabase
      await _supabase.updateHabit(updatedHabit);
      print('✅ Habit updated in Supabase');

      // ✅ 2. آپدیت در LocalStorage از طریق SyncProvider
      if (mounted) {
        try {
          final syncProvider =
              Provider.of<SyncProvider>(context, listen: false);

          // ✅ حذف عادت قدیمی و اضافه کردن عادت جدید
          final currentHabits = syncProvider.habits;
          final updatedHabits = currentHabits.map((h) {
            if (h.id == updatedHabit.id) {
              return updatedHabit;
            }
            return h;
          }).toList();

          await syncProvider.saveHabits(updatedHabits);
          print('✅ Habit updated in LocalStorage');
        } catch (e) {
          print('⚠️ Error updating LocalStorage: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('عادت با موفقیت ویرایش شد! ✅'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('❌ Error updating habit: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در ویرایش عادت: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
