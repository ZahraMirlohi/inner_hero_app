// lib/services/privacy_service.dart
//
// تنظیمات حریم خصوصی هم‌مسیری که روی سرور ذخیره می‌شن:
// دریافت درخواست (profiles.allow_buddy_requests) و نمایش در پیشنهادها
// (user_personalities.is_looking_for_buddy).

import 'package:supabase_flutter/supabase_flutter.dart';

class PrivacyService {
  PrivacyService._();
  static final PrivacyService instance = PrivacyService._();

  SupabaseClient get _c => Supabase.instance.client;
  String? get _me => _c.auth.currentUser?.id;

  Future<bool> allowRequests() async {
    final me = _me;
    if (me == null) return true;
    try {
      final r = await _c
          .from('profiles')
          .select('allow_buddy_requests')
          .eq('user_id', me)
          .maybeSingle();
      return r?['allow_buddy_requests'] != false;
    } catch (_) {
      return true; // ستون هنوز ساخته نشده
    }
  }

  Future<bool> discoverable() async {
    final me = _me;
    if (me == null) return true;
    try {
      final r = await _c
          .from('user_personalities')
          .select('is_looking_for_buddy')
          .eq('user_id', me)
          .maybeSingle();
      return r?['is_looking_for_buddy'] != false;
    } catch (_) {
      return true;
    }
  }

  Future<void> setAllowRequests(bool v) async {
    final me = _me;
    if (me == null) return;
    await _c.from('profiles').update({'allow_buddy_requests': v}).eq('user_id', me);
  }

  Future<void> setDiscoverable(bool v) async {
    final me = _me;
    if (me == null) return;
    await _c
        .from('user_personalities')
        .update({'is_looking_for_buddy': v}).eq('user_id', me);
  }
}
