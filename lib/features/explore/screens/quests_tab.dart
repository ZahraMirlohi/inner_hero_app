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
          padding: const EdgeInsets.fromLTRB(16, 100, 16, 120), // ✅ padding-top
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ═══════════════════════════════════════════════
              // ماموریت‌های در حال انجام (افقی)
              // ═══════════════════════════════════════════════
              if (activeQuests.isNotEmpty) ...[
                _buildSectionHeader(
                  icon: Icons.play_circle,
                  title: 'ماموریت‌های در حال انجام',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 240, // ✅ ارتفاع ثابت برای کارت‌های افقی
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    itemCount: activeQuests.length,
                    itemBuilder: (context, index) {
                      final quest = activeQuests[index];
                      final userQuest = userQuests.firstWhere(
                        (uq) => uq.questId == quest.id,
                        orElse: () => UserQuest(
                          id: '',
                          userId: '',
                          questId: quest.id,
                          startedAt: DateTime.now(),
                          createdAt: DateTime.now(),
                        ),
                      );

                      return Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: SizedBox(
                          width: 260, // ✅ عرض ثابت
                          child: _buildActiveQuestCard(
                            quest,
                            userQuest.progress,
                            primaryColor,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ═══════════════════════════════════════════════
              // ماموریت‌های تکمیل شده (مدال‌های کوچک افقی)
              // ═══════════════════════════════════════════════
              if (completedQuests.isNotEmpty) ...[
                _buildSectionHeader(
                  icon: Icons.emoji_events,
                  title: 'ماموریت‌های تکمیل شده',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 145, // ✅ ارتفاع برای کارت مدال
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    itemCount: completedQuests.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: _buildMedalCard(
                          completedQuests[index],
                          primaryColor,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ═══════════════════════════════════════════════
              // ماموریت‌های جدید (عمودی)
              // ═══════════════════════════════════════════════
              if (newQuests.isNotEmpty) ...[
                _buildSectionHeader(
                  icon: Icons.flag,
                  title: 'ماموریت‌های جدید',
                ),
                const SizedBox(height: 12),
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

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'fitness_center':
        return Icons.fitness_center;
      case 'book':
        return Icons.book;
      case 'wb_sunny':
        return Icons.wb_sunny;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'water_drop':
        return Icons.water_drop;
      case 'no_food':
        return Icons.no_food;
      case 'language':
        return Icons.language;
      case 'directions_walk':
        return Icons.directions_walk;
      case 'whatshot':
        return Icons.whatshot;
      case 'flag':
        return Icons.flag;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'sports_martial_arts':
        return Icons.sports_martial_arts;
      case 'school':
        return Icons.school;
      case 'psychology':
        return Icons.psychology;
      case 'favorite':
        return Icons.favorite;
      case 'star':
        return Icons.star;
      case 'emoji_events':
        return Icons.emoji_events;
      case 'timer':
        return Icons.timer;
      case 'calendar_today':
        return Icons.calendar_today;
      default:
        return Icons.flag; // ✅ پیش‌فرض
    }
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

  Widget _buildActiveQuestCard(Quest quest, int progress, Color primaryColor) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final Color primaryLight = themeProvider.primaryLight;

    // ✅ رنگ کرمی
    const Color creamColor = Color(0xFFFFF8E1); // کرمی روشن
    const Color creamTextColor = Color(0xFF5D4037); // قهوه‌ای تیره برای متن

    final double progressValue = quest.targetCount > 0
        ? (progress / quest.targetCount).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFB981), // ✅ کرمی
        borderRadius: BorderRadius.circular(20),
        // ✅ بدون بوردر
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 204, 148, 103)
                .withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── ردیف بالا: آیکون + عنوان + بج فعال ───
            Row(
              children: [
                // ✅ آیکون با پس‌زمینه سفید + بدون استروک + آیکون مشکی
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white, // ✅ سفید
                    borderRadius: BorderRadius.circular(12),
                    // ✅ بدون border
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      _getIconData(quest.icon),
                      color: const Color(0xFF090909), // ✅ مشکی
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    quest.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: creamTextColor,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // ✅ بج «فعال»
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: creamTextColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bolt,
                        size: 10,
                        color: creamTextColor,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'فعال',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: creamTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ─── توضیحات ───
            Text(
              quest.description,
              style: TextStyle(
                fontSize: 11,
                color: creamTextColor.withValues(alpha: 0.8),
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 10),

            // ─── نوار پیشرفت ───
            Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    backgroundColor: creamTextColor.withValues(alpha: 0.15),
                    color: creamTextColor,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '$progress از ${quest.targetCount} روز',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: creamTextColor.withValues(alpha: 0.8),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(progressValue * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: creamTextColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const Spacer(),

            // ─── ردیف پایین: XP + دکمه‌ها ───
            Row(
              children: [
                // XP
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 39, 39, 39)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.stars,
                        size: 11,
                        color: Color.fromARGB(255, 0, 0, 0),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '+${quest.xpReward}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color.fromARGB(255, 0, 0, 0),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // ✅ دکمه مشاهده (مشکی)
                GestureDetector(
                  onTap: () => widget.showQuestDetail(quest),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF090909),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 12,
                          color: Colors.white,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'مشاهده',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                // ✅ دکمه غیرفعال (primaryLight)
                GestureDetector(
                  onTap: () => _showCancelQuestDialog(quest),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 255, 255, 255),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF090909).withValues(alpha: 0.10),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.pause_circle_outline,
                          size: 12,
                          color: Color(0xFF090909),
                        ),
                        SizedBox(width: 3),
                        Text(
                          'غیرفعال',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF090909),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedalCard(Quest quest, Color primaryColor) {
    return GestureDetector(
      onTap: () => widget.showQuestDetail(quest),
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          // ✅ گرادیانت پس‌زمینه کرمی-طلایی ملایم
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFDF5), // کرم خیلی روشن
              Color(0xFFFFF3D6), // کرم طلایی
            ],
          ),
          boxShadow: [
            // ✅ سایه بیرونی تیره
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            // ✅ درخشش طلایی
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.20),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ═══════════════════════════════════════════
              // 🏅 روبان‌های آویزان از بالای مدال
              // ═══════════════════════════════════════════
              SizedBox(
                height: 18,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // روبان چپ
                    Transform.rotate(
                      angle: -0.35,
                      child: Container(
                        width: 14,
                        height: 22,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFE53935), // قرمز
                              Color(0xFFB71C1C),
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(2),
                            bottomRight: Radius.circular(8),
                            topLeft: Radius.circular(2),
                            topRight: Radius.circular(2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    // روبان راست
                    Transform.rotate(
                      angle: 0.35,
                      child: Container(
                        width: 14,
                        height: 22,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFE53935),
                              Color(0xFFB71C1C),
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(8),
                            bottomRight: Radius.circular(2),
                            topLeft: Radius.circular(2),
                            topRight: Radius.circular(2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ═══════════════════════════════════════════
              // 🏅 مدال دایره‌ای طلایی
              // ═══════════════════════════════════════════
              Transform.translate(
                offset: const Offset(0, -4), // ✅ کمی روی روبان‌ها سوار شود
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // ✅ گرادیانت طلایی براق
                    gradient: const RadialGradient(
                      center: Alignment(-0.4, -0.4), // درخشش بالا-چپ
                      radius: 0.9,
                      colors: [
                        Color(0xFFFFF8B0), // درخشان
                        Color(0xFFFFD700), // طلایی
                        Color(0xFFE5A100), // طلایی تیره
                        Color(0xFFB8860B), // طلایی قهوه‌ای
                      ],
                      stops: [0.0, 0.4, 0.75, 1.0],
                    ),
                    boxShadow: [
                      // ✅ درخشش بیرونی
                      BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                      // ✅ سایه عمیق
                      BoxShadow(
                        color: const Color(0xFFB8860B).withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // حلقه داخلی
                      Positioned.fill(
                        child: Container(
                          margin: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFFF8B0)
                                  .withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      // آیکون مرکزی
                      Center(
                        child: Icon(
                          _getIconData(quest.icon),
                          size: 26,
                          color: const Color(0xFF5D4037), // قهوه‌ای تیره
                        ),
                      ),
                      // ✨ درخشش گوشه بالا-راست
                      Positioned(
                        top: 8,
                        right: 10,
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      // ✨ درخشش کوچک‌تر
                      Positioned(
                        top: 14,
                        right: 16,
                        child: Container(
                          width: 2,
                          height: 2,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 4),

              // ═══════════════════════════════════════════
              // 📛 پلاک نام مدال
              // ═══════════════════════════════════════════
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  // ✅ پس‌زمینه پلاک قهوه‌ای تیره
                  color: const Color(0xFF5D4037),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5D4037).withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  quest.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFFF8B0), // متن کرمی-طلایی
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 4),

              // ═══════════════════════════════════════════
              // ⭐ تعداد XP کوچک
              // ═══════════════════════════════════════════
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.star,
                    size: 9,
                    color: Color(0xFFE5A100),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '+${quest.xpReward} XP',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB8860B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
  }) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF090909).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF090909),
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF090909),
            ),
          ),
        ],
      ),
    );
  }
}
