import 'package:flutter/material.dart';
import '/features/chat/models/chat_models.dart';

class BuddyChatScreen extends StatefulWidget {
  final ConversationModel conversation;

  const BuddyChatScreen({super.key, required this.conversation});

  @override
  State<BuddyChatScreen> createState() => _BuddyChatScreenState();
}

class _BuddyChatScreenState extends State<BuddyChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessageModel> _messages = [];
  bool _isFocusMode = false;
  int _remainingMessages = 20; // تعداد پیام‌های باقی‌مانده در روز

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  void _loadMessages() {
    // نمونه پیام‌ها
    _messages.addAll([
      ChatMessageModel(
        id: '1',
        conversationId: widget.conversation.id,
        senderId: 'other',
        senderName: 'سپیده',
        message: 'سلام! امروز چطور بود؟',
        sentAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      ChatMessageModel(
        id: '2',
        conversationId: widget.conversation.id,
        senderId: 'me',
        senderName: 'من',
        message: 'عالی! امروز ورزش صبحگاهی رو انجام دادم 🏃‍♂️',
        sentAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ]);
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    if (_remainingMessages <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('به محدودیت پیام روزانه رسیدید')),
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
    });
  }

  void _sendEncouragement() {
    setState(() {
      _messages.add(
        ChatMessageModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          conversationId: widget.conversation.id,
          senderId: 'me',
          senderName: 'من',
          message: '🔥 آفرین! ادامه بده',
          messageType: MessageType.encouragement,
          sentAt: DateTime.now(),
          metadata: {'type': 'encouragement', 'emoji': '🔥'},
        ),
      );
    });
  }

  void _sendProgressCard() {
    setState(() {
      _messages.add(
        ChatMessageModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          conversationId: widget.conversation.id,
          senderId: 'me',
          senderName: 'من',
          message: 'پیشرفت امروز من',
          messageType: MessageType.progress,
          sentAt: DateTime.now(),
          metadata: {'habitsCompleted': 4, 'totalHabits': 5, 'xpEarned': 50},
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF4A90E2),
              child: Icon(Icons.person, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.conversation.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: Colors.green),
                    SizedBox(width: 4),
                    Text('آنلاین', style: TextStyle(fontSize: 10)),
                  ],
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
            icon: Icon(
              _isFocusMode ? Icons.do_not_disturb_on : Icons.do_not_disturb_off,
              color: _isFocusMode ? Colors.orange : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _isFocusMode = !_isFocusMode;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _isFocusMode
                        ? 'حالت فوکوس فعال شد'
                        : 'حالت فوکوس غیرفعال شد',
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            tooltip: 'حالت فوکوس',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // پیام خودکار روزانه
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4A90E2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.notifications_active,
                  color: Color(0xFF4A90E2),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'یادآور روزانه',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'امروز عادت‌هات رو انجام دادی؟',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    minimumSize: const Size(60, 30),
                  ),
                  child: const Text('بله', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    minimumSize: const Size(60, 30),
                  ),
                  child: const Text('خیر', style: TextStyle(fontSize: 12)),
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
                final isMe = message.senderId == 'me';
                return _buildMessageBubble(message, isMe);
              },
            ),
          ),

          // دکمه‌های واکنش سریع
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildReactionButton('🔥', 'آفرین!'),
                const SizedBox(width: 8),
                _buildReactionButton('💪', 'قدرتمند'),
                const SizedBox(width: 8),
                _buildReactionButton('🎉', 'تبریک'),
                const SizedBox(width: 8),
                _buildReactionButton('🙏', 'متشکرم'),
                const Spacer(),
                IconButton(
                  onPressed: _sendProgressCard,
                  icon: const Icon(Icons.insights),
                  tooltip: 'ارسال کارت پیشرفت',
                ),
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
                        vertical: 12,
                      ),
                      suffixText: '${_remainingMessages} باقی‌مانده',
                      suffixStyle: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                    maxLines: 3,
                    minLines: 1,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90E2),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF4A90E2) : Colors.white,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: isMe
                ? const Radius.circular(4)
                : const Radius.circular(20),
            bottomLeft: isMe
                ? const Radius.circular(20)
                : const Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.senderName,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A90E2),
                  ),
                ),
              ),
            if (message.messageType == MessageType.progress)
              _buildProgressCard(message.metadata)
            else if (message.messageType == MessageType.encouragement)
              _buildEncouragementCard(message.message)
            else
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

  Widget _buildProgressCard(Map<String, dynamic>? metadata) {
    if (metadata == null) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            '📊 پیشرفت امروز',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    '${metadata['habitsCompleted']}/${metadata['totalHabits']}',
                  ),
                  const Text('عادت', style: TextStyle(fontSize: 10)),
                ],
              ),
              Column(
                children: [
                  Text('+${metadata['xpEarned']}'),
                  const Text('XP', style: TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEncouragementCard(String message) {
    return Row(
      children: [
        const Text('🔥 ', style: TextStyle(fontSize: 20)),
        Expanded(child: Text(message)),
      ],
    );
  }

  Widget _buildReactionButton(String emoji, String text) {
    return GestureDetector(
      onTap: () {
        _sendEncouragement();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$emoji $text', style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
