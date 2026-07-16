import 'package:flutter/material.dart';
import '/features/chat/models/chat_models.dart';

class SquadChatScreen extends StatefulWidget {
  final ConversationModel conversation;

  const SquadChatScreen({super.key, required this.conversation});

  @override
  State<SquadChatScreen> createState() => _SquadChatScreenState();
}

class _SquadChatScreenState extends State<SquadChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessageModel> _messages = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMessages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadMessages() {
    _messages.addAll([
      ChatMessageModel(
        id: '1',
        conversationId: widget.conversation.id,
        senderId: 'system',
        senderName: 'سیستم',
        message: 'الناز امروز استریک ۳۰ روزه‌اش رو کامل کرد! 🎉',
        messageType: MessageType.system,
        sentAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      ChatMessageModel(
        id: '2',
        conversationId: widget.conversation.id,
        senderId: 'user1',
        senderName: 'الناز',
        message: 'ممنون دوستان! شما هم ادامه بدید 💪',
        sentAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      ChatMessageModel(
        id: '3',
        conversationId: widget.conversation.id,
        senderId: 'user2',
        senderName: 'رضا',
        message: 'آفرین الناز! واقعاً عالی بود',
        sentAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ]);
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
            if (widget.conversation.weeklyProgress != null)
              Text(
                'پیشرفت گروه: ${(widget.conversation.weeklyProgress! * 100).toInt()}%',
                style: const TextStyle(fontSize: 10),
              ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A2E),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF9B59B6),
          labelColor: const Color(0xFF9B59B6),
          tabs: const [
            Tab(icon: Icon(Icons.chat), text: 'چت'),
            Tab(icon: Icon(Icons.show_chart), text: 'پیشرفت'),
            Tab(icon: Icon(Icons.people), text: 'اعضا'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildChatTab(), _buildProgressTab(), _buildMembersTab()],
      ),
    );
  }

  Widget _buildChatTab() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages.reversed.toList()[index];
              final isSystem = message.senderId == 'system';
              final isMe = message.senderId == 'me';
              return _buildMessageBubble(message, isSystem, isMe);
            },
          ),
        ),
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
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF9B59B6),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.send, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
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
            const Icon(Icons.info, size: 14, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              message.message,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
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
          color: isMe ? const Color(0xFF9B59B6) : Colors.white,
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
                  color: Color(0xFF9B59B6),
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

  Widget _buildProgressTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // نوار پیشرفت کلی
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Text(
                'پیشرفت گروه این هفته',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: widget.conversation.weeklyProgress,
                      strokeWidth: 10,
                      backgroundColor: Colors.grey.shade200,
                      color: const Color(0xFF9B59B6),
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        '${((widget.conversation.weeklyProgress ?? 0) * 100).toInt()}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('%', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // سهم اعضا
        const Text(
          'سهم اعضا',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._getMemberProgress().map(
          (member) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  child: Icon(Icons.person, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member['name'],
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: member['progress'],
                        backgroundColor: Colors.grey.shade200,
                        color: const Color(0xFF9B59B6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${((member['progress'] as double) * 100).toInt()}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getMemberProgress() {
    return [
      {'name': 'الناز', 'progress': 0.95},
      {'name': 'رضا', 'progress': 0.82},
      {'name': 'سارا', 'progress': 0.78},
      {'name': 'علی', 'progress': 0.65},
      {'name': 'مریم', 'progress': 0.91},
    ];
  }

  Widget _buildMembersTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(Icons.group, color: Color(0xFF9B59B6)),
              const SizedBox(width: 12),
              Text(
                '${widget.conversation.participants.length} عضو',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              OutlinedButton(onPressed: () {}, child: const Text('دعوت')),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._getMembers().map(
          (member) => ListTile(
            leading: CircleAvatar(
              backgroundColor: (member['color'] as Color).withOpacity(0.2),
              child: Icon(Icons.person, color: member['color']),
            ),
            title: Text(member['name']),
            subtitle: Text(member['role']),
            trailing: member['isOnline'] == true
                ? Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getMembers() {
    return [
      {
        'name': 'الناز',
        'role': 'کاپیتان',
        'color': Colors.orange,
        'isOnline': true,
      },
      {'name': 'رضا', 'role': 'عضو', 'color': Colors.blue, 'isOnline': true},
      {'name': 'سارا', 'role': 'عضو', 'color': Colors.pink, 'isOnline': false},
      {'name': 'علی', 'role': 'عضو', 'color': Colors.green, 'isOnline': true},
      {
        'name': 'مریم',
        'role': 'عضو',
        'color': Colors.purple,
        'isOnline': false,
      },
    ];
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
