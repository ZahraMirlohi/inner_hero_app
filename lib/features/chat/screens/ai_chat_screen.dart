// lib/features/chat/screens/ai_chat_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/services/chat_service.dart';
import '/services/ai_service.dart';
import '/providers/sync_provider.dart';
import '/providers/theme_provider.dart';
import '/features/chat/models/message_model.dart';
import '/features/chat/models/conversation_model.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen>
    with SingleTickerProviderStateMixin {
  late ChatService _chatService;
  late AIService _aiService;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isTyping = false;
  String? _conversationId;
  String? _userId;

  // پیشنهادات سریع
  final List<String> _quickSuggestions = [
    'چطور می‌تونم امروز بهتر باشم؟',
    'به من انگیزه بده 🚀',
    'برنامه امروز من چیه؟',
    'چطور استریکم رو حفظ کنم؟',
    'برای فردا برنامه‌ریزی کن',
  ];

  @override
  void initState() {
    super.initState();
    _chatService = ChatService();
    _aiService = AIService();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
      }
    });

    _initChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);
    final user = await _chatService.getCurrentUser();

    if (user != null && mounted) {
      setState(() {
        _userId = user.id;
      });

      final conversations = await _chatService.getUserConversations(user.id);
      final aiConversation = conversations.firstWhere(
        (c) => c.type == ConversationType.ai,
        orElse: () => Conversation(
          id: '',
          type: ConversationType.ai,
          lastMessageAt: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      );

      if (aiConversation.id.isNotEmpty) {
        _conversationId = aiConversation.id;
        await _loadMessages();
      } else {
        _conversationId = await _chatService.createConversation(
          type: 'ai',
          memberIds: [user.id],
          name: 'مربی هوش مصنوعی',
          createdBy: user.id,
        );

        final welcomeMessage = await _aiService.getWelcomeMessage(
          user.id,
          syncProvider.habits,
          syncProvider.profile,
        );

        await _chatService.sendMessage(
          conversationId: _conversationId!,
          senderId: 'ai',
          content: welcomeMessage,
          type: 'ai',
        );

        await _loadMessages();
      }
    }
  }

  Future<void> _loadMessages() async {
    if (_conversationId == null || !mounted) return;

    final messages = await _chatService.getMessagesHistory(_conversationId!);
    if (mounted) {
      setState(() {
        _messages = messages.reversed.toList();
      });
    }
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _conversationId == null || _userId == null) return;

    _messageController.clear();
    _focusNode.unfocus();

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    // ذخیره پیام کاربر
    await _chatService.sendMessage(
      conversationId: _conversationId!,
      senderId: _userId!,
      content: text,
    );

    // دریافت پاسخ از AI
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);
    final response = await _aiService.getResponse(
      userId: _userId!,
      message: text,
      habits: syncProvider.habits,
      profile: syncProvider.profile,
    );

    // ذخیره پاسخ AI
    await _chatService.sendMessage(
      conversationId: _conversationId!,
      senderId: 'ai',
      content: response,
      type: 'ai',
    );

    await _loadMessages();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
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

  void _sendSuggestion(String suggestion) {
    _messageController.text = suggestion;
    _sendMessage();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('🤖', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'مربی هوش مصنوعی',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.textColor,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'آنلاین',
                      style: TextStyle(
                        fontSize: 11,
                        color: primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
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
            icon: Icon(Icons.refresh, size: 20, color: primaryColor),
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick Suggestions
          _buildQuickSuggestions(theme, primaryColor),

          // Messages
          Expanded(
            child: _messages.isEmpty
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
                      return _buildMessageBubble(message, theme, primaryColor);
                    },
                  ),
          ),

          // Input Bar
          _buildInputBar(theme, primaryColor),
        ],
      ),
    );
  }

  Widget _buildQuickSuggestions(ThemeProvider theme, Color primaryColor) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _quickSuggestions.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _sendSuggestion(_quickSuggestions[index]),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Center(
                child: Text(
                  _quickSuggestions[index],
                  style: TextStyle(
                    fontSize: 12,
                    color: primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(
    ChatMessage message,
    ThemeProvider theme,
    Color primaryColor,
  ) {
    final isAI = message.isFromAI;
    final isSystem = message.isSystem;

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message.content,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return Align(
      alignment: isAI ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Column(
          crossAxisAlignment:
              isAI ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            if (isAI)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Text('🤖', style: TextStyle(fontSize: 10)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'مربی هوش مصنوعی',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isAI ? theme.surfaceColor : const Color(0xFF090909),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: isAI ? theme.textColor : Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: theme.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider theme, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome,
              size: 48,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'از مربی هوش مصنوعی بپرسید!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'برنامه‌ریزی، انگیزه و راهنمایی شخصی',
            style: TextStyle(
              fontSize: 13,
              color: theme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(ThemeProvider theme, Color primaryColor) {
    return SafeArea(
      top: false,
      child: Container(
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
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.15),
                  ),
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
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isLoading ? Colors.grey.shade300 : primaryColor,
                shape: BoxShape.circle,
                boxShadow: _isLoading
                    ? null
                    : [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: _isLoading ? null : _sendMessage,
                icon: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 22,
                      ),
              ),
            ),
          ],
        ),
      ),
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
