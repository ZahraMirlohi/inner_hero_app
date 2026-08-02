// lib/features/chat/models/conversation_model.dart

enum ConversationType { buddy, squad, arena, ai }

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
  final String? lastMessage;
  final int unreadCount;
  final List<String> memberIds;
  final String? avatarUrl;
  final DateTime? buddyLastSeen;

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
    this.buddyLastSeen,
  });

  // ✅ displayName با اولویت name
  String get displayName {
    if (name != null && name!.isNotEmpty) {
      return name!;
    }

    // ✅ استفاده از switch با پوشش همه موارد + default
    switch (type) {
      case ConversationType.buddy:
        return 'هم‌مسیر';
      case ConversationType.squad:
        return 'گروه';
      case ConversationType.arena:
        return 'میدان';
      case ConversationType.ai:
        return 'مربی هوش مصنوعی';
    }
  }

  String get iconEmoji {
    // ✅ استفاده از switch با پوشش همه موارد
    switch (type) {
      case ConversationType.buddy:
        return '👤';
      case ConversationType.squad:
        return '👥';
      case ConversationType.arena:
        return '🏟️';
      case ConversationType.ai:
        return '🤖';
    }
  }

  // ✅ وضعیت آنلاین کاربر مقابل
  bool get isBuddyOnline {
    if (buddyLastSeen == null) return false;
    final now = DateTime.now();
    final diff = now.difference(buddyLastSeen!);
    return diff.inMinutes < 5;
  }

  // ✅ متن وضعیت آنلاین
  String get buddyStatusText {
    if (isBuddyOnline) {
      return 'آنلاین 🟢';
    }
    if (buddyLastSeen != null) {
      return 'آخرین بازدید: ${_formatTimeAgo(buddyLastSeen!)}';
    }
    return 'آفلاین';
  }

  String _formatTimeAgo(DateTime time) {
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
