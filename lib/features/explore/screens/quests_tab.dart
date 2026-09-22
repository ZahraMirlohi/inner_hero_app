// lib/features/explore/screens/quests_tab.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/quest_model.dart';
import '../models/user_quest_model.dart';
import '../widgets/quest_card.dart';
import '/services/supabase_service.dart';
import '/providers/theme_provider.dart';

class QuestsTab extends StatefulWidget {
  final List<Quest> quests;
  final List<Quest> completedQuests;
  final String currentUserId;
  final VoidCallback onRefresh;
  final Function(Quest) showQuestDetail;

  const QuestsTab({
    super.key,
    required this.quests,
    required this.completedQuests,
    required this.currentUserId,
    required this.onRefresh,
    required this.showQuestDetail,
  });

  @override
  State<QuestsTab> createState() => _QuestsTabState();
}

class _QuestsTabState extends State<QuestsTab> {
  final _supabase = SupabaseService();

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final Color primaryColor = themeProvider.primaryColor;

    if (widget.quests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flag_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'هنوز ماموریتی وجود ندارد',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<List<UserQuest>>(
      future: _supabase.getUserQuests(widget.currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: primaryColor),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade300, size: 48),
                const SizedBox(height: 12),
                Text(
                  'خطا در بارگذاری ماموریت‌ها',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: widget.onRefresh,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                  ),
                  child: const Text('تلاش مجدد'),
                ),
              ],
            ),
          );
        }

        final userQuests = snapshot.data ?? [];

        final activeQuestIds = userQuests
            .where((uq) => uq.isActive && !uq.isCompleted)
            .map((uq) => uq.questId)
            .toList();

        final activeQuests =
            widget.quests.where((q) => activeQuestIds.contains(q.id)).toList();

        final completedQuestIds = userQuests
            .where((uq) => uq.isCompleted)
            .map((uq) => uq.questId)
            .toList();

        final completedQuests = widget.quests
            .where((q) => completedQuestIds.contains(q.id))
            .toList();

        final startedOrCompletedQuestIds = userQuests
            .where((uq) => uq.isActive || uq.isCompleted)
            .map((uq) => uq.questId)
            .toList();

        final newQuests = widget.quests
            .where((q) => !startedOrCompletedQuestIds.contains(q.id))
            .toList();

        if (newQuests.isEmpty &&
            activeQuests.isEmpty &&
            completedQuests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.flag_outlined,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'هنوز ماموریتی وجود ندارد',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (activeQuests.isNotEmpty) ...[
                _buildSectionHeader(
                  icon: Icons.play_circle,
                  title: '⚡ ماموریت‌های در حال انجام',
                  color: Colors.orange,
                ),
                const SizedBox(height: 12),
                ...activeQuests.map(
                  (quest) => QuestCard(
                    quest: quest,
                    isActive: true,
                    isCompleted: false,
                    progress: _getQuestProgress(quest.id, userQuests),
                    primaryColor: primaryColor,
                    onTap: () => widget.showQuestDetail(quest),
                    onCancel: () => _showCancelQuestDialog(quest),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (completedQuests.isNotEmpty) ...[
                _buildSectionHeader(
                  icon: Icons.emoji_events,
                  title: '🏆 ماموریت‌های تکمیل شده',
                  color: Colors.green,
                ),
                const SizedBox(height: 12),
                ...completedQuests.map(
                  (quest) => QuestCard(
                    quest: quest,
                    isActive: false,
                    isCompleted: true,
                    primaryColor: primaryColor,
                    onTap: null,
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (newQuests.isNotEmpty) ...[
                _buildSectionHeader(
                  icon: Icons.flag,
                  title: '✨ ماموریت‌های جدید',
                  color: primaryColor,
                ),
                SizedBox(height: 12),
                ...newQuests.map(
                  (quest) => QuestCard(
                    quest: quest,
                    isActive: false,
                    isCompleted: false,
                    primaryColor: primaryColor,
                    onTap: () => widget.showQuestDetail(quest),
                    onStart: () => _startQuest(quest),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
// 🚀 شروع ماموریت
// ═══════════════════════════════════════════════════════════
  Future<void> _startQuest(Quest quest) async {
    try {
      // ✅ شروع ماموریت در دیتابیس
      await _supabase.startQuest(widget.currentUserId, quest);

      // ✅ ریفرش داده‌های صفحه
      widget.onRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ماموریت "${quest.title}" شروع شد! 🎉'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error starting quest: $e');
      if (mounted) {
        String message = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
// ⚠️ دیالوگ انصراف از ماموریت
// ═══════════════════════════════════════════════════════════
  void _showCancelQuestDialog(Quest quest) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFEF4444),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'انصراف از ماموریت',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF090909),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'آیا از انصراف از ماموریت "${quest.title}" مطمئن هستید؟',
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFA500).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFA500).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFFFFA500),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'با انصراف، تمام پیشرفت شما از دست خواهد رفت و باید از اول شروع کنید.',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'انصراف',
              style: TextStyle(color: Color(0xFF73786B)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelQuest(quest);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('بله، انصراف'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
// 🗑️ لغو ماموریت
// ═══════════════════════════════════════════════════════════
  Future<void> _cancelQuest(Quest quest) async {
    try {
      await _supabase.cancelQuest(widget.currentUserId, quest.id);

      widget.onRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('از ماموریت "${quest.title}" انصراف دادید'),
            backgroundColor: const Color(0xFF090909),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error cancelling quest: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  int _getQuestProgress(String questId, List<UserQuest> userQuests) {
    try {
      final userQuest = userQuests.firstWhere(
        (uq) => uq.questId == questId,
      );
      return userQuest.progress;
    } catch (e) {
      return 0;
    }
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
