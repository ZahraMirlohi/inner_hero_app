// lib/features/profile/widgets/analytics_overview_widget.dart

import 'package:flutter/material.dart';
import '/services/supabase_service.dart';
// ✅ حذف import های استفاده نشده

class AnalyticsOverviewWidget extends StatefulWidget {
  final String userId;
  final VoidCallback onTapMore;

  const AnalyticsOverviewWidget({
    super.key,
    required this.userId,
    required this.onTapMore,
  });

  @override
  State<AnalyticsOverviewWidget> createState() =>
      AnalyticsOverviewWidgetState();
}

class AnalyticsOverviewWidgetState extends State<AnalyticsOverviewWidget> {
  final SupabaseService _supabase = SupabaseService();

  // آمار امروز
  int _todayTasks = 0;
  int _todayTasksCompleted = 0;
  int _todayHabits = 0;
  int _todayHabitsCompleted = 0;
  int _todayChallenges = 0;
  int _todayChallengesCompleted = 0;
  int _todayQuests = 0;
  int _todayQuestsCompleted = 0;

  double _completionRate = 0.0;
  int _totalItems = 0;
  int _totalCompleted = 0;

  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  // ✅ متد عمومی برای ریفرش از بیرون
  void refreshData() {
    if (!_isRefreshing) {
      _isRefreshing = true;
      _loadStats().then((_) {
        _isRefreshing = false;
      });
    }
  }

  // ✅ متد بارگذاری آمار با کش
  Future<void> _loadStats() async {
    // اگر در حال بارگذاری است، از بارگذاری مجدد جلوگیری کن
    if (_isLoading && _isRefreshing) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final today = DateTime.now();

      // دریافت عادت‌ها
      final allHabits = await _supabase.getHabits(widget.userId);

      // دریافت تسک‌ها
      final allTasks = await _supabase.getTasks(widget.userId);

      // دریافت چالش‌های کاربر
      final userChallenges = await _supabase.getUserChallenges(widget.userId);

      // دریافت ماموریت‌های کاربر
      final userQuests = await _supabase.getUserQuests(widget.userId);

      // ==================== محاسبه آمار امروز ====================

      // 1. عادت‌های امروز
      int todayHabits = 0;
      int todayHabitsCompleted = 0;

      for (var habit in allHabits) {
        if (!habit.isActive) continue;
        if (!habit.shouldDoOnDate(today)) continue;

        todayHabits++;

        final isCompleted = await _supabase.isHabitCompletedOnDate(
          habit.id,
          widget.userId,
          today,
        );
        if (isCompleted) {
          todayHabitsCompleted++;
        }
      }

      // 2. تسک‌های امروز
      int todayTasks = 0;
      int todayTasksCompleted = 0;

      for (var task in allTasks) {
        if (task.dueDate == null) continue;
        if (!task.isForDate(today)) continue;

        todayTasks++;
        if (task.isCompleted) {
          todayTasksCompleted++;
        }
      }

      // 3. چالش‌های امروز
      int todayChallenges = 0;
      int todayChallengesCompleted = 0;

      final activeChallenges = userChallenges
          .where((c) => c['is_active'] == true && c['is_completed'] == false)
          .toList();

      for (var challenge in activeChallenges) {
        final challengeId = challenge['id'];
        final challengeHabits = allHabits
            .where((h) => h.challengeId == challengeId)
            .toList();

        if (challengeHabits.isEmpty) continue;

        todayChallenges++;

        bool allDone = true;
        for (var habit in challengeHabits) {
          final isCompleted = await _supabase.isHabitCompletedOnDate(
            habit.id,
            widget.userId,
            today,
          );
          if (!isCompleted) {
            allDone = false;
            break;
          }
        }
        if (allDone) {
          todayChallengesCompleted++;
        }
      }

      // 4. ماموریت‌های امروز
      int todayQuests = 0;
      int todayQuestsCompleted = 0;

      final activeQuests = userQuests
          .where((uq) => uq.isActive && !uq.isCompleted)
          .toList();

      for (var userQuest in activeQuests) {
        final questHabits = allHabits
            .where((h) => h.questId == userQuest.questId)
            .toList();

        if (questHabits.isEmpty) continue;

        todayQuests++;

        bool allDone = true;
        for (var habit in questHabits) {
          final isCompleted = await _supabase.isHabitCompletedOnDate(
            habit.id,
            widget.userId,
            today,
          );
          if (!isCompleted) {
            allDone = false;
            break;
          }
        }
        if (allDone) {
          todayQuestsCompleted++;
        }
      }

      // ==================== محاسبه نرخ تکمیل ====================
      final totalItems =
          todayHabits + todayTasks + todayChallenges + todayQuests;
      final totalCompleted =
          todayHabitsCompleted +
          todayTasksCompleted +
          todayChallengesCompleted +
          todayQuestsCompleted;

      final double completionRate = totalItems > 0
          ? (totalCompleted / totalItems).toDouble()
          : 0.0;

      if (mounted) {
        setState(() {
          _todayHabits = todayHabits;
          _todayHabitsCompleted = todayHabitsCompleted;
          _todayTasks = todayTasks;
          _todayTasksCompleted = todayTasksCompleted;
          _todayChallenges = todayChallenges;
          _todayChallengesCompleted = todayChallengesCompleted;
          _todayQuests = todayQuests;
          _todayQuestsCompleted = todayQuestsCompleted;
          _totalItems = totalItems;
          _totalCompleted = totalCompleted;
          _completionRate = completionRate;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading stats: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // هدر
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📊 نمای کلی پیشرفت امروز',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              TextButton(
                onPressed: widget.onTapMore,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'جزئیات بیشتر ›',
                  style: TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(
              child: SizedBox(
                height: 100,
                child: CircularProgressIndicator(color: Color(0xFF2563EB)),
              ),
            )
          else ...[
            // نرخ تکمیل کلی
            _buildCompletionRateCard(),

            const SizedBox(height: 16),

            // آمار در ۴ ردیف
            _buildStatRow(
              icon: Icons.fitness_center,
              label: 'عادت‌ها',
              total: _todayHabits,
              completed: _todayHabitsCompleted,
              color: const Color(0xFF4A90E2),
            ),
            const SizedBox(height: 10),

            _buildStatRow(
              icon: Icons.assignment,
              label: 'تسک‌ها',
              total: _todayTasks,
              completed: _todayTasksCompleted,
              color: const Color(0xFFFFA500),
            ),
            const SizedBox(height: 10),

            _buildStatRow(
              icon: Icons.flag,
              label: 'چالش‌ها',
              total: _todayChallenges,
              completed: _todayChallengesCompleted,
              color: const Color(0xFF7C3AED),
            ),
            const SizedBox(height: 10),

            _buildStatRow(
              icon: Icons.stars,
              label: 'ماموریت‌ها',
              total: _todayQuests,
              completed: _todayQuestsCompleted,
              color: const Color(0xFF2ECC71),
            ),

            const SizedBox(height: 16),

            // پیام تشویقی
            _buildMotivationalMessage(),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletionRateCard() {
    final percent = (_completionRate * 100).toInt();
    final bool isGood = percent >= 70;
    final bool isExcellent = percent >= 90;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isExcellent
              ? [const Color(0xFF2ECC71), const Color(0xFF27AE60)]
              : isGood
              ? [const Color(0xFF4A90E2), const Color(0xFF7C3AED)]
              : [const Color(0xFFFFA500), const Color(0xFFE74C3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'نرخ تکمیل امروز',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _completionRate,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              color: Colors.white,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getCompletionMessage(percent),
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required int total,
    required int completed,
    required Color color,
  }) {
    final bool hasItems = total > 0;
    final bool allDone = hasItems && completed == total;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.12), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
          if (hasItems) ...[
            Text(
              '$completed / $total',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: allDone ? Colors.green : color,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: allDone
                    ? Colors.green.withValues(alpha: 0.12)
                    : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                allDone ? '✅ کامل' : '${((completed / total) * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: allDone ? Colors.green : color,
                ),
              ),
            ),
          ] else ...[
            Text(
              'هیچی',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ],
        ],
      ),
    );
  }

  String _getCompletionMessage(int percent) {
    if (percent >= 90) {
      return '🌟 فوق‌العاده! امروز واقعاً درخشان بودی!';
    } else if (percent >= 70) {
      return '💪 عالی! تقریباً همه کارها رو انجام دادی!';
    } else if (percent >= 50) {
      return '👍 خوب! نصف کارها رو انجام دادی، ادامه بده!';
    } else if (percent >= 30) {
      return '📈 شروع خوبی داری، امروز رو قوی تموم کن!';
    } else if (percent > 0) {
      return '🌱 هر قدم کوچک مهمه، امروز رو ادامه بده!';
    } else {
      return '🚀 امروز رو شروع کن! یک قدم به قهرمانی نزدیک‌تر میشی!';
    }
  }

  Widget _buildMotivationalMessage() {
    final bool hasItems = _totalItems > 0;
    final bool allDone = hasItems && _totalItems == _totalCompleted;

    if (!hasItems) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.emoji_emotions, color: Colors.grey.shade400, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'برای امروز هیچ کاری تعیین نکردی! یک عادت یا تسک جدید اضافه کن 🎯',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      );
    }

    if (allDone) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '🎉 همه کارهای امروز رو انجام دادی! تو یک قهرمان واقعی هستی!',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.green.shade700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final remaining = _totalItems - _totalCompleted;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFA500).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFA500).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department,
            color: Color(0xFFFFA500),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '🔥 فقط $remaining کار دیگه مونده! ادامه بده، به قهرمانی نزدیک میشی!',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.orange.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
