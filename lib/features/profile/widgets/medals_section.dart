// lib/features/profile/widgets/medals_section.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/core/app_palette.dart';
import '/providers/theme_provider.dart';
import '/services/supabase_service.dart';

/// مدال‌ها و افتخارات: مدال ماموریت‌ها و چالش‌های انجام‌شده (جدول user_badges).
class MedalsSection extends StatefulWidget {
  final String userId;
  final int refreshToken;

  const MedalsSection({super.key, required this.userId, this.refreshToken = 0});

  @override
  State<MedalsSection> createState() => _MedalsSectionState();
}

class _MedalsSectionState extends State<MedalsSection> {
  List<Map<String, dynamic>> _badges = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MedalsSection old) {
    super.didUpdateWidget(old);
    if (old.refreshToken != widget.refreshToken ||
        old.userId != widget.userId) {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final rows = await SupabaseService()
          .client
          .from('user_badges')
          .select('badge_name, badge_icon, badge_type')
          .eq('user_id', widget.userId)
          .order('earned_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _badges = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // نام ذخیره‌شده با آیکون شروع می‌شود؛ در نمایش فقط عنوان را می‌خواهیم
  String _title(Map<String, dynamic> b) {
    final name = (b['badge_name'] as String?) ?? '';
    final icon = (b['badge_icon'] as String?) ?? '';
    return name.startsWith(icon) ? name.substring(icon.length).trim() : name;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final quests = _badges.where((b) => b['badge_type'] == 'quest').toList();
    final challenges =
        _badges.where((b) => b['badge_type'] == 'challenge').toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: theme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.military_tech_rounded,
                  color: theme.textColor, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text('مدال‌ها و افتخارات',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: theme.textColor)),
              ),
              Text('${_badges.length}',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.textSecondaryColor)),
            ],
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Center(
                child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2)))
          else if (_badges.isEmpty)
            Text('هنوز مدالی نگرفته‌ای. ماموریت یا چالشی را تمام کن تا اولین مدال به نامت بخورد.',
                style: TextStyle(
                    fontSize: 13, height: 1.8, color: theme.textSecondaryColor))
          else ...[
            if (quests.isNotEmpty)
              _group(theme, 'ماموریت‌ها', quests, Tone.mint),
            if (quests.isNotEmpty && challenges.isNotEmpty)
              const SizedBox(height: 14),
            if (challenges.isNotEmpty)
              _group(theme, 'چالش‌ها', challenges, Tone.butter),
          ],
        ],
      ),
    );
  }

  Widget _group(ThemeProvider theme, String label,
      List<Map<String, dynamic>> items, Tone tone) {
    final tc = theme.tone(tone);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.textSecondaryColor)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 12,
          children: [
            for (final b in items)
              SizedBox(
                width: 76,
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration:
                          BoxDecoration(color: tc.bg, shape: BoxShape.circle),
                      child: Text((b['badge_icon'] as String?) ?? '🏅',
                          style: const TextStyle(fontSize: 26)),
                    ),
                    const SizedBox(height: 6),
                    Text(_title(b),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: theme.textColor)),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
