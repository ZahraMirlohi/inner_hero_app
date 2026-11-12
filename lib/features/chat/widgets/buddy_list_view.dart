import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/core/app_palette.dart';
import '/l10n/app_strings.dart';
import '/providers/theme_provider.dart';
import '/services/chat_service.dart';
import 'avatar_viewer.dart';

/// لیست هم‌مسیرها (مستقل از وجود گفتگو). لمس = باز کردن گفتگو، منو = حذف هم‌مسیر.
class BuddyListView extends StatefulWidget {
  final void Function(String userId) onOpen;
  const BuddyListView({super.key, required this.onOpen});

  @override
  State<BuddyListView> createState() => _BuddyListViewState();
}

class _BuddyListViewState extends State<BuddyListView> {
  final _chat = ChatService();
  List<Map<String, dynamic>> _buddies = [];
  final Set<String> _busy = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = (await _chat.getCurrentUser())?.id;
      if (me == null) return;
      final list = await _chat.getBuddies(me);
      if (mounted) setState(() => _buddies = list);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _remove(Map<String, dynamic> b) async {
    final id = b['user_id'] as String;
    if (_busy.contains(id)) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(c.tr('bd.remove')),
        content: Text(c.tr('bd.remove.q', {'n': '${b['name']}'})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(c.tr('bd.cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(c.tr('bd.delete'),
                  style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy.add(id));
    try {
      final me = (await _chat.getCurrentUser())!.id;
      await _chat.removeBuddy(me, id);
      if (!mounted) return;
      setState(() => _buddies.removeWhere((x) => x['user_id'] == id));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('bd.removed'))));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr('bd.error'))));
      }
    } finally {
      _busy.remove(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_buddies.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(context.tr('bd.empty'),
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: theme.textSecondaryColor, fontSize: 14)),
        ),
      );
    }
    final tc = theme.tone(Tone.lilac);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 160),
        itemCount: _buddies.length,
        itemBuilder: (_, i) {
          final b = _buddies[i];
          final url = b['avatar_url'];
          final has = url is String && url.trim().isNotEmpty;
          return GestureDetector(
            onTap: () => widget.onOpen(b['user_id'] as String),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(28),
                boxShadow: theme.softShadow,
              ),
              child: Row(children: [
                GestureDetector(
                  onTap: has ? () => showAvatarViewer(context, url) : null,
                  child: Container(
                    width: 48,
                    height: 48,
                    clipBehavior: Clip.antiAlias,
                    decoration:
                        BoxDecoration(color: tc.bg, shape: BoxShape.circle),
                    child: has
                        ? Image.network(url.trim(),
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) =>
                                Icon(Icons.person_rounded, color: tc.fg))
                        : Icon(Icons.person_rounded, color: tc.fg),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${b['name'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: theme.textColor)),
                ),
                IconButton(
                  icon: Icon(Icons.person_remove_rounded,
                      color: theme.textSecondaryColor),
                  tooltip: context.tr('bd.remove'),
                  onPressed: _busy.contains(b['user_id'])
                      ? null
                      : () => _remove(b),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}
