// lib/features/chat/screens/buddy_chat_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '/services/chat_service.dart';
import '../models/message_model.dart';
import '../models/conversation_model.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shamsi_date/shamsi_date.dart'; // ✅ اضافه کنید
import '/services/date_service.dart';
import 'user_profile_screen.dart';

class BuddyChatScreen extends StatefulWidget {
  final Conversation conversation;

  const BuddyChatScreen({super.key, required this.conversation});

  @override
  State<BuddyChatScreen> createState() => _BuddyChatScreenState();
}

class _BuddyChatScreenState extends State<BuddyChatScreen>
    with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  // ==================== داده‌ها ====================
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _userId;
  String? _buddyId;
  String? _highlightedMessageId;
  String? _buddyName;
  String? _buddyAvatar;
  bool _isBuddyOnline = false;
  bool _isBuddyTyping = false;
  bool _isSelectMode = false;
  bool _isChatMuted = false;
  bool _showMediaMenu = false;
  int _todayHabitsCompleted = 0;
  int _todayHabitsRemaining = 0;
  int _currentStreak = 0;

  Set<String> _selectedMessageIds = {};
  StreamSubscription<List<ChatMessage>>? _messageSubscription;
  StreamSubscription<Map<String, bool>>? _typingSubscription;
  Offset? _menuPosition;
  ChatMessage? _menuMessage;

  // ==================== وضعیت‌ها ====================
  bool _showEmojiPicker = false;
  bool _showStickerPicker = false;
  bool _showGifPicker = false;
  ChatMessage? _replyToMessage;
  ChatMessage? _selectedMessage;
  Timer? _statusTimer;

  // ==================== استیکرها ====================
  final List<String> _popularEmojis = [
    '😊',
    '😂',
    '🤣',
    '❤️',
    '🔥',
    '💪',
    '🎉',
    '✨',
    '🌟',
    '⭐',
    '👏',
    '🙌',
    '🤗',
    '😍',
    '🥰',
    '😘',
    '😎',
    '🤩',
    '🥳',
    '💯',
    '🔥',
    '⚡',
    '💎',
    '🏆',
    '👑',
    '💪',
    '🤝',
    '❤️‍🔥',
    '✨',
    '🌟',
    '💫',
    '🌈',
  ];
  final List<MediaMenuItem> _mediaMenuItems = [];

  final List<Map<String, String>> _popularGifs = [
    {'name': 'سلام', 'emoji': '👋', 'id': '1'},
    {'name': 'خنده', 'emoji': '😂', 'id': '2'},
    {'name': 'تشویق', 'emoji': '👏', 'id': '3'},
    {'name': 'عشق', 'emoji': '❤️', 'id': '4'},
    {'name': 'شکست', 'emoji': '😢', 'id': '5'},
    {'name': 'پیروزی', 'emoji': '🏆', 'id': '6'},
  ];

  // ==================== واکنش‌ها ====================
  final List<String> _popularReactions = [
    '❤️',
    '🔥',
    '💪',
    '🎉',
    '😂',
    '😍',
    '🙏',
    '👍',
  ];

  @override
  void initState() {
    super.initState();
    _initChat();

    // ✅ تایمر برای به‌روزرسانی وضعیت آنلاین هر 15 ثانیه
    _statusTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      // ✅ فقط اگر صفحه هنوز mount شده باشد و buddyId وجود داشته باشد
      if (mounted && _buddyId != null) {
        _getBuddyStatus(_buddyId!);
      } else {
        // اگر صفحه mount نیست، تایمر را لغو کن
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel(); // ✅ لغو تایمر
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ==================== مقداردهی اولیه ====================

  final Map<String, String> _userNameCache = {};

  Future<void> _initChat() async {
    final user = await _chatService.getCurrentUser();

    // ✅ اگر کاربر وجود نداشت یا صفحه mount نیست، خروج
    if (user == null || !mounted) return;

    setState(() {
      _userId = user.id;
    });

    // ✅ به‌روزرسانی last_seen_at خود کاربر
    await _updateLastSeen(user.id);

    // پیدا کردن ID کاربر مقابل
    String buddyId = '';
    if (widget.conversation.memberIds.isNotEmpty) {
      final others = widget.conversation.memberIds
          .where((id) => id != user.id)
          .toList();
      if (others.isNotEmpty) {
        buddyId = others.first;
      }
    }

    // اگر memberIds خالی بود، از دیتابیس دریافت کن
    if (buddyId.isEmpty) {
      try {
        final membersResponse = await _chatService.client
            .from('conversation_members')
            .select('user_id')
            .eq('conversation_id', widget.conversation.id);

        for (var member in membersResponse) {
          final id = member['user_id'] as String?;
          if (id != null && id != user.id) {
            buddyId = id;
            break;
          }
        }
      } catch (e) {
        print('❌ Error fetching members: $e');
      }
    }

    if (buddyId.isNotEmpty) {
      _buddyId = buddyId;

      try {
        final profile = await _chatService.client
            .from('profiles')
            .select('name, avatar_url, updated_at, last_seen_at')
            .eq('user_id', buddyId)
            .maybeSingle();

        // ✅ فقط اگر صفحه هنوز mount شده باشد
        if (mounted) {
          if (profile != null) {
            setState(() {
              _buddyName = profile['name'] as String? ?? 'کاربر';
              _buddyAvatar = profile['avatar_url'];
            });

            // ✅ دریافت وضعیت آنلاین
            final lastSeen = profile['last_seen_at'] ?? profile['updated_at'];
            _checkOnlineStatus(lastSeen);

            // ✅ دریافت وضعیت به‌روز از دیتابیس
            await _getBuddyStatus(buddyId);
          }
        }
      } catch (e) {
        print('❌ Error getting buddy profile: $e');
        if (mounted) {
          setState(() {
            _isBuddyOnline = false;
          });
        }
      }
    }

    // ✅ بارگذاری پیام‌ها
    await _loadMessages();

    // ✅ اشتراک پیام‌های جدید
    _messageSubscription = _chatService
        .getMessages(widget.conversation.id, userId: _userId)
        .listen((newMessages) async {
          // ✅ اگر صفحه mount نیست، خروج
          if (!mounted) return;

          final messagesWithReactions = await _loadReactionsForMessages(
            newMessages,
          );

          // ✅ فقط اگر صفحه هنوز mount شده باشد
          if (mounted) {
            setState(() {
              _messages = messagesWithReactions.reversed.toList();
            });
            await _markMessagesAsRead();
            _scrollToBottom();
          }
        });

    // ✅ اشتراک وضعیت تایپ
    _typingSubscription = _chatService
        .getTypingStatus(widget.conversation.id)
        .listen((typingData) {
          // ✅ اگر صفحه mount نیست یا buddyId وجود ندارد، خروج
          if (!mounted || _buddyId == null) return;

          print('📊 Typing data received: $typingData');
          print('📊 Buddy ID: $_buddyId');

          final isTyping = typingData[_buddyId] == true;
          print('📊 Is typing: $isTyping');

          // ✅ فقط اگر صفحه هنوز mount شده باشد
          if (mounted && isTyping != _isBuddyTyping) {
            setState(() {
              _isBuddyTyping = isTyping;
            });
          }
        });
  }

  // lib/features/chat/screens/buddy_chat_screen.dart

  // ✅ نمایش منوی چندرسانه‌ای
  void _showMediaMenuSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.7,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ نشانگر کشیدن
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
                  const SizedBox(height: 16),

                  // ✅ عنوان
                  const Text(
                    'ارسال محتوا',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'یکی از گزینه‌های زیر را انتخاب کنید',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),

                  // ✅ لیست گزینه‌ها
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 1.1,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: _getMediaMenuItems().length,
                      itemBuilder: (context, index) {
                        final item = _getMediaMenuItems()[index];
                        return _buildMediaMenuItem(item);
                      },
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ✅ ساخت آیتم منوی چندرسانه‌ای
  Widget _buildMediaMenuItem(MediaMenuItem item) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        item.onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
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
          border: Border.all(color: Colors.grey.shade100, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ✅ آیکون
            Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: item.color, size: 24),
                ),
                // ✅ نشان (Badge)
                if (item.badge != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        item.badge!,
                        style: const TextStyle(
                          fontSize: 8,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ✅ لیست آیتم‌های منو
  List<MediaMenuItem> _getMediaMenuItems() {
    return [
      MediaMenuItem(
        icon: Icons.image,
        title: 'ارسال عکس',
        color: const Color(0xFF4A90E2),
        onTap: _sendImage,
      ),
      MediaMenuItem(
        icon: Icons.location_on,
        title: 'ارسال لوکیشن',
        color: const Color(0xFF2ECC71),
        onTap: _sendLocation,
      ),
      MediaMenuItem(
        icon: Icons.contact_phone,
        title: 'ارسال شماره تماس',
        color: const Color(0xFFE74C3C),
        onTap: _sendContact,
      ),
      MediaMenuItem(
        icon: Icons.attach_file,
        title: 'ارسال فایل',
        color: const Color(0xFFF39C12),
        onTap: _sendFile,
      ),
      MediaMenuItem(
        icon: Icons.music_note,
        title: 'ارسال موزیک',
        color: const Color(0xFF9B59B6),
        onTap: _sendMusic,
      ),
      MediaMenuItem(
        icon: Icons.trending_up,
        title: 'کارت پیشرفت روزانه',
        color: const Color(0xFF1ABC9C),
        onTap: _sendDailyProgressCard,
      ),
      MediaMenuItem(
        icon: Icons.show_chart,
        title: 'نمودار عملکرد',
        color: const Color(0xFF3498DB),
        onTap: _sendPerformanceChart,
        badge: 'جدید',
      ),
      MediaMenuItem(
        icon: Icons.checklist,
        title: 'عادت‌های امروز',
        color: const Color(0xFFFFA500),
        onTap: _sendTodayHabits,
      ),
      MediaMenuItem(
        icon: Icons.flag,
        title: 'چالش و دعوت',
        color: const Color(0xFFE74C3C),
        onTap: _sendChallengeInvite,
      ),
      MediaMenuItem(
        icon: Icons.timer,
        title: 'تایمر / یادآور',
        color: const Color(0xFF6C5CE7),
        onTap: _sendTimerReminder,
      ),
      MediaMenuItem(
        icon: Icons.stars,
        title: 'هدیه XP',
        color: const Color(0xFFFFA500),
        onTap: _sendXPGift,
        badge: '🎁',
      ),
    ];
  }

  // lib/features/chat/screens/buddy_chat_screen.dart

  // ✅ ارسال لوکیشن
  void _sendLocation() {
    // در آینده: دریافت لوکیشن واقعی
    _sendMessage(
      text: '📍 موقعیت مکانی من',
      type: MessageType.text,
      metadata: {'type': 'location', 'lat': 35.6892, 'lng': 51.3890},
    );
  }

  // ✅ ارسال شماره تماس
  void _sendContact() {
    // در آینده: انتخاب از لیست مخاطبان
    _sendMessage(text: '📞 شماره تماس: ۰۹۱۲xxx-xxxx', type: MessageType.text);
  }

  // ✅ ارسال فایل
  void _sendFile() {
    // در آینده: انتخاب فایل
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📁 قابلیت ارسال فایل به زودی اضافه میشود'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ✅ ارسال موزیک
  void _sendMusic() {
    // در آینده: انتخاب موزیک
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎵 قابلیت ارسال موزیک به زودی اضافه میشود'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ✅ ارسال کارت پیشرفت روزانه
  void _sendDailyProgressCard() {
    // دریافت آمار امروز
    final todayHabits = _messages.where((m) => m.senderId == _userId).length;
    final progressText =
        '''
📊 کارت پیشرفت روزانه
━━━━━━━━━━━━━━━━━━━━
✅ عادت‌های انجام شده: $_todayHabitsCompleted
⏳ عادت‌های باقیمانده: $_todayHabitsRemaining
🔥 استریک فعلی: $_currentStreak روز
━━━━━━━━━━━━━━━━━━━━
💪 ادامه بده! به قهرمانی نزدیک میشی!
''';

    _sendMessage(text: progressText, type: MessageType.text);
  }

  // ✅ ارسال نمودار عملکرد
  void _sendPerformanceChart() {
    // در آینده: تولید نمودار
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📊 نمودار عملکرد به زودی اضافه میشود'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ✅ ارسال عادت‌های امروز
  void _sendTodayHabits() {
    // در آینده: دریافت عادت‌های امروز
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 لیست عادت‌های امروز به زودی اضافه میشود'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ✅ ارسال چالش و دعوت
  void _sendChallengeInvite() {
    // در آینده: ارسال دعوت چالش
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🏆 ارسال چالش و دعوت به زودی اضافه میشود'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ✅ ارسال تایمر/یادآور
  void _sendTimerReminder() {
    // در آینده: تنظیم تایمر
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⏰ تنظیم تایمر و یادآور به زودی اضافه میشود'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ✅ ارسال هدیه XP
  void _sendXPGift() {
    // در آینده: انتخاب مقدار XP
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎁 ارسال هدیه XP به زودی اضافه میشود'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ✅ نمایش منوی هدر
  void _showHeaderMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ نشانگر کشیدن
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
                const SizedBox(height: 16),

                // ✅ عنوان منو
                const Text(
                  'گزینه‌های گفتگو',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 16),

                // ✅ گزینه بی‌صدا/صدا دار
                _buildMenuTile(
                  icon: _isChatMuted ? Icons.volume_off : Icons.volume_up,
                  title: _isChatMuted ? 'فعال کردن صدا' : 'بی‌صدا کردن',
                  subtitle: _isChatMuted
                      ? 'اعلان‌های این گفتگو فعال میشوند'
                      : 'اعلان‌های این گفتگو غیرفعال میشوند',
                  onTap: () {
                    Navigator.pop(context);
                    _toggleMuteChat();
                  },
                  color: _isChatMuted ? Colors.green : Colors.orange,
                ),

                const Divider(height: 1),

                // ✅ گزینه جستجو
                _buildMenuTile(
                  icon: Icons.search,
                  title: 'جستجو در گفتگو',
                  subtitle: 'جستجوی پیام‌ها',
                  onTap: () {
                    Navigator.pop(context);
                    _showSearchInChat();
                  },
                  color: const Color(0xFF4A90E2),
                ),

                const Divider(height: 1),

                // ✅ گزینه پاک کردن تاریخچه
                _buildMenuTile(
                  icon: Icons.delete_sweep,
                  title: 'پاک کردن تاریخچه',
                  subtitle: 'تمام پیام‌های این گفتگو حذف میشوند',
                  onTap: () {
                    Navigator.pop(context);
                    _confirmClearHistory();
                  },
                  color: Colors.orange,
                ),

                const Divider(height: 1),

                // ✅ گزینه حذف گفتگو
                _buildMenuTile(
                  icon: Icons.exit_to_app,
                  title: 'حذف گفتگو',
                  subtitle: 'از لیست گفتگوها حذف میشود',
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteConversation();
                  },
                  color: Colors.red,
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // ✅ ساخت آیتم منو
  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1A1A2E),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }

  // ✅ تغییر وضعیت بی‌صدا/صدا دار
  void _toggleMuteChat() {
    setState(() {
      _isChatMuted = !_isChatMuted;
    });

    // ✅ ذخیره در LocalStorage یا دیتابیس
    // می‌توانید این وضعیت را در دیتابیس ذخیره کنید

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isChatMuted ? '🔇 گفتگو بی‌صدا شد' : '🔊 گفتگو صدا دار شد',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // ✅ جستجو در گفتگو - نسخه کامل
  void _showSearchInChat() {
    final TextEditingController searchController = TextEditingController();
    final FocusNode focusNode = FocusNode();

    // ✅ فوکوس روی فیلد جستجو
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.search,
                color: Color(0xFF4A90E2),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'جستجو در گفتگو',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: searchController,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: 'متن مورد نظر را وارد کنید...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF4A90E2)),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.grey,
                          size: 18,
                        ),
                        onPressed: () {
                          searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                // ✅ به‌روزرسانی برای نمایش دکمه پاک کردن
                setState(() {});
              },
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  Navigator.pop(context);
                  _searchMessages(value);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('انصراف'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final query = searchController.text.trim();
              if (query.isNotEmpty) {
                Navigator.pop(context);
                _searchMessages(query);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('لطفاً متن مورد نظر را وارد کنید'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
            icon: const Icon(Icons.search, size: 18),
            label: const Text('جستجو'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              elevation: 0,
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  // ✅ جستجوی پیام‌ها
  void _searchMessages(String query) {
    // ✅ پیدا کردن پیام‌های حاوی عبارت جستجو
    final results = _messages.where((msg) {
      return msg.content.toLowerCase().contains(query.toLowerCase());
    }).toList();

    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('نتیجه‌ای یافت نشد 🔍'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // ✅ نمایش نتایج
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
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
                  const SizedBox(height: 12),
                  Text(
                    'نتایج جستجو (${results.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final msg = results[index];
                        final isMe = msg.senderId == _userId;
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: isMe
                                ? const Color(0xFF4A90E2)
                                : Colors.grey.shade300,
                            child: Text(
                              isMe ? 'من' : '👤',
                              style: TextStyle(
                                fontSize: 10,
                                color: isMe
                                    ? Colors.white
                                    : Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            msg.content,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            _formatTime(msg.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _scrollToMessage(msg.id);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ✅ تأیید پاک کردن تاریخچه
  void _confirmClearHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'پاک کردن تاریخچه',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'آیا از پاک کردن تمام پیام‌های این گفتگو مطمئن هستید؟\n\n'
          'این عمل قابل بازگشت نیست.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearChatHistory();
            },
            child: const Text('پاک کردن', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ✅ پاک کردن تاریخچه گفتگو
  Future<void> _clearChatHistory() async {
    if (_userId == null) return;

    try {
      // ✅ حذف همه پیام‌های گفتگو
      await _chatService.client
          .from('messages')
          .delete()
          .eq('conversation_id', widget.conversation.id);

      setState(() {
        _messages.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تاریخچه گفتگو پاک شد 🗑️'),
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

  // ✅ تأیید حذف گفتگو
  void _confirmDeleteConversation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'حذف گفتگو',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'آیا از حذف گفتگو با "${_buddyName ?? 'کاربر'}" مطمئن هستید؟\n\n'
          'با این کار، این گفتگو از لیست شما حذف میشود.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteConversation();
            },
            child: const Text('حذف گفتگو', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ✅ حذف گفتگو
  Future<void> _deleteConversation() async {
    if (_userId == null) return;

    try {
      await _chatService.deleteConversationForBoth(widget.conversation.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('گفتگو حذف شد 🗑️'),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context); // برگشت به صفحه لیست گفتگوها
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

  // lib/features/chat/screens/buddy_chat_screen.dart

  // ✅ متد علامت‌گذاری پیام‌ها به عنوان خوانده شده
  Future<void> _markMessagesAsRead() async {
    if (_userId == null || _messages.isEmpty) return;

    // ✅ پیدا کردن پیام‌های خوانده نشده (که توسط کاربر مقابل ارسال شده)
    final unreadMessages = _messages.where((msg) {
      return msg.senderId != _userId &&
          msg.status != MessageStatus.seen &&
          msg.status != MessageStatus.delivered;
    }).toList();

    if (unreadMessages.isEmpty) return;

    try {
      // ✅ علامت‌گذاری همه پیام‌ها به عنوان خوانده شده
      await _chatService.markAllMessagesAsRead(
        conversationId: widget.conversation.id,
        userId: _userId!,
      );

      // ✅ به‌روزرسانی محلی
      setState(() {
        for (var msg in unreadMessages) {
          final index = _messages.indexWhere((m) => m.id == msg.id);
          if (index != -1) {
            _messages[index].status =
                MessageStatus.seen; // ✅ حالا قابل تغییر است
          }
        }
      });
    } catch (e) {
      print('❌ Error marking messages as read: $e');
    }
  }

  void _checkOnlineStatus(String? updatedAt) {
    print('📊 Checking online status with: $updatedAt');

    if (updatedAt != null && updatedAt.isNotEmpty) {
      try {
        final lastSeen = DateTime.parse(updatedAt).toUtc();
        final now = DateTime.now().toUtc();
        final diff = now.difference(lastSeen);
        final isOnline = diff.inMinutes < 5;

        // ✅ فقط اگر صفحه هنوز mount شده باشد، setState صدا بزن
        if (mounted) {
          setState(() {
            _isBuddyOnline = isOnline;
          });
        }
      } catch (e) {
        print('❌ Error parsing date: $e');
        if (mounted) {
          setState(() {
            _isBuddyOnline = false;
          });
        }
      }
    } else {
      print('⚠️ No updated_at provided');
      if (mounted) {
        setState(() {
          _isBuddyOnline = false;
        });
      }
    }
  }

  // ✅ ویجت منوی کنار پیام - با هایلایت دایره‌ای
  Widget _buildMessageActionsPopup() {
    if (_menuMessage == null || _menuPosition == null) {
      return const SizedBox.shrink();
    }

    final message = _menuMessage!;
    final isOwnMessage = message.senderId == _userId;
    final screenSize = MediaQuery.of(context).size;

    final double bubbleX = _menuPosition!.dx;
    final double bubbleY = _menuPosition!.dy;

    const double menuWidth = 220;
    const double reactionsHeight = 52;
    const double menuItemsHeight = 230;
    const double gap = 6;
    const double totalHeight = reactionsHeight + gap + menuItemsHeight;

    double left;
    double top;

    if (isOwnMessage) {
      left = bubbleX - menuWidth - 20;
    } else {
      left = bubbleX + 2;
    }

    top = bubbleY - (totalHeight / 2);

    if (left < 10) left = 10;
    if (left + menuWidth > screenSize.width - 10) {
      left = screenSize.width - menuWidth - 10;
    }
    if (top < 60) top = 60;
    if (top + totalHeight > screenSize.height - 20) {
      top = screenSize.height - totalHeight - 20;
    }

    final List<BoxShadow> shadows = [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.12),
        blurRadius: 16,
        spreadRadius: 2,
        offset: const Offset(0, 4),
      ),
    ];

    return Positioned(
      left: left,
      top: top,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ✅ حباب ری‌اکشن‌ها - با هایلایت دایره‌ای
          Container(
            width: menuWidth,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: shadows,
            ),
            child: SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                itemCount: _popularReactions.length,
                itemBuilder: (context, index) {
                  final emoji = _popularReactions[index];
                  final isSelected =
                      message.reactions?.any(
                        (r) => r.emoji == emoji && r.userId == _userId,
                      ) ??
                      false;

                  return GestureDetector(
                    onTap: () {
                      _closeMenu();
                      _toggleReaction(message, emoji);
                    },
                    child: Container(
                      width: 36, // ✅ اندازه ثابت برای دایره
                      height: 36,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF4A90E2).withValues(alpha: 0.15)
                            : Colors.transparent,
                        shape: BoxShape.circle, // ✅ دایره کامل
                        border: isSelected
                            ? Border.all(
                                color: const Color(0xFF4A90E2),
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 6),

          // ✅ حباب گزینه‌های منو
          Container(
            width: menuWidth,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: shadows,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPopupMenuItem(
                  icon: Icons.reply,
                  label: 'پاسخ',
                  onTap: () {
                    _closeMenu();
                    _setReplyTo(message);
                  },
                ),

                if (isOwnMessage && message.canBeEdited)
                  _buildPopupMenuItem(
                    icon: Icons.edit,
                    label: 'ویرایش',
                    onTap: () {
                      _closeMenu();
                      _editMessage(message);
                    },
                  ),

                _buildPopupMenuItem(
                  icon: Icons.copy,
                  label: 'کپی',
                  onTap: () {
                    _closeMenu();
                    _copyMessage(message);
                  },
                ),

                _buildPopupMenuItem(
                  icon: Icons.delete_outline,
                  label: 'حذف',
                  color: Colors.red,
                  onTap: () {
                    _closeMenu();
                    _showDeleteOptionsDialog(message);
                  },
                ),

                _buildPopupMenuItem(
                  icon: Icons.share,
                  label: 'اشتراک‌گذاری',
                  onTap: () {
                    _closeMenu();
                    _forwardMessage(message);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ آیتم منوی پاپ‌آپ (بدون فلش پایین)
  Widget _buildPopupMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? Colors.grey.shade700),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: color ?? Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ واکنش‌ها با قابلیت بستن منو
  Widget _buildReactionRow(ChatMessage message, {bool closeMenu = false}) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _popularReactions.length,
        itemBuilder: (context, index) {
          final emoji = _popularReactions[index];
          final isSelected =
              message.reactions?.any((r) => r.emoji == emoji) ?? false;

          return GestureDetector(
            onTap: () {
              if (closeMenu) _closeMenu();
              _toggleReaction(message, emoji);
            },
            child: Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: isSelected
                    ? Border.all(color: Colors.blue, width: 1)
                    : null,
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          );
        },
      ),
    );
  }

  // ✅ نمایش منوی اکشن در کنار پیام
  void _showMessageActionsPopup(ChatMessage message, Offset position) {
    setState(() {
      _menuMessage = message;
      _menuPosition = position;
    });
  }

  // ✅ بستن منو
  void _closeMenu() {
    setState(() {
      _menuMessage = null;
      _menuPosition = null;
    });
  }

  Future<void> _getBuddyStatus(String buddyId) async {
    // ✅ اگر صفحه mount نیست، خروج
    if (!mounted) return;

    try {
      print('📊 Getting buddy status for: $buddyId');

      final profile = await _chatService.client
          .from('profiles')
          .select('last_seen_at, updated_at')
          .eq('user_id', buddyId)
          .maybeSingle();

      // ✅ فقط اگر صفحه هنوز mount شده باشد
      if (mounted) {
        if (profile != null) {
          final lastSeen = profile['last_seen_at'] ?? profile['updated_at'];
          print('📊 Profile found - last_seen: $lastSeen');
          _checkOnlineStatus(lastSeen);
        } else {
          print('⚠️ Profile not found for buddy: $buddyId');
          setState(() {
            _isBuddyOnline = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error getting buddy status: $e');
      if (mounted) {
        setState(() {
          _isBuddyOnline = false;
        });
      }
    }
  }

  // ✅ متد گروه‌بندی واکنش‌ها
  List<Map<String, dynamic>> _groupReactions(List<MessageReaction> reactions) {
    final Map<String, int> counts = {};
    for (var reaction in reactions) {
      counts[reaction.emoji] = (counts[reaction.emoji] ?? 0) + 1;
    }
    return counts.entries.map((entry) {
      return {'emoji': entry.key, 'count': entry.value};
    }).toList();
  }

  Future<void> _loadMessages() async {
    // ✅ اگر صفحه mount نیست، خروج
    if (!mounted) return;

    try {
      final messages = await _chatService.getMessagesHistory(
        widget.conversation.id,
        limit: 50,
      );

      final messagesWithReactions = await _loadReactionsForMessages(messages);

      // ✅ فقط اگر صفحه هنوز mount شده باشد
      if (mounted) {
        setState(() {
          _messages = messagesWithReactions.reversed.toList();
          _isLoading = false;
        });
      }

      await _markMessagesAsRead();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ✅ بارگذاری واکنش‌ها برای لیست پیام‌ها
  Future<List<ChatMessage>> _loadReactionsForMessages(
    List<ChatMessage> messages,
  ) async {
    if (messages.isEmpty) return messages;

    try {
      // ✅ استفاده از متد جدید بدون join
      final allReactions = await _chatService.getConversationReactions(
        widget.conversation.id,
      );

      // پر کردن واکنش‌ها برای هر پیام
      final updatedMessages = messages.map((msg) {
        final reactions = allReactions[msg.id];
        if (reactions != null && reactions.isNotEmpty) {
          return ChatMessage(
            id: msg.id,
            conversationId: msg.conversationId,
            senderId: msg.senderId,
            senderName: msg.senderName,
            senderAvatar: msg.senderAvatar,
            content: msg.content,
            type: msg.type,
            status: msg.status,
            metadata: msg.metadata,
            isRead: msg.isRead,
            isEdited: msg.isEdited,
            isDeleted: msg.isDeleted,
            replyToId: msg.replyToId,
            replyTo: msg.replyTo,
            reactions: reactions,
            createdAt: msg.createdAt,
            editedAt: msg.editedAt,
            deletedAt: msg.deletedAt,
            isTemp: msg.isTemp,
          );
        }
        return msg;
      }).toList();

      return updatedMessages;
    } catch (e) {
      print('❌ Error loading reactions: $e');
      return messages;
    }
  }

  // lib/features/chat/screens/buddy_chat_screen.dart

  void _scrollToBottom() {
    // ✅ اگر صفحه mount نیست، خروج
    if (!mounted) return;

    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ==================== ارسال پیام ====================

  // lib/features/chat/screens/buddy_chat_screen.dart

  Future<void> _sendMessage({
    String? text,
    MessageType type = MessageType.text,
    Map<String, dynamic>? metadata,
    String? replyToId,
  }) async {
    final content = text ?? _messageController.text.trim();

    if (content.isEmpty && replyToId == null && _replyToMessage == null) return;
    if (content.isEmpty && (replyToId != null || _replyToMessage != null))
      return;

    if (_userId == null || _isSending) return;

    final replyTo = _replyToMessage;
    final replyToIdToSend = replyToId ?? replyTo?.id;

    // ✅ ایجاد پیام موقت با وضعیت sending
    final tempMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: widget.conversation.id,
      senderId: _userId!,
      senderName: _buddyName,
      senderAvatar: _buddyAvatar,
      content: content,
      type: type,
      status: MessageStatus.sending,
      metadata: metadata,
      isRead: false,
      isEdited: false,
      isDeleted: false,
      replyToId: replyToIdToSend,
      replyTo: replyTo,
      reactions: [],
      createdAt: DateTime.now(),
      isTemp: true,
      hiddenFor: [],
    );

    // ✅ اضافه کردن پیام موقت به انتهای لیست (آخرین آیتم)
    setState(() {
      _messages.add(tempMessage); // ✅ به جای insert(0, ...) از add استفاده کنید
      _isSending = true;
      _replyToMessage = null;
      _showStickerPicker = false;
      _showGifPicker = false;
    });

    // ✅ پاک کردن متن و فوکوس روی اینپوت
    _messageController.clear();
    _focusNode.requestFocus(); // ✅ فوکوس مجدد روی اینپوت
    _sendTypingStatus(false);

    try {
      final typeString = type.toString().split('.').last;
      await _chatService.sendMessage(
        conversationId: widget.conversation.id,
        senderId: _userId!,
        content: content,
        type: typeString,
        metadata: metadata,
        replyToId: replyToIdToSend,
        senderName: _buddyName,
      );

      // ✅ به‌روزرسانی وضعیت به sent و تغییر ایندکس پیام
      setState(() {
        final index = _messages.indexWhere((msg) => msg.id == tempMessage.id);
        if (index != -1) {
          // ✅ پیام را به انتها ببریم (آخرین پیام)
          final updatedMessage = ChatMessage(
            id: tempMessage.id,
            conversationId: tempMessage.conversationId,
            senderId: tempMessage.senderId,
            senderName: tempMessage.senderName,
            senderAvatar: tempMessage.senderAvatar,
            content: tempMessage.content,
            type: tempMessage.type,
            status: MessageStatus.sent,
            metadata: tempMessage.metadata,
            isRead: tempMessage.isRead,
            isEdited: tempMessage.isEdited,
            isDeleted: tempMessage.isDeleted,
            replyToId: tempMessage.replyToId,
            replyTo: tempMessage.replyTo,
            reactions: tempMessage.reactions,
            createdAt: tempMessage.createdAt,
            editedAt: tempMessage.editedAt,
            deletedAt: tempMessage.deletedAt,
            isTemp: false,
            hiddenFor: tempMessage.hiddenFor,
          );

          // ✅ حذف پیام موقت و اضافه کردن پیام جدید در انتها
          _messages.removeAt(index);
          _messages.add(updatedMessage);
        }
      });

      // ✅ به‌روزرسانی last_seen_at
      await _updateLastSeen(_userId!);
    } catch (e) {
      // ❌ خطا - به‌روزرسانی وضعیت به failed
      setState(() {
        final index = _messages.indexWhere((msg) => msg.id == tempMessage.id);
        if (index != -1) {
          _messages[index] = ChatMessage(
            id: tempMessage.id,
            conversationId: tempMessage.conversationId,
            senderId: tempMessage.senderId,
            senderName: tempMessage.senderName,
            senderAvatar: tempMessage.senderAvatar,
            content: tempMessage.content,
            type: tempMessage.type,
            status: MessageStatus.failed,
            metadata: tempMessage.metadata,
            isRead: tempMessage.isRead,
            isEdited: tempMessage.isEdited,
            isDeleted: tempMessage.isDeleted,
            replyToId: tempMessage.replyToId,
            replyTo: tempMessage.replyTo,
            reactions: tempMessage.reactions,
            createdAt: tempMessage.createdAt,
            editedAt: tempMessage.editedAt,
            deletedAt: tempMessage.deletedAt,
            isTemp: false,
            hiddenFor: tempMessage.hiddenFor,
          );
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در ارسال پیام: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _updateLastSeen(String userId) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _chatService.client
          .from('profiles')
          .update({'last_seen_at': now})
          .eq('user_id', userId);
      print('📊 Updated last_seen_at for user $userId to $now');
    } catch (e) {
      print('⚠️ Error updating last_seen: $e');
    }
  }

  // ==================== ارسال عکس ====================

  // ✅ انتخاب و ارسال تصویر
  Future<void> _sendImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() {
        _isSending = true;
      });

      // آپلود عکس
      final file = File(image.path);
      final imageUrl = await _chatService.uploadImage(file);

      if (imageUrl != null) {
        await _sendMessage(
          text: imageUrl,
          type: MessageType.image,
          metadata: {'width': 1024, 'height': 1024},
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('خطا در آپلود عکس'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  // ==================== وضعیت تایپ ====================

  // ✅ در متد _sendTypingStatus:
  Future<void> _sendTypingStatus(bool isTyping) async {
    if (_userId == null) return;
    try {
      print('📊 Sending typing status: $isTyping');

      await _chatService.sendTypingStatus(
        conversationId: widget.conversation.id,
        userId: _userId!,
        isTyping: isTyping,
      );

      if (isTyping) {
        await _updateLastSeen(_userId!);
      }
    } catch (e) {
      print('⚠️ Typing status error: $e');
    }
  }

  // lib/features/chat/screens/buddy_chat_screen.dart

  // ✅ ارسال GIF با نوع صحیح
  void _sendGif(String gifName, String gifId) {
    _sendMessage(
      text: gifName,
      type: MessageType.gif, // ✅ این باید MessageType.gif باشد
      metadata: {'gif_id': gifId},
    );
    setState(() {
      _showGifPicker = false;
    });
  }

  // ==================== واکنش به پیام ====================

  // lib/features/chat/screens/buddy_chat_screen.dart

  Future<void> _toggleReaction(ChatMessage message, String emoji) async {
    if (_userId == null) return;

    try {
      // ✅ 1. اجرای عملیات toggle در دیتابیس
      await _chatService.toggleReaction(
        messageId: message.id,
        userId: _userId!,
        emoji: emoji,
      );
      await _updateLastSeen(_userId!);

      // ✅ 2. به‌روزرسانی محلی واکنش‌ها (با منطق مشابه)
      setState(() {
        final index = _messages.indexWhere((msg) => msg.id == message.id);
        if (index != -1) {
          final currentMessage = _messages[index];

          // دریافت واکنش‌های فعلی
          List<MessageReaction> currentReactions = List.from(
            currentMessage.reactions ?? [],
          );

          // ✅ بررسی اینکه آیا کاربر قبلاً واکنش داده است
          final userReactionIndex = currentReactions.indexWhere(
            (r) => r.userId == _userId,
          );

          if (userReactionIndex != -1) {
            // ✅ اگر کاربر قبلاً واکنش داده بود
            final existingEmoji = currentReactions[userReactionIndex].emoji;

            if (existingEmoji == emoji) {
              // ✅ اگر همان ایموجی بود → حذف کن
              currentReactions.removeAt(userReactionIndex);
            } else {
              // ✅ اگر ایموجی متفاوت بود → جایگزین کن
              currentReactions[userReactionIndex] = MessageReaction(
                userId: _userId!,
                emoji: emoji,
                userName: 'من',
                createdAt: DateTime.now(),
              );
            }
          } else {
            // ✅ اگر کاربر قبلاً واکنش نداده بود → اضافه کن
            currentReactions.add(
              MessageReaction(
                userId: _userId!,
                emoji: emoji,
                userName: 'من',
                createdAt: DateTime.now(),
              ),
            );
          }

          // به‌روزرسانی پیام
          _messages[index] = ChatMessage(
            id: currentMessage.id,
            conversationId: currentMessage.conversationId,
            senderId: currentMessage.senderId,
            senderName: currentMessage.senderName,
            senderAvatar: currentMessage.senderAvatar,
            content: currentMessage.content,
            type: currentMessage.type,
            status: currentMessage.status,
            metadata: currentMessage.metadata,
            isRead: currentMessage.isRead,
            isEdited: currentMessage.isEdited,
            isDeleted: currentMessage.isDeleted,
            replyToId: currentMessage.replyToId,
            replyTo: currentMessage.replyTo,
            reactions: currentReactions,
            createdAt: currentMessage.createdAt,
            editedAt: currentMessage.editedAt,
            deletedAt: currentMessage.deletedAt,
            isTemp: currentMessage.isTemp,
          );
        }
      });
    } catch (e) {
      print('❌ Error toggling reaction: $e');
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

  // ✅ ورود به حالت انتخاب
  void _enterSelectMode(String messageId) {
    setState(() {
      _isSelectMode = true;
      _selectedMessageIds.add(messageId);
    });
  }

  // ✅ خروج از حالت انتخاب
  void _exitSelectMode() {
    setState(() {
      _isSelectMode = false;
      _selectedMessageIds.clear();
    });
  }

  // ✅ انتخاب/لغو انتخاب یک پیام
  void _toggleMessageSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
        if (_selectedMessageIds.isEmpty) {
          _isSelectMode = false;
        }
      } else {
        _selectedMessageIds.add(messageId);
      }
    });
  }

  // ✅ حذف پیام‌های انتخاب شده
  Future<void> _deleteSelectedMessages() async {
    if (_selectedMessageIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف پیام‌های انتخاب شده'),
        content: Text(
          'آیا از حذف ${_selectedMessageIds.length} پیام انتخاب شده مطمئن هستید؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف همه', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && _userId != null) {
      try {
        // حذف همه پیام‌های انتخاب شده
        for (var messageId in _selectedMessageIds) {
          final message = _messages.firstWhere((msg) => msg.id == messageId);
          if (message.senderId == _userId) {
            await _chatService.deleteMessageForEveryone(messageId, _userId!);
          } else {
            await _chatService.deleteMessageForMe(messageId, _userId!);
          }
        }

        setState(() {
          _messages.removeWhere((msg) => _selectedMessageIds.contains(msg.id));
          _isSelectMode = false;
          _selectedMessageIds.clear();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_selectedMessageIds.length} پیام حذف شد 🗑️'),
              duration: const Duration(seconds: 1),
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

  // ==================== پاسخ به پیام ====================

  void _setReplyTo(ChatMessage message) {
    setState(() {
      _replyToMessage = message;
    });
    _focusNode.requestFocus();
  }

  // ==================== منوی پیام ====================

  // ✅ دیالوگ انتخاب نوع حذف (نسخه ساده)
  void _showDeleteOptionsDialog(ChatMessage message) {
    final isOwnMessage = message.senderId == _userId;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف پیام', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ حذف برای من
            ListTile(
              leading: const Icon(Icons.person_remove, color: Colors.orange),
              title: const Text('حذف برای من'),
              subtitle: const Text('پیام فقط برای شما حذف میشود'),
              onTap: () {
                Navigator.pop(context);
                _deleteMessageForMe(message);
              },
            ),

            // ✅ حذف برای همه (فقط برای پیام‌های خودتان)
            if (isOwnMessage)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text(
                  'حذف برای همه',
                  style: TextStyle(color: Colors.red),
                ),
                subtitle: const Text('پیام برای همه حذف میشود'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessageForEveryone(message);
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
        ],
      ),
    );
  }

  // lib/features/chat/screens/buddy_chat_screen.dart

  // ✅ اشتراک‌گذاری با پشتیبانی از تصویر
  void _forwardMessage(ChatMessage message) async {
    try {
      final String appLink =
          dotenv.env['APP_DOWNLOAD_LINK'] ?? 'https://innerhero.app/download';
      final String appName = dotenv.env['APP_NAME'] ?? 'قهرمان درون';

      // ✅ اگر پیام تصویر است
      if (message.type == MessageType.image) {
        // اشتراک‌گذاری با لینک تصویر
        final String shareText =
            '''
📷 ${message.senderName ?? 'کاربر'} یک تصویر ارسال کرده:

🔗 مشاهده تصویر: ${message.content}

━━━━━━━━━━━━━━━━━━━━
📱 $appName - اپلیکیشن مدیریت عادت‌ها
🔗 دانلود اپلیکیشن: $appLink
━━━━━━━━━━━━━━━━━━━━
''';

        await Share.share(shareText);
      } else {
        // ✅ اشتراک‌گذاری متن معمولی
        final String shareText =
            '''
📩 ${message.senderName ?? 'کاربر'} نوشته:

"${message.content}"

━━━━━━━━━━━━━━━━━━━━
📱 $appName - اپلیکیشن مدیریت عادت‌ها
🔗 دانلود اپلیکیشن: $appLink
━━━━━━━━━━━━━━━━━━━━
''';

        await Share.share(shareText);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('پیام با موفقیت به اشتراک گذاشته شد 📤'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error sharing message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در اشتراک‌گذاری: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ حذف برای خودم
  Future<void> _deleteMessageForMe(ChatMessage message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف برای من'),
        content: const Text('آیا از حذف این پیام برای خودتان مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirm == true && _userId != null) {
      try {
        await _chatService.deleteMessageForMe(message.id, _userId!);

        setState(() {
          _messages.removeWhere((msg) => msg.id == message.id);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('پیام برای شما حذف شد 🗑️'),
              duration: Duration(seconds: 1),
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

  // ✅ حذف برای همه
  Future<void> _deleteMessageForEveryone(ChatMessage message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف برای همه'),
        content: const Text('آیا از حذف این پیام برای همه مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'حذف برای همه',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && _userId != null) {
      try {
        await _chatService.deleteMessageForEveryone(message.id, _userId!);

        setState(() {
          _messages.removeWhere((msg) => msg.id == message.id);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('پیام برای همه حذف شد 🗑️'),
              duration: Duration(seconds: 1),
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

  // ✅ بررسی اینکه آیا کاربر فعلی به این پیام واکنش داده است
  bool _hasUserReacted(ChatMessage message) {
    if (_userId == null) return false;
    return message.reactions?.any((r) => r.userId == _userId) ?? false;
  }

  // ✅ دریافت ایموجی واکنش کاربر - نسخه اصلاح شده
  String? _getUserReactionEmoji(ChatMessage message) {
    if (_userId == null) return null;
    if (message.reactions == null) return null;

    for (var reaction in message.reactions!) {
      if (reaction.userId == _userId) {
        return reaction.emoji;
      }
    }
    return null;
  }

  // lib/features/chat/screens/buddy_chat_screen.dart

  // ✅ متد ساخت ویجت واکنش‌ها - با هایلایت border آبی دور ایموجی کاربر
  Widget _buildReactions(ChatMessage message) {
    final reactions = message.reactions;
    if (reactions == null || reactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final groupedReactions = _groupReactions(reactions);
    final userReactionEmoji = _getUserReactionEmoji(message);

    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: groupedReactions.map((item) {
          final emoji = item['emoji'] as String;
          final count = item['count'] as int;
          final isUserReacted = emoji == userReactionEmoji;

          return GestureDetector(
            onTap: () {
              _toggleReaction(message, emoji);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                // ✅ هایلایت border آبی دور ایموجی کاربر
                border: isUserReacted
                    ? Border.all(color: const Color(0xFF4A90E2), width: 1.5)
                    : null,
                borderRadius: BorderRadius.circular(12),
                // ✅ پس‌زمینه خالی (بدون رنگ)
                color: Colors.transparent,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    emoji,
                    style: TextStyle(
                      fontSize: 15,
                      color: isUserReacted
                          ? const Color(0xFF4A90E2) // ✅ آبی برای کاربر
                          : Colors.black87, // ✅ مشکی برای دیگران
                    ),
                  ),
                  if (count > 1) ...[
                    const SizedBox(width: 1),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        color: isUserReacted
                            ? const Color(0xFF4A90E2) // ✅ آبی برای کاربر
                            : Colors.grey.shade600, // ✅ خاکستری برای دیگران
                        fontWeight: isUserReacted
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? Colors.grey.shade700),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: color ?? Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ویرایش و حذف ====================

  // lib/features/chat/screens/buddy_chat_screen.dart

  // ✅ ویرایش پیام - طراحی مدرن (مثل تلگرام)
  void _editMessage(ChatMessage message) {
    final controller = TextEditingController(text: message.content);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.edit_outlined,
                color: Color(0xFF4A90E2),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'ویرایش پیام',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'متن جدید را وارد کنید...',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
            ),
            contentPadding: const EdgeInsets.all(14),
            fillColor: Colors.grey.shade50,
            filled: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              'انصراف',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newContent = controller.text.trim();
              if (newContent.isNotEmpty && newContent != message.content) {
                await _chatService.editMessage(
                  messageId: message.id,
                  userId: _userId!,
                  newContent: newContent,
                );
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              elevation: 0,
            ),
            child: const Text(
              'ذخیره تغییرات',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 4,
      ),
    );
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف پیام'),
        content: const Text('آیا از حذف این پیام مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && _userId != null) {
      try {
        // ✅ حذف کامل از دیتابیس
        await _chatService.deleteMessage(message.id, _userId!);

        // ✅ حذف از لیست محلی
        setState(() {
          _messages.removeWhere((msg) => msg.id == message.id);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('پیام حذف شد 🗑️'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطا در حذف پیام: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ✅ کپی متن پیام با فرمت بهتر
  void _copyMessage(ChatMessage message) {
    final String appLink = 'https://innerhero.app/download';
    final String appName = 'قهرمان درون';

    final String copyText =
        '''
${message.content}

━━━━━━━━━━━━━━━━━━━━
📱 ارسال شده از اپلیکیشن $appName
🔗 دانلود اپلیکیشن: $appLink
━━━━━━━━━━━━━━━━━━━━
''';

    // کپی در کلیپ‌بورد
    Clipboard.setData(ClipboardData(text: copyText));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('متن با لینک دانلود کپی شد 📋'),
        duration: Duration(seconds: 2),
      ),
    );
  }
  // ==================== ساخت پیام ====================

  // lib/features/chat/screens/buddy_chat_screen.dart

  Widget _buildMessageBubble(ChatMessage message) {
    final isMe = message.senderId == _userId;
    final isSystem = message.type == MessageType.system;
    final isSelected = _selectedMessageIds.contains(message.id);
    final isFailed = message.status == MessageStatus.failed;

    final GlobalKey bubbleKey = GlobalKey();

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.content,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    return Dismissible(
      key: Key(message.id),
      direction: DismissDirection.startToEnd,
      background: Container(
        margin: const EdgeInsets.only(bottom: 6),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF4A90E2).withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.reply, color: Color(0xFF4A90E2), size: 20),
            const SizedBox(width: 8),
            Text(
              'پاسخ',
              style: TextStyle(
                color: const Color(0xFF4A90E2),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        _setReplyTo(message);
        return false;
      },
      child: Container(
        key: bubbleKey,
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4A90E2).withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  // ✅ اگر پیام ناموفق است، منوی ویژه نمایش بده
                  if (isFailed) {
                    _showFailedMessageOptions(message);
                    return;
                  }

                  if (_isSelectMode) {
                    _toggleMessageSelection(message.id);
                  } else {
                    try {
                      final RenderBox renderBox =
                          bubbleKey.currentContext!.findRenderObject()
                              as RenderBox;

                      Offset position;

                      if (isMe) {
                        position = renderBox.localToGlobal(
                          Offset(
                            renderBox.size.width,
                            renderBox.size.height / 2,
                          ),
                        );
                      } else {
                        position = renderBox.localToGlobal(
                          Offset(0, renderBox.size.height / 2),
                        );
                      }

                      _showMessageActionsPopup(message, position);
                    } catch (e) {
                      _showMessageActionsPopup(message, const Offset(100, 200));
                    }
                  }
                },
                onLongPress: () {
                  if (!_isSelectMode) {
                    _enterSelectMode(message.id);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFF4A90E2) : Colors.white,
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomRight: isMe
                          ? const Radius.circular(4)
                          : const Radius.circular(16),
                      bottomLeft: isMe
                          ? const Radius.circular(16)
                          : const Radius.circular(4),
                    ),
                    border: _highlightedMessageId == message.id
                        ? Border.all(color: const Color(0xFFFFA500), width: 2)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                      if (_highlightedMessageId == message.id)
                        BoxShadow(
                          color: const Color(0xFFFFA500).withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      // ✅ سایه قرمز برای پیام‌های ناموفق
                      if (isFailed)
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.2),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ✅ ریپلای داخل حباب
                      if (message.replyTo != null)
                        GestureDetector(
                          onTap: () {
                            _scrollToMessage(message.replyToId!);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border(
                                left: BorderSide(
                                  color: isMe
                                      ? const Color(0xFF90CAF9)
                                      : const Color(0xFF4A90E2),
                                  width: 2.5,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.reply_outlined,
                                      size: 9,
                                      color: isMe
                                          ? Colors.white.withValues(alpha: 0.6)
                                          : const Color(0xFF4A90E2),
                                    ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        _getReplyToSenderName(message),
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: isMe
                                              ? Colors.white.withValues(
                                                  alpha: 0.7,
                                                )
                                              : const Color(0xFF4A90E2),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  _truncateText(message.replyTo!.content, 40),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isMe
                                        ? Colors.white.withValues(alpha: 0.55)
                                        : Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),

                      // ✅ محتوای اصلی پیام
                      _buildMessageContent(message, isMe),

                      // ✅ زمان و وضعیت
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          mainAxisAlignment: isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _getTimeOnly(message.createdAt),
                              style: TextStyle(
                                fontSize: 9,
                                color: isMe
                                    ? Colors.white.withValues(alpha: 0.6)
                                    : Colors.grey.shade500,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              // ✅ نمایش علامت تعجب قرمز برای پیام‌های ناموفق
                              if (isFailed)
                                const Icon(
                                  Icons.error_outline,
                                  size: 14,
                                  color: Colors.red,
                                )
                              else
                                _buildStatusIcon(message.status),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ✅ واکنش‌ها
              _buildReactions(message),
            ],
          ),
        ),
      ),
    );
  }

  // lib/features/chat/screens/buddy_chat_screen.dart

  // ✅ نمایش گزینه‌های پیام ناموفق
  void _showFailedMessageOptions(ChatMessage message) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
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
                const SizedBox(height: 16),
                const Text(
                  'ارسال پیام ناموفق بود',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'پیام به دلیل مشکل در اتصال ارسال نشد',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),

                // ✅ گزینه ارسال مجدد
                _buildFailedMessageOption(
                  icon: Icons.refresh,
                  title: 'ارسال مجدد',
                  subtitle: 'تلاش مجدد برای ارسال پیام',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    _resendFailedMessage(message);
                  },
                ),

                const Divider(height: 1),

                // ✅ گزینه کپی متن
                _buildFailedMessageOption(
                  icon: Icons.copy,
                  title: 'کپی متن',
                  subtitle: 'متن پیام را کپی کنید',
                  color: Colors.grey,
                  onTap: () {
                    Navigator.pop(context);
                    _copyMessage(message);
                  },
                ),

                const Divider(height: 1),

                // ✅ گزینه حذف
                _buildFailedMessageOption(
                  icon: Icons.delete_outline,
                  title: 'حذف پیام',
                  subtitle: 'پیام ناموفق را حذف کنید',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _deleteFailedMessage(message);
                  },
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // ✅ آیتم منوی پیام ناموفق
  Widget _buildFailedMessageOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      onTap: onTap,
    );
  }

  // lib/features/chat/screens/buddy_chat_screen.dart

  // ✅ ارسال مجدد پیام ناموفق
  Future<void> _resendFailedMessage(ChatMessage message) async {
    if (_userId == null) return;

    // ✅ تغییر وضعیت به sending
    setState(() {
      final index = _messages.indexWhere((msg) => msg.id == message.id);
      if (index != -1) {
        _messages[index].status = MessageStatus.sending;
      }
    });

    try {
      final typeString = message.type.toString().split('.').last;
      await _chatService.sendMessage(
        conversationId: widget.conversation.id,
        senderId: _userId!,
        content: message.content,
        type: typeString,
        metadata: message.metadata,
        replyToId: message.replyToId,
      );

      // ✅ ارسال موفق
      setState(() {
        final index = _messages.indexWhere((msg) => msg.id == message.id);
        if (index != -1) {
          _messages[index].status = MessageStatus.sent;
        }
      });

      await _updateLastSeen(_userId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('پیام با موفقیت ارسال شد ✅'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      // ❌ ارسال مجدد ناموفق
      setState(() {
        final index = _messages.indexWhere((msg) => msg.id == message.id);
        if (index != -1) {
          _messages[index].status = MessageStatus.failed;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در ارسال مجدد: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ حذف پیام ناموفق
  void _deleteFailedMessage(ChatMessage message) {
    setState(() {
      _messages.removeWhere((msg) => msg.id == message.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('پیام ناموفق حذف شد 🗑️'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // ✅ دریافت نام واقعی فرستنده پیام ریپلای شده
  String _getReplyToSenderName(ChatMessage message) {
    if (message.replyTo == null) return 'کاربر';

    final replyTo = message.replyTo!;

    // ✅ اگر فرستنده خود کاربر است
    if (replyTo.senderId == _userId) {
      return 'شما';
    }

    // ✅ اگر نام فرستنده در replyTo ذخیره شده است
    if (replyTo.senderName != null && replyTo.senderName!.isNotEmpty) {
      return replyTo.senderName!;
    }

    // ✅ اگر نام کاربر مقابل را داریم
    if (_buddyName != null && replyTo.senderId == _buddyId) {
      return _buddyName!;
    }

    // ✅ اگر هیچکدام نبود، از دیتابیس دریافت کن
    // (این بخش به صورت async قابل انجام است، اما برای سادگی مقدار پیش‌فرض برمیگرداند)
    return 'کاربر';
  }

  void _loadSenderNameToCache(String userId) {
    _chatService.client
        .from('profiles')
        .select('name')
        .eq('user_id', userId)
        .maybeSingle()
        .then((profile) {
          if (profile != null && profile['name'] != null && mounted) {
            setState(() {
              _userNameCache[userId] = profile['name'] as String;
            });
          }
        })
        .catchError((e) {
          print('⚠️ Error loading sender name: $e');
        });
  }

  Future<String> _getSenderNameFromDatabase(String userId) async {
    try {
      final profile = await _chatService.client
          .from('profiles')
          .select('name')
          .eq('user_id', userId)
          .maybeSingle();

      if (profile != null && profile['name'] != null) {
        return profile['name'] as String;
      }
      return 'کاربر';
    } catch (e) {
      return 'کاربر';
    }
  }

  // ✅ متد ساخت آیکون وضعیت پیام
  Widget _buildStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        );

      case MessageStatus.sent:
        return Icon(
          Icons.check,
          size: 14,
          color: Colors.white.withValues(alpha: 0.6),
        );

      case MessageStatus.delivered:
        return Icon(
          Icons.done_all,
          size: 14,
          color: Colors.white.withValues(alpha: 0.6),
        );

      case MessageStatus.seen:
        return Icon(Icons.done_all, size: 14, color: Colors.blue.shade300);

      case MessageStatus.failed:
        return Icon(Icons.error_outline, size: 14, color: Colors.red.shade300);
    }
  }

  // ✅ متد کمکی برای محدود کردن متن
  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }
  // lib/features/chat/screens/buddy_chat_screen.dart

  // ✅ اسکرول به پیام مورد نظر
  void _scrollToMessage(String messageId) {
    // پیدا کردن ایندکس پیام در لیست
    final index = _messages.indexWhere((msg) => msg.id == messageId);

    if (index != -1) {
      // محاسبه موقعیت اسکرول (چون لیست reverse است)
      final reverseIndex = _messages.length - 1 - index;

      // ✅ با انیمیشن به پیام اسکرول کن
      _scrollController.animateTo(
        reverseIndex * 80.0, // ارتفاع تقریبی هر پیام
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      // ✅ هایلایت کردن پیام (اختیاری)
      _highlightMessage(messageId);
    } else {
      // اگر پیام در لیست نبود (مثلاً قدیمی است)، پیام خطا نشان بده
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('پیام مورد نظر در دسترس نیست'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // ✅ هایلایت کردن پیام (اختیاری)
  void _highlightMessage(String messageId) {
    // میتونید یک متغیر برای ذخیره messageId هایلایت شده تعریف کنید
    // و در _buildMessageBubble چک کنید که اگر id مطابقت داشت،
    // یک border یا رنگ متفاوت به پیام بدهید

    // مثال ساده:
    setState(() {
      _highlightedMessageId = messageId;
    });

    // بعد از 2 ثانیه هایلایت رو بردارید
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _highlightedMessageId = null;
        });
      }
    });
  }

  // ✅ اضافه کردن متد برای ساخت ویجت تاریخ
  Widget _buildDateMarker(DateTime date) {
    return FutureBuilder<String>(
      future: _getDateLabel(date),
      builder: (context, snapshot) {
        final label = snapshot.data ?? '...';
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageContent(ChatMessage message, bool isMe) {
    switch (message.type) {
      case MessageType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                message.content,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.image_not_supported,
                  size: 50,
                  color: Colors.grey,
                ),
              ),
            ),
            if (message.metadata?['caption'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  message.metadata!['caption'],
                  style: TextStyle(
                    color: isMe ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
              ),
          ],
        );

      case MessageType.sticker:
        return Text(message.content, style: const TextStyle(fontSize: 48));

      case MessageType.gif:
        return Row(
          children: [
            const Text('🎬', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message.content,
                style: TextStyle(
                  color: isMe ? Colors.white : const Color(0xFF1A1A2E),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );

      default:
        return Text(
          message.content,
          style: TextStyle(
            color: isMe ? Colors.white : const Color(0xFF1A1A2E),
            fontSize: 14,
          ),
        );
    }
  }

  // lib/features/chat/screens/buddy_chat_screen.dart

  // ✅ دریافت تاریخ شمسی یا میلادی - نسخه اصلاح شده
  Future<String> _getDateLabel(DateTime date) async {
    final calendarType = await DateService.getCalendarType();

    if (calendarType == 'jalali') {
      final jalali = Jalali.fromDateTime(date);
      final now = Jalali.now();

      // ✅ اگر امروز است
      if (jalali.year == now.year &&
          jalali.month == now.month &&
          jalali.day == now.day) {
        return 'امروز';
      }

      // ✅ محاسبه دیروز شمسی
      final today = DateTime.now();
      final yesterdayDate = today.subtract(const Duration(days: 1));
      final jalaliYesterday = Jalali.fromDateTime(yesterdayDate);

      if (jalali.year == jalaliYesterday.year &&
          jalali.month == jalaliYesterday.month &&
          jalali.day == jalaliYesterday.day) {
        return 'دیروز';
      }

      // ✅ نمایش تاریخ شمسی
      const monthNames = [
        'فروردین',
        'اردیبهشت',
        'خرداد',
        'تیر',
        'مرداد',
        'شهریور',
        'مهر',
        'آبان',
        'آذر',
        'دی',
        'بهمن',
        'اسفند',
      ];
      return '${jalali.day} ${monthNames[jalali.month - 1]}';
    } else {
      // ✅ تاریخ میلادی
      final now = DateTime.now();

      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        return 'Today';
      }

      final yesterday = now.subtract(const Duration(days: 1));
      if (date.year == yesterday.year &&
          date.month == yesterday.month &&
          date.day == yesterday.day) {
        return 'Yesterday';
      }

      const monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${date.day} ${monthNames[date.month - 1]}';
    }
  }

  // ✅ دریافت فقط ساعت
  String _getTimeOnly(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // ✅ بررسی اینکه آیا دو تاریخ در یک روز هستند
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // ==================== ویجت‌ها ====================

  Widget _buildReplyPreview() {
    if (_replyToMessage == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'پاسخ به ${_replyToMessage!.senderName ?? "کاربر"}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  _replyToMessage!.content,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1A1A2E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _replyToMessage = null;
              });
            },
            icon: const Icon(Icons.close, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerPicker() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
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
                'استیکرها',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showStickerPicker = false;
                        _showGifPicker = true;
                      });
                    },
                    icon: const Icon(Icons.gif_box, size: 24),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showStickerPicker = false;
                      });
                    },
                    icon: const Icon(Icons.close, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                childAspectRatio: 1,
              ),
              itemCount: _popularEmojis.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    _sendMessage(
                      text: _popularEmojis[index],
                      type: MessageType.sticker,
                    );
                    setState(() {
                      _showStickerPicker = false;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        _popularEmojis[index],
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // lib/features/chat/screens/buddy_chat_screen.dart

  Widget _buildGifPicker() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
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
                'GIF',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showGifPicker = false;
                        _showStickerPicker = true;
                      });
                    },
                    icon: const Icon(Icons.emoji_emotions, size: 24),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showGifPicker = false;
                      });
                    },
                    icon: const Icon(Icons.close, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1,
              ),
              itemCount: _popularGifs.length,
              itemBuilder: (context, index) {
                final gif = _popularGifs[index];
                return GestureDetector(
                  onTap: () {
                    // ✅ ارسال با نوع GIF
                    _sendMessage(
                      text: gif['name']!,
                      type: MessageType.gif,
                      metadata: {'gif_id': gif['id'] ?? index.toString()},
                    );
                    setState(() {
                      _showGifPicker = false;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          gif['emoji']!,
                          style: const TextStyle(fontSize: 32),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          gif['name']!,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // lib/features/chat/screens/buddy_chat_screen.dart

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showStickerPicker) _buildStickerPicker(),
          if (_showGifPicker) _buildGifPicker(),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // پیش‌نمایش پاسخ
                _buildReplyPreview(),

                Row(
                  children: [
                    // ✅ دکمه چندرسانه‌ای (جدید)
                    IconButton(
                      onPressed: _showMediaMenuSheet,
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Color(0xFF4A90E2),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'ارسال محتوا',
                    ),

                    const SizedBox(width: 4),

                    // دکمه استیکر
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _showStickerPicker = !_showStickerPicker;
                          _showGifPicker = false;
                        });
                      },
                      icon: Icon(
                        _showStickerPicker
                            ? Icons.keyboard
                            : Icons.emoji_emotions,
                        color: _showStickerPicker
                            ? const Color(0xFF4A90E2)
                            : Colors.grey.shade600,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),

                    const SizedBox(width: 4),

                    // ورودی متن
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _messageController,
                          focusNode: _focusNode,
                          onChanged: (value) {
                            _sendTypingStatus(value.isNotEmpty);
                            setState(() {});
                          },
                          decoration: InputDecoration(
                            hintText: _replyToMessage != null
                                ? 'پاسخ به ${_replyToMessage!.senderName ?? "کاربر"}...'
                                : 'پیام خود را بنویسید...',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            prefixIcon: _replyToMessage != null
                                ? Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.reply,
                                      size: 16,
                                      color: const Color(0xFF4A90E2),
                                    ),
                                  )
                                : null,
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) {
                            if (_messageController.text.isNotEmpty ||
                                _replyToMessage != null) {
                              _sendMessage();
                            }
                          },
                          maxLines: 4,
                          minLines: 1,
                          maxLength: 500,
                          buildCounter:
                              (
                                BuildContext context, {
                                required int currentLength,
                                required bool isFocused,
                                required int? maxLength,
                              }) => null,
                        ),
                      ),
                    ),

                    const SizedBox(width: 4),

                    // دکمه ارسال
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color:
                            _isSending ||
                                (_messageController.text.isEmpty &&
                                    _replyToMessage == null)
                            ? Colors.grey.shade300
                            : const Color(0xFF4A90E2),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed:
                            _isSending ||
                                (_messageController.text.isEmpty &&
                                    _replyToMessage == null)
                            ? null
                            : () => _sendMessage(),
                        icon: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== AppBar ====================

  PreferredSizeWidget _buildAppBar() {
    if (_isSelectMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitSelectMode,
        ),
        title: Text(
          '${_selectedMessageIds.length} پیام انتخاب شده',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A2E),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _selectedMessageIds.isEmpty
                ? null
                : _deleteSelectedMessages,
          ),
        ],
      );
    }

    return AppBar(
      title: GestureDetector(
        onTap: () {
          // ✅ باز کردن صفحه پروفایل کاربر
          if (_buddyId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfileScreen(
                  userId: _buddyId!,
                  userName: _buddyName,
                  userAvatar: _buddyAvatar,
                ),
              ),
            );
          }
        },
        child: Row(
          children: [
            // ✅ آواتار با دایره وضعیت
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade200,
                  child: _buddyAvatar != null && _buddyAvatar!.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            _buddyAvatar!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Text(
                              _buddyName?.substring(0, 1).toUpperCase() ?? '?',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      : Text(
                          _buddyName?.substring(0, 1).toUpperCase() ?? '?',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _isBuddyOnline ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _buddyName ?? 'کاربر',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_isBuddyTyping)
                    const Text(
                      'در حال تایپ...',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      foregroundColor: const Color(0xFF1A1A2E),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: _showHeaderMenu,
          tooltip: 'گزینه‌های بیشتر',
        ),
      ],
    );
  }
  // ==================== Build ====================

  // lib/features/chat/screens/buddy_chat_screen.dart

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(),
      body: GestureDetector(
        onTap: () {
          if (_menuMessage != null) {
            _closeMenu();
          }
        },
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: _isLoading
                        ? _buildLoadingState()
                        : _messages.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message =
                                  _messages[_messages.length - 1 - index];
                              final widgets = <Widget>[];

                              // ✅ بررسی نیاز به نمایش مارکر تاریخ
                              if (index == _messages.length - 1) {
                                // ✅ اولین پیام (قدیمی‌ترین)
                                widgets.add(
                                  _buildDateMarker(message.createdAt),
                                );
                              } else {
                                // ✅ پیام بعدی (جدیدتر)
                                final nextMessage =
                                    _messages[_messages.length - 2 - index];
                                if (!_isSameDay(
                                  message.createdAt,
                                  nextMessage.createdAt,
                                )) {
                                  widgets.add(
                                    _buildDateMarker(message.createdAt),
                                  );
                                }
                              }

                              widgets.add(_buildMessageBubble(message));
                              return Column(children: widgets);
                            },
                          ),
                  ),
                  _buildInputBar(),
                ],
              ),
              _buildMessageActionsPopup(),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== حالت‌ها ====================

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF4A90E2), strokeWidth: 2),
          SizedBox(height: 12),
          Text(
            'در حال بارگذاری پیام‌ها...',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF4A90E2).withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: Color(0xFF4A90E2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'گفتگو را شروع کنید',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'با ${_buddyName ?? 'کاربر'} پیام دهید',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ==================== متدهای کمکی ====================

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      // امروز: فقط ساعت
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'دیروز';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} روز پیش';
    } else if (diff.inDays < 30) {
      return '${diff.inDays ~/ 7} هفته پیش';
    } else {
      return '${diff.inDays ~/ 30} ماه پیش';
    }
  }
}

// lib/features/chat/screens/buddy_chat_screen.dart

// ✅ مدل آیتم منو
class MediaMenuItem {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  final String? badge;

  MediaMenuItem({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
    this.badge,
  });
}
