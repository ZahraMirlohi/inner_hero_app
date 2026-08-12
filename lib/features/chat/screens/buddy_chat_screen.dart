// lib/features/chat/screens/buddy_chat_screen.dart

// ✅ ایمپورت‌های صحیح
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:linkify/linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

// ✅ سرویس‌های جدید
import '/services/chat_service.dart';
import '/services/supabase_service.dart';
import '/services/audio_player_service.dart';
import '/services/date_service.dart';

// ✅ بقیه ایمپورت‌ها به همین صورت باقی می‌مانند
import '../models/message_model.dart';
import '../models/conversation_model.dart';
import '../models/challenge_invite.dart';
import '../models/weekly_habit_performance.dart';
import '../models/today_habits_list.dart';
import '../models/xp_gift.dart';
import '../widgets/file_message_widget.dart';
import '../widgets/weekly_performance_widget.dart';
import '../widgets/today_habits_list_widget.dart';
import '../widgets/challenge_invite_widget.dart';
import '../widgets/active_challenge_widget.dart';
import '../widgets/xp_gift_card_widget.dart';
import '../widgets/create_challenge_sheet.dart';
import '../widgets/message_actions_menu.dart';
import '../widgets/xp_gift_dialog.dart';
import '../widgets/audio_player_header.dart';
import '/services/challenge_invite_service.dart';
import '/services/weekly_performance_service.dart';
import '/services/today_habits_service.dart';
import '/services/xp_gift_service.dart';
import 'user_profile_screen.dart';
import 'location_picker_screen.dart';

class BuddyChatScreen extends StatefulWidget {
  final Conversation conversation;

  const BuddyChatScreen({super.key, required this.conversation});

  @override
  State<BuddyChatScreen> createState() => _BuddyChatScreenState();
}

class _BuddyChatScreenState extends State<BuddyChatScreen>
    with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final SupabaseService _supabase = SupabaseService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  final Map<String, ChallengeInvite> _challengeCache = {};
  final Map<String, DateTime> _challengeCacheTime = {};
  static const Duration _cacheDuration = Duration(seconds: 30);

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
  bool _isLoadingChallenges = false;

  Set<String> _selectedMessageIds = {};
  StreamSubscription<List<ChatMessage>>? _messageSubscription;
  StreamSubscription<Map<String, bool>>? _typingSubscription;
  Offset? _menuPosition;
  ChatMessage? _menuMessage;
  ChatMessage? _pinnedMessage;

  final Map<String, GlobalKey> _messageKeys = {};

  int _todayHabitsCompleted = 0;
  int _todayHabitsRemaining = 0;
  int _currentStreak = 0;
  List<bool> _weekDays = List.filled(7, false);
  int _totalTodayHabits = 0;

  // ==================== وضعیت‌ها ====================
  bool _showStickerPicker = false;
  bool _showGifPicker = false;
  ChatMessage? _replyToMessage;
  Timer? _statusTimer;
  String? _conversationId;
  String? _currentUserId;
  String? _myName;

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

  final List<Map<String, String>> _popularGifs = [
    {'name': 'سلام', 'emoji': '👋', 'id': '1'},
    {'name': 'خنده', 'emoji': '😂', 'id': '2'},
    {'name': 'تشویق', 'emoji': '👏', 'id': '3'},
    {'name': 'عشق', 'emoji': '❤️', 'id': '4'},
    {'name': 'شکست', 'emoji': '😢', 'id': '5'},
    {'name': 'پیروزی', 'emoji': '🏆', 'id': '6'},
  ];

  // ✅ وضعیت بارگذاری چالش‌ها
  final Set<String> _loadingChallenges = {};

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

    _statusTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted && _buddyId != null) {
        _getBuddyStatus(_buddyId!);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  final Map<String, String> _userNameCache = {};

  // lib/features/chat/screens/buddy_chat_screen.dart

  // ✅ متد بارگذاری چالش‌ها - با مدیریت خطا
  Future<void> _loadChallengesFromMessages(List<ChatMessage> messages) async {
    // پیدا کردن همه challenge_idها از پیام‌ها
    final Set<String> challengeIds = {};
    for (var msg in messages) {
      if (msg.metadata != null) {
        if (msg.metadata!['is_challenge_invite'] == true ||
            msg.metadata!['is_active_challenge'] == true) {
          final id = msg.metadata!['challenge_id'] as String?;
          if (id != null && !_challengeCache.containsKey(id)) {
            challengeIds.add(id);
          }
        }
      }
    }

    if (challengeIds.isEmpty) return;

    try {
      final service = ChallengeInviteService();
      for (var id in challengeIds) {
        try {
          final challenge = await service.getChallengeById(id);
          if (challenge != null) {
            _challengeCache[id] = challenge;
            print('✅ Challenge loaded: $id');
          }
        } catch (e) {
          print('⚠️ Error loading challenge $id: $e');
          // ادامه بده، یک چالش خراب نباید بقیه را متوقف کند
        }
      }
    } catch (e) {
      print('⚠️ Error in _loadChallengesFromMessages: $e');
      // خطا را نادیده بگیر
    }
  }

  // lib/features/chat/screens/buddy_chat_screen.dart

  Future<void> _initChat() async {
    try {
      final user = await _chatService.getCurrentUser();

      if (user == null || !mounted) return;

      setState(() {
        _userId = user.id;
        _currentUserId = user.id;
        _conversationId = widget.conversation.id;
      });

      await _updateLastSeen(user.id);

      // ✅ دریافت نام خود کاربر
      try {
        final myProfile = await _supabase.client
            .from('profiles')
            .select('name')
            .eq('user_id', user.id)
            .maybeSingle();

        if (myProfile != null && mounted) {
          setState(() {
            _myName = myProfile['name'] as String? ?? 'کاربر';
          });
        }
      } catch (e) {
        print('⚠️ Error getting my name: $e');
        if (mounted) {
          setState(() {
            _myName = 'کاربر';
          });
        }
      }

      // ✅ پیدا کردن buddyId
      String buddyId = '';
      if (widget.conversation.memberIds.isNotEmpty) {
        final others = widget.conversation.memberIds
            .where((id) => id != user.id)
            .toList();
        if (others.isNotEmpty) {
          buddyId = others.first;
        }
      }

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
          debugPrint('❌ Error fetching members: $e');
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

          if (mounted) {
            if (profile != null) {
              setState(() {
                _buddyName = profile['name'] as String? ?? 'کاربر';
                _buddyAvatar = profile['avatar_url'];
              });

              final lastSeen = profile['last_seen_at'] ?? profile['updated_at'];
              _checkOnlineStatus(lastSeen);
              await _getBuddyStatus(buddyId);
            }
          }
        } catch (e) {
          debugPrint('❌ Error getting buddy profile: $e');
          if (mounted) {
            setState(() {
              _isBuddyOnline = false;
            });
          }
        }
      }

      // ✅ بارگذاری پیام‌ها با مدیریت خطا
      try {
        await _loadMessages();
        // ✅ اسکرول به انتهای صفحه بعد از بارگذاری
        _scrollToBottom();
      } catch (e) {
        print('❌ Error in _loadMessages: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }

      // lib/features/chat/screens/buddy_chat_screen.dart

      /// ✅ تنظیمات Realtime برای پیام‌ها - با به‌روزرسانی وضعیت
      _messageSubscription = _chatService
          .getMessages(widget.conversation.id, userId: _userId)
          .listen((newMessages) async {
            if (!mounted) return;

            try {
              final messagesWithReactions = await _loadReactionsForMessages(
                newMessages,
              );

              if (mounted) {
                // ✅ تعداد پیام‌های قبلی را ذخیره کن
                final oldMessageCount = _messages.length;

                setState(() {
                  _messages = messagesWithReactions.reversed.toList();
                  // ✅ بروزرسانی پیام پین شده
                  try {
                    _pinnedMessage = _messages.firstWhere((m) => m.isPinned);
                  } catch (e) {
                    _pinnedMessage = null;
                  }
                });

                // ✅ پیام‌های جدید را به عنوان خوانده شده علامت بزن
                await _markMessagesAsRead();

                // ✅ اگر پیام جدید از طرف مقابل رسیده، اسکرول به پایین
                if (_messages.length > oldMessageCount) {
                  final lastMessage = _messages.first;
                  if (lastMessage.senderId != _userId) {
                    _scrollToBottom();
                  }
                }
              }
            } catch (e) {
              print('❌ Error in realtime update: $e');
            }
          });
      // ✅ تنظیمات Realtime برای وضعیت تایپ
      _typingSubscription = _chatService
          .getTypingStatus(widget.conversation.id)
          .listen((typingData) {
            if (!mounted || _buddyId == null) return;

            try {
              final isTyping = typingData[_buddyId] == true;
              if (mounted && isTyping != _isBuddyTyping) {
                setState(() {
                  _isBuddyTyping = isTyping;
                });
              }
            } catch (e) {
              print('❌ Error in typing status: $e');
            }
          });
    } catch (e) {
      print('❌ Critical error in _initChat: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ✅ اصلاح متد _getCachedChallenge با مدیریت خطا
  Future<ChallengeInvite?> _getCachedChallenge(String challengeId) async {
    // اگر در حال بارگذاری است، صبر کن
    if (_loadingChallenges.contains(challengeId)) {
      await Future.delayed(const Duration(milliseconds: 100));
      return _challengeCache[challengeId];
    }

    // اگر در کش باشد و معتبر باشد
    if (_challengeCache.containsKey(challengeId) &&
        _challengeCacheTime.containsKey(challengeId)) {
      final cacheTime = _challengeCacheTime[challengeId]!;
      if (DateTime.now().difference(cacheTime) < _cacheDuration) {
        return _challengeCache[challengeId];
      }
    }

    _loadingChallenges.add(challengeId);

    try {
      final service = ChallengeInviteService();
      final challenge = await service.getChallengeById(challengeId);

      if (challenge != null) {
        _challengeCache[challengeId] = challenge;
        _challengeCacheTime[challengeId] = DateTime.now();
      }

      return challenge;
    } catch (e) {
      print('❌ Error getting challenge: $e');
      return null;
    } finally {
      _loadingChallenges.remove(challengeId);
    }
  }

  // ✅ متد پاک کردن کش
  void _clearChallengeCache(String challengeId) {
    _challengeCache.remove(challengeId);
    _challengeCacheTime.remove(challengeId);
  }

  // ✅ نمایش منوی چندرسانه‌ای (مینیمال و مدرن)
  void _showMediaMenuSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.35, // ✅ ارتفاع کمتر
          minChildSize: 0.25,
          maxChildSize: 0.45,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

                  // ✅ عنوان بسیار مینیمال
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      'ارسال',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ✅ لیست آیکون‌ها (بدون متن)
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5, // ✅ ۵ آیکون در هر ردیف
                            childAspectRatio: 1.0, // ✅ مربعی
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

  // ✅ ساخت آیتم منوی چندرسانه‌ای (مینیمال، بدون متن)
  Widget _buildMediaMenuItem(MediaMenuItem item) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        item.onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent, // ✅ پس‌زمینه شفاف
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ✅ آیکون اصلی
            Container(
              width: 52, // ✅ سایز آیکون
              height: 52,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12), // ✅ رنگ ملایم
                shape: BoxShape.circle, // ✅ دایره‌ای
              ),
              child: Icon(
                item.icon,
                color: item.color,
                size: 28, // ✅ سایز بزرگ‌تر
              ),
            ),
            // ❌ متن حذف شد
          ],
        ),
      ),
    );
  }

  // ✅ لیست آیتم‌های منو (به‌روزرسانی شده برای مینیمال)
  List<MediaMenuItem> _getMediaMenuItems() {
    final bool isWeb = identical(0, 0.0) ? false : true;

    return [
      MediaMenuItem(
        icon: Icons.image,
        title: '', // ✅ متن خالی
        color: const Color(0xFF4A90E2),
        onTap: _sendImage,
      ),
      MediaMenuItem(
        icon: Icons.location_on,
        title: '',
        color: const Color(0xFF2ECC71),
        onTap: _sendLocation,
      ),
      // ✅ فقط در موبایل و دسکتاپ
      if (!isWeb)
        MediaMenuItem(
          icon: Icons.contact_phone,
          title: '',
          color: const Color(0xFFE74C3C),
          onTap: _sendContact,
        ),
      MediaMenuItem(
        icon: Icons.attach_file,
        title: '',
        color: const Color(0xFFF39C12),
        onTap: _sendFile,
      ),
      MediaMenuItem(
        icon: Icons.music_note,
        title: '',
        color: const Color(0xFF9B59B6),
        onTap: _sendMusic,
      ),
      MediaMenuItem(
        icon: Icons.trending_up,
        title: '',
        color: const Color(0xFF1ABC9C),
        onTap: _sendDailyProgressCard,
      ),
      MediaMenuItem(
        icon: Icons.analytics,
        title: '',
        color: const Color(0xFF7C3AED),
        onTap: _sendWeeklyPerformance,
      ),
      MediaMenuItem(
        icon: Icons.checklist,
        title: '',
        color: const Color(0xFFFFA500),
        onTap: _sendTodayHabitsList,
      ),
      MediaMenuItem(
        icon: Icons.emoji_events,
        title: '',
        color: const Color(0xFFE74C3C),
        onTap: _showCreateChallengeDialog,
      ),
      MediaMenuItem(
        icon: Icons.stars,
        title: '',
        color: const Color(0xFFFFA500),
        onTap: _sendXPGift,
      ),
    ];
  }

  // ✅ ارسال لوکیشن
  void _sendLocation() async {
    final locationText = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
    );

    if (locationText != null && locationText.isNotEmpty) {
      _sendMessage(text: locationText, type: MessageType.text);
    }
  }

  // ✅ متد ارسال شماره تماس - با flutter_contacts
  Future<void> _sendContact() async {
    // ✅ تشخیص Web
    final bool isWeb = kIsWeb;

    if (isWeb) {
      _showContactInputDialog();
      return;
    }

    // ✅ در موبایل/دسکتاپ: از flutter_contacts استفاده کن
    try {
      // ✅ درخواست دسترسی
      final hasPermission = await FlutterContacts.requestPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('برای ارسال شماره تماس به دسترسی مخاطبان نیاز است'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // ✅ دریافت مخاطبان
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      if (!mounted) return;

      if (contacts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('مخاطبی در گوشی شما وجود ندارد'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // ✅ نمایش دیالوگ انتخاب مخاطب
      final selectedContact = await showModalBottomSheet<Contact>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
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
                    const SizedBox(height: 16),
                    const Text(
                      'انتخاب مخاطب',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${contacts.length} مخاطب',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: contacts.length,
                        itemBuilder: (context, index) {
                          final contact = contacts[index];
                          final displayName = contact.displayName ?? 'بدون نام';
                          final phones = contact.phones
                              .map((p) => p.number)
                              .toList();

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(
                                0xFF4A90E2,
                              ).withValues(alpha: 0.1),
                              child: Text(
                                displayName.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF4A90E2),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: phones.isNotEmpty
                                ? Text(
                                    phones.first,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  )
                                : null,
                            onTap: () => Navigator.pop(context, contact),
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

      if (selectedContact != null && mounted) {
        final phones = selectedContact.phones.map((p) => p.number).toList();
        final phoneNumber = phones.isNotEmpty
            ? phones.first
            : 'شماره موجود نیست';
        final displayName = selectedContact.displayName ?? 'کاربر';

        final contactText =
            '''
📞 شماره تماس
━━━━━━━━━━━━━━━━━━━━
👤 نام: $displayName
📱 شماره: $phoneNumber
━━━━━━━━━━━━━━━━━━━━
''';

        _sendMessage(text: contactText, type: MessageType.text);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در دریافت مخاطبان: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ متد جدید برای Web - نمایش دیالوگ وارد کردن شماره
  void _showContactInputDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();

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
                Icons.contact_phone,
                color: Color(0xFF4A90E2),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'ارسال شماره تماس',
              style: TextStyle(
                fontSize: 17,
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
              controller: nameController,
              decoration: InputDecoration(
                hintText: 'نام مخاطب',
                prefixIcon: const Icon(
                  Icons.person_outline,
                  color: Color(0xFF4A90E2),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'شماره تماس',
                prefixIcon: const Icon(
                  Icons.phone_outlined,
                  color: Color(0xFF4A90E2),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();

              if (name.isEmpty && phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('لطفاً نام یا شماره تماس را وارد کنید'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }

              Navigator.pop(context);

              final contactText =
                  '''
📞 شماره تماس
━━━━━━━━━━━━━━━━━━━━
👤 نام: ${name.isNotEmpty ? name : 'کاربر'}
📱 شماره: ${phone.isNotEmpty ? phone : 'شماره موجود نیست'}
━━━━━━━━━━━━━━━━━━━━
''';

              _sendMessage(text: contactText, type: MessageType.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('ارسال'),
          ),
        ],
      ),
    );
  }

  // ✅ متد ارسال فایل - اصلاح شده
  Future<void> _sendFile() async {
    try {
      print('📁 _sendFile called!');

      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) {
        print('⚠️ No file selected');
        return;
      }

      final file = result.files.first;
      final fileName = file.name;
      final fileSize = file.size ?? 0;
      final fileBytes = file.bytes;

      if (fileBytes == null) {
        _showSnackBar('فایل قابل خواندن نیست');
        return;
      }

      // ✅ ایجاد پیام موقت
      final tempMessageId = DateTime.now().millisecondsSinceEpoch.toString();

      final tempMessage = ChatMessage(
        id: tempMessageId,
        conversationId: widget.conversation.id,
        senderId: _userId!,
        senderName: _myName,
        senderAvatar: null,
        content: '📁 در حال آپلود فایل...',
        type: MessageType.text,
        status: MessageStatus.sending,
        metadata: {
          'file_name': fileName,
          'file_size': fileSize,
          'type': 'file',
          'is_uploading': true,
          'platform': kIsWeb ? 'web' : 'mobile',
        },
        isRead: false,
        isEdited: false,
        isDeleted: false,
        createdAt: DateTime.now(),
        isTemp: true,
        hiddenFor: [],
      );

      setState(() {
        _messages.insert(0, tempMessage);
        _isSending = true;
      });

      _scrollToBottom();

      // ✅ آپلود فایل
      final String fileUrl = await _uploadFileToStorageHttp(
        fileBytes: fileBytes,
        fileName: fileName,
        folder: 'chat_files',
      );

      if (fileUrl.isEmpty) {
        setState(() {
          final index = _messages.indexWhere((msg) => msg.id == tempMessageId);
          if (index != -1) {
            _messages[index].status = MessageStatus.failed;
          }
          _isSending = false;
        });
        _showSnackBar('خطا در آپلود فایل');
        return;
      }

      print('✅ File uploaded successfully: $fileUrl');

      // ✅ ارسال پیام واقعی
      final Map<String, dynamic> metadata = {
        'file_url': fileUrl,
        'file_name': fileName,
        'file_size': fileSize,
        'type': 'file',
        'platform': kIsWeb ? 'web' : 'mobile',
        'is_progress_card': false,
        'is_uploading': false,
      };

      // ✅ ساخت متن پیام با لینک فایل
      final fileText =
          '''
📁 فایل ارسال شد
━━━━━━━━━━━━━━━━━━━━
📄 نام فایل: $fileName
📦 حجم: ${_getFileSizeString(fileSize)}
━━━━━━━━━━━━━━━━━━━━
''';

      // ✅ ارسال پیام به دیتابیس
      await _chatService.sendMessage(
        conversationId: widget.conversation.id,
        senderId: _userId!,
        content: fileText,
        type: 'text',
        metadata: metadata,
        senderName: _myName,
      );

      print('✅ File message sent to database');

      // ✅ حذف پیام موقت
      setState(() {
        _messages.removeWhere((msg) => msg.id == tempMessageId);
        _isSending = false;
      });

      // ✅ بارگذاری مجدد پیام‌ها برای نمایش فایل
      await _loadMessages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📁 فایل با موفقیت ارسال شد'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('❌ Error in _sendFile: $e');
      setState(() {
        _isSending = false;
      });
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

  Future<void> _sendMusic() async {
    try {
      print('🎵 _sendMusic called!');

      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.audio,
      );

      if (result == null || result.files.isEmpty) {
        print('⚠️ No music file selected');
        return;
      }

      final file = result.files.first;
      final fileName = file.name;
      final fileSize = file.size ?? 0;
      final fileBytes = file.bytes;

      print('🎵 Music file selected:');
      print('   - Name: $fileName');
      print('   - Size: $fileSize');

      if (fileBytes == null) {
        _showSnackBar('فایل قابل خواندن نیست');
        return;
      }

      // ✅ 1. ایجاد پیام موقت با وضعیت "در حال ارسال"
      final tempMessageId = DateTime.now().millisecondsSinceEpoch.toString();

      final tempMessage = ChatMessage(
        id: tempMessageId,
        conversationId: widget.conversation.id,
        senderId: _userId!,
        senderName: _myName,
        senderAvatar: null,
        content: '🎵 در حال ارسال موزیک...',
        type: MessageType.text,
        status: MessageStatus.sending,
        metadata: {
          'file_name': fileName,
          'file_size': fileSize,
          'type': 'music',
          'is_uploading': true,
          'platform': kIsWeb ? 'web' : 'mobile',
        },
        isRead: false,
        isEdited: false,
        isDeleted: false,
        createdAt: DateTime.now(),
        isTemp: true,
        hiddenFor: [],
      );

      // ✅ 2. اضافه کردن پیام موقت به لیست
      setState(() {
        _messages.insert(0, tempMessage);
        _isSending = true;
      });

      _scrollToBottom();

      // ✅ 3. آپلود فایل
      final String fileUrl = await _uploadFileToStorageHttp(
        fileBytes: fileBytes,
        fileName: fileName,
        folder: 'chat_music',
      );

      if (fileUrl.isEmpty) {
        // ❌ اگر آپلود失敗، پیام را به حالت failed تغییر بده
        setState(() {
          final index = _messages.indexWhere((msg) => msg.id == tempMessageId);
          if (index != -1) {
            _messages[index] = ChatMessage(
              id: _messages[index].id,
              conversationId: _messages[index].conversationId,
              senderId: _messages[index].senderId,
              senderName: _messages[index].senderName,
              senderAvatar: _messages[index].senderAvatar,
              content: '❌ خطا در ارسال موزیک',
              type: MessageType.text,
              status: MessageStatus.failed,
              metadata: _messages[index].metadata,
              isRead: _messages[index].isRead,
              isEdited: _messages[index].isEdited,
              isDeleted: _messages[index].isDeleted,
              createdAt: _messages[index].createdAt,
              isTemp: false,
              hiddenFor: _messages[index].hiddenFor,
            );
          }
          _isSending = false;
        });

        _showSnackBar('خطا در آپلود موزیک');
        return;
      }

      print('✅ Music uploaded to: $fileUrl');

      // ✅ 4. ساخت metadata نهایی
      final Map<String, dynamic> metadata = {
        'file_url': fileUrl,
        'file_name': fileName,
        'file_size': fileSize,
        'type': 'music',
        'platform': kIsWeb ? 'web' : 'mobile',
        'is_progress_card': false,
        'is_uploading': false,
      };

      final musicText =
          '''
🎵 فایل موزیک
━━━━━━━━━━━━━━━━━━━━
🎶 نام: $fileName
📦 حجم: ${_getFileSizeString(fileSize)}
━━━━━━━━━━━━━━━━━━━━
''';

      // ✅ 5. ارسال پیام واقعی به دیتابیس - با استفاده از sendMessage مستقیم
      // و سپس پیام موقت را با پیام واقعی جایگزین کنید
      try {
        await _chatService.sendMessage(
          conversationId: widget.conversation.id,
          senderId: _userId!,
          content: musicText,
          type: 'text',
          metadata: metadata,
          senderName: _myName,
        );

        print('✅ Music message sent to database');

        // ✅ 6. پیام موقت را با یک پیام واقعی جایگزین کن
        // برای این کار باید پیام جدید را از دیتابیس دریافت کنیم
        // یا اینکه پیام موقت را به روزرسانی کنیم

        // روش: پیام موقت را به روزرسانی کن
        setState(() {
          final index = _messages.indexWhere((msg) => msg.id == tempMessageId);
          if (index != -1) {
            _messages[index] = ChatMessage(
              id: tempMessageId,
              conversationId: widget.conversation.id,
              senderId: _userId!,
              senderName: _myName,
              senderAvatar: null,
              content: musicText,
              type: MessageType.text,
              status: MessageStatus.sent,
              metadata: metadata,
              isRead: false,
              isEdited: false,
              isDeleted: false,
              replyToId: null,
              replyTo: null,
              reactions: [],
              createdAt: DateTime.now(),
              editedAt: null,
              deletedAt: null,
              isTemp: false,
              hiddenFor: [],
            );
          }
          _isSending = false;
        });

        print('✅ _sendMusic completed!');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎵 فایل موزیک ارسال شد'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } catch (e) {
        print('❌ Error sending music message: $e');
        // در صورت خطا، پیام موقت را به حالت failed تغییر بده
        setState(() {
          final index = _messages.indexWhere((msg) => msg.id == tempMessageId);
          if (index != -1) {
            _messages[index] = ChatMessage(
              id: _messages[index].id,
              conversationId: _messages[index].conversationId,
              senderId: _messages[index].senderId,
              senderName: _messages[index].senderName,
              senderAvatar: _messages[index].senderAvatar,
              content: '❌ خطا در ارسال موزیک',
              type: MessageType.text,
              status: MessageStatus.failed,
              metadata: _messages[index].metadata,
              isRead: _messages[index].isRead,
              isEdited: _messages[index].isEdited,
              isDeleted: _messages[index].isDeleted,
              createdAt: _messages[index].createdAt,
              isTemp: false,
              hiddenFor: _messages[index].hiddenFor,
            );
          }
          _isSending = false;
        });
      }
    } catch (e) {
      print('❌ Error in _sendMusic: $e');

      // ❌ در صورت خطا، پیام موقت را به حالت failed تغییر بده
      setState(() {
        final index = _messages.indexWhere(
          (msg) =>
              msg.metadata != null && msg.metadata!['is_uploading'] == true,
        );
        if (index != -1) {
          _messages[index] = ChatMessage(
            id: _messages[index].id,
            conversationId: _messages[index].conversationId,
            senderId: _messages[index].senderId,
            senderName: _messages[index].senderName,
            senderAvatar: _messages[index].senderAvatar,
            content: '❌ خطا در ارسال موزیک',
            type: MessageType.text,
            status: MessageStatus.failed,
            metadata: _messages[index].metadata,
            isRead: _messages[index].isRead,
            isEdited: _messages[index].isEdited,
            isDeleted: _messages[index].isDeleted,
            createdAt: _messages[index].createdAt,
            isTemp: false,
            hiddenFor: _messages[index].hiddenFor,
          );
        }
        _isSending = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در ارسال موزیک: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ متد ارسال ویجت عملکرد هفتگی
  void _sendWeeklyPerformance() async {
    if (_userId == null) {
      _showSnackBar('لطفاً وارد حساب کاربری خود شوید');
      return;
    }

    try {
      // نمایش لودینگ
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('در حال آماده‌سازی ویجت...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final service = WeeklyPerformanceService();
      final performance = await service.getUserWeeklyPerformance(_userId!);

      if (performance == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('هیچ عادتی برای نمایش وجود ندارد'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // ✅ ساخت متن ویجت
      final successPercent = (performance.successRate * 100).toInt();
      final motivationalMessage = performance.getMotivationalMessage();

      final String widgetText =
          '''
📊 عملکرد هفتگی عادت‌ها
━━━━━━━━━━━━━━━━━━━━
✅ انجام شده: ${performance.completedHabits} از ${performance.totalHabits}
📈 نرخ موفقیت: $successPercent%
🔥 استریک: ${_currentStreak} روز
━━━━━━━━━━━━━━━━━━━━
$motivationalMessage
━━━━━━━━━━━━━━━━━━━━
''';

      // ✅ ارسال با metadata
      _sendMessage(
        text: widgetText,
        type: MessageType.text,
        metadata: {
          'type': 'weekly_performance',
          'userId': _userId,
          'userName': performance.userName,
          'habits': performance.habits.map((h) => h.toMap()).toList(),
          'weekStart': performance.weekStart.toIso8601String(),
          'weekEnd': performance.weekEnd.toIso8601String(),
          'totalHabits': performance.totalHabits,
          'completedHabits': performance.completedHabits,
          'successRate': performance.successRate,
          'is_performance_widget': true,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📊 ویجت عملکرد ارسال شد'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('❌ Error sending weekly performance: $e');
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

  // ✅ متد ارسال لیست عادت‌های امروز
  void _sendTodayHabitsList() async {
    if (_userId == null) {
      _showSnackBar('لطفاً وارد حساب کاربری خود شوید');
      return;
    }

    try {
      // نمایش لودینگ
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('در حال آماده‌سازی لیست...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final service = TodayHabitsService();
      final data = await service.getUserTodayHabits(_userId!);

      if (data == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('هیچ عادتی برای امروز وجود ندارد'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // ✅ ساخت متن ویجت
      final rate = (data.completionRate * 100).toInt();
      final jalaliDate = Jalali.fromDateTime(data.date);
      final dateString = '${jalaliDate.day} ${_getMonthName(jalaliDate.month)}';

      final String widgetText =
          '''
📋 لیست امروز (${dateString})
━━━━━━━━━━━━━━━━━━━━
✅ انجام شده: ${data.completedItems} از ${data.totalItems}
📈 نرخ موفقیت: $rate%
━━━━━━━━━━━━━━━━━━━━
${data.completionMessage}
━━━━━━━━━━━━━━━━━━━━
''';

      // ✅ ارسال با metadata
      _sendMessage(
        text: widgetText,
        type: MessageType.text,
        metadata: {
          'is_today_list_widget': true,
          'userId': _userId,
          'userName': data.userName,
          'date': data.date.toIso8601String(),
          'habits': data.habits.map((h) => h.toMap()).toList(),
          'tasks': data.tasks.map((t) => t.toMap()).toList(),
          'challenges': data.challenges.map((c) => c.toMap()).toList(),
          'quests': data.quests.map((q) => q.toMap()).toList(),
          'totalItems': data.totalItems,
          'completedItems': data.completedItems,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📋 لیست امروز ارسال شد'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('❌ Error sending today habits list: $e');
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

  // ✅ متد کمکی برای نام ماه
  String _getMonthName(int month) {
    const months = [
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
    return months[month - 1];
  }

  // ✅ اصلاح متد _showCreateChallengeDialog
  void _showCreateChallengeDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return CreateChallengeSheet(
          buddyName: _buddyName ?? 'هم‌مسیر',
          buddyId: _buddyId ?? '',
          userId: _userId ?? '',
          userName: _myName ?? 'کاربر', // ✅ نام خود کاربر
          onSubmit: (challenge) {
            _sendChallengeInvite(challenge);
          },
        );
      },
    );
  }

  // lib/features/chat/screens/buddy_chat_screen.dart

  void _sendChallengeInvite(ChallengeInvite challenge) async {
    try {
      final service = ChallengeInviteService();
      final created = await service.createChallenge(
        creatorId: challenge.creatorId,
        creatorName: challenge.creatorName,
        opponentId: challenge.opponentId,
        opponentName: challenge.opponentName,
        title: challenge.title,
        description: challenge.description,
        habits: challenge.habits,
        duration: challenge.duration,
        xpReward: challenge.xpReward,
        startDate: challenge.startDate,
      );

      if (created != null) {
        // ✅ اضافه کردن به کش بلافاصله
        _challengeCache[created.id] = created;

        // ✅ ارسال پیام
        _sendMessage(
          text:
              '🏆 ${created.title}\n\n${created.description}\n\n📋 ${created.habits.length} عادت • ${created.duration} روز • ${created.xpReward} XP',
          type: MessageType.text,
          metadata: {'is_challenge_invite': true, 'challenge_id': created.id},
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🏆 چالش با موفقیت ارسال شد!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error sending challenge: $e');
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

  // ✅ اصلاح متد _respondToChallenge
  void _respondToChallenge(String challengeId, bool accept) async {
    try {
      final service = ChallengeInviteService();
      final success = await service.respondToChallenge(challengeId, accept);

      if (success && mounted) {
        // ✅ پاک کردن کش چالش
        _challengeCache.remove(challengeId);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? '✅ چالش پذیرفته شد!' : '❌ چالش رد شد'),
            backgroundColor: accept ? Colors.green : Colors.orange,
          ),
        );

        // ✅ بارگذاری مجدد پیام‌ها برای نمایش ویجت جدید
        _loadMessages();
      }
    } catch (e) {
      print('❌ Error responding to challenge: $e');
    }
  }
  // ==================== متدهای کمکی ====================

  // ✅ تبدیل حجم فایل به رشته خوانا
  String _getFileSizeString(int bytes) {
    if (bytes == 0) return '0 B';

    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    var size = bytes.toDouble();

    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }

    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  // ==================== آپلود فایل به Supabase Storage ====================

  Future<String> _uploadFileToStorage({
    required Uint8List fileBytes,
    required String fileName,
    required String folder,
  }) async {
    try {
      final user = await _supabase.getCurrentUser();
      if (user == null) {
        _showSnackBar('لطفاً وارد حساب کاربری خود شوید');
        return '';
      }

      // ✅ فقط پسوند فایل را نگه دار
      final extension = fileName.contains('.')
          ? fileName.substring(fileName.lastIndexOf('.'))
          : '.mp3';

      final simpleFileName =
          '${DateTime.now().millisecondsSinceEpoch}$extension';
      final path = '$folder/${user.id}/$simpleFileName';

      print('📤 Uploading to: $path');

      // ✅ آپلود بدون FileOptions (با تنظیم contentType به صورت جداگانه)
      await _supabase.client.storage
          .from('chat_files')
          .uploadBinary(path, fileBytes);

      final String publicUrl = _supabase.client.storage
          .from('chat_files')
          .getPublicUrl(path);

      print('✅ Uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Upload error: $e');
      _showSnackBar('خطا در آپلود: ${e.toString()}');
      return '';
    }
  }

  /// ✅ روش جایگزین آپلود با http
  Future<String> _uploadFileToStorageHttp({
    required Uint8List fileBytes,
    required String fileName,
    required String folder,
  }) async {
    try {
      final user = await _supabase.getCurrentUser();
      if (user == null) {
        _showSnackBar('لطفاً وارد حساب کاربری خود شوید');
        return '';
      }

      final session = _supabase.client.auth.currentSession;
      if (session == null) {
        _showSnackBar('جلسه کاربری معتبر نیست');
        return '';
      }

      // ✅ فقط پسوند فایل را نگه دار
      final extension = fileName.contains('.')
          ? fileName.substring(fileName.lastIndexOf('.'))
          : '.mp3';

      final simpleFileName =
          '${DateTime.now().millisecondsSinceEpoch}$extension';
      final path = '$folder/${user.id}/$simpleFileName';

      final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
      final storageUrl = '$supabaseUrl/storage/v1/object/chat_files/$path';

      print('📤 Uploading to (HTTP): $storageUrl');

      final response = await http.put(
        Uri.parse(storageUrl),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'audio/mpeg', // ✅ برای MP3
          'x-upsert': 'true', // ✅ اگر فایل وجود داشت، جایگزین کن
        },
        body: fileBytes,
      );

      print('📤 HTTP Response status: ${response.statusCode}');
      print('📤 HTTP Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final publicUrl = _supabase.client.storage
            .from('chat_files')
            .getPublicUrl(path);
        print('✅ Uploaded (HTTP): $publicUrl');
        return publicUrl;
      } else {
        print('❌ HTTP upload failed: ${response.statusCode}');
        _showSnackBar('خطا در آپلود: ${response.statusCode}');
        return '';
      }
    } catch (e) {
      print('❌ Upload error (HTTP): $e');
      _showSnackBar('خطا در آپلود: ${e.toString()}');
      return '';
    }
  }

  // ==================== ویجت تصویر ====================

  Widget _buildImageMessage(ChatMessage message, bool isMe) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        message.content,
        width: 200,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
      ),
    );
  }

  // lib/features/chat/screens/buddy_chat_screen.dart

  // ✅ متد ارسال یادآور در چت
  void _sendReminder(String challengeTitle) async {
    if (_userId == null || _buddyId == null) return;

    final reminderText =
        '''
⏰ یادآوری چالش
━━━━━━━━━━━━━━━━━━━━
🏆 چالش: $challengeTitle

سلام! وقتشه که عادت‌های امروز رو انجام بدی! 💪
به یاد داشته باش که هر روز یک قدم به قهرمانی نزدیک‌تر میشی.

🔥 ادامه بده! بهت ایمان دارم!
━━━━━━━━━━━━━━━━━━━━
''';

    await _sendMessage(
      text: reminderText,
      type: MessageType.text,
      metadata: {'type': 'reminder', 'challenge_title': challengeTitle},
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ یادآوری با موفقیت ارسال شد!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ==================== ویجت استیکر ====================

  Widget _buildStickerMessage(ChatMessage message, bool isMe) {
    return Text(message.content, style: const TextStyle(fontSize: 48));
  }

  // ==================== ویجت GIF ====================

  Widget _buildGifMessage(ChatMessage message, bool isMe) {
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
  }

  // ==================== متدهای کمکی ====================

  // lib/features/chat/screens/buddy_chat_screen.dart

  // ✅ 1. اصلاح متد _sendDailyProgressCard - حذف .then و استفاده از async/await
  void _sendDailyProgressCard() {
    // دریافت اطلاعات واقعی با async/await
    _getTodayStatsAndSend();
  }

  // ✅ 2. متد جدید برای دریافت آمار و ارسال کارت
  Future<void> _getTodayStatsAndSend() async {
    try {
      final user = await _supabase.getCurrentUser();
      if (user == null) return;

      // دریافت عادت‌های امروز
      final habits = await _supabase.getHabits(user.id);
      final today = DateTime.now();

      int total = 0;
      int completed = 0;

      for (var habit in habits) {
        if (!habit.isActive) continue;
        if (!habit.shouldDoOnDate(today)) continue;

        total++;
        final isCompleted = await _supabase.isHabitCompletedOnDate(
          habit.id,
          user.id,
          today,
        );
        if (isCompleted) completed++;
      }

      // دریافت استریک
      final profile = await _supabase.client
          .from('profiles')
          .select('current_streak, best_streak')
          .eq('user_id', user.id)
          .maybeSingle();

      // ✅ دریافت وضعیت هفته با تقویم شمسی
      final weekDays = await _getWeekDaysStatus(user.id);

      print('📊 _getTodayStatsAndSend - WeekDays: $weekDays');
      print('📊 _getTodayStatsAndSend - Total: $total, Completed: $completed');

      // ✅ به‌روزرسانی متغیرهای کلاس
      _totalTodayHabits = total;
      _todayHabitsCompleted = completed;
      _todayHabitsRemaining = total - completed;
      _currentStreak = profile?['current_streak'] ?? 0;
      _weekDays = weekDays;

      // ✅ ارسال کارت پیشرفت
      final String progressText =
          '''
📊 کارت پیشرفت روزانه
━━━━━━━━━━━━━━━━━━━━
✅ عادت‌های انجام شده: $_todayHabitsCompleted
⏳ عادت‌های باقیمانده: ${_totalTodayHabits - _todayHabitsCompleted}
🔥 استریک فعلی: $_currentStreak روز
━━━━━━━━━━━━━━━━━━━━
💪 ادامه بده! به قهرمانی نزدیک میشی!
''';

      _sendMessage(
        text: progressText,
        type: MessageType.progress,
        metadata: {
          'streak': _currentStreak,
          'completed': _todayHabitsCompleted,
          'total': _totalTodayHabits,
          'weekDays': _weekDays,
          'is_progress_card': true,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (e) {
      print('❌ Error getting today stats: $e');
    }
  }

  // lib/features/chat/screens/buddy_chat_screen.dart

  // ✅ اصلاح متد دریافت آمار امروز
  void _getTodayStats() async {
    try {
      final user = await _supabase.getCurrentUser();
      if (user == null) return;

      // دریافت عادت‌های امروز
      final habits = await _supabase.getHabits(user.id);
      final today = DateTime.now();

      int total = 0;
      int completed = 0;

      for (var habit in habits) {
        if (!habit.isActive) continue;
        if (!habit.shouldDoOnDate(today)) continue;

        total++;
        final isCompleted = await _supabase.isHabitCompletedOnDate(
          habit.id,
          user.id,
          today,
        );
        if (isCompleted) completed++;
      }

      // دریافت استریک
      final profile = await _supabase.client
          .from('profiles')
          .select('current_streak, best_streak')
          .eq('user_id', user.id)
          .maybeSingle();

      // ✅ دریافت وضعیت هفته با تقویم شمسی
      final weekDays = await _getWeekDaysStatus(user.id);

      print('📊 _getTodayStats - WeekDays: $weekDays');
      print('📊 _getTodayStats - Total: $total, Completed: $completed');

      if (mounted) {
        setState(() {
          _totalTodayHabits = total;
          _todayHabitsCompleted = completed;
          _todayHabitsRemaining = total - completed;
          _currentStreak = profile?['current_streak'] ?? 0;
          _weekDays = weekDays;
        });
      }
    } catch (e) {
      print('❌ Error getting today stats: $e');
    }
  }

  // lib/features/chat/screens/buddy_chat_screen.dart

  // ✅ متد دریافت وضعیت روزهای هفته با تقویم شمسی
  Future<List<bool>> _getWeekDaysStatus(String userId) async {
    List<bool> weekDays = List.filled(7, false);

    try {
      final now = DateTime.now();

      // ✅ محاسبه شروع هفته بر اساس تقویم شمسی
      final jalaliNow = Jalali.fromDateTime(now);
      final daysToSubtract = jalaliNow.weekDay - 1; // 0 = شنبه
      final weekStart = now.subtract(Duration(days: daysToSubtract));

      print('📅 Week start (Jalali): ${Jalali.fromDateTime(weekStart)}');
      print('📅 Today (Jalali): ${Jalali.fromDateTime(now)}');
      print('📅 Days to subtract: $daysToSubtract');

      for (int i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        final dateStr = date.toIso8601String().split('T').first;

        // ✅ دریافت وضعیت فعالیت از دیتابیس
        final activity = await _supabase.client
            .from('user_daily_activity')
            .select('is_active')
            .eq('user_id', userId)
            .eq('activity_date', dateStr)
            .maybeSingle();

        final isActive = activity != null && activity['is_active'] == true;
        weekDays[i] = isActive;

        // ✅ لاگ برای دیباگ
        final jalaliDate = Jalali.fromDateTime(date);
        print(
          '📊 Day ${i + 1}: ${jalaliDate.day}/${jalaliDate.month} - isActive: $isActive',
        );
      }

      return weekDays;
    } catch (e) {
      print('❌ Error getting week days status: $e');
      return weekDays;
    }
  }

  Future<int> _getUserStreak(String userId) async {
    try {
      final response = await _supabase.client
          .from('profiles')
          .select('current_streak')
          .eq('user_id', userId)
          .maybeSingle();
      return response?['current_streak'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getTodayHabitsCount(String userId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      final response = await _supabase.client
          .from('habits')
          .select('id')
          .eq('user_id', userId)
          .eq('is_active', true);
      return response.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getTodayCompletedHabits(String userId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      final response = await _supabase.client
          .from('habit_completions')
          .select('habit_id')
          .eq('user_id', userId)
          .eq('date', today);
      return response.length;
    } catch (e) {
      return 0;
    }
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

  // یک تابع کمکی برای پاکسازی نام فایل
  String _sanitizeFileName(String fileName) {
    // 1. پسوند فایل را جدا کنید
    final extension = fileName.split('.').last;
    // 2. نام فایل را بدون پسوند بگیرید
    var name = fileName.substring(0, fileName.length - extension.length - 1);

    // 3. تمام کاراکترهای غیرمجاز (فاصله، پرانتز، خط تیره) را با "_" جایگزین کنید
    // فقط حروف انگلیسی، اعداد و "_" و "-" را نگه دارید (و "." برای پسوند)
    final RegExp regExp = RegExp(r'[^a-zA-Z0-9_-]');
    name = name.replaceAll(regExp, '_'); // تبدیل کاراکترهای بد به "_"

    // 4. اگر نام خالی شد، یک نام پیش‌فرض بدهید
    if (name.isEmpty) name = 'audio_file';

    // 5. نام نهایی را بسازید
    return '$name.$extension';
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

  // lib/features/chat/screens/buddy_chat_screen.dart

  // ✅ متد ارسال هدیه XP (اصلاح شده)
  void _sendXPGift() async {
    if (_userId == null || _buddyId == null) {
      _showSnackBar('لطفاً وارد حساب کاربری خود شوید');
      return;
    }

    try {
      // ✅ دریافت XP از جدول profiles
      final profile = await _supabase.client
          .from('profiles')
          .select('total_xp')
          .eq('user_id', _userId!)
          .maybeSingle();

      final userXP = profile?['total_xp'] as int? ?? 0;

      if (userXP < 5) {
        _showSnackBar('XP کافی برای ارسال هدیه ندارید (حداقل ۵ XP)');
        return;
      }

      // ✅ استفاده از showDialog با XPGiftDialog (ویجت)
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => XPGiftDialog(
          // ✅ اینجا XPGiftDialog یک ویجت است
          senderName: _myName ?? 'کاربر',
          receiverName: _buddyName ?? 'کاربر',
          maxXP: userXP,
        ),
      );

      if (result == null) return;

      final amount = result['amount'] as int;
      final message = result['message'] as String? ?? '';

      // ✅ ارسال هدیه
      final giftId = DateTime.now().millisecondsSinceEpoch.toString();

      await _supabase.client.from('xp_gifts').insert({
        'id': giftId,
        'sender_id': _userId,
        'sender_name': _myName ?? 'کاربر',
        'receiver_id': _buddyId,
        'receiver_name': _buddyName ?? 'کاربر',
        'amount': amount,
        'message': message,
        'sent_at': DateTime.now().toIso8601String(),
        'is_delivered': false,
        'status': 'pending',
      });

      final giftText = '🎁 هدیه XP از ${_myName ?? "کاربر"}';

      _sendMessage(
        text: giftText,
        type: MessageType.text,
        metadata: {
          'type': 'xp_gift_card',
          'gift_id': giftId,
          'amount': amount,
          'sender_id': _userId,
          'sender_name': _myName ?? 'کاربر',
          'receiver_id': _buddyId,
          'receiver_name': _buddyName ?? 'کاربر',
          'message': message,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎁 کارت هدیه $amount XP ارسال شد!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error sending XP gift: $e');
      _showSnackBar('خطا در ارسال هدیه: ${e.toString()}');
    }
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

  /// جستجوی پیام‌ها و اسکرول به نتیجه
  void _searchMessages(String query) {
    if (query.isEmpty) {
      _showSnackBar('لطفاً متن مورد نظر را وارد کنید');
      return;
    }

    final results = _messages.where((msg) {
      return msg.content.toLowerCase().contains(query.toLowerCase());
    }).toList();

    if (results.isEmpty) {
      _showSnackBar('نتیجه‌ای یافت نشد 🔍');
      return;
    }

    if (results.length == 1) {
      _scrollToMessage(results.first.id); // ✅ استفاده از متد جدید
      return;
    }

    _showSearchResultsSheet(results, query);
  }

  /// ✅ اسکرول به پیام پین شده - نسخه نهایی با چندین روش پشتیبان
  void _scrollToPinnedMessage(String messageId) {
    // 1. ابتدا مطمئن شویم که پیام در لیست وجود دارد
    final index = _messages.indexWhere((msg) => msg.id == messageId);
    if (index == -1) {
      _showSnackBar('پیام پین شده در لیست موجود نیست');
      return;
    }

    print('📌 Scrolling to pinned message: $messageId (index: $index)');

    // 2. هایلایت پیام
    _highlightMessage(messageId);

    // 3. روش اول: استفاده از Scrollable.ensureVisible با تاخیر
    _scrollToMessageWithEnsureVisible(messageId);
  }

  /// ✅ روش اول: Scrollable.ensureVisible (دقیق‌ترین روش)
  void _scrollToMessageWithEnsureVisible(String messageId) {
    // صبر برای رندر شدن کامل
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // اگر کلید وجود ندارد، ایجاد کن
      if (!_messageKeys.containsKey(messageId)) {
        _messageKeys[messageId] = GlobalKey();
      }

      final key = _messageKeys[messageId]!;

      // چندین بار تلاش با تاخیرهای مختلف
      _tryEnsureVisible(key, messageId, attempt: 0);
    });
  }

  /// ✅ تلاش مجدد برای ensureVisible با تاخیرهای افزایشی
  void _tryEnsureVisible(GlobalKey key, String messageId, {int attempt = 0}) {
    const maxAttempts = 5;
    const delay = Duration(milliseconds: 200);

    Future.delayed(delay * (attempt + 1), () {
      if (!mounted) return;

      try {
        final context = key.currentContext;
        if (context != null) {
          // ✅ پیدا شد! اسکرول کن
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
            alignment: 0.5,
          );
          print(
            '✅ Scrolled to pinned message: $messageId (attempt ${attempt + 1})',
          );
          return;
        }
      } catch (e) {
        print('⚠️ EnsureVisible attempt ${attempt + 1} failed: $e');
      }

      // اگر تلاش‌ها تمام نشده، دوباره امتحان کن
      if (attempt < maxAttempts - 1) {
        _tryEnsureVisible(key, messageId, attempt: attempt + 1);
      } else {
        // ✅ اگر همه تلاش‌ها شکست خورد، از روش جایگزین استفاده کن
        print('⚠️ All ensureVisible attempts failed, using fallback');
        _scrollToMessageFallback(messageId);
      }
    });
  }

  /// نمایش نتایج جستجو در BottomSheet
  void _showSearchResultsSheet(List<ChatMessage> results, String query) {
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
                  // نشانگر کشیدن
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
                  Row(
                    children: [
                      const Icon(Icons.search, color: Color(0xFF4A90E2)),
                      const SizedBox(width: 8),
                      Text(
                        'نتایج جستجو (${results.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('بستن'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final msg = results[index];
                        final isMe = msg.senderId == _userId;
                        final preview = msg.content.length > 60
                            ? '${msg.content.substring(0, 60)}...'
                            : msg.content;

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
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Row(
                            children: [
                              Text(
                                msg.senderName ?? 'کاربر',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTime(msg.createdAt),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                            size: 20,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            // ✅ اسکرول به پیام
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

  // lib/features/chat/screens/buddy_chat_screen.dart

  /// ✅ تأیید پاک کردن تاریخچه
  void _confirmClearHistory() {
    _clearChatHistory(); // ✅ مستقیماً متد اصلاح شده را صدا بزن
  }

  // lib/features/chat/screens/buddy_chat_screen.dart

  /// ✅ متد کمکی برای بررسی توکن قبل از عملیات حساس
  Future<bool> _ensureValidSession() async {
    try {
      final session = _chatService.client.auth.currentSession;
      if (session == null) {
        print('⚠️ No active session, redirecting to login...');
        // می‌توانید به صفحه لاگین هدایت کنید
        return false;
      }

      // بررسی انقضای توکن
      final expiresAt = session.expiresAt;
      if (expiresAt != null) {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if (expiresAt - now < 60) {
          // کمتر از 1 دقیقه
          print('⏰ Session expired, refreshing...');
          try {
            await _chatService.client.auth.refreshSession();
            print('✅ Session refreshed');
          } catch (e) {
            print('❌ Failed to refresh session: $e');
            return false;
          }
        }
      }
      return true;
    } catch (e) {
      print('❌ Error checking session: $e');
      return false;
    }
  }

  // lib/features/chat/screens/buddy_chat_screen.dart

  /// ✅ پاک کردن تاریخچه گفتگو - نسخه نهایی با بررسی توکن
  Future<void> _clearChatHistory() async {
    if (_userId == null) return;

    // ✅ بررسی توکن قبل از عملیات
    final isValid = await _ensureValidSession();
    if (!isValid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لطفاً مجدداً وارد حساب کاربری خود شوید'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // ✅ نمایش دیالوگ تایید
    final confirm = await showDialog<bool>(
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
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'پاک کردن همه',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // ✅ حذف همه پیام‌های گفتگو با یک کوئری
      await _chatService.client
          .from('messages')
          .delete()
          .eq('conversation_id', widget.conversation.id);

      // ✅ پاک کردن لیست محلی
      setState(() {
        _messages.clear();
        _messageKeys.clear();
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تاریخچه گفتگو با موفقیت پاک شد 🗑️'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error clearing chat history: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در پاک کردن تاریخچه: ${e.toString()}'),
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

  /// ✅ متد علامت‌گذاری پیام‌ها به عنوان خوانده شده - استفاده از متد safe
  Future<void> _markMessagesAsRead() async {
    if (_userId == null || _messages.isEmpty) return;

    // ✅ پیدا کردن پیام‌های خوانده نشده
    final unreadMessages = _messages.where((msg) {
      final isFromOther = msg.senderId != _userId;
      final isUnread =
          msg.status != MessageStatus.seen &&
          msg.status != MessageStatus.delivered;
      final isNotDeleted = !msg.isDeleted;
      return isFromOther && isUnread && isNotDeleted;
    }).toList();

    if (unreadMessages.isEmpty) {
      print('📊 No unread messages to mark as read');
      return;
    }

    print('📊 Marking ${unreadMessages.length} messages as read');

    for (var msg in unreadMessages) {
      print('   - Message ${msg.id.substring(0, 8)} status: ${msg.status}');
    }

    try {
      // ✅ استفاده از متد safe
      await _chatService.markAllMessagesAsReadSafe(
        conversationId: widget.conversation.id,
        userId: _userId!,
      );

      // ✅ به‌روزرسانی محلی
      setState(() {
        for (var msg in unreadMessages) {
          final index = _messages.indexWhere((m) => m.id == msg.id);
          if (index != -1) {
            _messages[index] = ChatMessage(
              id: _messages[index].id,
              conversationId: _messages[index].conversationId,
              senderId: _messages[index].senderId,
              senderName: _messages[index].senderName,
              senderAvatar: _messages[index].senderAvatar,
              content: _messages[index].content,
              type: _messages[index].type,
              status: MessageStatus.seen,
              metadata: _messages[index].metadata,
              isRead: true,
              isEdited: _messages[index].isEdited,
              isDeleted: _messages[index].isDeleted,
              replyToId: _messages[index].replyToId,
              replyTo: _messages[index].replyTo,
              reactions: _messages[index].reactions,
              createdAt: _messages[index].createdAt,
              editedAt: _messages[index].editedAt,
              deletedAt: _messages[index].deletedAt,
              isTemp: _messages[index].isTemp,
              hiddenFor: _messages[index].hiddenFor,
              isPinned: _messages[index].isPinned,
              pinnedAt: _messages[index].pinnedAt,
              pinnedBy: _messages[index].pinnedBy,
            );
          }
        }
      });

      print('✅ ${unreadMessages.length} messages marked as read locally');
    } catch (e) {
      print('❌ Error marking messages as read: $e');
      // در صورت خطا، فقط وضعیت محلی را به‌روزرسانی کن
      setState(() {
        for (var msg in unreadMessages) {
          final index = _messages.indexWhere((m) => m.id == msg.id);
          if (index != -1) {
            _messages[index].status = MessageStatus.seen;
          }
        }
      });
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

  // lib/features/chat/screens/buddy_chat_screen.dart

  // ✅ اصلاح _buildMessageActionsPopup
  Widget _buildMessageActionsPopup() {
    if (_menuMessage == null || _menuPosition == null) {
      return const SizedBox.shrink();
    }

    final message = _menuMessage!;
    final isOwnMessage = message.senderId == _userId;
    final screenSize = MediaQuery.of(context).size;
    final isPinned = message.isPinned;

    final double bubbleX = _menuPosition!.dx;
    final double bubbleY = _menuPosition!.dy;

    const double menuWidth = 220;
    const double reactionsHeight = 52;
    const double menuItemsHeight = 270; // ✅ افزایش ارتفاع برای گزینه جدید
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
          // ✅ حباب ری‌اکشن‌ها
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
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF4A90E2).withValues(alpha: 0.15)
                            : Colors.transparent,
                        shape: BoxShape.circle,
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

                // ✅ گزینه پین/لغو پین
                _buildPopupMenuItem(
                  icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  label: isPinned ? 'لغو پین' : 'پین کردن',
                  color: isPinned ? Colors.orange : const Color(0xFF4A90E2),
                  onTap: () {
                    _closeMenu();
                    if (isPinned) {
                      _unpinMessage(message);
                    } else {
                      _pinMessage(message);
                    }
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

  // ✅ متد پین کردن پیام
  Future<void> _pinMessage(ChatMessage message) async {
    if (_userId == null) return;

    try {
      await _chatService.pinMessage(messageId: message.id, userId: _userId!);

      // ✅ به‌روزرسانی محلی
      setState(() {
        // پیدا کردن پیام در لیست و به‌روزرسانی
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          _messages[index] = ChatMessage(
            id: _messages[index].id,
            conversationId: _messages[index].conversationId,
            senderId: _messages[index].senderId,
            senderName: _messages[index].senderName,
            senderAvatar: _messages[index].senderAvatar,
            content: _messages[index].content,
            type: _messages[index].type,
            status: _messages[index].status,
            metadata: _messages[index].metadata,
            isRead: _messages[index].isRead,
            isEdited: _messages[index].isEdited,
            isDeleted: _messages[index].isDeleted,
            replyToId: _messages[index].replyToId,
            replyTo: _messages[index].replyTo,
            reactions: _messages[index].reactions,
            createdAt: _messages[index].createdAt,
            editedAt: _messages[index].editedAt,
            deletedAt: _messages[index].deletedAt,
            isTemp: _messages[index].isTemp,
            hiddenFor: _messages[index].hiddenFor,
            isPinned: true,
            pinnedAt: DateTime.now(),
            pinnedBy: _userId,
          );
        }

        // پاک کردن پین قبلی از سایر پیام‌ها
        for (int i = 0; i < _messages.length; i++) {
          if (_messages[i].id != message.id && _messages[i].isPinned) {
            _messages[i] = ChatMessage(
              id: _messages[i].id,
              conversationId: _messages[i].conversationId,
              senderId: _messages[i].senderId,
              senderName: _messages[i].senderName,
              senderAvatar: _messages[i].senderAvatar,
              content: _messages[i].content,
              type: _messages[i].type,
              status: _messages[i].status,
              metadata: _messages[i].metadata,
              isRead: _messages[i].isRead,
              isEdited: _messages[i].isEdited,
              isDeleted: _messages[i].isDeleted,
              replyToId: _messages[i].replyToId,
              replyTo: _messages[i].replyTo,
              reactions: _messages[i].reactions,
              createdAt: _messages[i].createdAt,
              editedAt: _messages[i].editedAt,
              deletedAt: _messages[i].deletedAt,
              isTemp: _messages[i].isTemp,
              hiddenFor: _messages[i].hiddenFor,
              isPinned: false,
              pinnedAt: null,
              pinnedBy: null,
            );
          }
        }

        _pinnedMessage = _messages.firstWhere(
          (m) => m.id == message.id,
          orElse: () => message,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📌 پیام پین شد'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Error pinning message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ متد لغو پین پیام
  Future<void> _unpinMessage(ChatMessage message) async {
    try {
      await _chatService.unpinMessage(messageId: message.id);

      // ✅ به‌روزرسانی محلی
      setState(() {
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          _messages[index] = ChatMessage(
            id: _messages[index].id,
            conversationId: _messages[index].conversationId,
            senderId: _messages[index].senderId,
            senderName: _messages[index].senderName,
            senderAvatar: _messages[index].senderAvatar,
            content: _messages[index].content,
            type: _messages[index].type,
            status: _messages[index].status,
            metadata: _messages[index].metadata,
            isRead: _messages[index].isRead,
            isEdited: _messages[index].isEdited,
            isDeleted: _messages[index].isDeleted,
            replyToId: _messages[index].replyToId,
            replyTo: _messages[index].replyTo,
            reactions: _messages[index].reactions,
            createdAt: _messages[index].createdAt,
            editedAt: _messages[index].editedAt,
            deletedAt: _messages[index].deletedAt,
            isTemp: _messages[index].isTemp,
            hiddenFor: _messages[index].hiddenFor,
            isPinned: false,
            pinnedAt: null,
            pinnedBy: null,
          );
        }
        _pinnedMessage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📌 پین پیام لغو شد'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Error unpinning message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // lib/features/chat/screens/buddy_chat_screen.dart

  Widget _buildPinnedMessageBar() {
    if (_pinnedMessage == null) return const SizedBox.shrink();

    final message = _pinnedMessage!;
    final isMe = message.senderId == _userId;
    final senderName = isMe ? 'شما' : (message.senderName ?? 'کاربر');

    return GestureDetector(
      onTap: () {
        print('📌 Clicked pinned message: ${message.id}');
        _scrollToPinnedMessage(message.id);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          border: Border(
            bottom: BorderSide(color: Colors.orange.shade200, width: 1),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.push_pin, color: Colors.orange, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '📌 پیام پین شده توسط $senderName',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    message.content,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: Colors.grey.shade500,
              onPressed: () => _unpinMessage(message),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
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

  // lib/features/chat/screens/buddy_chat_screen.dart

  // ✅ متد کمکی برای پیدا کردن پیام پین شده
  ChatMessage? _findPinnedMessage(List<ChatMessage> messages) {
    try {
      return messages.firstWhere((m) => m.isPinned);
    } catch (e) {
      return null;
    }
  }

  // lib/features/chat/screens/buddy_chat_screen.dart

  Future<void> _loadMessages() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print('📊 _loadMessages: Fetching messages...');

      // ✅ پاک کردن کلیدهای قبلی
      _messageKeys.clear();

      final messages = await _chatService.getMessagesHistory(
        widget.conversation.id,
        limit: 200,
      );

      print('📊 _loadMessages: Got ${messages.length} messages');

      if (mounted) {
        setState(() {
          _messages = messages.reversed.toList();
          _isLoading = false;

          // پیدا کردن پیام پین شده
          try {
            _pinnedMessage = _messages.firstWhere((m) => m.isPinned);
          } catch (e) {
            _pinnedMessage = null;
          }
        });

        // ✅ علامت‌گذاری پیام‌ها به عنوان خوانده شده
        await _markMessagesAsRead();

        print('📊 _loadMessages: Loaded ${_messages.length} messages');
      }

      _scrollToBottom();
    } catch (e) {
      print('❌ Error loading messages: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ✅ متد کمکی برای پیدا کردن پیام پین شده (ایمن)
  ChatMessage? _findPinnedMessageSafely(List<ChatMessage> messages) {
    try {
      return messages.firstWhere((m) => m.isPinned);
    } catch (e) {
      return null;
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

  /// ✅ اسکرول به انتهای صفحه
  void _scrollToBottom({bool animated = true}) {
    if (!mounted) return;

    // اگر لیست خالی است یا کنترلر وجود ندارد
    if (_messages.isEmpty || !_scrollController.hasClients) return;

    try {
      // در لیست با reverse: true، موقعیت 0 یعنی انتهای صفحه
      const double target = 0;

      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    } catch (e) {
      // اگر خطا بود، روش جایگزین
      try {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } catch (e2) {
        print('⚠️ Scroll to bottom error: $e2');
      }
    }
  }

  /// ✅ دکمه شناور برای رفتن به انتهای صفحه
  Widget _buildScrollToBottomButton() {
    // فقط اگر بیش از 5 پیام باشد و کاربر در پایین نباشد نمایش داده شود
    if (_messages.length < 5) return const SizedBox.shrink();

    // بررسی اینکه آیا کاربر در پایین صفحه است
    bool isAtBottom = true;
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      isAtBottom = position.pixels < 50; // نزدیک به پایین
    }

    // اگر در پایین است، دکمه را نشان نده
    if (isAtBottom) return const SizedBox.shrink();

    return Positioned(
      bottom: 100,
      right: 16,
      child: GestureDetector(
        onTap: () => _scrollToBottom(animated: true),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF4A90E2),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_downward,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  // ==================== ارسال پیام ====================

  // lib/features/chat/screens/buddy_chat_screen.dart

  // ✅ متد ارسال پیام - باید metadata را درست ارسال کند
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

    final typeString = type.toString().split('.').last;
    print('📤 [DEBUG] _sendMessage called! type=$type, typeString=$typeString');
    print('📤 [DEBUG] metadata: $metadata');

    // ✅ ایجاد پیام موقت
    final tempMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: widget.conversation.id,
      senderId: _userId!,
      senderName: _myName, // ✅ استفاده از _myName
      senderAvatar: null,
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

    setState(() {
      _messages.insert(0, tempMessage);
      _isSending = true;
      _replyToMessage = null;
      _showStickerPicker = false;
      _showGifPicker = false;
    });

    _messageController.clear();
    _focusNode.requestFocus();
    _sendTypingStatus(false);

    try {
      await _chatService.sendMessage(
        conversationId: widget.conversation.id,
        senderId: _userId!,
        content: content,
        type: typeString,
        metadata: metadata,
        replyToId: replyToIdToSend,
        senderName: _myName,
      );

      print('✅ [DEBUG] Message sent successfully!');

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
        }
      });

      await _updateLastSeen(_userId!);
      _scrollToBottom();
    } catch (e) {
      print('❌ [DEBUG] Error sending message: $e');

      setState(() {
        final index = _messages.indexWhere((msg) => msg.id == tempMessage.id);
        if (index != -1) {
          _messages[index].status = MessageStatus.failed;
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

  // ==================== متدهای کمکی ====================

  // ✅ متد جدید برای گروه‌بندی واکنش‌ها
  List<Map<String, dynamic>> _groupReactions(List<MessageReaction> reactions) {
    final Map<String, int> counts = {};

    for (var reaction in reactions) {
      counts[reaction.emoji] = (counts[reaction.emoji] ?? 0) + 1;
    }

    return counts.entries.map((entry) {
      return {'emoji': entry.key, 'count': entry.value};
    }).toList();
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

  Widget _buildMessageBubble(ChatMessage message) {
    final isMe = message.senderId == _userId;
    final isSystem = message.type == MessageType.system;
    final isSelected = _selectedMessageIds.contains(message.id);
    final isFailed = message.status == MessageStatus.failed;

    // ✅ ایجاد یا بازیابی کلید برای این پیام
    if (!_messageKeys.containsKey(message.id)) {
      _messageKeys[message.id] = GlobalKey();
    }
    final key = _messageKeys[message.id]!;

    if (isSystem) {
      return Container(
        key: key,
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
        key: key,
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
                          key.currentContext!.findRenderObject() as RenderBox;

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
                    border: message.isPinned
                        ? Border.all(color: Colors.orange, width: 2)
                        : _highlightedMessageId == message.id
                        ? Border.all(color: const Color(0xFFFFA500), width: 2)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                      if (message.isPinned)
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.2),
                          blurRadius: 8,
                          spreadRadius: 1,
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
                      // ✅ نمایش آیکون پین
                      if (message.isPinned)
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.push_pin,
                                size: 12,
                                color: Colors.orange,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'پین شده',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

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

  // lib/features/chat/screens/buddy_chat_screen.dart

  /// ✅ متد ساخت آیکون وضعیت پیام - نسخه کامل با وضعیت sending
  Widget _buildStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Colors.white70,
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

  // ✅ اصلاح متد بارگذاری پیام پین شده
  Future<void> _loadPinnedMessage() async {
    try {
      final pinned = await _chatService.getPinnedMessage(
        widget.conversation.id,
      );
      if (mounted) {
        setState(() {
          _pinnedMessage = pinned;
        });
      }
    } catch (e) {
      print('❌ Error loading pinned message: $e');
      // اگر خطا بود، پیام پین شده را null قرار بده
      if (mounted) {
        setState(() {
          _pinnedMessage = null;
        });
      }
    }
  }

  /// هایلایت پیام با رنگ برجسته
  void _highlightMessage(String messageId) {
    // لغو هایلایت قبلی
    _highlightedMessageId = null;

    // تنظیم هایلایت جدید
    setState(() {
      _highlightedMessageId = messageId;
    });

    // بعد از 3 ثانیه هایلایت را بردار
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _highlightedMessageId = null;
        });
      }
    });
  }

  /// ✅ نشانگر تاریخ
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
    // ✅ اگر پیام در حال آپلود است
    if (message.metadata != null && message.metadata!['is_uploading'] == true) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '🎵 در حال آپلود...',
              style: TextStyle(
                fontSize: 13,
                color: isMe ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    // ✅ اگر پیام ناموفق است
    if (message.status == MessageStatus.failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.content,
            style: TextStyle(
              color: isMe ? Colors.white : const Color(0xFF1A1A2E),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.error_outline, size: 14, color: Colors.red),
              const SizedBox(width: 4),
              Text(
                'ارسال ناموفق',
                style: TextStyle(fontSize: 11, color: Colors.red.shade300),
              ),
            ],
          ),
        ],
      );
    }

    // ============================================================
    // ✅ اولویت اول: کارت هدیه XP
    // ============================================================
    if (message.metadata != null &&
        message.metadata!['type'] == 'xp_gift_card') {
      try {
        final giftId = message.metadata!['gift_id'] as String;
        final amount = message.metadata!['amount'] as int;
        final senderName =
            message.metadata!['sender_name'] as String? ?? 'کاربر';
        final receiverName =
            message.metadata!['receiver_name'] as String? ?? 'کاربر';
        final messageText = message.metadata!['message'] as String? ?? '';

        return XPGiftCardWidget(
          key: ValueKey('gift_${message.id}_$giftId'),
          giftId: giftId,
          amount: amount,
          senderName: senderName,
          receiverName: receiverName,
          message: messageText,
          isMe: isMe,
          onDelivered: () {
            _loadMessages();
          },
        );
      } catch (e) {
        print('❌ Error building XP gift card: $e');
        return Text(
          message.content,
          style: TextStyle(
            color: isMe ? Colors.white : const Color(0xFF1A1A2E),
            fontSize: 14,
          ),
        );
      }
    }

    // ============================================================
    // ✅ اولویت دوم: ویجت چالش (هم دعوت و هم فعال)
    // ============================================================
    if (message.metadata != null &&
        (message.metadata!['is_challenge_invite'] == true ||
            message.metadata!['is_active_challenge'] == true)) {
      try {
        final challengeId = message.metadata!['challenge_id'] as String;
        final challenge = _challengeCache[challengeId];

        if (challenge == null) {
          // بارگذاری در پس‌زمینه
          _loadChallengeInBackground(challengeId);
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '⏳ در حال بارگذاری چالش...',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          );
        }

        // ✅ اگر چالش فعال است، ویجت چالش فعال را نمایش بده
        if (challenge.status == ChallengeStatus.active) {
          return ActiveChallengeWidget(
            key: ValueKey('active_${challenge.id}'),
            challenge: challenge,
            currentUserId: _userId!,
            onToggleHabit: (habitId, action) async {
              final service = ChallengeInviteService();
              if (action == 'complete') {
                await service.completeHabitToday(
                  challengeId: challengeId,
                  userId: _userId!,
                  habitId: habitId,
                );
              } else {
                await service.uncompleteHabitToday(
                  challengeId: challengeId,
                  userId: _userId!,
                  habitId: habitId,
                );
              }
              _challengeCache.remove(challengeId);
              _loadChallengeInBackground(challengeId);
              if (mounted) setState(() {});
            },
            onCancel: () async {
              final service = ChallengeInviteService();
              await service.cancelChallenge(
                challengeId: challengeId,
                userId: _userId!,
              );
              _challengeCache.remove(challengeId);
              if (mounted) setState(() {});
            },
            onSendReminder: () {
              _sendReminder(challenge.title);
            },
          );
        }

        // ✅ اگر چالش در حالت pending است، ویجت دعوت را نمایش بده
        if (challenge.status == ChallengeStatus.pending) {
          return ChallengeInviteWidget(
            key: ValueKey('invite_${challenge.id}'),
            challenge: challenge,
            isMe: isMe,
            onRespond: (accept) async {
              final service = ChallengeInviteService();
              final success = await service.respondToChallenge(
                challengeId,
                accept,
              );
              if (success) {
                _challengeCache.remove(challengeId);
                if (accept) {
                  _loadMessages();
                } else {
                  if (mounted) setState(() {});
                }
              }
            },
          );
        }

        // ✅ اگر چالش کامل، لغو یا رد شده است، وضعیت نهایی را نمایش بده
        if (challenge.status == ChallengeStatus.completed ||
            challenge.status == ChallengeStatus.cancelled ||
            challenge.status == ChallengeStatus.rejected) {
          return ChallengeInviteWidget(
            key: ValueKey('final_${challenge.id}'),
            challenge: challenge,
            isMe: isMe,
            onRespond: (accept) async {},
          );
        }

        // ✅ حالت پیش‌فرض: نمایش دعوت
        return ChallengeInviteWidget(
          key: ValueKey('default_${challenge.id}'),
          challenge: challenge,
          isMe: isMe,
          onRespond: (accept) async {
            final service = ChallengeInviteService();
            final success = await service.respondToChallenge(
              challengeId,
              accept,
            );
            if (success) {
              _challengeCache.remove(challengeId);
              if (accept) {
                _loadMessages();
              } else {
                if (mounted) setState(() {});
              }
            }
          },
        );
      } catch (e) {
        print('❌ Error building challenge: $e');
        return Text(
          message.content,
          style: TextStyle(
            color: isMe ? Colors.white : const Color(0xFF1A1A2E),
            fontSize: 14,
          ),
        );
      }
    }

    // ============================================================
    // ✅ اولویت سوم: ویجت لیست عادت‌های امروز
    // ============================================================
    if (message.metadata != null &&
        message.metadata!['is_today_list_widget'] == true) {
      try {
        final data = TodayHabitsList.fromMetadata(message.metadata!);
        return TodayHabitsListWidget(
          key: ValueKey('today_${message.id}'),
          data: data,
          isMe: isMe,
        );
      } catch (e) {
        print('❌ Error building today list widget: $e');
        return Text(
          message.content,
          style: TextStyle(
            color: isMe ? Colors.white : const Color(0xFF1A1A2E),
            fontSize: 14,
          ),
        );
      }
    }

    // ============================================================
    // ✅ اولویت چهارم: ویجت عملکرد هفتگی
    // ============================================================
    if (message.metadata != null &&
        message.metadata!['is_performance_widget'] == true) {
      try {
        final performance = WeeklyHabitPerformance.fromMetadata(
          message.metadata!,
        );
        return WeeklyPerformanceWidget(
          key: ValueKey('weekly_${message.id}'),
          data: performance,
          isMe: isMe,
        );
      } catch (e) {
        print('❌ Error building performance widget: $e');
        return Text(
          message.content,
          style: TextStyle(
            color: isMe ? Colors.white : const Color(0xFF1A1A2E),
            fontSize: 14,
          ),
        );
      }
    }

    // ============================================================
    // ✅ اولویت پنجم: فایل و موزیک (با file_url)
    // ============================================================

    // ✅ در بخش _buildMessageContent
    if (message.metadata != null &&
        (message.metadata!['file_url'] != null ||
            message.metadata!['file_name'] != null)) {
      final fileUrl = message.metadata!['file_url'] as String? ?? '';
      final fileName = message.metadata!['file_name'] as String? ?? 'فایل';
      final fileSize = message.metadata!['file_size'] as int? ?? 0;

      String fileType = message.metadata!['type'] as String? ?? 'file';
      if (fileType == 'music') {
        fileType = 'audio';
      }

      print('📊 Building FileMessageWidget:');
      print('   - fileUrl: $fileUrl');
      print('   - fileName: $fileName');
      print('   - fileType: $fileType');
      print('   - fileSize: $fileSize');

      return FileMessageWidget(
        key: ValueKey('file_${message.id}_${fileUrl.hashCode}'),
        fileUrl: fileUrl,
        fileName: fileName,
        fileType: fileType,
        fileSize: fileSize,
        isMe: isMe,
      );
    }

    // ============================================================
    // ✅ اولویت ششم: کارت پیشرفت
    // ============================================================
    if (message.metadata != null &&
        message.metadata!['is_progress_card'] == true) {
      return _buildProgressCard(message, isMe);
    }

    // ============================================================
    // ✅ اولویت هفتم: نوع پیام progress
    // ============================================================
    if (message.type == MessageType.progress) {
      return _buildProgressCard(message, isMe);
    }

    // ✅ بررسی لینک لوکیشن
    if (message.type == MessageType.text && _isLocationLink(message.content)) {
      return Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF4A90E2) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMe ? Colors.white24 : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.location_on,
                color: Colors.green,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📍 موقعیت مکانی',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isMe ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                  ),
                  Text(
                    'مشاهده روی نقشه',
                    style: TextStyle(
                      fontSize: 11,
                      color: isMe ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 16),
              color: isMe ? Colors.white : const Color(0xFF4A90E2),
              onPressed: () => _openInMap(message.content),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    }

    // ✅ بررسی اینکه آیا پیام حاوی شماره تماس است
    if (message.type == MessageType.text &&
        _isContactMessage(message.content)) {
      return _buildContactMessage(message, isMe);
    }

    // ============================================================
    // ✅ بقیه موارد بر اساس نوع پیام
    // ============================================================
    switch (message.type) {
      case MessageType.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            message.content,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.image_not_supported,
              size: 50,
              color: Colors.grey,
            ),
          ),
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
        // ✅ نمایش متن با لینک‌های قابل کلیک
        return _buildLinkifiedText(message.content, isMe);
    }
  }

  // ============================================================
  // ✅ متدهای کمکی
  // ============================================================

  /// ✅ بررسی اینکه آیا پیام حاوی شماره تماس است
  bool _isContactMessage(String content) {
    return content.contains('📞 شماره تماس') ||
        content.contains('👤 نام:') ||
        content.contains('📱 شماره:');
  }

  /// ✅ ساخت ویجت شماره تماس
  Widget _buildContactMessage(ChatMessage message, bool isMe) {
    // استخراج اطلاعات از متن
    String name = '';
    String phone = '';

    final lines = message.content.split('\n');
    for (var line in lines) {
      if (line.contains('👤 نام:')) {
        name = line.replaceAll('👤 نام:', '').trim();
      } else if (line.contains('📱 شماره:')) {
        phone = line.replaceAll('📱 شماره:', '').trim();
      }
    }

    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF4A90E2) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe ? Colors.white24 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.contact_phone,
              color: Colors.blue,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : 'مخاطب',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isMe ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
                Text(
                  phone.isNotEmpty ? phone : 'شماره موجود نیست',
                  style: TextStyle(
                    fontSize: 11,
                    color: isMe ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (phone.isNotEmpty && phone != 'شماره موجود نیست')
            IconButton(
              icon: const Icon(Icons.phone, size: 16),
              color: isMe ? Colors.white : const Color(0xFF4A90E2),
              onPressed: () => _callPhoneNumber(phone),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  /// ✅ تماس با شماره تلفن
  void _callPhoneNumber(String phone) {
    // حذف کاراکترهای غیرمجاز
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isNotEmpty) {
      final url = 'tel:$cleanPhone';
      _launchUrl(url);
    }
  }

  // ✅ متد جدید برای بارگذاری چالش در پس‌زمینه
  void _loadChallengeInBackground(String challengeId) {
    // اگر در حال بارگذاری است، صبر کن
    if (_loadingChallenges.contains(challengeId)) return;

    _loadingChallenges.add(challengeId);

    Future.delayed(Duration.zero, () async {
      try {
        final service = ChallengeInviteService();
        final challenge = await service.getChallengeById(challengeId);
        if (challenge != null && mounted) {
          _challengeCache[challengeId] = challenge;
          setState(() {});
        }
      } catch (e) {
        print('❌ Error loading challenge in background: $e');
      } finally {
        _loadingChallenges.remove(challengeId);
      }
    });
  }

  // ✅ متد ریفرش یک چالش خاص
  void _refreshChallenge(String challengeId) {
    _challengeCache.remove(challengeId);
    _loadChallengeInBackground(challengeId);
  }
  // ==================== ویجت فایل ====================

  Widget _buildFileMessageWidget({
    required String fileName,
    required int fileSize,
    required bool isMusic,
    required bool isMe,
    String? filePath,
    bool hasBytes = false,
  }) {
    final fileSizeString = _getFileSizeString(fileSize);

    // ✅ اگر موزیک است، پلیر نمایش داده شود
    if (isMusic) {
      return _buildMusicPlayer(
        fileName: fileName,
        fileSizeString: fileSizeString,
        isMe: isMe,
        filePath: filePath,
        hasBytes: hasBytes,
      );
    }

    // ✅ نمایش فایل معمولی
    return _buildFileCard(
      fileName: fileName,
      fileSizeString: fileSizeString,
      isMe: isMe,
      filePath: filePath,
      hasBytes: hasBytes,
    );
  }

  // ==================== کارت فایل ====================

  Widget _buildFileCard({
    required String fileName,
    required String fileSizeString,
    required bool isMe,
    String? filePath,
    bool hasBytes = false,
  }) {
    final bool isWeb = kIsWeb;
    final bool canOpen = !isWeb && filePath != null && filePath.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? Colors.blue.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe ? Colors.blue.shade200 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.insert_drive_file,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isMe ? Colors.black87 : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      fileSizeString,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // ✅ دکمه دانلود (فقط در موبایل/دسکتاپ)
              if (!isWeb)
                IconButton(
                  icon: const Icon(Icons.download, size: 20),
                  color: Colors.blue,
                  onPressed: () => _downloadFile(filePath, fileName),
                  tooltip: 'دانلود فایل',
                ),
            ],
          ),
          // ✅ دکمه باز کردن فایل (فقط در موبایل/دسکتاپ)
          if (canOpen)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: () => _openFile(filePath),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.open_in_browser,
                        size: 14,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'باز کردن فایل',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // ✅ پیام برای وب
          if (isWeb)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'در وب فقط می‌توانید دانلود کنید',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade700,
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

  // ==================== پلیر موزیک ====================

  Widget _buildMusicPlayer({
    required String fileName,
    required String fileSizeString,
    required bool isMe,
    String? filePath,
    bool hasBytes = false,
  }) {
    final bool isWeb = kIsWeb;
    final bool canPlay = isWeb
        ? hasBytes
        : (hasBytes || (filePath != null && File(filePath).existsSync()));

    if (!canPlay) {
      return _buildFileCard(
        fileName: fileName,
        fileSizeString: fileSizeString,
        isMe: isMe,
        filePath: filePath,
        hasBytes: hasBytes,
      );
    }

    // ✅ استفاده از StatefulWidget برای مدیریت وضعیت پلیر
    return _MusicPlayerWidget(
      fileName: fileName,
      fileSizeString: fileSizeString,
      isMe: isMe,
      filePath: filePath,
      hasBytes: hasBytes,
      onDownload: () => _downloadFile(filePath, fileName),
      onShowSnackBar: _showSnackBar,
    );
  }

  // ==================== عملیات فایل ====================

  Future<void> _openFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) {
      _showSnackBar('مسیر فایل موجود نیست');
      return;
    }

    try {
      // ✅ در وب، باز کردن فایل مستقیم ممکن نیست
      if (kIsWeb) {
        // روش جایگزین برای وب: نمایش پیام
        _showSnackBar('در وب، فایل را دانلود کنید');
        return;
      }

      final file = File(filePath);

      if (!await file.exists()) {
        _showSnackBar('فایل یافت نشد');
        return;
      }

      // ✅ روش‌های مختلف برای باز کردن فایل
      try {
        // روش 1: url_launcher
        final uri = Uri.file(filePath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          return;
        }
      } catch (e) {
        print('⚠️ url_launcher failed: $e');
      }

      try {
        // روش 2: OpenFile (برای اندروید و iOS)
        final result = await OpenFile.open(filePath);
        if (result.type == ResultType.done) {
          return;
        }
      } catch (e) {
        print('⚠️ OpenFile failed: $e');
      }

      _showSnackBar('خطا در باز کردن فایل');
    } catch (e) {
      _showSnackBar('خطا: ${e.toString()}');
    }
  }

  Future<void> _downloadFile(String? filePath, String fileName) async {
    if (filePath == null || filePath.isEmpty) {
      _showSnackBar('مسیر فایل موجود نیست');
      return;
    }

    try {
      // ✅ در وب، از bytes استفاده کن
      if (kIsWeb) {
        // روش جایگزین برای وب
        _showSnackBar('در وب، فایل را با راست کلیک ذخیره کنید');
        return;
      }

      final file = File(filePath);

      if (!await file.exists()) {
        _showSnackBar('فایل یافت نشد');
        return;
      }

      // ✅ روش‌های مختلف برای دانلود
      try {
        // روش 1: FilePicker.saveFile
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'ذخیره فایل',
          fileName: fileName,
          bytes: await file.readAsBytes(),
        );

        if (result != null) {
          _showSnackBar('✅ فایل با موفقیت ذخیره شد');
          return;
        }
      } catch (e) {
        print('⚠️ FilePicker save failed: $e');
      }

      // روش 2: ذخیره در دایرکتوری دانلود (اندروید/iOS)
      try {
        final downloadsDir = await getExternalStorageDirectory();
        if (downloadsDir != null) {
          final newPath = '${downloadsDir.path}/$fileName';
          await file.copy(newPath);
          _showSnackBar('✅ فایل با موفقیت ذخیره شد');
          return;
        }
      } catch (e) {
        print('⚠️ Could not save to downloads: $e');
      }

      // روش 3: ذخیره در دایرکتوری اسناد
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final newPath = '${appDir.path}/$fileName';
        await file.copy(newPath);
        _showSnackBar('✅ فایل با موفقیت ذخیره شد');
        return;
      } catch (e) {
        print('⚠️ Could not save to documents: $e');
      }

      _showSnackBar('خطا در ذخیره فایل');
    } catch (e) {
      _showSnackBar('خطا: ${e.toString()}');
    }
  }

  // lib/features/chat/screens/buddy_chat_screen.dart

  // ✅ اصلاح _buildProgressCard با عرض ثابت
  Widget _buildProgressCard(ChatMessage message, bool isMe) {
    final metadata = message.metadata ?? {};
    final streak = metadata['streak'] ?? 0;
    final completed = metadata['completed'] ?? 0;
    final total = metadata['total'] ?? 0;

    List<bool> weekDays = [];
    if (metadata['weekDays'] != null && metadata['weekDays'] is List) {
      weekDays = List<bool>.from(metadata['weekDays']);
    }

    if (weekDays.isEmpty) {
      weekDays = _weekDays;
    }

    const weekDayLetters = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

    final jalaliToday = Jalali.fromDateTime(DateTime.now());
    final todayIndex = jalaliToday.weekDay - 1;

    return Container(
      width: 280, // ✅ عرض ثابت و مناسب
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A90E2), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A90E2).withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              const Text(
                'پیشرفت روزانه',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$streak روز',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildProgressStat(
                Icons.check_circle,
                '$completed',
                'انجام شده',
                Colors.green,
              ),
              const SizedBox(width: 8),
              _buildProgressStat(
                Icons.pending,
                '${total - completed}',
                'باقیمانده',
                Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? completed / total : 0,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              color: Colors.white,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${total > 0 ? ((completed / total) * 100).toInt() : 0}% تکمیل شده',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
            ),
          ),
          if (weekDays.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (index) {
                final isActive =
                    weekDays.length > index && weekDays[index] == true;
                final isToday = index == todayIndex;

                return Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? Colors.white
                            : isToday
                            ? Colors.white.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.1),
                        border: isToday && !isActive
                            ? Border.all(color: Colors.white, width: 1.5)
                            : null,
                      ),
                      child: isActive
                          ? const Icon(
                              Icons.check,
                              color: Color(0xFF4A90E2),
                              size: 12,
                            )
                          : null,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      weekDayLetters[index],
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isActive
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  /// ✅ اسکرول دقیق به پیام با استفاده از GlobalKey
  void _scrollToMessage(String messageId) {
    // 1. هایلایت پیام
    _highlightMessage(messageId);

    // 2. پیدا کردن کلید پیام
    final key = _messageKeys[messageId];
    if (key == null) {
      _showSnackBar('پیام مورد نظر یافت نشد');
      return;
    }

    // 3. صبر برای رندر شدن کامل
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        // ✅ استفاده از Scrollable.ensureVisible - دقیق‌ترین روش
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          alignment: 0.5, // وسط صفحه
        );
      } catch (e) {
        print('❌ Scroll error: $e');
        _scrollToMessageFallback(messageId);
      }
    });
  }

  /// ✅ روش سوم: Fallback با محاسبه موقعیت بر اساس ایندکس
  void _scrollToMessageFallback(String messageId) {
    final index = _messages.indexWhere((msg) => msg.id == messageId);
    if (index == -1) return;

    final reverseIndex = _messages.length - 1 - index;

    // محاسبه موقعیت با تخمین ارتفاع
    double estimatedOffset = 0;
    final int startIdx = _messages.length - 1;
    final int endIdx = index;

    for (int i = startIdx; i > endIdx; i--) {
      final msg = _messages[i];
      estimatedOffset += _estimateSingleItemHeight(msg);
    }

    // اضافه کردن padding برای اطمینان
    estimatedOffset += 20;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      try {
        final maxOffset = _scrollController.position.maxScrollExtent;
        final target = estimatedOffset.clamp(0.0, maxOffset);

        print(
          '📊 Fallback scroll: index=$index, reverse=$reverseIndex, target=$target, max=$maxOffset',
        );

        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
        );
      } catch (e) {
        print('❌ Fallback scroll error: $e');
      }
    });
  }

  /// ✅ تخمین ارتفاع یک پیام خاص
  double _estimateSingleItemHeight(ChatMessage message) {
    double height = 70.0; // حداقل ارتفاع

    // بر اساس طول متن
    height += (message.content.length / 40) * 14;
    if (message.content.length > 100) height += 10;

    // بر اساس نوع پیام
    switch (message.type) {
      case MessageType.image:
        height += 120;
        break;
      case MessageType.sticker:
        height += 60;
        break;
      case MessageType.gif:
        height += 40;
        break;
      default:
        break;
    }

    // اگر ریپلای دارد
    if (message.replyTo != null) height += 40;

    // اگر متادیتا دارد (چالش، کارت پیشرفت، و...)
    if (message.metadata != null) {
      if (message.metadata!['is_challenge_invite'] == true) height += 80;
      if (message.metadata!['is_progress_card'] == true) height += 70;
      if (message.metadata!['is_performance_widget'] == true) height += 60;
      if (message.metadata!['is_today_list_widget'] == true) height += 80;
      if (message.metadata!['type'] == 'xp_gift_card') height += 70;
      if (message.metadata!['file_url'] != null) height += 50;
    }

    return height;
  }

  /// ✅ روش دوم: محاسبه دقیق موقعیت با RenderBox و اسکرول
  void _scrollToMessageWithRenderBox(String messageId) {
    try {
      final key = _messageKeys[messageId];
      if (key == null) {
        _scrollToMessageFallback(messageId);
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          final context = key.currentContext;
          if (context == null) {
            _scrollToMessageFallback(messageId);
            return;
          }

          final RenderBox renderBox = context.findRenderObject() as RenderBox;
          final Offset position = renderBox.localToGlobal(Offset.zero);
          final Size size = renderBox.size;

          final screenHeight = MediaQuery.of(context).size.height;
          final appBarHeight =
              kToolbarHeight + MediaQuery.of(context).padding.top;
          final bottomBarHeight = 80.0;

          // محاسبه موقعیت مرکزی پیام
          final centerY = position.dy + (size.height / 2);

          // موقعیت هدف برای قرار دادن پیام در مرکز
          final targetScrollOffset =
              centerY -
              (screenHeight / 2) +
              (appBarHeight / 2) +
              (bottomBarHeight / 2);

          final maxOffset = _scrollController.position.maxScrollExtent;
          final safeTarget = targetScrollOffset.clamp(0.0, maxOffset);

          print(
            '📊 RenderBox scroll: position=${position.dy}, size=${size.height}, target=$safeTarget',
          );

          _scrollController.animateTo(
            safeTarget,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
          );
        } catch (e) {
          print('⚠️ RenderBox method failed: $e');
          _scrollToMessageFallback(messageId);
        }
      });
    } catch (e) {
      print('⚠️ RenderBox error: $e');
      _scrollToMessageFallback(messageId);
    }
  }

  /// ✅ پیدا کردن Context یک پیام با استفاده از GlobalKey
  BuildContext? _findMessageWidgetContext(String messageId) {
    try {
      // روش 1: استفاده از GlobalKey ذخیره شده
      // ما باید در _buildMessageBubble یک GlobalKey ذخیره کنیم

      // روش 2: جستجو در درخت ویجت
      // این روش پیچیده است، از روش 3 استفاده می‌کنیم

      // روش 3: استفاده از key در Widget tree
      // اگر به هر پیام یک Key بدهیم، می‌توانیم با روش زیر پیدا کنیم

      // برای سادگی، از روش مستقیم استفاده می‌کنیم:
      // در _buildMessageBubble به Container اصلی کلید می‌دهیم
      // و در اینجا با استفاده از آن کلید، context را پیدا می‌کنیم

      // اما چون flutter نمی‌گذارد مستقیم از کلید استفاده کنیم،
      // از روش fallback استفاده می‌کنیم

      return null;
    } catch (e) {
      return null;
    }
  }

  /// ✅ محاسبه موقعیت دقیق بر اساس موقعیت RenderBox
  double _calculateExactOffset(Offset position, Size size) {
    // در listView با reverse: true، موقعیت از پایین محاسبه می‌شود
    // ما باید موقعیت را از پایین لیست محاسبه کنیم

    // ارتفاع کل محتوای لیست را بدست می‌آوریم
    final totalHeight = _messages.length * 85.0; // تقریبی

    // موقعیت پیام از پایین لیست
    final fromBottom = totalHeight - position.dy - size.height;

    return fromBottom.clamp(0.0, totalHeight);
  }

  /// ✅ جستجوی موقعیت دقیق با روش باینری
  void _findExactPositionWithBinarySearch(
    String messageId,
    int estimatedIndex,
  ) {
    if (!_scrollController.hasClients) return;

    const int maxAttempts = 5;
    int attempts = 0;
    double low = 0;
    double high = _scrollController.position.maxScrollExtent;
    double mid = (low + high) / 2;

    void attemptScroll() {
      if (attempts >= maxAttempts || !mounted) {
        // اگر نتوانستیم پیدا کنیم، به موقعیت تخمینی برویم
        final target = (estimatedIndex * 85.0).clamp(0.0, high);
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        return;
      }

      attempts++;
      _scrollController.jumpTo(mid);

      // بررسی کنیم که آیا پیام در صفحه قابل مشاهده است
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted || !_scrollController.hasClients) return;

        // چک کردن اینکه آیا پیام مورد نظر در viewport است
        final visible = _isMessageVisible(messageId);
        if (visible) {
          // پیدا شد! الان دقیق‌تر تنظیم کن
          _adjustScrollToCenter(messageId);
          return;
        }

        // اگر پیام در بالای viewport است، باید پایین‌تر برویم
        // اگر در پایین است، باید بالاتر برویم
        // اینجا باید بر اساس موقعیت پیام نسبت به viewport تصمیم بگیریم

        // برای سادگی، از روش تخمینی استفاده می‌کنیم
        final target = (estimatedIndex * 85.0).clamp(0.0, high);
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }

    attemptScroll();
  }

  /// ✅ بررسی اینکه آیا پیام در صفحه قابل مشاهده است
  bool _isMessageVisible(String messageId) {
    // این متد باید بررسی کند که آیا پیام با id مشخص در viewport است
    // برای سادگی، true برگردانید تا از حلقه بی‌نهایت جلوگیری شود
    return true;
  }

  /// ✅ تنظیم دقیق اسکرول برای قرار دادن پیام در مرکز
  void _adjustScrollToCenter(String messageId) {
    // با استفاده از RenderBox موقعیت دقیق را پیدا کن
    _scrollToMessageWithRenderBox(messageId);
  }

  /// ✅ تخمین ارتفاع هر آیتم بر اساس تعداد کلمات و نوع پیام
  double _estimateItemHeight() {
    // اگر پیام‌ها وجود ندارند، مقدار پیش‌فرض برگردان
    if (_messages.isEmpty) return 85.0;

    // میانگین ارتفاع پیام‌ها را محاسبه کن
    // برای دقت بیشتر، فقط پیام‌های قابل مشاهده را در نظر بگیر
    final visibleCount = _messages.length > 20 ? 20 : _messages.length;
    double totalHeight = 0;
    int count = 0;

    for (int i = 0; i < visibleCount; i++) {
      final msg = _messages[i];
      // بر اساس نوع پیام و طول متن، ارتفاع را تخمین بزن
      double estimated = 65.0; // حداقل ارتفاع
      estimated += (msg.content.length / 40) * 15; // هر 40 کاراکتر 15 پیکسل
      if (msg.content.length > 100) estimated += 10;

      // پیام‌های با استیکر یا تصویر بزرگتر هستند
      if (msg.type == MessageType.image) estimated += 80;
      if (msg.type == MessageType.sticker) estimated += 40;
      if (msg.type == MessageType.gif) estimated += 30;

      // ریپلای‌ها بزرگتر هستند
      if (msg.replyTo != null) estimated += 35;

      // متادیتاهای خاص (چالش، کارت پیشرفت) بزرگتر هستند
      if (msg.metadata != null) {
        if (msg.metadata!['is_challenge_invite'] == true) estimated += 60;
        if (msg.metadata!['is_progress_card'] == true) estimated += 50;
        if (msg.metadata!['is_performance_widget'] == true) estimated += 40;
      }

      totalHeight += estimated;
      count++;
    }

    if (count == 0) return 85.0;
    return totalHeight / count;
  }

  /// ✅ نمایش پیام خطا
  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.orange,
      ),
    );
  }

  String _getWeekDayLetter(int index) {
    const days = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
    return days[index];
  }

  Widget _buildProgressStat(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementCard(ChatMessage message, bool isMe) {
    final metadata = message.metadata ?? {};
    final title = metadata['title'] ?? 'دستاورد جدید!';
    final badge = metadata['badge'] ?? '🏆';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFA500), Color(0xFFFF6B6B)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(badge, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            metadata['description'] ?? 'تبریک! شما به این دستاورد رسیدید! 🎉',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          if (metadata['xp'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '+${metadata['xp']} XP',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// ✅ نمایش گزینه‌های لینک
  void _showLinkOptions(String url, bool isMe) {
    final bool isLocationLink = _isLocationLink(url);
    final String displayUrl = url.length > 50
        ? '${url.substring(0, 50)}...'
        : url;

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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    displayUrl,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),

                if (isLocationLink)
                  _buildLinkOption(
                    icon: Icons.map,
                    title: 'باز کردن در نقشه',
                    subtitle: 'مشاهده موقعیت روی نقشه',
                    color: const Color(0xFF4A90E2),
                    onTap: () {
                      Navigator.pop(context);
                      _openInMap(url);
                    },
                  ),

                _buildLinkOption(
                  icon: Icons.open_in_browser,
                  title: 'باز کردن در مرورگر',
                  subtitle: 'باز کردن لینک در مرورگر',
                  color: const Color(0xFF2ECC71),
                  onTap: () {
                    Navigator.pop(context);
                    _launchUrl(url);
                  },
                ),

                _buildLinkOption(
                  icon: Icons.copy,
                  title: 'کپی لینک',
                  subtitle: 'کپی آدرس در کلیپ‌بورد',
                  color: const Color(0xFFF39C12),
                  onTap: () {
                    Navigator.pop(context);
                    _copyLink(url);
                  },
                ),

                _buildLinkOption(
                  icon: Icons.share,
                  title: 'اشتراک‌گذاری',
                  subtitle: 'ارسال لینک برای دیگران',
                  color: const Color(0xFF9B59B6),
                  onTap: () {
                    Navigator.pop(context);
                    _shareLink(url);
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

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      final file = result.files.first;

      // ✅ 1. آپلود فایل به سرور
      final String fileUrl = await _uploadFileToServer(file);

      // ✅ 2. ارسال پیام با URL فایل (با await)
      await _sendMessageWithFile(
        // ✅ حالا این خط کار می‌کند
        fileUrl: fileUrl,
        fileName: file.name,
        fileType: _getFileType(file.extension),
        fileSize: file.size,
      );
    }
  }

  Future<String> _uploadFileToServer(
    PlatformFile file, [
    String? customFileName,
  ]) async {
    try {
      final bytes = file.bytes;
      // ✅ اگر نام سفارشی داده شده استفاده کن، وگرنه از نام اصلی استفاده کن
      final fileName = customFileName ?? file.name;

      final String path =
          'chat_files/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      await _supabase.client.storage
          .from('chat_files')
          .uploadBinary(path, bytes!);

      final String fileUrl = _supabase.client.storage
          .from('chat_files')
          .getPublicUrl(path);

      print('📤 فایل آپلود شد: $fileUrl');

      return fileUrl;
    } catch (e) {
      throw Exception('خطا در آپلود فایل: $e');
    }
  }

  Future<void> _sendMessageWithFile({
    required String fileUrl,
    required String fileName,
    required String fileType,
    required int fileSize,
  }) async {
    // ارسال پیام به Supabase با metadata شامل URL عمومی
    await _chatService.client.from('messages').insert({
      'conversation_id': _conversationId,
      'sender_id': _currentUserId,
      'content': '📎 فایل ارسال شد',
      'type': 'file',
      'metadata': {
        'fileUrl': fileUrl,
        'fileName': fileName,
        'fileType': fileType,
        'fileSize': fileSize,
      },
    });
    print('✅ [DEBUG] _sendMessageWithFile inserted successfully!');
  }

  String _getFileType(String? extension) {
    if (extension == null) return 'document';
    final ext = extension.toLowerCase();
    if (['mp3', 'wav', 'aac', 'm4a'].contains(ext)) return 'audio';
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return 'image';
    if (['mp4', 'avi', 'mov', 'mkv'].contains(ext)) return 'video';
    if (['pdf'].contains(ext)) return 'pdf';
    return 'document';
  }

  /// ✅ آیتم گزینه‌های لینک
  Widget _buildLinkOption({
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
          color: const Color(0xFF1A1A2E),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      onTap: onTap,
    );
  }

  /// ✅ ساخت متن با لینک‌های قابل کلیک
  Widget _buildLinkifiedText(String text, bool isMe) {
    final elements = linkify(
      text,
      options: const LinkifyOptions(humanize: false),
    );

    return Wrap(
      children: elements.map((element) {
        if (element is LinkableElement) {
          // ✅ لینک - قابل کلیک
          return GestureDetector(
            onTap: () => _showLinkOptions(element.url, isMe),
            child: Text(
              element.text,
              style: TextStyle(
                color: isMe ? Colors.white : const Color(0xFF4A90E2),
                fontSize: 14,
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        } else {
          // ✅ متن عادی
          return Text(
            element.text,
            style: TextStyle(
              color: isMe ? Colors.white : const Color(0xFF1A1A2E),
              fontSize: 14,
            ),
          );
        }
      }).toList(),
    );
  }

  /// ✅ بررسی اینکه آیا لینک مربوط به موقعیت مکانی است
  bool _isLocationLink(String url) {
    final locationPatterns = [
      'openstreetmap.org',
      'google.com/maps',
      'maps.google.com',
      'neshan.org',
      'map.ir',
      '/maps',
      '?q=',
      '?mlat=',
      '?lat=',
    ];

    final lowerUrl = url.toLowerCase();
    return locationPatterns.any((pattern) => lowerUrl.contains(pattern));
  }

  /// ✅ باز کردن لینک در مرورگر
  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لینک معتبر نیست'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// ✅ باز کردن لینک در نقشه
  void _openInMap(String url) {
    // استخراج مختصات از لینک (اگر ممکن باشد)
    final latLng = _extractLatLngFromUrl(url);

    if (latLng != null) {
      // اگر مختصات داشت، باز کردن در نقشه با مختصات دقیق
      final mapUrl =
          'https://www.openstreetmap.org/?mlat=${latLng.latitude}&mlon=${latLng.longitude}&zoom=16';
      _launchUrl(mapUrl);
    } else {
      // اگر مختصات نداشت، خود لینک را باز کن
      _launchUrl(url);
    }
  }

  /// ✅ استخراج مختصات از لینک
  LatLng? _extractLatLngFromUrl(String url) {
    try {
      // الگوی لینک OpenStreetMap
      final regExp = RegExp(r'[?&]mlat=([\d.-]+)&mlon=([\d.-]+)');
      final match = regExp.firstMatch(url);
      if (match != null) {
        final lat = double.tryParse(match.group(1) ?? '');
        final lng = double.tryParse(match.group(2) ?? '');
        if (lat != null && lng != null) {
          return LatLng(lat, lng);
        }
      }

      // الگوی لینک Google Maps
      final googleRegExp = RegExp(r'[?&]q=([\d.-]+),([\d.-]+)');
      final googleMatch = googleRegExp.firstMatch(url);
      if (googleMatch != null) {
        final lat = double.tryParse(googleMatch.group(1) ?? '');
        final lng = double.tryParse(googleMatch.group(2) ?? '');
        if (lat != null && lng != null) {
          return LatLng(lat, lng);
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // ✅ کپی لینک در کلیپ‌بورد
  void _copyLink(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('لینک کپی شد 📋'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ✅ اشتراک‌گذاری لینک
  void _shareLink(String url) async {
    try {
      final shareText =
          '''
📍 لینک موقعیت مکانی
━━━━━━━━━━━━━━━━━━━━
🔗 $url
━━━━━━━━━━━━━━━━━━━━
📱 ارسال شده از اپلیکیشن قهرمان درون
''';
      await Share.share(shareText);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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

  /// ✅ بررسی اینکه آیا دو تاریخ در یک روز هستند
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

  // lib/features/chat/screens/buddy_chat_screen.dart

  /// ✅ اصلاح متد _buildAppBar - بدون پلیر موزیک (با ChangeNotifier)
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
            // آواتار با دایره وضعیت
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

  /// ✅ متد کمکی برای فرمت زمان
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// ✅ استخراج نام فایل از URL
  String _extractFileName(String? url) {
    if (url == null || url.isEmpty) return '';
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        final fileName = segments.last;
        final parts = fileName.split('_');
        if (parts.length > 1) {
          return parts.sublist(1).join('_');
        }
        return fileName;
      }
      return 'فایل موزیک';
    } catch (e) {
      return 'فایل موزیک';
    }
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
          child: Column(
            children: [
              // ✅ فقط هدر جدید را نگه دارید
              const AudioPlayerHeader(),

              // ✅ بقیه محتوا
              Expanded(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        _buildPinnedMessageBar(),
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

                                    if (index == _messages.length - 1) {
                                      widgets.add(
                                        _buildDateMarker(message.createdAt),
                                      );
                                    } else {
                                      final nextMessage =
                                          _messages[_messages.length -
                                              2 -
                                              index];
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
                    _buildScrollToBottomButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  // ==================== حالت‌ها ====================

  /// ✅ حالت بارگذاری
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

  /// ✅ حالت خالی
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

class MediaMenuItem {
  final IconData icon;
  final String title; // ✅ می‌تواند خالی باشد
  final Color color;
  final VoidCallback onTap;

  MediaMenuItem({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });
}

// ✅ این کلاس باید با سرویس جدید کار کند
class _MusicPlayerWidget extends StatefulWidget {
  final String fileName;
  final String fileSizeString;
  final bool isMe;
  final String? filePath;
  final bool hasBytes;
  final VoidCallback onDownload;
  final Function(String) onShowSnackBar;

  const _MusicPlayerWidget({
    required this.fileName,
    required this.fileSizeString,
    required this.isMe,
    this.filePath,
    required this.hasBytes,
    required this.onDownload,
    required this.onShowSnackBar,
  });

  @override
  State<_MusicPlayerWidget> createState() => _MusicPlayerWidgetState();
}

class _MusicPlayerWidgetState extends State<_MusicPlayerWidget> {
  late AudioPlayerService _audioService; // ✅ تغییر به AudioPlayerService
  late final String _playUrl;
  bool _isLoading = false;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioService = Provider.of<AudioPlayerService>(
      context,
      listen: false,
    ); // ✅ تغییر
    _playUrl = widget.filePath ?? '';

    _position = _audioService.position;
    _duration = _audioService.duration;
    _isPlaying = _audioService.isPlayingUrl(_playUrl);

    _audioService.addListener(_onAudioServiceChanged);
  }

  @override
  void dispose() {
    _audioService.removeListener(_onAudioServiceChanged);
    super.dispose();
  }

  void _onAudioServiceChanged() {
    if (!mounted) return;

    final bool isThisPlaying = _audioService.isPlayingUrl(_playUrl);

    setState(() {
      _position = _audioService.position;
      _duration = _audioService.duration;
      _isPlaying = isThisPlaying;
    });
  }

  Future<void> _togglePlayback() async {
    if (kIsWeb) {
      widget.onShowSnackBar('پخش موزیک در وب به زودی اضافه می‌شود');
      return;
    }

    if (widget.filePath == null || widget.filePath!.isEmpty) {
      widget.onShowSnackBar('فایل موزیک یافت نشد');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final file = File(widget.filePath!);
      if (!await file.exists()) {
        widget.onShowSnackBar('فایل موزیک یافت نشد');
        return;
      }
      await _audioService.togglePlayback(widget.filePath!);
    } catch (e) {
      widget.onShowSnackBar('خطا در پخش موزیک');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _seekTo(double value) {
    final newPosition = Duration(
      milliseconds: (value * _duration.inMilliseconds).toInt(),
    );
    _audioService.seek(newPosition);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bool isThisPlaying = _isPlaying;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isMe ? Colors.purple.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isMe ? Colors.purple.shade200 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ هدر
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.music_note,
                  color: Colors.purple,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.fileName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: widget.isMe ? Colors.black87 : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.fileSizeString,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!kIsWeb)
                IconButton(
                  icon: const Icon(Icons.download, size: 20),
                  color: Colors.purple,
                  onPressed: widget.onDownload,
                  tooltip: 'دانلود موزیک',
                ),
            ],
          ),
          const SizedBox(height: 8),

          // ✅ پلیر با نوار پیشرفت
          Row(
            children: [
              // دکمه پلی/مکث
              GestureDetector(
                onTap: _isLoading ? null : _togglePlayback,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isThisPlaying ? Colors.purple : Colors.purple,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          isThisPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 24,
                        ),
                ),
              ),

              const SizedBox(width: 12),

              // نوار پیشرفت با زمان
              Expanded(
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12,
                        ),
                        activeTrackColor: Colors.purple,
                        inactiveTrackColor: Colors.grey.shade300,
                        thumbColor: Colors.purple,
                        overlayColor: Colors.purple.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: _duration.inMilliseconds > 0
                            ? (_position.inMilliseconds /
                                      _duration.inMilliseconds)
                                  .clamp(0.0, 1.0)
                            : 0.0,
                        onChanged: _duration.inMilliseconds > 0
                            ? _seekTo
                            : null,
                        min: 0,
                        max: 1,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
}
