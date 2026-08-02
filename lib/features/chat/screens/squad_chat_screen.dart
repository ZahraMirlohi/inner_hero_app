// lib/features/chat/screens/squad_chat_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/services/chat_service.dart';
import '/services/buddy_matcher_service.dart';
import '/providers/sync_provider.dart';
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

  // ==================== گروه‌های پیشنهادی ====================
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

      // دریافت اطلاعات گروه
      _squadInfo = await _getSquadInfo(widget.conversation.squadId);

      // دریافت اعضا
      _members = await _getSquadMembers(widget.conversation.id);

      // بررسی نقش کاربر
      final isAdmin = _members.any(
        (m) => m['user_id'] == _userId && m['role'] == 'admin',
      );
      setState(() {
        _isAdmin = isAdmin;
      });

      // دریافت تاریخچه پیام‌ها
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
    // در واقعیت از دیتابیس دریافت می‌شود
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
    // در واقعیت از دیتابیس دریافت می‌شود
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

  void _showMessageActions(ChatMessage message) {
    setState(() {
      _selectedMessage = message;
    });

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
              _editMessage(message);
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

  void _editMessage(ChatMessage message) {
    final controller = TextEditingController(text: message.content);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ویرایش پیام'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
              backgroundColor: const Color(0xFF9B59B6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    // فقط ادمین یا خود فرستنده می‌تواند حذف کند
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    // ✅ این متد باید از chat_service استفاده کند
    _chatService
        .toggleReaction(messageId: message.id, userId: _userId!, emoji: emoji)
        .then((_) {
          // به‌روزرسانی UI بعد از تغییر واکنش
          setState(() {});
        })
        .catchError((e) {
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

  Widget _buildMessageBubble(ChatMessage message) {
    final isMe = message.isFromMe;
    final isDeleted = message.isDeleted;
    final isSystem = message.isSystem;

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
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

    if (message.isDeleted) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
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
      onLongPress: () => _showMessageActions(message),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              // نام فرستنده (برای پیام‌های دیگران)
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2, left: 4),
                  child: Text(
                    message.senderName ?? 'کاربر',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF9B59B6),
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
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'پاسخ به ${message.replyTo!.senderName ?? "کاربر"}',
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.7)
                              : Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        message.replyTo!.content,
                        style: TextStyle(
                          fontSize: 12,
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.8)
                              : Colors.grey.shade700,
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
                  color: isMe ? const Color(0xFF9B59B6) : Colors.white,
                  borderRadius: BorderRadius.circular(16).copyWith(
                    bottomRight: isMe
                        ? const Radius.circular(4)
                        : const Radius.circular(16),
                    bottomLeft: isMe
                        ? const Radius.circular(16)
                        : const Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isMe ? Colors.white : const Color(0xFF1A1A2E),
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
                                : Colors.grey.shade500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // واکنش‌ها
              if (message.reactions != null && message.reactions!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: message.reactions!.map((reaction) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: Text(
                          reaction.emoji, // ✅ استفاده از reaction.emoji
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
                    color: isMe ? Colors.purple.shade100 : Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ),
        ),
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
                      borderRadius: BorderRadius.circular(8),
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

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showStickerPicker) _buildStickerPicker(),

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
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showStickerPicker = !_showStickerPicker;
                    });
                  },
                  icon: const Icon(Icons.emoji_emotions_outlined),
                  color: Colors.grey.shade600,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),

                IconButton(
                  onPressed: () {
                    _showSquadTools();
                  },
                  icon: const Icon(Icons.attach_file),
                  color: Colors.grey.shade600,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),

                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: 'پیام خود را بنویسید...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
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
                        : const Color(0xFF9B59B6),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: (_isSending || _messageController.text.isEmpty)
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
                        : const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== تب‌ها ====================

  Widget _buildChatTab() {
    return Column(
      children: [
        _buildReplyPreview(),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF9B59B6)),
                )
              : _messages.isEmpty
              ? _buildEmptyState()
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
                    return _buildMessageBubble(message);
                  },
                ),
        ),
        _buildInputBar(),
      ],
    );
  }

  Widget _buildMembersTab() {
    return Column(
      children: [
        // اطلاعات گروه
        _buildSquadInfoCard(),
        const SizedBox(height: 12),

        // لیست اعضا
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _members.length,
            itemBuilder: (context, index) {
              final member = _members[index];
              final isMe = member['user_id'] == _userId;
              return _buildMemberItem(member, isMe);
            },
          ),
        ),

        // دکمه دعوت
        if (_isAdmin)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _showInviteDialog();
                },
                icon: const Icon(Icons.person_add),
                label: const Text('دعوت به گروه'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9B59B6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSquadInfoCard() {
    if (_squadInfo == null) return const SizedBox.shrink();

    final info = _squadInfo!;
    final progress = info['weekly_progress'] as double? ?? 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF9B59B6), const Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.group, color: Colors.white, size: 24),
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
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
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
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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

  Widget _buildMemberItem(Map<String, dynamic> member, bool isMe) {
    final isOnline = member['is_online'] ?? false;
    final isAdmin = member['role'] == 'admin';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? Colors.purple.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isMe
            ? Border.all(color: const Color(0xFF9B59B6), width: 1.5)
            : Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isOnline
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.grey.shade200,
                child: Icon(
                  Icons.person,
                  color: isOnline ? Colors.green : Colors.grey.shade400,
                ),
              ),
              if (isOnline)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                        BorderSide(color: Colors.white, width: 2),
                      ),
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
                    Text(
                      member['name'] ?? 'کاربر',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isMe ? FontWeight.w700 : FontWeight.w600,
                        color: isMe
                            ? const Color(0xFF9B59B6)
                            : const Color(0xFF1A1A2E),
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
                          color: const Color(0xFF9B59B6),
                          borderRadius: BorderRadius.circular(8),
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
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'ادمین',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.white,
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
                    color: isOnline ? Colors.green : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          if (_isAdmin && !isMe)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF9B59B6).withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.group_add,
              size: 48,
              color: Color(0xFF9B59B6),
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
            'با اعضای گروه پیام دهید',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ==================== ابزارهای گروه ====================

  void _showSquadTools() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                const Text(
                  'ابزارهای گروه',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (_isAdmin) ...[
                  _buildToolItem(
                    icon: Icons.edit,
                    title: 'ویرایش اطلاعات گروه',
                    subtitle: 'تغییر نام و توضیحات',
                    onTap: () {
                      Navigator.pop(context);
                      _editSquadInfo();
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildToolItem(
                    icon: Icons.person_add,
                    title: 'دعوت به گروه',
                    subtitle: 'ارسال کد دعوت',
                    onTap: () {
                      Navigator.pop(context);
                      _showInviteDialog();
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                _buildToolItem(
                  icon: Icons.flag,
                  title: 'چالش گروهی',
                  subtitle: 'مشاهده پیشرفت چالش',
                  onTap: () {
                    Navigator.pop(context);
                    _showChallengeProgress();
                  },
                ),
                const SizedBox(height: 8),
                _buildToolItem(
                  icon: Icons.notifications_off,
                  title: 'بی‌صدا کردن گروه',
                  subtitle: 'غیرفعال کردن اعلان‌ها',
                  onTap: () {
                    Navigator.pop(context);
                  },
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
                      _deleteSquad();
                    },
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
    Color? color,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (color ?? const Color(0xFF9B59B6)).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color ?? const Color(0xFF9B59B6), size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color ?? const Color(0xFF1A1A2E),
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _editSquadInfo() {
    // TODO: ویرایش اطلاعات گروه
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ویرایش گروه به زودی اضافه می‌شود'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _showInviteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('دعوت به گروه'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'کد دعوت گروه را با دوستان خود به اشتراک بگذارید',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code, size: 32),
                  const SizedBox(width: 12),
                  Text(
                    'GRP-${widget.conversation.id.substring(0, 6).toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
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
              // کپی کد
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('کد دعوت کپی شد 📋'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('کپی'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9B59B6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('کاربر به ادمین تبدیل شد'),
                  backgroundColor: Colors.green,
                ),
              );
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('کاربر از گروه حذف شد'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteSquad() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                const SnackBar(
                  content: Text('گروه با موفقیت حذف شد'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text('حذف گروه', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showChallengeProgress() {
    // TODO: نمایش پیشرفت چالش گروهی
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('پیشرفت چالش به زودی اضافه می‌شود'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // ==================== Main Build ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // تب‌ها
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF9B59B6),
              indicatorWeight: 3,
              labelColor: const Color(0xFF9B59B6),
              unselectedLabelColor: Colors.grey.shade500,
              tabs: const [
                Tab(icon: Icon(Icons.chat), text: 'چت'),
                Tab(icon: Icon(Icons.people), text: 'اعضا'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildChatTab(), _buildMembersTab()],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final memberCount = _members.length;

    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF9B59B6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.group, color: Color(0xFF9B59B6), size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.conversation.displayName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$memberCount عضو',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      foregroundColor: const Color(0xFF1A1A2E),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: _showSquadTools,
        ),
      ],
    );
  }

  // ==================== متدهای کمکی ====================

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
