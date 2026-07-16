import 'package:flutter/material.dart';
import '/services/supabase_service.dart';
import '/services/date_service.dart';
import '/features/arena/models/task_model.dart';
import 'package:shamsi_date/shamsi_date.dart';

class EditTaskScreen extends StatefulWidget {
  final Task task;

  const EditTaskScreen({super.key, required this.task});

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late List<String> _subTasks;
  final _subTaskController = TextEditingController();
  DateTime? _dueDate;
  late int _xpReward;
  bool _isLoading = false;
  String _calendarType = 'jalali';

  final _supabase = SupabaseService(); // ← تغییر

  @override
  void initState() {
    super.initState();
    _loadCalendarType();
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(
      text: widget.task.description,
    );
    _subTasks = List.from(widget.task.subTasks);
    _dueDate = widget.task.dueDate;
    _xpReward = widget.task.xpReward;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subTaskController.dispose();
    super.dispose();
  }

  Future<void> _loadCalendarType() async {
    final calendarType = await DateService.getCalendarType();
    if (mounted) {
      setState(() {
        _calendarType = calendarType;
      });
    }
  }

  Future<void> _selectDate() async {
    if (_calendarType == 'jalali') {
      _showJalaliDatePicker();
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

  void _showJalaliDatePicker() {
    final now = _dueDate != null
        ? Jalali.fromDateTime(_dueDate!)
        : Jalali.now();
    int selectedYear = now.year;
    int selectedMonth = now.month;
    int selectedDay = now.day;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            int daysInMonth = _getDaysInMonth(selectedYear, selectedMonth);
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
                            initialValue: selectedYear,
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
                            initialValue: selectedMonth,
                            decoration: const InputDecoration(
                              labelText: 'ماه',
                              border: OutlineInputBorder(),
                            ),
                            items: List.generate(12, (i) {
                              final month = i + 1;
                              return DropdownMenuItem(
                                value: month,
                                child: Text(_getMonthName(month)),
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
                      initialValue: selectedDay > daysInMonth
                          ? daysInMonth
                          : selectedDay,
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

  int _getDaysInMonth(int year, int month) {
    if (month <= 6) return 31;
    if (month <= 11) return 30;
    final date = Jalali(year, month, 1);
    return (date.isLeapYear == true) ? 30 : 29;
  }

  String _getMonthName(int month) {
    const months = [
      'فروردین',
      'اردیبهشت',
      'خرداد',
      'تیر',
      'مرداد',
      'شهریور',
      'مهر',
      'آبان',
      'آذر',
      'دی',
      'بهمن',
      'اسفند',
    ];
    return months[month - 1];
  }

  String _getDisplayDate() {
    if (_dueDate == null) return 'انتخاب کنید';

    if (_calendarType == 'jalali') {
      final jalali = Jalali.fromDateTime(_dueDate!);
      return '${jalali.year}/${jalali.month.toString().padLeft(2, '0')}/${jalali.day.toString().padLeft(2, '0')}';
    } else {
      return '${_dueDate!.year}/${_dueDate!.month.toString().padLeft(2, '0')}/${_dueDate!.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('ویرایش تسک'),
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
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'عنوان تسک',
                hintText: 'مثال: تماس با مشتری',
                prefixIcon: const Icon(Icons.title, color: Color(0xFFFFA500)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'لطفاً عنوان را وارد کنید' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'توضیحات (اختیاری)',
                prefixIcon: const Icon(
                  Icons.description,
                  color: Color(0xFFFFA500),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            _buildSubTasksSection(),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFA500).withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  color: Color(0xFFFFA500),
                  size: 20,
                ),
              ),
              title: const Text('تاریخ سررسید'),
              subtitle: Text(
                _getDisplayDate(),
                style: TextStyle(
                  color: _dueDate != null
                      ? const Color(0xFF1A1A2E)
                      : Colors.grey,
                ),
              ),
              onTap: _selectDate,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('امتیاز XP:'),
                const SizedBox(width: 16),
                Expanded(
                  child: Slider(
                    value: _xpReward.toDouble(),
                    min: 5,
                    max: 200,
                    divisions: 9,
                    activeColor: const Color(0xFFFFA500),
                    inactiveColor: Colors.grey.shade300,
                    onChanged: (value) =>
                        setState(() => _xpReward = value.toInt()),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
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
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _updateTask,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFA500),
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
                      'ذخیره تغییرات',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('زیرتسک‌ها', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _subTaskController,
                decoration: InputDecoration(
                  hintText: 'مثلاً: تهیه لیست موارد',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
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
                backgroundColor: const Color(0xFFFFA500),
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
            children: List.generate(_subTasks.length, (index) {
              final subTask = _subTasks[index];
              return Chip(
                label: Text(subTask),
                onDeleted: () {
                  setState(() {
                    _subTasks.removeAt(index);
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

  Future<void> _updateTask() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedTask = Task(
        id: widget.task.id,
        userId: widget.task.userId,
        title: _titleController.text,
        description: _descriptionController.text,
        subTasks: _subTasks,
        completedSubTasks: widget.task.completedSubTasks,
        dueDate: _dueDate,
        isCompleted: widget.task.isCompleted,
        xpReward: _xpReward,
        createdAt: widget.task.createdAt,
        updatedAt: DateTime.now(),
      );

      await _supabase.updateTask(updatedTask); // ← تغییر

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تسک با موفقیت ویرایش شد!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در ویرایش تسک: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
