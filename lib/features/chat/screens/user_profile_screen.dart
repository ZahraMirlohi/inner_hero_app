// lib/features/chat/screens/user_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '/services/chat_service.dart';
import '/services/supabase_service.dart';
import '/providers/theme_provider.dart';
import '/features/profile/models/user_photo_model.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String? userName;
  final String? userAvatar;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.userName,
    this.userAvatar,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final ChatService _chatService = ChatService();
  final SupabaseService _supabase = SupabaseService();
  Map<String, dynamic>? _userData;
  List<UserPhoto> _photos = [];
  bool _isLoading = true;
  bool _isLoadingPhotos = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _chatService.client.from('profiles').select('''
    name, username, bio, avatar_url,
    total_xp, current_streak, best_streak, created_at
  ''').eq('user_id', widget.userId).maybeSingle();

      if (!mounted) return;

      if (profile != null) {
        final personality = await _chatService.client
            .from('user_personalities')
            .select('gender, mbti_type, interests, goals, bio')
            .eq('user_id', widget.userId)
            .maybeSingle();

        if (!mounted) return;

        setState(() {
          _userData = {'profile': profile, 'personality': personality ?? {}};
          _isLoading = false;
        });

        // ✅ بارگذاری عکس‌های گالری (بعد از profile)
        _loadUserPhotos();
      } else {
        setState(() {
          _errorMessage = 'اطلاعات کاربر یافت نشد';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'خطا در بارگذاری اطلاعات: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // ✅ بارگذاری عکس‌های گالری
  Future<void> _loadUserPhotos() async {
    if (!mounted) return;

    setState(() => _isLoadingPhotos = true);

    try {
      final photos = await _supabase.getUserPhotos(
        widget.userId,
        visibleOnly: true,
      );

      if (!mounted) return;

      setState(() {
        _photos = photos;
        _isLoadingPhotos = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingPhotos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'اطلاعات کاربر',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.textColor,
          ),
        ),
        backgroundColor: theme.surfaceColor,
        elevation: 0,
        foregroundColor: theme.textColor,
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState(primaryColor)
            : _errorMessage != null
                ? _buildErrorState(theme, primaryColor)
                : _buildProfileContent(theme, primaryColor),
      ),
    );
  }

  Widget _buildLoadingState(Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: primaryColor, strokeWidth: 2),
          const SizedBox(height: 16),
          const Text(
            'در حال بارگذاری اطلاعات...',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeProvider theme, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(fontSize: 14, color: theme.textSecondaryColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadUserData,
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text(
              'تلاش مجدد',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(ThemeProvider theme, Color primaryColor) {
    final profile = _userData!['profile'] as Map<String, dynamic>;
    final personality =
        _userData!['personality'] as Map<String, dynamic>? ?? {};

    final name = profile['name'] as String? ?? 'کاربر';
    final avatarUrl = profile['avatar_url'] as String?;
    final username = profile['username'] as String?;
    final bio = profile['bio'] as String? ?? personality['bio'] as String?;
    final totalXp = profile['total_xp'] as int? ?? 0;
    final currentStreak = profile['current_streak'] as int? ?? 0;
    final bestStreak = profile['best_streak'] as int? ?? 0;
    final createdAt = profile['created_at'] != null
        ? DateTime.parse(profile['created_at'])
        : DateTime.now();
    final mbtiType = personality['mbti_type'] as String?;
    final interests = personality['interests'] as List? ?? [];
    final goals = personality['goals'] as List? ?? [];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        children: [
          // ✅ کارت اصلی پروفایل
          _buildProfileCard(
            name: name,
            avatarUrl: avatarUrl,
            username: username,
            bio: bio,
            theme: theme,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 16),

          // ✅ گالری عکس‌ها (جدید)
          _buildGallerySection(theme, primaryColor),

          const SizedBox(height: 16),

          // ✅ آمار کاربر
          _buildStatsCard(
            totalXp: totalXp,
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            createdAt: createdAt,
            theme: theme,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 16),

          // ✅ اطلاعات شخصیت
          if (mbtiType != null || interests.isNotEmpty || goals.isNotEmpty)
            _buildPersonalityCard(
              mbtiType: mbtiType,
              interests: interests,
              goals: goals,
              theme: theme,
              primaryColor: primaryColor,
            ),
          const SizedBox(height: 16),

          // ✅ دکمه بازگشت
          _buildActionButtons(primaryColor),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📸 بخش گالری عکس‌ها (جدید)
  // ═══════════════════════════════════════════════════════════
  Widget _buildGallerySection(ThemeProvider theme, Color primaryColor) {
    // اگر در حال بارگذاری است
    if (_isLoadingPhotos) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.surfaceColor,
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
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.photo_library,
                    color: primaryColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'گالری',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: primaryColor,
                  strokeWidth: 2,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      );
    }

    // اگر عکسی وجود ندارد
    if (_photos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.surfaceColor,
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.photo_library,
                    color: primaryColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'گالری',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 48,
                      color: theme.textSecondaryColor.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'هنوز عکسی آپلود نکرده',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // نمایش گالری
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
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
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.photo_library,
                  color: primaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'گالری',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_photos.length} عکس',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Grid عکس‌ها
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _photos.length,
            itemBuilder: (context, index) {
              final photo = _photos[index];
              return _buildPhotoTile(photo, index, theme, primaryColor);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoTile(
    UserPhoto photo,
    int index,
    ThemeProvider theme,
    Color primaryColor,
  ) {
    return GestureDetector(
      onTap: () => _openPhotoViewer(index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: photo.photoUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: theme.isDarkMode
                    ? const Color(0xFF2A2A2A)
                    : Colors.grey.shade200,
                child: Icon(
                  Icons.image,
                  color: theme.textSecondaryColor,
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: theme.isDarkMode
                    ? const Color(0xFF2A2A2A)
                    : Colors.grey.shade200,
                child: Icon(
                  Icons.broken_image,
                  color: theme.textSecondaryColor,
                ),
              ),
            ),
            // کپشن
            if (photo.caption != null && photo.caption!.isNotEmpty)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: Text(
                    photo.caption!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            // لایک
            if (photo.likesCount > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 10,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${photo.likesCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // badge primary
            if (photo.isPrimary)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star,
                    color: Colors.white,
                    size: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openPhotoViewer(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ProfilePhotoViewer(
          photos: _photos,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Widget _buildProfileCard({
    required String name,
    String? username,
    String? avatarUrl,
    String? bio,
    required ThemeProvider theme,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
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
        children: [
          // ✅ آواتار
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor.withValues(alpha: 0.15),
              border: Border.all(color: primaryColor, width: 3),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: avatarUrl != null && avatarUrl.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _buildAvatarInitial(
                        name,
                        primaryColor,
                      ),
                      errorWidget: (_, __, ___) => _buildAvatarInitial(
                        name,
                        primaryColor,
                      ),
                    ),
                  )
                : _buildAvatarInitial(name, primaryColor),
          ),
          const SizedBox(height: 16),

          // ✅ نام
          Text(
            name,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),

          // ✅ یوزرنیم (به جای ایمیل و شماره)
          if (username != null && username.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.alternate_email,
                    size: 14,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    username,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ✅ بیو
          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Text(
                bio,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.textColor,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatarInitial(String name, Color primaryColor) {
    return Center(
      child: Text(
        name.substring(0, 1).toUpperCase(),
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
      ),
    );
  }

  Widget _buildStatsCard({
    required int totalXp,
    required int currentStreak,
    required int bestStreak,
    required DateTime createdAt,
    required ThemeProvider theme,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.stars,
            label: 'XP',
            value: totalXp.toString(),
            color: primaryColor,
            theme: theme,
          ),
          _buildStatItem(
            icon: Icons.local_fire_department,
            label: 'استریک فعلی',
            value: '$currentStreak روز',
            color: primaryColor,
            theme: theme,
          ),
          _buildStatItem(
            icon: Icons.emoji_events,
            label: 'بهترین استریک',
            value: '$bestStreak روز',
            color: primaryColor,
            theme: theme,
          ),
          _buildStatItem(
            icon: Icons.cake,
            label: 'عضو از',
            value: _formatDate(createdAt),
            color: primaryColor,
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required ThemeProvider theme,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: theme.textColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: theme.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalityCard({
    String? mbtiType,
    List<dynamic>? interests,
    List<dynamic>? goals,
    required ThemeProvider theme,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.psychology,
                  color: primaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'شخصیت',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (mbtiType != null && mbtiType.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'MBTI: $mbtiType',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (interests != null && interests.isNotEmpty) ...[
            Text(
              'علاقه‌مندی‌ها:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: interests.map((interest) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    interest.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      color: primaryColor,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
          if (goals != null && goals.isNotEmpty) ...[
            Text(
              'اهداف:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: goals.map((goal) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    goal.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      color: primaryColor,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(Color primaryColor) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pop(context);
        },
        icon: const Icon(Icons.arrow_back, size: 18, color: Colors.white),
        label: const Text(
          'بازگشت به گفتگو',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'امروز';
    } else if (diff.inDays == 1) {
      return 'دیروز';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} روز پیش';
    } else if (diff.inDays < 30) {
      return '${diff.inDays ~/ 7} هفته پیش';
    } else if (diff.inDays < 365) {
      return '${diff.inDays ~/ 30} ماه پیش';
    } else {
      return '${diff.inDays ~/ 365} سال پیش';
    }
  }
}

// ═══════════════════════════════════════════════════════════
// 📷 Photo Viewer (نمایش تمام‌صفحه)
// ═══════════════════════════════════════════════════════════
class _ProfilePhotoViewer extends StatefulWidget {
  final List<UserPhoto> photos;
  final int initialIndex;

  const _ProfilePhotoViewer({
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<_ProfilePhotoViewer> createState() => _ProfilePhotoViewerState();
}

class _ProfilePhotoViewerState extends State<_ProfilePhotoViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final currentPhoto = widget.photos[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.photos.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            pageController: _pageController,
            itemCount: widget.photos.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            builder: (context, index) {
              final photo = widget.photos[index];
              return PhotoViewGalleryPageOptions(
                imageProvider: CachedNetworkImageProvider(photo.photoUrl),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
              );
            },
            loadingBuilder: (context, event) => Center(
              child: CircularProgressIndicator(
                color: theme.primaryColor,
              ),
            ),
          ),
          // کپشن پایین
          if (currentPhoto.caption != null && currentPhoto.caption!.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: Text(
                  currentPhoto.caption!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
