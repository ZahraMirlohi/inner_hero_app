// lib/features/profile/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/l10n/app_strings.dart';
import '/providers/auth_provider.dart';
import '/providers/calendar_provider.dart';
import '/providers/settings_provider.dart';
import '/providers/sync_provider.dart';
import '/providers/theme_provider.dart';
import '/services/local_storage_service.dart';
import '/services/sound_service.dart';
import '/services/supabase_service.dart';
import 'color_picker_screen.dart';

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
      appBar: AppBar(
        title: Text(context.tr('settings.title')),
        backgroundColor: theme.backgroundColor,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            _section(theme, context.tr('settings.section_look'), [
              _themeModeRow(theme),
              _colorTile(theme),
              _calendarRow(theme),
            ]),
            _section(theme, context.tr('settings.section_language'), [
              _languageRow(theme, settings),
            ]),
            _section(theme, context.tr('settings.section_feedback'), [
              _switchTile(
                theme,
                icon: Icons.graphic_eq_rounded,
                title: context.tr('settings.sound'),
                subtitle: context.tr('settings.sound_hint'),
                value: settings.soundEnabled,
                onChanged: (v) async {
                  await settings.setSound(v);
                  if (v) SoundService.instance.play(Sfx.check);
                },
              ),
              _switchTile(
                theme,
                icon: Icons.vibration_rounded,
                title: context.tr('settings.vibration'),
                subtitle: context.tr('settings.vibration_hint'),
                value: settings.vibrationEnabled,
                onChanged: (v) async {
                  await settings.setVibration(v);
                  if (v) SoundService.instance.play(Sfx.tap);
                },
              ),
            ]),
            _section(theme, context.tr('settings.section_notifications'), [
              _switchTile(
                theme,
                icon: Icons.notifications_rounded,
                title: context.tr('settings.notifications'),
                subtitle: context.tr('settings.notifications_hint'),
                value: settings.notificationsEnabled,
                onChanged: settings.setNotifications,
              ),
              _switchTile(
                theme,
                icon: Icons.checklist_rounded,
                title: context.tr('settings.notif_habits'),
                value: settings.rawNotifHabits,
                enabled: settings.notificationsEnabled,
                onChanged: settings.setNotifHabits,
              ),
              _switchTile(
                theme,
                icon: Icons.chat_bubble_rounded,
                title: context.tr('settings.notif_chat'),
                value: settings.rawNotifChat,
                enabled: settings.notificationsEnabled,
                onChanged: settings.setNotifChat,
              ),
              _switchTile(
                theme,
                icon: Icons.emoji_events_rounded,
                title: context.tr('settings.notif_challenges'),
                value: settings.rawNotifChallenges,
                enabled: settings.notificationsEnabled,
                onChanged: settings.setNotifChallenges,
              ),
              _switchTile(
                theme,
                icon: Icons.card_giftcard_rounded,
                title: context.tr('settings.notif_xp'),
                value: settings.rawNotifXp,
                enabled: settings.notificationsEnabled,
                onChanged: settings.setNotifXp,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text(
                  context.tr('settings.notif_note'),
                  style: TextStyle(
                    color: theme.textSecondaryColor,
                    fontSize: 12,
                  ),
                ),
              ),
            ]),
            _section(theme, context.tr('settings.section_privacy'), [
              _switchTile(
                theme,
                icon: Icons.lock_rounded,
                title: context.tr('settings.private_profile'),
                subtitle: context.tr('settings.private_profile_hint'),
                value: settings.privateProfile,
                enabled: false, // تا وقتی ستون سرورش ساخته نشده فقط «به‌زودی»
                onChanged: settings.setPrivateProfile,
                badge: context.tr('common.soon'),
              ),
            ]),
            _section(theme, context.tr('settings.section_account'), [
              _actionTile(
                theme,
                icon: Icons.logout_rounded,
                title: context.tr('settings.logout'),
                onTap: _logout,
              ),
              _actionTile(
                theme,
                icon: Icons.delete_forever_rounded,
                title: context.tr('settings.delete_account'),
                color: _danger,
                onTap: _confirmDeleteAccount,
              ),
            ]),
            _section(theme, context.tr('settings.section_about'), [
              _infoTile(
                theme,
                icon: Icons.info_rounded,
                title: context.tr('settings.version'),
                value: _appVersion,
              ),
              _actionTile(
                theme,
                icon: Icons.people_rounded,
                title: context.tr('settings.team'),
                onTap: _showTeamDialog,
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── بخش‌ها ───────────────────────────

  Widget _section(ThemeProvider theme, String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, bottom: 8),
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
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _iconBox(ThemeProvider theme, IconData icon, [Color? color]) {
    final c = color ?? theme.primaryColor;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: c, size: 22),
    );
  }

  Widget _switchTile(
    ThemeProvider theme, {
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required Future<void> Function(bool) onChanged,
    bool enabled = true,
    String? badge,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: ListTile(
        minVerticalPadding: 10,
        leading: _iconBox(theme, icon),
        title: Row(
          children: [
            Flexible(
              child: Text(title, style: TextStyle(color: theme.textColor)),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                style: TextStyle(
                  color: theme.textSecondaryColor,
                  fontSize: 12,
                ),
              ),
        trailing: Switch(
          value: value,
          onChanged: enabled ? (v) => onChanged(v) : null,
        ),
        onTap: enabled ? () => onChanged(!value) : null,
      ),
    );
  }

  Widget _actionTile(
    ThemeProvider theme, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      minVerticalPadding: 10,
      leading: _iconBox(theme, icon, color),
      title: Text(title, style: TextStyle(color: color ?? theme.textColor)),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: theme.textSecondaryColor,
        textDirection: TextDirection.ltr,
      ),
      onTap: onTap,
    );
  }

  Widget _infoTile(
    ThemeProvider theme, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    return ListTile(
      minVerticalPadding: 10,
      leading: _iconBox(theme, icon),
      title: Text(title, style: TextStyle(color: theme.textColor)),
      trailing: Text(value, style: TextStyle(color: theme.textSecondaryColor)),
    );
  }

  /// ردیفی از گزینه‌های انتخابی (چیپ‌های کاملاً گرد و بدون حاشیه)
  Widget _choiceRow<T>(
    ThemeProvider theme, {
    required IconData icon,
    required String title,
    String? subtitle,
    required List<MapEntry<T, String>> options,
    required T selected,
    required ValueChanged<T> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(theme, icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: theme.textColor)),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: theme.textSecondaryColor,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final o in options)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _chip(theme, o.key == selected, o.value, o.key,
                        onSelected),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip<T>(ThemeProvider theme, bool active, String label, T value,
      ValueChanged<T> onSelected) {
    return GestureDetector(
      onTap: () {
        SoundService.instance.play(Sfx.tap);
        onSelected(value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? theme.primaryColor : theme.cardSecondaryColor,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? theme.onPrimaryColor : theme.textColor,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _themeModeRow(ThemeProvider theme) {
    return _choiceRow<AppThemeMode>(
      theme,
      icon: theme.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
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
    return ListTile(
      minVerticalPadding: 10,
      leading: _iconBox(theme, Icons.palette_rounded),
      title: Text(context.tr('settings.color'),
          style: TextStyle(color: theme.textColor)),
      subtitle: Text(
        context.tr('settings.color_hint'),
        style: TextStyle(color: theme.textSecondaryColor, fontSize: 12),
      ),
      trailing: Container(
        width: 28,
        height: 28,
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
      icon: Icons.translate_rounded,
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
