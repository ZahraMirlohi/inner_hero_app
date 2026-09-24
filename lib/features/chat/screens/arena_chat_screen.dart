// lib/features/chat/screens/arena_chat_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/services/chat_service.dart';
import '/services/buddy_matcher_service.dart';
import '/providers/sync_provider.dart';
import '/providers/theme_provider.dart';
import '../models/message_model.dart';
import '../models/conversation_model.dart';
import '../models/feed_post_model.dart';
import '../widgets/message_actions_menu.dart';

class ArenaChatScreen extends StatefulWidget {
  final Conversation conversation;

  const ArenaChatScreen({super.key, required this.conversation});

  @override
  State<ArenaChatScreen> createState() => _ArenaChatScreenState();
}

class _ArenaChatScreenState extends State<ArenaChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ChatService _chatService = ChatService();
  final BuddyMatcherService _matcherService = BuddyMatcherService();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _postController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  // ==================== داده‌ها ====================
  List<ChatMessage> _messages = [];
  List<FeedPost> _posts = [];
  List<Map<String, dynamic>> _participants = [];
  Map<String, dynamic>? _challengeInfo;
  bool _isLoading = true;
  bool _isSending = false;
  String? _userId;

  // ==================== وضعیت‌ها ====================
  bool _showPostInput = false;
  bool _showStickerPicker = false;
  String? _selectedPostIdForComment;
  Map<String, List<Map<String, dynamic>>> _commentsCache = {};

  // ==================== استیکرها ====================
  final List<String> _popularStickers = [
    '😊',
    '😂',
    '🤣',
    '❤️',
    '🔥',
    '💪',
    '🎉',
    '✨',
    '🌟',
    '⭐',
    '👏',
    '🙌',
    '🤗',
    '😍',
    '🥰',
    '😘',
  ];

  // ==================== انواع پست ====================
  final List<Map<String, dynamic>> _postTypes = [
    {
      'type': 'progress',
      'icon': Icons.trending_up,
      'label': 'پیشرفت',
    },
    {
      'type': 'achievement',
      'icon': Icons.emoji_events,
      'label': 'دستاورد',
    },
    {
      'type': 'question',
      'icon': Icons.help,
      'label': 'سوال',
    },
    {
      'type': 'tip',
      'icon': Icons.lightbulb,
      'label': 'نکته',
    },
    {
      'type': 'encouragement',
      'icon': Icons.favorite,
      'label': 'تشویق',
    },
    {
      'type': 'celebration',
      'icon': Icons.celebration,
      'label': 'جشن',
    },
  ];

  String _selectedPostType = 'progress';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _setupRealtimeSubscription();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _showStickerPicker = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _postController.dispose();
    _commentController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ==================== بارگذاری داده ====================
  Future<void> _loadData() async {
    final user = await _chatService.getCurrentUser();
    if (user != null) {
      setState(() {
        _userId = user.id;
      });

      _challengeInfo = await _getChallengeInfo(widget.conversation.challengeId);
      _participants = await _getChallengeParticipants(
        widget.conversation.challengeId,
      );
      _posts = await _getChallengePosts(widget.conversation.challengeId);

      final messages = await _chatService.getMessagesHistory(
        widget.conversation.id,
        limit: 30,
      );

      setState(() {
        _messages = messages.reversed.toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _getChallengeInfo(String? challengeId) async {
    return {
      'id': challengeId,
      'title': 'چالش ۳۰ روزه ورزش صبحگاهی',
      'description': 'هر روز ۲۰ دقیقه ورزش صبحگاهی انجام دهید',
      'duration': 30,
      'current_day': 15,
      'total_participants': 45,
      'xp_reward': 500,
      'start_date': DateTime.now().subtract(const Duration(days: 14)),
      'end_date': DateTime.now().add(const Duration(days: 15)),
      'leaderboard': [
        {'name': 'علی', 'progress': 28},
        {'name': 'سارا', 'progress': 26},
        {'name': 'رضا', 'progress': 25},
        {'name': 'مریم', 'progress': 24},
        {'name': 'حسین', 'progress': 22},
      ],
    };
  }

  Future<List<Map<String, dynamic>>> _getChallengeParticipants(
    String? challengeId,
  ) async {
    return [
      {'user_id': 'user1', 'name': 'علی', 'progress': 28, 'avatar': null},
      {'user_id': 'user2', 'name': 'سارا', 'progress': 26, 'avatar': null},
      {'user_id': 'user3', 'name': 'رضا', 'progress': 25, 'avatar': null},
      {'user_id': 'user4', 'name': 'مریم', 'progress': 24, 'avatar': null},
      {'user_id': 'user5', 'name': 'حسین', 'progress': 22, 'avatar': null},
    ];
  }

  Future<List<FeedPost>> _getChallengePosts(String? challengeId) async {
    return [
      FeedPost(
        id: '1',
        challengeId: challengeId ?? '',
        userId: 'user1',
        userName: 'علی',
        userAvatar: null,
        type: PostType.progress,
        content:
            'روز ۲۸ از ۳۰! امروز ۲۵ دقیقه ورزش کردم. احساس فوق‌العاده‌ای دارم! 💪',
        metadata: {'habits_completed': 28, 'total_habits': 30},
        likesCount: 12,
        commentsCount: 5,
        isPinned: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
        isLikedByUser: false,
      ),
      FeedPost(
        id: '2',
        challengeId: challengeId ?? '',
        userId: 'user2',
        userName: 'سارا',
        userAvatar: null,
        type: PostType.achievement,
        content:
            '🎉 امروز ۲۶ روز متوالی ورزش کردم! این بزرگترین دستاورد من است.',
        metadata: {'streak': 26, 'best_streak': 26},
        likesCount: 8,
        commentsCount: 3,
        isPinned: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
        isLikedByUser: true,
      ),
      FeedPost(
        id: '3',
        challengeId: challengeId ?? '',
        userId: 'user3',
        userName: 'رضا',
        userAvatar: null,
        type: PostType.question,
        content:
            'چه راهکاری برای بیدار شدن صبح زود دارید؟ من واقعاً مشکل دارم 😅',
        metadata: {},
        likesCount: 5,
        commentsCount: 8,
        isPinned: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 8)),
        isLikedByUser: false,
      ),
    ];
  }

  void _setupRealtimeSubscription() {
    _chatService.getMessages(widget.conversation.id).listen((newMessages) {
      if (mounted) {
        setState(() {
          _messages = newMessages.reversed.toList();
        });
      }
    });
  }

  // ==================== ارسال پیام ====================
  Future<void> _sendMessage({
    String? text,
    MessageType type = MessageType.text,
    Map<String, dynamic>? metadata,
  }) async {
    final content = text ?? _messageController.text.trim();
    if (content.isEmpty || _userId == null || _isSending) return;

    _messageController.clear();
    _focusNode.unfocus();
    setState(() {
      _isSending = true;
      _showStickerPicker = false;
    });

    try {
      await _chatService.sendMessage(
        conversationId: widget.conversation.id,
        senderId: _userId!,
        content: content,
        type: type.toString().split('.').last,
        metadata: metadata,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در ارسال پیام: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  // ==================== مدیریت پست‌ها ====================
  Future<void> _createPost(Color primaryColor) async {
    final content = _postController.text.trim();
    if (content.isEmpty || _userId == null) return;

    setState(() {
      _isSending = true;
    });

    try {
      final newPost = FeedPost(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        challengeId: widget.conversation.challengeId ?? '',
        userId: _userId!,
        userName: 'من',
        userAvatar: null,
        type: PostType.values.firstWhere(
          (e) => e.toString().split('.').last == _selectedPostType,
          orElse: () => PostType.progress,
        ),
        content: content,
        metadata: {},
        likesCount: 0,
        commentsCount: 0,
        isPinned: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isLikedByUser: false,
      );

      setState(() {
        _posts.insert(0, newPost);
        _postController.clear();
        _showPostInput = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('پست با موفقیت ارسال شد 🎉'),
          backgroundColor: primaryColor,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _toggleLike(String postId) async {
    setState(() {
      final index = _posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        final post = _posts[index];
        if (post.isLikedByUser) {
          _posts[index] = FeedPost(
            id: post.id,
            challengeId: post.challengeId,
            userId: post.userId,
            userName: post.userName,
            userAvatar: post.userAvatar,
            type: post.type,
            content: post.content,
            metadata: post.metadata,
            likesCount: post.likesCount - 1,
            commentsCount: post.commentsCount,
            isPinned: post.isPinned,
            createdAt: post.createdAt,
            updatedAt: DateTime.now(),
            isLikedByUser: false,
          );
        } else {
          _posts[index] = FeedPost(
            id: post.id,
            challengeId: post.challengeId,
            userId: post.userId,
            userName: post.userName,
            userAvatar: post.userAvatar,
            type: post.type,
            content: post.content,
            metadata: post.metadata,
            likesCount: post.likesCount + 1,
            commentsCount: post.commentsCount,
            isPinned: post.isPinned,
            createdAt: post.createdAt,
            updatedAt: DateTime.now(),
            isLikedByUser: true,
          );
        }
      }
    });
  }

  void _showComments(String postId) {
    setState(() {
      _selectedPostIdForComment = postId;
      if (!_commentsCache.containsKey(postId)) {
        _commentsCache[postId] = [
          {
            'user_id': 'user1',
            'name': 'علی',
            'content': 'عالی! ادامه بده 💪',
            'created_at': DateTime.now().subtract(const Duration(minutes: 10)),
          },
          {
            'user_id': 'user2',
            'name': 'سارا',
            'content': 'منم همین مشکل رو دارم 😅',
            'created_at': DateTime.now().subtract(const Duration(minutes: 5)),
          },
        ];
      }
    });
  }

  Future<void> _addComment(String postId) async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _userId == null) return;

    final newComment = {
      'user_id': _userId,
      'name': 'من',
      'content': content,
      'created_at': DateTime.now(),
    };

    setState(() {
      if (_commentsCache.containsKey(postId)) {
        _commentsCache[postId]!.insert(0, newComment);
      } else {
        _commentsCache[postId] = [newComment];
      }

      final index = _posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        final post = _posts[index];
        _posts[index] = FeedPost(
          id: post.id,
          challengeId: post.challengeId,
          userId: post.userId,
          userName: post.userName,
          userAvatar: post.userAvatar,
          type: post.type,
          content: post.content,
          metadata: post.metadata,
          likesCount: post.likesCount,
          commentsCount: post.commentsCount + 1,
          isPinned: post.isPinned,
          createdAt: post.createdAt,
          updatedAt: DateTime.now(),
          isLikedByUser: post.isLikedByUser,
        );
      }

      _commentController.clear();
    });
  }

  // ==================== ویجت‌ها ====================
  Widget _buildMessageBubble(
    ChatMessage message,
    ThemeProvider theme,
    Color primaryColor,
  ) {
    final isMe = message.isFromMe;
    final isDeleted = message.isDeleted;
    final isSystem = message.isSystem;

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          message.content,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    if (isDeleted) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'این پیام حذف شده است',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 2, left: 4),
                child: Text(
                  message.senderName ?? 'کاربر',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF090909) : theme.surfaceColor,
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
                  color: isMe ? Colors.white : theme.textColor,
                  fontSize: 14,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _formatTime(message.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? Colors.white70 : theme.textSecondaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(
    FeedPost post,
    ThemeProvider theme,
    Color primaryColor,
  ) {
    final isPinned = post.isPinned;
    final typeInfo = _postTypes.firstWhere(
      (t) => t['type'] == post.type.toString().split('.').last,
      orElse: () => _postTypes[0],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isPinned
            ? primaryColor.withValues(alpha: 0.06)
            : theme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPinned ? primaryColor : primaryColor.withValues(alpha: 0.1),
          width: isPinned ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // هدر پست
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      post.userName?.substring(0, 1).toUpperCase() ?? '?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userName ?? 'کاربر',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.textColor,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            typeInfo['icon'],
                            size: 12,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            typeInfo['label'],
                            style: TextStyle(
                              fontSize: 11,
                              color: primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(post.createdAt),
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isPinned)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.push_pin,
                          size: 12,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'پین',
                          style: TextStyle(
                            fontSize: 10,
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // محتوای پست
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              post.content,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: theme.textColor,
              ),
            ),
          ),

          // متادیتا
          if (post.metadata != null && post.metadata!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: post.metadata!.entries.map((entry) {
                    return Expanded(
                      child: Column(
                        children: [
                          Text(
                            entry.value.toString(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          Text(
                            _getMetadataLabel(entry.key),
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // دکمه‌های تعامل
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleLike(post.id),
                  child: Row(
                    children: [
                      Icon(
                        post.isLikedByUser
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: post.isLikedByUser
                            ? primaryColor
                            : theme.textSecondaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        post.likesCount.toString(),
                        style: TextStyle(
                          fontSize: 13,
                          color: post.isLikedByUser
                              ? primaryColor
                              : theme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: () => _showComments(post.id),
                  child: Row(
                    children: [
                      Icon(
                        Icons.comment_outlined,
                        color: theme.textSecondaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        post.commentsCount.toString(),
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('اشتراک‌گذاری به زودی اضافه می‌شود'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.share_outlined,
                    color: theme.textSecondaryColor,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // کامنت‌ها
          if (_selectedPostIdForComment == post.id)
            _buildCommentsSection(post.id, theme, primaryColor),

          if (post.commentsCount > 0 && _selectedPostIdForComment != post.id)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              child: GestureDetector(
                onTap: () => _showComments(post.id),
                child: Text(
                  'مشاهده ${post.commentsCount} کامنت',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textSecondaryColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(
    String postId,
    ThemeProvider theme,
    Color primaryColor,
  ) {
    final comments = _commentsCache[postId] ?? [];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.04),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...comments.map((comment) {
            final isMe = comment['user_id'] == _userId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        (comment['name'] as String)
                            .substring(0, 1)
                            .toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comment['name'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.textColor,
                          ),
                        ),
                        Text(
                          comment['content'],
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.textColor,
                          ),
                        ),
                        Text(
                          _formatTime(comment['created_at'] as DateTime),
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isMe)
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _commentsCache[postId]!.remove(comment);
                        });
                      },
                      icon: Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: theme.textSecondaryColor,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            );
          }),

          // ورودی کامنت
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'نظر خود را بنویسید...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: theme.textSecondaryColor,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _addComment(postId),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _addComment(postId),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.send,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),

          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _selectedPostIdForComment = null;
                });
              },
              child: Text(
                'بستن',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.textSecondaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerPicker(ThemeProvider theme) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'استیکرها',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.textColor,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _showStickerPicker = false;
                  });
                },
                icon: const Icon(Icons.close, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                childAspectRatio: 1,
              ),
              itemCount: _popularStickers.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    _sendMessage(
                      text: _popularStickers[index],
                      type: MessageType.sticker,
                    );
                    setState(() {
                      _showStickerPicker = false;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _popularStickers[index],
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostInput(ThemeProvider theme, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _postTypes.map((type) {
                final isSelected = _selectedPostType == type['type'];

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPostType = type['type'];
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primaryColor
                          : primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? null
                          : Border.all(
                              color: primaryColor.withValues(alpha: 0.2),
                            ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          type['icon'] as IconData,
                          size: 14,
                          color: isSelected ? Colors.white : primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          type['label'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? Colors.white : primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _postController,
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'پیشرفت امروز خود را به اشتراک بگذارید...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: theme.textSecondaryColor,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  GestureDetector(
                    onTap: () => _createPost(primaryColor),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showPostInput = false;
                      });
                    },
                    child: Text(
                      'لغو',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textSecondaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== تب‌ها ====================
  Widget _buildChatTab(ThemeProvider theme, Color primaryColor) {
    return Column(
      children: [
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: primaryColor),
                )
              : _messages.isEmpty
                  ? _buildEmptyState(
                      'هنوز پیامی ارسال نشده است',
                      'اولین پیام را ارسال کنید',
                      theme,
                      primaryColor,
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[_messages.length - 1 - index];
                        return _buildMessageBubble(
                          message,
                          theme,
                          primaryColor,
                        );
                      },
                    ),
        ),
        _buildInputBar(theme, primaryColor),
      ],
    );
  }

  Widget _buildFeedTab(ThemeProvider theme, Color primaryColor) {
    return Column(
      children: [
        if (!_showPostInput)
          Padding(
            padding: const EdgeInsets.all(12),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showPostInput = true;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'پیشرفت امروز خود را به اشتراک بگذارید...',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_showPostInput) _buildPostInput(theme, primaryColor),
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: primaryColor),
                )
              : _posts.isEmpty
                  ? _buildEmptyState(
                      'هنوز پستی وجود ندارد',
                      'اولین پست را ارسال کنید',
                      theme,
                      primaryColor,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _posts.length,
                      itemBuilder: (context, index) {
                        return _buildPostCard(
                          _posts[index],
                          theme,
                          primaryColor,
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildInputBar(ThemeProvider theme, Color primaryColor) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showStickerPicker) _buildStickerPicker(theme),
          Container(
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
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showStickerPicker = !_showStickerPicker;
                    });
                  },
                  icon: Icon(
                    _showStickerPicker
                        ? Icons.keyboard
                        : Icons.emoji_emotions_outlined,
                    color: _showStickerPicker
                        ? primaryColor
                        : theme.textSecondaryColor,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(24),
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
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      maxLines: 4,
                      minLines: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isSending || _messageController.text.isEmpty
                        ? Colors.grey.shade300
                        : primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: (_isSending || _messageController.text.isEmpty)
                        ? null
                        : () => _sendMessage(),
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    String title,
    String subtitle,
    ThemeProvider theme,
    Color primaryColor,
  ) {
    return Center(
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
              Icons.stadium_outlined,
              size: 48,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
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
          ),
        ],
      ),
    );
  }

  // ==================== اطلاعات چالش ====================
  Widget _buildChallengeInfoCard(ThemeProvider theme, Color primaryColor) {
    if (_challengeInfo == null) return const SizedBox.shrink();

    final info = _challengeInfo!;
    final progress = info['current_day'] as int? ?? 0;
    final total = info['duration'] as int? ?? 30;
    final progressPercent = total > 0 ? progress / total : 0.0;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.flag,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info['title'] ?? 'چالش',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${info['total_participants'] ?? 0} شرکت‌کننده',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(progressPercent * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressPercent.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              color: Colors.white,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'روز $progress از $total',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              Text(
                '${total - progress} روز باقی‌مانده',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== Main Build ====================
  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(theme, primaryColor),
      body: Column(
        children: [
          _buildChallengeInfoCard(theme, primaryColor),

          // تب‌های دور گرد مشکی
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                Tab(height: 42, icon: Icon(Icons.chat, size: 16), text: 'چت'),
                Tab(
                  height: 42,
                  icon: Icon(Icons.article, size: 16),
                  text: 'فید',
                ),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChatTab(theme, primaryColor),
                _buildFeedTab(theme, primaryColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    ThemeProvider theme,
    Color primaryColor,
  ) {
    return AppBar(
      title: Column(
        children: [
          Text(
            widget.conversation.displayName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.textColor,
            ),
          ),
          Text(
            '🔥 ${_challengeInfo?['total_participants'] ?? 0} شرکت‌کننده',
            style: TextStyle(
              fontSize: 11,
              color: theme.textSecondaryColor,
            ),
          ),
        ],
      ),
      backgroundColor: theme.surfaceColor,
      elevation: 0,
      foregroundColor: theme.textColor,
      actions: [
        IconButton(
          icon: Icon(Icons.emoji_events, color: primaryColor),
          onPressed: () => _showLeaderboard(theme, primaryColor),
        ),
      ],
    );
  }

  void _showLeaderboard(ThemeProvider theme, Color primaryColor) {
    if (_challengeInfo == null) return;

    final leaderboard = _challengeInfo!['leaderboard'] as List? ?? [];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: theme.surfaceColor,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events, color: primaryColor, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'جدول رده‌بندی',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...leaderboard.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isTop3 = index < 3;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isTop3
                          ? primaryColor.withValues(alpha: 0.08)
                          : primaryColor.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isTop3
                            ? primaryColor.withValues(alpha: 0.3)
                            : primaryColor.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isTop3 ? primaryColor : Colors.grey.shade300,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isTop3
                                    ? Colors.white
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item['name'] ?? 'کاربر',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: theme.textColor,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${item['progress'] ?? 0} روز',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== متدهای کمکی ====================
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

  String _getMetadataLabel(String key) {
    switch (key) {
      case 'habits_completed':
        return 'عادت انجام شده';
      case 'total_habits':
        return 'کل عادت‌ها';
      case 'streak':
        return 'استریک';
      case 'best_streak':
        return 'بهترین استریک';
      default:
        return key;
    }
  }
}
