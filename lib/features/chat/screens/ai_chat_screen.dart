// lib/features/chat/screens/ai_chat_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/chat_service.dart';
import '../../../services/ai_service.dart';
import '../../../providers/sync_provider.dart';
import '../models/message_model.dart';
import '../models/conversation_model.dart';

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

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
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
    _initChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF9B59B6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('🤖', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مربی هوش مصنوعی',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  'آنلاین 🟢',
                  style: TextStyle(fontSize: 11, color: Colors.green),
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
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick Suggestions
          _buildQuickSuggestions(),

          // Messages
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[_messages.length - 1 - index];
                      return _buildMessageBubble(message);
                    },
                  ),
          ),

          // Input
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildQuickSuggestions() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _quickSuggestions.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _sendSuggestion(_quickSuggestions[index]),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF9B59B6).withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                _quickSuggestions[index],
                style: TextStyle(fontSize: 12, color: const Color(0xFF9B59B6)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isAI = message.isFromAI;
    final isSystem = message.isSystem;

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
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
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Column(
          crossAxisAlignment: isAI
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isAI ? Colors.white : const Color(0xFF9B59B6),
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: isAI
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                  bottomRight: isAI
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: isAI ? const Color(0xFF1A1A2E) : Colors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.createdAt),
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
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
              Icons.auto_awesome,
              size: 48,
              color: Color(0xFF9B59B6),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'از مربی هوش مصنوعی بپرسید!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'برنامه‌ریزی، انگیزه و راهنمایی شخصی',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'پیام خود را بنویسید...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: _isLoading
                  ? Colors.grey.shade300
                  : const Color(0xFF9B59B6),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _isLoading ? null : _sendMessage,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
