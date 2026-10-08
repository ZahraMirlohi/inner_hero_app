// lib/features/arena/screens/add_task_screen.dart

import 'package:flutter/material.dart';
import 'package:inner_hero_app/providers/sync_provider.dart';
import 'package:provider/provider.dart';
import '/services/supabase_service.dart';
import '/features/arena/models/task_model.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '/providers/theme_provider.dart';
import '/providers/calendar_provider.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<String> _subTasks = [];
  final _subTaskController = TextEditingController();
  DateTime? _dueDate;
  int _xpReward = 10;
  bool _isLoading = false;

  final _supabase = SupabaseService();

  Future<void> _selectDate() async {
    final calendar = Provider.of<CalendarProvider>(context, listen: false);

    if (calendar.isJalali) {
      _showJalaliDatePicker(calendar);
    } else {
      _showGregorianDatePicker();
    }
  }

  void _showGregorianDatePicker() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null && mounted) {
      setState(() {
        _dueDate = date;
      });
    }
  }

  void _showJalaliDatePicker(CalendarProvider calendar) {
    final now =
        _dueDate != null ? Jalali.fromDateTime(_dueDate!) : Jalali.now();
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
              title: const Text('انتخاب تاریخ', textAlign: TextAlign.right),
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
                                setStateDialog(() {
                                  selectedYear = value;
                                });
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
                                setStateDialog(() {
                                  selectedMonth = value;
                                });
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
                          setStateDialog(() {
                            selectedDay = value;
                          });
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
                      final miladiDate = jalaliDate.toDateTime();
                      setState(() {
                        _dueDate = miladiDate;
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

  String _getDisplayDate(CalendarProvider calendar) {
    if (_dueDate == null) return 'انتخاب کنید';
    return calendar.formatShort(_dueDate!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final calendar = Provider.of<CalendarProvider>(context);
    final Color primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: const Text('وظیفه جدید'),
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
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildTitleField(primaryColor, theme),
            const SizedBox(height: 16),
            _buildDescriptionField(primaryColor, theme),
            const SizedBox(height: 16),
            _buildSubTasksSection(primaryColor, theme),
            const SizedBox(height: 16),
            _buildDateSection(primaryColor, calendar, theme),
            const SizedBox(height: 16),
            _buildXPSection(primaryColor, theme),
            const SizedBox(height: 32),
            _buildSubmitButton(primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleField(Color primaryColor, ThemeProvider theme) {
    return TextFormField(
      controller: _titleController,
      style: TextStyle(color: theme.textColor),
      decoration: InputDecoration(
        labelText: 'عنوان تسک',
        hintText: 'مثال: تماس با مشتری',
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
          value?.isEmpty ?? true ? 'لطفاً عنوان را وارد کنید' : null,
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

  Widget _buildSubTasksSection(Color primaryColor, ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'زیرتسک‌ها',
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
                controller: _subTaskController,
                style: TextStyle(color: theme.textColor),
                decoration: InputDecoration(
                  hintText: 'مثلاً: تهیه لیست موارد',
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
                      _subTasks.add(value);
                      _subTaskController.clear();
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                if (_subTaskController.text.isNotEmpty) {
                  setState(() {
                    _subTasks.add(_subTaskController.text);
                    _subTaskController.clear();
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
        if (_subTasks.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _subTasks
                .map(
                  (st) => Chip(
                    label: Text(st, style: TextStyle(color: theme.textColor)),
                    backgroundColor:
                        theme.isDarkMode ? const Color(0xFF2A2A2A) : null,
                    onDeleted: () => setState(() => _subTasks.remove(st)),
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

  Widget _buildDateSection(
    Color primaryColor,
    CalendarProvider calendar,
    ThemeProvider theme,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: primaryColor.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.calendar_today, color: primaryColor, size: 20),
      ),
      title: Text(
        'تاریخ سررسید',
        style: TextStyle(color: theme.textColor),
      ),
      subtitle: Text(
        _getDisplayDate(calendar),
        style: TextStyle(
          color: _dueDate != null ? theme.textColor : theme.textSecondaryColor,
        ),
      ),
      onTap: _selectDate,
    );
  }

  Widget _buildXPSection(Color primaryColor, ThemeProvider theme) {
    return Row(
      children: [
        Text('امتیاز XP:', style: TextStyle(color: theme.textColor)),
        const SizedBox(width: 16),
        Expanded(
          child: Slider(
            value: _xpReward.toDouble(),
            min: 5,
            max: 200,
            divisions: 9,
            activeColor: primaryColor,
            inactiveColor: theme.borderColor,
            onChanged: (value) => setState(() => _xpReward = value.toInt()),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: primaryColor.withAlpha(25),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$_xpReward XP',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(Color primaryColor) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _saveTask,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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
              'ذخیره تسک',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = await _supabase.getCurrentUser();
      if (user != null && mounted) {
        final task = Task(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: user.id,
          title: _titleController.text,
          description: _descriptionController.text,
          subTasks: _subTasks,
          completedSubTasks: [],
          dueDate: _dueDate,
          isCompleted: false,
          xpReward: _xpReward,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _supabase.createTask(task);

        // ✅ اضافه کردن به LocalStorage فوری
        if (mounted) {
          try {
            final syncProvider =
                Provider.of<SyncProvider>(context, listen: false);

            // ✅ ذخیره تسک جدید در LocalStorage
            await syncProvider.saveTaskToLocal(task);

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
              content: Text('تسک با موفقیت ایجاد شد! 🎉'),
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
            content: Text('خطا در ذخیره تسک: ${e.toString()}'),
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
    _subTaskController.dispose();
    super.dispose();
  }
}
