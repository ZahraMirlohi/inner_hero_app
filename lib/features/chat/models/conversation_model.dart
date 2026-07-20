// lib/features/chat/models/conversation_model.dart

class Conversation {
  final String id;
  final ConversationType type;
  final String? name;
  final String? createdBy;
  final String? squadId;
  final String? challengeId;
  final bool isActive;
  final DateTime lastMessageAt;
  final DateTime createdAt;

  // اطلاعات اضافی برای نمایش
  final String? lastMessage;
  final int unreadCount;
  final List<String> memberIds;
  final String? avatarUrl;

  Conversation({
    required this.id,
    required this.type,
    this.name,
    this.createdBy,
    this.squadId,
    this.challengeId,
    this.isActive = true,
    required this.lastMessageAt,
    required this.createdAt,
    this.lastMessage,
    this.unreadCount = 0,
    this.memberIds = const [],
    this.avatarUrl,
  });

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'],
      type: ConversationType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => ConversationType.buddy,
      ),
      name: map['name'],
      createdBy: map['created_by'],
      squadId: map['squad_id'],
      challengeId: map['challenge_id'],
      isActive: map['is_active'] ?? true,
      lastMessageAt: DateTime.parse(map['last_message_at']),
      createdAt: DateTime.parse(map['created_at']),
      memberIds: List<String>.from(map['member_ids'] ?? []),
      avatarUrl: map['avatar_url'],
    );
  }

  String get displayName {
    if (name != null && name!.isNotEmpty) return name!;
    if (type == ConversationType.ai) return 'مربی هوش مصنوعی';
    if (type == ConversationType.buddy) return 'هم‌مسیر';
    if (type == ConversationType.squad) return 'گروه';
    return 'گفتگو';
  }

  String get iconEmoji {
    switch (type) {
      case ConversationType.ai:
        return '🤖';
      case ConversationType.buddy:
        return '👤';
      case ConversationType.squad:
        return '👥';
      case ConversationType.arena:
        return '🏟️';
    }
  }
}

enum ConversationType { buddy, squad, arena, ai }
