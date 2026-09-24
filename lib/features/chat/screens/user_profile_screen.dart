// lib/features/chat/screens/user_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/services/chat_service.dart';
import '/providers/theme_provider.dart';

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
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _chatService.client.from('profiles').select('''
            name,
            email,
            phone,
            bio,
            avatar_url,
            total_xp,
            current_streak,
            best_streak,
            created_at
          ''').eq('user_id', widget.userId).maybeSingle();

      if (profile != null) {
        final personality =
            await _chatService.client.from('user_personalities').select('''
              gender,
              mbti_type,
              interests,
              goals,
              bio
            ''').eq('user_id', widget.userId).maybeSingle();

        setState(() {
          _userData = {'profile': profile, 'personality': personality ?? {}};
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'اطلاعات کاربر یافت نشد';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'خطا در بارگذاری اطلاعات: ${e.toString()}';
        _isLoading = false;
      });
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
      body: _isLoading
          ? _buildLoadingState(primaryColor)
          : _errorMessage != null
              ? _buildErrorState(theme, primaryColor)
              : _buildProfileContent(theme, primaryColor),
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
    final email = profile['email'] as String?;
    final phone = profile['phone'] as String?;
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
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ✅ کارت اصلی پروفایل
          _buildProfileCard(
            name: name,
            avatarUrl: avatarUrl,
            email: email,
            phone: phone,
            bio: bio,
            theme: theme,
            primaryColor: primaryColor,
          ),
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

  Widget _buildProfileCard({
    required String name,
    String? avatarUrl,
    String? email,
    String? phone,
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
                    child: Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildAvatarInitial(
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
          const SizedBox(height: 4),

          // ✅ ایمیل
          if (email != null && email.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.email_outlined,
                  size: 14,
                  color: theme.textSecondaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.textSecondaryColor,
                  ),
                ),
              ],
            ),

          // ✅ تلفن
          if (phone != null && phone.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.phone_outlined,
                  size: 14,
                  color: theme.textSecondaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  phone,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.textSecondaryColor,
                  ),
                ),
              ],
            ),

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
