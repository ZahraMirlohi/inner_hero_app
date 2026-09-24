// lib/features/chat/screens/buddy_finder_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/services/buddy_matcher_service.dart';
import '/services/chat_service.dart';
import '/providers/theme_provider.dart';
import '/features/profile/models/user_personality.dart';
import '/features/profile/screens/personality_screen.dart';
import '/features/chat/models/conversation_model.dart';
import 'chat_screen.dart';
import 'buddy_chat_screen.dart';

class BuddyFinderScreen extends StatefulWidget {
  const BuddyFinderScreen({super.key});

  @override
  State<BuddyFinderScreen> createState() => _BuddyFinderScreenState();
}

class _BuddyFinderScreenState extends State<BuddyFinderScreen>
    with SingleTickerProviderStateMixin {
  final BuddyMatcherService _matcherService = BuddyMatcherService();
  final ChatService _chatService = ChatService();
  final SupabaseClient _supabaseClient = Supabase.instance.client;

  // ==================== داده‌ها ====================
  List<Map<String, dynamic>> _matches = [];
  bool _isLoading = true;
  String? _userId;

  // ==================== فیلترها ====================
  Gender? _filterGender;
  double _minMatchScore = 0;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  // ==================== بارگذاری داده‌ها ====================
  Future<void> _loadData() async {
    final user = await _matcherService.getCurrentUser();
    if (user != null) {
      if (!mounted) return;

      setState(() {
        _userId = user.id;
        _isLoading = true;
      });

      try {
        final matches = await _matcherService.findMatchingBuddies(
          user.id,
          minMatchScore: _minMatchScore,
        );

        if (!mounted) return;

        setState(() {
          _matches = matches;
          _isLoading = false;
        });
      } catch (e) {
        print('❌ Error loading data: $e');
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ==================== ارسال درخواست ====================
  Future<void> _sendRequest(String toUserId, Color primaryColor) async {
    if (_userId == null) return;

    try {
      await _matcherService.sendBuddyRequestWithMatch(
        _userId!,
        toUserId,
        message: 'سلام! من از طریق سیستم هم‌مسیر با شما آشنا شدم. '
            'به نظر می‌رسد علاقه‌مندی‌های مشترکی داریم. '
            'خوشحال می‌شوم با هم هم‌مسیر باشیم! 🤝',
      );

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('درخواست هم‌مسیر ارسال شد ✅'),
            backgroundColor: primaryColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
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

  // ==================== لغو درخواست ====================
  Future<void> _cancelRequest(String toUserId, Color primaryColor) async {
    if (_userId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('لغو درخواست'),
        content: const Text('آیا از لغو درخواست هم‌مسیری مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'لغو درخواست',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _matcherService.cancelBuddyRequest(_userId!, toUserId);
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('درخواست هم‌مسیر لغو شد 🗑️'),
              backgroundColor: primaryColor,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
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
  }

  // ==================== پاسخ به درخواست ====================
  Future<void> _respondToRequest(
    String requestId,
    bool accept,
    Color primaryColor,
  ) async {
    try {
      await _matcherService.respondToBuddyRequest(requestId, accept);

      if (accept) {
        await Future.delayed(const Duration(seconds: 1));
      }

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? 'درخواست پذیرفته شد 🎉' : 'درخواست رد شد'),
            backgroundColor: accept ? primaryColor : Colors.grey,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error responding to request: $e');
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

  // ==================== Build ====================
  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'پیدا کردن هم‌مسیر',
          style: TextStyle(color: theme.textColor),
        ),
        backgroundColor: theme.surfaceColor,
        elevation: 0,
        foregroundColor: theme.textColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: primaryColor),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadData();
            },
            tooltip: 'بروزرسانی',
          ),
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: _showFilters ? primaryColor : theme.textColor,
            ),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: primaryColor),
            )
          : Column(
              children: [
                if (_showFilters) _buildFilters(theme, primaryColor),
                Expanded(
                  child: _matches.isEmpty
                      ? _buildEmptyState(theme, primaryColor)
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _matches.length,
                          itemBuilder: (context, index) {
                            return _buildMatchCard(
                              _matches[index],
                              theme,
                              primaryColor,
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  // ==================== فیلترها ====================
  Widget _buildFilters(ThemeProvider theme, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'فیلترها',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _filterGender = null;
                    _minMatchScore = 0;
                  });
                  _loadData();
                },
                child: Text(
                  'پاک کردن',
                  style: TextStyle(color: primaryColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'جنسیت:',
                style: TextStyle(fontSize: 13, color: theme.textColor),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'همه',
                _filterGender == null,
                () {
                  setState(() {
                    _filterGender = null;
                  });
                },
                primaryColor,
              ),
              _buildFilterChip(
                'مرد',
                _filterGender == Gender.male,
                () {
                  setState(() {
                    _filterGender = Gender.male;
                  });
                },
                primaryColor,
              ),
              _buildFilterChip(
                'زن',
                _filterGender == Gender.female,
                () {
                  setState(() {
                    _filterGender = Gender.female;
                  });
                },
                primaryColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'امتیاز:',
                style: TextStyle(fontSize: 13, color: theme.textColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: _minMatchScore,
                  min: 0,
                  max: 80,
                  divisions: 8,
                  activeColor: primaryColor,
                  onChanged: (value) {
                    setState(() {
                      _minMatchScore = value;
                    });
                  },
                ),
              ),
              Text(
                '${_minMatchScore.toInt()}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'اعمال:',
                style: TextStyle(fontSize: 13, color: theme.textColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _loadData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'اعمال فیلترها',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    bool isSelected,
    VoidCallback onTap,
    Color primaryColor,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ==================== کارت تطابق ====================
  Widget _buildMatchCard(
    Map<String, dynamic> match,
    ThemeProvider theme,
    Color primaryColor,
  ) {
    final score = match['match_score'] as double? ?? 0;
    final commonHabits = match['common_habits'] as List? ?? [];
    final commonInterests = match['common_interests'] as List? ?? [];
    final isBuddy = match['is_buddy'] ?? false;
    final hasPendingRequest = match['has_pending_request'] ?? false;
    final isSentByMe = match['is_sent_by_me'] ?? false;
    final isReceivedByMe = match['is_received_by_me'] ?? false;
    final conversationId = match['conversation_id'] as String?;
    final requestId = match['request_id'] as String?;

    // ✅ رنگ بوردر بر اساس وضعیت
    Color borderColor = Colors.grey.shade200;
    if (isBuddy) {
      borderColor = primaryColor;
    } else if (hasPendingRequest) {
      borderColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: borderColor, width: isBuddy ? 2 : 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // آواتار
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    (match['name'] ?? 'کاربر').substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
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
                            match['name'] ?? 'کاربر',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // برچسب وضعیت
                        if (isBuddy)
                          _buildStatusBadge(
                            'هم‌مسیر ✅',
                            primaryColor,
                          )
                        else if (isReceivedByMe)
                          _buildStatusBadge(
                            'درخواست جدید',
                            Colors.orange,
                          )
                        else if (isSentByMe)
                          _buildStatusBadge(
                            'در انتظار پاسخ',
                            Colors.blue,
                          ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _getScoreColor(score),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${score.toInt()}%',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.stars,
                          size: 14,
                          color: Color(0xFFFFA500),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${match['total_xp'] ?? 0} XP',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textSecondaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.local_fire_department,
                          size: 14,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${match['current_streak'] ?? 0} روز',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // اشتراکات
          if (commonHabits.isNotEmpty || commonInterests.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...commonHabits.take(3).map((habit) {
                  return _buildTagChip(
                    '🏃 $habit',
                    primaryColor,
                  );
                }),
                ...commonInterests.take(2).map((interest) {
                  return _buildTagChip(
                    '❤️ $interest',
                    primaryColor,
                  );
                }),
                if (commonHabits.length > 3 || commonInterests.length > 2)
                  Text(
                    'و ${(commonHabits.length > 3 ? commonHabits.length - 3 : 0) + (commonInterests.length > 2 ? commonInterests.length - 2 : 0)} مورد دیگر',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.textSecondaryColor,
                    ),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // دکمه‌های اقدام
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  match,
                  theme,
                  primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  _showUserProfile(match['user_id'], theme, primaryColor);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
                ),
                child: Icon(
                  Icons.person_outline,
                  size: 20,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTagChip(String label, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: primaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ==================== دکمه اقدام ====================
  Widget _buildActionButton(
    Map<String, dynamic> match,
    ThemeProvider theme,
    Color primaryColor,
  ) {
    final isBuddy = match['is_buddy'] ?? false;
    final isSentByMe = match['is_sent_by_me'] ?? false;
    final isReceivedByMe = match['is_received_by_me'] ?? false;
    final conversationId = match['conversation_id'] as String?;
    final requestId = match['request_id'] as String?;
    final score = match['match_score'] as double? ?? 0;
    final userId = match['user_id'];

    // ✅ هم‌مسیر شده → دکمه "گپ و گفتگو"
    if (isBuddy) {
      return ElevatedButton.icon(
        onPressed: () {
          if (conversationId != null) {
            final conv = Conversation(
              id: conversationId,
              type: ConversationType.buddy,
              name: match['name'],
              memberIds: [userId],
              lastMessageAt: DateTime.now(),
              createdAt: DateTime.now(),
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BuddyChatScreen(conversation: conv),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('خطا در باز کردن چت'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        icon: const Icon(Icons.chat, size: 18, color: Colors.white),
        label: const Text(
          'گپ و گفتگو',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          foregroundColor: Colors.white,
        ),
      );
    }

    // ✅ درخواست ارسال شده → "در انتظار پاسخ" + لغو
    if (isSentByMe) {
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                foregroundColor: Colors.grey.shade700,
              ),
              child: Text(
                'در انتظار پاسخ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () => _cancelRequest(userId, primaryColor),
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'لغو درخواست',
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      );
    }

    // ✅ درخواست دریافت شده → قبول/رد
    if (isReceivedByMe && requestId != null) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _respondToRequest(requestId, true, primaryColor),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'قبول درخواست',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ElevatedButton(
              onPressed: () =>
                  _respondToRequest(requestId, false, primaryColor),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade500,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'رد درخواست',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // ✅ هیچ ارتباطی → ارسال درخواست
    return ElevatedButton(
      onPressed: () => _sendRequest(userId, primaryColor),
      style: ElevatedButton.styleFrom(
        backgroundColor: score >= 70 ? primaryColor : primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        foregroundColor: Colors.white,
      ),
      child: Text(
        score >= 70 ? 'ارسال درخواست 🤝' : 'ارسال درخواست',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  // ==================== نمایش پروفایل ====================
  void _showUserProfile(
    String userId,
    ThemeProvider theme,
    Color primaryColor,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: theme.surfaceColor,
      builder: (context) {
        return FutureBuilder<Map<String, dynamic>>(
          future: _getUserProfile(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: primaryColor),
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('خطا در بارگذاری اطلاعات'),
                ),
              );
            }

            final data = snapshot.data!;
            return _buildUserProfileSheet(data, theme, primaryColor);
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getUserProfile(String userId) async {
    try {
      final profile = await _supabaseClient
          .from('profiles')
          .select('name, avatar_url, total_xp, current_streak, created_at')
          .eq('user_id', userId)
          .maybeSingle();

      final personality = await _supabaseClient
          .from('user_personalities')
          .select('gender, mbti_type, interests, goals, bio')
          .eq('user_id', userId)
          .maybeSingle();

      return {'profile': profile ?? {}, 'personality': personality ?? {}};
    } catch (e) {
      print('❌ Error getting user profile: $e');
      return {'profile': {}, 'personality': {}};
    }
  }

  Widget _buildUserProfileSheet(
    Map<String, dynamic> data,
    ThemeProvider theme,
    Color primaryColor,
  ) {
    final profile = data['profile'] as Map<String, dynamic>? ?? {};
    final personality = data['personality'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                (profile['name'] ?? 'کاربر').substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile['name'] ?? 'کاربر',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (personality['gender'] != null)
                Text(
                  _getGenderText(personality['gender']),
                  style: TextStyle(color: theme.textSecondaryColor),
                ),
              if (personality['mbti_type'] != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    personality['mbti_type'] ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.stars,
                label: 'XP',
                value: '${profile['total_xp'] ?? 0}',
                primaryColor: primaryColor,
                theme: theme,
              ),
              _buildStatItem(
                icon: Icons.local_fire_department,
                label: 'استریک',
                value: '${profile['current_streak'] ?? 0} روز',
                primaryColor: primaryColor,
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (personality['interests'] != null &&
              (personality['interests'] as List).isNotEmpty) ...[
            Text(
              'علاقه‌مندی‌ها:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (personality['interests'] as List).map((interest) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    interest,
                    style: TextStyle(
                      fontSize: 12,
                      color: primaryColor,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (personality['bio'] != null &&
              personality['bio'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'درباره من:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              personality['bio'] ?? '',
              style: TextStyle(
                fontSize: 13,
                color: theme.textSecondaryColor,
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _getGenderText(String? gender) {
    switch (gender) {
      case 'male':
        return 'مرد';
      case 'female':
        return 'زن';
      case 'other':
        return 'سایر';
      default:
        return 'نامشخص';
    }
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color primaryColor,
    required ThemeProvider theme,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: primaryColor, size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.textColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: theme.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 70) return const Color(0xFF2ECC71);
    if (score >= 50) return const Color(0xFFFFA500);
    return Colors.grey;
  }

  Widget _buildEmptyState(ThemeProvider theme, Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
                Icons.people_outline,
                size: 56,
                color: primaryColor.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'هم‌مسیری پیدا نشد',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'با تکمیل پروفایل شخصیت، شانس پیدا کردن هم‌مسیر را افزایش دهید',
              style: TextStyle(
                fontSize: 13,
                color: theme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PersonalityScreen(),
                  ),
                ).then((_) => _loadData());
              },
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text(
                'تکمیل پروفایل شخصیت',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
