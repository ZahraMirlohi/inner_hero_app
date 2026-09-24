// lib/features/explore/widgets/quest_card.dart

import 'package:flutter/material.dart';
import '../models/quest_model.dart';

class QuestCard extends StatelessWidget {
  final Quest quest;
  final bool isActive;
  final bool isCompleted;
  final int? progress;
  final VoidCallback? onTap;
  final VoidCallback? onStart;
  final VoidCallback? onCancel;
  final Color primaryColor;

  const QuestCard({
    super.key,
    required this.quest,
    this.isActive = false,
    this.isCompleted = false,
    this.progress,
    this.onTap,
    this.onStart,
    this.onCancel,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    // ═══════════════════════════════════════════════════════
    // 🎨 رنگ‌بندی بدنه کارت
    // ═══════════════════════════════════════════════════════
    final Color bodyColor;
    final Color borderColor;
    final double borderWidth;
    final Color subtleTextColor;

    if (isCompleted) {
      bodyColor = const Color(0xFFF0FDF4);
      borderColor = Colors.green.shade200;
      borderWidth = 2;
      subtleTextColor = Colors.green.shade700;
    } else if (isActive) {
      bodyColor = primaryColor;
      borderColor = Colors.transparent;
      borderWidth = 0;
      subtleTextColor = Colors.black.withValues(alpha: 0.65);
    } else {
      bodyColor = Colors.white;
      borderColor = Colors.white;
      borderWidth = 2.5;
      subtleTextColor = const Color(0xFF73786B);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? primaryColor.withValues(alpha: 0.30)
                  : isCompleted
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: bodyColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
          ),
          // ═══════════════════════════════════════════════════
          // 📐 چیدمان Row: اطلاعات چپ + هدر راست
          // ═══════════════════════════════════════════════════
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── بخش چپ: اطلاعات ───
                Expanded(
                  child: _buildLeftContent(
                    isActive,
                    isCompleted,
                    subtleTextColor,
                  ),
                ),

                const SizedBox(width: 12),

                // ─── بخش راست: هدر (آیکون + عنوان) ───
                _buildRightHeader(isActive, isCompleted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 بخش چپ: اطلاعات
  // ═══════════════════════════════════════════════════════════
  Widget _buildLeftContent(
    bool isActive,
    bool isCompleted,
    Color subtleTextColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── توضیحات ───
        Text(
          quest.description,
          style: TextStyle(
            fontSize: 13,
            color: subtleTextColor,
            height: 1.5,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 12),

        // ─── نوار پیشرفت (فقط برای فعال) ───
        if (isActive && progress != null) ...[
          _buildProgressBar(progress!),
          const SizedBox(height: 12),
        ],

        // ─── بج تکمیل (برای completed) ───
        if (isCompleted) ...[
          _buildCompletedBanner(),
          const SizedBox(height: 12),
        ],

        // ─── تگ‌های اطلاعاتی (عمودی) ───
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildInfoChip(
              icon: Icons.calendar_today,
              label: '${quest.targetCount} روز',
              isActive: isActive,
              isCompleted: isCompleted,
            ),
            _buildInfoChip(
              icon: Icons.stars,
              label: '+${quest.xpReward} XP',
              isActive: isActive,
              isCompleted: isCompleted,
              iconColor: const Color(0xFFFFA500),
            ),
            if (isCompleted)
              _buildInfoChip(
                icon: Icons.emoji_events,
                label: quest.badge,
                isActive: false,
                isCompleted: true,
                iconColor: const Color(0xFF9B59B6),
              ),
          ],
        ),

        const SizedBox(height: 12),

        // ─── دکمه (شروع/غیرفعال/تکمیل) ───
        _buildActionButton(isActive, isCompleted),
      ],
    );
  }

  Widget _buildRightHeader(bool isActive, bool isCompleted) {
    // رنگ‌بندی بر اساس حالت
    final Color headerBg;
    final Color headerBorder;
    final double headerBorderWidth;
    final Color iconBoxBg;
    final Color iconColor;
    final Color titleColor;

    if (isActive) {
      headerBg = Colors.white;
      headerBorder = Colors.white;
      headerBorderWidth = 2;
      iconBoxBg = const Color(0xFF090909);
      iconColor = Colors.white;
      titleColor = const Color(0xFF090909);
    } else if (isCompleted) {
      headerBg = Colors.white;
      headerBorder = Colors.green;
      headerBorderWidth = 2;
      iconBoxBg = const Color(0xFF090909);
      iconColor = Colors.white;
      titleColor = const Color(0xFF090909);
    } else {
      headerBg = Colors.white;
      headerBorder = const Color(0xFF090909);
      headerBorderWidth = 2;
      iconBoxBg = primaryColor; // ✅ سبز (رنگ تم) — قبلاً 0xFF090909 بود
      iconColor = Colors.white;
      titleColor = const Color(0xFF090909);
    }

    return SizedBox(
      width: 90, // ✅ کمی پهن‌تر برای فونت بزرگ‌تر
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: headerBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: headerBorder,
            width: headerBorderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── جعبه آیکون ───
            Container(
              width: 34, // ✅ از 32 به 34
              height: 34,
              decoration: BoxDecoration(
                color: iconBoxBg,
                borderRadius: BorderRadius.circular(9),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.20),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  _getIconData(quest.icon),
                  color: iconColor,
                  size: 18, // ✅ از 17 به 18
                ),
              ),
            ),

            const SizedBox(height: 6),

            // ─── عنوان (فونت بزرگ‌تر) ───
            Text(
              quest.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12, // ✅ از 10 به 12
                fontWeight: FontWeight.bold,
                color: titleColor,
                height: 2,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
            ),

            // ─── بج تکمیل (برای completed) ───
            if (isCompleted) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, color: Colors.white, size: 10),
                    SizedBox(width: 2),
                    Text(
                      'تکمیل',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 نوار پیشرفت
  // ═══════════════════════════════════════════════════════════
  Widget _buildProgressBar(int currentProgress) {
    final double value = quest.targetCount > 0
        ? (currentProgress / quest.targetCount).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.black.withValues(alpha: 0.12),
                  color: const Color(0xFF090909),
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$currentProgress/${quest.targetCount}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF090909),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ بنر تکمیل
  // ═══════════════════════════════════════════════════════════
  Widget _buildCompletedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 14, color: Colors.green),
          const SizedBox(width: 6),
          Text(
            'تکمیل شد',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🏷️ Info Chip
  // ═══════════════════════════════════════════════════════════
  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isCompleted,
    Color? iconColor,
  }) {
    final Color bgColor;
    final Color fgColor;

    if (isActive) {
      bgColor = Colors.white.withValues(alpha: 0.35);
      fgColor = const Color(0xFF090909);
    } else if (isCompleted) {
      bgColor = Colors.green.withValues(alpha: 0.12);
      fgColor = Colors.green.shade700;
    } else {
      bgColor = const Color(0xFF090909).withValues(alpha: 0.06);
      fgColor = const Color(0xFF090909);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: isActive ? const Color(0xFF090909) : (iconColor ?? fgColor),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 دکمه اقدام (شروع/غیرفعال/تکمیل)
  // ═══════════════════════════════════════════════════════════
  Widget _buildActionButton(bool isActive, bool isCompleted) {
    if (isCompleted) {
      return _buildCompletedBadge();
    } else if (isActive && onCancel != null) {
      return _buildCancelButton();
    } else if (!isActive && onStart != null) {
      return _buildStartButton();
    }
    return const SizedBox.shrink();
  }

  // ═══════════════════════════════════════════════════════════
  // 🚀 دکمه شروع
  // ═══════════════════════════════════════════════════════════
  Widget _buildStartButton() {
    return GestureDetector(
      onTap: onStart,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF090909), // ✅ مشکی
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
            SizedBox(width: 4),
            Text(
              'شروع',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ⚫ دکمه غیرفعال
  // ═══════════════════════════════════════════════════════════
  Widget _buildCancelButton() {
    return GestureDetector(
      onTap: onCancel,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF090909),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'غیرفعال',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ بج تکمیل
  // ═══════════════════════════════════════════════════════════
  Widget _buildCompletedBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFA500).withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, size: 12, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'تکمیل شده',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 آیکون‌ها
  // ═══════════════════════════════════════════════════════════
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
      default:
        return Icons.flag;
    }
  }
}
