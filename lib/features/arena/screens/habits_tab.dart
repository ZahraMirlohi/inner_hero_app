// lib/features/arena/screens/habits_tab.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/services/supabase_service.dart';
import '/services/date_service.dart';
import '/features/arena/models/habit_model.dart';
import '../category_selection_screen.dart';
import '../edit_habit_screen.dart';
import '/../providers/sync_provider.dart';
import '/models/offline_operation.dart';

class HabitsTab extends StatefulWidget {
  const HabitsTab({super.key});

  @override
  State<HabitsTab> createState() => HabitsTabState();
}

class HabitsTabState extends State<HabitsTab> with TickerProviderStateMixin {
  final SupabaseService _supabase = SupabaseService();
  List<Habit> _habits = [];
  bool _isLoading = true;
  String? _currentUserId;
  String? _expandedItemId;
  String? _expandedSubItemId;

  final Map<String, AnimationController> _animationControllers = {};
  final Map<String, Animation<double>> _animations = {};
  void refreshData() {
    if (!_isLoading) {
      // ✅ ریفرش کامل
      _loadHabits();
    }
  }

  @override
  void initState() {
    super.initState();
    // ✅ بارگذاری با کمی تأخیر
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHabits();
    });
  }

  @override
  void dispose() {
    for (var controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initAnimation(String id) {
    if (!_animationControllers.containsKey(id)) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      );
      final animation = CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutBack,
      );
      _animationControllers[id] = controller;
      _animations[id] = animation;
    }
  }

  void _toggleExpanded(String id) {
    setState(() {
      if (_expandedItemId == id) {
        if (_animationControllers.containsKey(id)) {
          _animationControllers[id]!.reverse();
        }
        _expandedItemId = null;
        _expandedSubItemId = null;
      } else {
        if (_expandedItemId != null &&
            _animationControllers.containsKey(_expandedItemId)) {
          _animationControllers[_expandedItemId]!.reverse();
        }
        _initAnimation(id);
        _animationControllers[id]!.forward();
        _expandedItemId = id;
        _expandedSubItemId = null;
      }
    });
  }

  Future<void> _loadHabits() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final user = await _supabase.getCurrentUser();
    if (user != null && mounted) {
      _currentUserId = user.id;

      // ✅ دریافت از SyncProvider
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);

      // ✅ ابتدا از داده‌های محلی استفاده کن
      final allHabits = syncProvider.habits.isNotEmpty
          ? syncProvider.habits
          : await _supabase.getHabits(_currentUserId!);

      // ✅ نمایش همه عادت‌های فعال (شامل عادت‌های چالش)
      _habits = allHabits.where((h) => h.isActive && h.isNotExpired()).toList();
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String _getFrequencyText(Habit habit) {
    switch (habit.frequencyType) {
      case 'daily':
        if (habit.dailyIntervalDays != null &&
            habit.dailyIntervalDays!.isNotEmpty) {
          return 'هر ${habit.dailyIntervalDays!.first} روز';
        }
        return 'روزانه';
      case 'weekly':
        if (habit.weeklyDays != null && habit.weeklyDays!.isNotEmpty) {
          return '${habit.weeklyDays!.length} روز در هفته';
        }
        return 'هفتگی';
      case 'monthly':
        if (habit.monthlyDays != null && habit.monthlyDays!.isNotEmpty) {
          return 'ماهانه (روزهای ${habit.monthlyDays!.join(", ")})';
        }
        return 'ماهانه';
      default:
        return 'روزانه';
    }
  }

  String _getTimeOfDayText(String timeOfDay) {
    switch (timeOfDay) {
      case 'morning':
        return 'صبح';
      case 'noon':
        return 'ظهر';
      case 'afternoon':
        return 'بعدازظهر';
      case 'night':
        return 'شب';
      default:
        return 'صبح';
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
      default:
        return Icons.fitness_center;
    }
  }

  void _showHabitDetailsDialog(Habit habit) async {
    String startDateStr = '';
    if (habit.startDate != null) {
      startDateStr = await DateService.formatDate(habit.startDate!);
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Color(habit.backgroundColor).withAlpha(255),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getIconData(habit.iconName),
                      color: Color(habit.iconColor),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        Text(
                          habit.description.isEmpty
                              ? 'بدون توضیحات'
                              : habit.description,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              _buildDetailRow(
                Icons.repeat,
                'زمانبندی',
                _getFrequencyText(habit),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                Icons.access_time,
                'زمان',
                _getTimeOfDayText(habit.timeOfDay),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.stars, 'امتیاز', '${habit.xpReward} XP'),
              if (habit.startDate != null) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.calendar_today,
                  'تاریخ شروع',
                  startDateStr,
                ),
              ],
              if (habit.reminders.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.alarm,
                  'یادآورها',
                  '${habit.reminders.length} یادآور',
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF4A90E2).withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF4A90E2), size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }

  // ==================== متدهای ویرایش و حذف ====================

  Future<void> _editHabit(Habit habit) async {
    // ✅ بررسی: عادت‌های چالش و ماموریت قابل ویرایش نیستند
    final isChallengeHabit = habit.title.startsWith('🏆');
    final isQuestHabit = habit.questId != null;

    if (isChallengeHabit || isQuestHabit) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'این عادت مربوط به چالش یا ماموریت است و قابل ویرایش نیست',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditHabitScreen(habit: habit)),
    );

    if (result == true && mounted) {
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);

      // ✅ اگر آنلاین هستیم، از دیتابیس reload کن
      if (syncProvider.isOnline) {
        _loadHabits();
      } else {
        // ✅ آفلاین: از LocalStorage بخوان
        final updatedHabits = syncProvider.habits;
        setState(() {
          _habits = updatedHabits
              .where((h) => h.isActive && h.isNotExpired())
              .toList();
        });
      }
    }
    _toggleExpanded(habit.id);
  }

  Future<void> _deleteHabit(Habit habit) async {
    // ✅ بررسی: عادت‌های چالش و ماموریت قابل حذف نیستند
    final isChallengeHabit = habit.title.startsWith('🏆');
    final isQuestHabit = habit.questId != null;

    if (isChallengeHabit || isQuestHabit) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'این عادت مربوط به چالش یا ماموریت است و قابل حذف نیست',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      _toggleExpanded(habit.id);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف عادت'),
        content: const Text('آیا از حذف این عادت مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);

      // ✅ حذف از UI
      setState(() {
        _habits.removeWhere((h) => h.id == habit.id);
      });

      // ✅ حذف از LocalStorage
      await _supabase.deleteHabit(habit.id);

      // ✅ اگر آنلاین هستیم، از دیتابیس حذف کن
      if (syncProvider.isOnline) {
        await _supabase.deleteHabit(habit.id);
      } else {
        // ✅ آفلاین: ذخیره در صف
        await syncProvider.addOfflineOperation(
          type: OperationType.deleteHabit,
          data: {'id': habit.id},
        );
        print('📝 Habit deletion saved offline: ${habit.title}');
      }
    }
    _toggleExpanded(habit.id);
  }

  Future<void> _toggleSubHabit(Habit habit, String subHabit) async {
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);

    List<String> newCompletedSubHabits = List.from(habit.completedSubHabits);
    if (newCompletedSubHabits.contains(subHabit)) {
      newCompletedSubHabits.remove(subHabit);
    } else {
      newCompletedSubHabits.add(subHabit);
    }

    final updatedHabit = Habit(
      id: habit.id,
      userId: habit.userId,
      title: habit.title,
      description: habit.description,
      subHabits: habit.subHabits,
      completedSubHabits: newCompletedSubHabits,
      iconName: habit.iconName,
      iconColor: habit.iconColor,
      backgroundColor: habit.backgroundColor,
      frequencyType: habit.frequencyType,
      dailyIntervalDays: habit.dailyIntervalDays,
      weeklyDays: habit.weeklyDays,
      weeklyIntervalWeeks: habit.weeklyIntervalWeeks,
      monthlyDays: habit.monthlyDays,
      monthlyIntervalMonths: habit.monthlyIntervalMonths,
      timeOfDay: habit.timeOfDay,
      reminders: habit.reminders,
      xpReward: habit.xpReward,
      currentStreak: habit.currentStreak,
      bestStreak: habit.bestStreak,
      isActive: habit.isActive,
      createdAt: habit.createdAt,
      updatedAt: DateTime.now(),
      groupId: habit.groupId,
      startDate: habit.startDate,
    );

    // ✅ به‌روزرسانی UI
    setState(() {
      final index = _habits.indexWhere((h) => h.id == habit.id);
      if (index != -1) {
        _habits[index] = updatedHabit;
      }
    });

    // ✅ ذخیره در LocalStorage
    await syncProvider.saveHabitToLocal(updatedHabit);

    // ✅ اگر آنلاین هستیم، به دیتابیس هم بفرست
    if (syncProvider.isOnline) {
      await _supabase.updateHabit(updatedHabit);
    } else {
      // ✅ آفلاین: ذخیره در صف
      await syncProvider.addOfflineOperation(
        type: OperationType.updateHabit,
        data: updatedHabit.toMap(),
      );
      print('📝 Habit update saved offline: ${updatedHabit.title}');
    }
  }

  // ==================== ویجت‌های کمکی ====================

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Icon(
          icon,
          color: onTap == null ? Colors.grey.shade300 : Colors.grey.shade600,
          size: 24,
        ),
      ),
    );
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CategorySelectionScreen()),
          );
          if (result == true && mounted) {
            _loadHabits();
          }
        },
        backgroundColor: const Color(0xFF4A90E2),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _loadHabits,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF4A90E2)),
              )
            : _habits.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.fitness_center_outlined,
                      size: 80,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'هیچ عادتی ندارید',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'روی دکمه + در پایین صفحه کلیک کنید',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _habits.length,
                itemBuilder: (context, index) {
                  final habit = _habits[index];
                  return _buildHabitItem(habit);
                },
              ),
      ),
    );
  }

  Widget _buildHabitItem(Habit habit) {
    // ✅ تشخیص عادت چالش (با 🏆 شروع میشه)
    final isChallengeHabit = habit.title.startsWith('🏆');

    // ✅ تشخیص عادت ماموریت (questId دارد)
    final isQuestHabit = habit.questId != null;

    // ✅ آیا عادت قابل ویرایش است؟
    final isEditable = !isChallengeHabit && !isQuestHabit;

    final hasSubHabits = habit.subHabits.isNotEmpty;
    final isExpanded = _expandedItemId == habit.id;
    final isSubExpanded = _expandedSubItemId == habit.id;

    _initAnimation(habit.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleExpanded(habit.id),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Color(habit.backgroundColor).withAlpha(255),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getIconData(habit.iconName),
                      color: Color(habit.iconColor),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        Text(
                          '${_getFrequencyText(habit)} • ${_getTimeOfDayText(habit.timeOfDay)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (hasSubHabits && habit.completedSubHabits.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A90E2).withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${habit.completedSubHabits.length}/${habit.subHabits.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A90E2),
                        ),
                      ),
                    ),
                  // ✅ برچسب وضعیت (چالش/ماموریت)
                  if (isChallengeHabit || isQuestHabit)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isChallengeHabit
                            ? Colors.orange.withAlpha(25)
                            : Colors.purple.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isChallengeHabit ? '🏆 چالش' : '🎯 ماموریت',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isChallengeHabit
                              ? Colors.orange.shade700
                              : Colors.purple.shade700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (isExpanded)
            SizeTransition(
              sizeFactor: _animations[habit.id]!,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade200,
                          width: isSubExpanded ? 0 : 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildActionButton(
                          icon: Icons.info_outline,
                          onTap: () => _showHabitDetailsDialog(habit),
                        ),
                        if (hasSubHabits)
                          _buildActionButton(
                            icon: isSubExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.list_alt,
                            onTap: () {
                              setState(() {
                                if (_expandedSubItemId == habit.id) {
                                  _expandedSubItemId = null;
                                } else {
                                  _expandedSubItemId = habit.id;
                                }
                              });
                            },
                          ),
                        // ✅ دکمه ویرایش - فقط برای عادت‌های قابل ویرایش
                        _buildActionButton(
                          icon: Icons.edit,
                          onTap: isEditable ? () => _editHabit(habit) : null,
                        ),
                        // ✅ دکمه حذف - فقط برای عادت‌های قابل ویرایش
                        _buildActionButton(
                          icon: Icons.delete,
                          onTap: isEditable ? () => _deleteHabit(habit) : null,
                        ),
                      ],
                    ),
                  ),

                  if (isSubExpanded && hasSubHabits)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'زیرعادت‌ها',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...habit.subHabits.map(
                            (subHabit) => CheckboxListTile(
                              value: habit.completedSubHabits.contains(
                                subHabit,
                              ),
                              onChanged: (value) async {
                                await _toggleSubHabit(habit, subHabit);
                                setState(() {});
                              },
                              title: Text(subHabit),
                              activeColor: const Color(0xFF4A90E2),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: habit.subHabits.isEmpty
                                ? 0
                                : habit.completedSubHabits.length /
                                      habit.subHabits.length,
                            backgroundColor: Colors.grey.shade200,
                            color: const Color(0xFF4A90E2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'پیشرفت: ${habit.subHabits.isEmpty ? 0 : ((habit.completedSubHabits.length / habit.subHabits.length) * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
