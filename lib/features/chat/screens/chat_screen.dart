// lib/features/chat/screens/chat_screen.dart

import '../widgets/avatar_viewer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/services/chat_service.dart';
import '/providers/theme_provider.dart';
import '../widgets/buddy_requests_view.dart';
import '../widgets/buddy_list_view.dart';
import '/l10n/app_strings.dart';
import '/core/app_palette.dart';
import '/features/chat/models/conversation_model.dart';
import 'ai_chat_screen.dart';
import 'buddy_finder_screen.dart';
import 'buddy_chat_screen.dart';
import 'squad_chat_screen.dart';
import 'arena_chat_screen.dart';

class ChatScreen extends StatefulWidget {
  /// MainScreen آن را زیاد می‌کند تا چت روی «درخواست‌ها» باز شود
  static final ValueNotifier<int> openRequestsSignal = ValueNotifier(0);

  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _buddySub = 0; // 0 گفتگوها، 1 درخواست‌ها، 2 هم‌مسیرها
  int _incomingCount = 0;
  int _requestsEpoch = 0;
  final ChatService _chatService = ChatService();
  final SupabaseClient _supabaseClient = Supabase.instance.client;

  List<Conversation> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    ChatScreen.openRequestsSignal.addListener(_openRequests);
    _loadIncomingCount();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    ChatScreen.openRequestsSignal.removeListener(_openRequests);
    _tabController.dispose();
    super.dispose();
  }

  void _openRequests() {
    if (!mounted) return;
    setState(() {
      _buddySub = 1;
      _requestsEpoch++;
    });
    _tabController.animateTo(0);
  }

  Future<void> _loadIncomingCount() async {
    try {
      final me = _supabaseClient.auth.currentUser?.id;
      if (me == null) return;
      final rows = await _supabaseClient
          .from('buddy_requests')
          .select('id')
          .eq('to_user_id', me)
          .eq('status', 'pending');
      if (mounted) setState(() => _incomingCount = rows.length);
    } catch (_) {}
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    final user = await _chatService.getCurrentUser();
    if (user == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    await _updateLastSeen(user.id);

    if (!mounted) return;

    try {
      final conversations = await _chatService.getUserConversations(user.id);

      if (!mounted) return;

      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading conversations: $e');
      if (mounted) {
        setState(() {
          _conversations = [];
          _isLoading = false;
        });
      }
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

  bool _openingChat = false;

  Future<void> _openBuddyChat(String otherId) async {
    if (_openingChat) return; // لمس تکراری تا باز شدن چت نادیده گرفته می‌شود
    _openingChat = true;
    try {
      final me = (await _chatService.getCurrentUser())!.id;
      final id = await _chatService.openBuddyConversation(me, otherId);
      final convs = await _chatService.getUserConversations(me);
      final conv = convs.firstWhere((c) => c.id == id);
      if (!mounted) return;
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => BuddyChatScreen(conversation: conv)));
      if (mounted) _loadData();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr('bd.error'))));
      }
    } finally {
      _openingChat = false;
    }
  }

  // ==================== حذف هم‌مسیر ====================
  Future<void> _removeBuddy(Conversation conv, {bool buddyToo = true}) async {
    try {
      final currentUser = await _chatService.getCurrentUser();
      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('ct.chat.login')),
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
            SnackBar(
              content: Text(context.tr('ct.chat.nouser')),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      await _chatService.deleteConversationForBoth(conv.id,
          removeBuddy: buddyToo);

      if (mounted) {
        setState(() {
          _conversations.removeWhere((c) => c.id == conv.id);
        });
      }

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(buddyToo
                ? context.tr('bd.removed')
                : context.tr('bd.delchat.done')),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error removing buddy: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('ct.err', {'e': e.toString()})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== مسدود کردن کاربر ====================
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
            SnackBar(
              content: Text(context.tr('ct.chat.nouser')),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final existing = await _supabaseClient
          .from('blocked_users')
          .select('id')
          .eq('blocker_id', currentUser.id)
          .eq('blocked_id', otherUserId)
          .maybeSingle();

      if (existing == null) {
        await _supabaseClient.from('blocked_users').insert({
          'blocker_id': currentUser.id,
          'blocked_id': otherUserId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      try {
        await _supabaseClient.from('buddy_requests').delete().or(
            'and(from_user_id.eq.${currentUser.id},to_user_id.eq.$otherUserId),'
            'and(from_user_id.eq.$otherUserId,to_user_id.eq.${currentUser.id})');
      } catch (e) {
        print('Error removing buddy requests: $e');
      }

      await _chatService.deleteConversationForBoth(conv.id);

      if (mounted) {
        setState(() {
          _conversations.removeWhere((c) => c.id == conv.id);
        });
      }

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('ct.chat.blocked')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error blocking user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('ct.err', {'e': e.toString()})),
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
        title: Text(context.tr('ct.chat.rmBuddy')),
        content: Text(
          context.tr('ct.chat.rmBuddy.q', {'n': conv.displayName}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('bd.cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeBuddy(conv);
            },
            child: Text(context.tr('bd.delete'), style: const TextStyle(color: Colors.red)),
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
        title: Text(context.tr('ct.chat.block')),
        content: Text(
          context.tr('ct.chat.block.q', {'n': conv.displayName}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('bd.cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _blockUser(conv);
            },
            child: Text(
              context.tr('ct.chat.block.btn'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showBuddyOptions(Conversation conv, Color primaryColor) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: theme.surfaceColor,
      builder: (context) => SafeArea(top: false, child: Builder(builder: (_) {
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
                      color: theme.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr('ct.chat.opts'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_sweep_rounded,
                        color: Colors.blueGrey),
                  ),
                  title: Text(context.tr('bd.delchat'),
                      style: TextStyle(color: theme.textColor)),
                  subtitle: Text(context.tr('bd.delchat.sub'),
                      style: TextStyle(
                          fontSize: 12, color: theme.textSecondaryColor)),
                  onTap: () {
                    Navigator.pop(context);
                    _removeBuddy(conv, buddyToo: false);
                  },
                ),
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
                  title: Text(
                    context.tr('bd.remove'),
                    style: TextStyle(color: theme.textColor),
                  ),
                  subtitle: Text(
                    context.tr('ct.chat.rmBuddy.sub'),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textSecondaryColor,
                    ),
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
                  title: Text(
                    context.tr('ct.chat.block'),
                    style: TextStyle(color: theme.textColor),
                  ),
                  subtitle: Text(
                    context.tr('ct.chat.block.sub'),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textSecondaryColor,
                    ),
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
      })),
    );
  }

  static const _ink = Color(0xFF090909);
  static const _tones = [
    Tone.sky, Tone.rose, Tone.lilac, Tone.butter, Tone.mint, Tone.peach, Tone.lime, Tone.apricot,
  ];

  List<BoxShadow> _cardShadow(ThemeProvider theme) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: theme.isDarkMode ? 0.3 : 0.05),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return context.tr('ct.ago.now');
    if (d.inMinutes < 60) return context.tr('ct.ago.min', {'n': '${d.inMinutes}'});
    if (d.inHours < 24) return context.tr('ct.ago.hour', {'n': '${d.inHours}'});
    if (d.inDays == 1) return context.tr('ct.ago.yesterday');
    if (d.inDays < 7) return context.tr('ct.ago.day', {'n': '${d.inDays}'});
    return context.tr('ct.ago.week', {'n': '${d.inDays ~/ 7}'});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final primaryColor = theme.effectivePrimary;
    // بالای نوار ناوبری اصلی (۶۴ + حاشیه‌ها + ناحیهٔ امن پایین)
    final navClear = 96.0 + MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: Stack(children: [
        Positioned.fill(child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  context.tr('ct.chat.title'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: theme.textColor,
                  ),
                ),
              ),
            ),
            _buildTabPill(theme, primaryColor),
            const SizedBox(height: 14),
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
      )),
        Positioned(
          right: 20,
          bottom: navClear,
          child: _buildAiFab(theme, primaryColor),
        ),
        Positioned(
          left: 20,
          bottom: navClear,
          child: FloatingActionButton(
            heroTag: 'chat_add',
            onPressed: () => _showNewConversationDialog(theme, primaryColor),
            backgroundColor: primaryColor,
            shape: const CircleBorder(),
            elevation: 6,
            child:
                Icon(Icons.add_rounded, color: theme.onPrimaryColor, size: 28),
          ),
        ),
      ]),
    );
  }

  Widget _buildTabPill(ThemeProvider theme, Color primaryColor) {
    return Container(
      height: 56,
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: _cardShadow(theme),
      ),
      child: TabBar(
        controller: _tabController,
        labelPadding: EdgeInsets.zero,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(24),
        ),
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(24),
        labelColor: theme.onPrimaryColor,
        unselectedLabelColor: theme.textSecondaryColor,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        tabs: [
          Tab(height: 48, text: context.tr('bd.tab.buddies')),
          Tab(height: 48, text: context.tr('ct.chat.tab.groups')),
          Tab(height: 48, text: context.tr('ct.chat.tab.channels')),
        ],
      ),
    );
  }

  // مربی هوش مصنوعی: دکمهٔ شناور کنار صفحه که به‌صورت پاپ‌آپ باز می‌شود
  Widget _buildAiFab(ThemeProvider theme, Color primaryColor) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: theme.surfaceColor,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.smart_toy_rounded, size: 44, color: primaryColor),
                  const SizedBox(height: 14),
                  Text(context.tr('ct.chat.ai'),
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: theme.textColor)),
                  const SizedBox(height: 8),
                  Text(context.tr('ct.chat.soon'),
                      style: TextStyle(
                          fontSize: 15, color: theme.textSecondaryColor)),
                ],
              ),
            ),
          ),
        );
      },
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _ink,
          borderRadius: BorderRadius.circular(26),
          boxShadow: _cardShadow(theme),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_rounded, color: primaryColor, size: 22),
            const SizedBox(width: 8),
            Text(context.tr('ct.chat.coach'),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildBuddyTab(ThemeProvider theme, Color primaryColor) {
    return Column(
      children: [
        _buildBuddySubToggle(theme),
        Expanded(
          child: _buddySub == 2
              ? BuddyListView(onOpen: _openBuddyChat)
              : _buddySub == 1
              ? BuddyRequestsView(
                  key: ValueKey(_requestsEpoch),
                  onChanged: (n, {bool accepted = false}) {
                    if (mounted) setState(() => _incomingCount = n);
                    if (accepted) _loadData();
                  },
                )
              : _buildBuddyConversations(theme, primaryColor),
        ),
      ],
    );
  }

  Widget _buildBuddySubToggle(ThemeProvider theme) {
    Widget chip(String label, int idx, {int badge = 0}) {
      final on = _buddySub == idx;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() {
            _buddySub = idx;
            if (idx == 1) _requestsEpoch++;
          }),
          child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? theme.effectivePrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(19),
            ),
            child: Text(badge > 0 ? '$label ($badge)' : label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: on ? theme.onPrimaryColor : theme.textSecondaryColor)),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(23),
      ),
      child: Row(children: [
        chip(context.tr('bd.tab.chats'), 0),
        chip(context.tr('bd.tab.buddies'), 2),
        chip(context.tr('bd.tab.requests'), 1, badge: _incomingCount),
      ]),
    );
  }

  Widget _buildBuddyConversations(ThemeProvider theme, Color primaryColor) {
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
        title: context.tr('ct.chat.nobuddy'),
        subtitle: context.tr('ct.chat.nobuddy.sub'),
        buttonText: context.tr('ct.chat.findBuddy'),
        onPressed: _showBuddyFinder,
        theme: theme,
        primaryColor: primaryColor,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 160),
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
        title: context.tr('ct.chat.nogroup'),
        subtitle: context.tr('ct.chat.nogroup.sub'),
        buttonText: context.tr('ct.chat.newGroup'),
        onPressed: () => _showCreateSquadDialog(theme, primaryColor),
        theme: theme,
        primaryColor: primaryColor,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 160),
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
        title: context.tr('ct.chat.nochan'),
        subtitle: context.tr('ct.chat.nochan.sub'),
        buttonText: context.tr('ct.chat.viewChallenges'),
        onPressed: () {},
        theme: theme,
        primaryColor: primaryColor,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 160),
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

  Widget _buildConversationItem(
    Conversation conv, {
    bool isSquad = false,
    bool isArena = false,
    required ThemeProvider theme,
    required Color primaryColor,
  }) {
    final displayName = conv.displayName;
    final lastMessage = conv.lastMessage ?? context.tr('ct.chat.startChat');
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              context.tr('ct.chat.rmBuddy'),
              style: const TextStyle(
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
              title: Text(context.tr('bd.delchat')),
              content: Text(context.tr('bd.delchat.q', {'n': displayName})),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(context.tr('bd.cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(context.tr('bd.delete'),
                      style: const TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
          return confirm ?? false;
        }
        return false;
      },
      onDismissed: (direction) {
        _removeBuddy(conv, buddyToo: false);
      },
      child: GestureDetector(
        onTap: () async {
          if (!mounted) return;

          if (conv.type == ConversationType.buddy) {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BuddyChatScreen(conversation: conv),
              ),
            );

            if (!mounted) return;

            if (result == true) {
              setState(() {
                _conversations.removeWhere((c) => c.id == conv.id);
              });
            }
            await _loadData();
          } else if (conv.type == ConversationType.squad) {
            if (!mounted) return;

            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SquadChatScreen(conversation: conv),
              ),
            );

            if (!mounted) return;
            await _loadData();
          } else if (conv.type == ConversationType.ai) {
            if (!mounted) return;

            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AIChatScreen()),
            );
          } else {
            if (!mounted) return;

            await Navigator.push(
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
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: _cardShadow(theme),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildAvatar(conv, displayName, isBuddy, isArena, theme),
                  if (isBuddy && conv.isBuddyOnline)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2ECC71),
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.cardColor, width: 3),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: theme.textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _ago(conv.lastMessageAt),
                          style: TextStyle(
                              fontSize: 12, color: theme.textSecondaryColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMessage,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: conv.unreadCount > 0
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              color: conv.unreadCount > 0
                                  ? theme.textColor
                                  : theme.textSecondaryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conv.unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(minWidth: 22),
                            height: 22,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Text(
                              conv.unreadCount > 99 ? '99+' : '${conv.unreadCount}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: theme.onPrimaryColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (isBuddy)
                IconButton(
                  onPressed: () => _showBuddyOptions(conv, primaryColor),
                  icon: const Icon(Icons.more_vert, size: 18),
                  color: theme.textSecondaryColor,
                  padding: const EdgeInsetsDirectional.only(start: 6),
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(Conversation conv, String name, bool isBuddy,
      bool isArena, ThemeProvider theme) {
    final tone = theme.tone(_tones[conv.id.hashCode.abs() % _tones.length]);
    final url = conv.avatarUrl;
    return GestureDetector(
      onTap: (!isArena && url != null && url.isNotEmpty)
          ? () => showAvatarViewer(context, url)
          : null,
      child: Container(
      width: 52,
      height: 52,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: tone.bg, shape: BoxShape.circle),
      child: (!isArena && url != null && url.isNotEmpty)
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _avatarFallback(name, tone),
            )
          : isBuddy
              ? _avatarFallback(name, tone)
              : Icon(
                  isArena ? Icons.campaign_rounded : Icons.groups_rounded,
                  size: 26,
                  color: tone.fg,
                ),
    ));
  }

  Widget _avatarFallback(String name, ToneColors tone) => Center(
        child: Text(
          name.isNotEmpty ? name.characters.first : '?',
          style: TextStyle(
              fontSize: 21, fontWeight: FontWeight.w800, color: tone.fg),
        ),
      );

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

  void _showNewConversationDialog(ThemeProvider theme, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      backgroundColor: theme.cardColor,
      builder: (context) => SafeArea(top: false, child: Builder(builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: theme.borderColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  context.tr('ct.chat.newChat'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 10),
                _buildOptionTile(
                  icon: Icons.person_add_alt_1_rounded,
                  title: context.tr('ct.chat.newBuddy'),
                  subtitle: context.tr('ct.chat.nobuddy.sub'),
                  tone: Tone.sky,
                  onTap: () {
                    Navigator.pop(context);
                    _showBuddyFinder();
                  },
                  theme: theme,
                ),
                _buildOptionTile(
                  icon: Icons.group_add_rounded,
                  title: context.tr('ct.chat.newGroup'),
                  subtitle: context.tr('ct.chat.newGroup.sub'),
                  tone: Tone.mint,
                  onTap: () {
                    Navigator.pop(context);
                    _showCreateSquadDialog(theme, primaryColor);
                  },
                  theme: theme,
                ),
                _buildOptionTile(
                  icon: Icons.vpn_key_rounded,
                  title: context.tr('ct.chat.joinGroup'),
                  subtitle: context.tr('ct.chat.joinGroup.sub'),
                  tone: Tone.butter,
                  onTap: () {
                    Navigator.pop(context);
                    _showJoinSquadDialog(primaryColor);
                  },
                  theme: theme,
                ),
              ],
            ),
          ),
        );
      })),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Tone tone,
    required VoidCallback onTap,
    required ThemeProvider theme,
  }) {
    final t = theme.tone(tone);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: t.bg, shape: BoxShape.circle),
              child: Icon(icon, color: t.fg, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: theme.textColor)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: theme.textSecondaryColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBuddyFinder() async {
    // بعد به صفحه هم‌مسیرها برو
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BuddyFinderScreen()),
    );

    if (!mounted) return;

    // اگه تغییری اعمال شد، داده‌ها رو reload کن
    if (result == true) {
      // صبر کن تا صفحه قبلی کامل بشه
      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        _loadData();
      }
    }
  }

  void _msg(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: error ? Colors.red : null,
      duration: const Duration(seconds: 2),
    ));
  }

  void _showCreateSquadDialog(ThemeProvider theme, Color primaryColor) {
    final nameC = TextEditingController();
    final descC = TextEditingController();
    bool isPublic = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: theme.cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text(context.tr('ct.chat.newGroup'), style: TextStyle(color: theme.textColor)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameC,
                  maxLength: 40,
                  decoration: InputDecoration(labelText: context.tr('ct.chat.groupName')),
                ),
                TextField(
                  controller: descC,
                  maxLength: 200,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: context.tr('ct.chat.groupDesc')),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.tr('ct.chat.public')),
                  subtitle: Text(context.tr('ct.chat.public.sub')),
                  value: isPublic,
                  onChanged: (v) => setD(() => isPublic = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.tr('bd.cancel'))),
            TextButton(
              onPressed: () async {
                final n = nameC.text.trim();
                if (n.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await _chatService.createGroup(
                    name: n,
                    description: descC.text.trim().isEmpty ? null : descC.text.trim(),
                    isPublic: isPublic,
                  );
                  _msg(context.tr('ct.chat.created'));
                  _loadData();
                } catch (e) {
                  _msg(_chatService.groupErrorText(e), error: true);
                }
              },
              child: Text(context.tr('ct.chat.create')),
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinSquadDialog(Color primaryColor) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final codeC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(context.tr('ct.chat.joinGroup'), style: TextStyle(color: theme.textColor)),
        content: TextField(
          controller: codeC,
          textDirection: TextDirection.ltr,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(labelText: context.tr('ct.chat.code')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(context.tr('bd.cancel'))),
          TextButton(
            onPressed: () async {
              final c = codeC.text.trim();
              if (c.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _chatService.joinGroupByCode(c);
                _msg(context.tr('ct.chat.joined'));
                _loadData();
              } catch (e) {
                _msg(_chatService.groupErrorText(e), error: true);
              }
            },
            child: Text(context.tr('ct.chat.join')),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays > 7) {
      return context.tr('ct.ago.week', {'n': '${diff.inDays ~/ 7}'});
    } else if (diff.inDays > 0) {
      return context.tr('ct.ago.day', {'n': '${diff.inDays}'});
    } else if (diff.inHours > 0) {
      return context.tr('ct.ago.hour', {'n': '${diff.inHours}'});
    } else if (diff.inMinutes > 0) {
      return context.tr('ct.ago.min', {'n': '${diff.inMinutes}'});
    } else {
      return context.tr('ct.ago.moments');
    }
  }
}
