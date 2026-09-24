// lib/features/chat/screens/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/services/chat_service.dart';
import '/providers/theme_provider.dart';
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
          .update({'last_seen_at': DateTime.now().toIso8601String()}).eq(
              'user_id', userId);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

  void _showBuddyOptions(Conversation conv, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
    final theme = Provider.of<ThemeProvider>(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'گپ و گفتگو',
          style: TextStyle(color: theme.textColor),
        ),
        backgroundColor: theme.surfaceColor,
        elevation: 0,
        foregroundColor: theme.textColor,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
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
                Tab(height: 44, text: 'هم‌مسیرها'),
                Tab(height: 44, text: 'گروه‌ها'),
                Tab(height: 44, text: 'کانال‌ها'),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ✅ کارت AI
          _buildAIChatCard(theme, primaryColor),
          const SizedBox(height: 6),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBuddyTab(theme, primaryColor),
                _buildSquadTab(theme, primaryColor),
                _buildArenaTab(theme, primaryColor),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewConversationDialog(theme, primaryColor),
        backgroundColor: primaryColor,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_comment, color: Colors.white),
      ),
    );
  }

  // ==================== کارت چت با AI ====================

  Widget _buildAIChatCard(ThemeProvider theme, Color primaryColor) {
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
          color: primaryColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.3),
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
                borderRadius: BorderRadius.circular(14),
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

  Widget _buildBuddyTab(ThemeProvider theme, Color primaryColor) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    final buddyConversations =
        _conversations.where((c) => c.type == ConversationType.buddy).toList();

    if (buddyConversations.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        title: 'هنوز هم‌مسیری ندارید',
        subtitle: 'با افراد هم‌هدف ارتباط برقرار کنید',
        buttonText: 'پیدا کردن هم‌مسیر',
        onPressed: _showBuddyFinder,
        theme: theme,
        primaryColor: primaryColor,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: buddyConversations.length,
      itemBuilder: (context, index) {
        final conv = buddyConversations[index];
        return _buildConversationItem(
          conv,
          theme: theme,
          primaryColor: primaryColor,
        );
      },
    );
  }

  Widget _buildSquadTab(ThemeProvider theme, Color primaryColor) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    final squadConversations =
        _conversations.where((c) => c.type == ConversationType.squad).toList();

    if (squadConversations.isEmpty) {
      return _buildEmptyState(
        icon: Icons.group_outlined,
        title: 'هنوز گروهی ندارید',
        subtitle: 'یک گروه بسازید یا به گروهی بپیوندید',
        buttonText: 'ساخت گروه جدید',
        onPressed: () => _showCreateSquadDialog(theme, primaryColor),
        theme: theme,
        primaryColor: primaryColor,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: squadConversations.length,
      itemBuilder: (context, index) {
        final conv = squadConversations[index];
        return _buildConversationItem(
          conv,
          isSquad: true,
          theme: theme,
          primaryColor: primaryColor,
        );
      },
    );
  }

  Widget _buildArenaTab(ThemeProvider theme, Color primaryColor) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    final arenaConversations =
        _conversations.where((c) => c.type == ConversationType.arena).toList();

    if (arenaConversations.isEmpty) {
      return _buildEmptyState(
        icon: Icons.stadium_outlined,
        title: 'کانال فعالی وجود ندارد',
        subtitle: 'با شرکت در چالش‌ها، کانال‌های جدید فعال می‌شوند',
        buttonText: 'مشاهده چالش‌ها',
        onPressed: () {},
        theme: theme,
        primaryColor: primaryColor,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: arenaConversations.length,
      itemBuilder: (context, index) {
        final conv = arenaConversations[index];
        return _buildConversationItem(
          conv,
          isArena: true,
          theme: theme,
          primaryColor: primaryColor,
        );
      },
    );
  }

  // ==================== ویجت گفتگو ====================

  Widget _buildConversationItem(
    Conversation conv, {
    bool isSquad = false,
    bool isArena = false,
    required ThemeProvider theme,
    required Color primaryColor,
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
          borderRadius: BorderRadius.circular(20),
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
                borderRadius: BorderRadius.circular(20),
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
            color: theme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
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
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    conv.iconEmoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // ✅ اطلاعات
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: theme.textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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
                        color: theme.textSecondaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // ✅ منوی سه نقطه
              if (isBuddy)
                IconButton(
                  onPressed: () => _showBuddyOptions(conv, primaryColor),
                  icon: const Icon(Icons.more_vert, size: 18),
                  color: theme.textSecondaryColor,
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
    required ThemeProvider theme,
    required Color primaryColor,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
                icon,
                size: 56,
                color: primaryColor.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: theme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
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

  void _showNewConversationDialog(ThemeProvider theme, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  color: primaryColor,
                  onTap: _showBuddyFinder,
                  primaryColor: primaryColor,
                ),
                const SizedBox(height: 8),
                _buildOptionTile(
                  icon: Icons.group_add,
                  title: 'ساخت گروه جدید',
                  subtitle: 'با دوستانتان یک گروه بسازید',
                  color: primaryColor,
                  onTap: () {
                    Navigator.pop(context);
                    _showCreateSquadDialog(theme, primaryColor);
                  },
                  primaryColor: primaryColor,
                ),
                const SizedBox(height: 8),
                _buildOptionTile(
                  icon: Icons.qr_code_scanner,
                  title: 'پیوستن به گروه',
                  subtitle: 'با کد دعوت وارد شوید',
                  color: primaryColor,
                  onTap: () {
                    Navigator.pop(context);
                    _showJoinSquadDialog(primaryColor);
                  },
                  primaryColor: primaryColor,
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
    required Color primaryColor,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
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

  void _showCreateSquadDialog(ThemeProvider theme, Color primaryColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('ساخت گروه به زودی اضافه می‌شود'),
        backgroundColor: primaryColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showJoinSquadDialog(Color primaryColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('پیوستن به گروه با کد دعوت به زودی اضافه می‌شود'),
        backgroundColor: primaryColor,
        duration: const Duration(seconds: 2),
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
