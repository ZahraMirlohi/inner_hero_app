// lib/features/explore/screens/leaderboard_tab.dart
import 'package:flutter/material.dart';
import '/services/supabase_service.dart';

class LeaderboardTab extends StatefulWidget {
  const LeaderboardTab({super.key});

  @override
  State<LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<LeaderboardTab> {
  final SupabaseService _supabase = SupabaseService();
  List<Map<String, dynamic>> _leaders = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String? _currentUserId;
  int _currentUserRank = 0;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final currentUser = await _supabase.getCurrentUser();
      _currentUserId = currentUser?.id;

      // دریافت لیست کاربران با بیشترین XP از user_progress
      final users = await _getTopUsers();

      // دریافت مدال‌های هر کاربر
      for (var user in users) {
        final badges = await _getUserBadges(user['user_id']);
        user['badges'] = badges;
        user['badgeCount'] = badges.length;
      }

      // مرتب‌سازی بر اساس XP (نزولی) و سپس تعداد مدال
      users.sort((a, b) {
        final xpA = (a['total_xp'] ?? 0) as int;
        final xpB = (b['total_xp'] ?? 0) as int;
        if (xpB != xpA) return xpB.compareTo(xpA);
        return (b['badgeCount'] ?? 0).compareTo(a['badgeCount'] ?? 0);
      });

      // افزودن رتبه
      for (int i = 0; i < users.length; i++) {
        users[i]['rank'] = i + 1;
        if (users[i]['user_id'] == _currentUserId) {
          _currentUserRank = i + 1;
        }
      }

      if (mounted) {
        setState(() {
          _leaders = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'خطا در بارگذاری: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getTopUsers() async {
    try {
      // 1. ابتدا سعی می‌کنیم از user_progress دریافت کنیم
      final response = await _supabase.client
          .from('user_progress')
          .select('user_id, total_xp')
          .order('total_xp', ascending: false)
          .limit(100);

      if (response.isNotEmpty) {
        // دریافت نام کاربران از profiles
        List<Map<String, dynamic>> users = [];
        for (var item in response) {
          final userId = item['user_id'];
          final profile = await _getUserProfile(userId);
          users.add({
            'user_id': userId,
            'name': profile?['name'] ?? 'کاربر ${userId.substring(0, 6)}',
            'total_xp': item['total_xp'] ?? 0,
            'avatar_url': profile?['avatar_url'],
          });
        }
        return users;
      }
    } catch (e) {
      print('Error getting from user_progress: $e');
    }

    // 2. اگر user_progress خالی بود، از profiles استفاده کن
    try {
      final response = await _supabase.client
          .from('profiles')
          .select('user_id, name, total_xp, avatar_url')
          .order('total_xp', ascending: false)
          .limit(100);

      if (response.isNotEmpty) {
        return List<Map<String, dynamic>>.from(response);
      }
    } catch (e) {
      print('Error getting from profiles: $e');
    }

    // 3. اگر هیچکدام نبود، داده‌های نمونه برگردان
    return _getSampleUsers();
  }

  Future<Map<String, dynamic>?> _getUserProfile(String userId) async {
    try {
      final response = await _supabase.client
          .from('profiles')
          .select('name, avatar_url')
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _getUserBadges(String userId) async {
    try {
      final response = await _supabase.client
          .from('user_badges')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true);

      if (response.isNotEmpty) {
        return List<Map<String, dynamic>>.from(response);
      }
    } catch (e) {
      // جدول وجود ندارد یا خطا
    }

    // داده‌های نمونه بر اساس XP کاربر
    return _getSampleBadges(userId);
  }

  List<Map<String, dynamic>> _getSampleBadges(String userId) {
    // تعداد مدال‌ها بر اساس هش userId (برای تنوع)
    final count = (userId.hashCode.abs() % 4) + 1;
    final allBadges = [
      {'badge_name': '🥇 طلایی', 'badge_icon': '🥇'},
      {'badge_name': '🔥 آتشین', 'badge_icon': '🔥'},
      {'badge_name': '⭐ ستاره', 'badge_icon': '⭐'},
      {'badge_name': '💪 قدرتمند', 'badge_icon': '💪'},
      {'badge_name': '🎯 هدف‌گذار', 'badge_icon': '🎯'},
      {'badge_name': '🏆 قهرمان', 'badge_icon': '🏆'},
    ];
    return allBadges.take(count).toList();
  }

  List<Map<String, dynamic>> _getSampleUsers() {
    final sampleUsers = [
      {'user_id': 'user_1', 'name': 'رضا قهرمان', 'total_xp': 12500},
      {'user_id': 'user_2', 'name': 'سارا توانا', 'total_xp': 10800},
      {'user_id': 'user_3', 'name': 'علی پهلوان', 'total_xp': 9200},
      {'user_id': 'user_4', 'name': 'مریم دانا', 'total_xp': 8500},
      {'user_id': 'user_5', 'name': 'حسین متین', 'total_xp': 7800},
    ];

    return sampleUsers
        .map((user) => {...user, 'avatar_url': null, 'badgeCount': 0})
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _errorMessage.isNotEmpty
                ? _buildErrorState()
                : _leaders.isEmpty
                ? _buildEmptyState()
                : _buildLeaderboardList(),
          ),
        ],
      ),
    );
  }

  // ==================== هدر ====================

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF2563EB),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.emoji_events, color: Colors.white, size: 32),
              SizedBox(width: 12),
              Text(
                'تالار افتخارات',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'بهترین قهرمانان اپلیکیشن',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          if (_currentUserRank > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stars, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'رتبه شما: #$_currentUserRank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== لیست رتبه‌بندی ====================

  Widget _buildLeaderboardList() {
    return RefreshIndicator(
      onRefresh: _loadLeaderboard,
      color: const Color(0xFF2563EB),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _leaders.length,
        itemBuilder: (context, index) {
          final user = _leaders[index];
          final rank = user['rank'] ?? index + 1;
          final isCurrentUser = user['user_id'] == _currentUserId;

          return _buildLeaderCard(user, rank, isCurrentUser);
        },
      ),
    );
  }

  Widget _buildLeaderCard(
    Map<String, dynamic> user,
    int rank,
    bool isCurrentUser,
  ) {
    final Color cardColor;
    final Color rankColor;
    final String rankEmoji;
    final int xp = (user['total_xp'] ?? 0) as int;

    if (rank == 1) {
      cardColor = const Color(0xFFFFD700).withOpacity(0.15);
      rankColor = const Color(0xFFFFD700);
      rankEmoji = '🥇';
    } else if (rank == 2) {
      cardColor = const Color(0xFFC0C0C0).withOpacity(0.15);
      rankColor = const Color(0xFFC0C0C0);
      rankEmoji = '🥈';
    } else if (rank == 3) {
      cardColor = const Color(0xFFCD7F32).withOpacity(0.15);
      rankColor = const Color(0xFFCD7F32);
      rankEmoji = '🥉';
    } else {
      cardColor = isCurrentUser
          ? const Color(0xFF2563EB).withOpacity(0.08)
          : Colors.white;
      rankColor = const Color(0xFF6B7280);
      rankEmoji = '';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isCurrentUser
            ? Border.all(color: const Color(0xFF2563EB), width: 2)
            : Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // رتبه
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: rank <= 3
                    ? rankColor.withOpacity(0.2)
                    : const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: rank <= 3
                    ? Text(rankEmoji, style: const TextStyle(fontSize: 22))
                    : Text(
                        rank.toString(),
                        style: TextStyle(
                          color: rankColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),

            // آواتار
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2563EB).withOpacity(0.1),
              ),
              child:
                  user['avatar_url'] != null &&
                      user['avatar_url'].toString().isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        user['avatar_url'],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person,
                          color: Color(0xFF2563EB),
                          size: 28,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.person,
                      color: Color(0xFF2563EB),
                      size: 28,
                    ),
            ),
            const SizedBox(width: 14),

            // نام و مدال‌ها
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user['name'] ?? 'کاربر',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isCurrentUser
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: isCurrentUser
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF1A1A2E),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'شما',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // مدال‌ها
                  if (user['badges'] != null &&
                      (user['badges'] as List).isNotEmpty)
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: (user['badges'] as List).take(5).map((badge) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            badge['badge_icon'] ?? '🏅',
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),

            // XP
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFA500).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stars, size: 16, color: Color(0xFFFFA500)),
                  const SizedBox(width: 6),
                  Text(
                    '$xp',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFA500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== حالت‌های مختلف ====================

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF2563EB)),
          SizedBox(height: 16),
          Text(
            'در حال بارگذاری تالار افتخارات...',
            style: TextStyle(color: Color(0xFF6B7280)),
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
            _errorMessage,
            style: const TextStyle(color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadLeaderboard,
            icon: const Icon(Icons.refresh),
            label: const Text('تلاش مجدد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'تالار افتخارات خالی است',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'با انجام عادت‌ها و تسک‌ها XP جمع‌آوری کنید',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadLeaderboard,
            icon: const Icon(Icons.refresh),
            label: const Text('بروزرسانی'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
