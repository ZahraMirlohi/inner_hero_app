import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/chat/models/message_model.dart';
import '../features/chat/models/conversation_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:mime/mime.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

class ChatService {
  final SupabaseClient _client = Supabase.instance.client;

  SupabaseClient get client => _client;

  // ==================== گفتگوها ====================
// lib/services/chat_service.dart

  Future<List<Conversation>> getUserConversations(String userId) async {
    try {
      // ✅ مرحله 1: گرفتن همه گفتگوهای فعال کاربر
      final conversationsResponse = await _client
          .from('conversation_members')
          .select('conversation_id')
          .eq('user_id', userId);

      if (conversationsResponse.isEmpty) {
        print('📊 No conversation memberships found for user: $userId');
        return [];
      }

      final conversationIds = conversationsResponse
          .map((m) => m['conversation_id'] as String)
          .toList();

      print('📊 User is member of ${conversationIds.length} conversations');

      // ✅ مرحله 2: گرفتن گفتگوهای فعال از بین این‌ها
      final activeConversationsResponse = await _client
          .from('conversations')
          .select()
          .inFilter('id', conversationIds)
          .eq('is_active', true)
          .order('last_message_at', ascending: false);

      print('📊 Active conversations: ${activeConversationsResponse.length}');

      if (activeConversationsResponse.isEmpty) {
        return [];
      }

      final activeConversationIds =
          activeConversationsResponse.map((c) => c['id'] as String).toList();

      // ✅ مرحله 3: گرفتن همه اعضای این گفتگوها با یک کوئری
      final allMembersResponse = await _client
          .from('conversation_members')
          .select('conversation_id, user_id')
          .inFilter('conversation_id', activeConversationIds);

      final Map<String, List<String>> membersByConv = {};
      for (var m in allMembersResponse) {
        final convId = m['conversation_id'] as String;
        final uid = m['user_id'] as String;
        membersByConv.putIfAbsent(convId, () => []).add(uid);
      }

      // ✅ مرحله 4: گرفتن همه پروفایل‌های اعضا با یک کوئری
      final allMemberIds = allMembersResponse
          .map((m) => m['user_id'] as String)
          .toSet()
          .toList();

      final profilesResponse = await _client
          .from('profiles')
          .select('user_id, name, avatar_url, updated_at, last_seen_at')
          .inFilter('user_id', allMemberIds);

      final Map<String, Map<String, dynamic>> profilesMap = {
        for (var p in profilesResponse) p['user_id'] as String: p,
      };

      // ✅ مرحله 5: گرفتن آخرین پیام هر گفتگو با یک کوئری
      final lastMessagesResponse = await _client
          .from('messages')
          .select('conversation_id, content, created_at, sender_id')
          .inFilter('conversation_id', activeConversationIds)
          .eq('is_deleted', false)
          .order('created_at', ascending: false);

      final Map<String, Map<String, dynamic>> lastMessageByConv = {};
      for (var msg in lastMessagesResponse) {
        final convId = msg['conversation_id'] as String;
        if (!lastMessageByConv.containsKey(convId)) {
          lastMessageByConv[convId] = msg;
        }
      }

      // ✅ مرحله 6: ساخت لیست نهایی
      final List<Conversation> conversations = [];

      for (var convData in activeConversationsResponse) {
        final conversationId = convData['id'] as String;
        final memberIds = membersByConv[conversationId] ?? [];

        // ✅ اگر بعد از همه چک‌ها، عضو کمتر از 2 بود، این گفتگو را رد کن
        if (memberIds.length < 2) {
          print(
              '⚠️ Skipping conversation $conversationId: only ${memberIds.length} members');
          continue;
        }

        // نوع گفتگو
        final typeStr = convData['type'] as String? ?? 'buddy';
        final type = ConversationType.values.firstWhere(
          (e) => e.toString().split('.').last == typeStr,
          orElse: () => ConversationType.buddy,
        );

        // نام گفتگو
        String conversationName = '';
        String? buddyAvatar;
        DateTime? buddyLastSeen;

        if (type == ConversationType.buddy && memberIds.length >= 2) {
          final otherUserId = memberIds.firstWhere(
            (id) => id != userId,
            orElse: () => '',
          );

          if (otherUserId.isNotEmpty) {
            final profile = profilesMap[otherUserId];
            if (profile != null) {
              conversationName = profile['name'] as String? ?? 'کاربر';
              buddyAvatar = profile['avatar_url'] as String?;

              final lastSeen = profile['last_seen_at'] ?? profile['updated_at'];
              if (lastSeen != null) {
                buddyLastSeen = DateTime.tryParse(lastSeen);
              }
            } else {
              conversationName = 'کاربر ${otherUserId.substring(0, 6)}';
            }
          }
        }

        if (conversationName.isEmpty) {
          conversationName = convData['name'] as String? ?? '';
        }

        // آخرین پیام
        final lastMsg = lastMessageByConv[conversationId];
        String lastMessage = 'شروع گفتگو';
        DateTime lastMessageAt = DateTime.now();

        if (lastMsg != null) {
          lastMessage = lastMsg['content'] as String? ?? 'شروع گفتگو';
          lastMessageAt = DateTime.tryParse(lastMsg['created_at'] as String) ??
              DateTime.now();
        }

        // تاریخ ایجاد
        DateTime createdAt;
        try {
          createdAt = DateTime.parse(convData['created_at'] as String);
        } catch (e) {
          createdAt = DateTime.now();
        }

        conversations.add(
          Conversation(
            id: conversationId,
            type: type,
            name: conversationName.isNotEmpty ? conversationName : null,
            createdBy: convData['created_by'] as String? ?? '',
            squadId: convData['squad_id'] as String?,
            challengeId: convData['challenge_id'] as String?,
            isActive: true,
            lastMessageAt: lastMessageAt,
            createdAt: createdAt,
            lastMessage: lastMessage,
            unreadCount: 0,
            memberIds: memberIds,
            avatarUrl: buddyAvatar,
            buddyLastSeen: buddyLastSeen,
          ),
        );
      }

      print('📊 Total conversations loaded: ${conversations.length}');
      for (var conv in conversations) {
        print(
            '   - ${conv.id}: ${conv.type} - ${conv.displayName} (${conv.memberIds.length} members) - Last: ${conv.lastMessage}');
      }

      return conversations;
    } catch (e) {
      print('❌ Error getting conversations: $e');
      return [];
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    try {
      // 1. دریافت اعضای گفتگو قبل از حذف
      final membersResponse = await _client
          .from('conversation_members')
          .select('user_id')
          .eq('conversation_id', conversationId);

      final memberIds =
          membersResponse.map((m) => m['user_id'] as String).toList();
      print('📊 Members in conversation: $memberIds');

      // 2. حذف پیام‌ها
      await _client
          .from('messages')
          .delete()
          .eq('conversation_id', conversationId);

      // 3. حذف اعضا
      await _client
          .from('conversation_members')
          .delete()
          .eq('conversation_id', conversationId);

      // 4. حذف گفتگو
      await _client.from('conversations').delete().eq('id', conversationId);

      // 5. ✅ حذف همه درخواست‌های هم‌مسیر بین این دو کاربر
      if (memberIds.length >= 2) {
        final user1 = memberIds[0];
        final user2 = memberIds[1];

        // ✅ حذف درخواست‌ها (همه وضعیت‌ها: pending, accepted, rejected)
        final deleteResult = await _client
            .from('buddy_requests')
            .delete()
            .or('from_user_id.eq.$user1,to_user_id.eq.$user1')
            .or('from_user_id.eq.$user2,to_user_id.eq.$user2');

        print('🗑️ Removed all buddy requests between $user1 and $user2');
        print('📊 Delete result: $deleteResult');
      }

      print('🗑️ Conversation and all related data deleted: $conversationId');
    } catch (e) {
      print('❌ Error deleting conversation: $e');
      rethrow;
    }
  }

  Future<String> createConversation({
    required String type,
    required List<String> memberIds,
    String? name,
    String? createdBy,
    String? squadId,
    String? challengeId,
  }) async {
    try {
      print('📊 ===== CREATE CONVERSATION START =====');

      // ✅ فقط چک کن کاربر وجود داره، بدون refresh اجباری
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('لطفاً دوباره وارد حساب کاربری شوید');
      }

      final actualCreatedBy = user.id;
      print('✅ Using actualCreatedBy: $actualCreatedBy');

      // ✅ 2. بررسی گفتگوی موجود
      try {
        final existingConversations =
            await getUserConversations(actualCreatedBy);
        for (var conv in existingConversations) {
          if (conv.type == ConversationType.buddy) {
            final allMembersExist =
                memberIds.every((id) => conv.memberIds.contains(id));
            if (allMembersExist) {
              print('ℹ️ Conversation already exists: ${conv.id}');
              return conv.id;
            }
          }
        }
      } catch (e) {
        print('⚠️ Error checking existing conversations: $e');
      }

      // ✅ 3. ایجاد گفتگو
      final now = DateTime.now().toIso8601String();

      final conversationData = <String, dynamic>{
        'type': type,
        'name': name,
        'created_by': actualCreatedBy,
        'squad_id': squadId,
        'challenge_id': challengeId,
        'is_active': true,
        'last_message_at': now,
      };

      print('📤 Inserting conversation: $conversationData');

      final conversationResponse = await _client
          .from('conversations')
          .insert(conversationData)
          .select()
          .single();

      final conversationId = conversationResponse['id'];
      print('✅ Conversation created: $conversationId');

      // ✅ 4. افزودن اعضا
      final List<Map<String, dynamic>> membersToInsert = [];
      for (var userId in memberIds) {
        if (userId.isNotEmpty) {
          membersToInsert.add({
            'conversation_id': conversationId,
            'user_id': userId,
            'role': userId == actualCreatedBy ? 'admin' : 'member',
            'joined_at': now,
          });
        }
      }

      if (membersToInsert.isEmpty) {
        await _client.from('conversations').delete().eq('id', conversationId);
        throw Exception('No valid members');
      }

      print('📤 Inserting members: $membersToInsert');

      try {
        await _client.from('conversation_members').insert(membersToInsert);
        print('✅ Members added successfully');
      } catch (e) {
        print('❌ Error adding members: $e');
        await _client.from('conversations').delete().eq('id', conversationId);
        rethrow;
      }

      print('✅ ===== CREATE CONVERSATION SUCCESS =====');
      return conversationId;
    } catch (e) {
      print('❌ ===== CREATE CONVERSATION ERROR =====');
      print('❌ Error: $e');
      rethrow;
    }
  }

// ✅ متد کمکی برای refresh اجباری session
  Future<void> _forceRefreshSession() async {
    final session = _client.auth.currentSession;

    if (session == null) {
      throw Exception('جلسه کاربری یافت نشد. لطفاً دوباره وارد شوید.');
    }

    if (session.isExpired) {
      print('⚠️ Session expired, forcing refresh...');
      try {
        await _client.auth.refreshSession();
        await Future.delayed(const Duration(milliseconds: 300));

        final newSession = _client.auth.currentSession;
        if (newSession == null || newSession.isExpired) {
          throw Exception('نشست شما منقضی شده. لطفاً دوباره وارد شوید.');
        }
        print('✅ Session refreshed successfully');
      } catch (e) {
        print('❌ Session refresh failed: $e');
        // خروج کاربر و هدایت به صفحه ورود
        await _client.auth.signOut();
        throw Exception('لطفاً دوباره وارد حساب کاربری شوید.');
      }
    }
  }

  // ==================== پیام‌ها ====================

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    String type = 'text',
    Map<String, dynamic>? metadata,
    String? replyToId,
    String? senderName,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'conversation_id': conversationId,
        'sender_id': senderId,
        'sender_name': senderName,
        'content': content,
        'type': type,
        'metadata': metadata ?? {},
        'reply_to_id': replyToId,
        'status': 'sent', // ✅ وضعیت اولیه sent
        'created_at': DateTime.now().toIso8601String(),
      };

      print('📤 [CHAT_SERVICE] Sending message...');
      print('   - type: $type');
      print('   - status: sent');

      final response = await _client.from('messages').insert(data).select();
      print('✅ [CHAT_SERVICE] Message inserted successfully!');

      await _client
          .from('conversations')
          .update({'last_message_at': DateTime.now().toIso8601String()}).eq(
              'id', conversationId);
    } catch (e) {
      print('🔴 [CHAT_SERVICE] Error inserting message: $e');
      rethrow;
    }
  }

  // ✅ پین کردن پیام
  Future<void> pinMessage({
    required String messageId,
    required String userId,
  }) async {
    try {
      // ✅ ابتدا پین قبلی را بردارید (فقط یک پیام می‌تواند پین شود)
      await _client
          .from('messages')
          .update({'is_pinned': false, 'pinned_at': null, 'pinned_by': null})
          .eq('conversation_id', await _getConversationIdByMessage(messageId))
          .eq('is_pinned', true);

      // ✅ پین کردن پیام جدید
      await _client.from('messages').update({
        'is_pinned': true,
        'pinned_at': DateTime.now().toIso8601String(),
        'pinned_by': userId,
      }).eq('id', messageId);

      print('📌 Message pinned: $messageId');
    } catch (e) {
      print('❌ Error pinning message: $e');
      rethrow;
    }
  }

  // ✅ لغو پین پیام
  Future<void> unpinMessage({required String messageId}) async {
    try {
      await _client.from('messages').update({
        'is_pinned': false,
        'pinned_at': null,
        'pinned_by': null
      }).eq('id', messageId);

      print('📌 Message unpinned: $messageId');
    } catch (e) {
      print('❌ Error unpinning message: $e');
      rethrow;
    }
  }

  // ✅ دریافت conversationId از messageId
  Future<String> _getConversationIdByMessage(String messageId) async {
    try {
      final response = await _client
          .from('messages')
          .select('conversation_id')
          .eq('id', messageId)
          .maybeSingle();

      return response?['conversation_id'] as String? ?? '';
    } catch (e) {
      return '';
    }
  }

  // ✅ دریافت پیام پین شده یک گفتگو
  Future<ChatMessage?> getPinnedMessage(String conversationId) async {
    try {
      final response = await _client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .eq('is_pinned', true)
          .maybeSingle();

      if (response == null) return null;
      return ChatMessage.fromMap(response);
    } catch (e) {
      print('❌ Error getting pinned message: $e');
      return null;
    }
  }

  Future<List<ChatMessage>> getMessagesHistory(
    String conversationId, {
    int limit = 50,
    String? userId,
  }) async {
    try {
      final response = await _client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .eq('is_deleted', false) // ✅ فقط پیام‌های حذف نشده
          .order('created_at', ascending: false)
          .limit(limit);

      final messages = response.map((item) {
        final msg = ChatMessage.fromMap(item);
        // ✅ تنظیم وضعیت از دیتابیس
        final statusStr = item['status'] as String? ?? 'sent';
        final status = MessageStatus.values.firstWhere(
          (e) => e.toString().split('.').last == statusStr,
          orElse: () => MessageStatus.sent,
        );
        // ✅ استفاده از setter (چون status دیگر final نیست)
        msg.status = status;
        return msg;
      }).toList();

      if (userId != null) {
        return messages
            .where((msg) => !msg.hiddenFor.contains(userId))
            .toList();
      }

      return messages;
    } catch (e) {
      print('❌ Error getting messages history: $e');
      return [];
    }
  }

  Stream<List<ChatMessage>> getMessages(
    String conversationId, {
    String? userId,
  }) {
    try {
      return _client.from('messages').stream(primaryKey: ['id']).map((data) {
        print('📊 [STREAM] Received ${data.length} messages from Realtime');

        final List<ChatMessage> messages = [];
        for (var item in data) {
          final convId = item['conversation_id'] as String?;
          if (convId == conversationId) {
            final msg = ChatMessage.fromMap(item);
            if (userId == null || !msg.hiddenFor.contains(userId)) {
              messages.add(msg);
              print(
                '📊 [STREAM] Added message: ${msg.id.substring(0, 8)} - type: ${msg.type} - status: ${msg.status}',
              );
            }
          }
        }
        messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return _populateReplyTo(messages);
      }).handleError((error) {
        print('⚠️ Realtime stream error: $error');
        return <ChatMessage>[];
      });
    } catch (e) {
      print('❌ Error getting messages stream: $e');
      return Stream.value([]);
    }
  }

  // ✅ متد کمکی برای پر کردن replyTo - نسخه کامل
  List<ChatMessage> _populateReplyTo(List<ChatMessage> messages) {
    // ایجاد Map برای دسترسی سریع به پیام‌ها با id
    final Map<String, ChatMessage> messageMap = {};
    for (var msg in messages) {
      messageMap[msg.id] = msg;
    }

    // پر کردن replyTo برای پیام‌هایی که replyToId دارند
    final List<ChatMessage> result = [];
    for (var msg in messages) {
      if (msg.replyToId != null && messageMap.containsKey(msg.replyToId)) {
        result.add(
          ChatMessage(
            id: msg.id,
            conversationId: msg.conversationId,
            senderId: msg.senderId,
            senderName: msg.senderName,
            senderAvatar: msg.senderAvatar,
            content: msg.content,
            type: msg.type,
            status: msg.status,
            metadata: msg.metadata,
            isRead: msg.isRead,
            isEdited: msg.isEdited,
            isDeleted: msg.isDeleted,
            replyToId: msg.replyToId,
            replyTo: messageMap[msg.replyToId],
            reactions: msg.reactions,
            createdAt: msg.createdAt,
            editedAt: msg.editedAt,
            deletedAt: msg.deletedAt,
            isTemp: msg.isTemp,
          ),
        );
      } else {
        result.add(msg);
      }
    }

    return result;
  }

  // lib/services/chat_service.dart

  // ✅ واکنش به پیام (Reaction) - با استفاده از upsert
  Future<void> toggleReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    try {
      // ✅ 1. بررسی واکنش قبلی کاربر برای این پیام
      final existingReaction = await _client
          .from('message_reactions')
          .select()
          .eq('message_id', messageId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingReaction != null) {
        // ✅ 2. اگر کاربر قبلاً واکنش داده بود
        final existingEmoji = existingReaction['emoji'] as String;

        if (existingEmoji == emoji) {
          // ✅ اگر همان ایموجی بود → حذف کن (لغو واکنش)
          await _client
              .from('message_reactions')
              .delete()
              .eq('id', existingReaction['id']);
          print('🗑️ Reaction removed: $emoji by user $userId');
        } else {
          // ✅ اگر ایموجی متفاوت بود → آپدیت کن (به‌جای حذف+ایجاد)
          await _client.from('message_reactions').update({
            'emoji': emoji,
            'created_at': DateTime.now().toIso8601String(),
          }).eq('id', existingReaction['id']);
          print('🔄 Reaction updated: $existingEmoji → $emoji by user $userId');
        }
      } else {
        // ✅ 3. اگر کاربر قبلاً واکنش نداده بود → اضافه کن
        await _client.from('message_reactions').insert({
          'message_id': messageId,
          'user_id': userId,
          'emoji': emoji,
          'created_at': DateTime.now().toIso8601String(),
        });
        print('✅ Reaction added: $emoji by user $userId');
      }
    } catch (e) {
      print('❌ Error toggling reaction: $e');
      rethrow;
    }
  }

  // lib/services/chat_service.dart

  // ✅ اضافه کردن متد به ChatService - با زمان UTC
  Future<void> updateLastSeen(String userId) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _client
          .from('profiles')
          .update({'last_seen_at': now}).eq('user_id', userId);
    } catch (e) {
      // خطا را نادیده بگیر
    }
  }

  // ✅ حذف پیام فقط برای خود کاربر (soft delete)
  Future<void> deleteMessageForMe(String messageId, String userId) async {
    try {
      // فقط برای خود کاربر مخفی میشه (با اضافه کردن کاربر به لیست hidden_for)
      // روش 1: استفاده از ستون hidden_for (آرایه‌ای از کاربرانی که پیام برایشان مخفی شده)
      final message = await _client
          .from('messages')
          .select('hidden_for')
          .eq('id', messageId)
          .single();

      List<String> hiddenFor = List<String>.from(message['hidden_for'] ?? []);
      if (!hiddenFor.contains(userId)) {
        hiddenFor.add(userId);
      }

      await _client
          .from('messages')
          .update({'hidden_for': hiddenFor}).eq('id', messageId);

      print('🗑️ Message hidden for user: $userId');
    } catch (e) {
      print('❌ Error hiding message: $e');
      rethrow;
    }
  }

  // ✅ حذف پیام برای همه (hard delete)
  Future<void> deleteMessageForEveryone(String messageId, String userId) async {
    try {
      // فقط فرستنده پیام میتواند برای همه حذف کند
      // یا ادمین گروه (برای گروه‌ها)
      await _client
          .from('messages')
          .delete()
          .eq('id', messageId)
          .eq('sender_id', userId);

      print('🗑️ Message deleted for everyone: $messageId');
    } catch (e) {
      print('❌ Error deleting message for everyone: $e');
      rethrow;
    }
  }

  // ✅ دریافت واکنش‌های یک پیام (بدون join)
  Future<List<MessageReaction>> getMessageReactions(String messageId) async {
    try {
      // 1. دریافت واکنش‌ها
      final response = await _client
          .from('message_reactions')
          .select()
          .eq('message_id', messageId);

      if (response.isEmpty) return [];

      // 2. دریافت نام کاربران
      final userIds =
          response.map((r) => r['user_id'] as String).toSet().toList();
      final Map<String, String> userNames = {};

      if (userIds.isNotEmpty) {
        try {
          final profiles = await _client
              .from('profiles')
              .select('user_id, name')
              .inFilter('user_id', userIds);

          for (var profile in profiles) {
            userNames[profile['user_id']] = profile['name'] ?? 'کاربر';
          }
        } catch (e) {
          for (var id in userIds) {
            userNames[id] = 'کاربر';
          }
        }
      }

      return response.map((item) {
        final userId = item['user_id'] as String;
        return MessageReaction(
          userId: userId,
          emoji: item['emoji'],
          userName: userNames[userId] ?? 'کاربر',
          createdAt: DateTime.parse(item['created_at']),
        );
      }).toList();
    } catch (e) {
      print('❌ Error getting message reactions: $e');
      return [];
    }
  }

  // ✅ دریافت واکنش‌های همه پیام‌های یک گفتگو (بدون join)
  Future<Map<String, List<MessageReaction>>> getConversationReactions(
    String conversationId,
  ) async {
    try {
      // 1. دریافت همه پیام‌های گفتگو
      final messages = await _client
          .from('messages')
          .select('id')
          .eq('conversation_id', conversationId);

      if (messages.isEmpty) return {};

      final messageIds = messages.map((m) => m['id'] as String).toList();

      // 2. دریافت واکنش‌های این پیام‌ها
      final response = await _client
          .from('message_reactions')
          .select()
          .inFilter('message_id', messageIds);

      if (response.isEmpty) return {};

      // 3. دریافت نام کاربران (به صورت جداگانه)
      final Map<String, String> userNames = {};
      final userIds =
          response.map((r) => r['user_id'] as String).toSet().toList();

      if (userIds.isNotEmpty) {
        try {
          final profiles = await _client
              .from('profiles')
              .select('user_id, name')
              .inFilter('user_id', userIds);

          for (var profile in profiles) {
            userNames[profile['user_id']] = profile['name'] ?? 'کاربر';
          }
        } catch (e) {
          // اگر خطا در دریافت پروفایل بود، فقط از userId استفاده کن
          for (var id in userIds) {
            userNames[id] = 'کاربر';
          }
        }
      }

      // 4. گروه‌بندی واکنش‌ها بر اساس message_id
      final Map<String, List<MessageReaction>> result = {};
      for (var item in response) {
        final messageId = item['message_id'] as String;
        final userId = item['user_id'] as String;

        if (!result.containsKey(messageId)) {
          result[messageId] = [];
        }

        result[messageId]!.add(
          MessageReaction(
            userId: userId,
            emoji: item['emoji'],
            userName: userNames[userId] ?? 'کاربر',
            createdAt: DateTime.parse(item['created_at']),
          ),
        );
      }
      return result;
    } catch (e) {
      print('❌ Error getting conversation reactions: $e');
      return {};
    }
  }

  // lib/services/chat_service.dart

  // ✅ حذف کامل پیام (بدون هیچ اثری)
  Future<void> deleteMessage(String messageId, String userId) async {
    try {
      // حذف کامل پیام از دیتابیس
      await _client
          .from('messages')
          .delete()
          .eq('id', messageId)
          .eq('sender_id', userId);

      print('🗑️ Message deleted permanently: $messageId');
    } catch (e) {
      print('❌ Error deleting message: $e');
      rethrow;
    }
  }

  // ✅ ویرایش پیام
  Future<void> editMessage({
    required String messageId,
    required String userId,
    required String newContent,
  }) async {
    try {
      await _client
          .from('messages')
          .update({
            'content': newContent,
            'is_edited': true,
            'edited_at': DateTime.now().toIso8601String(),
          })
          .eq('id', messageId)
          .eq('sender_id', userId);
    } catch (e) {
      print('❌ Error editing message: $e');
      rethrow;
    }
  }

  // lib/services/chat_service.dart

  // ✅ اصلاح متد sendTypingStatus
  Future<void> sendTypingStatus({
    required String conversationId,
    required String userId,
    required bool isTyping,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      // ✅ Upsert با استفاده از onConflict
      await _client.from('typing_status').upsert({
        'conversation_id': conversationId,
        'user_id': userId,
        'is_typing': isTyping,
        'updated_at': now,
      }, onConflict: 'conversation_id, user_id');

      print('📊 Typing status updated: $isTyping for user $userId');
    } catch (e) {
      print('⚠️ Typing status error: $e');
    }
  }

  // lib/services/chat_service.dart

  // ✅ علامت‌گذاری پیام به عنوان خوانده شده
  Future<void> markMessageAsRead({
    required String messageId,
    required String userId,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      await _client
          .from('messages')
          .update({'status': 'seen', 'read_at': now})
          .eq('id', messageId)
          .neq('sender_id', userId); // فقط پیام‌هایی که خود کاربر نفرستاده

      print('✅ Message $messageId marked as read by $userId');
    } catch (e) {
      print('❌ Error marking message as read: $e');
    }
  }

  // lib/services/chat_service.dart

  /// ✅ علامت‌گذاری همه پیام‌های یک گفتگو به عنوان خوانده شده - نسخه اصلاح شده
  Future<void> markAllMessagesAsRead({
    required String conversationId,
    required String userId,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      // ✅ فقط پیام‌هایی که توسط کاربر مقابل ارسال شده و هنوز seen نشده‌اند
      final result = await _client
          .from('messages')
          .update({'status': 'seen', 'read_at': now})
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId)
          .neq('status', 'seen');

      // ✅ بررسی اینکه result لیست است یا نه
      if (result != null && result is List) {
        print('✅ All messages in conversation $conversationId marked as read');
        print('📊 Updated ${result.length} messages');
      } else {
        // اگر result null بود یا لیست نبود، اما خطایی رخ نداده، یعنی موفق بوده
        print('✅ All messages in conversation $conversationId marked as read');
        print('📊 Update completed successfully (no detailed count)');
      }
    } catch (e) {
      print('❌ Error marking all messages as read: $e');
      // خطا را نادیده بگیر و ادامه بده
      // چون ممکن است جدول messages خالی باشد یا محدودیت‌های RLS مانع شود
    }
  }

  // lib/services/chat_service.dart

  /// ✅ علامت‌گذاری همه پیام‌ها با RPC (روش مطمئن‌تر)
  Future<int> markAllMessagesAsReadRPC({
    required String conversationId,
    required String userId,
  }) async {
    try {
      final result = await _client.rpc(
        'mark_messages_as_read',
        params: {'p_conversation_id': conversationId, 'p_user_id': userId},
      );

      // نتیجه می‌تواند int یا Map باشد
      int count = 0;
      if (result is int) {
        count = result;
      } else if (result is Map) {
        count = result['count'] ?? 0;
      }

      print('✅ $count messages marked as read via RPC');
      return count;
    } catch (e) {
      print('❌ Error marking messages as read via RPC: $e');
      return 0;
    }
  }

  // lib/services/chat_service.dart

  /// ✅ روش جایگزین بدون RPC - با تعریف متغیر now
  Future<void> markAllMessagesAsReadSafe({
    required String conversationId,
    required String userId,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      // ✅ به‌روزرسانی مستقیم
      await _client
          .from('messages')
          .update({'status': 'seen', 'read_at': now})
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId)
          .neq('status', 'seen');

      print('✅ All messages marked as read (safe method)');
    } catch (e) {
      print('⚠️ Safe method failed, trying individual updates...');

      // اگر خطا داد، تک تک پیام‌ها را به‌روزرسانی کن
      try {
        final now2 = DateTime.now().toUtc().toIso8601String();

        final unread = await _client
            .from('messages')
            .select('id')
            .eq('conversation_id', conversationId)
            .neq('sender_id', userId)
            .neq('status', 'seen');

        for (var msg in unread) {
          await _client
              .from('messages')
              .update({'status': 'seen', 'read_at': now2}).eq('id', msg['id']);
        }
        print('✅ ${unread.length} messages marked as read individually');
      } catch (e2) {
        print('❌ Error marking messages individually: $e2');
      }
    }
  }

  // ✅ دریافت وضعیت تایپ کاربران دیگر - با مدیریت خطا
  Stream<Map<String, bool>> getTypingStatus(String conversationId) {
    try {
      return _client
          .from('typing_status')
          .stream(primaryKey: ['id']).map((data) {
        final Map<String, bool> result = {};
        final now = DateTime.now().toUtc();

        for (var item in data) {
          if (item['conversation_id'] == conversationId) {
            final userId = item['user_id'] as String;
            final isTyping = item['is_typing'] as bool;
            final updatedAt = DateTime.parse(item['updated_at']).toUtc();

            // اگر بیش از 5 ثانیه از آخرین به‌روزرسانی گذشته، تایپ نیست
            if (now.difference(updatedAt).inSeconds < 5) {
              result[userId] = isTyping;
            }
          }
        }
        return result;
      }).handleError((error) {
        // ✅ مدیریت خطا - فقط لاگ کن
        print('⚠️ Typing status stream error: $error');
        return <String, bool>{};
      });
    } catch (e) {
      print('❌ Error getting typing status: $e');
      return Stream.value({});
    }
  }

  // ==================== دریافت پیام‌های قدیمی‌تر با RPC ====================

  // اگر نیاز به فیلتر بر اساس تاریخ دارید، از این روش استفاده کنید
  Future<List<ChatMessage>> getMessagesBeforeDate(
    String conversationId, {
    required DateTime before,
    int limit = 50,
  }) async {
    try {
      // استفاده از RPC برای فیلتر کردن تاریخ
      final response = await _client.rpc(
        'get_messages_before_date',
        params: {
          'p_conversation_id': conversationId,
          'p_before_date': before.toIso8601String(),
          'p_limit': limit,
        },
      );

      return response.map((item) => ChatMessage.fromMap(item)).toList();
    } catch (e) {
      print('❌ Error getting messages before date: $e');
      return [];
    }
  }

  // ==================== اعضا ====================

  Future<void> addMember(String conversationId, String userId) async {
    try {
      await _client.from('conversation_members').insert({
        'conversation_id': conversationId,
        'user_id': userId,
        'joined_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Error adding member: $e');
      rethrow;
    }
  }

  Future<void> removeMember(String conversationId, String userId) async {
    try {
      await _client
          .from('conversation_members')
          .delete()
          .eq('conversation_id', conversationId)
          .eq('user_id', userId);
    } catch (e) {
      print('❌ Error removing member: $e');
      rethrow;
    }
  }

  // ==================== هم‌مسیر (Buddy) ====================

  Future<void> sendBuddyRequest(
    String fromUserId,
    String toUserId, {
    String? message,
  }) async {
    try {
      await _client.from('buddy_requests').insert({
        'from_user_id': fromUserId,
        'to_user_id': toUserId,
        'message': message,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Error sending buddy request: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getBuddyRequests(String userId) async {
    try {
      final response = await _client
          .from('buddy_requests')
          .select('*, from_user:profiles!from_user_id(*)')
          .eq('to_user_id', userId)
          .eq('status', 'pending');

      return response;
    } catch (e) {
      print('❌ Error getting buddy requests: $e');
      return [];
    }
  }

  Future<void> respondToBuddyRequest(String requestId, bool accept) async {
    try {
      final status = accept ? 'accepted' : 'rejected';
      await _client
          .from('buddy_requests')
          .update({'status': status}).eq('id', requestId);

      if (accept) {
        final request = await _client
            .from('buddy_requests')
            .select()
            .eq('id', requestId)
            .single();

        await createConversation(
          type: 'buddy',
          memberIds: [request['from_user_id'], request['to_user_id']],
          name: null,
          createdBy: request['from_user_id'],
        );
      }
    } catch (e) {
      print('❌ Error responding to buddy request: $e');
      rethrow;
    }
  }

  // lib/services/chat_service.dart

  Future<void> deleteConversationForBoth(String conversationId) async {
    try {
      print('🗑️ Starting deletion for conversation: $conversationId');

      // 1. دریافت اعضای گفتگو
      final membersResponse = await _client
          .from('conversation_members')
          .select('user_id')
          .eq('conversation_id', conversationId);

      final memberIds =
          membersResponse.map((m) => m['user_id'] as String).toList();

      print('📊 Members in conversation: $memberIds');

      // 2. حذف درخواست‌های هم‌مسیر
      if (memberIds.length >= 2) {
        try {
          await _client.from('buddy_requests').delete().or(
              'and(from_user_id.eq.${memberIds[0]},to_user_id.eq.${memberIds[1]}),'
              'and(from_user_id.eq.${memberIds[1]},to_user_id.eq.${memberIds[0]})');
          print('🗑️ Removed buddy requests between members');
        } catch (e) {
          print('⚠️ Error removing buddy requests: $e');
        }
      }

      // 3. حذف typing_status
      try {
        await _client
            .from('typing_status')
            .delete()
            .eq('conversation_id', conversationId);
      } catch (e) {
        print('⚠️ Error deleting typing status: $e');
      }

      // 4. حذف واکنش‌ها
      try {
        final messages = await _client
            .from('messages')
            .select('id')
            .eq('conversation_id', conversationId);

        if (messages.isNotEmpty) {
          final messageIds = messages.map((m) => m['id'] as String).toList();
          await _client
              .from('message_reactions')
              .delete()
              .inFilter('message_id', messageIds);
        }
      } catch (e) {
        print('⚠️ Error deleting reactions: $e');
      }

      // 5. حذف پیام‌ها
      try {
        await _client
            .from('messages')
            .delete()
            .eq('conversation_id', conversationId);
        print('🗑️ Messages deleted');
      } catch (e) {
        print('⚠️ Error deleting messages: $e');
      }

      // 6. حذف خود گفتگو
      bool conversationDeleted = false;
      try {
        final deleteResult = await _client
            .from('conversations')
            .delete()
            .eq('id', conversationId)
            .select();

        if (deleteResult.isNotEmpty) {
          conversationDeleted = true;
          print('✅ Conversation deleted successfully');
        } else {
          print('⚠️ Conversation NOT deleted (RLS issue)');
        }
      } catch (e) {
        print('❌ Error deleting conversation: $e');
      }

      // 7. اگر حذف نشد، غیرفعال کن
      if (!conversationDeleted) {
        try {
          await _client
              .from('conversations')
              .update({'is_active': false}).eq('id', conversationId);
          print('ℹ️ Conversation marked as inactive');
        } catch (e) {
          print('⚠️ Error marking inactive: $e');
        }
      }

      // 8. حذف members
      try {
        await _client
            .from('conversation_members')
            .delete()
            .eq('conversation_id', conversationId);
        print('🗑️ Members deleted');
      } catch (e) {
        print('⚠️ Error deleting members: $e');
      }
    } catch (e) {
      print('❌ Error deleting conversation: $e');
      rethrow;
    }
  }

  // ==================== کمکی ====================

  Future<User?> getCurrentUser() async {
    try {
      return _client.auth.currentUser;
    } catch (e) {
      return null;
    }
  }

  Future<String?> uploadImage(File imageFile) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'chat_images/$fileName';

      final session = _client.auth.currentSession;
      if (session == null) {
        print('❌ No active session');
        return null;
      }

      final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
      if (supabaseUrl.isEmpty) {
        print('❌ SUPABASE_URL not found');
        return null;
      }

      final uploadUrl = '$supabaseUrl/storage/v1/object/chat/$path';

      // ✅ تبدیل به Uint8List
      final bytes = await imageFile.readAsBytes();
      final uint8List = Uint8List.fromList(bytes);

      final response = await http.put(
        Uri.parse(uploadUrl),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/octet-stream',
        },
        body: uint8List,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final publicUrl = _client.storage.from('chat').getPublicUrl(path);
        return publicUrl;
      }
      return null;
    } catch (e) {
      print('❌ Error uploading image: $e');
      return null;
    }
  }
}
