// lib/features/chat/models/feed_post_model.dart

class FeedPost {
  final String id;
  final String challengeId;
  final String userId;
  final String? userName;
  final String? userAvatar;
  final PostType type;
  final String content;
  final Map<String, dynamic>? metadata;
  final int likesCount;
  final int commentsCount;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  bool isLikedByUser;

  FeedPost({
    required this.id,
    required this.challengeId,
    required this.userId,
    this.userName,
    this.userAvatar,
    required this.type,
    required this.content,
    this.metadata,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
    this.isLikedByUser = false,
  });

  factory FeedPost.fromMap(Map<String, dynamic> map) {
    return FeedPost(
      id: map['id'],
      challengeId: map['challenge_id'],
      userId: map['user_id'],
      userName: map['user_name'],
      userAvatar: map['user_avatar'],
      type: PostType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => PostType.progress,
      ),
      content: map['content'],
      metadata: map['metadata'] as Map<String, dynamic>?,
      likesCount: map['likes_count'] ?? 0,
      commentsCount: map['comments_count'] ?? 0,
      isPinned: map['is_pinned'] ?? false,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      isLikedByUser: map['is_liked_by_user'] ?? false,
    );
  }

  String get typeEmoji {
    switch (type) {
      case PostType.progress:
        return '📊';
      case PostType.achievement:
        return '🏆';
      case PostType.question:
        return '❓';
      case PostType.tip:
        return '💡';
      case PostType.encouragement:
        return '💪';
      case PostType.celebration:
        return '🎉';
    }
  }

  String get typeLabel {
    switch (type) {
      case PostType.progress:
        return 'گزارش پیشرفت';
      case PostType.achievement:
        return 'دستاورد';
      case PostType.question:
        return 'سوال';
      case PostType.tip:
        return 'نکته';
      case PostType.encouragement:
        return 'تشویق';
      case PostType.celebration:
        return 'جشن';
    }
  }
}

enum PostType {
  progress,
  achievement,
  question,
  tip,
  encouragement,
  celebration,
}
