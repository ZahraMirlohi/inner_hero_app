// lib/features/chat/models/message_model.dart

import 'package:flutter/material.dart';

enum MessageType { text, image, sticker, gif, file, system }

enum MessageStatus { sending, sent, delivered, seen, failed }

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String? senderName;
  final String? senderAvatar;
  final String content;
  final MessageType type;
  MessageStatus status;
  final Map<String, dynamic>? metadata;
  final bool isRead;
  final bool isEdited;
  final bool isDeleted;
  final String? replyToId;
  final ChatMessage? replyTo;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final bool isTemp;
  // ✅ اضافه کردن لیست واکنش‌ها (برای نمایش در UI)
  final List<MessageReaction>? reactions;
  final List<String> hiddenFor;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.senderName,
    this.senderAvatar,
    required this.content,
    this.type = MessageType.text,
    this.status = MessageStatus.sent,
    this.metadata,
    this.isRead = false,
    this.isEdited = false,
    this.isDeleted = false,
    this.replyToId,
    this.replyTo,
    this.reactions,
    required this.createdAt,
    this.editedAt,
    this.deletedAt,
    this.isTemp = false,
    this.hiddenFor = const [],
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      conversationId: map['conversation_id'],
      senderId: map['sender_id'],
      senderName: map['sender_name'] as String?,
      senderAvatar: map['sender_avatar'],
      content: map['content'],
      type: MessageType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => MessageType.text,
      ),
      status: MessageStatus.values.firstWhere(
        (e) => e.toString().split('.').last == (map['status'] ?? 'sent'),
        orElse: () => MessageStatus.sent,
      ),
      hiddenFor: List<String>.from(map['hidden_for'] ?? []),
      metadata: map['metadata'] as Map<String, dynamic>?,
      isRead: map['is_read'] ?? false,
      isEdited: map['is_edited'] ?? false,
      isDeleted: map['is_deleted'] ?? false,
      replyToId: map['reply_to_id'],
      replyTo: null,
      reactions: null, // در آینده از جدول جداگانه پر میشود
      createdAt: DateTime.parse(map['created_at']),
      editedAt: map['edited_at'] != null
          ? DateTime.parse(map['edited_at'])
          : null,
      deletedAt: map['deleted_at'] != null
          ? DateTime.parse(map['deleted_at'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_avatar': senderAvatar,
      'content': content,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'metadata': metadata,
      'is_read': isRead,
      'is_edited': isEdited,
      'is_deleted': isDeleted,
      'reply_to_id': replyToId,
      'hidden_for': hiddenFor,
      'created_at': createdAt.toIso8601String(),
      'edited_at': editedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  bool get isFromMe => senderId == 'me';
  bool get isFromAI => false;
  bool get isSystem => type == MessageType.system;
  bool get isReply => replyToId != null;
  bool get canBeEdited => !isDeleted && type == MessageType.text && !isFromAI;
  bool get canBeDeleted => !isDeleted;
  bool get showEditedBadge => isEdited && !isDeleted;
  bool get isImage => type == MessageType.image;
  bool get isSticker => type == MessageType.sticker;
  bool get isGif => type == MessageType.gif;
}

// ✅ مدل جدید برای واکنش‌ها
class MessageReaction {
  final String userId;
  final String emoji;
  final String? userName;
  final DateTime createdAt;

  MessageReaction({
    required this.userId,
    required this.emoji,
    this.userName,
    required this.createdAt,
  });

  factory MessageReaction.fromMap(Map<String, dynamic> map) {
    return MessageReaction(
      userId: map['user_id'],
      emoji: map['emoji'],
      userName: map['user_name'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

// ✅ استیکرهای محبوب
class StickerData {
  static const List<String> stickers = [
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
    '😎',
    '🤩',
    '🥳',
    '💯',
    '🔥',
    '⚡',
    '💎',
    '🏆',
    '👑',
    '💪',
    '🤝',
    '❤️‍🔥',
    '✨',
    '🌟',
    '💫',
    '🌈',
  ];
}

// ✅ GIF‌های محبوب
class GifData {
  static const List<Map<String, String>> gifs = [
    {'name': 'سلام', 'url': 'https://media.giphy.com/media/...'},
    {'name': 'خنده', 'url': 'https://media.giphy.com/media/...'},
    {'name': 'تشویق', 'url': 'https://media.giphy.com/media/...'},
    {'name': 'عشق', 'url': 'https://media.giphy.com/media/...'},
  ];
}
