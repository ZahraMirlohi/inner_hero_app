// lib/features/explore/screens/quests_tab.dart

import 'package:flutter/material.dart';
import '../models/quest_model.dart';
import '../models/user_quest_model.dart';
import '../widgets/quest_card.dart';
import '/services/supabase_service.dart';

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
        // ✅ حالت بارگذاری
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF4A90E2)),
          );
        }

        // ✅ حالت خطا
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
                  child: const Text('تلاش مجدد'),
                ),
              ],
            ),
          );
        }

        // ✅ دریافت داده‌ها
        final userQuests = snapshot.data ?? [];

        // ✅ ماموریت‌های فعال (در حال انجام)
        final activeQuestIds = userQuests
            .where((uq) => uq.isActive && !uq.isCompleted)
            .map((uq) => uq.questId)
            .toList();

        final activeQuests = widget.quests
            .where((q) => activeQuestIds.contains(q.id))
            .toList();

        // ✅ ماموریت‌های تکمیل شده
        final completedQuestIds = userQuests
            .where((uq) => uq.isCompleted)
            .map((uq) => uq.questId)
            .toList();

        final completedQuests = widget.quests
            .where((q) => completedQuestIds.contains(q.id))
            .toList();

        // ✅ ماموریت‌های جدید (شروع نشده)
        final startedOrCompletedQuestIds = userQuests
            .where((uq) => uq.isActive || uq.isCompleted)
            .map((uq) => uq.questId)
            .toList();

        final newQuests = widget.quests
            .where((q) => !startedOrCompletedQuestIds.contains(q.id))
            .toList();

        // ✅ اگر هیچ ماموریتی وجود نداشت
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

        // ✅ نمایش ماموریت‌ها
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ ماموریت‌های فعال (در حال انجام)
              if (activeQuests.isNotEmpty) ...[
                const Text(
                  '⚡ ماموریت‌های در حال انجام',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 12),
                ...activeQuests.map(
                  (quest) => QuestCard(
                    quest: quest,
                    isActive: true,
                    isCompleted: false,
                    onTap: () => widget.showQuestDetail(quest),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ✅ ماموریت‌های تکمیل شده
              if (completedQuests.isNotEmpty) ...[
                const Text(
                  '🏆 ماموریت‌های تکمیل شده',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 12),
                ...completedQuests.map(
                  (quest) => QuestCard(
                    quest: quest,
                    isActive: false,
                    isCompleted: true,
                    onTap: null,
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ✅ ماموریت‌های جدید
              if (newQuests.isNotEmpty) ...[
                const Text(
                  '✨ ماموریت‌های جدید',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 12),
                ...newQuests.map(
                  (quest) => QuestCard(
                    quest: quest,
                    isActive: false,
                    isCompleted: false,
                    onTap: () => widget.showQuestDetail(quest),
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
}
