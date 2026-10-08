// lib/features/arena/screens/add_habit_screen.dart

import 'package:flutter/material.dart';
import 'package:inner_hero_app/providers/sync_provider.dart';
import 'package:provider/provider.dart';
import '/services/supabase_service.dart';
import '/features/arena/models/habit_model.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'category_selection_screen.dart';
import '/providers/theme_provider.dart';
import '/providers/calendar_provider.dart';

class AddHabitScreen extends StatefulWidget {
  final String? preSelectedTitle;
  final String? preSelectedIcon;
  final int? preSelectedColor;

  const AddHabitScreen({
    super.key,
    this.preSelectedTitle,
    this.preSelectedIcon,
    this.preSelectedColor,
  });

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<String> _subHabits = [];
  final _subHabitController = TextEditingController();

  String _selectedIcon = 'fitness_center';
  int _selectedIconColor = 0xFF4A90E2;
  int _selectedBgColor = 0xFFB0CC5D;

  String _frequencyType = 'daily';
  int _dailyIntervalDays = 1;
  List<int> _weeklyDays = [];
  int _weeklyIntervalWeeks = 1;
  List<int> _monthlyDays = [];
  int _monthlyIntervalMonths = 1;

  String _timeOfDay = 'morning';
  List<Reminder> _reminders = [];

  DateTime? _startDate;
  int _xpReward = 10;
  bool _isLoading = false;

  String? _targetValue;
  String? _fullDescription;
  String? _halfDescription;
  String? _basicDescription;

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

  final _supabase = SupabaseService();

  @override
  void initState() {
    super.initState();
    if (widget.preSelectedTitle != null) {
      _titleController.text = widget.preSelectedTitle!;
    }
    if (widget.preSelectedIcon != null) {
      _selectedIcon = widget.preSelectedIcon!;
    }
    if (widget.preSelectedColor != null) {
      _selectedIconColor = widget.preSelectedColor!;
      _selectedBgColor = 0xFFB0CC5D;
    }

    _targetValue = null;
    _fullDescription = 'انجام کامل عادت';
    _halfDescription = 'انجام نیمی از عادت';
    _basicDescription = 'انجام حداقل عادت';
  }

  Future<void> _selectStartDate() async {
    final calendar = Provider.of<CalendarProvider>(context, listen: false);

    if (calendar.isJalali) {
      _showJalaliDatePickerForHabit(calendar);
    } else {
      _showGregorianDatePickerForHabit();
    }
  }

  void _showGregorianDatePickerForHabit() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null && mounted) {
      setState(() {
        _startDate = date;
      });
    }
  }

  void _showJalaliDatePickerForHabit(CalendarProvider calendar) {
    final now =
        _startDate != null ? Jalali.fromDateTime(_startDate!) : Jalali.now();
    int selectedYear = now.year;
    int selectedMonth = now.month;
    int selectedDay = now.day;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            int daysInMonth = calendar.daysInMonth(
              selectedYear,
              selectedMonth,
            );
            if (selectedDay > daysInMonth) {
              selectedDay = daysInMonth;
            }

            return AlertDialog(
              title: const Text('تاریخ شروع عادت'),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: selectedYear,
                            decoration: const InputDecoration(
                              labelText: 'سال',
                              border: OutlineInputBorder(),
                            ),
                            items: List.generate(10, (i) {
                              final year = Jalali.now().year - 2 + i;
                              return DropdownMenuItem(
                                value: year,
                                child: Text(year.toString()),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setStateDialog(() => selectedYear = value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: selectedMonth,
                            decoration: const InputDecoration(
                              labelText: 'ماه',
                              border: OutlineInputBorder(),
                            ),
                            items: List.generate(12, (i) {
                              final month = i + 1;
                              return DropdownMenuItem(
                                value: month,
                                child: Text(
                                  calendar
                                      .formatWithMonthName(
                                        Jalali(selectedYear, month, 1)
                                            .toDateTime(),
                                      )
                                      .split(' ')
                                      .first,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setStateDialog(() => selectedMonth = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value:
                          selectedDay > daysInMonth ? daysInMonth : selectedDay,
                      decoration: const InputDecoration(
                        labelText: 'روز',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(daysInMonth, (i) {
                        final day = i + 1;
                        return DropdownMenuItem(
                          value: day,
                          child: Text(day.toString()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setStateDialog(() => selectedDay = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('انصراف'),
                ),
                ElevatedButton(
                  onPressed: () {
                    try {
                      final jalaliDate = Jalali(
                        selectedYear,
                        selectedMonth,
                        selectedDay,
                      );
                      setState(() {
                        _startDate = jalaliDate.toDateTime();
                      });
                      Navigator.pop(context);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تاریخ وارد شده معتبر نیست'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text('انتخاب'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getDisplayStartDate(CalendarProvider calendar) {
    if (_startDate == null) return 'انتخاب کنید (اختیاری)';
    return calendar.formatShort(_startDate!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final calendar = Provider.of<CalendarProvider>(context);
    final Color primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: const Text('عادت جدید'),
        backgroundColor: theme.surfaceColor,
        elevation: 0,
        foregroundColor: theme.textColor,
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
              _buildTitleField(primaryColor, theme),
              const SizedBox(height: 16),
              _buildDescriptionField(primaryColor, theme),
              const SizedBox(height: 16),
              _buildLevelSettingsSection(primaryColor, theme),
              const SizedBox(height: 32),
              _buildSubHabitsSection(primaryColor, theme),
              const SizedBox(height: 24),
              _buildIconAndColorSection(primaryColor, theme),
              const SizedBox(height: 24),
              _buildFrequencySection(primaryColor, theme),
              const SizedBox(height: 24),
              _buildTimeSection(primaryColor, theme),
              const SizedBox(height: 24),
              _buildStartDateSection(primaryColor, calendar, theme),
              const SizedBox(height: 24),
              _buildRemindersSection(primaryColor, theme),
              const SizedBox(height: 24),
              _buildXPSection(primaryColor, theme),
              const SizedBox(height: 24),
              _buildSubmitButton(primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelSettingsSection(Color primaryColor, ThemeProvider theme) {
    return Card(
      color: theme.cardColor,
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
            Text(
              'این تنظیمات به کاربر کمک می‌کند بداند هر سطح به چه معناست',
              style: TextStyle(fontSize: 12, color: theme.textSecondaryColor),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              initialValue: _targetValue,
              labelText: 'مقدار هدف (اختیاری)',
              hintText: 'مثال: ۳۰ دقیقه، ۲۰ صفحه، ۸ لیوان',
              primaryColor: primaryColor,
              theme: theme,
              onChanged: (value) => _targetValue = value,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              initialValue: _fullDescription,
              labelText: '🌟 توضیح سطح کامل',
              hintText: 'انجام کامل عادت',
              primaryColor: primaryColor,
              theme: theme,
              onChanged: (value) => _fullDescription = value,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              initialValue: _halfDescription,
              labelText: '⭐ توضیح سطح نیمه',
              hintText: 'انجام نیمی از عادت',
              primaryColor: primaryColor,
              theme: theme,
              onChanged: (value) => _halfDescription = value,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              initialValue: _basicDescription,
              labelText: '✨ توضیح سطح پایه',
              hintText: 'انجام حداقل عادت',
              primaryColor: primaryColor,
              theme: theme,
              onChanged: (value) => _basicDescription = value,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String? initialValue,
    required String labelText,
    required String hintText,
    required Color primaryColor,
    required ThemeProvider theme,
    required Function(String) onChanged,
  }) {
    return TextFormField(
      initialValue: initialValue,
      style: TextStyle(color: theme.textColor),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        labelStyle: TextStyle(color: theme.textSecondaryColor),
        hintStyle: TextStyle(color: theme.textSecondaryColor),
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: theme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: theme.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildStartDateSection(
    Color primaryColor,
    CalendarProvider calendar,
    ThemeProvider theme,
  ) {
    return Card(
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryColor.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.calendar_today, color: primaryColor, size: 20),
        ),
        title: Text(
          'تاریخ شروع (اختیاری)',
          style: TextStyle(color: theme.textColor),
        ),
        subtitle: Text(
          _getDisplayStartDate(calendar),
          style: TextStyle(
            color:
                _startDate != null ? theme.textColor : theme.textSecondaryColor,
          ),
        ),
        onTap: _selectStartDate,
      ),
    );
  }

  Widget _buildIconAndColorSection(Color primaryColor, ThemeProvider theme) {
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
      color: theme.cardColor,
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
            Text('انتخاب آیکن:',
                style: TextStyle(fontSize: 14, color: theme.textColor)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _icons.map((icon) {
                final isSelected = _selectedIcon == icon['name'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = icon['name']),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primaryColor.withAlpha(30)
                          : (theme.isDarkMode
                              ? const Color(0xFF2A2A2A)
                              : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: primaryColor, width: 2)
                          : null,
                    ),
                    child: Icon(
                      icon['icon'],
                      color: isSelected
                          ? (theme.isDarkMode
                              ? Colors.white
                              : const Color(0xFF090909))
                          : theme.textSecondaryColor,
                      size: 28,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('رنگ باکس عادت:',
                style: TextStyle(fontSize: 14, color: theme.textColor)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _bgColors.map((color) {
                final isSelected = _selectedBgColor == color.value;
                return GestureDetector(
                  onTap: () => setState(() => _selectedBgColor = color.value),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: theme.textColor, width: 2)
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

  Widget _buildFrequencySection(Color primaryColor, ThemeProvider theme) {
    return Card(
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.isDarkMode
                  ? const Color(0xFF2A2A2A)
                  : Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                _buildFrequencyTab('روزانه', 'daily', primaryColor, theme),
                _buildFrequencyTab('هفتگی', 'weekly', primaryColor, theme),
                _buildFrequencyTab('ماهانه', 'monthly', primaryColor, theme),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildFrequencyContent(primaryColor, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencyTab(
      String title, String type, Color primaryColor, ThemeProvider theme) {
    final isSelected = _frequencyType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _frequencyType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? theme.cardColor : Colors.transparent,
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
              color: isSelected ? primaryColor : theme.textSecondaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFrequencyContent(Color primaryColor, ThemeProvider theme) {
    switch (_frequencyType) {
      case 'daily':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('هر ', style: TextStyle(color: theme.textColor)),
            Container(
              width: 70,
              height: 48,
              decoration: BoxDecoration(
                border: Border.all(color: theme.borderColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: DropdownButton<int>(
                  value: _dailyIntervalDays,
                  underline: const SizedBox(),
                  dropdownColor: theme.cardColor,
                  style: TextStyle(color: theme.textColor),
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
            Text(' روز', style: TextStyle(color: theme.textColor)),
          ],
        );

      case 'weekly':
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
                      color: isSelected
                          ? primaryColor
                          : (theme.isDarkMode
                              ? const Color(0xFF2A2A2A)
                              : Colors.grey.shade200),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _weekdayLetters[index],
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : theme.textSecondaryColor,
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
                Text('هر ', style: TextStyle(color: theme.textColor)),
                Container(
                  width: 70,
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.borderColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: DropdownButton<int>(
                      value: _weeklyIntervalWeeks,
                      underline: const SizedBox(),
                      dropdownColor: theme.cardColor,
                      style: TextStyle(color: theme.textColor),
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
                Text(' هفته', style: TextStyle(color: theme.textColor)),
              ],
            ),
          ],
        );

      case 'monthly':
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
                      color: isSelected
                          ? primaryColor
                          : (theme.isDarkMode
                              ? const Color(0xFF2A2A2A)
                              : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        day.toString(),
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : theme.textSecondaryColor,
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
                Text('هر ', style: TextStyle(color: theme.textColor)),
                Container(
                  width: 70,
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.borderColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: DropdownButton<int>(
                      value: _monthlyIntervalMonths,
                      underline: const SizedBox(),
                      dropdownColor: theme.cardColor,
                      style: TextStyle(color: theme.textColor),
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
                Text(' ماه', style: TextStyle(color: theme.textColor)),
              ],
            ),
          ],
        );

      default:
        return const SizedBox();
    }
  }

  Widget _buildTimeSection(Color primaryColor, ThemeProvider theme) {
    return Card(
      color: theme.cardColor,
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
                    'صبح', 'morning', Icons.wb_sunny, primaryColor, theme),
                const SizedBox(width: 12),
                _buildTimeButton(
                    'ظهر', 'noon', Icons.sunny, primaryColor, theme),
                const SizedBox(width: 12),
                _buildTimeButton('بعدازظهر', 'afternoon', Icons.sunny_snowing,
                    primaryColor, theme),
                const SizedBox(width: 12),
                _buildTimeButton(
                    'شب', 'night', Icons.nightlight_round, primaryColor, theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeButton(String label, String value, IconData icon,
      Color primaryColor, ThemeProvider theme) {
    final isSelected = _timeOfDay == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _timeOfDay = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor
                : (theme.isDarkMode
                    ? const Color(0xFF2A2A2A)
                    : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : theme.textSecondaryColor,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : theme.textSecondaryColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRemindersSection(Color primaryColor, ThemeProvider theme) {
    return Card(
      color: theme.cardColor,
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'هیچ یادآوری تنظیم نشده است',
                    style: TextStyle(color: theme.textSecondaryColor),
                  ),
                ),
              )
            else
              ..._reminders.map((reminder) =>
                  _buildReminderItem(reminder, primaryColor, theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderItem(
      Reminder reminder, Color primaryColor, ThemeProvider theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:
            theme.isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.alarm, color: primaryColor, size: 20),
          const SizedBox(width: 12),
          Text(
            reminder.getTimeString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: theme.textColor,
            ),
          ),
          const Spacer(),
          Switch(
            value: reminder.isEnabled,
            onChanged: (value) => setState(() => reminder.isEnabled = value),
            activeColor: primaryColor,
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
            onPressed: () => setState(() => _reminders.remove(reminder)),
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

  Widget _buildTitleField(Color primaryColor, ThemeProvider theme) {
    return TextFormField(
      controller: _titleController,
      style: TextStyle(color: theme.textColor),
      decoration: InputDecoration(
        labelText: 'عنوان عادت',
        hintText: 'مثال: ورزش روزانه',
        labelStyle: TextStyle(color: theme.textSecondaryColor),
        hintStyle: TextStyle(color: theme.textSecondaryColor),
        prefixIcon: Icon(Icons.title, color: primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        filled: true,
        fillColor: theme.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
      ),
      validator: (value) =>
          (value == null || value.isEmpty) ? 'لطفاً عنوان را وارد کنید' : null,
    );
  }

  Widget _buildDescriptionField(Color primaryColor, ThemeProvider theme) {
    return TextFormField(
      controller: _descriptionController,
      style: TextStyle(color: theme.textColor),
      decoration: InputDecoration(
        labelText: 'توضیحات (اختیاری)',
        labelStyle: TextStyle(color: theme.textSecondaryColor),
        prefixIcon: Icon(Icons.description, color: primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        filled: true,
        fillColor: theme.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
      ),
      maxLines: 2,
    );
  }

  Widget _buildSubHabitsSection(Color primaryColor, ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'زیرعادت‌ها (ریز عادت)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.textColor,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _subHabitController,
                style: TextStyle(color: theme.textColor),
                decoration: InputDecoration(
                  hintText: 'مثلاً: ۱۰ دقیقه پیاده روی',
                  hintStyle: TextStyle(color: theme.textSecondaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: primaryColor, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor:
                      theme.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
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
            children: _subHabits
                .map(
                  (sh) => Chip(
                    label: Text(sh, style: TextStyle(color: theme.textColor)),
                    backgroundColor:
                        theme.isDarkMode ? const Color(0xFF2A2A2A) : null,
                    onDeleted: () => setState(() => _subHabits.remove(sh)),
                    deleteIcon:
                        Icon(Icons.close, size: 16, color: theme.textColor),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildXPSection(Color primaryColor, ThemeProvider theme) {
    return Row(
      children: [
        Text('امتیاز XP هر بار:', style: TextStyle(color: theme.textColor)),
        const SizedBox(width: 16),
        Expanded(
          child: Slider(
            value: _xpReward.toDouble(),
            min: 5,
            max: 200,
            divisions: 39,
            activeColor: primaryColor,
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
      onPressed: _isLoading ? null : _saveHabit,
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
              'ایجاد عادت',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }

  Future<void> _saveHabit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_frequencyType == 'monthly' && _monthlyDays.isNotEmpty) {
      _monthlyDays.removeWhere((day) => day < 1 || day > 31);
      if (_monthlyDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لطفاً حداقل یک روز معتبر برای ماه انتخاب کنید'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final user = await _supabase.getCurrentUser();

      if (user != null && mounted) {
        final habit = Habit(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: user.id,
          title: _titleController.text,
          description: _descriptionController.text,
          subHabits: _subHabits,
          completedSubHabits: [],
          iconName: _selectedIcon,
          iconColor: _selectedIconColor,
          backgroundColor: _selectedBgColor,
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
          startDate: _startDate,
          xpReward: _xpReward,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          targetValue: _targetValue,
          fullDescription: _fullDescription,
          halfDescription: _halfDescription,
          basicDescription: _basicDescription,
        );

        await _supabase.createHabit(habit);

        // ✅ اضافه کردن به LocalStorage فوری
        if (mounted) {
          try {
            final syncProvider =
                Provider.of<SyncProvider>(context, listen: false);

            // ✅ ذخیره عادت جدید در LocalStorage
            await syncProvider.saveHabitToLocal(habit);

            // ✅ در صورت آنلاین بودن، force refresh از سرور
            if (syncProvider.isOnline) {
              await syncProvider.refreshHabitsAndTasks(); // ← سبک‌تر
            }
          } catch (e) {
            print('⚠️ Error refreshing local storage: $e');
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('عادت با موفقیت ایجاد شد! 🎉'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در ذخیره عادت: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subHabitController.dispose();
    super.dispose();
  }
}
