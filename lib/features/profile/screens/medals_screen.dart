// lib/features/profile/screens/medals_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/core/app_palette.dart';
import '/providers/theme_provider.dart';
import '/services/supabase_service.dart';
import '/widgets/bottom_safe.dart';

/// مدال‌ها و افتخارات: ماموریت‌ها و چالش‌های تمام‌شده، مستقیم از جدول‌های
/// user_quests و user_challenges (نه وابسته به user_badges).
class MedalsScreen extends StatefulWidget {
  final String userId;
  const MedalsScreen({super.key, required this.userId});

  @override
  State<MedalsScreen> createState() => _MedalsScreenState();
}

class _Medal {
  final String title;
  _Medal(this.title);
}

class _MedalsScreenState extends State<MedalsScreen> {
  List<_Medal> _quests = [];
  List<_Medal> _challenges = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<List<_Medal>> _fetch(
      {required String link,
      required String table,
      required String idCol,
      required String? Function(Map<String, dynamic> r) name}) async {
    final client = SupabaseService().client;
    final mine = await client
        .from(link)
        .select(idCol)
        .eq('user_id', widget.userId)
        .eq('is_completed', true);
    final ids = [for (final r in mine) r[idCol]];
    if (ids.isEmpty) return [];
    final rows = await client.from(table).select().inFilter('id', ids);
    return [
      for (final r in rows)
        _Medal(name(Map<String, dynamic>.from(r))?.trim().isNotEmpty == true
            ? name(Map<String, dynamic>.from(r))!
            : (r['title'] as String?) ?? '')
    ];
  }

  Future<void> _load() async {
    try {
      final q = await _fetch(
        link: 'user_quests',
        table: 'quests',
        idCol: 'quest_id',
        name: (r) => r['badge'] as String?,
      );
      final c = await _fetch(
        link: 'user_challenges',
        table: 'challenges',
        idCol: 'challenge_id',
        name: (_) => null,
      );
      if (!mounted) return;
      setState(() {
        _quests = q;
        _challenges = c;
        _loading = false;
      });
    } catch (e) {
      debugPrint('medals load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final empty = _quests.isEmpty && _challenges.isEmpty;

    return BottomSafe(
      child: Scaffold(
        backgroundColor: theme.backgroundColor,
        appBar: AppBar(
          backgroundColor: theme.backgroundColor,
          title: Text('مدال‌ها و افتخارات',
              style: TextStyle(
                  color: theme.textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : empty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                          'هنوز مدالی نگرفته‌ای. یک ماموریت یا چالش را تمام کن تا اولین مدال به نامت بخورد.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14,
                              height: 1.9,
                              color: theme.textSecondaryColor)),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      if (_quests.isNotEmpty)
                        _group(theme, 'ماموریت‌ها', _quests, Tone.mint),
                      if (_challenges.isNotEmpty)
                        _group(theme, 'چالش‌ها', _challenges, Tone.butter),
                    ],
                  ),
      ),
    );
  }

  Widget _group(ThemeProvider theme, String label, List<_Medal> items, Tone tone) {
    final tc = theme.tone(tone);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: theme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: theme.textColor)),
            ),
            Text('${items.length}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.textSecondaryColor)),
          ]),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 14,
            children: [
              for (final m in items)
                SizedBox(
                  width: 88,
                  child: Column(children: [
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration:
                          BoxDecoration(color: tc.bg, shape: BoxShape.circle),
                      child: Icon(
                          tone == Tone.mint
                              ? Icons.military_tech_rounded
                              : Icons.emoji_events_rounded,
                          size: 34,
                          color: tc.fg),
                    ),
                    const SizedBox(height: 6),
                    Text(m.title,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: theme.textColor)),
                  ]),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
