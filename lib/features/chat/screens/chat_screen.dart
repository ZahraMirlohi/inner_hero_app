// lib/features/chat/screens/chat_screen.dart

import 'package:flutter/material.dart';
import '/services/chat_service.dart';
import '/features/chat/models/conversation_model.dart';
import 'ai_chat_screen.dart';
import 'buddy_finder_screen.dart';
import 'buddy_chat_screen.dart';
import 'squad_chat_screen.dart';
import 'arena_chat_screen.dart';

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
      // ✅ به‌روزرسانی last_seen_at هنگام ورود به صفحه چت
      await _updateLastSeen(user.id);

      try {
        final conversations = await _chatService.getUserConversations(user.id);
        setState(() {
          _conversations = conversations;
          _isLoading = false;
        });
      } catch (e) {
        print('❌ Error loading conversations: $e');
        setState(() {
          _conversations = [];
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateLastSeen(String userId) async {
    try {
      await _chatService.client
          .from('profiles')
          .update({'last_seen_at': DateTime.now().toIso8601String()})
          .eq('user_id', userId);
    } catch (e) {
      // خطا را نادیده بگیر
    }
  }

  // ==================== حذف هم‌مسیر ====================

  Future<void> _removeBuddy(Conversation conv) async {
    try {
      final currentUser = await _chatService.getCurrentUser();
      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لطفاً وارد حساب کاربری خود شوید'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      print('📊 Current user: ${currentUser.id}');
      print('📊 Conversation members: ${conv.memberIds}');

      String otherUserId = '';
      for (var id in conv.memberIds) {
        if (id != currentUser.id) {
          otherUserId = id;
          break;
        }
      }

      if (otherUserId.isEmpty) {
        print('⚠️ Member not found in conversation, fetching from database...');
        final membersResponse = await _chatService.client
            .from('conversation_members')
            .select('user_id')
            .eq('conversation_id', conv.id);

        for (var member in membersResponse) {
          final id = member['user_id'] as String?;
          if (id != null && id != currentUser.id) {
            otherUserId = id;
            break;
          }
        }
      }

      if (otherUserId.isEmpty) {
        print('❌ Could not find other user in conversation');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('کاربر مقابل پیدا نشد'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      print('✅ Other user found: $otherUserId');

      await _chatService.deleteConversationForBoth(conv.id);

      setState(() {
        _conversations.removeWhere((c) => c.id == conv.id);
      });

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('هم‌مسیر "${conv.displayName}" حذف شد'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error removing buddy: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _blockUser(Conversation conv) async {
    try {
      final currentUser = await _chatService.getCurrentUser();
      if (currentUser == null) return;

      String otherUserId = '';
      for (var id in conv.memberIds) {
        if (id != currentUser.id) {
          otherUserId = id;
          break;
        }
      }

      if (otherUserId.isEmpty) {
        final membersResponse = await _chatService.client
            .from('conversation_members')
            .select('user_id')
            .eq('conversation_id', conv.id);

        for (var member in membersResponse) {
          final id = member['user_id'] as String?;
          if (id != null && id != currentUser.id) {
            otherUserId = id;
            break;
          }
        }
      }

      if (otherUserId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('کاربر مقابل پیدا نشد'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      await _chatService.blockUser(currentUser.id, otherUserId);
      await _chatService.deleteConversationForBoth(conv.id);

      setState(() {
        _conversations.removeWhere((c) => c.id == conv.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('کاربر مسدود شد'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error blocking user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmRemoveBuddy(Conversation conv) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف هم‌مسیر'),
        content: Text(
          'آیا از حذف هم‌مسیر "${conv.displayName}" مطمئن هستید؟\n'
          'با این کار، گفتگوی شما حذف می‌شود و دیگر در لیست هم‌مسیرها نخواهید بود.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeBuddy(conv);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmBlockUser(Conversation conv) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('مسدود کردن کاربر'),
        content: Text(
          'آیا از مسدود کردن "${conv.displayName}" مطمئن هستید؟\n'
          'با این کار:\n'
          '• کاربر از لیست هم‌مسیرها حذف می‌شود\n'
          '• دیگر نمی‌تواند به شما پیام دهد\n'
          '• شما نمی‌توانید به او پیام دهید',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _blockUser(conv);
            },
            child: const Text(
              'مسدود کردن',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showBuddyOptions(Conversation conv) {
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
                  'گزینه‌های هم‌مسیر',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_remove,
                      color: Colors.orange,
                    ),
                  ),
                  title: const Text('حذف از هم‌مسیرها'),
                  subtitle: const Text(
                    'دیگر با این کاربر هم‌مسیر نخواهید بود',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmRemoveBuddy(conv);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.block, color: Colors.red),
                  ),
                  title: const Text('مسدود کردن کاربر'),
                  subtitle: const Text(
                    'کاربر را مسدود کنید و از لیست هم‌مسیرها حذف کنید',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmBlockUser(conv);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('گپ و گفتگو'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A2E),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF4A90E2),
            indicatorWeight: 3,
            labelColor: const Color(0xFF4A90E2),
            unselectedLabelColor: Colors.grey.shade500,
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(text: 'هم‌مسیرها'),
              Tab(text: 'گروه‌ها'),
              Tab(text: 'کانال‌ها'),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // ✅ بخش پین شده: چت با هوش مصنوعی
          _buildAIChatCard(),
          const SizedBox(height: 6),
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
        shape: const CircleBorder(),
        child: const Icon(Icons.add_comment, color: Colors.white),
      ),
    );
  }

  // ==================== کارت چت با AI ====================

  Widget _buildAIChatCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AIChatScreen()),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF9B59B6), Color(0xFF7C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9B59B6).withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('🤖', style: TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        'مربی هوش مصنوعی',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'آنلاین',
                          style: TextStyle(fontSize: 8, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'برنامه، انگیزه و راهنمایی شخصی',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_right,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== تب‌ها ====================

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
        onPressed: () {},
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

  // lib/features/chat/screens/chat_screen.dart

  Widget _buildConversationItem(
    Conversation conv, {
    bool isSquad = false,
    bool isArena = false,
  }) {
    final displayName = conv.displayName;
    final lastMessage = conv.lastMessage ?? 'شروع گفتگو';
    final isBuddy = conv.type == ConversationType.buddy;

    return Dismissible(
      key: Key(conv.id),
      direction: isBuddy ? DismissDirection.endToStart : DismissDirection.none,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'حذف هم‌مسیر',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 10),
            Icon(Icons.delete, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('حذف هم‌مسیر'),
              content: Text(
                'آیا از حذف هم‌مسیر "$displayName" مطمئن هستید؟\n'
                'با این کار، گفتگوی شما حذف می‌شود و دیگر در لیست هم‌مسیرها نخواهید بود.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('انصراف'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('حذف', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
          return confirm ?? false;
        }
        return false;
      },
      onDismissed: (direction) {
        _removeBuddy(conv);
      },
      child: GestureDetector(
        onTap: () {
          if (conv.type == ConversationType.buddy) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BuddyChatScreen(conversation: conv),
              ),
            );
          } else if (conv.type == ConversationType.squad) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SquadChatScreen(conversation: conv),
              ),
            );
          } else if (conv.type == ConversationType.ai) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AIChatScreen()),
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
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // ✅ آواتار
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color:
                      (isSquad
                              ? const Color(0xFF9B59B6)
                              : isArena
                              ? const Color(0xFFFFA500)
                              : const Color(0xFF4A90E2))
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    conv.iconEmoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // ✅ اطلاعات - با Expanded برای گرفتن فضای باقیمانده
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A2E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // ✅ نشان آنلاین بودن (فقط برای هم‌مسیرها)
                        if (isBuddy && conv.isBuddyOnline)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // ✅ منوی سه نقطه (فقط برای هم‌مسیرها)
              if (isBuddy)
                IconButton(
                  onPressed: () => _showBuddyOptions(conv),
                  icon: const Icon(Icons.more_vert, size: 18),
                  color: Colors.grey.shade500,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                elevation: 0,
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== دیالوگ‌ها ====================

  void _showNewConversationDialog() {
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
                  'شروع گفتگوی جدید',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildOptionTile(
                  icon: Icons.person_add,
                  title: 'هم‌مسیر جدید',
                  subtitle: 'با افراد هم‌هدف ارتباط برقرار کنید',
                  color: const Color(0xFF4A90E2),
                  onTap: _showBuddyFinder,
                ),
                const SizedBox(height: 8),
                _buildOptionTile(
                  icon: Icons.group_add,
                  title: 'ساخت گروه جدید',
                  subtitle: 'با دوستانتان یک گروه بسازید',
                  color: const Color(0xFF9B59B6),
                  onTap: _showCreateSquadDialog,
                ),
                const SizedBox(height: 8),
                _buildOptionTile(
                  icon: Icons.qr_code_scanner,
                  title: 'پیوستن به گروه',
                  subtitle: 'با کد دعوت وارد شوید',
                  color: const Color(0xFFFFA500),
                  onTap: _showJoinSquadDialog,
                ),
                const SizedBox(height: 12),
              ],
            ),
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
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }

  void _showBuddyFinder() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BuddyFinderScreen()),
    );
  }

  void _showCreateSquadDialog() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ساخت گروه به زودی اضافه می‌شود'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showJoinSquadDialog() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('پیوستن به گروه با کد دعوت به زودی اضافه می‌شود'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
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
