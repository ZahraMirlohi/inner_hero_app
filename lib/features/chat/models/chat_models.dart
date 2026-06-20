import 'package:flutter/material.dart';

enum ChatType { buddy, squad, arena }

enum MessageType { text, encouragement, progress, system, ai }

class ConversationModel {
  String id;
  String name;
  ChatType type;
  String? avatarUrl;
  String lastMessage;
  DateTime lastMessageTime;
  int unreadCount;
  List<String> participants;
  String? squadId; // برای گروه‌ها
  String? challengeId; // برای چالش‌ها
  double? weeklyProgress; // برای گروه‌ها
  int? maxMembers; // برای گروه‌ها
  bool isAiAvailable; // برای چت با هوش مصنوعی

  ConversationModel({
    required this.id,
    required this.name,
    required this.type,
    this.avatarUrl,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.participants = const [],
    this.squadId,
    this.challengeId,
    this.weeklyProgress,
    this.maxMembers,
    this.isAiAvailable = false,
  });
}

class ChatMessageModel {
  String id;
  String conversationId;
  String senderId;
  String senderName;
  String? senderAvatar;
  String message;
  MessageType messageType;
  DateTime sentAt;
  bool isRead;
  Map<String, dynamic>? metadata; // برای کارت پیشرفت، تشویق و غیره

  ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.message,
    this.messageType = MessageType.text,
    required this.sentAt,
    this.isRead = false,
    this.metadata,
  });
}

class SquadModel {
  String id;
  String name;
  String icon;
  Color color;
  List<String> members;
  String? weeklyChallenge;
  double weeklyProgress;
  int totalXPEarned;
  DateTime createdAt;
  String inviteCode;

  SquadModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.members,
    this.weeklyChallenge,
    this.weeklyProgress = 0,
    this.totalXPEarned = 0,
    required this.createdAt,
    required this.inviteCode,
  });
}

class ArenaChallengeModel {
  String id;
  String title;
  String description;
  DateTime startDate;
  DateTime endDate;
  int participants;
  int totalXPPool;
  Map<String, int> leaderboard;

  ArenaChallengeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    this.participants = 0,
    this.totalXPPool = 0,
    this.leaderboard = const {},
  });
}
