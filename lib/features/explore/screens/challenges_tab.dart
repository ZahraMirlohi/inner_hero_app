// lib/features/explore/screens/challenges_tab.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/services/supabase_service.dart';
import '/providers/theme_provider.dart';

// ═══════════════════════════════════════════════════════════════
// 🎨 SOFT GLASS DESIGN SYSTEM
// ═══════════════════════════════════════════════════════════════

class SoftShadows {
  // سطح 0 - کارت روی پس‌زمینه معمولی
  static List<BoxShadow> level0 = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  // سطح 1 - کارت روی کادر رنگی
  static List<BoxShadow> level1 = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // سطح 2 - کارت با استروک
  static List<BoxShadow> level2(Color accent) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: accent.withValues(alpha: 0.12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  // سطح 4 - کادر بزرگ رنگی
  static List<BoxShadow> level4(Color accent) => [
        BoxShadow(
          color: accent.withValues(alpha: 0.25),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: accent.withValues(alpha: 0.15),
          blurRadius: 48,
          spreadRadius: 8,
        ),
      ];
}

// ═══════════════════════════════════════════════════════════════
// 🔲 CLIPPER: حفره مستطیل با گوشه‌های گرد
// ═══════════════════════════════════════════════════════════════

class _CardNotchClipper extends CustomClipper<Path> {
  final double notchWidth; // عرض حفره
  final double notchDepth; // عمق حفره
  final double notchCorner; // ✅ گردی گوشه‌های حفره
  final double notchPosition; // 0.0 = چپ, 1.0 = راست
  final bool isTop; // بالا یا پایین
  final double cornerRadius; // گردی گوشه‌های کارت

  const _CardNotchClipper({
    this.notchWidth = 80,
    this.notchDepth = 20,
    this.notchCorner = 25, // ✅ این پارامتر باید اینجا تعریف بشه
    this.notchPosition = 5.0,
    this.isTop = true,
    this.cornerRadius = 50,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final double halfWidth = notchWidth / 2;

    final double notchCenterX = (notchPosition * size.width).clamp(
      halfWidth + cornerRadius,
      size.width - halfWidth - cornerRadius,
    );

    final double notchStartX = notchCenterX - halfWidth;
    final double notchEndX = notchCenterX + halfWidth;

    // 🔑 محدود کردن گردی گوشه به نصف ابعاد حفره
    final double maxCorner = (halfWidth < notchDepth ? halfWidth : notchDepth);
    final double c = notchCorner.clamp(0.0, maxCorner);

    if (isTop) {
      // ─── شروع از گوشه بالا-چپ کارت ───
      path.moveTo(0, cornerRadius);
      path.quadraticBezierTo(0, 0, cornerRadius, 0);

      // خط بالا تا شروع حفره
      path.lineTo(notchStartX, 0);

      // ═══════════════════════════════════════════════
      // 🟦 حفره مستطیل گوشه‌گرد
      // ═══════════════════════════════════════════════

      // گوشه بالا-چپ حفره
      path.quadraticBezierTo(notchStartX, 0, notchStartX, c);

      // دیواره چپ (عمودی)
      path.lineTo(notchStartX, notchDepth - c);

      // گوشه پایین-چپ حفره
      path.quadraticBezierTo(
        notchStartX,
        notchDepth,
        notchStartX + c,
        notchDepth,
      );

      // کف حفره (افقی)
      path.lineTo(notchEndX - c, notchDepth);

      // گوشه پایین-راست حفره
      path.quadraticBezierTo(
        notchEndX,
        notchDepth,
        notchEndX,
        notchDepth - c,
      );

      // دیواره راست (عمودی)
      path.lineTo(notchEndX, c);

      // گوشه بالا-راست حفره
      path.quadraticBezierTo(notchEndX, 0, notchEndX, 0);

      // ادامه خط بالا تا گوشه بالا-راست کارت
      path.lineTo(size.width - cornerRadius, 0);
      path.quadraticBezierTo(size.width, 0, size.width, cornerRadius);

      // سمت راست کارت
      path.lineTo(size.width, size.height - cornerRadius);
      path.quadraticBezierTo(
        size.width,
        size.height,
        size.width - cornerRadius,
        size.height,
      );

      // پایین کارت
      path.lineTo(cornerRadius, size.height);
      path.quadraticBezierTo(0, size.height, 0, size.height - cornerRadius);

      // سمت چپ کارت
      path.lineTo(0, cornerRadius);
    } else {
      // ─── حفره در پایین (آینه‌ای) ───
      path.moveTo(0, cornerRadius);
      path.quadraticBezierTo(0, 0, cornerRadius, 0);

      path.lineTo(size.width - cornerRadius, 0);
      path.quadraticBezierTo(size.width, 0, size.width, cornerRadius);

      path.lineTo(size.width, size.height - cornerRadius);
      path.quadraticBezierTo(
        size.width,
        size.height,
        size.width - cornerRadius,
        size.height,
      );

      // خط پایین تا لبه راست حفره
      path.lineTo(notchEndX, size.height);

      // گوشه بالا-راست حفره (نسبت به پایین)
      path.quadraticBezierTo(
        notchEndX,
        size.height,
        notchEndX,
        size.height - c,
      );

      // دیواره راست
      path.lineTo(notchEndX, size.height - notchDepth + c);

      // گوشه پایین-راست حفره
      path.quadraticBezierTo(
        notchEndX,
        size.height - notchDepth,
        notchEndX - c,
        size.height - notchDepth,
      );

      // کف حفره
      path.lineTo(notchStartX + c, size.height - notchDepth);

      // گوشه پایین-چپ حفره
      path.quadraticBezierTo(
        notchStartX,
        size.height - notchDepth,
        notchStartX,
        size.height - notchDepth + c,
      );

      // دیواره چپ
      path.lineTo(notchStartX, size.height - c);

      // گوشه بالا-چپ حفره
      path.quadraticBezierTo(
          notchStartX, size.height, notchStartX, size.height);

      // ادامه خط پایین
      path.lineTo(cornerRadius, size.height);
      path.quadraticBezierTo(0, size.height, 0, size.height - cornerRadius);
      path.lineTo(0, cornerRadius);
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _CardNotchClipper oldClipper) {
    return oldClipper.notchWidth != notchWidth ||
        oldClipper.notchDepth != notchDepth ||
        oldClipper.notchCorner != notchCorner ||
        oldClipper.notchPosition != notchPosition ||
        oldClipper.isTop != isTop ||
        oldClipper.cornerRadius != cornerRadius;
  }
}

class _NotchedChallengeCard extends StatelessWidget {
  final Map<String, dynamic> challenge;
  final Color accentColor;
  final Color primaryColor;
  final bool isCompleted;
  final bool isActive;
  final int? participants;
  final String? progressText;
  final double? progressValue;
  final VoidCallback onTap;
  final VoidCallback? onLeave;
  final String notchLabel;
  final IconData notchIcon;
  final bool showNotch;
  final Color? fillColor;
  final bool showBorder;

  const _NotchedChallengeCard({
    required this.challenge,
    required this.accentColor,
    required this.primaryColor,
    this.isCompleted = false,
    this.isActive = false,
    this.participants,
    this.progressText,
    this.progressValue,
    required this.onTap,
    this.onLeave,
    required this.notchLabel,
    required this.notchIcon,
    this.showNotch = true,
    this.fillColor,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final challengeDuration = challenge['challenge_duration'] as int? ?? 7;
    final xpReward = challenge['xp_reward'] as int? ?? 50;
    final title = challenge['title'] ?? 'بدون عنوان';
    final isBoss = challenge['is_boss'] == true;

    // ═══════════════════════════════════════════════════════
    // 🎨 رنگ‌بندی بر اساس حالت کارت
    // ═══════════════════════════════════════════════════════

    // 🟢 کارت فعال → رنگ تم، بدون بوردر
    // ⚪ کارت موفق → پس‌زمینه سبز ملایم، بوردر سبز
    // ⚪ کارت جدید → پس‌زمینه سفید، بوردر سفید
    final Color cardColor = isActive
        ? primaryColor // ✅ رنگ تم
        : (isCompleted ? Colors.green.shade50 : Colors.white);

    final Color borderColor = isActive
        ? Colors.transparent // ✅ بدون بوردر
        : (isCompleted ? Colors.green : Colors.white);

    final double borderWidth = isActive ? 0 : 2.5; // ✅ ضخامت صفر برای فعال

    // ═══════════════════════════════════════════════════════
    // 🎛️ پارامترهای حفره
    // ═══════════════════════════════════════════════════════
    const double notchWidth = 80;
    const double notchDepth = 40;
    const double notchCorner = 20;
    const double notchRightOffset = 45;

    final double contentTopPadding = showNotch ? (notchDepth + 10) : 16;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? primaryColor.withValues(alpha: 0.30) // ✅ سایه رنگی برای فعال
                : Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ─── لایه ۱: تگ داخل حفره ───
          // ─── لایه ۱: تگ داخل حفره ───
          if (showNotch)
            Positioned(
              top: 0, // ✅ از 6 به 0
              left: 0,
              right: 0,
              height: notchDepth, // ✅ ارتفاع دقیقاً برابر عمق حفره
              child: Center(
                // ✅ وسط‌چین دقیقاً در حفره
                child: _buildNotchTag(
                  notchIcon,
                  notchLabel,
                  accentColor,
                ),
              ),
            ),

          // ─── لایه ۲: کارت ───
          showNotch
              ? ClipPath(
                  clipper: _CardNotchClipper(
                    notchWidth: notchWidth,
                    notchDepth: notchDepth,
                    notchCorner: notchCorner,
                    notchPosition: 0.5,
                    isTop: true,
                    cornerRadius: 24,
                  ),
                  child: _buildCardContent(
                    title: title,
                    challengeDuration: challengeDuration,
                    xpReward: xpReward,
                    isBoss: isBoss,
                    cardColor: cardColor, // ✅ پاس دادن رنگ
                    borderColor: borderColor, // ✅ پاس دادن رنگ بوردر
                    borderWidth: borderWidth, // ✅ پاس دادن ضخامت بوردر
                    contentTopPadding: contentTopPadding,
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: borderColor,
                      width: borderWidth,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _buildCardContent(
                      title: title,
                      challengeDuration: challengeDuration,
                      xpReward: xpReward,
                      isBoss: isBoss,
                      cardColor: cardColor,
                      borderColor: borderColor,
                      borderWidth: borderWidth,
                      contentTopPadding: contentTopPadding,
                    ),
                  ),
                ),

          // ─── لایه ۳: ناحیه کلیک ───
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      ),
    );
  }

// ═══════════════════════════════════════════════════════════
// 🎨 محتوای داخلی کارت
// ═══════════════════════════════════════════════════════════
  Widget _buildCardContent({
    required String title,
    required int challengeDuration,
    required int xpReward,
    required bool isBoss,
    required Color cardColor,
    required Color borderColor,
    required double borderWidth,
    required double contentTopPadding,
  }) {
    final bool isDarkBackground = isActive;
    final Color textColor =
        isDarkBackground ? Colors.white : const Color(0xFF090909);
    final Color subtleTextColor = isDarkBackground
        ? Colors.white.withValues(alpha: 0.85)
        : const Color(0xFF090909).withValues(alpha: 0.7);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, contentTopPadding, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ═══════════════════════════════════════════════
            // ─── ردیف اول: مدت زمان + بج‌ها ───
            // ═══════════════════════════════════════════════
            // ✅ تگ روز فقط برای کارت‌های فعال یا موفق
            if (isActive || isCompleted || isBoss) ...[
              Row(
                children: [
                  if (isActive || isCompleted)
                    _buildTag(
                      icon: Icons.timer_outlined,
                      label: '$challengeDuration روز',
                      color: isDarkBackground ? Colors.white : accentColor,
                      textColor: textColor,
                      subtleColor: subtleTextColor,
                    ),
                  const Spacer(),
                  if (isCompleted) _buildCompletedBadge(),
                  if (isBoss && !isCompleted) _buildBossBadge(),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // ─── عنوان ───
            Text(
              title,
              style: TextStyle(
                fontSize: 14, // ✅ از 16 به 14
                fontWeight: FontWeight.w600, // ✅ از bold به w600
                color: textColor,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // ─── نوار پیشرفت ───
            if (isActive && progressValue != null) ...[
              const SizedBox(height: 10),
              _buildProgressBar(progressValue!, progressText ?? ''),
            ],

            const SizedBox(height: 10),

            // ─── ردیف پایین: XP + تعداد نفرات + انصراف ───
            Row(
              children: [
                _buildXPChip(
                  xpReward,
                  isDarkBackground ? Colors.white : accentColor,
                  isCompleted,
                  textColor: textColor,
                ),
                const Spacer(),
                _buildTag(
                  icon: Icons.people,
                  label: '${participants ?? challenge['participants'] ?? 0}',
                  color: isDarkBackground ? Colors.white : accentColor,
                  textColor: textColor,
                  subtleColor: subtleTextColor,
                ),
                if (isActive && onLeave != null) ...[
                  const SizedBox(width: 6),
                  _buildLeaveButton(onLeave!),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🏷️ متدهای کمکی — همه داخل کلاس
  // ═══════════════════════════════════════════════════════════

  Widget _buildTag({
    required IconData icon,
    required String label,
    required Color color,
    Color? textColor,
    Color? subtleColor,
  }) {
    final Color finalTextColor = textColor ?? const Color(0xFF090909);
    final Color finalSubtleColor =
        subtleColor ?? const Color(0xFF090909).withValues(alpha: 0.7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: finalSubtleColor), // ✅ از 12 به 11
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9, // ✅ از 10 به 9
              fontWeight: FontWeight.w500, // ✅ از w600 به w500
              color: finalTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotchTag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        // ✅ رنگ پاستیلی ساده (بدون گرادیانت)
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildXPChip(
    int xp,
    Color color,
    bool isCompleted, {
    Color? textColor, // ✅ جدید
  }) {
    final Color finalTextColor = textColor ?? const Color(0xFF090909);
    final bool isDarkBg = finalTextColor == Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDarkBg
            ? Colors.white.withValues(alpha: 0.2) // روی پس‌زمینه رنگی
            : (isCompleted ? Colors.grey.shade200 : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.stars,
            size: 13,
            color: isDarkBg ? Colors.white : const Color(0xFFFFA500),
          ),
          const SizedBox(width: 4),
          Text(
            '+$xp XP',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDarkBg ? Colors.white : finalTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double progress, String text) {
    final bool isDarkBg = isActive;
    final Color textColor = isDarkBg ? Colors.white : const Color(0xFF73786B);
    final Color percentColor = isDarkBg ? Colors.white : accentColor;

    // ✅ رنگ نوار پیشرفت — همیشه مشکی عمیق
    const Color progressBarColor = Color(0xFF090909);

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: isDarkBg
                ? Colors.white.withValues(alpha: 0.25) // روی پس‌زمینه رنگی
                : Colors.grey.shade100,
            color: progressBarColor, // ✅ مشکی
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 10,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: percentColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLeaveButton(VoidCallback onLeave) {
    // ✅ مشکی ثابت روی کارت فعال
    const Color btnColor = Color(0xFF090909);

    return GestureDetector(
      onTap: onLeave,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 0, 0, 0), // ✅ پس‌زمینه سفید
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: btnColor, // ✅ بوردر مشکی
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15), // ✅ سایه ملایم
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'انصراف',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color.fromARGB(255, 255, 255, 255), // ✅ متن مشکی
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, size: 12, color: Colors.white),
          SizedBox(width: 3),
          Text(
            'کامل شده',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBossBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF9B59B6).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, size: 12, color: Color(0xFF9B59B6)),
          SizedBox(width: 3),
          Text(
            'باس',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF9B59B6),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 🎯 WIDGET اصلی صفحه چالش‌ها
// ═══════════════════════════════════════════════════════════════

class ChallengesTab extends StatefulWidget {
  final List<Map<String, dynamic>> challenges;
  final List<Map<String, dynamic>> myChallenges;
  final String currentUserId;
  final VoidCallback onRefresh;
  final Function(Map<String, dynamic>) joinChallenge;
  final Function(Map<String, dynamic>) leaveChallenge;
  final Function(Map<String, dynamic>) showChallengeDetails;

  const ChallengesTab({
    super.key,
    required this.challenges,
    required this.myChallenges,
    required this.currentUserId,
    required this.onRefresh,
    required this.joinChallenge,
    required this.leaveChallenge,
    required this.showChallengeDetails,
  });

  @override
  State<ChallengesTab> createState() => _ChallengesTabState();
}

class _ChallengesTabState extends State<ChallengesTab> {
  final _supabase = SupabaseService();
  int _refreshCounter = 0;
  bool _isInitialized = false;

  final Map<String, _CachedProgress> _progressCache = {};
  final Map<String, bool> _isLoadingProgress = {};
  final Map<String, _CachedValue<int>> _participantsCache = {};

  @override
  void initState() {
    super.initState();
    _checkExpiredChallenges();
  }

  @override
  void didUpdateWidget(ChallengesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.challenges != widget.challenges) {
      _progressCache.clear();
      _participantsCache.clear();
    }
  }

  Future<void> _checkExpiredChallenges() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await Future.delayed(const Duration(milliseconds: 500));
    await _supabase.checkExpiredChallenges(widget.currentUserId);

    if (mounted) {
      widget.onRefresh();
    }
  }

  Future<Map<String, int>> _getCachedProgress(String challengeId) async {
    if (_progressCache.containsKey(challengeId)) {
      final cached = _progressCache[challengeId]!;
      if (DateTime.now().difference(cached.timestamp) <
          const Duration(seconds: 30)) {
        return cached.data;
      }
    }

    if (_isLoadingProgress[challengeId] == true) {
      await Future.delayed(const Duration(milliseconds: 100));
      return _getCachedProgress(challengeId);
    }

    _isLoadingProgress[challengeId] = true;

    try {
      final result = await _supabase.getUserChallengeProgressDetails(
        widget.currentUserId,
        challengeId,
      );

      _progressCache[challengeId] = _CachedProgress(
        data: result,
        timestamp: DateTime.now(),
      );

      return result;
    } catch (e) {
      return {'completedDays': 0, 'totalDays': 0};
    } finally {
      _isLoadingProgress[challengeId] = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<int> _getCachedParticipants(String challengeId) async {
    if (_participantsCache.containsKey(challengeId)) {
      final cached = _participantsCache[challengeId]!;
      if (DateTime.now().difference(cached.timestamp) <
          const Duration(minutes: 5)) {
        return cached.value;
      }
    }

    try {
      final count = await _supabase.getRealParticipantsCount(challengeId);
      _participantsCache[challengeId] = _CachedValue(
        value: count,
        timestamp: DateTime.now(),
      );
      return count;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final Color primaryColor = themeProvider.primaryColor;

    if (widget.challenges.isEmpty) {
      return _buildEmptyState(primaryColor);
    }

    // ─── دسته‌بندی چالش‌ها ───
    final successfulChallenges = widget.challenges
        .where((c) => c['isJoined'] == true && c['isCompleted'] == true)
        .toList();

    final activeChallenges = widget.challenges
        .where(
          (c) =>
              c['isJoined'] == true &&
              c['isCompleted'] != true &&
              c['status'] != 'failed',
        )
        .toList();

    final otherChallenges =
        widget.challenges.where((c) => c['isJoined'] != true).toList();

    final availableChallenges = otherChallenges
        .where((c) => c['isRegistrationClosed'] != true)
        .toList();

    final expiredChallenges = otherChallenges
        .where((c) => c['isRegistrationClosed'] == true)
        .toList();

    final sortedChallenges = [...availableChallenges, ...expiredChallenges];

    // ─── تقسیم به دو ستون ───
    List<Map<String, dynamic>> leftColumn = [];
    List<Map<String, dynamic>> rightColumn = [];

    for (int i = 0; i < sortedChallenges.length; i++) {
      if (i % 2 == 0) {
        leftColumn.add(sortedChallenges[i]);
      } else {
        rightColumn.add(sortedChallenges[i]);
      }
    }

    return Container(
      color: const Color(0xFFF7FCEB),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── چالش‌های موفق ───
            if (successfulChallenges.isNotEmpty) ...[
              _buildSectionHeader(
                icon: Icons.emoji_events,
                title: ' چالش‌های موفق',
                color: Colors.green,
                centered: true,
              ),
              const SizedBox(height: 12),
              // ✅ اسکرول افقی کارت‌های کوچک
              SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: successfulChallenges.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: _buildSuccessCard(
                        successfulChallenges[index],
                        primaryColor,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ─── چالش‌های فعال ───
            if (activeChallenges.isNotEmpty) ...[
              _buildSectionHeader(
                icon: Icons.play_circle,
                title: ' چالش‌های فعال من',
                color: const Color(0xFF090909),
                centered: true, // ✅
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200, // ✅ ارتفاع ثابت برای یکسان بودن کارت‌ها
                child: ListView.builder(
                  scrollDirection: Axis.horizontal, // ✅ اسکرول افقی
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: activeChallenges.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: SizedBox(
                        width: 280, // ✅ عرض ثابت برای هر کارت
                        child: _buildActiveCard(
                          activeChallenges[index],
                          const Color.fromARGB(255, 108, 188, 224),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
            // ─── چالش‌های جدید (دو ستونه) ───
            if (otherChallenges.isNotEmpty) ...[
              _buildSectionHeader(
                icon: Icons.explore,
                title: ' چالش‌های جدید',
                color: const Color.fromARGB(255, 0, 0, 0),
                centered: true,
              ),
              const SizedBox(height: 12), // ✅ از 12 به 8
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: leftColumn
                          .asMap()
                          .map(
                            (index, challenge) => MapEntry(
                              index,
                              Padding(
                                // ✅ از 14 به 6
                                padding: const EdgeInsets.only(bottom: 6),
                                child: SizedBox(
                                  height: 170,
                                  child: _buildNewCard(
                                    challenge,
                                    primaryColor,
                                    index % 8,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .values
                          .toList(),
                    ),
                  ),
                  const SizedBox(width: 10), // ✅ از 12 به 10
                  Expanded(
                    child: Column(
                      children: rightColumn
                          .asMap()
                          .map(
                            (index, challenge) => MapEntry(
                              index,
                              Padding(
                                // ✅ از 14 به 6
                                padding: const EdgeInsets.only(bottom: 6),
                                child: SizedBox(
                                  height: 170,
                                  child: _buildNewCard(
                                    challenge,
                                    primaryColor,
                                    (index + leftColumn.length) % 8,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .values
                          .toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12), // ✅ از 16 به 12
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // کارت‌های تخصصی
  // ═══════════════════════════════════════════════════════════

  Widget _buildSuccessCard(Map<String, dynamic> challenge, Color primaryColor) {
    final title = challenge['title'] ?? 'چالش';
    final duration = challenge['challenge_duration'] as int? ?? 7;

    return GestureDetector(
      onTap: () => widget.showChallengeDetails(challenge),
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          // ✅ گرادیانت طلایی-نارنجی پس‌زمینه
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFDF5), // کرم خیلی روشن
              Color(0xFFFFF0C4), // طلایی کرم
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            // ✅ درخشش طلایی قوی‌تر از ماموریت
            BoxShadow(
              color: const Color(0xFFFFA500).withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
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
              // 🌟 ستاره‌های تزئینی گوشه
              // ═══════════════════════════════════════════
              SizedBox(
                height: 14,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // جرقه چپ
                    const Icon(
                      Icons.star,
                      size: 10,
                      color: Color(0xFFFFC107),
                    ),
                    const SizedBox(width: 4),
                    // جرقه میانی (بزرگ‌تر)
                    const Icon(
                      Icons.star,
                      size: 14,
                      color: Color(0xFFFFA500),
                    ),
                    const SizedBox(width: 4),
                    // جرقه راست
                    const Icon(
                      Icons.star,
                      size: 10,
                      color: Color(0xFFFFC107),
                    ),
                  ],
                ),
              ),

              // ═══════════════════════════════════════════
              // 🏆 جام طلایی
              // ═══════════════════════════════════════════
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // ✅ هاله درخشش پشت جام
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFFFD700).withValues(alpha: 0.35),
                          const Color(0xFFFFD700).withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                  // ✅ جام
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // ✅ گرادیانت طلایی براق
                      gradient: const RadialGradient(
                        center: Alignment(-0.4, -0.4),
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
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
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
                                    .withValues(alpha: 0.7),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        // ✅ آیکون جام
                        const Center(
                          child: Icon(
                            Icons.emoji_events,
                            size: 30,
                            color: Color(0xFF5D4037), // قهوه‌ای تیره
                          ),
                        ),
                        // ✨ درخشش بالا-راست
                        Positioned(
                          top: 6,
                          right: 8,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 14,
                          right: 14,
                          child: Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // ═══════════════════════════════════════════
              // 📛 پلاک نام
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
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFFF8B0),
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 4),

              // ═══════════════════════════════════════════
              // 🏅 برچسب «قهرمان»
              // ═══════════════════════════════════════════
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFA500).withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFFA500).withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.workspace_premium,
                      size: 10,
                      color: Color(0xFFE5A100),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$duration روز قهرمانی',
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB8860B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveCard(Map<String, dynamic> challenge, Color primaryColor) {
    final challengeId = challenge['id'];
    final totalDays = challenge['challenge_duration'] as int? ?? 7;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final Color primaryLight = themeProvider.primaryLight;

    // ✅ حذف dynamicGreen — استفاده مستقیم از primaryColor

    return FutureBuilder<List<dynamic>>(
      key: ValueKey('active_${challengeId}_$_refreshCounter'),
      future: Future.wait([
        _getCachedProgress(challengeId),
        _getCachedParticipants(challengeId),
      ]),
      builder: (context, snapshot) {
        int participants = 0;
        int completedDays = 0;
        int total = totalDays;
        double progress = 0.0;

        if (snapshot.hasData) {
          final progressData = snapshot.data![0] as Map<String, int>;
          participants = snapshot.data![1] as int;
          completedDays = progressData['completedDays'] ?? 0;
          total = progressData['totalDays'] ?? totalDays;
          progress = total > 0 ? completedDays / total : 0.0;
        }

        final title = challenge['title'] ?? 'بدون عنوان';
        final xpReward = challenge['xp_reward'] as int? ?? 50;

        return Container(
          decoration: BoxDecoration(
            color: primaryColor, // ✅ رنگ تم اپلیکیشن
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.30),
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
                // ─── ردیف بالا: مدت زمان ───
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 11,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$total روز',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bolt,
                            size: 11,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          const Text(
                            'فعال',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ─── عنوان ───
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.3,
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
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        color: const Color(0xFF090909),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '$completedDays از $total روز',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.stars,
                            size: 11,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '+$xpReward XP',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),

                    // ✅ دکمه مشاهده (مشکی)
                    GestureDetector(
                      onTap: () => widget.showChallengeDetails(challenge),
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

                    // ✅ دکمه حذف (primaryLight)
                    GestureDetector(
                      onTap: () => _showLeaveChallengeDialog(challenge),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 255, 255, 255),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 12,
                              color: Color(0xFF090909),
                            ),
                            SizedBox(width: 3),
                            Text(
                              'حذف',
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
      },
    );
  }

  Widget _buildNewCard(
    Map<String, dynamic> challenge,
    Color primaryColor,
    int colorIndex,
  ) {
    final challengeId = challenge['id'];
    final isExpired = challenge['isRegistrationClosed'] == true;
    final duration = challenge['challenge_duration'] as int? ?? 7;

    // 🎨 پالت رنگ‌های متنوع برای کارت‌های جدید
    final List<Color> cardColors = [
      const Color(0xFF4A90E2),
      const Color(0xFFE74C3C),
      const Color(0xFF9B59B6),
      const Color(0xFFF39C12),
      const Color(0xFF1ABC9C),
      const Color(0xFF2ECC71),
      const Color(0xFFE67E22),
      const Color(0xFF7C3AED),
    ];

    final accentColor = isExpired
        ? Colors.grey.shade400
        : cardColors[colorIndex % cardColors.length];

    return FutureBuilder<int>(
      key: ValueKey('new_${challengeId}_$_refreshCounter'),
      future: _getCachedParticipants(challengeId),
      builder: (context, snapshot) {
        return _NotchedChallengeCard(
          challenge: challenge,
          accentColor: accentColor,
          primaryColor: primaryColor,
          participants: snapshot.data,
          notchLabel: '$duration روز', // ← اینجا تغییر کرد
          notchIcon: Icons.calendar_today, // ← آیکون تقویم
          onTap: () => widget.showChallengeDetails(challenge),
        );
      },
    );
  }
  // ═══════════════════════════════════════════════════════════
  // بخش‌های صفحه
  // ═══════════════════════════════════════════════════════════

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
    bool centered = false, // ✅ پارامتر جدید
  }) {
    if (centered) {
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDailySpark(Color primaryColor) {
    final List<Map<String, dynamic>> sparks = [
      {
        'type': 'quote',
        'text':
            'تنها محدودیتی که دارید، محدودیتی است که خودتان در ذهنتان ایجاد می‌کنید.',
        'author': 'نپلئون هیل',
      },
      {
        'type': 'quote',
        'text': 'موفقیت مجموع تلاش‌های کوچکی است که روز به روز تکرار می‌شوند.',
        'author': 'رابرت کالیر',
      },
      {
        'type': 'challenge',
        'text': 'امروز ۱۰ دقیقه بدون گوشی وقت بگذران',
        'author': '',
      },
      {
        'type': 'fact',
        'text': 'عادت‌های جدید به طور متوسط ۶۶ روز طول می‌کشند تا شکل بگیرند.',
        'author': 'تحقیقات دانشگاه کالج لندن',
      },
      {
        'type': 'quote',
        'text': 'با انجام کارهای کوچک هر روز، می‌توانید به نتایج بزرگ برسید.',
        'author': 'لائوتسه',
      },
    ];

    final spark = sparks[DateTime.now().day % sparks.length];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFB347).withValues(alpha: 0.9),
            const Color(0xFFFF6B6B).withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B6B).withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              spark['type'] == 'quote'
                  ? Icons.format_quote
                  : spark['type'] == 'challenge'
                      ? Icons.bolt
                      : Icons.lightbulb,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spark['type'] == 'quote'
                      ? '✨ جرقه روزانه'
                      : spark['type'] == 'challenge'
                          ? '⚡ چالش روزانه'
                          : '💡 واقعیت علمی',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  spark['text'] ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                if (spark['author'] != null &&
                    spark['author'].toString().isNotEmpty)
                  Text(
                    '- ${spark['author']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color primaryColor) {
    return Container(
      color: const Color(0xFFF7FCEB),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.emoji_events_outlined,
                size: 64,
                color: primaryColor.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'هنوز چالشی وجود ندارد',
              style: TextStyle(
                color: Color(0xFF73786B),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'برای اضافه شدن چالش‌های جدید منتظر بمانید',
              style: TextStyle(color: Color(0xFF73786B), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showLeaveChallengeDialog(Map<String, dynamic> challenge) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('انصراف از چالش'),
        content: Text(
          'آیا از انصراف از چالش "${challenge['title']}" مطمئن هستید؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.leaveChallenge(challenge);
            },
            child: const Text(
              'بله، انصراف',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// مدل‌های کش
// ═══════════════════════════════════════════════════════════════

class _CachedProgress {
  final Map<String, int> data;
  final DateTime timestamp;

  _CachedProgress({required this.data, required this.timestamp});
}

class _CachedValue<T> {
  final T value;
  final DateTime timestamp;

  _CachedValue({required this.value, required this.timestamp});
}
