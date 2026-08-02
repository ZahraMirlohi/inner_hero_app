// lib/features/chat/screens/user_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/services/chat_service.dart';

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
      // ✅ دریافت اطلاعات کاربر از دیتابیس
      final profile = await _chatService.client
          .from('profiles')
          .select('''
            name,
            email,
            phone,
            bio,
            avatar_url,
            total_xp,
            current_streak,
            best_streak,
            created_at
          ''')
          .eq('user_id', widget.userId)
          .maybeSingle();

      if (profile != null) {
        // ✅ دریافت اطلاعات شخصیت کاربر
        final personality = await _chatService.client
            .from('user_personalities')
            .select('''
              gender,
              mbti_type,
              interests,
              goals,
              bio
            ''')
            .eq('user_id', widget.userId)
            .maybeSingle();

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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'اطلاعات کاربر',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A2E),
        centerTitle: true,
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
          ? _buildErrorState()
          : _buildProfileContent(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF4A90E2), strokeWidth: 2),
          SizedBox(height: 16),
          Text(
            'در حال بارگذاری اطلاعات...',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadUserData,
            icon: const Icon(Icons.refresh),
            label: const Text('تلاش مجدد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
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
          ),
          const SizedBox(height: 16),

          // ✅ آمار کاربر
          _buildStatsCard(
            totalXp: totalXp,
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            createdAt: createdAt,
          ),
          const SizedBox(height: 16),

          // ✅ اطلاعات شخصیت
          if (mbtiType != null || interests.isNotEmpty || goals.isNotEmpty)
            _buildPersonalityCard(
              mbtiType: mbtiType,
              interests: interests,
              goals: goals,
            ),
          const SizedBox(height: 16),

          // ✅ دکمه شروع گفتگو
          _buildActionButtons(),
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
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ✅ آواتار
          CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFF4A90E2).withValues(alpha: 0.1),
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? Text(
                    name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A90E2),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),

          // ✅ نام
          Text(
            name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
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
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  email,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  phone,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),

          // ✅ بیو
          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                bio,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
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

  Widget _buildStatsCard({
    required int totalXp,
    required int currentStreak,
    required int bestStreak,
    required DateTime createdAt,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
            color: const Color(0xFFFFA500),
          ),
          _buildStatItem(
            icon: Icons.local_fire_department,
            label: 'استریک فعلی',
            value: '$currentStreak روز',
            color: const Color(0xFFE74C3C),
          ),
          _buildStatItem(
            icon: Icons.emoji_events,
            label: 'بهترین استریک',
            value: '$bestStreak روز',
            color: const Color(0xFF9B59B6),
          ),
          _buildStatItem(
            icon: Icons.cake,
            label: 'عضو از',
            value: _formatDate(createdAt),
            color: const Color(0xFF4A90E2),
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
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }

  Widget _buildPersonalityCard({
    String? mbtiType,
    List<dynamic>? interests,
    List<dynamic>? goals,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology, color: Color(0xFF9B59B6), size: 20),
              SizedBox(width: 8),
              Text(
                'شخصیت',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (mbtiType != null && mbtiType.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'MBTI: $mbtiType',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4A90E2),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (interests != null && interests.isNotEmpty) ...[
            const Text(
              'علاقه‌مندی‌ها:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 4),
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
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    interest.toString(),
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          if (goals != null && goals.isNotEmpty) ...[
            const Text(
              'اهداف:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 4),
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
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    goal.toString(),
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pop(context);
        },
        icon: const Icon(Icons.arrow_back, size: 18),
        label: const Text(
          'بازگشت به گفتگو',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4A90E2),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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
