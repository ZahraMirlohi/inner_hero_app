// پیام‌های غنی (گزارش، لیست امروز، پیشرفت، مخاطب، لوکیشن) برای چت گروه
// منطق ارسال/نمایش مشابه چت هم‌مسیر است.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:url_launcher/url_launcher.dart';
import '/providers/theme_provider.dart';
import '/services/supabase_service.dart';
import '/services/today_habits_service.dart';
import '/services/weekly_performance_service.dart';
import '../models/message_model.dart';
import '../models/today_habits_list.dart';
import '../models/weekly_habit_performance.dart';
import '../utils/chat_colors.dart';
import 'today_habits_list_widget.dart';
import 'weekly_performance_widget.dart';

class RichPayload {
  final String text;
  final MessageType type;
  final Map<String, dynamic>? meta;
  RichPayload(this.text, {this.type = MessageType.text, this.meta});
}

const _months = [
  'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
  'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
];

class GroupRichSender {
  /// گزارش هفتگی؛ null یعنی داده‌ای نیست
  static Future<RichPayload?> weekly(String userId) async {
    final p = await WeeklyPerformanceService().getUserWeeklyPerformance(userId);
    if (p == null) return null;
    final percent = (p.successRate * 100).toInt();
    return RichPayload(
      '📊 عملکرد هفتگی عادت‌ها\n✅ انجام شده: ${p.completedHabits} از ${p.totalHabits}\n📈 نرخ موفقیت: $percent%\n${p.getMotivationalMessage()}',
      meta: {
        'type': 'weekly_performance',
        'userId': userId,
        'userName': p.userName,
        'habits': p.habits.map((h) => h.toMap()).toList(),
        'weekStart': p.weekStart.toIso8601String(),
        'weekEnd': p.weekEnd.toIso8601String(),
        'totalHabits': p.totalHabits,
        'completedHabits': p.completedHabits,
        'successRate': p.successRate,
        'is_performance_widget': true,
      },
    );
  }

  static Future<RichPayload?> todayList(String userId) async {
    final d = await TodayHabitsService().getUserTodayHabits(userId);
    if (d == null) return null;
    final j = Jalali.fromDateTime(d.date);
    return RichPayload(
      '📋 لیست امروز (${j.day} ${_months[j.month - 1]})\n✅ انجام شده: ${d.completedItems} از ${d.totalItems}\n${d.completionMessage}',
      meta: {
        'is_today_list_widget': true,
        'userId': userId,
        'userName': d.userName,
        'date': d.date.toIso8601String(),
        'habits': d.habits.map((h) => h.toMap()).toList(),
        'tasks': d.tasks.map((t) => t.toMap()).toList(),
        'challenges': d.challenges.map((c) => c.toMap()).toList(),
        'quests': d.quests.map((q) => q.toMap()).toList(),
        'totalItems': d.totalItems,
        'completedItems': d.completedItems,
      },
    );
  }

  static Future<RichPayload?> progress(String userId) async {
    final sb = SupabaseService();
    final habits = await sb.getHabits(userId);
    final today = DateTime.now();
    var total = 0, done = 0;
    for (final h in habits) {
      if (!h.isActive || !h.shouldDoOnDate(today)) continue;
      total++;
      if (await sb.isHabitCompletedOnDate(h.id, userId, today)) done++;
    }
    final profile = await sb.client
        .from('profiles')
        .select('current_streak')
        .eq('user_id', userId)
        .maybeSingle();
    final streak = (profile?['current_streak'] as num?)?.toInt() ?? 0;

    final weekDays = List<bool>.filled(7, false);
    final start = today.subtract(Duration(days: Jalali.fromDateTime(today).weekDay - 1));
    final dates = [
      for (var i = 0; i < 7; i++)
        start.add(Duration(days: i)).toIso8601String().split('T').first
    ];
    try {
      final rows = await sb.client
          .from('user_daily_activity')
          .select('activity_date, is_active')
          .eq('user_id', userId)
          .inFilter('activity_date', dates);
      for (final r in rows) {
        final i = dates.indexOf(r['activity_date'].toString().split('T').first);
        if (i != -1) weekDays[i] = r['is_active'] == true;
      }
    } catch (_) {}

    return RichPayload(
      '📊 کارت پیشرفت روزانه\n✅ انجام شده: $done\n⏳ باقیمانده: ${total - done}\n🔥 استریک: $streak روز',
      type: MessageType.progress,
      meta: {
        'streak': streak,
        'completed': done,
        'total': total,
        'weekDays': weekDays,
        'is_progress_card': true,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// انتخاب مخاطب با انتخابگر خود سیستم (بدون نیاز به مجوز)
  static Future<RichPayload?> contact() async {
    final c = await FlutterContacts.openExternalPick();
    if (c == null) return null;
    final phone = c.phones.isNotEmpty ? c.phones.first.number : 'شماره موجود نیست';
    return RichPayload(
        '📞 شماره تماس\n👤 نام: ${c.displayName}\n📱 شماره: $phone');
  }
}

class GroupRichContent {
  static bool isContact(String t) =>
      t.contains('📞 شماره تماس') || t.contains('👤 نام:') || t.contains('📱 شماره:');

  static bool isLocation(String t) {
    final l = t.toLowerCase();
    return ['openstreetmap.org', 'google.com/maps', 'maps.google.com', 'neshan.org', 'map.ir', '?mlat=', '?lat=']
        .any(l.contains);
  }

  /// null یعنی پیام غنی نیست و فرستنده باید متن/عکس/فایل معمولی را نشان دهد
  static Widget? build(BuildContext context, ChatMessage m, bool isMe, ThemeProvider theme) {
    final md = m.metadata;
    final fallback = Text(m.content,
        style: TextStyle(color: isMe ? const Color(0xFF090909) : theme.textColor, fontSize: 13));
    try {
      if (md != null && md['is_today_list_widget'] == true) {
        return TodayHabitsListWidget(
            key: ValueKey('today_${m.id}'), data: TodayHabitsList.fromMetadata(md), isMe: isMe);
      }
      if (md != null && md['is_performance_widget'] == true) {
        return WeeklyPerformanceWidget(
            key: ValueKey('weekly_${m.id}'), data: WeeklyHabitPerformance.fromMetadata(md), isMe: isMe);
      }
    } catch (_) {
      return fallback;
    }
    if (md != null && md['is_progress_card'] == true || m.type == MessageType.progress) {
      return _progress(m, isMe, theme);
    }
    if (m.type == MessageType.text && isLocation(m.content)) return _location(m, isMe, theme);
    if (m.type == MessageType.text && isContact(m.content)) return _contact(context, m, isMe, theme);
    return null;
  }

  static Widget _progress(ChatMessage m, bool isMe, ThemeProvider theme) {
    final md = m.metadata ?? {};
    final streak = md['streak'] ?? 0;
    final done = (md['completed'] as num?)?.toInt() ?? 0;
    final total = (md['total'] as num?)?.toInt() ?? 0;
    final days = md['weekDays'] is List ? List<bool>.from(md['weekDays']) : <bool>[];
    final bg = isMe ? ChatColors.myBubble(theme) : ChatColors.otherBubble(theme);
    final fg = isMe ? ChatColors.myBubbleText(theme) : ChatColors.otherBubbleText(theme);
    const letters = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
    return Container(
      width: 260,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Icon(Icons.trending_up, color: fg, size: 16),
            const SizedBox(width: 6),
            Text('پیشرفت روزانه',
                style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.bold)),
            const Spacer(),
            Icon(Icons.local_fire_department, color: fg, size: 14),
            Text(' $streak روز', style: TextStyle(color: fg, fontSize: 11)),
          ]),
          const SizedBox(height: 10),
          Text('$done انجام شده  •  ${total - done} باقیمانده',
              style: TextStyle(color: fg, fontSize: 12)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total > 0 ? done / total : 0,
              backgroundColor: fg.withValues(alpha: 0.15),
              color: fg,
              minHeight: 5,
            ),
          ),
          if (days.length == 7) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var i = 0; i < 7; i++)
                  Column(children: [
                    Text(letters[i], style: TextStyle(color: fg, fontSize: 10)),
                    const SizedBox(height: 2),
                    Icon(days[i] ? Icons.check_circle : Icons.circle_outlined,
                        size: 14, color: fg.withValues(alpha: days[i] ? 1 : 0.4)),
                  ]),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static Widget _location(ChatMessage m, bool isMe, ThemeProvider theme) {
    final fg = isMe ? ChatColors.myBubbleText(theme) : theme.textColor;
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(m.content), mode: LaunchMode.externalApplication),
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? ChatColors.myBubble(theme) : ChatColors.otherBubble(theme),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          Icon(Icons.location_on, color: fg, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text('📍 موقعیت مکانی\nمشاهده روی نقشه',
                style: TextStyle(color: fg, fontSize: 12, height: 1.6)),
          ),
          Icon(Icons.open_in_new, size: 16, color: fg),
        ]),
      ),
    );
  }

  static Widget _contact(BuildContext context, ChatMessage m, bool isMe, ThemeProvider theme) {
    var name = '', phone = '';
    for (final line in m.content.split('\n')) {
      if (line.contains('👤 نام:')) name = line.replaceAll('👤 نام:', '').trim();
      if (line.contains('📱 شماره:')) phone = line.replaceAll('📱 شماره:', '').trim();
    }
    final has = phone.isNotEmpty && phone != 'شماره موجود نیست';
    return GestureDetector(
      onTap: has ? () => showPhoneActions(context, theme, name, phone) : null,
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF090909) : theme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          const Icon(Icons.contact_phone, color: Colors.blue, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.isEmpty ? 'مخاطب' : name,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isMe ? Colors.white : theme.textColor)),
              Text(phone,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                      fontSize: 12, color: isMe ? Colors.white70 : theme.textSecondaryColor)),
            ]),
          ),
        ]),
      ),
    );
  }

  /// تماس (شماره‌گیر با شماره‌ی آماده) / کپی / ذخیره در مخاطبین
  static void showPhoneActions(BuildContext context, ThemeProvider theme, String name, String phone) {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Text(phone,
              textDirection: TextDirection.ltr,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textColor)),
          ListTile(
            leading: const Icon(Icons.call),
            title: const Text('تماس'),
            onTap: () {
              Navigator.pop(ctx);
              launchUrl(Uri.parse('tel:$clean'), mode: LaunchMode.externalApplication);
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('کپی شماره'),
            onTap: () {
              Navigator.pop(ctx);
              Clipboard.setData(ClipboardData(text: phone));
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_add_alt_1),
            title: const Text('ذخیره در مخاطبین'),
            onTap: () async {
              Navigator.pop(ctx);
              try {
                await FlutterContacts.openExternalInsert(
                    Contact(displayName: name, phones: [Phone(phone)]));
              } catch (_) {}
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
