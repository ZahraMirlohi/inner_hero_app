// lib/features/chat/screens/buddy_chat_screen.dart

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

// ✅ سرویس‌ها
import '/services/chat_service.dart';
import '/services/supabase_service.dart';
import '/services/audio_player_service.dart';
import '/services/date_service.dart';
import '/providers/theme_provider.dart';

// ✅ مدل‌ها
import '../models/message_model.dart';
import '../models/conversation_model.dart';
import '../models/challenge_invite.dart';
import '../models/weekly_habit_performance.dart';
import '../models/today_habits_list.dart';
import '../models/xp_gift.dart';

// ✅ ویجت‌ها
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

// ✅ سرویس‌های تخصصی
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

  // ==================== بارگذاری چالش‌ها ====================
  Future<void> _loadChallengesFromMessages(List<ChatMessage> messages) async {
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
          }
        } catch (e) {
          print('⚠️ Error loading challenge $id: $e');
        }
      }
    } catch (e) {
      print('⚠️ Error in _loadChallengesFromMessages: $e');
    }
  }

  // ==================== Init Chat ====================
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
        if (mounted) {
          setState(() {
            _myName = 'کاربر';
          });
        }
      }

      String buddyId = '';
      if (widget.conversation.memberIds.isNotEmpty) {
        final others =
            widget.conversation.memberIds.where((id) => id != user.id).toList();
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

      try {
        await _loadMessages();
        _scrollToBottom();
      } catch (e) {
        print('❌ Error in _loadMessages: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }

      _messageSubscription = _chatService
          .getMessages(widget.conversation.id, userId: _userId)
          .listen((newMessages) async {
        if (!mounted) return;

        try {
          final messagesWithReactions = await _loadReactionsForMessages(
            newMessages,
          );

          if (mounted) {
            final oldMessageCount = _messages.length;

            setState(() {
              _messages = messagesWithReactions.reversed.toList();
              try {
                _pinnedMessage = _messages.firstWhere((m) => m.isPinned);
              } catch (e) {
                _pinnedMessage = null;
              }
            });

            await _markMessagesAsRead();

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

  // ✅ متد دریافت چالش کش شده
  Future<ChallengeInvite?> _getCachedChallenge(String challengeId) async {
    if (_loadingChallenges.contains(challengeId)) {
      await Future.delayed(const Duration(milliseconds: 100));
      return _challengeCache[challengeId];
    }

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

  void _clearChallengeCache(String challengeId) {
    _challengeCache.remove(challengeId);
    _challengeCacheTime.remove(challengeId);
  }

  // ==================== منوی چندرسانه‌ای ====================
  void _showMediaMenuSheet(ThemeProvider theme, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: theme.surfaceColor,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.35,
          minChildSize: 0.25,
          maxChildSize: 0.45,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      'ارسال',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: theme.textColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        childAspectRatio: 1.0,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _getMediaMenuItems(theme, primaryColor).length,
                      itemBuilder: (context, index) {
                        final item =
                            _getMediaMenuItems(theme, primaryColor)[index];
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

  Widget _buildMediaMenuItem(MediaMenuItem item) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        item.onTap();
      },
      child: Container(
        decoration: const BoxDecoration(color: Colors.transparent),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.icon,
                color: item.color,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<MediaMenuItem> _getMediaMenuItems(
    ThemeProvider theme,
    Color primaryColor,
  ) {
    final bool isWeb = kIsWeb;

    return [
      MediaMenuItem(
        icon: Icons.image,
        title: '',
        color: primaryColor,
        onTap: _sendImage,
      ),
      MediaMenuItem(
        icon: Icons.location_on,
        title: '',
        color: primaryColor,
        onTap: _sendLocation,
      ),
      if (!isWeb)
        MediaMenuItem(
          icon: Icons.contact_phone,
          title: '',
          color: primaryColor,
          onTap: _sendContact,
        ),
      MediaMenuItem(
        icon: Icons.attach_file,
        title: '',
        color: primaryColor,
        onTap: _sendFile,
      ),
      MediaMenuItem(
        icon: Icons.music_note,
        title: '',
        color: primaryColor,
        onTap: _sendMusic,
      ),
      MediaMenuItem(
        icon: Icons.trending_up,
        title: '',
        color: primaryColor,
        onTap: _sendDailyProgressCard,
      ),
      MediaMenuItem(
        icon: Icons.analytics,
        title: '',
        color: primaryColor,
        onTap: _sendWeeklyPerformance,
      ),
      MediaMenuItem(
        icon: Icons.checklist,
        title: '',
        color: primaryColor,
        onTap: _sendTodayHabitsList,
      ),
      MediaMenuItem(
        icon: Icons.emoji_events,
        title: '',
        color: primaryColor,
        onTap: () => _showCreateChallengeDialog(theme, primaryColor),
      ),
      MediaMenuItem(
        icon: Icons.stars,
        title: '',
        color: primaryColor,
        onTap: _sendXPGift,
      ),
    ];
  }

  // ==================== ارسال لوکیشن ====================
  void _sendLocation() async {
    final locationText = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
    );

    if (locationText != null && locationText.isNotEmpty) {
      _sendMessage(text: locationText, type: MessageType.text);
    }
  }

  // ==================== ارسال مخاطب ====================
  Future<void> _sendContact() async {
    final bool isWeb = kIsWeb;

    if (isWeb) {
      _showContactInputDialog();
      return;
    }

    try {
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

      final selectedContact = await showModalBottomSheet<Contact>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                          final phones =
                              contact.phones.map((p) => p.number).toList();

                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .primaryColor
                                  .withValues(alpha: 0.1),
                              child: Text(
                                displayName.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
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
        final phoneNumber =
            phones.isNotEmpty ? phones.first : 'شماره موجود نیست';
        final displayName = selectedContact.displayName ?? 'کاربر';

        final contactText = '''
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

  void _showContactInputDialog() {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final primaryColor = theme.primaryColor;
    final TextEditingController nameController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.contact_phone,
                color: primaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'ارسال شماره تماس',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
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
                prefixIcon: Icon(Icons.person_outline, color: primaryColor),
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
                prefixIcon: Icon(Icons.phone_outlined, color: primaryColor),
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

              final contactText = '''
📞 شماره تماس
━━━━━━━━━━━━━━━━━━━━
👤 نام: ${name.isNotEmpty ? name : 'کاربر'}
📱 شماره: ${phone.isNotEmpty ? phone : 'شماره موجود نیست'}
━━━━━━━━━━━━━━━━━━━━
''';

              _sendMessage(text: contactText, type: MessageType.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
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

  // ==================== ارسال فایل ====================
  Future<void> _sendFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final fileName = file.name;
      final fileSize = file.size ?? 0;

      Uint8List? fileBytes;

      if (file.bytes != null) {
        fileBytes = file.bytes;
      } else if (file.path != null && file.path!.isNotEmpty) {
        try {
          final File fileObj = File(file.path!);
          fileBytes = await fileObj.readAsBytes();
        } catch (e) {
          print('❌ Error reading file from path: $e');
        }
      } else if (kIsWeb) {
        if (file.path != null) {
          final response = await http.get(Uri.parse(file.path!));
          if (response.statusCode == 200) {
            fileBytes = response.bodyBytes;
          }
        }
      }

      if (fileBytes == null) {
        _showSnackBar('فایل قابل خواندن نیست');
        return;
      }

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

      final Map<String, dynamic> metadata = {
        'file_url': fileUrl,
        'file_name': fileName,
        'file_size': fileSize,
        'type': 'file',
        'platform': kIsWeb ? 'web' : 'mobile',
        'is_progress_card': false,
        'is_uploading': false,
      };

      final fileText = '''
📁 فایل ارسال شد
━━━━━━━━━━━━━━━━━━━━
📄 نام فایل: $fileName
📦 حجم: ${_getFileSizeString(fileSize)}
━━━━━━━━━━━━━━━━━━━━
''';

      await _chatService.sendMessage(
        conversationId: widget.conversation.id,
        senderId: _userId!,
        content: fileText,
        type: 'text',
        metadata: metadata,
        senderName: _myName,
      );

      setState(() {
        _messages.removeWhere((msg) => msg.id == tempMessageId);
        _isSending = false;
      });

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

  // ==================== ارسال موزیک ====================
  Future<void> _sendMusic() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.audio,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final fileName = file.name;
      final fileSize = file.size ?? 0;

      Uint8List? fileBytes;

      if (file.bytes != null) {
        fileBytes = file.bytes;
      } else if (file.path != null && file.path!.isNotEmpty) {
        try {
          final File fileObj = File(file.path!);
          fileBytes = await fileObj.readAsBytes();
        } catch (e) {
          print('❌ Error reading file from path: $e');
        }
      } else if (kIsWeb && file.path != null) {
        try {
          final response = await http.get(Uri.parse(file.path!));
          if (response.statusCode == 200) {
            fileBytes = response.bodyBytes;
          }
        } catch (e) {
          print('❌ Error downloading music from URL: $e');
        }
      }

      if (fileBytes == null) {
        _showSnackBar('فایل موزیک قابل خواندن نیست');
        return;
      }

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

      setState(() {
        _messages.insert(0, tempMessage);
        _isSending = true;
      });

      _scrollToBottom();

      final String fileUrl = await _uploadFileToStorageHttp(
        fileBytes: fileBytes,
        fileName: fileName,
        folder: 'chat_music',
      );

      if (fileUrl.isEmpty) {
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

      final Map<String, dynamic> metadata = {
        'file_url': fileUrl,
        'file_name': fileName,
        'file_size': fileSize,
        'type': 'music',
        'platform': kIsWeb ? 'web' : 'mobile',
        'is_progress_card': false,
        'is_uploading': false,
      };

      final musicText = '''
🎵 فایل موزیک
━━━━━━━━━━━━━━━━━━━━
🎶 نام: $fileName
📦 حجم: ${_getFileSizeString(fileSize)}
━━━━━━━━━━━━━━━━━━━━
''';

      try {
        await _chatService.sendMessage(
          conversationId: widget.conversation.id,
          senderId: _userId!,
          content: musicText,
          type: 'text',
          metadata: metadata,
          senderName: _myName,
        );

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

  // ==================== ارسال عملکرد هفتگی ====================
  void _sendWeeklyPerformance() async {
    if (_userId == null) {
      _showSnackBar('لطفاً وارد حساب کاربری خود شوید');
      return;
    }

    try {
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

      final successPercent = (performance.successRate * 100).toInt();
      final motivationalMessage = performance.getMotivationalMessage();

      final String widgetText = '''
📊 عملکرد هفتگی عادت‌ها
━━━━━━━━━━━━━━━━━━━━
✅ انجام شده: ${performance.completedHabits} از ${performance.totalHabits}
📈 نرخ موفقیت: $successPercent%
🔥 استریک: ${_currentStreak} روز
━━━━━━━━━━━━━━━━━━━━
$motivationalMessage
━━━━━━━━━━━━━━━━━━━━
''';

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

  // ==================== ارسال لیست عادت‌های امروز ====================
  void _sendTodayHabitsList() async {
    if (_userId == null) {
      _showSnackBar('لطفاً وارد حساب کاربری خود شوید');
      return;
    }

    try {
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

      final rate = (data.completionRate * 100).toInt();
      final jalaliDate = Jalali.fromDateTime(data.date);
      final dateString = '${jalaliDate.day} ${_getMonthName(jalaliDate.month)}';

      final String widgetText = '''
📋 لیست امروز (${dateString})
━━━━━━━━━━━━━━━━━━━━
✅ انجام شده: ${data.completedItems} از ${data.totalItems}
📈 نرخ موفقیت: $rate%
━━━━━━━━━━━━━━━━━━━━
${data.completionMessage}
━━━━━━━━━━━━━━━━━━━━
''';

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

  // ==================== دیالوگ ساخت چالش ====================
  void _showCreateChallengeDialog(
    ThemeProvider theme,
    Color primaryColor,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return CreateChallengeSheet(
          buddyName: _buddyName ?? 'هم‌مسیر',
          buddyId: _buddyId ?? '',
          userId: _userId ?? '',
          userName: _myName ?? 'کاربر',
          onSubmit: (challenge) {
            _sendChallengeInvite(challenge);
          },
        );
      },
    );
  }

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
        _challengeCache[created.id] = created;

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

  void _respondToChallenge(String challengeId, bool accept) async {
    try {
      final service = ChallengeInviteService();
      final success = await service.respondToChallenge(challengeId, accept);

      if (success && mounted) {
        _challengeCache.remove(challengeId);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? '✅ چالش پذیرفته شد!' : '❌ چالش رد شد'),
            backgroundColor: accept ? Colors.green : Colors.orange,
          ),
        );

        _loadMessages();
      }
    } catch (e) {
      print('❌ Error responding to challenge: $e');
    }
  }

  // ==================== متدهای کمکی ====================
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

  // ==================== آپلود ====================
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

      final extension = fileName.contains('.')
          ? fileName.substring(fileName.lastIndexOf('.'))
          : '.mp3';

      final simpleFileName =
          '${DateTime.now().millisecondsSinceEpoch}$extension';
      final path = '$folder/${user.id}/$simpleFileName';

      await _supabase.client.storage
          .from('chat_files')
          .uploadBinary(path, fileBytes);

      final String publicUrl =
          _supabase.client.storage.from('chat_files').getPublicUrl(path);

      return publicUrl;
    } catch (e) {
      print('❌ Upload error: $e');
      _showSnackBar('خطا در آپلود: ${e.toString()}');
      return '';
    }
  }

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

      final extension = fileName.contains('.')
          ? fileName.substring(fileName.lastIndexOf('.'))
          : '.jpg';

      final simpleFileName =
          '${DateTime.now().millisecondsSinceEpoch}$extension';
      final path = '$folder/${user.id}/$simpleFileName';

      final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
      final storageUrl = '$supabaseUrl/storage/v1/object/chat_files/$path';

      String contentType = 'application/octet-stream';
      if (extension == '.jpg' || extension == '.jpeg') {
        contentType = 'image/jpeg';
      } else if (extension == '.png') {
        contentType = 'image/png';
      } else if (extension == '.gif') {
        contentType = 'image/gif';
      } else if (extension == '.mp3') {
        contentType = 'audio/mpeg';
      } else if (extension == '.pdf') {
        contentType = 'application/pdf';
      }

      final response = await http.put(
        Uri.parse(storageUrl),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': contentType,
          'x-upsert': 'true',
        },
        body: fileBytes,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final publicUrl =
            _supabase.client.storage.from('chat_files').getPublicUrl(path);
        return publicUrl;
      } else {
        _showSnackBar('خطا در آپلود: ${response.statusCode}');
        return '';
      }
    } catch (e) {
      print('❌ Upload error (HTTP): $e');
      _showSnackBar('خطا در آپلود: ${e.toString()}');
      return '';
    }
  }

  // ==================== ارسال یادآور ====================
  void _sendReminder(String challengeTitle) async {
    if (_userId == null || _buddyId == null) return;

    final reminderText = '''
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

  // ==================== ارسال کارت پیشرفت ====================
  void _sendDailyProgressCard() {
    _getTodayStatsAndSend();
  }

  Future<void> _getTodayStatsAndSend() async {
    try {
      final user = await _supabase.getCurrentUser();
      if (user == null) return;

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

      final profile = await _supabase.client
          .from('profiles')
          .select('current_streak, best_streak')
          .eq('user_id', user.id)
          .maybeSingle();

      final weekDays = await _getWeekDaysStatus(user.id);

      _totalTodayHabits = total;
      _todayHabitsCompleted = completed;
      _todayHabitsRemaining = total - completed;
      _currentStreak = profile?['current_streak'] ?? 0;
      _weekDays = weekDays;

      final String progressText = '''
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

  Future<List<bool>> _getWeekDaysStatus(String userId) async {
    List<bool> weekDays = List.filled(7, false);

    try {
      final now = DateTime.now();
      final jalaliNow = Jalali.fromDateTime(now);
      final daysToSubtract = jalaliNow.weekDay - 1;
      final weekStart = now.subtract(Duration(days: daysToSubtract));

      for (int i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        final dateStr = date.toIso8601String().split('T').first;

        final activity = await _supabase.client
            .from('user_daily_activity')
            .select('is_active')
            .eq('user_id', userId)
            .eq('activity_date', dateStr)
            .maybeSingle();

        final isActive = activity != null && activity['is_active'] == true;
        weekDays[i] = isActive;
      }

      return weekDays;
    } catch (e) {
      print('❌ Error getting week days status: $e');
      return weekDays;
    }
  }

  // ==================== ارسال هدیه XP ====================
  void _sendXPGift() async {
    if (_userId == null || _buddyId == null) {
      _showSnackBar('لطفاً وارد حساب کاربری خود شوید');
      return;
    }

    try {
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

      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => XPGiftDialog(
          senderName: _myName ?? 'کاربر',
          receiverName: _buddyName ?? 'کاربر',
          maxXP: userXP,
        ),
      );

      if (result == null) return;

      final amount = result['amount'] as int;
      final message = result['message'] as String? ?? '';

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

  // ==================== منوی هدر ====================
  void _showHeaderMenu(ThemeProvider theme, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                  'گزینه‌های گفتگو',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildMenuTile(
                  icon: _isChatMuted ? Icons.volume_off : Icons.volume_up,
                  title: _isChatMuted ? 'فعال کردن صدا' : 'بی‌صدا کردن',
                  subtitle: _isChatMuted
                      ? 'اعلان‌های این گفتگو فعال می‌شوند'
                      : 'اعلان‌های این گفتگو غیرفعال می‌شوند',
                  onTap: () {
                    Navigator.pop(context);
                    _toggleMuteChat(primaryColor);
                  },
                  color: _isChatMuted ? Colors.green : primaryColor,
                ),
                const Divider(height: 1),
                _buildMenuTile(
                  icon: Icons.search,
                  title: 'جستجو در گفتگو',
                  subtitle: 'جستجوی پیام‌ها',
                  onTap: () {
                    Navigator.pop(context);
                    _showSearchInChat(primaryColor);
                  },
                  color: primaryColor,
                ),
                const Divider(height: 1),
                _buildMenuTile(
                  icon: Icons.delete_sweep,
                  title: 'پاک کردن تاریخچه',
                  subtitle: 'تمام پیام‌های این گفتگو حذف می‌شوند',
                  onTap: () {
                    Navigator.pop(context);
                    _confirmClearHistory(primaryColor);
                  },
                  color: Colors.orange,
                ),
                const Divider(height: 1),
                _buildMenuTile(
                  icon: Icons.exit_to_app,
                  title: 'حذف گفتگو',
                  subtitle: 'از لیست گفتگوها حذف می‌شود',
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteConversation(primaryColor);
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
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
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

  void _toggleMuteChat(Color primaryColor) {
    setState(() {
      _isChatMuted = !_isChatMuted;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isChatMuted ? '🔇 گفتگو بی‌صدا شد' : '🔊 گفتگو صدا دار شد',
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: primaryColor,
      ),
    );
  }

  // ==================== جستجو در چت ====================
  void _showSearchInChat(Color primaryColor) {
    final TextEditingController searchController = TextEditingController();
    final FocusNode focusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.search,
                color: primaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'جستجو در گفتگو',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
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
                prefixIcon: Icon(Icons.search, color: primaryColor),
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
      _scrollToMessage(results.first.id);
      return;
    }

    _showSearchResultsSheet(results, query);
  }

  void _scrollToPinnedMessage(String messageId) {
    final index = _messages.indexWhere((msg) => msg.id == messageId);
    if (index == -1) {
      _showSnackBar('پیام پین شده در لیست موجود نیست');
      return;
    }

    _highlightMessage(messageId);
    _scrollToMessageWithEnsureVisible(messageId);
  }

  void _scrollToMessageWithEnsureVisible(String messageId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messageKeys.containsKey(messageId)) {
        _messageKeys[messageId] = GlobalKey();
      }

      final key = _messageKeys[messageId]!;
      _tryEnsureVisible(key, messageId, attempt: 0);
    });
  }

  void _tryEnsureVisible(GlobalKey key, String messageId, {int attempt = 0}) {
    const maxAttempts = 5;
    const delay = Duration(milliseconds: 200);

    Future.delayed(delay * (attempt + 1), () {
      if (!mounted) return;

      try {
        final context = key.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
            alignment: 0.5,
          );
          return;
        }
      } catch (e) {
        print('⚠️ EnsureVisible attempt ${attempt + 1} failed: $e');
      }

      if (attempt < maxAttempts - 1) {
        _tryEnsureVisible(key, messageId, attempt: attempt + 1);
      } else {
        _scrollToMessageFallback(messageId);
      }
    });
  }

  void _showSearchResultsSheet(List<ChatMessage> results, String query) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFF4A90E2),
                            child: Text(
                              isMe ? 'من' : '👤',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
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

  void _confirmClearHistory(Color primaryColor) {
    _clearChatHistory(primaryColor);
  }

  Future<bool> _ensureValidSession() async {
    try {
      final session = _chatService.client.auth.currentSession;
      if (session == null) {
        return false;
      }

      final expiresAt = session.expiresAt;
      if (expiresAt != null) {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if (expiresAt - now < 60) {
          try {
            await _chatService.client.auth.refreshSession();
          } catch (e) {
            return false;
          }
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _clearChatHistory(Color primaryColor) async {
    if (_userId == null) return;

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

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
      await _chatService.client
          .from('messages')
          .delete()
          .eq('conversation_id', widget.conversation.id);

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

  void _confirmDeleteConversation(Color primaryColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'حذف گفتگو',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'آیا از حذف گفتگو با "${_buddyName ?? 'کاربر'}" مطمئن هستید؟\n\n'
          'با این کار، این گفتگو از لیست شما حذف می‌شود.',
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
        Navigator.pop(context);
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

  Future<void> _markMessagesAsRead() async {
    if (_userId == null || _messages.isEmpty) return;

    final unreadMessages = _messages.where((msg) {
      final isFromOther = msg.senderId != _userId;
      final isUnread = msg.status != MessageStatus.seen &&
          msg.status != MessageStatus.delivered;
      final isNotDeleted = !msg.isDeleted;
      return isFromOther && isUnread && isNotDeleted;
    }).toList();

    if (unreadMessages.isEmpty) return;

    try {
      await _chatService.markAllMessagesAsReadSafe(
        conversationId: widget.conversation.id,
        userId: _userId!,
      );

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
    } catch (e) {
      print('❌ Error marking messages as read: $e');
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
    if (updatedAt != null && updatedAt.isNotEmpty) {
      try {
        final lastSeen = DateTime.parse(updatedAt).toUtc();
        final now = DateTime.now().toUtc();
        final diff = now.difference(lastSeen);
        final isOnline = diff.inMinutes < 5;

        if (mounted) {
          setState(() {
            _isBuddyOnline = isOnline;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isBuddyOnline = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isBuddyOnline = false;
        });
      }
    }
  }

  // ==================== Build Message Menu ====================
  Widget _buildMessageActionsPopup(ThemeProvider theme, Color primaryColor) {
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
    const double menuItemsHeight = 270;
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
              color: theme.surfaceColor,
              borderRadius: BorderRadius.circular(20),
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
                  final isSelected = message.reactions?.any(
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
                            ? primaryColor.withValues(alpha: 0.15)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: primaryColor,
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
              color: theme.surfaceColor,
              borderRadius: BorderRadius.circular(20),
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
                      _editMessage(message, primaryColor);
                    },
                  ),
                _buildPopupMenuItem(
                  icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  label: isPinned ? 'لغو پین' : 'پین کردن',
                  color: isPinned ? Colors.orange : primaryColor,
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
                    _showDeleteOptionsDialog(message, primaryColor);
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

  Future<void> _pinMessage(ChatMessage message) async {
    if (_userId == null) return;

    try {
      await _chatService.pinMessage(messageId: message.id, userId: _userId!);

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
            isPinned: true,
            pinnedAt: DateTime.now(),
            pinnedBy: _userId,
          );
        }

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

  Future<void> _unpinMessage(ChatMessage message) async {
    try {
      await _chatService.unpinMessage(messageId: message.id);

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

  Widget _buildPinnedMessageBar(ThemeProvider theme, Color primaryColor) {
    if (_pinnedMessage == null) return const SizedBox.shrink();

    final message = _pinnedMessage!;
    final isMe = message.senderId == _userId;
    final senderName = isMe ? 'شما' : (message.senderName ?? 'کاربر');

    return GestureDetector(
      onTap: () {
        _scrollToPinnedMessage(message.id);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.push_pin, color: primaryColor, size: 16),
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
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textSecondaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: theme.textSecondaryColor,
              onPressed: () => _unpinMessage(message),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopupMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
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

  void _showMessageActionsPopup(ChatMessage message, Offset position) {
    setState(() {
      _menuMessage = message;
      _menuPosition = position;
    });
  }

  void _closeMenu() {
    setState(() {
      _menuMessage = null;
      _menuPosition = null;
    });
  }

  Future<void> _getBuddyStatus(String buddyId) async {
    if (!mounted) return;

    try {
      final profile = await _chatService.client
          .from('profiles')
          .select('last_seen_at, updated_at')
          .eq('user_id', buddyId)
          .maybeSingle();

      if (mounted) {
        if (profile != null) {
          final lastSeen = profile['last_seen_at'] ?? profile['updated_at'];
          _checkOnlineStatus(lastSeen);
        } else {
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

  ChatMessage? _findPinnedMessage(List<ChatMessage> messages) {
    try {
      return messages.firstWhere((m) => m.isPinned);
    } catch (e) {
      return null;
    }
  }

  Future<void> _loadMessages() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      _messageKeys.clear();

      final messages = await _chatService.getMessagesHistory(
        widget.conversation.id,
        limit: 200,
      );

      if (mounted) {
        setState(() {
          _messages = messages.reversed.toList();
          _isLoading = false;

          try {
            _pinnedMessage = _messages.firstWhere((m) => m.isPinned);
          } catch (e) {
            _pinnedMessage = null;
          }
        });

        await _markMessagesAsRead();
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

  Future<List<ChatMessage>> _loadReactionsForMessages(
    List<ChatMessage> messages,
  ) async {
    if (messages.isEmpty) return messages;

    try {
      final allReactions = await _chatService.getConversationReactions(
        widget.conversation.id,
      );

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

  void _scrollToBottom({bool animated = true}) {
    if (!mounted) return;
    if (_messages.isEmpty || !_scrollController.hasClients) return;

    try {
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

  Widget _buildScrollToBottomButton(Color primaryColor) {
    if (_messages.length < 5) return const SizedBox.shrink();

    bool isAtBottom = true;
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      isAtBottom = position.pixels < 50;
    }

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
            color: primaryColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.4),
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
  Future<void> _sendMessage({
    String? text,
    MessageType type = MessageType.text,
    Map<String, dynamic>? metadata,
    String? replyToId,
  }) async {
    final content = text ?? _messageController.text.trim();

    if (content.isEmpty && replyToId == null && _replyToMessage == null) return;
    if (content.isEmpty && (replyToId != null || _replyToMessage != null)) {
      return;
    }

    if (_userId == null || _isSending) return;

    final replyTo = _replyToMessage;
    final replyToIdToSend = replyToId ?? replyTo?.id;

    final typeString = type.toString().split('.').last;

    final tempMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: widget.conversation.id,
      senderId: _userId!,
      senderName: _myName,
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
      print('❌ Error sending message: $e');

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
          .update({'last_seen_at': now}).eq('user_id', userId);
    } catch (e) {
      print('⚠️ Error updating last_seen: $e');
    }
  }

  // ==================== ارسال عکس ====================
  Future<void> _sendImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image == null) return;

      final tempMessageId = DateTime.now().millisecondsSinceEpoch.toString();

      final tempMessage = ChatMessage(
        id: tempMessageId,
        conversationId: widget.conversation.id,
        senderId: _userId!,
        senderName: _myName,
        senderAvatar: null,
        content: '🖼️ در حال آپلود تصویر...',
        type: MessageType.text,
        status: MessageStatus.sending,
        metadata: {
          'type': 'image',
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

      final String imageUrl = await _uploadImage(image);

      if (imageUrl.isEmpty) {
        setState(() {
          final index = _messages.indexWhere((msg) => msg.id == tempMessageId);
          if (index != -1) {
            _messages[index].status = MessageStatus.failed;
          }
          _isSending = false;
        });
        _showSnackBar('خطا در آپلود عکس');
        return;
      }

      final Map<String, dynamic> metadata = {
        'type': 'image',
        'width': 1024,
        'height': 1024,
        'is_uploading': false,
      };

      await _chatService.sendMessage(
        conversationId: widget.conversation.id,
        senderId: _userId!,
        content: imageUrl,
        type: 'image',
        metadata: metadata,
        senderName: _myName,
      );

      setState(() {
        _messages.removeWhere((msg) => msg.id == tempMessageId);
        _isSending = false;
      });

      await _loadMessages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🖼️ عکس با موفقیت ارسال شد'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('❌ Error in _sendImage: $e');
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

  Future<String> _uploadImage(XFile imageFile) async {
    try {
      final File file = File(imageFile.path);
      final bytes = await file.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

      final String fileUrl = await _uploadFileToStorageHttp(
        fileBytes: bytes,
        fileName: fileName,
        folder: 'chat_images',
      );

      return fileUrl;
    } catch (e) {
      print('❌ Error uploading image: $e');
      return '';
    }
  }

  // ==================== وضعیت تایپ ====================
  Future<void> _sendTypingStatus(bool isTyping) async {
    if (_userId == null) return;
    try {
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

  // ==================== ارسال GIF ====================
  void _sendGif(String gifName, String gifId) {
    _sendMessage(
      text: gifName,
      type: MessageType.gif,
      metadata: {'gif_id': gifId},
    );
    setState(() {
      _showGifPicker = false;
    });
  }

  // ==================== واکنش ====================
  Future<void> _toggleReaction(ChatMessage message, String emoji) async {
    if (_userId == null) return;

    try {
      await _chatService.toggleReaction(
        messageId: message.id,
        userId: _userId!,
        emoji: emoji,
      );
      await _updateLastSeen(_userId!);

      setState(() {
        final index = _messages.indexWhere((msg) => msg.id == message.id);
        if (index != -1) {
          final currentMessage = _messages[index];

          List<MessageReaction> currentReactions = List.from(
            currentMessage.reactions ?? [],
          );

          final userReactionIndex = currentReactions.indexWhere(
            (r) => r.userId == _userId,
          );

          if (userReactionIndex != -1) {
            final existingEmoji = currentReactions[userReactionIndex].emoji;

            if (existingEmoji == emoji) {
              currentReactions.removeAt(userReactionIndex);
            } else {
              currentReactions[userReactionIndex] = MessageReaction(
                userId: _userId!,
                emoji: emoji,
                userName: 'من',
                createdAt: DateTime.now(),
              );
            }
          } else {
            currentReactions.add(
              MessageReaction(
                userId: _userId!,
                emoji: emoji,
                userName: 'من',
                createdAt: DateTime.now(),
              ),
            );
          }

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

  void _enterSelectMode(String messageId) {
    setState(() {
      _isSelectMode = true;
      _selectedMessageIds.add(messageId);
    });
  }

  void _exitSelectMode() {
    setState(() {
      _isSelectMode = false;
      _selectedMessageIds.clear();
    });
  }

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

  Future<void> _deleteSelectedMessages() async {
    if (_selectedMessageIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

  void _setReplyTo(ChatMessage message) {
    setState(() {
      _replyToMessage = message;
    });
    _focusNode.requestFocus();
  }

  void _showDeleteOptionsDialog(ChatMessage message, Color primaryColor) {
    final isOwnMessage = message.senderId == _userId;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف پیام', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              leading: const Icon(Icons.person_remove, color: Colors.orange),
              title: const Text('حذف برای من'),
              subtitle: const Text('پیام فقط برای شما حذف میشود'),
              onTap: () {
                Navigator.pop(context);
                _deleteMessageForMe(message);
              },
            ),
            if (isOwnMessage)
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
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

  void _forwardMessage(ChatMessage message) async {
    try {
      final String appLink =
          dotenv.env['APP_DOWNLOAD_LINK'] ?? 'https://innerhero.app/download';
      final String appName = dotenv.env['APP_NAME'] ?? 'قهرمان درون';

      if (message.type == MessageType.image) {
        final String shareText = '''
📷 ${message.senderName ?? 'کاربر'} یک تصویر ارسال کرده:

🔗 مشاهده تصویر: ${message.content}

━━━━━━━━━━━━━━━━━━━━
📱 $appName - اپلیکیشن مدیریت عادت‌ها
🔗 دانلود اپلیکیشن: $appLink
━━━━━━━━━━━━━━━━━━━━
''';

        await Share.share(shareText);
      } else {
        final String shareText = '''
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

  Future<void> _deleteMessageForMe(ChatMessage message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

  Future<void> _deleteMessageForEveryone(ChatMessage message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

  bool _hasUserReacted(ChatMessage message) {
    if (_userId == null) return false;
    return message.reactions?.any((r) => r.userId == _userId) ?? false;
  }

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

  Widget _buildReactions(ChatMessage message, Color primaryColor) {
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                border: isUserReacted
                    ? Border.all(color: primaryColor, width: 1.5)
                    : null,
                borderRadius: BorderRadius.circular(14),
                color: Colors.transparent,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    emoji,
                    style: TextStyle(
                      fontSize: 15,
                      color: isUserReacted ? primaryColor : Colors.black87,
                    ),
                  ),
                  if (count > 1) ...[
                    const SizedBox(width: 2),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        color:
                            isUserReacted ? primaryColor : Colors.grey.shade600,
                        fontWeight:
                            isUserReacted ? FontWeight.bold : FontWeight.w500,
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
  void _editMessage(ChatMessage message, Color primaryColor) {
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
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.edit_outlined,
                color: primaryColor,
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
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
            contentPadding: const EdgeInsets.all(14),
            fillColor: Colors.grey.shade50,
            filled: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
      ),
    );
  }

  void _copyMessage(ChatMessage message) {
    final String appLink = 'https://innerhero.app/download';
    final String appName = 'قهرمان درون';

    final String copyText = '''
${message.content}

━━━━━━━━━━━━━━━━━━━━
📱 ارسال شده از اپلیکیشن $appName
🔗 دانلود اپلیکیشن: $appLink
━━━━━━━━━━━━━━━━━━━━
''';

    Clipboard.setData(ClipboardData(text: copyText));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('متن با لینک دانلود کپی شد 📋'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ==================== ساخت پیام ====================
  Widget _buildMessageBubble(
    ChatMessage message,
    ThemeProvider theme,
    Color primaryColor,
  ) {
    final isMe = message.senderId == _userId;
    final isSystem = message.type == MessageType.system;
    final isSelected = _selectedMessageIds.contains(message.id);
    final isFailed = message.status == MessageStatus.failed;

    if (!_messageKeys.containsKey(message.id)) {
      _messageKeys[message.id] = GlobalKey();
    }
    final key = _messageKeys[message.id]!;

    if (isSystem) {
      return Container(
        key: key,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
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
          color: primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.reply, color: primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'پاسخ',
              style: TextStyle(
                color: primaryColor,
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
              ? primaryColor.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
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
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? primaryColor : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: message.isPinned
                        ? Border.all(color: Colors.orange, width: 2)
                        : _highlightedMessageId == message.id
                            ? Border.all(color: primaryColor, width: 2)
                            : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                      if (message.isPinned)
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.2),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      if (_highlightedMessageId == message.id)
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
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
                      if (message.isPinned)
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
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
                      if (message.replyTo != null)
                        GestureDetector(
                          onTap: () {
                            _scrollToMessage(message.replyToId!);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border(
                                left: BorderSide(
                                  color: isMe
                                      ? primaryColor.withValues(alpha: 0.6)
                                      : primaryColor,
                                  width: 3,
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
                                      size: 10,
                                      color: isMe
                                          ? Colors.white.withValues(alpha: 0.7)
                                          : primaryColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        _getReplyToSenderName(message),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: isMe
                                              ? Colors.white
                                                  .withValues(alpha: 0.8)
                                              : primaryColor,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _truncateText(message.replyTo!.content, 40),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isMe
                                        ? Colors.white.withValues(alpha: 0.6)
                                        : Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      _buildMessageContent(
                        message,
                        isMe,
                        theme,
                        primaryColor,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
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
                                    : theme.textSecondaryColor,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              if (isFailed)
                                const Icon(
                                  Icons.error_outline,
                                  size: 14,
                                  color: Colors.red,
                                )
                              else
                                _buildStatusIcon(message.status, primaryColor),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildReactions(message, primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  void _showFailedMessageOptions(ChatMessage message) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final primaryColor = theme.primaryColor;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                _buildFailedMessageOption(
                  icon: Icons.refresh,
                  title: 'ارسال مجدد',
                  subtitle: 'تلاش مجدد برای ارسال پیام',
                  color: primaryColor,
                  onTap: () {
                    Navigator.pop(context);
                    _resendFailedMessage(message);
                  },
                ),
                const Divider(height: 1),
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

  Widget _buildFailedMessageOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
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

  Future<void> _resendFailedMessage(ChatMessage message) async {
    if (_userId == null) return;

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

  String _getReplyToSenderName(ChatMessage message) {
    if (message.replyTo == null) return 'کاربر';

    final replyTo = message.replyTo!;

    if (replyTo.senderId == _userId) {
      return 'شما';
    }

    if (replyTo.senderName != null && replyTo.senderName!.isNotEmpty) {
      return replyTo.senderName!;
    }

    if (_buddyName != null && replyTo.senderId == _buddyId) {
      return _buddyName!;
    }

    return 'کاربر';
  }

  Widget _buildStatusIcon(MessageStatus status, Color primaryColor) {
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
        return Icon(Icons.done_all, size: 14, color: primaryColor);

      case MessageStatus.failed:
        return Icon(Icons.error_outline, size: 14, color: Colors.red.shade300);
    }
  }

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }

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
      if (mounted) {
        setState(() {
          _pinnedMessage = null;
        });
      }
    }
  }

  void _highlightMessage(String messageId) {
    _highlightedMessageId = null;

    setState(() {
      _highlightedMessageId = messageId;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _highlightedMessageId = null;
        });
      }
    });
  }

  Widget _buildDateMarker(DateTime date, ThemeProvider theme) {
    return FutureBuilder<String>(
      future: _getDateLabel(date),
      builder: (context, snapshot) {
        final label = snapshot.data ?? '...';
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: theme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.textSecondaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageContent(
    ChatMessage message,
    bool isMe,
    ThemeProvider theme,
    Color primaryColor,
  ) {
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

    if (message.status == MessageStatus.failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.content,
            style: TextStyle(
              color: isMe ? Colors.white : theme.textColor,
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

    // ✅ کارت هدیه XP
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
            color: isMe ? Colors.white : theme.textColor,
            fontSize: 14,
          ),
        );
      }
    }

    // ✅ ویجت چالش
    if (message.metadata != null &&
        (message.metadata!['is_challenge_invite'] == true ||
            message.metadata!['is_active_challenge'] == true)) {
      try {
        final challengeId = message.metadata!['challenge_id'] as String;
        final challenge = _challengeCache[challengeId];

        if (challenge == null) {
          _loadChallengeInBackground(challengeId);
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              '⏳ در حال بارگذاری چالش...',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          );
        }

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
            color: isMe ? Colors.white : theme.textColor,
            fontSize: 14,
          ),
        );
      }
    }

    // ✅ لیست امروز
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
            color: isMe ? Colors.white : theme.textColor,
            fontSize: 14,
          ),
        );
      }
    }

    // ✅ عملکرد هفتگی
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
            color: isMe ? Colors.white : theme.textColor,
            fontSize: 14,
          ),
        );
      }
    }

    // ✅ فایل و موزیک
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

      return FileMessageWidget(
        key: ValueKey('file_${message.id}_${fileUrl.hashCode}'),
        fileUrl: fileUrl,
        fileName: fileName,
        fileType: fileType,
        fileSize: fileSize,
        isMe: isMe,
      );
    }

    // ✅ کارت پیشرفت
    if (message.metadata != null &&
        message.metadata!['is_progress_card'] == true) {
      return _buildProgressCard(message, isMe, theme, primaryColor);
    }

    if (message.type == MessageType.progress) {
      return _buildProgressCard(message, isMe, theme, primaryColor);
    }

    // ✅ لینک لوکیشن
    if (message.type == MessageType.text && _isLocationLink(message.content)) {
      return Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF090909) : theme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
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
                      color: isMe ? Colors.white : theme.textColor,
                    ),
                  ),
                  Text(
                    'مشاهده روی نقشه',
                    style: TextStyle(
                      fontSize: 11,
                      color: isMe ? Colors.white70 : theme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 16),
              color: isMe ? Colors.white : primaryColor,
              onPressed: () => _openInMap(message.content),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    }

    // ✅ شماره تماس
    if (message.type == MessageType.text &&
        _isContactMessage(message.content)) {
      return _buildContactMessage(message, isMe, theme);
    }

    switch (message.type) {
      case MessageType.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
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
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primaryColor,
                  ),
                ),
              );
            },
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
                  color: isMe ? Colors.white : theme.textColor,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );

      default:
        return _buildLinkifiedText(message.content, isMe, theme, primaryColor);
    }
  }

  bool _isContactMessage(String content) {
    return content.contains('📞 شماره تماس') ||
        content.contains('👤 نام:') ||
        content.contains('📱 شماره:');
  }

  Widget _buildContactMessage(
    ChatMessage message,
    bool isMe,
    ThemeProvider theme,
  ) {
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
        color: isMe ? const Color(0xFF090909) : theme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
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
                    color: isMe ? Colors.white : theme.textColor,
                  ),
                ),
                Text(
                  phone.isNotEmpty ? phone : 'شماره موجود نیست',
                  style: TextStyle(
                    fontSize: 11,
                    color: isMe ? Colors.white70 : theme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          if (phone.isNotEmpty && phone != 'شماره موجود نیست')
            IconButton(
              icon: const Icon(Icons.phone, size: 16),
              color: isMe ? Colors.white : Colors.blue,
              onPressed: () => _callPhoneNumber(phone),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  void _callPhoneNumber(String phone) {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isNotEmpty) {
      final url = 'tel:$cleanPhone';
      _launchUrl(url);
    }
  }

  void _loadChallengeInBackground(String challengeId) {
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

  void _refreshChallenge(String challengeId) {
    _challengeCache.remove(challengeId);
    _loadChallengeInBackground(challengeId);
  }

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
          borderRadius: BorderRadius.circular(14),
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

  Widget _buildProgressCard(
    ChatMessage message,
    bool isMe,
    ThemeProvider theme,
    Color primaryColor,
  ) {
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
      width: 280,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF090909),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
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
              Icon(Icons.trending_up, color: primaryColor, size: 16),
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
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      color: Colors.orange,
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
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total > 0 ? completed / total : 0,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              color: primaryColor,
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
                            ? primaryColor
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
                              color: Colors.white,
                              size: 12,
                            )
                          : null,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      weekDayLetters[index],
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal,
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

  void _scrollToMessage(String messageId) {
    _highlightMessage(messageId);

    final key = _messageKeys[messageId];
    if (key == null) {
      _showSnackBar('پیام مورد نظر یافت نشد');
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          alignment: 0.5,
        );
      } catch (e) {
        print('❌ Scroll error: $e');
        _scrollToMessageFallback(messageId);
      }
    });
  }

  void _scrollToMessageFallback(String messageId) {
    final index = _messages.indexWhere((msg) => msg.id == messageId);
    if (index == -1) return;

    double estimatedOffset = 0;
    final int startIdx = _messages.length - 1;
    final int endIdx = index;

    for (int i = startIdx; i > endIdx; i--) {
      estimatedOffset += _estimateSingleItemHeight(_messages[i]);
    }

    estimatedOffset += 20;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      try {
        final maxOffset = _scrollController.position.maxScrollExtent;
        final target = estimatedOffset.clamp(0.0, maxOffset);

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

  double _estimateSingleItemHeight(ChatMessage message) {
    double height = 70.0;

    height += (message.content.length / 40) * 14;
    if (message.content.length > 100) height += 10;

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

    if (message.replyTo != null) height += 40;

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

  Future<void> _getHabitTimeToday(String habitId) async {
    return;
  }

  // ==================== Build ====================
  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(theme, primaryColor),
      body: GestureDetector(
        onTap: () {
          if (_menuMessage != null) {
            _closeMenu();
          }
        },
        child: SafeArea(
          child: Column(
            children: [
              const AudioPlayerHeader(),
              Expanded(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        _buildPinnedMessageBar(theme, primaryColor),
                        Expanded(
                          child: _isLoading
                              ? _buildLoadingState(primaryColor)
                              : _messages.isEmpty
                                  ? _buildEmptyState(theme, primaryColor)
                                  : ListView.builder(
                                      controller: _scrollController,
                                      reverse: true,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      itemCount: _messages.length,
                                      itemBuilder: (context, index) {
                                        final message = _messages[
                                            _messages.length - 1 - index];
                                        final widgets = <Widget>[];

                                        if (index == _messages.length - 1) {
                                          widgets.add(
                                            _buildDateMarker(
                                              message.createdAt,
                                              theme,
                                            ),
                                          );
                                        } else {
                                          final nextMessage = _messages[
                                              _messages.length - 2 - index];
                                          if (!_isSameDay(
                                            message.createdAt,
                                            nextMessage.createdAt,
                                          )) {
                                            widgets.add(
                                              _buildDateMarker(
                                                message.createdAt,
                                                theme,
                                              ),
                                            );
                                          }
                                        }

                                        widgets.add(
                                          _buildMessageBubble(
                                            message,
                                            theme,
                                            primaryColor,
                                          ),
                                        );
                                        return Column(children: widgets);
                                      },
                                    ),
                        ),
                        _buildInputBar(theme, primaryColor),
                      ],
                    ),
                    _buildMessageActionsPopup(theme, primaryColor),
                    _buildScrollToBottomButton(primaryColor),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: primaryColor, strokeWidth: 2),
          const SizedBox(height: 12),
          const Text(
            'در حال بارگذاری پیام‌ها...',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider theme, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'گفتگو را شروع کنید',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'با ${_buddyName ?? 'کاربر'} پیام دهید',
            style: TextStyle(
              fontSize: 13,
              color: theme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Reply Preview ====================
  Widget _buildReplyPreview(ThemeProvider theme, Color primaryColor) {
    if (_replyToMessage == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'پاسخ به ${_replyToMessage!.senderName ?? "کاربر"}',
                  style: TextStyle(
                    fontSize: 12,
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _replyToMessage!.content,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.textColor,
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

  // ==================== Sticker Picker ====================
  Widget _buildStickerPicker(ThemeProvider theme, Color primaryColor) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              Text(
                'استیکرها',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.textColor,
                ),
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
                      borderRadius: BorderRadius.circular(14),
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

  Widget _buildGifPicker(ThemeProvider theme, Color primaryColor) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              Text(
                'GIF',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.textColor,
                ),
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
                      borderRadius: BorderRadius.circular(14),
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

  // ==================== Input Bar ====================
  Widget _buildInputBar(ThemeProvider theme, Color primaryColor) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showStickerPicker) _buildStickerPicker(theme, primaryColor),
          if (_showGifPicker) _buildGifPicker(theme, primaryColor),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.surfaceColor,
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
                _buildReplyPreview(theme, primaryColor),
                Row(
                  children: [
                    // دکمه چندرسانه‌ای
                    IconButton(
                      onPressed: () => _showMediaMenuSheet(theme, primaryColor),
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: primaryColor,
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
                            ? primaryColor
                            : theme.textSecondaryColor,
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
                                      color: primaryColor,
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
                          buildCounter: (
                            BuildContext context, {
                            required int currentLength,
                            required bool isFocused,
                            required int? maxLength,
                          }) =>
                              null,
                        ),
                      ),
                    ),

                    const SizedBox(width: 4),

                    // دکمه ارسال
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _isSending ||
                                (_messageController.text.isEmpty &&
                                    _replyToMessage == null)
                            ? Colors.grey.shade300
                            : primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: _isSending ||
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

  // ==================== App Bar ====================
  PreferredSizeWidget _buildAppBar(
    ThemeProvider theme,
    Color primaryColor,
  ) {
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
        backgroundColor: theme.surfaceColor,
        elevation: 0,
        foregroundColor: theme.textColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed:
                _selectedMessageIds.isEmpty ? null : _deleteSelectedMessages,
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
            Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: _buddyAvatar != null && _buddyAvatar!.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            _buddyAvatar!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                _buddyName?.substring(0, 1).toUpperCase() ??
                                    '?',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            _buddyName?.substring(0, 1).toUpperCase() ?? '?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
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
                    Text(
                      'در حال تایپ...',
                      style: TextStyle(
                        fontSize: 11,
                        color: primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      backgroundColor: theme.surfaceColor,
      elevation: 0,
      foregroundColor: theme.textColor,
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showHeaderMenu(theme, primaryColor),
          tooltip: 'گزینه‌های بیشتر',
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

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

  // ==================== متدهای کمکی ====================
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
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

  Future<String> _getDateLabel(DateTime date) async {
    final calendarType = await DateService.getCalendarType();

    if (calendarType == 'jalali') {
      final jalali = Jalali.fromDateTime(date);
      final now = Jalali.now();

      if (jalali.year == now.year &&
          jalali.month == now.month &&
          jalali.day == now.day) {
        return 'امروز';
      }

      final today = DateTime.now();
      final yesterdayDate = today.subtract(const Duration(days: 1));
      final jalaliYesterday = Jalali.fromDateTime(yesterdayDate);

      if (jalali.year == jalaliYesterday.year &&
          jalali.month == jalaliYesterday.month &&
          jalali.day == jalaliYesterday.day) {
        return 'دیروز';
      }

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

  String _getTimeOnly(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

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

  void _openInMap(String url) {
    final latLng = _extractLatLngFromUrl(url);

    if (latLng != null) {
      final mapUrl =
          'https://www.openstreetmap.org/?mlat=${latLng.latitude}&mlon=${latLng.longitude}&zoom=16';
      _launchUrl(mapUrl);
    } else {
      _launchUrl(url);
    }
  }

  LatLng? _extractLatLngFromUrl(String url) {
    try {
      final regExp = RegExp(r'[?&]mlat=([\d.-]+)&mlon=([\d.-]+)');
      final match = regExp.firstMatch(url);
      if (match != null) {
        final lat = double.tryParse(match.group(1) ?? '');
        final lng = double.tryParse(match.group(2) ?? '');
        if (lat != null && lng != null) {
          return LatLng(lat, lng);
        }
      }

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

  void _copyLink(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('لینک کپی شد 📋'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareLink(String url) async {
    try {
      final shareText = '''
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

  void _showLinkOptions(
    String url,
    bool isMe,
    ThemeProvider theme,
    Color primaryColor,
  ) {
    final bool isLocationLink = _isLocationLink(url);
    final String displayUrl =
        url.length > 50 ? '${url.substring(0, 50)}...' : url;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textSecondaryColor,
                    ),
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
                    color: primaryColor,
                    onTap: () {
                      Navigator.pop(context);
                      _openInMap(url);
                    },
                  ),
                _buildLinkOption(
                  icon: Icons.open_in_browser,
                  title: 'باز کردن در مرورگر',
                  subtitle: 'باز کردن لینک در مرورگر',
                  color: primaryColor,
                  onTap: () {
                    Navigator.pop(context);
                    _launchUrl(url);
                  },
                ),
                _buildLinkOption(
                  icon: Icons.copy,
                  title: 'کپی لینک',
                  subtitle: 'کپی آدرس در کلیپ‌بورد',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    _copyLink(url);
                  },
                ),
                _buildLinkOption(
                  icon: Icons.share,
                  title: 'اشتراک‌گذاری',
                  subtitle: 'ارسال لینک برای دیگران',
                  color: Colors.purple,
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

  Widget _buildLinkOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      onTap: onTap,
    );
  }

  Widget _buildLinkifiedText(
    String text,
    bool isMe,
    ThemeProvider theme,
    Color primaryColor,
  ) {
    final elements = linkify(
      text,
      options: const LinkifyOptions(humanize: false),
    );

    return Wrap(
      children: elements.map((element) {
        if (element is LinkableElement) {
          return GestureDetector(
            onTap: () =>
                _showLinkOptions(element.url, isMe, theme, primaryColor),
            child: Text(
              element.text,
              style: TextStyle(
                color: isMe ? Colors.white : primaryColor,
                fontSize: 14,
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        } else {
          return Text(
            element.text,
            style: TextStyle(
              color: isMe ? Colors.white : theme.textColor,
              fontSize: 14,
            ),
          );
        }
      }).toList(),
    );
  }
}

// ==================== Models ====================
class MediaMenuItem {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  MediaMenuItem({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });
}
