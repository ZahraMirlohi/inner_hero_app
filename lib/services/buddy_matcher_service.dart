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

  // ==================== پیدا کردن هم‌مسیرها ====================

  // lib/services/buddy_matcher_service.dart

  Future<List<Map<String, dynamic>>> findMatchingBuddies(
    String userId, {
    int limit = 20,
    double minMatchScore = 0,
  }) async {
    try {
      final currentPersonality = await getUserPersonality(userId);
      if (currentPersonality == null) {
        print('❌ No personality found for user: $userId');
        return [];
      }

      print('📊 Current user personality:');
      print('   - Gender: ${currentPersonality.gender}');
      print('   - Looking for buddy: ${currentPersonality.isLookingForBuddy}');

      // ✅ دریافت همه کاربران
      final allUsers = await _client.from('user_personalities').select();
      print('📊 Total users in table: ${allUsers.length}');

      // ✅ فیلتر کاربرانی که به دنبال هم‌مسیر هستند
      final lookingUsers = allUsers.where((user) {
        final looking = user['is_looking_for_buddy'];
        if (looking == null) return false;
        if (looking is bool) return looking == true;
        if (looking is String) return looking.toLowerCase() == 'true';
        return false;
      }).toList();

      print('📊 Users looking for buddy: ${lookingUsers.length}');

      // ✅ حذف کاربر فعلی
      final otherUsers = lookingUsers.where((user) {
        return user['user_id'] != userId;
      }).toList();

      print('📊 Other users: ${otherUsers.length}');

      if (otherUsers.isEmpty) {
        print('⚠️ No other users found');
        return [];
      }

      // ✅ دریافت لیست مسدود شده‌ها
      final blockedResponse = await _client
          .from('blocked_users')
          .select('blocked_id')
          .eq('blocker_id', userId);

      final blockedIds = blockedResponse
          .map((b) => b['blocked_id'] as String)
          .toSet();

      // ✅ دریافت لیست کاربرانی که با آنها چت روم دارند (هم‌مسیرهای فعلی)
      final chatService = ChatService();
      final existingConversations = await chatService.getUserConversations(
        userId,
      );

      final existingBuddyIds = <String>{};
      for (var conv in existingConversations) {
        if (conv.type == ConversationType.buddy) {
          for (var memberId in conv.memberIds) {
            if (memberId != userId) {
              existingBuddyIds.add(memberId);
            }
          }
        }
      }
      print('📊 Existing buddies (with chat): $existingBuddyIds');

      // ✅ دریافت درخواست‌های ارسال شده (pending)
      final sentRequests = await _client
          .from('buddy_requests')
          .select('to_user_id, id')
          .eq('from_user_id', userId)
          .eq('status', 'pending');

      final sentRequestIds = sentRequests
          .map((r) => r['to_user_id'] as String)
          .toSet();

      final sentRequestMap = <String, String>{};
      for (var r in sentRequests) {
        sentRequestMap[r['to_user_id'] as String] = r['id'] as String;
      }
      print('📊 Sent pending requests to: $sentRequestIds');

      // ✅ دریافت درخواست‌های دریافت شده (pending)
      final receivedRequests = await _client
          .from('buddy_requests')
          .select('from_user_id, id')
          .eq('to_user_id', userId)
          .eq('status', 'pending');

      final receivedRequestIds = receivedRequests
          .map((r) => r['from_user_id'] as String)
          .toSet();

      final receivedRequestMap = <String, String>{};
      for (var r in receivedRequests) {
        receivedRequestMap[r['from_user_id'] as String] = r['id'] as String;
      }
      print('📊 Received pending requests from: $receivedRequestIds');

      // ✅ فیلتر نهایی - فقط کاربران مسدود شده حذف می‌شوند
      final filteredUsers = otherUsers.where((user) {
        final otherUserId = user['user_id'];
        if (blockedIds.contains(otherUserId)) {
          print('⏭️ Skipping blocked user: $otherUserId');
          return false;
        }
        return true;
      }).toList();

      print('📊 Filtered users (after all checks): ${filteredUsers.length}');

      if (filteredUsers.isEmpty) {
        print('⚠️ No filtered users found');
        return [];
      }

      // ============================================
      // محاسبه امتیاز تطابق و ساخت لیست با وضعیت چت
      // ============================================

      List<Map<String, dynamic>> matches = [];

      for (var userData in filteredUsers) {
        final otherUserId = userData['user_id'];

        final otherPersonality = UserPersonality.fromMap(userData, otherUserId);
        final matchScore = currentPersonality.calculateMatchScore(
          otherPersonality,
        );

        final profile = await _client
            .from('profiles')
            .select('name, avatar_url, total_xp, current_streak')
            .eq('user_id', otherUserId)
            .maybeSingle();

        // ✅ بررسی وضعیت‌ها
        final isBuddy = existingBuddyIds.contains(otherUserId);
        final isSentByMe = sentRequestIds.contains(otherUserId);
        final isReceivedByMe = receivedRequestIds.contains(otherUserId);
        final hasPendingRequest = isSentByMe || isReceivedByMe;

        String? requestId;
        if (isSentByMe) {
          requestId = sentRequestMap[otherUserId];
        } else if (isReceivedByMe) {
          requestId = receivedRequestMap[otherUserId];
        }

        String? conversationId;
        if (isBuddy) {
          for (var conv in existingConversations) {
            if (conv.type == ConversationType.buddy &&
                conv.memberIds.contains(otherUserId)) {
              conversationId = conv.id;
              break;
            }
          }
        }

        matches.add({
          'user_id': otherUserId,
          'name': profile?['name'] ?? 'کاربر ${otherUserId.substring(0, 6)}',
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
          'has_pending_request': hasPendingRequest,
          'is_sent_by_me': isSentByMe,
          'is_received_by_me': isReceivedByMe,
          'request_id': requestId,
          'conversation_id': conversationId,
        });
      }

      matches.sort(
        (a, b) =>
            (b['match_score'] as double).compareTo(a['match_score'] as double),
      );

      print('✅ Found ${matches.length} matches');
      for (var match in matches.take(5)) {
        print(
          '   - ${match['name']}: ${match['match_score'].toStringAsFixed(1)}% (buddy: ${match['is_buddy']}, pending: ${match['has_pending_request']})',
        );
      }

      return matches.take(limit).toList();
    } catch (e) {
      print('❌ Error finding matching buddies: $e');
      return [];
    }
  }

  // ==================== سایر متدها ====================

  // lib/services/buddy_matcher_service.dart

  Future<void> sendBuddyRequestWithMatch(
    String fromUserId,
    String toUserId, {
    String? message,
  }) async {
    try {
      print('📊 Sending buddy request from $fromUserId to $toUserId');

      // ✅ 1. حذف درخواست‌های قبلی (همه وضعیت‌ها)
      await _client
          .from('buddy_requests')
          .delete()
          .eq('from_user_id', fromUserId)
          .eq('to_user_id', toUserId);

      print('🗑️ Removed previous requests');

      // ✅ 2. محاسبه امتیاز تطابق
      final fromPersonality = await getUserPersonality(fromUserId);
      final toPersonality = await getUserPersonality(toUserId);

      double matchScore = 0;
      if (fromPersonality != null && toPersonality != null) {
        matchScore = fromPersonality.calculateMatchScore(toPersonality);
      }

      print('📊 Match score: $matchScore');

      // ✅ 3. ایجاد درخواست جدید
      final insertResponse = await _client.from('buddy_requests').insert({
        'from_user_id': fromUserId,
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

  // lib/services/buddy_matcher_service.dart

  Future<void> respondToBuddyRequest(String requestId, bool accept) async {
    try {
      final status = accept ? 'accepted' : 'rejected';

      // ✅ 1. ابتدا بررسی کنید که درخواست وجود دارد
      final checkRequest = await _client
          .from('buddy_requests')
          .select('id, from_user_id, to_user_id, status')
          .eq('id', requestId)
          .maybeSingle();

      if (checkRequest == null) {
        print('⚠️ Request with id $requestId not found');
        throw Exception('درخواست یافت نشد');
      }

      print('📊 Found request:');
      print('   - ID: ${checkRequest['id']}');
      print('   - from: ${checkRequest['from_user_id']}');
      print('   - to: ${checkRequest['to_user_id']}');
      print('   - status: ${checkRequest['status']}');

      // ✅ 2. به‌روزرسانی وضعیت درخواست
      final updateResponse = await _client
          .from('buddy_requests')
          .update({'status': status})
          .eq('id', requestId)
          .select();

      print('📊 Update response: $updateResponse');

      if (updateResponse.isEmpty) {
        print('⚠️ No rows updated');
        throw Exception('به‌روزرسانی درخواست انجام نشد');
      }

      print('📊 Request status updated to: $status');

      if (accept) {
        final request = checkRequest;
        print('📊 Accepting request:');
        print('   - from_user_id: ${request['from_user_id']}');
        print('   - to_user_id: ${request['to_user_id']}');

        final chatService = ChatService();

        // ✅ 3. بررسی وجود گفتگو
        final existingConversations = await chatService.getUserConversations(
          request['from_user_id'],
        );

        bool conversationExists = false;
        for (var conv in existingConversations) {
          if (conv.type == ConversationType.buddy) {
            final hasFromUser = conv.memberIds.contains(
              request['from_user_id'],
            );
            final hasToUser = conv.memberIds.contains(request['to_user_id']);
            if (hasFromUser && hasToUser) {
              conversationExists = true;
              print('ℹ️ Conversation already exists: ${conv.id}');
              break;
            }
          }
        }

        // ✅ 4. ایجاد گفتگو اگر وجود ندارد
        if (!conversationExists) {
          final memberIds = <String>[
            request['from_user_id'] as String,
            request['to_user_id'] as String,
          ].where((id) => id.isNotEmpty).toList();

          if (memberIds.length >= 2) {
            final convId = await chatService.createConversation(
              type: 'buddy',
              memberIds: memberIds,
              name: null,
              createdBy: request['from_user_id'],
            );
            print('✅ Conversation created: $convId');

            // ✅ 5. صبر کنید تا گفتگو در دیتابیس ثبت شود
            await Future.delayed(const Duration(milliseconds: 500));
          } else {
            print('❌ Not enough valid members: $memberIds');
            throw Exception('Invalid members for conversation');
          }
        } else {
          print('ℹ️ Using existing conversation');
        }
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
