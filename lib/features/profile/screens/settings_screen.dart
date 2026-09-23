// lib/features/profile/widgets/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/services/date_service.dart';
import '/services/supabase_service.dart';
import '/providers/theme_provider.dart';
import 'color_picker_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SupabaseService _supabase = SupabaseService();
  bool _isDarkMode = false;
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _privateProfile = false;
  String _calendarType = 'jalali';
  String _language = 'fa';

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
                  _buildSwitchTile(
                    icon: Icons.dark_mode,
                    title: 'حالت تاریک',
                    value: _isDarkMode,
                    onChanged: (value) {
                      setState(() {
                        _isDarkMode = value;
                      });
                    },
                    primaryColor: primaryColor,
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
                  ),
                  // ✅ آیتم انتخاب رنگ
                  _buildColorTile(theme, primaryColor),
                ],
              ),
              const SizedBox(height: 16),

              // بخش تنظیمات نمایش
              _buildSettingsGroup(
                'نمایش',
                theme,
                [
                  _buildDropdownTile(
                    icon: Icons.calendar_today,
                    title: 'نوع تقویم',
                    value: _calendarType,
                    options: ['شمسی', 'میلادی'],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _calendarType = value;
                          final type = value == 'شمسی' ? 'jalali' : 'gregorian';
                          DateService.saveCalendarType(type);
                        });
                      }
                    },
                    primaryColor: primaryColor,
                  ),
                  _buildDropdownTile(
                    icon: Icons.language,
                    title: 'زبان',
                    value: _language == 'fa' ? 'فارسی' : 'English',
                    options: ['فارسی', 'English'],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _language = value == 'فارسی' ? 'fa' : 'en';
                        });
                      }
                    },
                    primaryColor: primaryColor,
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
                  ),
                  ListTile(
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
                        title: const Text('خروج از حساب'),
                        content: const Text('آیا از خروج خود مطمئن هستید؟'),
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
                      await _supabase.logout();
                      if (mounted) {
                        Navigator.pushReplacementNamed(context, '/login');
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
    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceColor,
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
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 آیتم انتخاب رنگ
  // ═══════════════════════════════════════════════════════════
  Widget _buildColorTile(ThemeProvider theme, Color primaryColor) {
    return ListTile(
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
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: primaryColor, size: 20),
      ),
      title: Text(title),
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
  Widget _buildDropdownTile({
    required IconData icon,
    required String title,
    required String value,
    required List<String> options,
    required Function(String?) onChanged,
    required Color primaryColor,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: primaryColor, size: 20),
      ),
      title: Text(title),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        items: options.map((option) {
          return DropdownMenuItem(value: option, child: Text(option));
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('حذف حساب کاربری'),
        content: const Text(
          'آیا از حذف حساب کاربری خود مطمئن هستید؟\n\n'
          'با حذف حساب، تمام اطلاعات شما از جمله عادت‌ها، تسک‌ها و پیشرفت‌تان پاک خواهد شد و قابل بازیابی نیست.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('حساب کاربری شما حذف شد'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
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
