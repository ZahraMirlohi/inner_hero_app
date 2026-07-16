import 'package:flutter/material.dart';
import '/features/chat/models/chat_models.dart';

class ArenaChatScreen extends StatefulWidget {
  final ConversationModel conversation;

  const ArenaChatScreen({super.key, required this.conversation});

  @override
  State<ArenaChatScreen> createState() => _ArenaChatScreenState();
}

class _ArenaChatScreenState extends State<ArenaChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessageModel> _messages = [];
  int _remainingMessages = 5; // حداکثر ۵ پیام در روز
  int _messageLength = 0;
  final int _maxMessageLength = 200;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  void _loadMessages() {
    _messages.addAll([
      ChatMessageModel(
        id: '1',
        conversationId: widget.conversation.id,
        senderId: 'system',
        senderName: 'سیستم',
        message: '🔥 کاربر رضا رتبه اول امروز رو گرفت!',
        messageType: MessageType.system,
        sentAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      ChatMessageModel(
        id: '2',
        conversationId: widget.conversation.id,
        senderId: 'user1',
        senderName: 'rezag',
        message: 'به همه پیشنهاد میکنم صبح ها مدیتیشن رو حتما امتحان کنید 🧘',
        sentAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      ChatMessageModel(
        id: '3',
        conversationId: widget.conversation.id,
        senderId: 'user2',
        senderName: 'sarahr',
        message: 'امروز تونستم ۱۰ کیلومتر بدوم! 🏃‍♀️',
        sentAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
    ]);
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    if (_messageController.text.length > _maxMessageLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حداکثر ${_maxMessageLength} کاراکتر مجاز است')),
      );
      return;
    }
    if (_remainingMessages <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('به محدودیت ۵ پیام در روز رسیدید')),
      );
      return;
    }

    setState(() {
      _messages.add(
        ChatMessageModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          conversationId: widget.conversation.id,
          senderId: 'me',
          senderName: 'من',
          message: _messageController.text,
          sentAt: DateTime.now(),
        ),
      );
      _remainingMessages--;
      _messageController.clear();
      _messageLength = 0;
    });
  }

  void _sendReaction(String emoji) {
    setState(() {
      _messages.add(
        ChatMessageModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          conversationId: widget.conversation.id,
          senderId: 'me',
          senderName: 'من',
          message: emoji,
          messageType: MessageType.encouragement,
          sentAt: DateTime.now(),
        ),
      );
      _remainingMessages--;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              widget.conversation.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              '۲۳۴ شرکت‌کننده | ۵ روز باقی‌مانده',
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A2E),
      ),
      body: Column(
        children: [
          // هدر چالش
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFFFF6B6B), const Color(0xFFFFA500)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.white, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'چالش صبح قهرمانانه',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: 0.7,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '٪۷۰ به هدف نهایی',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // لیست پیام‌ها
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages.reversed.toList()[index];
                final isSystem = message.senderId == 'system';
                final isMe = message.senderId == 'me';
                return _buildMessageBubble(message, isSystem, isMe);
              },
            ),
          ),

          // دکمه‌های واکنش
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildReactionButton('🔥'),
                _buildReactionButton('❤️'),
                _buildReactionButton('👏'),
                _buildReactionButton('💪'),
                _buildReactionButton('🎉'),
              ],
            ),
          ),

          // ورودی پیام
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        onChanged: (value) {
                          setState(() {
                            _messageLength = value.length;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'پیام خود را بنویسید...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          suffixText: '$_messageLength/$_maxMessageLength',
                          suffixStyle: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                        maxLength: _maxMessageLength,
                        buildCounter:
                            (
                              context, {
                              required currentLength,
                              required isFocused,
                              maxLength,
                            }) => null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFA500),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: _sendMessage,
                        icon: const Icon(Icons.send, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.message, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'پیام‌های باقی‌مانده امروز: $_remainingMessages',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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

  Widget _buildMessageBubble(
    ChatMessageModel message,
    bool isSystem,
    bool isMe,
  ) {
    if (isSystem) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 14, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              message.message,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (message.messageType == MessageType.encouragement) {
      return Align(
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(message.message, style: const TextStyle(fontSize: 24)),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFFFA500) : Colors.white,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: isMe
                ? const Radius.circular(4)
                : const Radius.circular(20),
            bottomLeft: isMe
                ? const Radius.circular(20)
                : const Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                message.senderName,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFFA500),
                ),
              ),
            Text(
              message.message,
              style: TextStyle(
                color: isMe ? Colors.white : const Color(0xFF1A1A2E),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.sentAt),
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.white.withOpacity(0.7) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionButton(String emoji) {
    return GestureDetector(
      onTap: () => _sendReaction(emoji),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 20)),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
