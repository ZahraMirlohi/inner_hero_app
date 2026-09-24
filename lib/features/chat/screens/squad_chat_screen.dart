// lib/features/chat/screens/squad_chat_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/services/chat_service.dart';
import '/services/buddy_matcher_service.dart';
import '/providers/sync_provider.dart';
import '/providers/theme_provider.dart';
import '../models/message_model.dart';
import '../models/conversation_model.dart';
import '../widgets/message_actions_menu.dart';

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

  // ==================== داده‌ها ====================
  List<ChatMessage> _messages = [];
  List<Map<String, dynamic>> _members = [];
  Map<String, dynamic>? _squadInfo;
  bool _isLoading = true;
  bool _isSending = false;
  String? _userId;
  ChatMessage? _replyToMessage;
  ChatMessage? _selectedMessage;

  // ==================== وضعیت‌ها ====================
  bool _showStickerPicker = false;
  bool _isAdmin = false;

  // ==================== استیکرها ====================
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
    _tabController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ==================== بارگذاری داده ====================
  Future<void> _loadData() async {
    final user = await _chatService.getCurrentUser();
    if (user != null) {
      setState(() {
        _userId = user.id;
      });

      _squadInfo = await _getSquadInfo(widget.conversation.squadId);
      _members = await _getSquadMembers(widget.conversation.id);

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
      'id': squadId,
      'name': widget.conversation.name,
      'description': 'گروه ورزش صبحگاهی',
      'max_members': 10,
      'current_members': 5,
      'weekly_challenge': '۲۰ دقیقه ورزش روزانه',
      'weekly_progress': 0.75,
      'created_at': DateTime.now(),
    };
  }

  Future<List<Map<String, dynamic>>> _getSquadMembers(
    String conversationId,
  ) async {
    return [
      {
        'user_id': 'user1',
        'name': 'علی',
        'role': 'admin',
        'is_online': true,
        'avatar': null,
      },
      {
        'user_id': 'user2',
        'name': 'سارا',
        'role': 'member',
        'is_online': true,
        'avatar': null,
      },
      {
        'user_id': 'user3',
        'name': 'رضا',
        'role': 'member',
        'is_online': false,
        'avatar': null,
      },
      {
        'user_id': 'user4',
        'name': 'مریم',
        'role': 'member',
        'is_online': true,
        'avatar': null,
      },
      {
        'user_id': 'user5',
        'name': 'حسین',
        'role': 'member',
        'is_online': false,
        'avatar': null,
      },
    ];
  }

  void _setupRealtimeSubscription() {
    _chatService.getMessages(widget.conversation.id).listen((newMessages) {
      if (mounted) {
        setState(() {
          _messages = newMessages.reversed.toList();
        });
        _scrollToBottom();
      }
    });
  }

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

  // ==================== ارسال پیام ====================
  Future<void> _sendMessage({
    String? text,
    MessageType type = MessageType.text,
    Map<String, dynamic>? metadata,
  }) async {
    final content = text ?? _messageController.text.trim();
    if (content.isEmpty || _userId == null || _isSending) return;

    _messageController.clear();
    _focusNode.unfocus();
    setState(() {
      _isSending = true;
      _replyToMessage = null;
      _showStickerPicker = false;
    });

    try {
      await _chatService.sendMessage(
        conversationId: widget.conversation.id,
        senderId: _userId!,
        content: content,
        type: type.toString().split('.').last,
        metadata: {...?metadata, 'reply_to_id': _replyToMessage?.id},
      );
    } catch (e) {
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
          _replyToMessage = null;
        });
      }
    }
  }

  // ==================== اقدامات روی پیام ====================
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
    final controller = TextEditingController(text: message.content);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('ویرایش پیام'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف پیام'),
        content: const Text('آیا از حذف این پیام برای خودتان مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                final index = _messages.indexWhere((m) => m.id == message.id);
                if (index != -1) {
                  _messages.removeAt(index);
                }
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف برای همه'),
        content: const Text('آیا از حذف این پیام برای همه مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('متن کپی شد 📋'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _toggleReaction(ChatMessage message, String emoji) {
    _chatService
        .toggleReaction(messageId: message.id, userId: _userId!, emoji: emoji)
        .then((_) {
      setState(() {});
    }).catchError((e) {
      print('❌ Error toggling reaction: $e');
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

  // ==================== ویجت‌ها ====================
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
        margin: const EdgeInsets.symmetric(vertical: 8),
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

    if (isDeleted) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'این پیام حذف شده است',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onLongPress: () => _showMessageActions(message, theme, primaryColor),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // نام فرستنده
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2, left: 4),
                  child: Text(
                    message.senderName ?? 'کاربر',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ),

              // پاسخ به پیام
              if (message.replyTo != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.1)
                        : primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
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
                          fontSize: 10,
                          color: isMe ? Colors.white70 : primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        message.replyTo!.content,
                        style: TextStyle(
                          fontSize: 12,
                          color: isMe ? Colors.white : theme.textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

              // پیام اصلی
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFF090909) : theme.surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isMe ? Colors.white : theme.textColor,
                        fontSize: 14,
                      ),
                    ),
                    if (message.showEditedBadge)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '(ویرایش شده)',
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.6)
                                : theme.textSecondaryColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // واکنش‌ها              if (message.reactions != null && message.reactions!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: message.reactions!.map((reaction) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        reaction.emoji,
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // زمان
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.textSecondaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
                      color: Colors.grey.shade100,
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
                      onPressed: () {
                        _showSquadTools(theme, primaryColor);
                      },
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
                          color: primaryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _messageController,
                          focusNode: _focusNode,
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
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          maxLines: 4,
                          minLines: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _isSending || _messageController.text.isEmpty
                            ? Colors.grey.shade300
                            : primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed:
                            (_isSending || _messageController.text.isEmpty)
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

  // ==================== تب‌ها ====================
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
                        return _buildMessageBubble(
                          message,
                          theme,
                          primaryColor,
                        );
                      },
                    ),
        ),
        _buildInputBar(theme, primaryColor),
      ],
    );
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
    final progress = info['weekly_progress'] as double? ?? 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.group,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info['name'] ?? 'گروه',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${info['current_members'] ?? 0}/${info['max_members'] ?? 10} عضو',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              color: Colors.white,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.bolt, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  info['weekly_challenge'] ?? 'چالش گروهی',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
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
        color: isMe ? primaryColor.withValues(alpha: 0.06) : theme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: isMe
            ? Border.all(color: primaryColor, width: 1.5)
            : Border.all(
                color: primaryColor.withValues(alpha: 0.1),
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
                      border: Border.all(color: Colors.white, width: 2),
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
                    if (isAdmin && !isMe) ...[
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
          if (_isAdmin && !isMe)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                size: 18,
                color: theme.textSecondaryColor,
              ),
              onSelected: (value) {
                if (value == 'make_admin') {
                  _promoteToAdmin(member['user_id']);
                } else if (value == 'remove') {
                  _removeMember(member['user_id']);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'make_admin',
                  child: Text('تبدیل به ادمین'),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Text(
                    'حذف از گروه',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
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

  // ==================== ابزارهای گروه ====================
  void _showSquadTools(ThemeProvider theme, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: theme.surfaceColor,
      builder: (context) {
        return SafeArea(
          child: Container(
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
                const SizedBox(height: 16),
                Text(
                  'ابزارهای گروه',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 16),
                if (_isAdmin) ...[
                  _buildToolItem(
                    icon: Icons.edit,
                    title: 'ویرایش اطلاعات گروه',
                    subtitle: 'تغییر نام و توضیحات',
                    onTap: () {
                      Navigator.pop(context);
                      _editSquadInfo(theme, primaryColor);
                    },
                    primaryColor: primaryColor,
                    theme: theme,
                  ),
                  const SizedBox(height: 8),
                  _buildToolItem(
                    icon: Icons.person_add,
                    title: 'دعوت به گروه',
                    subtitle: 'ارسال کد دعوت',
                    onTap: () {
                      Navigator.pop(context);
                      _showInviteDialog(theme, primaryColor);
                    },
                    primaryColor: primaryColor,
                    theme: theme,
                  ),
                  const SizedBox(height: 8),
                ],
                _buildToolItem(
                  icon: Icons.flag,
                  title: 'چالش گروهی',
                  subtitle: 'مشاهده پیشرفت چالش',
                  onTap: () {
                    Navigator.pop(context);
                    _showChallengeProgress(primaryColor);
                  },
                  primaryColor: primaryColor,
                  theme: theme,
                ),
                const SizedBox(height: 8),
                _buildToolItem(
                  icon: Icons.notifications_off,
                  title: 'بی‌صدا کردن گروه',
                  subtitle: 'غیرفعال کردن اعلان‌ها',
                  onTap: () {
                    Navigator.pop(context);
                  },
                  primaryColor: primaryColor,
                  theme: theme,
                ),
                const SizedBox(height: 8),
                if (_isAdmin)
                  _buildToolItem(
                    icon: Icons.delete_forever,
                    title: 'حذف گروه',
                    subtitle: 'حذف کامل گروه',
                    color: Colors.red,
                    onTap: () {
                      Navigator.pop(context);
                      _deleteSquad(primaryColor);
                    },
                    primaryColor: primaryColor,
                    theme: theme,
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
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

  void _editSquadInfo(ThemeProvider theme, Color primaryColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('ویرایش گروه به زودی اضافه می‌شود'),
        backgroundColor: primaryColor,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showInviteDialog(ThemeProvider theme, Color primaryColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('دعوت به گروه'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'کد دعوت گروه را با دوستان خود به اشتراک بگذارید',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textSecondaryColor),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code, size: 32, color: primaryColor),
                  const SizedBox(width: 12),
                  Text(
                    'GRP-${widget.conversation.id.substring(0, 6).toUpperCase()}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('کد دعوت کپی شد 📋'),
                  backgroundColor: primaryColor,
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 18, color: Colors.white),
            label: const Text(
              'کپی',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _promoteToAdmin(String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تبدیل به ادمین'),
        content: const Text('آیا از تبدیل این کاربر به ادمین مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                final index = _members.indexWhere(
                  (m) => m['user_id'] == userId,
                );
                if (index != -1) {
                  _members[index]['role'] = 'admin';
                }
              });
              Navigator.pop(context);
            },
            child: const Text('تأیید'),
          ),
        ],
      ),
    );
  }

  void _removeMember(String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف از گروه'),
        content: const Text('آیا از حذف این کاربر از گروه مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _members.removeWhere((m) => m['user_id'] == userId);
              });
              Navigator.pop(context);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteSquad(Color primaryColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف گروه'),
        content: const Text(
          'آیا از حذف کامل این گروه مطمئن هستید؟\n\n'
          'با حذف گروه، تمام پیام‌ها و اعضا حذف خواهند شد.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('گروه با موفقیت حذف شد'),
                  backgroundColor: primaryColor,
                ),
              );
            },
            child: const Text(
              'حذف گروه',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showChallengeProgress(Color primaryColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('پیشرفت چالش به زودی اضافه می‌شود'),
        backgroundColor: primaryColor,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // ==================== Main Build ====================
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
          // تب‌های دور گرد مشکی
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFF090909),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              labelPadding: EdgeInsets.zero,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor,
                    Color.lerp(primaryColor, Colors.black, 0.15)!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(height: 42, icon: Icon(Icons.chat, size: 16), text: 'چت'),
                Tab(
                  height: 42,
                  icon: Icon(Icons.people, size: 16),
                  text: 'اعضا',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChatTab(theme, primaryColor),
                _buildMembersTab(theme, primaryColor),
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
      title: Row(
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
      backgroundColor: theme.surfaceColor,
      elevation: 0,
      foregroundColor: theme.textColor,
      actions: [
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
