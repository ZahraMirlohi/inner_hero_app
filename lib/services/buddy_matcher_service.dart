// lib/services/buddy_matcher_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/profile/models/user_personality.dart';
import 'chat_service.dart';
import '../features/chat/models/conversation_model.dart';

class BuddyMatcherService {
  final SupabaseClient _client = Supabase.instance.client;

  // دریافت پروفایل شخصیت کاربر
  Future<UserPersonality?> getUserPersonality(String userId) async {
    try {
      final response = await _client
          .from('user_personalities')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return UserPersonality.fromMap(response, userId);
    } catch (e) {
      print('❌ Error getting user personality: $e');
      return null;
    }
  }

  // ذخیره/به‌روزرسانی پروفایل شخصیت
  Future<void> saveUserPersonality(UserPersonality personality) async {
    try {
      final data = personality.toMap();
      data['user_id'] = personality.userId;

      await _client.from('user_personalities').upsert(data);
    } catch (e) {
      print('❌ Error saving user personality: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 جستجو با username یا phone
  // ═══════════════════════════════════════════════════════════

  /// جستجوی کاربر با username یا شماره موبایل
  ///
  /// - `query` می‌تواند username یا phone باشد
  /// - خود کاربر از نتایج حذف می‌شود
  /// - فقط کاربرانی که `is_looking_for_buddy = true` هستند نمایش داده می‌شوند
  Future<Map<String, dynamic>?> searchUserByUsernameOrPhone({
    required String currentUserId,
    required String query,
  }) async {
    try {
      final cleanQuery = query.trim().toLowerCase();
      if (cleanQuery.isEmpty) return null;

      // ✅ ساخت شرط جستجو
      final isPhone = RegExp(r'^[\d+]+$').hasMatch(cleanQuery);

      dynamic profile;

      if (isPhone) {
        // جستجو با شماره موبایل
        profile = await _client
            .from('profiles')
            .select(
                'user_id, name, username, phone, avatar_url, total_xp, current_streak, bio')
            .eq('phone', cleanQuery)
            .neq('user_id', currentUserId)
            .maybeSingle();
      } else {
        // جستجو با username (case-insensitive)
        profile = await _client
            .from('profiles')
            .select(
                'user_id, name, username, phone, avatar_url, total_xp, current_streak, bio')
            .ilike('username', cleanQuery)
            .neq('user_id', currentUserId)
            .maybeSingle();
      }

      if (profile == null) {
        print('🔍 User not found with query: $cleanQuery');
        return null;
      }

      final userId = profile['user_id'] as String;

      // ✅ بررسی اینکه آیا کاربر personality دارد
      final personalityResponse = await _client
          .from('user_personalities')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      // ✅ بررسی اینکه آیا این کاربر buddy است یا درخواست pending دارد
      final requestsResponse = await _client
          .from('buddy_requests')
          .select('id, from_user_id, to_user_id, status')
          .or('and(from_user_id.eq.$currentUserId,to_user_id.eq.$userId),and(from_user_id.eq.$userId,to_user_id.eq.$currentUserId)')
          .maybeSingle();

      // ✅ بررسی وجود گفتگو
      final conversationsResponse = await _client
          .from('conversation_members')
          .select('conversation_id')
          .eq('user_id', currentUserId);

      bool isBuddy = false;
      String? conversationId;

      if (conversationsResponse.isNotEmpty) {
        final convIds = conversationsResponse
            .map((m) => m['conversation_id'] as String)
            .toList();

        final buddyConvs = await _client
            .from('conversations')
            .select('id, type, is_active')
            .inFilter('id', convIds)
            .eq('type', 'buddy')
            .eq('is_active', true);

        for (var conv in buddyConvs) {
          final members = await _client
              .from('conversation_members')
              .select('user_id')
              .eq('conversation_id', conv['id']);

          final memberIds = members.map((m) => m['user_id'] as String).toList();

          if (memberIds.contains(userId) && memberIds.contains(currentUserId)) {
            isBuddy = true;
            conversationId = conv['id'] as String;
            break;
          }
        }
      }

      // ✅ محاسبه امتیاز تطابق (اگر personality داشته باشد)
      double matchScore = 0;
      final currentPersonality = await getUserPersonality(currentUserId);

      if (currentPersonality != null && personalityResponse != null) {
        try {
          final otherPersonality = UserPersonality.fromMap(
            personalityResponse,
            userId,
          );
          matchScore = currentPersonality.calculateMatchScore(otherPersonality);
        } catch (e) {
          print('⚠️ Error calculating match score: $e');
        }
      }

      // ✅ بررسی وضعیت درخواست
      final isSentByMe = requestsResponse != null &&
          requestsResponse['from_user_id'] == currentUserId &&
          requestsResponse['status'] == 'pending';
      final isReceivedByMe = requestsResponse != null &&
          requestsResponse['to_user_id'] == currentUserId &&
          requestsResponse['status'] == 'pending';

      return {
        'user_id': userId,
        'name': profile['name'] ?? 'کاربر',
        'username': profile['username'],
        'phone': profile['phone'],
        'gender': personalityResponse?['gender']?.toString().split('.').last ??
            'other',
        'avatar_url': profile['avatar_url'],
        'total_xp': profile['total_xp'] ?? 0,
        'current_streak': profile['current_streak'] ?? 0,
        'bio': profile['bio'],
        'match_score': matchScore,
        'personality': personalityResponse != null
            ? UserPersonality.fromMap(personalityResponse, userId)
            : null,
        'common_habits': [],
        'common_interests': [],
        'is_buddy': isBuddy,
        'has_pending_request': isSentByMe || isReceivedByMe,
        'is_sent_by_me': isSentByMe,
        'is_received_by_me': isReceivedByMe,
        'request_id': requestsResponse?['id'],
        'conversation_id': conversationId,
      };
    } catch (e) {
      print('❌ Error searching user: $e');
      return null;
    }
  }

  /// بررسی می‌کند آیا کاربری با این username یا phone وجود دارد
  Future<bool> userExists({
    required String query,
  }) async {
    try {
      final cleanQuery = query.trim().toLowerCase();
      if (cleanQuery.isEmpty) return false;

      final isPhone = RegExp(r'^[\d+]+$').hasMatch(cleanQuery);

      dynamic response;

      if (isPhone) {
        response = await _client
            .from('profiles')
            .select('user_id')
            .eq('phone', cleanQuery)
            .maybeSingle();
      } else {
        response = await _client
            .from('profiles')
            .select('user_id')
            .ilike('username', cleanQuery)
            .maybeSingle();
      }

      return response != null;
    } catch (e) {
      print('❌ Error checking user existence: $e');
      return false;
    }
  }

  // ==================== پیدا کردن هم‌مسیرها ====================

  // lib/services/buddy_matcher_service.dart

  Future<List<Map<String, dynamic>>> findMatchingBuddies(
    String userId, {
    int limit = 20,
    double minMatchScore = 0,
    Gender? filterGender,
  }) async {
    try {
      final currentPersonality = await getUserPersonality(userId);
      if (currentPersonality == null) return [];

      // ✅ یک کوئری برای همه کاربران
      final allUsers = await _client.from('user_personalities').select();
      final lookingUsers = allUsers.where((u) {
        final looking = u['is_looking_for_buddy'];
        if (looking is bool) return looking == true;
        if (looking is String) return looking.toLowerCase() == 'true';
        return false;
      }).toList();

      final otherUsers =
          lookingUsers.where((u) => u['user_id'] != userId).toList();

      if (otherUsers.isEmpty) return [];

      final otherUserIds =
          otherUsers.map((u) => u['user_id'] as String).toList();

      // ✅ گرفتن همه پروفایل‌ها با یک کوئری
      final profilesResponse = await _client
          .from('profiles')
          .select('user_id, name, avatar_url, total_xp, current_streak')
          .inFilter('user_id', otherUserIds);

      final Map<String, Map<String, dynamic>> profilesMap = {
        for (var p in profilesResponse) p['user_id'] as String: p,
      };

      // ✅ گرفتن blocked users
      final blockedResponse = await _client
          .from('blocked_users')
          .select('blocked_id')
          .eq('blocker_id', userId);
      final blockedIds =
          blockedResponse.map((b) => b['blocked_id'] as String).toSet();

      // ✅ گرفتن همه درخواست‌ها با یک کوئری
      final allRequestsResponse = await _client
          .from('buddy_requests')
          .select('id, from_user_id, to_user_id, status')
          .or('from_user_id.eq.$userId,to_user_id.eq.$userId');

      final sentRequestMap = <String, String>{};
      final receivedRequestMap = <String, String>{};
      for (var r in allRequestsResponse) {
        if (r['status'] != 'pending') continue;
        if (r['from_user_id'] == userId) {
          sentRequestMap[r['to_user_id'] as String] = r['id'] as String;
        } else if (r['to_user_id'] == userId) {
          receivedRequestMap[r['from_user_id'] as String] = r['id'] as String;
        }
      }

      // ✅ گرفتن گفتگوهای buddy فقط (با is_active = true)
      final conversationsResponse = await _client
          .from('conversations')
          .select('id, type, is_active')
          .eq('type', 'buddy')
          .eq('is_active', true);

      final buddyConversationIds =
          conversationsResponse.map((c) => c['id'] as String).toList();

      // ✅ گرفتن همه اعضای این گفتگوها با یک کوئری
      final existingBuddyMap = <String, String>{};
      if (buddyConversationIds.isNotEmpty) {
        final membersResponse = await _client
            .from('conversation_members')
            .select('conversation_id, user_id')
            .inFilter('conversation_id', buddyConversationIds)
            .inFilter('user_id', otherUserIds);

        // ✅ گرفتن همه اعضای این گفتگوها (نه فقط otherUserIds)
        final allMembersResponse = await _client
            .from('conversation_members')
            .select('conversation_id, user_id')
            .inFilter('conversation_id', buddyConversationIds);

        // گروه‌بندی بر اساس conversation_id
        final Map<String, List<String>> convMembers = {};
        for (var m in allMembersResponse) {
          final convId = m['conversation_id'] as String;
          final uid = m['user_id'] as String;
          convMembers.putIfAbsent(convId, () => []).add(uid);
        }

        // ✅ فقط گفتگوهایی که هر دو کاربر در آن هستند
        for (var entry in convMembers.entries) {
          if (entry.value.contains(userId) && entry.value.length >= 2) {
            for (var memberId in entry.value) {
              if (memberId != userId && otherUserIds.contains(memberId)) {
                existingBuddyMap[memberId] = entry.key;
              }
            }
          }
        }
      }

      // ✅ ساخت لیست match
      List<Map<String, dynamic>> matches = [];

      for (var userData in otherUsers) {
        final otherUserId = userData['user_id'] as String;

        if (blockedIds.contains(otherUserId)) continue;

        final otherPersonality = UserPersonality.fromMap(userData, otherUserId);

        if (filterGender != null && otherPersonality.gender != filterGender) {
          continue;
        }

        final matchScore =
            currentPersonality.calculateMatchScore(otherPersonality);
        if (matchScore < minMatchScore) continue;

        final profile = profilesMap[otherUserId];

        final isBuddy = existingBuddyMap.containsKey(otherUserId);
        final isSentByMe = sentRequestMap.containsKey(otherUserId);
        final isReceivedByMe = receivedRequestMap.containsKey(otherUserId);

        matches.add({
          'user_id': otherUserId,
          'name': profile?['name'] ?? 'کاربر',
          'gender': otherPersonality.gender.toString().split('.').last,
          'avatar_url': profile?['avatar_url'],
          'total_xp': profile?['total_xp'] ?? 0,
          'current_streak': profile?['current_streak'] ?? 0,
          'match_score': matchScore,
          'personality': otherPersonality,
          'common_habits': currentPersonality.habits
              .where((h) => otherPersonality.habits.contains(h))
              .toList(),
          'common_interests': currentPersonality.interests
              .where((i) => otherPersonality.interests.contains(i))
              .toList(),
          'is_buddy': isBuddy,
          'has_pending_request': isSentByMe || isReceivedByMe,
          'is_sent_by_me': isSentByMe,
          'is_received_by_me': isReceivedByMe,
          'request_id': isSentByMe
              ? sentRequestMap[otherUserId]
              : receivedRequestMap[otherUserId],
          'conversation_id': existingBuddyMap[otherUserId],
        });
      }

      matches.sort((a, b) =>
          (b['match_score'] as double).compareTo(a['match_score'] as double));

      return matches.take(limit).toList();
    } catch (e) {
      print('❌ Error finding matching buddies: $e');
      return [];
    }
  }

  // ==================== سایر متدها ====================

  Future<void> sendBuddyRequestWithMatch(
    String fromUserId,
    String toUserId, {
    String? message,
  }) async {
    try {
      // ✅ چک کردن auth.uid() و تطابق با fromUserId
      final currentUser = _client.auth.currentUser;

      print('🔍 ===== SEND BUDDY REQUEST DEBUG =====');
      print('🔍 Current auth.uid(): ${currentUser?.id}');
      print('🔍 fromUserId param:    $fromUserId');
      print('🔍 toUserId param:      $toUserId');

      if (currentUser == null) {
        throw Exception('کاربر احراز هویت نشده است');
      }

      // ✅ استفاده از auth.uid() به جای پارامتر (اجباری برای RLS)
      final actualFromUserId = currentUser.id;

      if (actualFromUserId != fromUserId) {
        print(
            '⚠️ Mismatch detected! Using auth.uid() instead: $actualFromUserId');
      }

      print('🔍 Using actualFromUserId: $actualFromUserId');
      print('🔍 ====================================');

      // 1. حذف درخواست‌های قبلی بین این دو کاربر
      await _client
          .from('buddy_requests')
          .delete()
          .eq('from_user_id', actualFromUserId)
          .eq('to_user_id', toUserId);

      print('🗑️ Removed previous requests');

      // 2. محاسبه امتیاز تطابق
      final fromPersonality = await getUserPersonality(actualFromUserId);
      final toPersonality = await getUserPersonality(toUserId);

      double matchScore = 0;
      if (fromPersonality != null && toPersonality != null) {
        matchScore = fromPersonality.calculateMatchScore(toPersonality);
      }

      print('📊 Match score: $matchScore');

      // 3. ایجاد درخواست جدید با actualFromUserId
      final insertResponse = await _client.from('buddy_requests').insert({
        'from_user_id': actualFromUserId, // ✅ auth.uid()
        'to_user_id': toUserId,
        'message': message ?? 'سلام! می‌خواهم با شما هم‌مسیر شوم 🤝',
        'match_score': matchScore,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      if (insertResponse.isNotEmpty) {
        print('✅ Buddy request sent successfully');
        print('📊 New request ID: ${insertResponse[0]['id']}');
      } else {
        print('⚠️ Request sent but no response');
      }
    } catch (e) {
      print('❌ Error sending buddy request: $e');
      rethrow;
    }
  }

  // ✅ دریافت درخواست‌های ارسال شده
  Future<List<Map<String, dynamic>>> getSentBuddyRequests(String userId) async {
    try {
      final response = await _client
          .from('buddy_requests')
          .select('*, to_user_id, from_user_id, id, status')
          .eq('from_user_id', userId)
          .order('created_at', ascending: false);

      print('📊 Sent requests for user $userId: ${response.length}');

      if (response.isEmpty) return [];

      List<Map<String, dynamic>> result = [];
      for (var request in response) {
        final toUserId = request['to_user_id'];

        final profile = await _client
            .from('profiles')
            .select('name, avatar_url')
            .eq('user_id', toUserId)
            .maybeSingle();

        result.add({
          ...request,
          'to_user': profile ?? {'name': 'کاربر', 'avatar_url': null},
        });
      }

      return result;
    } catch (e) {
      print('❌ Error getting sent buddy requests: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getBuddyRequests(String userId) async {
    try {
      final response = await _client
          .from('buddy_requests')
          .select('*, from_user_id, to_user_id')
          .eq('to_user_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      if (response.isEmpty) return [];

      List<Map<String, dynamic>> result = [];
      for (var request in response) {
        final fromUserId = request['from_user_id'];

        final profile = await _client
            .from('profiles')
            .select('name, avatar_url')
            .eq('user_id', fromUserId)
            .maybeSingle();

        result.add({
          ...request,
          'from_user': profile ?? {'name': 'کاربر', 'avatar_url': null},
        });
      }

      return result;
    } catch (e) {
      print('❌ Error getting buddy requests: $e');
      return [];
    }
  }

  // lib/services/buddy_matcher_service.dart

  // ✅ اضافه کردن متد برای پاک کردن تاریخچه درخواست‌ها
  Future<void> clearRequestHistory(String userId) async {
    try {
      await _client
          .from('buddy_requests')
          .delete()
          .or('from_user_id.eq.$userId,to_user_id.eq.$userId');

      print('🗑️ All buddy requests cleared for user: $userId');
    } catch (e) {
      print('❌ Error clearing request history: $e');
      rethrow;
    }
  }

  // ✅ اضافه کردن متد برای دریافت تاریخچه کامل درخواست‌ها
  Future<List<Map<String, dynamic>>> getRequestHistory(String userId) async {
    try {
      final response = await _client
          .from('buddy_requests')
          .select('*, from_user_id, to_user_id')
          .or('from_user_id.eq.$userId,to_user_id.eq.$userId')
          .order('created_at', ascending: false);

      if (response.isEmpty) return [];

      List<Map<String, dynamic>> result = [];
      for (var request in response) {
        final fromUserId = request['from_user_id'];
        final toUserId = request['to_user_id'];

        // دریافت پروفایل فرستنده
        final fromProfile = await _client
            .from('profiles')
            .select('name, avatar_url')
            .eq('user_id', fromUserId)
            .maybeSingle();

        // دریافت پروفایل گیرنده
        final toProfile = await _client
            .from('profiles')
            .select('name, avatar_url')
            .eq('user_id', toUserId)
            .maybeSingle();

        result.add({
          ...request,
          'from_user': fromProfile ?? {'name': 'کاربر', 'avatar_url': null},
          'to_user': toProfile ?? {'name': 'کاربر', 'avatar_url': null},
        });
      }

      return result;
    } catch (e) {
      print('❌ Error getting request history: $e');
      return [];
    }
  }

  // lib/services/buddy_matcher_service.dart

  // ==================== پاسخ به درخواست ====================

  Future<void> respondToBuddyRequest(String requestId, bool accept) async {
    try {
      final status = accept ? 'accepted' : 'rejected';

      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('کاربر احراز هویت نشده است');
      }

      print('🔍 Responding to request: $requestId');
      print('🔍 Current user: ${currentUser.id}');

      // 1. بررسی وجود درخواست
      final checkRequest = await _client
          .from('buddy_requests')
          .select('id, from_user_id, to_user_id, status')
          .eq('id', requestId)
          .maybeSingle();

      if (checkRequest == null) {
        throw Exception('درخواست یافت نشد');
      }

      print('📊 Found request:');
      print('   - ID: ${checkRequest['id']}');
      print('   - from: ${checkRequest['from_user_id']}');
      print('   - to: ${checkRequest['to_user_id']}');
      print('   - status: ${checkRequest['status']}');

      // ✅ چک: کاربر فعلی باید گیرنده درخواست باشد
      if (checkRequest['to_user_id'] != currentUser.id) {
        print('⚠️ Current user is not the recipient of this request');
      }

      // ✅ 2. اگر accept، اول conversation رو بساز
      // ✅ بعد status رو آپدیت کن (تا اگه خطا داد، درخواست خراب نشه)
      if (accept) {
        final request = checkRequest;
        print('📊 Accepting request:');
        print('   - from_user_id: ${request['from_user_id']}');
        print('   - to_user_id: ${request['to_user_id']}');

        final chatService = ChatService();

        // بررسی وجود گفتگو
        final existingConversations = await chatService.getUserConversations(
          request['from_user_id'],
        );

        bool conversationExists = false;
        String? existingConversationId;

        for (var conv in existingConversations) {
          if (conv.type == ConversationType.buddy) {
            final hasFromUser =
                conv.memberIds.contains(request['from_user_id']);
            final hasToUser = conv.memberIds.contains(request['to_user_id']);
            if (hasFromUser && hasToUser) {
              conversationExists = true;
              existingConversationId = conv.id;
              print('ℹ️ Conversation already exists: ${conv.id}');
              break;
            }
          }
        }

        String? conversationId;

        if (!conversationExists) {
          final memberIds = <String>[
            request['from_user_id'] as String,
            request['to_user_id'] as String,
          ].where((id) => id.isNotEmpty).toList();

          if (memberIds.length >= 2) {
            print('🔍 Creating conversation with members: $memberIds');

            conversationId = await chatService.createConversation(
              type: 'buddy',
              memberIds: memberIds,
              name: null,
              createdBy: currentUser.id,
            );
            print('✅ Conversation created: $conversationId');
          } else {
            throw Exception('Invalid members for conversation');
          }
        } else {
          conversationId = existingConversationId;
        }

        // ✅ حالا که conversation ساخته شد، status رو آپدیت کن
        final updateResponse = await _client
            .from('buddy_requests')
            .update({'status': 'accepted'})
            .eq('id', requestId)
            .select();

        if (updateResponse.isEmpty) {
          throw Exception('به‌روزرسانی درخواست انجام نشد');
        }

        print('✅ Request accepted and conversation created: $conversationId');
      } else {
        // ✅ برای reject، فقط status رو آپدیت کن
        final updateResponse = await _client
            .from('buddy_requests')
            .update({'status': 'rejected'})
            .eq('id', requestId)
            .select();

        if (updateResponse.isEmpty) {
          throw Exception('به‌روزرسانی درخواست انجام نشد');
        }

        print('✅ Request rejected');
      }
    } catch (e) {
      print('❌ Error responding to buddy request: $e');
      rethrow;
    }
  }

  Future<void> cancelBuddyRequest(String fromUserId, String toUserId) async {
    try {
      print('📊 Cancelling request from $fromUserId to $toUserId');

      // ✅ حذف درخواست
      final deleteResponse = await _client
          .from('buddy_requests')
          .delete()
          .eq('from_user_id', fromUserId)
          .eq('to_user_id', toUserId)
          .eq('status', 'pending')
          .select();

      if (deleteResponse.isEmpty) {
        print('⚠️ No pending request found to cancel');
      } else {
        print('🗑️ Buddy request cancelled successfully');
      }
    } catch (e) {
      print('❌ Error cancelling buddy request: $e');
      rethrow;
    }
  }

  Future<User?> getCurrentUser() async {
    try {
      return _client.auth.currentUser;
    } catch (e) {
      return null;
    }
  }
}
