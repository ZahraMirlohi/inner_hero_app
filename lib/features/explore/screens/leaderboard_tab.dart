// lib/features/explore/screens/leaderboard_tab.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/services/supabase_service.dart';
import '/providers/theme_provider.dart';
import '/core/app_palette.dart';

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

      final badgesByUser = await _getBadgesFor(
          [for (final u in users) u['user_id'] as String]);
      for (var user in users) {
        final badges = badgesByUser[user['user_id']] ?? const [];
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
        // یک درخواست برای همه پروفایل‌ها (به‌جای ۱۰۰ درخواست جدا)
        final ids = [for (final r in response) r['user_id'] as String];
        final profiles = await _supabase.client
            .from('profiles')
            .select('user_id, name, avatar_url')
            .inFilter('user_id', ids);
        final byId = {for (final p in profiles) p['user_id'] as String: p};
        return [
          for (final item in response)
            {
              'user_id': item['user_id'],
              'name': byId[item['user_id']]?['name'] ??
                  'کاربر ${(item['user_id'] as String).substring(0, 6)}',
              'total_xp': item['total_xp'] ?? 0,
              'avatar_url': byId[item['user_id']]?['avatar_url'],
            }
        ];
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

    return []; // بدون داده‌ی ساختگی؛ حالت خالی نمایش داده می‌شود
  }

  /// مدال‌های فعال همه کاربران با یک درخواست
  Future<Map<String, List<Map<String, dynamic>>>> _getBadgesFor(
      List<String> ids) async {
    final out = <String, List<Map<String, dynamic>>>{};
    if (ids.isEmpty) return out;
    try {
      final rows = await _supabase.client
          .from('user_badges')
          .select()
          .inFilter('user_id', ids)
          .eq('is_active', true);
      for (final r in rows) {
        out.putIfAbsent(r['user_id'] as String, () => []).add(r);
      }
    } catch (_) {}
    return out;
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
  static const _ink = Color(0xFF090909);

  Widget _avatar(dynamic url, double size, ThemeProvider theme) {
    final has = url is String && url.trim().isNotEmpty;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(color: _ink, shape: BoxShape.circle),
      child: has
          ? Image.network(url.trim(),
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Icon(Icons.person_rounded,
                  size: size * 0.5, color: theme.effectivePrimary))
          : Icon(Icons.person_rounded,
              size: size * 0.5, color: theme.effectivePrimary),
    );
  }

  Widget _xpLabel(int xp, {double size = 12}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: size + 2, color: _ink),
          const SizedBox(width: 3),
          Text('$xp',
              style: TextStyle(
                  fontSize: size, fontWeight: FontWeight.w800, color: _ink)),
        ],
      );

  Widget _buildHeader(Color primaryColor, ThemeProvider theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.tone(Tone.butter).bg,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration:
                const BoxDecoration(color: _ink, shape: BoxShape.circle),
            child: Icon(Icons.emoji_events_rounded,
                size: 28, color: theme.effectivePrimary),
          ),
          const SizedBox(height: 6),
          const Text('تالار افتخارات',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 4),
          const Text('بهترین قهرمانان اپلیکیشن',
              style: TextStyle(fontSize: 13, color: Color(0xFF3C4034))),
          if (_currentUserRank > 0) ...[
            const SizedBox(height: 8),
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16)),
              child: Text('رتبه شما: $_currentUserRank',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _ink)),
            ),
          ],
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
        padding: const EdgeInsets.only(top: 16, bottom: 120),
        child: Column(
          children: [
            if (top3.isNotEmpty) _buildPodium(top3, primaryColor, theme),
            if (rest.isNotEmpty) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
    Widget item(int idx, int rank, String medal, double h, Tone tone) {
      if (top3.length <= idx) return const Expanded(child: SizedBox());
      final u = top3[idx];
      final badges = (u['badgeCount'] ?? 0) as int;
      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(medal, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            _avatar(u['avatar_url'], 56, theme),
            const SizedBox(height: 6),
            Text(u['name'] ?? 'کاربر',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.textColor)),
            if (badges > 0) ...[
              const SizedBox(height: 4),
              Container(
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(11)),
                child: Text('$badges مدال',
                    style: const TextStyle(fontSize: 11, color: _ink)),
              ),
            ],
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              height: h,
              decoration: BoxDecoration(
                color: theme.tone(tone).bg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$rank',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _ink)),
                  _xpLabel((u['total_xp'] ?? 0) as int),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 16, 26, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          item(1, 2, '🥈', 96, Tone.sky),
          const SizedBox(width: 8),
          item(0, 1, '🥇', 128, Tone.butter),
          const SizedBox(width: 8),
          item(2, 3, '🥉', 78, Tone.peach),
        ],
      ),
    );
  }

  Widget _buildRestHeader(int count, ThemeProvider theme) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              color: theme.primarySoft, shape: BoxShape.circle),
          child: const Icon(Icons.format_list_numbered_rounded,
              size: 18, color: _ink),
        ),
        const SizedBox(width: 8),
        Text('سایر قهرمانان',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: theme.textColor)),
        const SizedBox(width: 8),
        Container(
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: theme.cardSecondaryColor,
              borderRadius: BorderRadius.circular(11)),
          child: Text('$count',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.textColor)),
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
    final isMe = user['user_id'] == _currentUserId;
    final badges = (user['badgeCount'] ?? 0) as int;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isMe ? theme.primarySoft : theme.cardColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: theme.softShadow,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text('$rank',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isMe ? _ink : theme.textColor)),
          ),
          const SizedBox(width: 12),
          _avatar(user['avatar_url'], 40, theme),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(user['name'] ?? 'کاربر',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isMe ? _ink : theme.textColor)),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        height: 22,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: theme.effectivePrimary,
                            borderRadius: BorderRadius.circular(11)),
                        child: Text('شما',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: theme.onPrimaryColor)),
                      ),
                    ],
                  ],
                ),
                if (badges > 0)
                  Text('$badges مدال',
                      style: TextStyle(
                          fontSize: 11,
                          color: isMe
                              ? const Color(0xFF3C4034)
                              : theme.textSecondaryColor)),
              ],
            ),
          ),
          if (isMe)
            _xpLabel((user['total_xp'] ?? 0) as int, size: 14)
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded,
                    size: 16, color: theme.textColor),
                const SizedBox(width: 3),
                Text('${user['total_xp'] ?? 0}',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: theme.textColor)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _stateView(ThemeProvider theme, IconData icon, Tone tone, String title,
      String sub, {Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                  color: theme.tone(tone).bg, shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: _ink),
            ),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: theme.textColor)),
            const SizedBox(height: 6),
            Text(sub,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, height: 1.7, color: theme.textSecondaryColor)),
            if (action != null) ...[const SizedBox(height: 18), action],
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
          CircularProgressIndicator(color: theme.effectivePrimary),
          const SizedBox(height: 16),
          Text('در حال بارگذاری تالار افتخارات...',
              style:
                  TextStyle(color: theme.textSecondaryColor, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildErrorState(Color primaryColor, ThemeProvider theme) {
    return _stateView(
      theme,
      Icons.cloud_off_rounded,
      Tone.rose,
      'مشکلی پیش اومد',
      _errorMessage,
      action: GestureDetector(
        onTap: _loadLeaderboard,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: _ink, borderRadius: BorderRadius.circular(24)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh_rounded,
                  size: 18, color: theme.effectivePrimary),
              const SizedBox(width: 6),
              Text('تلاش مجدد',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.effectivePrimary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color primaryColor, ThemeProvider theme) {
    return _stateView(
      theme,
      Icons.emoji_events_rounded,
      Tone.butter,
      'تالار افتخارات خالیه',
      'با انجام عادت‌ها و کارها XP جمع کن تا اسمت اینجا بیاد',
    );
  }
}
