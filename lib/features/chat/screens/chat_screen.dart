import 'package:flutter/material.dart';
import '/features/chat/models/chat_models.dart';
import '/features/chat/screens/buddy_chat_screen.dart';
import '/features/chat/screens/squad_chat_screen.dart';
import '/features/chat/screens/arena_chat_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ConversationModel> _conversations = [];
  bool _isLoading = true;

  // نمونه دیتا
  final List<ConversationModel> _sampleConversations = [
    ConversationModel(
      id: '1',
      name: 'سپیده صبحگاهی',
      type: ChatType.buddy,
      avatarUrl: null,
      lastMessage: 'عالی بود! امروز هم تمرین کردم 💪',
      lastMessageTime: DateTime.now().subtract(const Duration(minutes: 5)),
      unreadCount: 2,
      participants: ['user1', 'user2'],
      isAiAvailable: true,
    ),
    ConversationModel(
      id: '2',
      name: 'اژدهایان سپیده‌دم',
      type: ChatType.squad,
      lastMessage: 'الناز امروز استریک ۳۰ روزه‌اش رو کامل کرد! 🎉',
      lastMessageTime: DateTime.now().subtract(const Duration(hours: 2)),
      unreadCount: 0,
      participants: ['user1', 'user2', 'user3', 'user4'],
      squadId: 'squad_1',
      weeklyProgress: 0.75,
      maxMembers: 8,
    ),
    ConversationModel(
      id: '3',
      name: 'چالش صبح قهرمانانه',
      type: ChatType.arena,
      lastMessage: '🔥 کاربر رضا رتبه اول امروز رو گرفت!',
      lastMessageTime: DateTime.now().subtract(const Duration(hours: 5)),
      unreadCount: 15,
      participants: [],
      challengeId: 'challenge_1',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadConversations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _conversations = _sampleConversations;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('گپ و گفتگو'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A2E),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4A90E2),
          indicatorWeight: 3,
          labelColor: const Color(0xFF4A90E2),
          unselectedLabelColor: Colors.grey.shade500,
          tabs: const [
            Tab(text: 'گفتگوها'),
            Tab(text: 'همراهان'),
            Tab(text: 'میدان'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConversationsList(),
          _buildBuddyList(),
          _buildArenaChallengesList(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewConversationDialog(),
        backgroundColor: const Color(0xFF4A90E2),
        child: const Icon(Icons.add_comment, color: Colors.white),
      ),
    );
  }

  Widget _buildConversationsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4A90E2)),
      );
    }

    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'هنوز گفتگویی ندارید',
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 8),
            Text(
              'یک همراه پیدا کنید یا به گروه بپیوندید',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conv = _conversations[index];
        return _buildConversationItem(conv);
      },
    );
  }

  Widget _buildConversationItem(ConversationModel conv) {
    return GestureDetector(
      onTap: () {
        if (conv.type == ChatType.buddy) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BuddyChatScreen(conversation: conv),
            ),
          );
        } else if (conv.type == ChatType.squad) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SquadChatScreen(conversation: conv),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ArenaChatScreen(conversation: conv),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // آواتار
            Stack(
              children: [
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    color:
                        (conv.type == ChatType.buddy
                                ? const Color(0xFF4A90E2)
                                : conv.type == ChatType.squad
                                ? const Color(0xFF9B59B6)
                                : const Color(0xFFFFA500))
                            .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Icon(
                      conv.type == ChatType.buddy
                          ? Icons.person
                          : conv.type == ChatType.squad
                          ? Icons.group
                          : Icons.stadium,
                      color: conv.type == ChatType.buddy
                          ? const Color(0xFF4A90E2)
                          : conv.type == ChatType.squad
                          ? const Color(0xFF9B59B6)
                          : const Color(0xFFFFA500),
                      size: 28,
                    ),
                  ),
                ),
                if (conv.unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        conv.unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // اطلاعات
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        conv.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (conv.type == ChatType.squad &&
                          conv.weeklyProgress != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${(conv.weeklyProgress! * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.green,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conv.lastMessage,
                    style: TextStyle(
                      fontSize: 13,
                      color: conv.unreadCount > 0
                          ? const Color(0xFF1A1A2E)
                          : Colors.grey.shade500,
                      fontWeight: conv.unreadCount > 0
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(conv.lastMessageTime),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (conv.type == ChatType.buddy && conv.isAiAvailable)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF9B59B6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: Color(0xFF9B59B6),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuddyList() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'به زودی...',
            style: TextStyle(fontSize: 18, color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 8),
          Text(
            'سیستم پیشنهاد همراه در حال توسعه',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.search),
            label: const Text('پیدا کردن همراه'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArenaChallengesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFF6B6B).withOpacity(0.9),
                const Color(0xFFFFA500).withOpacity(0.9),
              ],
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '۲۳۴ نفر شرکت‌کننده | ۵ روز باقی‌مانده',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: 0.7,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.chevron_right, color: Colors.white),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNewConversationDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
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
              const SizedBox(height: 20),
              const Text(
                'شروع گفتگوی جدید',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildOptionTile(
                icon: Icons.person_add,
                title: 'همراه جدید',
                subtitle: 'یک همراه مسئولیت‌پذیر پیدا کنید',
                color: const Color(0xFF4A90E2),
                onTap: () {},
              ),
              const SizedBox(height: 12),
              _buildOptionTile(
                icon: Icons.group_add,
                title: 'ساخت گروه جدید',
                subtitle: 'با دوستانتان یک گروه بسازید',
                color: const Color(0xFF9B59B6),
                onTap: () {},
              ),
              const SizedBox(height: 12),
              _buildOptionTile(
                icon: Icons.qr_code_scanner,
                title: 'پیوستن به گروه',
                subtitle: 'با کد دعوت وارد شوید',
                color: const Color(0xFFFFA500),
                onTap: () {},
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays > 7) {
      return '${diff.inDays ~/ 7} هفته پیش';
    } else if (diff.inDays > 0) {
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
