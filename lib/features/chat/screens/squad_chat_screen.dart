// lib/features/chat/screens/squad_chat_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/services/chat_service.dart';
import '/services/buddy_matcher_service.dart';
import '/providers/sync_provider.dart';
import '/providers/theme_provider.dart';
import '../models/message_model.dart';
import '../models/conversation_model.dart';
import '/services/chat_upload_service.dart';
import '../widgets/message_actions_menu.dart';
import '../widgets/file_message_widget.dart';
import '../widgets/group_rich_messages.dart';
import 'location_picker_screen.dart';

class SquadChatScreen extends StatefulWidget {
  final Conversation conversation;

  const SquadChatScreen({super.key, required this.conversation});

  @override
  State<SquadChatScreen> createState() => _SquadChatScreenState();
}

class _SquadChatScreenState extends State<SquadChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<ChatMessage> _messages = [];
  List<Map<String, dynamic>> _members = [];
  Map<String, dynamic>? _squadInfo;
  bool _isLoading = true;
  bool _isSending = false;
  String? _userId;
  ChatMessage? _replyToMessage;
  ChatMessage? _selectedMessage;

  bool _showStickerPicker = false;
  bool _isAdmin = false;
  Map<String, dynamic> _settings = {};
  String _myName = 'کاربر';
  final ValueNotifier<int> _membersRev = ValueNotifier<int>(0);
  StreamSubscription<List<ChatMessage>>? _msgSub;
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedId;
  // واکنش‌ها جدا از پیام‌ها نگهداری می‌شوند تا با هر به‌روزرسانی استریم گم نشوند
  Map<String, List<MessageReaction>> _reactions = {};
  RealtimeChannel? _reactionChannel;
  Timer? _reactionDebounce;
  ChatMessage? _menuMessage;
  Offset? _menuPosition;
  final GlobalKey _stackKey = GlobalKey();
  final List<String> _menuReactions = ['❤️', '🔥', '💪', '🎉', '😂', '😍', '🙏', '👍'];

  bool get _reactionsEnabled => _settings['reactions_enabled'] != false;
  bool get _adminsOnlyPosting => _settings['posting_mode'] == 'admins';
  bool get _canPost => !_adminsOnlyPosting || _isAdmin;

  final List<String> _popularStickers = [
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
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _setupRealtimeSubscription();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _showStickerPicker = false;
        });
        Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
      }
    });
  }

  @override
  void dispose() {
    _membersRev.dispose();
    _msgSub?.cancel();
    _reactionDebounce?.cancel();
    if (_reactionChannel != null) _chatService.client.removeChannel(_reactionChannel!);
    _tabController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = await _chatService.getCurrentUser();
    if (user != null) {
      setState(() {
        _userId = user.id;
      });

      _members = await _getSquadMembers(widget.conversation.id);
      _myName = (_members.firstWhere((m) => m['user_id'] == _userId,
                  orElse: () => {'name': 'کاربر'})['name'] as String?) ??
          'کاربر';
      try {
        _settings = await _chatService.getGroupSettings(widget.conversation.id);
      } catch (e) {
        print('group settings error: $e');
      }
      _squadInfo = await _getSquadInfo(widget.conversation.squadId);

      final isAdmin = _members.any(
        (m) => m['user_id'] == _userId && m['role'] == 'admin',
      );
      setState(() {
        _isAdmin = isAdmin;
      });

      final messages = await _chatService.getMessagesHistory(
        widget.conversation.id,
        limit: 50,
      );

      setState(() {
        _messages = messages.reversed.toList();
        _isLoading = false;
      });
      _scrollToBottom();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _getSquadInfo(String? squadId) async {
    return {
      'id': widget.conversation.id,
      'name': (_settings['name'] as String?)?.isNotEmpty == true
          ? _settings['name']
          : widget.conversation.name,
      'description': _settings['description'],
      'current_members': _members.length,
      'is_public': _settings['is_public'] == true,
    };
  }

  Future<List<Map<String, dynamic>>> _getSquadMembers(
    String conversationId,
  ) async {
    try {
      final rows = await _chatService.client
          .from('conversation_members')
          .select('user_id, role, joined_at')
          .eq('conversation_id', conversationId)
          .order('joined_at', ascending: true);
      final ids = [for (final r in rows) r['user_id'] as String];
      final profiles = ids.isEmpty
          ? []
          : await _chatService.client
              .from('profiles')
              .select('user_id, name, avatar_url, last_seen_at')
              .inFilter('user_id', ids);
      final byId = {for (final p in profiles) p['user_id'] as String: p};
      final now = DateTime.now();
      return [
        for (final r in rows)
          () {
            final pr = byId[r['user_id']];
            final seen = DateTime.tryParse('${pr?['last_seen_at'] ?? ''}');
            return <String, dynamic>{
              'user_id': r['user_id'],
              'name': (pr?['name'] as String?)?.isNotEmpty == true
                  ? pr!['name']
                  : 'کاربر',
              'role': r['role'] ?? 'member',
              'is_online':
                  seen != null && now.difference(seen.toLocal()).inMinutes < 5,
              'avatar': pr?['avatar_url'],
            };
          }(),
      ];
    } catch (e) {
      print('members load error: $e');
      return [];
    }
  }

  void _setupRealtimeSubscription() {
    _msgSub = _chatService
        .getMessages(widget.conversation.id, userId: _chatService.client.auth.currentUser?.id)
        .listen((newMessages) {
      if (mounted) {
        final grew = newMessages.length > _messages.length;
        setState(() {
          _messages = newMessages.reversed.toList();
        });
        if (grew) {
          _scrollToBottom();
          _loadReactions();
        }
      }
    });
    _loadReactions();
    // واکنش‌های بقیه‌ی اعضا به‌صورت زنده
    _reactionChannel = _chatService.client
        .channel('reactions_${widget.conversation.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'message_reactions',
          callback: (_) {
            _reactionDebounce?.cancel();
            _reactionDebounce =
                Timer(const Duration(milliseconds: 300), _loadReactions);
          },
        )
        .subscribe();
  }

  Future<void> _loadReactions() async {
    final r = await _chatService.getConversationReactions(widget.conversation.id);
    if (mounted) setState(() => _reactions = r);
  }

  List<MessageReaction> _reactionsOf(ChatMessage m) =>
      _reactions[m.id] ?? m.reactions ?? const [];

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage({
    String? text,
    MessageType type = MessageType.text,
    Map<String, dynamic>? metadata,
  }) async {
    final content = text ?? _messageController.text.trim();
    if (content.isEmpty || _userId == null || _isSending || !_canPost) return;

    final replyTo = _replyToMessage;
    final typeStr = type.toString().split('.').last;
    // پیام بلافاصله پایین لیست می‌نشیند (تا رسیدن نسخه‌ی سرور)
    final temp = ChatMessage(
      id: 'tmp_${DateTime.now().microsecondsSinceEpoch}',
      conversationId: widget.conversation.id,
      senderId: _userId!,
      senderName: _myName,
      content: content,
      type: type,
      status: MessageStatus.sending,
      metadata: metadata,
      replyToId: replyTo?.id,
      replyTo: replyTo,
      createdAt: DateTime.now(),
      isTemp: true,
    );

    _messageController.clear();
    setState(() {
      _messages.add(temp);
      _isSending = true;
      _replyToMessage = null;
      _showStickerPicker = false;
    });
    _scrollToBottom();

    try {
      await _chatService.sendMessage(
        conversationId: widget.conversation.id,
        senderId: _userId!,
        content: content,
        type: typeStr,
        metadata: metadata,
        replyToId: replyTo?.id,
        senderName: _myName,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _messages.removeWhere((m) => m.id == temp.id));
        _snack(_chatService.groupErrorText(e), error: true);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ==================== پیوست (چندتایی) ====================
  void _showAttachMenu(ThemeProvider theme, Color primaryColor) {
    Widget item(IconData icon, String title, AttachKind kind) => ListTile(
          leading: Icon(icon, color: primaryColor),
          title: Text(title),
          onTap: () {
            Navigator.pop(context);
            _sendAttachments(kind);
          },
        );
    Widget rich(IconData icon, String title, VoidCallback run) => ListTile(
          leading: Icon(icon, color: primaryColor),
          title: Text(title),
          onTap: () {
            Navigator.pop(context);
            run();
          },
        );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          item(Icons.image, 'عکس (چندتایی)', AttachKind.image),
          item(Icons.attach_file, 'فایل (چندتایی)', AttachKind.file),
          item(Icons.music_note, 'موزیک (چندتایی)', AttachKind.music),
          rich(Icons.location_on, 'موقعیت مکانی', _sendLocation),
          rich(Icons.contact_phone, 'شماره تماس', () => _sendRich(GroupRichSender.contact())),
          rich(Icons.insights, 'گزارش هفتگی', () => _sendRich(GroupRichSender.weekly(_userId!))),
          rich(Icons.show_chart, 'نمودار پیشرفت', () => _sendRich(GroupRichSender.progress(_userId!))),
          rich(Icons.checklist, 'لیست کارهای امروز', () => _sendRich(GroupRichSender.todayList(_userId!))),
          const SizedBox(height: 8),
        ])),
      ),
    );
  }

  Future<void> _sendLocation() async {
    final t = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const LocationPickerScreen()));
    if (t != null && t.isNotEmpty) _sendMessage(text: t);
  }

  Future<void> _sendRich(Future<RichPayload?> f) async {
    try {
      final p = await f;
      if (p == null) {
        _snack('داده‌ای برای ارسال وجود ندارد');
        return;
      }
      await _sendMessage(text: p.text, type: p.type, metadata: p.meta);
    } catch (e) {
      _snack('ارسال ناموفق بود', error: true);
    }
  }

  Future<void> _sendAttachments(AttachKind kind) async {
    if (_userId == null || !_canPost) return;
    final items = await ChatUploadService.pick(kind);
    if (items.isEmpty) return;
    setState(() => _isSending = true);
    var failed = 0;
    for (final a in items) {
      try {
        final url = await ChatUploadService.upload(
            a, kind == AttachKind.image ? 'chat_images' : 'chat_files');
        final isImage = kind == AttachKind.image;
        await _chatService.sendMessage(
          conversationId: widget.conversation.id,
          senderId: _userId!,
          senderName: _myName,
          content: isImage ? url : '${kind == AttachKind.music ? '🎵' : '📁'} ${a.name}',
          type: isImage ? 'image' : 'text',
          metadata: isImage
              ? {'type': 'image'}
              : {
                  'file_url': url,
                  'file_name': a.name,
                  'file_size': a.size,
                  'type': kind == AttachKind.music ? 'music' : 'file',
                },
        );
      } catch (e) {
        failed++;
        print('attachment send error: $e');
      }
    }
    if (mounted) setState(() => _isSending = false);
    if (failed > 0) _snack('ارسال $failed مورد ناموفق بود', error: true);
  }

  // ==================== جستجو و پرش دقیق ====================
  void _showSearch(ThemeProvider theme, Color primaryColor) {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('جستجو در گفتگو', style: TextStyle(color: theme.textColor)),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'متن پیام...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          TextButton(
            onPressed: () {
              final q = c.text.trim().toLowerCase();
              Navigator.pop(ctx);
              if (q.isEmpty) return;
              final res = _messages
                  .where((m) => !m.isDeleted && m.content.toLowerCase().contains(q))
                  .toList()
                  .reversed
                  .toList();
              if (res.isEmpty) {
                _snack('نتیجه‌ای یافت نشد');
              } else if (res.length == 1) {
                _jumpTo(res.first.id);
              } else {
                _showSearchResults(res, theme);
              }
            },
            child: const Text('جستجو'),
          ),
        ],
      ),
    );
  }

  void _showSearchResults(List<ChatMessage> res, ThemeProvider theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: res.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) => ListTile(
            title: Text(res[i].content, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(res[i].senderName ?? ''),
            onTap: () {
              Navigator.pop(ctx);
              _jumpTo(res[i].id);
            },
          ),
        ),
      ),
    );
  }

  // اگر ویجت پیام هنوز ساخته نشده، با تخمین ارتفاع نزدیک می‌شویم و تا ساخته‌شدن تکرار می‌کنیم
  Future<void> _jumpTo(String id, {int attempt = 0}) async {
    if (!mounted) return;
    final idx = _messages.indexWhere((m) => m.id == id);
    if (idx == -1) {
      _snack('پیام مورد نظر پیدا نشد');
      return;
    }
    if (attempt == 0) {
      setState(() => _highlightedId = id);
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _highlightedId == id) setState(() => _highlightedId = null);
      });
    }
    final ctx = _messageKeys[id]?.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          alignment: 0.5);
      return;
    }
    if (attempt >= 8 || !_scrollController.hasClients) return;
    final fromBottom = _messages.length - 1 - idx;
    final step = (attempt + 1) ~/ 2;
    final nudge = attempt == 0 ? 0.0 : (attempt.isOdd ? 1 : -1) * step * 250.0;
    final max = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo((fromBottom * 90.0 + nudge).clamp(0.0, max));
    await Future.delayed(const Duration(milliseconds: 80));
    _jumpTo(id, attempt: attempt + 1);
  }

  void _showMessageActions(
    ChatMessage message,
    ThemeProvider theme,
    Color primaryColor,
  ) {
    setState(() {
      _selectedMessage = message;
    });

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: theme.surfaceColor,
      builder: (context) {
        return SafeArea(
          child: MessageActionsMenu(
            message: message,
            onReply: () {
              Navigator.pop(context);
              _setReplyTo(message);
            },
            onEdit: () {
              Navigator.pop(context);
              _editMessage(message, primaryColor);
            },
            onDelete: () {
              Navigator.pop(context);
              _deleteMessageForMe(message);
            },
            onDeleteForEveryone: () {
              Navigator.pop(context);
              _deleteMessageForEveryone(message);
            },
            onCopy: () {
              Navigator.pop(context);
              _copyMessage(message);
            },
            onReact: (emoji) {
              Navigator.pop(context);
              _toggleReaction(message, emoji);
            },
            onForward: () {
              Navigator.pop(context);
              _forwardMessage(message);
            },
          ),
        );
      },
    );
  }

  void _setReplyTo(ChatMessage message) {
    setState(() {
      _replyToMessage = message;
    });
    _focusNode.requestFocus();
  }

  void _editMessage(ChatMessage message, Color primaryColor) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final controller = TextEditingController(text: message.content);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('ویرایش پیام', style: TextStyle(color: theme.textColor)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: theme.textColor),
          maxLines: 3,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newContent = controller.text.trim();
              if (newContent.isNotEmpty && newContent != message.content) {
                _chatService
                    .editMessage(
                        messageId: message.id,
                        userId: _userId!,
                        newContent: newContent)
                    .catchError((e) => _snack('ویرایش ناموفق بود', error: true));
                setState(() {
                  final index = _messages.indexWhere((m) => m.id == message.id);
                  if (index != -1) {
                    _messages[index] = ChatMessage(
                      id: message.id,
                      conversationId: message.conversationId,
                      senderId: message.senderId,
                      senderName: message.senderName,
                      senderAvatar: message.senderAvatar,
                      content: newContent,
                      type: message.type,
                      status: message.status,
                      metadata: message.metadata,
                      isRead: message.isRead,
                      isEdited: true,
                      isDeleted: message.isDeleted,
                      replyToId: message.replyToId,
                      replyTo: message.replyTo,
                      createdAt: message.createdAt,
                      editedAt: DateTime.now(),
                      deletedAt: message.deletedAt,
                    );
                  }
                });
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  void _deleteMessageForMe(ChatMessage message) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('حذف پیام', style: TextStyle(color: theme.textColor)),
        content: Text(
          'آیا از حذف این پیام برای خودتان مطمئن هستید؟',
          style: TextStyle(color: theme.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              _chatService
                  .deleteMessageForMe(message.id, _userId!)
                  .catchError((e) => _snack('حذف ناموفق بود', error: true));
              setState(() {
                _messages.removeWhere((m) => m.id == message.id);
              });
              Navigator.pop(context);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteMessageForEveryone(ChatMessage message) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    if (!_isAdmin && !message.isFromMe) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فقط ادمین یا فرستنده می‌تواند پیام را حذف کند'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('حذف برای همه', style: TextStyle(color: theme.textColor)),
        content: Text(
          'آیا از حذف این پیام برای همه مطمئن هستید؟',
          style: TextStyle(color: theme.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              final del = message.isFromMe
                  ? _chatService.deleteMessageForEveryone(message.id, _userId!)
                  : _chatService.adminDeleteMessage(message.id);
              del.catchError((e) => _snack('حذف ناموفق بود', error: true));
              setState(() {
                final index = _messages.indexWhere((m) => m.id == message.id);
                if (index != -1) {
                  _messages[index] = ChatMessage(
                    id: message.id,
                    conversationId: message.conversationId,
                    senderId: message.senderId,
                    senderName: message.senderName,
                    senderAvatar: message.senderAvatar,
                    content: 'این پیام توسط ادمین حذف شده است',
                    type: MessageType.system,
                    status: message.status,
                    metadata: message.metadata,
                    isRead: message.isRead,
                    isEdited: message.isEdited,
                    isDeleted: true,
                    replyToId: message.replyToId,
                    replyTo: message.replyTo,
                    createdAt: message.createdAt,
                    editedAt: message.editedAt,
                    deletedAt: DateTime.now(),
                  );
                }
              });
              Navigator.pop(context);
            },
            child: const Text(
              'حذف برای همه',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _copyMessage(ChatMessage message) {
    Clipboard.setData(ClipboardData(text: message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('متن کپی شد 📋'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _toggleReaction(ChatMessage message, String emoji) {
    if (!_reactionsEnabled) {
      _snack('ادمین واکنش‌ها را غیرفعال کرده است');
      return;
    }
    final list = List<MessageReaction>.from(_reactionsOf(message));
    final mine = list.indexWhere((r) => r.userId == _userId);
    final same = mine != -1 && list[mine].emoji == emoji;
    if (mine != -1) list.removeAt(mine);
    if (!same) {
      list.add(MessageReaction(
          userId: _userId!, emoji: emoji, userName: _myName, createdAt: DateTime.now()));
    }
    setState(() => _reactions = {..._reactions, message.id: list});
    _chatService
        .toggleReaction(messageId: message.id, userId: _userId!, emoji: emoji)
        .catchError((e) {
      _snack('ثبت واکنش ناموفق بود', error: true);
      _loadReactions();
    });
  }

  void _forwardMessage(ChatMessage message) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('اشتراک‌گذاری به زودی اضافه می‌شود'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Widget _buildReplyPreview(ThemeProvider theme, Color primaryColor) {
    if (_replyToMessage == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        border: Border(
          bottom: BorderSide(color: theme.borderColor), // ✅
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
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

  Widget _buildMessageBubble(
    ChatMessage message,
    ThemeProvider theme,
    Color primaryColor,
  ) {
    final isMe = message.isFromMe;
    final isDeleted = message.isDeleted;
    final isSystem = message.isSystem;

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          // ✅ با تم هماهنگ
          color:
              theme.isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            fontSize: 11,
            color: theme.textSecondaryColor,
          ),
        ),
      );
    }

    if (isDeleted) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            // ✅ با تم هماهنگ
            color: theme.isDarkMode
                ? const Color(0xFF2A2A2A)
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'این پیام حذف شده است',
            style: TextStyle(
              fontSize: 11,
              color: theme.textSecondaryColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    // ✅ رنگ‌های حباب
    final Color myBubbleColor =
        theme.isDarkMode ? theme.primaryColor : theme.primaryLight;
    final Color otherBubbleColor =
        theme.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    final Color bubbleColor = isMe ? myBubbleColor : otherBubbleColor;
    final Color textColor = isMe ? const Color(0xFF090909) : theme.textColor;

    return GestureDetector(
      onTapUp: (d) => _openMenu(message, d.globalPosition),
      onLongPressStart: (d) => _openMenu(message, d.globalPosition),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) _buildAvatar(message, primaryColor, theme),
            Flexible(child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2, left: 4),
                  child: Text(
                    message.senderName ?? 'کاربر',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ),
              if (message.replyTo != null)
                GestureDetector(
                  onTap: () => _jumpTo(message.replyTo!.id),
                  child: Container(
                  margin: const EdgeInsets.only(bottom: 3),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.1)
                        : primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border(
                      left: BorderSide(color: primaryColor, width: 3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'پاسخ به ${message.replyTo!.senderName ?? "کاربر"}',
                        style: TextStyle(
                          fontSize: 9,
                          color: isMe ? Colors.white70 : primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        message.replyTo!.content,
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe ? Colors.white : theme.textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _highlightedId == message.id
                      ? Color.alphaBlend(
                          const Color(0xFFFF6B00).withValues(alpha: 0.3),
                          bubbleColor)
                      : bubbleColor,
                  borderRadius: BorderRadius.circular(18),
                  border: _highlightedId == message.id
                      ? Border.all(color: const Color(0xFFFF6B00), width: 3)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                    if (_highlightedId == message.id)
                      BoxShadow(
                        color: const Color(0xFFFF6B00).withValues(alpha: 0.6),
                        blurRadius: 24,
                        spreadRadius: 5,
                      ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSquadContent(message, isMe, textColor),
                    if (message.showEditedBadge)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '(ویرایش شده)',
                          style: TextStyle(
                            fontSize: 9,
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.7)
                                : theme.textSecondaryColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _buildReactionChips(message, theme, primaryColor),
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.createdAt),
                      style: TextStyle(
                        fontSize: 9,
                        color: theme.textSecondaryColor,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      _buildStatusIcon(message.status),
                    ],
                  ],
                ),
              ),
            ],
          ),
        )),
          ],
        ),
      ),
    );
  }

  // تیک وضعیت مثل چت هم‌مسیر
  Widget _buildStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
              strokeWidth: 1.2, color: Colors.grey.shade500),
        );
      case MessageStatus.failed:
        return const Icon(Icons.error_outline, size: 14, color: Colors.red);
      case MessageStatus.seen:
        return const Icon(Icons.done_all, size: 14, color: Color(0xFF4FC3F7));
      default:
        return Icon(Icons.done_all, size: 14, color: Colors.grey.shade500);
    }
  }

  Widget _buildAvatar(ChatMessage m, Color primaryColor, ThemeProvider theme) {
    final member = _members.cast<Map<String, dynamic>?>().firstWhere(
        (x) => x?['user_id'] == m.senderId,
        orElse: () => null);
    final url = (member?['avatar'] as String?)?.isNotEmpty == true
        ? member!['avatar'] as String
        : m.senderAvatar;
    final name = m.senderName ?? 'کاربر';
    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 18),
      child: CircleAvatar(
        radius: 14,
        backgroundColor: primaryColor.withValues(alpha: 0.2),
        backgroundImage:
            (url != null && url.isNotEmpty) ? NetworkImage(url) : null,
        child: (url != null && url.isNotEmpty)
            ? null
            : Text(name.isEmpty ? '?' : name.characters.first,
                style: TextStyle(
                    fontSize: 12,
                    color: primaryColor,
                    fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ==================== منوی شناور ====================
  void _openMenu(ChatMessage m, Offset global) {
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final local = box != null ? box.globalToLocal(global) : global;
    setState(() {
      _menuMessage = m;
      _menuPosition = local;
    });
  }

  void _closeMenu() => setState(() {
        _menuMessage = null;
        _menuPosition = null;
      });

  Widget _menuItem(IconData icon, String label, VoidCallback onTap,
      ThemeProvider theme,
      {Color? color}) {
    final c = color ?? (theme.isDarkMode ? Colors.white : Colors.grey.shade800);
    return InkWell(
      onTap: () {
        _closeMenu();
        onTap();
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: c),
          ),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500, color: c)),
        ]),
      ),
    );
  }

  Widget _buildPopup(ThemeProvider theme, Color primaryColor) {
    final m = _menuMessage;
    final pos = _menuPosition;
    if (m == null || pos == null) return const SizedBox.shrink();
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final size = box?.size ?? MediaQuery.of(context).size;
    const w = 210.0;
    final own = m.isFromMe;
    final items = <Widget>[
      _menuItem(Icons.reply, 'پاسخ', () => _setReplyTo(m), theme),
      if (own && m.canBeEdited)
        _menuItem(Icons.edit, 'ویرایش', () => _editMessage(m, primaryColor), theme),
      _menuItem(Icons.copy, 'کپی', () => _copyMessage(m), theme),
      if (own)
        _menuItem(Icons.delete_outline, 'حذف برای من',
            () => _deleteMessageForMe(m), theme,
            color: Colors.red),
      if (own || _isAdmin)
        _menuItem(Icons.delete_forever, 'حذف برای همه',
            () => _deleteMessageForEveryone(m), theme,
            color: Colors.red),
    ];
    final totalH = 44 + 4 + items.length * 40 + 6.0;
    final left = (pos.dx - w / 2).clamp(8.0, (size.width - w - 8).clamp(8.0, 9999.0));
    final top = (pos.dy - totalH / 2).clamp(8.0, (size.height - totalH - 8).clamp(8.0, 9999.0));
    final shadows = [
      BoxShadow(
          color: Colors.black.withValues(alpha: theme.isDarkMode ? 0.6 : 0.2),
          blurRadius: 20,
          spreadRadius: 2,
          offset: const Offset(0, 6)),
    ];
    BoxDecoration deco() => BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: theme.isDarkMode ? theme.borderColor : Colors.grey.shade200),
          boxShadow: shadows,
        );
    final mine = _reactionsOf(m).where((r) => r.userId == _userId).map((r) => r.emoji).toSet();
    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: w,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_reactionsEnabled)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: deco(),
                child: SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final e in _menuReactions)
                        GestureDetector(
                          onTap: () {
                            _closeMenu();
                            _toggleReaction(m, e);
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            decoration: BoxDecoration(
                              color: mine.contains(e)
                                  ? primaryColor.withValues(alpha: 0.2)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: mine.contains(e)
                                  ? Border.all(color: primaryColor, width: 1.5)
                                  : null,
                            ),
                            child: Center(
                                child: Text(e, style: const TextStyle(fontSize: 20))),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: deco(),
              child: Column(mainAxisSize: MainAxisSize.min, children: items),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildReactionChips(ChatMessage m, ThemeProvider theme, Color primaryColor) {
    final list = _reactionsOf(m);
    if (list.isEmpty) return const SizedBox.shrink();
    final counts = <String, int>{};
    for (final r in list) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
    }
    final mine = list.where((r) => r.userId == _userId).map((r) => r.emoji).toSet();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        spacing: 3,
        children: [
          for (final e in counts.entries)
            GestureDetector(
              onTap: () => _toggleReaction(m, e.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  border: mine.contains(e.key)
                      ? Border.all(color: primaryColor, width: 1.5)
                      : null,
                  borderRadius: BorderRadius.circular(14),
                  color: theme.isDarkMode
                      ? Colors.black.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.9),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: theme.isDarkMode ? 0.3 : 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1)),
                  ],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(e.key, style: const TextStyle(fontSize: 15)),
                  if (e.value > 1) ...[
                    const SizedBox(width: 2),
                    Text('${e.value}',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: theme.textSecondaryColor)),
                  ],
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSquadContent(ChatMessage m, bool isMe, Color textColor) {
    final rich = GroupRichContent.build(
        context, m, isMe, Provider.of<ThemeProvider>(context, listen: false));
    if (rich != null) return rich;
    final md = m.metadata;
    if (md != null && md['file_url'] != null) {
      var t = md['type'] as String? ?? 'file';
      if (t == 'music') t = 'audio';
      return FileMessageWidget(
        key: ValueKey('f_${m.id}'),
        fileUrl: md['file_url'] as String,
        fileName: md['file_name'] as String? ?? 'فایل',
        fileType: t,
        fileSize: (md['file_size'] as num?)?.toInt() ?? 0,
        isMe: isMe,
      );
    }
    if (m.type == MessageType.image) {
      return GestureDetector(
        onTap: () => showDialog(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.black,
            insetPadding: EdgeInsets.zero,
            child: InteractiveViewer(child: Image.network(m.content)),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            m.content,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
          ),
        ),
      );
    }
    return Text(
      m.content,
      style: TextStyle(color: textColor, fontSize: 13, height: 1.4),
    );
  }

  Widget _buildStickerPicker(ThemeProvider theme) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
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
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                childAspectRatio: 1,
              ),
              itemCount: _popularStickers.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    _sendMessage(
                      text: _popularStickers[index],
                      type: MessageType.sticker,
                    );
                    setState(() {
                      _showStickerPicker = false;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      // ✅ با تم هماهنگ
                      color: theme.isDarkMode
                          ? const Color(0xFF2A2A2A)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _popularStickers[index],
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

  Widget _buildInputBar(ThemeProvider theme, Color primaryColor) {
    if (!_canPost) {
      return SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: theme.surfaceColor,
          child: Text('فقط ادمین‌های گروه می‌توانند پیام بفرستند',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textSecondaryColor, fontSize: 13)),
        ),
      );
    }
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showStickerPicker) _buildStickerPicker(theme),
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
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _showStickerPicker = !_showStickerPicker;
                        });
                      },
                      icon: Icon(
                        _showStickerPicker
                            ? Icons.keyboard
                            : Icons.emoji_emotions_outlined,
                        color: _showStickerPicker
                            ? primaryColor
                            : theme.textSecondaryColor,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: _isSending
                          ? null
                          : () => _showAttachMenu(theme, primaryColor),
                      icon: Icon(
                        Icons.attach_file,
                        color: theme.textSecondaryColor,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          // ✅ ورودی متن با تم هماهنگ
                          color: theme.isDarkMode
                              ? const Color(0xFF2A2A2A)
                              : primaryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _messageController,
                          focusNode: _focusNode,
                          style: TextStyle(color: theme.textColor),
                          decoration: InputDecoration(
                            hintText: 'پیام خود را بنویسید...',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: theme.textSecondaryColor,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          textInputAction: TextInputAction.newline,
                          keyboardType: TextInputType.multiline,
                          maxLines: 4,
                          minLines: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _messageController,
                      builder: (context, value, _) {
                        final empty = value.text.trim().isEmpty;
                        return Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _isSending || empty
                            ? (theme.isDarkMode
                                ? const Color(0xFF2A2A2A)
                                : Colors.grey.shade300)
                            : primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed:
                            (_isSending || empty)
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
                    );
                      },
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

  Widget _buildChatTab(ThemeProvider theme, Color primaryColor) {
    return Column(
      children: [
        _buildReplyPreview(theme, primaryColor),
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: primaryColor),
                )
              : _messages.isEmpty
                  ? _buildEmptyState(theme, primaryColor)
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[_messages.length - 1 - index];
                        return KeyedSubtree(
                          key: _messageKeys.putIfAbsent(
                              message.id, () => GlobalKey()),
                          child: _buildMessageBubble(
                            message,
                            theme,
                            primaryColor,
                          ),
                        );
                      },
                    ),
        ),
        _buildInputBar(theme, primaryColor),
      ],
    );
  }

  // با کلیک روی سربرگ: صفحه‌ی اعضا
  void _openMembersPage(ThemeProvider theme, Color primaryColor) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: theme.backgroundColor,
          appBar: AppBar(
            title: const Text('اعضای گروه'),
            backgroundColor: theme.surfaceColor,
            elevation: 0,
            foregroundColor: theme.textColor,
          ),
          body: ValueListenableBuilder<int>(
            valueListenable: _membersRev,
            builder: (_, __, ___) => _buildMembersTab(theme, primaryColor),
          ),
        ),
      ),
    );
  }

  Future<void> _addFromBuddies(ThemeProvider theme, Color primaryColor) async {
    List<Map<String, dynamic>> buddies;
    try {
      buddies = await _chatService.getMyBuddies();
    } catch (e) {
      _snack('خواندن هم‌مسیرها ناموفق بود', error: true);
      return;
    }
    final existing = {for (final m in _members) m['user_id']};
    buddies = buddies.where((b) => !existing.contains(b['user_id'])).toList();
    if (!mounted) return;
    if (buddies.isEmpty) {
      _snack('هم‌مسیری برای افزودن نمانده است');
      return;
    }
    final picked = <String>{};
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.7,
            child: Column(children: [
              const SizedBox(height: 16),
              Text('افزودن از هم‌مسیرهای من',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: theme.textColor)),
              Expanded(
                child: ListView(
                  children: [
                    for (final b in buddies)
                      CheckboxListTile(
                        value: picked.contains(b['user_id']),
                        onChanged: (v) => setS(() => v == true
                            ? picked.add(b['user_id'] as String)
                            : picked.remove(b['user_id'])),
                        secondary: CircleAvatar(
                          backgroundImage: (b['avatar_url'] as String?)?.isNotEmpty == true
                              ? NetworkImage(b['avatar_url'] as String)
                              : null,
                          child: (b['avatar_url'] as String?)?.isNotEmpty == true
                              ? null
                              : Text(((b['name'] as String?) ?? '؟').characters.first),
                        ),
                        title: Text((b['name'] as String?) ?? 'کاربر'),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: picked.isEmpty ? null : () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('افزودن ${picked.length} نفر',
                        style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    if (ok != true || picked.isEmpty) return;
    await _run(() async {
      await _chatService.addGroupMembers(widget.conversation.id, picked.toList());
    }, ok: 'اعضا اضافه شدند');
  }

  Widget _buildMembersTab(ThemeProvider theme, Color primaryColor) {
    return Column(
      children: [
        _buildSquadInfoCard(theme, primaryColor),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _members.length,
            itemBuilder: (context, index) {
              final member = _members[index];
              final isMe = member['user_id'] == _userId;
              return _buildMemberItem(
                member,
                isMe,
                theme,
                primaryColor,
              );
            },
          ),
        ),
        if (_isAdmin)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _addFromBuddies(theme, primaryColor),
                icon: const Icon(Icons.group_add, color: Colors.white),
                label: const Text('افزودن از هم‌مسیرهای من',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        if (_isAdmin)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _showInviteDialog(theme, primaryColor);
                },
                icon: const Icon(Icons.person_add, color: Colors.white),
                label: const Text(
                  'دعوت به گروه',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSquadInfoCard(ThemeProvider theme, Color primaryColor) {
    if (_squadInfo == null) return const SizedBox.shrink();
    final info = _squadInfo!;
    final desc = (info['description'] as String?) ?? '';

    Widget badge(IconData icon, String t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 4),
            Text(t,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ]),
        );

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.group, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(info['name'] ?? 'گروه',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ]),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(desc,
                style: TextStyle(
                    fontSize: 12,
                    height: 1.7,
                    color: Colors.white.withValues(alpha: 0.9))),
          ],
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            badge(Icons.people_alt_rounded, '${info['current_members'] ?? 0} عضو'),
            badge(
                info['is_public'] == true
                    ? Icons.public_rounded
                    : Icons.lock_rounded,
                info['is_public'] == true ? 'عمومی' : 'خصوصی'),
            if (!_reactionsEnabled)
              badge(Icons.sentiment_dissatisfied_rounded, 'واکنش‌ها خاموش'),
            if (_adminsOnlyPosting) badge(Icons.campaign_rounded, 'فقط ادمین‌ها'),
          ]),
        ],
      ),
    );
  }

  Widget _buildMemberItem(
    Map<String, dynamic> member,
    bool isMe,
    ThemeProvider theme,
    Color primaryColor,
  ) {
    final isOnline = member['is_online'] ?? false;
    final isAdmin = member['role'] == 'admin';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color:
            isMe ? primaryColor.withValues(alpha: 0.06) : theme.cardColor, // ✅
        borderRadius: BorderRadius.circular(18),
        border: isMe
            ? Border.all(color: primaryColor, width: 1.5)
            : Border.all(
                color: theme.borderColor, // ✅
                width: 1,
              ),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  color: primaryColor,
                  size: 22,
                ),
              ),
              if (isOnline)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.cardColor, width: 2),
                    ),
                  ),
                ),
            ],
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
                        member['name'] ?? 'کاربر',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isMe ? FontWeight.w700 : FontWeight.w600,
                          color: isMe ? primaryColor : theme.textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'من',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (isAdmin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'ادمین',
                          style: TextStyle(
                            fontSize: 8,
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isOnline ? 'آنلاین 🟢' : 'آفلاین',
                  style: TextStyle(
                    fontSize: 11,
                    color: isOnline ? primaryColor : theme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          if (!isMe)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                size: 18,
                color: theme.textSecondaryColor,
              ),
              onSelected: (value) {
                final id = member['user_id'] as String;
                if (value == 'make_admin') {
                  _setRole(id, 'admin');
                } else if (value == 'remove_admin') {
                  _setRole(id, 'member');
                } else if (value == 'remove') {
                  _removeMember(id, ban: false);
                } else if (value == 'ban') {
                  _removeMember(id, ban: true);
                } else if (value == 'report') {
                  _reportMember(id, member['name'] ?? 'کاربر');
                }
              },
              itemBuilder: (context) => [
                if (_isAdmin && !isAdmin)
                  const PopupMenuItem(
                      value: 'make_admin', child: Text('تبدیل به ادمین')),
                if (_isAdmin && isAdmin)
                  const PopupMenuItem(
                      value: 'remove_admin', child: Text('برداشتن ادمینی')),
                if (_isAdmin)
                  const PopupMenuItem(
                      value: 'remove',
                      child: Text('حذف از گروه',
                          style: TextStyle(color: Colors.red))),
                if (_isAdmin)
                  const PopupMenuItem(
                      value: 'ban',
                      child: Text('حذف و مسدود کردن',
                          style: TextStyle(color: Colors.red))),
                const PopupMenuItem(value: 'report', child: Text('گزارش عضو')),
              ],
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.group_add,
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
            'با اعضای گروه پیام دهید',
            style: TextStyle(
              fontSize: 13,
              color: theme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : null,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _reloadGroup() async {
    final members = await _getSquadMembers(widget.conversation.id);
    try {
      _settings = await _chatService.getGroupSettings(widget.conversation.id);
    } catch (_) {}
    _members = members;
    final info = await _getSquadInfo(widget.conversation.squadId);
    if (!mounted) return;
    setState(() {
      _squadInfo = info;
      _isAdmin =
          members.any((m) => m['user_id'] == _userId && m['role'] == 'admin');
    });
    _membersRev.value++;
  }

  Future<void> _run(Future<void> Function() action, {String? ok}) async {
    try {
      await action();
      await _reloadGroup();
      if (ok != null) _snack(ok);
    } catch (e) {
      _snack(_chatService.groupErrorText(e), error: true);
    }
  }

  Future<bool> _confirm(String title, String body, String yes,
      {bool danger = false}) async {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(title, style: TextStyle(color: theme.textColor)),
        content: Text(body,
            style: TextStyle(color: theme.textSecondaryColor, height: 1.7)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text(yes, style: TextStyle(color: danger ? Colors.red : null)),
          ),
        ],
      ),
    );
    return r == true;
  }

  void _showSquadTools(ThemeProvider theme, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      backgroundColor: theme.surfaceColor,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Widget switchTile(IconData icon, String title, String sub, bool v,
              Future<void> Function(bool) onChanged) {
            return SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(icon, color: primaryColor),
              title: Text(title,
                  style: TextStyle(
                      color: theme.textColor, fontWeight: FontWeight.w600)),
              subtitle: Text(sub,
                  style: TextStyle(
                      color: theme.textSecondaryColor, fontSize: 12)),
              value: v,
              onChanged: (nv) async {
                await onChanged(nv);
                setSheet(() {});
              },
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.borderColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('ابزارهای گروه',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: theme.textColor)),
                  const SizedBox(height: 10),
                  if (_isAdmin) ...[
                    _buildToolItem(
                      icon: Icons.edit,
                      title: 'ویرایش اطلاعات گروه',
                      subtitle: 'تغییر نام و توضیحات',
                      onTap: () {
                        Navigator.pop(ctx);
                        _editSquadInfo(theme, primaryColor);
                      },
                      primaryColor: primaryColor,
                      theme: theme,
                    ),
                    const SizedBox(height: 8),
                    _buildToolItem(
                      icon: Icons.person_add,
                      title: 'دعوت به گروه',
                      subtitle: 'کد دعوت',
                      onTap: () {
                        Navigator.pop(ctx);
                        _showInviteDialog(theme, primaryColor);
                      },
                      primaryColor: primaryColor,
                      theme: theme,
                    ),
                    const Divider(height: 24),
                    switchTile(
                      Icons.public_rounded,
                      'گروه عمومی',
                      'همه می‌توانند گروه را پیدا کنند و بپیوندند',
                      _settings['is_public'] == true,
                      (v) => _run(() => _chatService
                          .updateGroup(widget.conversation.id, isPublic: v)),
                    ),
                    switchTile(
                      Icons.emoji_emotions_rounded,
                      'واکنش با استیکر',
                      'اعضا بتوانند به پیام‌ها واکنش بدهند',
                      _reactionsEnabled,
                      (v) => _run(() => _chatService.updateGroup(
                          widget.conversation.id,
                          reactionsEnabled: v)),
                    ),
                    switchTile(
                      Icons.campaign_rounded,
                      'فقط ادمین‌ها پیام بدهند',
                      'اعضا فقط می‌خوانند (حالت کانال)',
                      _adminsOnlyPosting,
                      (v) => _run(() => _chatService.updateGroup(
                          widget.conversation.id,
                          postingMode: v ? 'admins' : 'all')),
                    ),
                    const Divider(height: 24),
                  ],
                  _buildToolItem(
                    icon: Icons.notifications_off,
                    title: 'بی‌صدا کردن گروه',
                    subtitle: 'غیرفعال کردن اعلان‌ها',
                    onTap: () async {
                      Navigator.pop(ctx);
                      try {
                        await _chatService.setGroupMuted(
                            widget.conversation.id, true);
                        _snack('گروه بی‌صدا شد');
                      } catch (e) {
                        _snack(_chatService.groupErrorText(e), error: true);
                      }
                    },
                    primaryColor: primaryColor,
                    theme: theme,
                  ),
                  const SizedBox(height: 8),
                  _buildToolItem(
                    icon: Icons.exit_to_app,
                    title: 'ترک گروه',
                    subtitle: 'از این گروه خارج می‌شوید',
                    color: Colors.red,
                    onTap: () {
                      Navigator.pop(ctx);
                      _leaveSquad();
                    },
                    primaryColor: primaryColor,
                    theme: theme,
                  ),
                  if (_isAdmin) ...[
                    const SizedBox(height: 8),
                    _buildToolItem(
                      icon: Icons.delete_forever,
                      title: 'حذف گروه',
                      subtitle: 'حذف کامل گروه برای همه',
                      color: Colors.red,
                      onTap: () {
                        Navigator.pop(ctx);
                        _deleteSquad(primaryColor);
                      },
                      primaryColor: primaryColor,
                      theme: theme,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color primaryColor,
    required ThemeProvider theme,
    Color? color,
  }) {
    final finalColor = color ?? primaryColor;

    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: finalColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: finalColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color ?? theme.textColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: theme.textSecondaryColor,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.textSecondaryColor,
      ),
      onTap: onTap,
    );
  }

  void _showInviteDialog(ThemeProvider theme, Color primaryColor) async {
    String? code = _settings['invite_code'] as String?;
    if (code == null || code.isEmpty) {
      try {
        code = await _chatService.regenerateInviteCode(widget.conversation.id);
        _settings['invite_code'] = code;
      } catch (e) {
        _snack(_chatService.groupErrorText(e), error: true);
        return;
      }
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: theme.cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text('دعوت به گروه', style: TextStyle(color: theme.textColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'این کد را برای دوستانت بفرست. با «پیوستن به گروه» وارد می‌شوند.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: theme.textSecondaryColor, height: 1.7)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SelectableText(
                  code!,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                      color: primaryColor),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  final c = await _chatService
                      .regenerateInviteCode(widget.conversation.id);
                  _settings['invite_code'] = c;
                  setD(() => code = c);
                } catch (e) {
                  _snack(_chatService.groupErrorText(e), error: true);
                }
              },
              child: const Text('کد جدید'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code!));
                if (ctx.mounted) Navigator.pop(ctx);
                _snack('کد دعوت کپی شد');
              },
              icon: const Icon(Icons.copy, size: 18, color: Colors.white),
              label: const Text('کپی', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editSquadInfo(ThemeProvider theme, Color primaryColor) {
    final nameC = TextEditingController(text: _squadInfo?['name'] ?? '');
    final descC = TextEditingController(text: _squadInfo?['description'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('ویرایش گروه', style: TextStyle(color: theme.textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameC,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'نام گروه'),
            ),
            TextField(
              controller: descC,
              maxLength: 200,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'توضیحات'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('انصراف')),
          TextButton(
            onPressed: () {
              final n = nameC.text.trim();
              if (n.isEmpty) return;
              Navigator.pop(ctx);
              _run(
                () => _chatService.updateGroup(widget.conversation.id,
                    name: n, description: descC.text.trim()),
                ok: 'اطلاعات گروه ذخیره شد',
              );
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  Future<void> _setRole(String userId, String role) async {
    final ok = await _confirm(
      role == 'admin' ? 'تبدیل به ادمین' : 'برداشتن ادمینی',
      role == 'admin'
          ? 'این کاربر می‌تواند گروه را مدیریت کند.'
          : 'این کاربر دیگر ادمین نخواهد بود.',
      'تأیید',
    );
    if (!ok) return;
    await _run(
        () => _chatService.setMemberRole(widget.conversation.id, userId, role));
  }

  Future<void> _removeMember(String userId, {bool ban = false}) async {
    final ok = await _confirm(
      ban ? 'حذف و مسدود کردن' : 'حذف از گروه',
      ban
          ? 'کاربر حذف می‌شود و دیگر نمی‌تواند دوباره به گروه بپیوندد.'
          : 'آیا از حذف این کاربر از گروه مطمئن هستید؟',
      'حذف',
      danger: true,
    );
    if (!ok) return;
    await _run(
      () => _chatService.removeGroupMember(widget.conversation.id, userId,
          ban: ban),
      ok: 'کاربر حذف شد',
    );
  }

  Future<void> _reportMember(String userId, String name) async {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    const reasons = [
      'پیام آزاردهنده',
      'اسپم یا تبلیغات',
      'محتوای نامناسب',
      'سایر'
    ];
    String reason = reasons.first;
    final detailsC = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: theme.cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title:
              Text('گزارش «$name»', style: TextStyle(color: theme.textColor)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final r in reasons)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(r),
                    value: r,
                    groupValue: reason,
                    onChanged: (v) => setD(() => reason = v ?? reason),
                  ),
                TextField(
                  controller: detailsC,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'توضیح (اختیاری)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('انصراف')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('ارسال گزارش')),
          ],
        ),
      ),
    );
    if (send != true) return;
    try {
      await _chatService.reportMember(widget.conversation.id, userId, reason,
          details: detailsC.text.trim().isEmpty ? null : detailsC.text.trim());
      _snack('گزارش ثبت شد، ممنون');
    } catch (e) {
      _snack(_chatService.groupErrorText(e), error: true);
    }
  }

  Future<void> _leaveSquad() async {
    final ok = await _confirm(
        'ترک گروه', 'آیا از خروج از این گروه مطمئن هستید؟', 'ترک گروه',
        danger: true);
    if (!ok) return;
    try {
      await _chatService.leaveGroup(widget.conversation.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _snack(_chatService.groupErrorText(e), error: true);
    }
  }

  Future<void> _deleteSquad(Color primaryColor) async {
    final ok = await _confirm(
      'حذف گروه',
      'با حذف گروه، تمام پیام‌ها و اعضا برای همه حذف می‌شوند و قابل بازگشت نیست.',
      'حذف گروه',
      danger: true,
    );
    if (!ok) return;
    try {
      await _chatService.deleteGroup(widget.conversation.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _snack(_chatService.groupErrorText(e), error: true);
    }
  }

  void _showChallengeProgress(Color primaryColor) {
    _snack('پیشرفت چالش گروهی به‌زودی');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(theme, primaryColor),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              key: _stackKey,
              children: [
                _buildChatTab(theme, primaryColor),
                if (_menuMessage != null)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _closeMenu,
                      child: const SizedBox.expand(),
                    ),
                  ),
                _buildPopup(theme, primaryColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    ThemeProvider theme,
    Color primaryColor,
  ) {
    final memberCount = _members.length;

    return AppBar(
      title: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openMembersPage(theme, primaryColor),
        child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.group,
              color: primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.conversation.displayName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.textColor,
                ),
              ),
              Text(
                '$memberCount عضو',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
      ),
      backgroundColor: theme.surfaceColor,
      elevation: 0,
      foregroundColor: theme.textColor,
      actions: [
        IconButton(
          icon: Icon(Icons.search, color: theme.textColor),
          onPressed: () => _showSearch(theme, primaryColor),
        ),
        IconButton(
          icon: Icon(Icons.more_vert, color: theme.textColor),
          onPressed: () => _showSquadTools(theme, primaryColor),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays > 0) {
      return '${diff.inDays} روز پیش';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} ساعت پیش';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} دقیقه پیش';
    } else {
      return 'لحظاتی پیش';
    }
  }
}
