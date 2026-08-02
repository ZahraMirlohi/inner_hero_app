// lib/features/chat/screens/arena_chat_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/services/chat_service.dart';
import '/services/buddy_matcher_service.dart';
import '/providers/sync_provider.dart';
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
      'color': const Color(0xFF4A90E2),
    },
    {
      'type': 'achievement',
      'icon': Icons.emoji_events,
      'label': 'دستاورد',
      'color': const Color(0xFFFFA500),
    },
    {
      'type': 'question',
      'icon': Icons.help,
      'label': 'سوال',
      'color': const Color(0xFF9B59B6),
    },
    {
      'type': 'tip',
      'icon': Icons.lightbulb,
      'label': 'نکته',
      'color': const Color(0xFF2ECC71),
    },
    {
      'type': 'encouragement',
      'icon': Icons.favorite,
      'label': 'تشویق',
      'color': const Color(0xFFE74C3C),
    },
    {
      'type': 'celebration',
      'icon': Icons.celebration,
      'label': 'جشن',
      'color': const Color(0xFFFF6B6B),
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

  Future<void> _createPost() async {
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
        const SnackBar(
          content: Text('پست با موفقیت ارسال شد 🎉'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
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

  Widget _buildMessageBubble(ChatMessage message) {
    final isMe = message.isFromMe;
    final isDeleted = message.isDeleted;
    final isSystem = message.isSystem;

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
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
            borderRadius: BorderRadius.circular(12),
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
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 2, left: 4),
                child: Text(
                  message.senderName ?? 'کاربر',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFFFA500),
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFFFFA500) : Colors.white,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isMe
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                  bottomLeft: isMe
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: isMe ? Colors.white : const Color(0xFF1A1A2E),
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
                  color: isMe ? Colors.orange.shade100 : Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(FeedPost post) {
    final isPinned = post.isPinned;
    final typeInfo = _postTypes.firstWhere(
      (t) => t['type'] == post.type.toString().split('.').last,
      orElse: () => _postTypes[0],
    );
    final color = typeInfo['color'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isPinned ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isPinned
            ? Border.all(color: Colors.blue.shade300, width: 1.5)
            : Border.all(color: Colors.grey.shade200, width: 1),
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
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: 0.1),
                  child: Text(
                    post.userName?.substring(0, 1).toUpperCase() ?? '?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
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
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(typeInfo['icon'], size: 12, color: color),
                          const SizedBox(width: 4),
                          Text(
                            typeInfo['label'],
                            style: TextStyle(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(post.createdAt),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
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
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.push_pin, size: 12, color: Colors.blue),
                        SizedBox(width: 2),
                        Text(
                          'پین',
                          style: TextStyle(fontSize: 10, color: Colors.blue),
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
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFF1A1A2E),
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
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: post.metadata!.entries.map((entry) {
                    return Expanded(
                      child: Column(
                        children: [
                          Text(
                            entry.value.toString(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4A90E2),
                            ),
                          ),
                          Text(
                            _getMetadataLabel(entry.key),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
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
                            ? Colors.red
                            : Colors.grey.shade500,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        post.likesCount.toString(),
                        style: TextStyle(
                          fontSize: 13,
                          color: post.isLikedByUser
                              ? Colors.red
                              : Colors.grey.shade500,
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
                        color: Colors.grey.shade500,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        post.commentsCount.toString(),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
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
                    color: Colors.grey.shade500,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // بخش کامنت‌ها
          if (_selectedPostIdForComment == post.id)
            _buildCommentsSection(post.id),

          if (post.commentsCount > 0 && _selectedPostIdForComment != post.id)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: GestureDetector(
                onTap: () => _showComments(post.id),
                child: Text(
                  'مشاهده ${post.commentsCount} کامنت',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(String postId) {
    final comments = _commentsCache[postId] ?? [];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...comments.map((comment) {
            final isMe = comment['user_id'] == _userId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.grey.shade300,
                    child: Text(
                      (comment['name'] as String).substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
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
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          comment['content'],
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        Text(
                          _formatTime(comment['created_at'] as DateTime),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
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
                        color: Colors.grey.shade400,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            );
          }),

          // ورودی کامنت جدید
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'نظر خود را بنویسید...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
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
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFA500),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send, color: Colors.white, size: 18),
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
              child: const Text(
                'بستن',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerPicker() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              const Text(
                'استیکرها',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
                      borderRadius: BorderRadius.circular(8),
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

  Widget _buildPostInput() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // انتخاب نوع پست
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _postTypes.map((type) {
                final isSelected = _selectedPostType == type['type'];
                final color = type['color'] as Color;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPostType = type['type'];
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? color : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          type['icon'] as IconData,
                          size: 14,
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          type['label'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade600,
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

          // ورودی پست
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _postController,
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'پیشرفت امروز خود را به اشتراک بگذارید...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
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
                    onTap: _createPost,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFA500),
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
                    child: const Text(
                      'لغو',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
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

  Widget _buildChatTab() {
    return Column(
      children: [
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFFA500)),
                )
              : _messages.isEmpty
              ? _buildEmptyState(
                  'هنوز پیامی ارسال نشده است',
                  'اولین پیام را ارسال کنید',
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
                    return _buildMessageBubble(message);
                  },
                ),
        ),
        _buildInputBar(),
      ],
    );
  }

  Widget _buildFeedTab() {
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(
                        0xFFFFA500,
                      ).withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.add,
                        color: Color(0xFFFFA500),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'پیشرفت امروز خود را به اشتراک بگذارید...',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),

        if (_showPostInput) _buildPostInput(),

        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFFA500)),
                )
              : _posts.isEmpty
              ? _buildEmptyState(
                  'هنوز پستی وجود ندارد',
                  'اولین پست را ارسال کنید',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _posts.length,
                  itemBuilder: (context, index) {
                    return _buildPostCard(_posts[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showStickerPicker) _buildStickerPicker(),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
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
                  icon: const Icon(Icons.emoji_emotions_outlined),
                  color: Colors.grey.shade600,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),

                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: 'پیام خود را بنویسید...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
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
                        : const Color(0xFFFFA500),
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
                        : const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFFA500).withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.stadium_outlined,
              size: 48,
              color: Color(0xFFFFA500),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ==================== اطلاعات چالش ====================

  Widget _buildChallengeInfoCard() {
    if (_challengeInfo == null) return const SizedBox.shrink();

    final info = _challengeInfo!;
    final progress = info['current_day'] as int? ?? 0;
    final total = info['duration'] as int? ?? 30;
    final progressPercent = total > 0 ? progress / total : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFA500), Color(0xFFFF6B6B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        // ✅ boxShadow باید داخل decoration باشد
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFA500).withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info['title'] ?? 'چالش',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${info['total_participants'] ?? 0} شرکت‌کننده',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
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
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              Text(
                '${total - progress} روز باقی‌مانده',
                style: TextStyle(
                  fontSize: 12,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildChallengeInfoCard(),

          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFFFA500),
              indicatorWeight: 3,
              labelColor: const Color(0xFFFFA500),
              unselectedLabelColor: Colors.grey.shade500,
              tabs: const [
                Tab(icon: Icon(Icons.chat), text: 'چت'),
                Tab(icon: Icon(Icons.article), text: 'فید'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildChatTab(), _buildFeedTab()],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Column(
        children: [
          Text(
            widget.conversation.displayName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Text(
            '🔥 ${_challengeInfo?['total_participants'] ?? 0} شرکت‌کننده',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      foregroundColor: const Color(0xFF1A1A2E),
      actions: [
        IconButton(
          icon: const Icon(Icons.emoji_events),
          onPressed: _showLeaderboard,
        ),
      ],
    );
  }

  void _showLeaderboard() {
    if (_challengeInfo == null) return;

    final leaderboard = _challengeInfo!['leaderboard'] as List? ?? [];

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
                  '🏆 جدول رده‌بندی',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                          ? Colors.amber.withValues(alpha: 0.1)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isTop3 ? Colors.amber : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: isTop3 ? Colors.amber : Colors.grey.shade300,
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
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFFA500,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${item['progress'] ?? 0} روز',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFFA500),
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
