// lib/features/chat/screens/chat_screen.dart

import 'package:flutter/material.dart';
import '/services/chat_service.dart';
import '/features/chat/models/conversation_model.dart';
import 'ai_chat_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ChatService _chatService = ChatService();
  List<Conversation> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = await _chatService.getCurrentUser();
    if (user != null) {
      final conversations = await _chatService.getUserConversations(user.id);
      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
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
            Tab(text: 'هم‌مسیرها'),
            Tab(text: 'گروه‌ها'),
            Tab(text: 'کانال‌ها'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ✅ بخش پین شده: چت با هوش مصنوعی
          _buildAIChatCard(),
          const SizedBox(height: 8),

          // ✅ تب‌ها
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildBuddyTab(), _buildSquadTab(), _buildArenaTab()],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewConversationDialog(),
        backgroundColor: const Color(0xFF4A90E2),
        child: const Icon(Icons.add_comment, color: Colors.white),
      ),
    );
  }

  // ==================== کارت چت با AI (پین شده در بالا) ====================

  Widget _buildAIChatCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AIChatScreen()),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF9B59B6), Color(0xFF7C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9B59B6).withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // آواتار AI
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Center(
                child: Text('🤖', style: TextStyle(fontSize: 28)),
              ),
            ),
            const SizedBox(width: 14),

            // اطلاعات
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'مربی هوش مصنوعی',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'آنلاین',
                          style: TextStyle(fontSize: 10, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'برای دریافت برنامه، انگیزه و راهنمایی کلیک کنید',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // نشانگر
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_right,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== تب هم‌مسیرها ====================

  Widget _buildBuddyTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4A90E2)),
      );
    }

    final buddyConversations = _conversations
        .where((c) => c.type == ConversationType.buddy)
        .toList();

    if (buddyConversations.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        title: 'هنوز هم‌مسیری ندارید',
        subtitle: 'با افراد هم‌هدف ارتباط برقرار کنید',
        buttonText: 'پیدا کردن هم‌مسیر',
        onPressed: _showBuddyFinder,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: buddyConversations.length,
      itemBuilder: (context, index) {
        final conv = buddyConversations[index];
        return _buildConversationItem(conv);
      },
    );
  }

  // ==================== تب گروه‌ها ====================

  Widget _buildSquadTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4A90E2)),
      );
    }

    final squadConversations = _conversations
        .where((c) => c.type == ConversationType.squad)
        .toList();

    if (squadConversations.isEmpty) {
      return _buildEmptyState(
        icon: Icons.group_outlined,
        title: 'هنوز گروهی ندارید',
        subtitle: 'یک گروه بسازید یا به گروهی بپیوندید',
        buttonText: 'ساخت گروه جدید',
        onPressed: _showCreateSquadDialog,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: squadConversations.length,
      itemBuilder: (context, index) {
        final conv = squadConversations[index];
        return _buildConversationItem(conv, isSquad: true);
      },
    );
  }

  // ==================== تب کانال‌ها ====================

  Widget _buildArenaTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4A90E2)),
      );
    }

    final arenaConversations = _conversations
        .where((c) => c.type == ConversationType.arena)
        .toList();

    if (arenaConversations.isEmpty) {
      return _buildEmptyState(
        icon: Icons.stadium_outlined,
        title: 'کانال فعالی وجود ندارد',
        subtitle: 'با شرکت در چالش‌ها، کانال‌های جدید فعال می‌شوند',
        buttonText: 'مشاهده چالش‌ها',
        onPressed: () {
          // رفتن به صفحه اکسپلور
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: arenaConversations.length,
      itemBuilder: (context, index) {
        final conv = arenaConversations[index];
        return _buildConversationItem(conv, isArena: true);
      },
    );
  }

  // ==================== ویجت گفتگو ====================

  Widget _buildConversationItem(
    Conversation conv, {
    bool isSquad = false,
    bool isArena = false,
  }) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('گفتگو با ${conv.displayName}'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // آواتار
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color:
                    (isSquad
                            ? const Color(0xFF9B59B6)
                            : isArena
                            ? const Color(0xFFFFA500)
                            : const Color(0xFF4A90E2))
                        .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child: Text(
                  conv.iconEmoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // اطلاعات
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conv.displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conv.lastMessage ?? 'شروع گفتگو',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // زمان
            Text(
              _formatTime(conv.lastMessageAt),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== حالت خالی ====================

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade500)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              buttonText,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== دیالوگ‌ها ====================

  void _showNewConversationDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                title: 'هم‌مسیر جدید',
                subtitle: 'با افراد هم‌هدف ارتباط برقرار کنید',
                color: const Color(0xFF4A90E2),
                onTap: _showBuddyFinder,
              ),
              const SizedBox(height: 12),
              _buildOptionTile(
                icon: Icons.group_add,
                title: 'ساخت گروه جدید',
                subtitle: 'با دوستانتان یک گروه بسازید',
                color: const Color(0xFF9B59B6),
                onTap: _showCreateSquadDialog,
              ),
              const SizedBox(height: 12),
              _buildOptionTile(
                icon: Icons.qr_code_scanner,
                title: 'پیوستن به گروه',
                subtitle: 'با کد دعوت وارد شوید',
                color: const Color(0xFFFFA500),
                onTap: _showJoinSquadDialog,
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
          color: color.withValues(alpha: 0.1),
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

  void _showBuddyFinder() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('سیستم پیدا کردن هم‌مسیر به زودی اضافه می‌شود'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showCreateSquadDialog() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ساخت گروه به زودی اضافه می‌شود'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showJoinSquadDialog() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('پیوستن به گروه با کد دعوت به زودی اضافه می‌شود'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // ==================== کمکی ====================

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
