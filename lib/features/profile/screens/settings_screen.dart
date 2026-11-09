// lib/features/profile/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/core/app_palette.dart';
import '/l10n/app_strings.dart';
import '/providers/auth_provider.dart';
import '/providers/calendar_provider.dart';
import '/providers/settings_provider.dart';
import '/providers/sync_provider.dart';
import '/providers/theme_provider.dart';
import '/services/local_storage_service.dart';
import '/services/notification_service.dart';
import '/services/sound_service.dart';
import '/services/supabase_service.dart';
import 'color_picker_screen.dart';
import 'terms_and_conditions_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _appVersion = '1.0.0';
  static const Color _danger = Color(0xFFE5483A);

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
          children: [
            _topBar(theme),
            _section(theme, Tone.lilac, Icons.tune_rounded,
                context.tr('pm.st.general'), [
              _themeModeRow(theme),
              _switchRow(
                theme,
                tone: Tone.peach,
                icon: Icons.notifications_active_rounded,
                title: context.tr('settings.notifications'),
                subtitle: context.tr('settings.notifications_hint'),
                value: settings.notificationsEnabled,
                onChanged: settings.setNotifications,
              ),
              _switchRow(
                theme,
                tone: Tone.butter,
                icon: Icons.music_note_rounded,
                title: context.tr('settings.sound'),
                subtitle: context.tr('settings.sound_hint'),
                value: settings.soundEnabled,
                onChanged: (v) async {
                  await settings.setSound(v);
                  if (v) SoundService.instance.play(Sfx.check);
                },
              ),
              _switchRow(
                theme,
                tone: Tone.peach,
                icon: Icons.vibration_rounded,
                title: context.tr('settings.vibration'),
                subtitle: context.tr('settings.vibration_hint'),
                value: settings.vibrationEnabled,
                onChanged: (v) async {
                  await settings.setVibration(v);
                  if (v) SoundService.instance.play(Sfx.tap);
                },
              ),
              _colorTile(theme),
            ]),
            _section(theme, Tone.sky, Icons.translate_rounded,
                context.tr('pm.st.display'), [
              _calendarRow(theme),
              _languageRow(theme, settings),
            ]),
            _section(theme, Tone.peach, Icons.notifications_rounded,
                context.tr('settings.section_notifications'), [
              _switchRow(
                theme,
                tone: Tone.mint,
                icon: Icons.checklist_rounded,
                title: context.tr('settings.notif_habits'),
                value: settings.rawNotifHabits,
                enabled: settings.notificationsEnabled,
                onChanged: settings.setNotifHabits,
              ),
              _row(
                theme,
                tone: Tone.apricot,
                icon: Icons.schedule_rounded,
                title: context.tr('settings.remind_time'),
                enabled: settings.notifHabits,
                onTap: () async {
                  final cur = await NotificationService.instance.reminderTime();
                  if (!context.mounted) return;
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: cur.hour, minute: cur.minute),
                  );
                  if (picked != null) {
                    await NotificationService.instance
                        .setReminderTime(picked.hour, picked.minute);
                    if (mounted) setState(() {});
                  }
                },
              ),
              _switchRow(
                theme,
                tone: Tone.sky,
                icon: Icons.chat_bubble_rounded,
                title: context.tr('settings.notif_chat'),
                value: settings.rawNotifChat,
                enabled: settings.notificationsEnabled,
                onChanged: settings.setNotifChat,
              ),
              _switchRow(
                theme,
                tone: Tone.butter,
                icon: Icons.emoji_events_rounded,
                title: context.tr('settings.notif_challenges'),
                value: settings.rawNotifChallenges,
                enabled: settings.notificationsEnabled,
                onChanged: settings.setNotifChallenges,
              ),
              _switchRow(
                theme,
                tone: Tone.rose,
                icon: Icons.card_giftcard_rounded,
                title: context.tr('settings.notif_xp'),
                value: settings.rawNotifXp,
                enabled: settings.notificationsEnabled,
                onChanged: settings.setNotifXp,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                child: Text(
                  context.tr('settings.notif_note'),
                  style: TextStyle(
                    color: theme.textSecondaryColor,
                    fontSize: 11.5,
                    height: 1.5,
                  ),
                ),
              ),
            ]),
            _section(theme, Tone.mint, Icons.shield_rounded,
                context.tr('settings.section_privacy'), [
              _switchRow(
                theme,
                tone: Tone.mint,
                icon: Icons.lock_rounded,
                title: context.tr('settings.private_profile'),
                subtitle: context.tr('settings.private_profile_hint'),
                value: settings.privateProfile,
                enabled: false, // تا وقتی ستون سرورش ساخته نشده فقط «به‌زودی»
                onChanged: settings.setPrivateProfile,
                badge: context.tr('common.soon'),
              ),
              _row(
                theme,
                tone: Tone.rose,
                icon: Icons.delete_forever_rounded,
                title: context.tr('settings.delete_account'),
                danger: true,
                onTap: _confirmDeleteAccount,
              ),
            ]),
            _section(theme, Tone.lime, Icons.info_rounded,
                context.tr('settings.section_about'), [
              _row(
                theme,
                tone: Tone.lime,
                icon: Icons.tag_rounded,
                title: context.tr('settings.version'),
                trailing: Text(
                  _appVersion,
                  style: TextStyle(
                    color: theme.textSecondaryColor,
                    fontSize: 13,
                  ),
                ),
              ),
              _row(
                theme,
                tone: Tone.lilac,
                icon: Icons.people_rounded,
                title: context.tr('settings.team'),
                onTap: _showTeamDialog,
              ),
              _row(
                theme,
                tone: Tone.sky,
                icon: Icons.description_rounded,
                title: context.tr('profile.terms'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TermsAndConditionsScreen()),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.isDarkMode
                      ? theme.cardSecondaryColor
                      : const Color(0xFF090909),
                  foregroundColor:
                      theme.isDarkMode ? theme.textColor : Colors.white,
                  elevation: 0,
                  shape: const StadiumBorder(),
                ),
                child: Text(context.tr('settings.logout'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(ThemeProvider theme) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.cardColor,
              shape: BoxShape.circle,
              boxShadow: theme.softShadow,
            ),
            child: Icon(Icons.arrow_back_rounded, textDirection: TextDirection.ltr,
                size: 22, color: theme.textColor),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(context.tr('settings.title'),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: theme.textColor)),
        ),
      ],
    );
  }

  // ─────────────────────────── ساختار ───────────────────────────

  /// بخش: برچسب خاکستری بالای کارت سفید گرد (مثل artboard)
  Widget _section(ThemeProvider theme, Tone tone, IconData icon, String title,
      List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
          child: Text(
            title,
            style: TextStyle(
              color: theme.textSecondaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: theme.softShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              ...children,
              const SizedBox(height: 4),
            ],
          ),
        ),
      ],
    );
  }

  Widget _iconBox(ThemeProvider theme, Tone tone, IconData icon,
      {bool danger = false}) {
    final t = theme.tone(tone);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: danger ? _danger : const Color(0xFF090909).withValues(alpha: theme.isDarkMode ? 0 : 1), size: 20),
    );
  }

  /// سطر فشرده: آیکون رنگی، عنوان، توضیح کوتاه، و عنصر انتهایی
  Widget _row(
    ThemeProvider theme, {
    required Tone tone,
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool danger = false,
    String? badge,
    bool enabled = true,
  }) {
    final showChevron = trailing == null && onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _iconBox(theme, tone, icon, danger: danger),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: danger ? _danger : theme.textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: theme.tone(Tone.butter).bg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: theme.tone(Tone.butter).fg,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            color: theme.textSecondaryColor,
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
              if (showChevron)
                Icon(
                  Icons.chevron_left_rounded,
                  textDirection: TextDirection.ltr,
                  size: 20,
                  color: theme.textSecondaryColor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _switchRow(
    ThemeProvider theme, {
    required Tone tone,
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required Future<void> Function(bool) onChanged,
    bool enabled = true,
    String? badge,
  }) {
    return _row(
      theme,
      tone: tone,
      icon: icon,
      title: title,
      subtitle: subtitle,
      badge: badge,
      enabled: enabled,
      onTap: () => onChanged(!value),
      trailing: GestureDetector(
        onTap: enabled ? () => onChanged(!value) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 50,
          height: 30,
          padding: const EdgeInsets.all(3),
          alignment:
              value ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
          decoration: BoxDecoration(
            color: value ? theme.primaryColor : const Color(0xFFD9DCCF),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }

  /// ردیف انتخاب‌ها: عنوان + چیپ‌های کوچک و کاملاً گرد
  Widget _choiceRow<T>(
    ThemeProvider theme, {
    required Tone tone,
    required IconData icon,
    required String title,
    String? subtitle,
    required List<MapEntry<T, String>> options,
    required T selected,
    required ValueChanged<T> onSelected,
  }) {
    final t = theme.tone(tone);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 7, 14, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(theme, tone, icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: theme.textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: theme.textSecondaryColor,
                          fontSize: 11.5,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              for (final o in options)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: GestureDetector(
                      onTap: () {
                        SoundService.instance.play(Sfx.tap);
                        onSelected(o.key);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: o.key == selected ? t.fg : t.bg,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          o.value,
                          style: TextStyle(
                            color: o.key == selected ? t.onFg : t.fg,
                            fontWeight: o.key == selected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _themeModeRow(ThemeProvider theme) {
    return _choiceRow<AppThemeMode>(
      theme,
      tone: Tone.lilac,
      icon:
          theme.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
      title: context.tr('settings.theme_mode'),
      subtitle: context.tr('settings.theme_mode_hint'),
      selected: theme.themeMode,
      onSelected: theme.setThemeMode,
      options: [
        MapEntry(AppThemeMode.system, context.tr('settings.theme_system')),
        MapEntry(AppThemeMode.light, context.tr('settings.theme_light')),
        MapEntry(AppThemeMode.dark, context.tr('settings.theme_dark')),
      ],
    );
  }

  Widget _colorTile(ThemeProvider theme) {
    return _row(
      theme,
      tone: Tone.apricot,
      icon: Icons.palette_rounded,
      title: context.tr('settings.color'),
      subtitle: context.tr('settings.color_hint'),
      trailing: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: theme.primaryColor,
          shape: BoxShape.circle,
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ColorPickerScreen()),
        );
      },
    );
  }

  Widget _calendarRow(ThemeProvider theme) {
    return Consumer<CalendarProvider>(
      builder: (context, calendar, _) {
        return _choiceRow<CalendarType>(
          theme,
          tone: Tone.sky,
          icon: Icons.calendar_month_rounded,
          title: context.tr('settings.calendar'),
          selected:
              calendar.isJalali ? CalendarType.jalali : CalendarType.gregorian,
          onSelected: calendar.setCalendarType,
          options: [
            MapEntry(CalendarType.jalali,
                context.tr('settings.calendar_jalali')),
            MapEntry(CalendarType.gregorian,
                context.tr('settings.calendar_gregorian')),
          ],
        );
      },
    );
  }

  Widget _languageRow(ThemeProvider theme, SettingsProvider settings) {
    return _choiceRow<String>(
      theme,
      tone: Tone.sky,
      icon: Icons.language_rounded,
      title: context.tr('settings.language'),
      subtitle: context.tr('settings.language_hint'),
      selected: settings.language,
      onSelected: settings.setLanguage,
      options: [
        MapEntry('fa', AppStrings.t('fa', 'settings.lang_fa')),
        MapEntry('en', AppStrings.t('en', 'settings.lang_en')),
      ],
    );
  }

  // ─────────────────────────── خروج و حذف حساب ───────────────────────────

  Future<bool> _askConfirm({
    required String title,
    required String body,
    required String confirmLabel,
    Color? confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: confirmColor == null
                ? null
                : TextButton.styleFrom(foregroundColor: confirmColor),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logout() async {
    final sync = context.read<SyncProvider>();
    final auth = context.read<AuthProvider>();
    final storage = LocalStorageService();

    // اول سعی می‌کنیم کارهای مونده رو بفرستیم تا چیزی گم نشه
    if (sync.isOnline && storage.getOfflineOperations().isNotEmpty) {
      _snack(context.tr('settings.logout_syncing'));
      await sync.flushPendingOperations();
    }
    if (!mounted) return;

    final pending = storage.getOfflineOperations().length;
    final body = pending > 0
        ? context.tr('settings.logout_unsynced', {'count': '$pending'})
        : context.tr('settings.logout_body');

    final ok = await _askConfirm(
      title: context.tr('settings.logout_title'),
      body: body,
      confirmLabel: context.tr('settings.logout'),
      confirmColor: pending > 0 ? _danger : null,
    );
    if (!ok || !mounted) return;

    final errorText = context.tr('settings.logout_error');
    try {
      sync.clear();
      await storage.clearAllUserData();
      await auth.forceLogout();
    } catch (_) {
      _snack(errorText);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final word = context.tr('settings.delete_word');
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final matches = controller.text.trim().toLowerCase() ==
              word.toLowerCase();
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Text(ctx.tr('settings.delete_title')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ctx.tr('settings.delete_body')),
                const SizedBox(height: 16),
                Text(
                  ctx.tr('settings.delete_type_hint', {'word': word}),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  onChanged: (_) => setLocal(() {}),
                  decoration: InputDecoration(
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ctx.tr('common.cancel')),
              ),
              TextButton(
                onPressed: matches ? () => Navigator.pop(ctx, true) : null,
                style: TextButton.styleFrom(foregroundColor: _danger),
                child: Text(ctx.tr('settings.delete_confirm_btn')),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    if (confirmed == true) await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    final sync = context.read<SyncProvider>();
    final auth = context.read<AuthProvider>();
    final loadingText = context.tr('settings.delete_loading');
    final doneText = context.tr('settings.delete_done');
    final theme = context.read<ThemeProvider>();
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: theme.primaryColor),
                const SizedBox(height: 16),
                Material(
                  color: Colors.transparent,
                  child: Text(
                    loadingText,
                    style: TextStyle(color: theme.textColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await SupabaseService().client.rpc('delete_user_account');
      sync.clear();
      await LocalStorageService().clearAllUserData();
      navigator.pop(); // بستن لودینگ
      await auth.forceLogout();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(doneText)));
    } catch (e) {
      navigator.pop();
      if (!mounted) return;
      _snack(context.tr('settings.delete_error', {'error': '$e'}));
    }
  }

  void _showTeamDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(ctx.tr('settings.team')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ctx.tr('app.name'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Elisa'),
            const SizedBox(height: 8),
            Text('${ctx.tr('settings.team_support')}: zahramirlohiiii@gmail.com'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.tr('settings.team_ok')),
          ),
        ],
      ),
    );
  }
}
