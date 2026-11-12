// lib/features/chat/widgets/buddy_requests_view.dart
//
// درخواست‌های هم‌مسیری: دریافتی (قبول/رد) و ارسال‌شده (لغو). هر دکمه تا پایان کار قفل می‌شود.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '/core/app_palette.dart';
import '/providers/theme_provider.dart';
import '/services/buddy_matcher_service.dart';

class BuddyRequestsView extends StatefulWidget {
  /// بعد از هر تغییر (قبول/رد/لغو) صدا زده می‌شود؛ شمارندهٔ دریافتی‌ها را می‌دهد.
  final void Function(int incomingCount, {bool accepted}) onChanged;
  const BuddyRequestsView({super.key, required this.onChanged});

  @override
  State<BuddyRequestsView> createState() => _BuddyRequestsViewState();
}

class _BuddyRequestsViewState extends State<BuddyRequestsView> {
  final _client = Supabase.instance.client;
  final _matcher = BuddyMatcherService();
  List<Map<String, dynamic>> _incoming = [];
  List<Map<String, dynamic>> _sent = [];
  final Set<String> _busy = {};
  bool _loading = true;

  String get _me => _client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _client
          .from('buddy_requests')
          .select('id, from_user_id, to_user_id')
          .eq('status', 'pending')
          .or('from_user_id.eq.$_me,to_user_id.eq.$_me')
          .order('created_at', ascending: false);
      final ids = {
        for (final r in rows)
          (r['from_user_id'] == _me ? r['to_user_id'] : r['from_user_id'])
              as String
      }.toList();
      final profiles = ids.isEmpty
          ? []
          : await _client
              .from('profiles')
              .select('user_id, name, avatar_url')
              .inFilter('user_id', ids);
      final byId = {for (final p in profiles) p['user_id'] as String: p};
      final inc = <Map<String, dynamic>>[];
      final out = <Map<String, dynamic>>[];
      for (final r in rows) {
        final mine = r['from_user_id'] == _me;
        final other = (mine ? r['to_user_id'] : r['from_user_id']) as String;
        final item = {
          'id': r['id'] as String,
          'other_id': other,
          'name': byId[other]?['name'] ?? 'کاربر',
          'avatar_url': byId[other]?['avatar_url'],
        };
        (mine ? out : inc).add(item);
      }
      if (!mounted) return;
      setState(() {
        _incoming = inc;
        _sent = out;
        _loading = false;
      });
      widget.onChanged(inc.length);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respond(Map<String, dynamic> r, bool accept) async {
    final id = r['id'] as String;
    if (!_busy.add(id)) return; // کلیک دوباره‌ی همان درخواست نادیده گرفته می‌شود
    setState(() {});
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _matcher.respondToBuddyRequest(id, accept);
      if (!mounted) return;
      setState(() => _incoming.removeWhere((x) => x['id'] == id));
      widget.onChanged(_incoming.length, accepted: accept);
      messenger.showSnackBar(SnackBar(
          content: Text(accept ? 'درخواست پذیرفته شد' : 'درخواست رد شد')));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('انجام نشد، دوباره امتحان کن')));
    } finally {
      _busy.remove(id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _cancel(Map<String, dynamic> r) async {
    final id = r['id'] as String;
    if (!_busy.add(id)) return;
    setState(() {});
    try {
      await _matcher.cancelBuddyRequest(_me, r['other_id'] as String);
      if (mounted) setState(() => _sent.removeWhere((x) => x['id'] == id));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لغو انجام نشد')));
      }
    } finally {
      _busy.remove(id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_incoming.isEmpty && _sent.isEmpty) {
      return Center(
        child: Text('درخواستی در انتظار نیست',
            style: TextStyle(color: theme.textSecondaryColor, fontSize: 14)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 160),
        children: [
          if (_incoming.isNotEmpty) _header(theme, 'دریافت‌شده'),
          for (final r in _incoming) _row(theme, r, incoming: true),
          if (_sent.isNotEmpty) _header(theme, 'ارسال‌شده'),
          for (final r in _sent) _row(theme, r, incoming: false),
        ],
      ),
    );
  }

  Widget _header(ThemeProvider theme, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
        child: Text(t,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: theme.textSecondaryColor)),
      );

  Widget _circle(Color bg, IconData icon, Color fg, VoidCallback? onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: fg),
        ),
      );

  Widget _row(ThemeProvider theme, Map<String, dynamic> r,
      {required bool incoming}) {
    final busy = _busy.contains(r['id']);
    final url = r['avatar_url'];
    final has = url is String && url.trim().isNotEmpty;
    final tc = theme.tone(Tone.lilac);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: theme.softShadow,
      ),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: tc.bg, shape: BoxShape.circle),
          child: has
              ? Image.network(url.trim(),
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) =>
                      Icon(Icons.person_rounded, color: tc.fg))
              : Icon(Icons.person_rounded, color: tc.fg),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(r['name'] as String,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: theme.textColor)),
        ),
        if (busy)
          const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2))
        else if (incoming) ...[
          _circle(theme.effectivePrimary, Icons.check_rounded,
              theme.onPrimaryColor, () => _respond(r, true)),
          const SizedBox(width: 8),
          _circle(theme.disabledButtonBackground, Icons.close_rounded,
              theme.textSecondaryColor, () => _respond(r, false)),
        ] else
          GestureDetector(
            onTap: () => _cancel(r),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: theme.disabledButtonBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('لغو',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.textSecondaryColor)),
            ),
          ),
      ]),
    );
  }
}
