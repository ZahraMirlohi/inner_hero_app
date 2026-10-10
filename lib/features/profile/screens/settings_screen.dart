// lib/features/profile/widgets/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:inner_hero_app/providers/calendar_provider.dart';
import 'package:provider/provider.dart';
import '/services/date_service.dart';
import '/services/supabase_service.dart';
import '/providers/theme_provider.dart';
import 'color_picker_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/services/local_storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SupabaseService _supabase = SupabaseService();
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _privateProfile = false;
  String _calendarType = 'jalali';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final calendar = await DateService.getCalendarType();
    if (mounted) {
      setState(() {
        _calendarType = calendar == 'jalali' ? 'شمسی' : 'میلادی';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'تنظیمات',
          style: TextStyle(color: theme.textColor),
        ),
        backgroundColor: theme.surfaceColor,
        elevation: 0,
        foregroundColor: theme.textColor,
      ),
      body: SafeArea(
        // ✅ SafeArea
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          //                                    ↑ پدینگ اضافه پایین
          child: Column(
            children: [
              // بخش تنظیمات عمومی
              _buildSettingsGroup(
                'عمومی',
                theme,
                [
                  // ✅ حالت تاریک با Consumer
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, _) {
                      return ListTile(
                        tileColor: themeProvider.surfaceColor, // ✅ اضافه کن
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            themeProvider.isDarkMode
                                ? Icons.dark_mode
                                : Icons.light_mode,
                            color: primaryColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          themeProvider.isDarkMode ? 'حالت روز' : 'حالت شب',
                          style: TextStyle(color: theme.textColor),
                        ),
                        subtitle: Text(
                          themeProvider.isDarkMode
                              ? 'رفتن به تم روشن'
                              : 'رفتن به تم تاریک',
                          style: TextStyle(
                            color: theme.textSecondaryColor,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Switch(
                          value: themeProvider.isDarkMode,
                          onChanged: (value) {
                            themeProvider.setDarkMode(value);
                          },
                          activeColor: primaryColor,
                        ),
                        onTap: () {
                          themeProvider.toggleDarkMode();
                        },
                      );
                    },
                  ),
                  _buildSwitchTile(
                    icon: Icons.notifications,
                    title: 'اعلان‌ها',
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                    },
                    primaryColor: primaryColor,
                    theme: theme,
                  ),
                  _buildSwitchTile(
                    icon: Icons.volume_up,
                    title: 'صدا',
                    value: _soundEnabled,
                    onChanged: (value) {
                      setState(() {
                        _soundEnabled = value;
                      });
                    },
                    primaryColor: primaryColor,
                    theme: theme,
                  ),
                  _buildSwitchTile(
                    icon: Icons.vibration,
                    title: 'لرزش',
                    value: _vibrationEnabled,
                    onChanged: (value) {
                      setState(() {
                        _vibrationEnabled = value;
                      });
                    },
                    primaryColor: primaryColor,
                    theme: theme,
                  ),
                  _buildColorTile(theme, primaryColor),
                ],
              ),
              const SizedBox(height: 16),

              // بخش تنظیمات نمایش
              _buildSettingsGroup(
                'نمایش',
                theme,
                [
                  Consumer<CalendarProvider>(
                    builder: (context, calendarProvider, _) {
                      return _buildDropdownTile(
                        icon: Icons.calendar_today,
                        title: 'نوع تقویم',
                        value: calendarProvider.isJalali ? 'شمسی' : 'میلادی',
                        options: const ['شمسی', 'میلادی'],
                        onChanged: (value) {
                          if (value != null) {
                            final type = value == 'شمسی'
                                ? CalendarType.jalali
                                : CalendarType.gregorian;
                            calendarProvider.setCalendarType(type);
                          }
                        },
                        primaryColor: primaryColor,
                        theme: theme, // ✅ اضافه کن
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // بخش حریم خصوصی
              _buildSettingsGroup(
                'حریم خصوصی',
                theme,
                [
                  _buildSwitchTile(
                    icon: Icons.lock,
                    title: 'پروفایل خصوصی',
                    value: _privateProfile,
                    onChanged: (value) {
                      setState(() {
                        _privateProfile = value;
                      });
                    },
                    primaryColor: primaryColor,
                    theme: theme,
                  ),
                  ListTile(
                    tileColor: theme.surfaceColor, // ✅ اضافه کن
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF44336).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.delete_forever,
                        color: Color(0xFFF44336),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'حذف حساب کاربری',
                      style: TextStyle(color: theme.textColor),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: theme.textSecondaryColor,
                    ),
                    onTap: () {
                      _showDeleteAccountDialog(theme, primaryColor);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // بخش درباره
              _buildSettingsGroup(
                'درباره',
                theme,
                [
                  ListTile(
                    tileColor: theme.surfaceColor, // ✅ اضافه کن
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.info,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'نسخه اپلیکیشن',
                      style: TextStyle(color: theme.textColor),
                    ),
                    trailing: Text(
                      '1.0.0',
                      style: TextStyle(color: theme.textSecondaryColor),
                    ),
                  ),
                  ListTile(
                    tileColor: theme.surfaceColor, // ✅ اضافه کن
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.people,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'تیم توسعه',
                      style: TextStyle(color: theme.textColor),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: theme.textSecondaryColor,
                    ),
                    onTap: () {
                      _showTeamDialog(theme, primaryColor);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // دکمه خروج
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        backgroundColor: theme.surfaceColor,
                        title: Text(
                          'خروج از حساب',
                          style: TextStyle(color: theme.textColor),
                        ),
                        content: Text(
                          'آیا از خروج خود مطمئن هستید؟',
                          style: TextStyle(color: theme.textSecondaryColor),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('انصراف'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'خروج',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        // ✅ 1. پاک کردن LocalStorage
                        final localStorage = LocalStorageService();
                        await localStorage.clearAllDataExceptProfile();

                        // ✅ 2. خروج از Supabase
                        await _supabase.logout();

                        // ✅ 3. پاک کردن user_id از SharedPreferences
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('user_id');

                        // ✅ 4. بستن Settings و برگشت به LoginScreen
                        if (mounted) {
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('خطا در خروج: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text(
                    'خروج از حساب',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📦 گروه تنظیمات
  // ═══════════════════════════════════════════════════════════
  Widget _buildSettingsGroup(
    String title,
    ThemeProvider theme,
    List<Widget> children,
  ) {
    return Material(
      color: theme.surfaceColor,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1),
            ...children,
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 آیتم انتخاب رنگ
  // ═══════════════════════════════════════════════════════════
  Widget _buildColorTile(ThemeProvider theme, Color primaryColor) {
    return ListTile(
      tileColor: theme.surfaceColor,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.color_lens,
          color: primaryColor,
          size: 20,
        ),
      ),
      title: Text(
        'رنگ اپلیکیشن',
        style: TextStyle(color: theme.textColor),
      ),
      subtitle: Text(
        'انتخاب رنگ اصلی برنامه',
        style: TextStyle(color: theme.textSecondaryColor, fontSize: 12),
      ),
      trailing: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: themeProvider.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.textSecondaryColor,
              ),
            ],
          );
        },
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ColorPickerScreen()),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔘 آیتم سوییچ
  // ═══════════════════════════════════════════════════════════
  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required Function(bool) onChanged,
    required Color primaryColor,
    required ThemeProvider theme, // ✅ اضافه کن
  }) {
    return ListTile(
      tileColor: theme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: primaryColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(color: theme.textColor),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: primaryColor,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 آیتم Dropdown
  // ═══════════════════════════════════════════════════════════
  // ═══════════════════════════════════════════════════════════
  // 📋 آیتم Dropdown
  // ═══════════════════════════════════════════════════════════
  Widget _buildDropdownTile({
    required IconData icon,
    required String title,
    required String value,
    required List<String> options,
    required Function(String?) onChanged,
    required Color primaryColor,
    required ThemeProvider theme, // ✅ اضافه کن
  }) {
    return ListTile(
      tileColor: theme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: primaryColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(color: theme.textColor),
      ),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        dropdownColor: theme.surfaceColor,
        style: TextStyle(color: theme.textColor),
        items: options.map((option) {
          return DropdownMenuItem(
            value: option,
            child: Text(
              option,
              style: TextStyle(color: theme.textColor),
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🗑️ دیالوگ حذف حساب
  // ═══════════════════════════════════════════════════════════
  void _showDeleteAccountDialog(ThemeProvider theme, Color primaryColor) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'حذف حساب کاربری',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'آیا از حذف حساب کاربری خود مطمئن هستید؟',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ هشدار',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'با حذف حساب، تمام اطلاعات شما از جمله:\n'
                    '• عادت‌ها و تسک‌ها\n'
                    '• عکس‌های گالری\n'
                    '• پیشرفت‌ها و XP\n'
                    '• چت‌ها و پیام‌ها\n'
                    'برای همیشه پاک می‌شود و قابل بازیابی نیست.',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textSecondaryColor,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'انصراف',
              style: TextStyle(color: theme.textSecondaryColor),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _deleteAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'حذف دائمی',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    try {
      // نمایش لودینگ
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('در حال حذف حساب کاربری...'),
              ],
            ),
          ),
        ),
      );

      // ✅ 1. حذف از Supabase با RPC
      await _supabase.client.rpc('delete_user_account');

      // ✅ 2. پاک کردن LocalStorage
      final localStorage = LocalStorageService();
      await localStorage.clearAllDataExceptProfile();

      // ✅ 3. خروج از session
      await _supabase.logout();

      // ✅ 4. پاک کردن user_id
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');

      // ✅ 5. بستن dialog لودینگ
      if (mounted) {
        Navigator.pop(context); // لودینگ
      }

      // ✅ 6. نمایش پیام موفقیت
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ حساب کاربری شما با موفقیت حذف شد'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // ✅ 7. بستن Settings و برگشت به LoginScreen
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      // بستن dialog لودینگ
      if (mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در حذف حساب: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 👥 دیالوگ تیم توسعه
  // ═══════════════════════════════════════════════════════════
  void _showTeamDialog(ThemeProvider theme, Color primaryColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('تیم توسعه'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('🌟 قهرمان درون'),
            SizedBox(height: 8),
            Text('Elisa :توسعه‌دهنده'),
            SizedBox(height: 4),
            Text('Elisa : تیم طراحی'),
            SizedBox(height: 4),
            Text('zahramirlohiiii@gmail.com : پشتیبانی'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('متوجه شدم'),
          ),
        ],
      ),
    );
  }
}
