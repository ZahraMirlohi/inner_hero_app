// lib/features/chat/screens/buddy_finder_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/services/buddy_matcher_service.dart';
import '/services/chat_service.dart';
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

  // lib/features/chat/screens/buddy_finder_screen.dart

  Future<void> _loadData() async {
    final user = await _matcherService.getCurrentUser();
    if (user != null) {
      if (!mounted) return;

      setState(() {
        _userId = user.id;
        _isLoading = true;
      });

      try {
        // ✅ دریافت داده‌های جدید
        final matches = await _matcherService.findMatchingBuddies(
          user.id,
          minMatchScore: _minMatchScore,
        );

        if (!mounted) return;

        // ✅ دیباگ: نمایش وضعیت هر کاربر
        for (var match in matches) {
          print('📊 Match: ${match['name']} - isBuddy: ${match['is_buddy']}');
        }

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

  Future<void> _sendRequest(String toUserId) async {
    if (_userId == null) return;

    try {
      await _matcherService.sendBuddyRequestWithMatch(
        _userId!,
        toUserId,
        message:
            'سلام! من از طریق سیستم هم‌مسیر با شما آشنا شدم. '
            'به نظر می‌رسد علاقه‌مندی‌های مشترکی داریم. '
            'خوشحال می‌شوم با هم هم‌مسیر باشیم! 🤝',
      );

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('درخواست هم‌مسیر ارسال شد ✅'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
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

  Future<void> _cancelRequest(String toUserId) async {
    if (_userId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            const SnackBar(
              content: Text('درخواست هم‌مسیر لغو شد 🗑️'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
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

  // lib/features/chat/screens/buddy_finder_screen.dart

  Future<void> _respondToRequest(String requestId, bool accept) async {
    try {
      print('📊 Responding to request $requestId with accept: $accept');

      // ✅ 1. پاسخ به درخواست
      await _matcherService.respondToBuddyRequest(requestId, accept);

      // ✅ 2. اگر قبول شده، صبر کنید تا گفتگو ایجاد شود
      if (accept) {
        print('📊 Request accepted, waiting for conversation to be created...');

        // ✅ 3. صبر کنید تا گفتگو ایجاد شود
        await Future.delayed(const Duration(seconds: 1));
      }

      // ✅ 4. ریفرش کامل داده‌ها
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? 'درخواست پذیرفته شد 🎉' : 'درخواست رد شد'),
            backgroundColor: accept ? Colors.green : Colors.grey,
            duration: Duration(seconds: 2),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('پیدا کردن هم‌مسیر'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A2E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              print('🔄 Manual refresh triggered');
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
              color: _showFilters ? const Color(0xFF4A90E2) : null,
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
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4A90E2)),
            )
          : Column(
              children: [
                if (_showFilters) _buildFilters(),
                Expanded(
                  child: _matches.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _matches.length,
                          itemBuilder: (context, index) {
                            return _buildMatchCard(_matches[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  // ==================== فیلترها ====================

  Widget _buildFilters() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              const Text(
                'فیلترها',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _filterGender = null;
                    _minMatchScore = 0;
                  });
                  _loadData();
                },
                child: const Text('پاک کردن'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('جنسیت:', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              _buildFilterChip('همه', _filterGender == null, () {
                setState(() {
                  _filterGender = null;
                });
              }),
              _buildFilterChip('مرد', _filterGender == Gender.male, () {
                setState(() {
                  _filterGender = Gender.male;
                });
              }),
              _buildFilterChip('زن', _filterGender == Gender.female, () {
                setState(() {
                  _filterGender = Gender.female;
                });
              }),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('امتیاز:', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: _minMatchScore,
                  min: 0,
                  max: 80,
                  divisions: 8,
                  activeColor: const Color(0xFF4A90E2),
                  onChanged: (value) {
                    setState(() {
                      _minMatchScore = value;
                    });
                  },
                ),
              ),
              Text(
                '${_minMatchScore.toInt()}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('اعمال:', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _loadData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A90E2) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  // ==================== کارت تطابق ====================

  Widget _buildMatchCard(Map<String, dynamic> match) {
    final score = match['match_score'] as double? ?? 0;
    final commonHabits = match['common_habits'] as List? ?? [];
    final commonInterests = match['common_interests'] as List? ?? [];
    final isBuddy = match['is_buddy'] ?? false;
    final hasPendingRequest = match['has_pending_request'] ?? false;
    final isSentByMe = match['is_sent_by_me'] ?? false;
    final isReceivedByMe = match['is_received_by_me'] ?? false;
    final conversationId = match['conversation_id'] as String?;
    final requestId = match['request_id'] as String?;

    // ✅ رنگ‌بندی بر اساس وضعیت
    Color borderColor = Colors.grey.shade200;
    if (isBuddy) {
      borderColor = Colors.green;
    } else if (hasPendingRequest) {
      borderColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF4A90E2).withValues(alpha: 0.1),
                child: Text(
                  (match['name'] ?? 'کاربر').substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A90E2),
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
                        Text(
                          match['name'] ?? 'کاربر',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // ✅ برچسب وضعیت
                        if (isBuddy)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'هم‌مسیر ✅',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          )
                        else if (isReceivedByMe)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'درخواست جدید',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                          )
                        else if (isSentByMe)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'در انتظار پاسخ',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
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
                            color: Colors.grey.shade600,
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
                            color: Colors.grey.shade600,
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
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '🏃 $habit',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF4A90E2),
                      ),
                    ),
                  );
                }),
                ...commonInterests.take(2).map((interest) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFA500).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '❤️ $interest',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFFFA500),
                      ),
                    ),
                  );
                }),
                if (commonHabits.length > 3 || commonInterests.length > 2)
                  Text(
                    'و ${(commonHabits.length > 3 ? commonHabits.length - 3 : 0) + (commonInterests.length > 2 ? commonInterests.length - 2 : 0)} مورد دیگر',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // ✅ دکمه‌های اقدام
          Row(
            children: [
              Expanded(child: _buildActionButton(match)),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  _showUserProfile(match['user_id']);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(Icons.person_outline, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== دکمه اقدام ====================

  // lib/features/chat/screens/buddy_finder_screen.dart

  Widget _buildActionButton(Map<String, dynamic> match) {
    final isBuddy = match['is_buddy'] ?? false;
    final isSentByMe = match['is_sent_by_me'] ?? false;
    final isReceivedByMe = match['is_received_by_me'] ?? false;
    final conversationId = match['conversation_id'] as String?;
    final requestId = match['request_id'] as String?;
    final score = match['match_score'] as double? ?? 0;
    final userId = match['user_id'];

    print(
      '📊 Action button for ${match['name']}: isBuddy=$isBuddy, isSentByMe=$isSentByMe, isReceivedByMe=$isReceivedByMe',
    );

    // ✅ اگر هم‌مسیر شده‌اید → دکمه "گپ و گفتگو"
    if (isBuddy) {
      return ElevatedButton.icon(
        onPressed: () {
          print('📊 Opening chat with buddy: $userId');
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
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          foregroundColor: Colors.white,
        ),
      );
    }

    // ✅ اگر درخواست ارسال شده → دکمه "در انتظار پاسخ" + لغو
    if (isSentByMe) {
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
            onPressed: () => _cancelRequest(userId),
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'لغو درخواست',
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      );
    }

    // ✅ اگر درخواست دریافت شده → دکمه قبول/رد
    if (isReceivedByMe && requestId != null) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _respondToRequest(requestId, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
              onPressed: () => _respondToRequest(requestId, false),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade500,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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

    // ✅ اگر هیچ ارتباطی ندارید → دکمه "ارسال درخواست"
    return ElevatedButton(
      onPressed: () => _sendRequest(userId),
      style: ElevatedButton.styleFrom(
        backgroundColor: score >= 70
            ? Colors.green.shade600
            : const Color(0xFF4A90E2),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  // ==================== نمایش پروفایل کاربر ====================

  void _showUserProfile(String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FutureBuilder<Map<String, dynamic>>(
          future: _getUserProfile(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text('خطا در بارگذاری اطلاعات'),
                ),
              );
            }

            final data = snapshot.data!;
            return _buildUserProfileSheet(data);
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

  Widget _buildUserProfileSheet(Map<String, dynamic> data) {
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

          CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFF4A90E2).withValues(alpha: 0.1),
            child: Text(
              (profile['name'] ?? 'کاربر').substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A90E2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Text(
            profile['name'] ?? 'کاربر',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (personality['gender'] != null)
                Text(
                  _getGenderText(personality['gender']),
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              if (personality['mbti_type'] != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    personality['mbti_type'] ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4A90E2),
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
              ),
              _buildStatItem(
                icon: Icons.local_fire_department,
                label: 'استریک',
                value: '${profile['current_streak'] ?? 0} روز',
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (personality['interests'] != null &&
              (personality['interests'] as List).isNotEmpty) ...[
            const Text(
              'علاقه‌مندی‌ها:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (personality['interests'] as List).map((interest) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(interest, style: const TextStyle(fontSize: 12)),
                );
              }).toList(),
            ),
          ],

          if (personality['bio'] != null &&
              personality['bio'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'درباره من:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              personality['bio'] ?? '',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
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
  }) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF4A90E2), size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 70) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.grey;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'هم‌مسیری پیدا نشد',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'با تکمیل پروفایل شخصیت، شانس پیدا کردن هم‌مسیر را افزایش دهید',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PersonalityScreen()),
              ).then((_) => _loadData());
            },
            icon: const Icon(Icons.person_add),
            label: const Text('تکمیل پروفایل شخصیت'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
