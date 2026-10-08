// lib/features/explore/screens/leaderboard_tab.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/services/supabase_service.dart';
import '/providers/theme_provider.dart';

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

      final users = await _getTopUsers();

      for (var user in users) {
        final badges = await _getUserBadges(user['user_id']);
        user['badges'] = badges;
        user['badgeCount'] = badges.length;
      }

      users.sort((a, b) {
        final xpA = (a['total_xp'] ?? 0) as int;
        final xpB = (b['total_xp'] ?? 0) as int;
        if (xpB != xpA) return xpB.compareTo(xpA);
        return (b['badgeCount'] ?? 0).compareTo(a['badgeCount'] ?? 0);
      });

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
      final response = await _supabase.client
          .from('user_progress')
          .select('user_id, total_xp')
          .order('total_xp', ascending: false)
          .limit(100);

      if (response.isNotEmpty) {
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
    } catch (e) {}
    return _getSampleBadges(userId);
  }

  List<Map<String, dynamic>> _getSampleBadges(String userId) {
    final count = (userId.hashCode.abs() % 4) + 1;
    final allBadges = [
      {'badge_name': '🥇 طلایی', 'badge_icon': '🥇'},
      {'badge_name': '🔥 آتشین', 'badge_icon': '🔥'},
      {'badge_name': '⭐ ستاره', 'badge_icon': '⭐'},
      {'badge_name': '💪 قدرتمند', 'badge_icon': '💪'},
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
    final theme = Provider.of<ThemeProvider>(context);
    final Color primaryColor = theme.primaryColor;

    return Container(
      color: theme.backgroundColor,
      child: Column(
        children: [
          const SizedBox(height: 100),
          _buildHeader(primaryColor, theme),
          Expanded(
            child: _isLoading
                ? _buildLoadingState(primaryColor, theme)
                : _errorMessage.isNotEmpty
                    ? _buildErrorState(primaryColor, theme)
                    : _leaders.isEmpty
                        ? _buildEmptyState(primaryColor, theme)
                        : _buildLeaderboardList(primaryColor, theme),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // هدر (طلایی نارنجی)
  // ═══════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════
// هدر (طلایی نارنجی) - تم‌محور
// ═══════════════════════════════════════════════════════════
  Widget _buildHeader(Color primaryColor, ThemeProvider theme) {
    // ✅ در تم شب از گرادیانت تیره استفاده کن
    final List<Color> headerGradient = theme.isDarkMode
        ? [
            const Color(0xFF8B5A0F), // طلایی-نارنجی تیره
            const Color(0xFF6B4410), // نارنجی قهوه‌ای
          ]
        : [
            const Color(0xFFFFD966), // روشن
            const Color(0xFFFFBF35), // طلایی اصلی
          ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: headerGradient,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.isDarkMode
                ? Colors.black.withValues(alpha: 0.4)
                : const Color(0xFFFFBF35).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'تالار افتخارات',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'بهترین قهرمانان اپلیکیشن',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (_currentUserRank > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.stars,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'رتبه شما: $_currentUserRank',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList(Color primaryColor, ThemeProvider theme) {
    final top3 = _leaders.take(3).toList();
    final rest = _leaders.skip(3).toList();

    return RefreshIndicator(
      onRefresh: _loadLeaderboard,
      color: primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 100, bottom: 120),
        child: Column(
          children: [
            if (top3.isNotEmpty) _buildPodium(top3, primaryColor, theme),
            if (rest.isNotEmpty) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildRestHeader(rest.length, theme),
              ),
              const SizedBox(height: 12),
              ...rest
                  .map((user) => _buildLeaderCard(user, primaryColor, theme)),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // سکوی سه‌نفره
  // ═══════════════════════════════════════════════════════════
  Widget _buildPodium(
    List<Map<String, dynamic>> top3,
    Color primaryColor,
    ThemeProvider theme,
  ) {
    final first = top3.isNotEmpty ? top3[0] : null;
    final second = top3.length > 1 ? top3[1] : null;
    final third = top3.length > 2 ? top3[2] : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.isDarkMode ? 0.3 : 0.06,
            ),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (second != null)
            Expanded(
              child: _buildPodiumItem(
                user: second,
                rank: 2,
                primaryColor: primaryColor,
                emoji: '🥈',
                height: 115,
                isCurrentUser: second['user_id'] == _currentUserId,
              ),
            ),
          const SizedBox(width: 8),
          if (first != null)
            Expanded(
              child: _buildPodiumItem(
                user: first,
                rank: 1,
                primaryColor: primaryColor,
                emoji: '🥇',
                height: 145,
                isCurrentUser: first['user_id'] == _currentUserId,
              ),
            ),
          const SizedBox(width: 8),
          if (third != null)
            Expanded(
              child: _buildPodiumItem(
                user: third,
                rank: 3,
                primaryColor: primaryColor,
                emoji: '🥉',
                height: 100,
                isCurrentUser: third['user_id'] == _currentUserId,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPodiumItem({
    required Map<String, dynamic> user,
    required int rank,
    required Color primaryColor,
    required String emoji,
    required double height,
    required bool isCurrentUser,
  }) {
    final xp = (user['total_xp'] ?? 0) as int;
    final name = user['name'] ?? 'کاربر';
    final avatarUrl = user['avatar_url'];

    final double opacity;
    if (rank == 1) {
      opacity = 1.0;
    } else if (rank == 2) {
      opacity = 0.85;
    } else {
      opacity = 0.7;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: rank == 1 ? 64 : 54,
              height: rank == 1 ? 64 : 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: primaryColor, width: 3),
                color: primaryColor.withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: avatarUrl != null && avatarUrl.toString().isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.person,
                          color: primaryColor,
                          size: rank == 1 ? 32 : 26,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.person,
                      color: primaryColor,
                      size: rank == 1 ? 32 : 26,
                    ),
            ),
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Text(
                  emoji,
                  style: TextStyle(fontSize: rank == 1 ? 18 : 15),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: isCurrentUser
                ? Border.all(
                    color: Color(0xFF090909),
                    width: 2.5,
                  )
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color.fromARGB(255, 0, 0, 0),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stars, size: 10, color: Colors.white),
                  const SizedBox(width: 3),
                  Text(
                    '$xp',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRestHeader(int count, ThemeProvider theme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.textColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.format_list_numbered,
            color: theme.textColor,
            size: 16,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'سایر قهرمانان',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: theme.textColor,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: theme.textColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: theme.textColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderCard(
    Map<String, dynamic> user,
    Color primaryColor,
    ThemeProvider theme,
  ) {
    final rank = user['rank'] ?? 0;
    final isCurrentUser = user['user_id'] == _currentUserId;
    final xp = (user['total_xp'] ?? 0) as int;
    final name = user['name'] ?? 'کاربر';
    final avatarUrl = user['avatar_url'];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: isCurrentUser ? primaryColor : theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrentUser ? Colors.transparent : theme.cardColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrentUser
                ? primaryColor.withValues(alpha: 0.30)
                : Colors.black.withValues(
                    alpha: theme.isDarkMode ? 0.3 : 0.06,
                  ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? Colors.white.withValues(alpha: 0.25)
                    : theme.textColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isCurrentUser ? Colors.white : theme.textColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCurrentUser
                    ? Colors.white.withValues(alpha: 0.25)
                    : primaryColor.withValues(alpha: 0.1),
              ),
              child: avatarUrl != null && avatarUrl.toString().isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.person,
                          color: isCurrentUser ? Colors.white : primaryColor,
                          size: 24,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.person,
                      color: isCurrentUser ? Colors.white : primaryColor,
                      size: 24,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isCurrentUser
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color:
                                isCurrentUser ? Colors.white : theme.textColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'شما',
                            style: TextStyle(
                              fontSize: 9,
                              color: primaryColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? Colors.white.withValues(alpha: 0.25)
                    : const Color(0xFFFFA500).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.stars,
                    size: 13,
                    color:
                        isCurrentUser ? Colors.white : const Color(0xFFFFA500),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$xp',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isCurrentUser
                          ? Colors.white
                          : const Color(0xFFFFA500),
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

  Widget _buildLoadingState(Color primaryColor, ThemeProvider theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: primaryColor),
          const SizedBox(height: 16),
          Text(
            'در حال بارگذاری تالار افتخارات...',
            style: TextStyle(
              color: theme.textSecondaryColor,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Color primaryColor, ThemeProvider theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textSecondaryColor),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadLeaderboard,
            icon: const Icon(Icons.refresh),
            label: const Text('تلاش مجدد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color primaryColor, ThemeProvider theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 80,
            color: theme.textSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'تالار افتخارات خالی است',
            style: TextStyle(
              color: theme.textSecondaryColor,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'با انجام عادت‌ها و تسک‌ها XP جمع کنید',
            style: TextStyle(
              color: theme.textSecondaryColor,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
