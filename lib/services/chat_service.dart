// lib/services/chat_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/chat/models/message_model.dart';
import '../features/chat/models/conversation_model.dart';

class ChatService {
  final SupabaseClient _client = Supabase.instance.client;

  // ==================== گفتگوها ====================

  Future<List<Conversation>> getUserConversations(String userId) async {
    try {
      final response = await _client
          .from('conversations')
          .select('''
            *,
            conversation_members!inner(user_id),
            last_message:messages!conversation_id(
              content,
              created_at,
              sender_id
            )
          ''')
          .eq('conversation_members.user_id', userId)
          .eq('is_active', true)
          .order('last_message_at', ascending: false);

      if (response.isEmpty) return [];

      return response.map((data) {
        String? lastMessage;
        if (data['last_message'] != null && data['last_message'].isNotEmpty) {
          lastMessage = data['last_message'][0]['content'];
        }

        final members = data['conversation_members'] as List;
        final memberIds = members.map((m) => m['user_id'] as String).toList();

        return Conversation(
          id: data['id'],
          type: ConversationType.values.firstWhere(
            (e) => e.toString().split('.').last == data['type'],
            orElse: () => ConversationType.buddy,
          ),
          name: data['name'],
          createdBy: data['created_by'],
          squadId: data['squad_id'],
          challengeId: data['challenge_id'],
          isActive: data['is_active'] ?? true,
          lastMessageAt: DateTime.parse(data['last_message_at']),
          createdAt: DateTime.parse(data['created_at']),
          lastMessage: lastMessage,
          unreadCount: 0,
          memberIds: memberIds,
        );
      }).toList();
    } catch (e) {
      print('❌ Error getting conversations: $e');
      return [];
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
      final conversationResponse = await _client
          .from('conversations')
          .insert({
            'type': type,
            'name': name,
            'created_by': createdBy,
            'squad_id': squadId,
            'challenge_id': challengeId,
            'is_active': true,
            'last_message_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final conversationId = conversationResponse['id'];

      final membersToInsert = memberIds
          .map(
            (userId) => {
              'conversation_id': conversationId,
              'user_id': userId,
              'joined_at': DateTime.now().toIso8601String(),
            },
          )
          .toList();

      await _client.from('conversation_members').insert(membersToInsert);

      return conversationId;
    } catch (e) {
      print('❌ Error creating conversation: $e');
      rethrow;
    }
  }

  // ==================== پیام‌ها ====================

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    String type = 'text',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _client.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': senderId,
        'content': content,
        'type': type,
        'metadata': metadata ?? {},
        'created_at': DateTime.now().toIso8601String(),
      });

      await _client
          .from('conversations')
          .update({'last_message_at': DateTime.now().toIso8601String()})
          .eq('id', conversationId);
    } catch (e) {
      print('❌ Error sending message: $e');
      rethrow;
    }
  }

  Stream<List<ChatMessage>> getMessages(String conversationId) {
    try {
      return _client
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .map(
            (data) => data.map((item) => ChatMessage.fromMap(item)).toList(),
          );
    } catch (e) {
      print('❌ Error getting messages stream: $e');
      return Stream.value([]);
    }
  }

  Future<List<ChatMessage>> getMessagesHistory(
    String conversationId, {
    int limit = 50,
    DateTime? before,
  }) async {
    try {
      // ✅ ساخت کوئری پایه
      var query = _client
          .from('messages')
          .select('*')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(limit);

      // ✅ اگر تاریخ قبل مشخص شده، از روش rpc یا فیلتر سمت کلاینت استفاده کن
      // برای سادگی، تاریخ را نادیده می‌گیریم و فقط limit استفاده می‌کنیم
      // می‌توانید بعداً با استفاده از RPC این را بهبود دهید

      final response = await query;
      return response.map((item) => ChatMessage.fromMap(item)).toList();
    } catch (e) {
      print('❌ Error getting messages history: $e');
      return [];
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
          .update({'status': status})
          .eq('id', requestId);

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

  // ==================== کمکی ====================

  Future<User?> getCurrentUser() async {
    try {
      return _client.auth.currentUser;
    } catch (e) {
      return null;
    }
  }
}
