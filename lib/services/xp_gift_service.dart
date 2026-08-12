// lib/services/xp_gift_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/chat/models/xp_gift.dart';
import 'supabase_service.dart';

class XPGiftService {
  final SupabaseClient _client = Supabase.instance.client;
  final SupabaseService _supabase = SupabaseService();

  // ✅ کش ساده برای جلوگیری از درخواست‌های مکرر
  final Map<String, _CachedGift> _giftCache = {};
  static const Duration _cacheDuration = Duration(seconds: 5);

  // ✅ دریافت هدیه با ID (با کش)
  Future<XPGift?> getGiftById(String giftId) async {
    // ✅ اگر در کش است و معتبر است
    if (_giftCache.containsKey(giftId)) {
      final cached = _giftCache[giftId]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheDuration) {
        return cached.gift;
      }
    }

    try {
      final response = await _client
          .from('xp_gifts')
          .select()
          .eq('id', giftId)
          .maybeSingle();

      if (response == null) return null;

      final gift = XPGift.fromMap(response);

      // ✅ ذخیره در کش
      _giftCache[giftId] = _CachedGift(gift: gift, timestamp: DateTime.now());

      return gift;
    } catch (e) {
      print('❌ Error getting gift: $e');
      return null;
    }
  }

  // ✅ پاک کردن کش یک هدیه خاص
  void clearGiftCache(String giftId) {
    _giftCache.remove(giftId);
  }

  // ✅ دریافت هدیه (با پاک کردن کش بعد از موفقیت)
  Future<bool> receiveGift(String giftId) async {
    try {
      // 1. دریافت اطلاعات هدیه
      final gift = await getGiftById(giftId);
      if (gift == null) return false;

      // 2. بررسی اینکه قبلاً دریافت نشده
      if (gift.isDelivered) return false;

      // 3. دریافت XP فعلی گیرنده
      final receiverProfile = await _client
          .from('profiles')
          .select('total_xp')
          .eq('user_id', gift.receiverId)
          .maybeSingle();

      final currentXP = receiverProfile?['total_xp'] as int? ?? 0;
      final newXP = currentXP + gift.amount;

      // 4. اضافه کردن XP به گیرنده (در جدول profiles)
      await _client
          .from('profiles')
          .update({'total_xp': newXP})
          .eq('user_id', gift.receiverId);

      // 5. به‌روزرسانی وضعیت هدیه
      await _client
          .from('xp_gifts')
          .update({
            'is_delivered': true,
            'delivered_at': DateTime.now().toIso8601String(),
          })
          .eq('id', giftId);

      // ✅ پاک کردن کش بعد از موفقیت
      clearGiftCache(giftId);

      return true;
    } catch (e) {
      print('❌ Error receiving gift: $e');
      return false;
    }
  }

  // ✅ دریافت هدیه‌های دریافتی کاربر
  Future<List<XPGift>> getReceivedGifts(String userId) async {
    try {
      final response = await _client
          .from('xp_gifts')
          .select()
          .eq('receiver_id', userId)
          .order('sent_at', ascending: false);

      return response.map((data) => XPGift.fromMap(data)).toList();
    } catch (e) {
      print('❌ Error getting received gifts: $e');
      return [];
    }
  }

  // ✅ دریافت هدیه‌های ارسالی کاربر
  Future<List<XPGift>> getSentGifts(String userId) async {
    try {
      final response = await _client
          .from('xp_gifts')
          .select()
          .eq('sender_id', userId)
          .order('sent_at', ascending: false);

      return response.map((data) => XPGift.fromMap(data)).toList();
    } catch (e) {
      print('❌ Error getting sent gifts: $e');
      return [];
    }
  }
}

// ✅ کلاس کمکی برای کش
class _CachedGift {
  final XPGift gift;
  final DateTime timestamp;

  _CachedGift({required this.gift, required this.timestamp});
}
