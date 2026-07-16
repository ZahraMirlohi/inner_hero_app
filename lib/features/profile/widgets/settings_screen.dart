// lib/features/profile/widgets/settings_screen.dart

import 'package:flutter/material.dart';
import '/services/date_service.dart';
import '/services/supabase_service.dart';

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
    setState(() {
      _calendarType = calendar == 'jalali' ? 'شمسی' : 'میلادی';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('تنظیمات'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A2E),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // بخش تنظیمات عمومی
            _buildSettingsGroup('عمومی', [
              _buildSwitchTile(
                icon: Icons.dark_mode,
                title: 'حالت تاریک',
                value: _isDarkMode,
                onChanged: (value) {
                  setState(() {
                    _isDarkMode = value;
                  });
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
              ),
            ]),
            const SizedBox(height: 16),

            // بخش تنظیمات نمایش
            _buildSettingsGroup('نمایش', [
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
              ),
            ]),
            const SizedBox(height: 16),

            // بخش حریم خصوصی
            _buildSettingsGroup('حریم خصوصی', [
              _buildSwitchTile(
                icon: Icons.lock,
                title: 'پروفایل خصوصی',
                value: _privateProfile,
                onChanged: (value) {
                  setState(() {
                    _privateProfile = value;
                  });
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF44336).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.delete_forever,
                    color: Color(0xFFF44336),
                    size: 20,
                  ),
                ),
                title: const Text('حذف حساب کاربری'),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  _showDeleteAccountDialog();
                },
              ),
            ]),
            const SizedBox(height: 16),

            // بخش درباره
            _buildSettingsGroup('درباره', [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.info,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
                title: const Text('نسخه اپلیکیشن'),
                trailing: const Text(
                  '1.0.0',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.people,
                    color: Color(0xFF7C3AED),
                    size: 20,
                  ),
                ),
                title: const Text('تیم توسعه'),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  _showTeamDialog();
                },
              ),
            ]),
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
    );
  }

  Widget _buildSettingsGroup(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF2563EB), size: 20),
      ),
      title: Text(title),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF2563EB),
        // ✅ shape را حذف کنید
      ),
    );
  }

  Widget _buildDropdownTile({
    required IconData icon,
    required String title,
    required String value,
    required List<String> options,
    required Function(String?) onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF7C3AED).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF7C3AED), size: 20),
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

  void _showDeleteAccountDialog() {
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
              // حذف حساب کاربری
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

  void _showTeamDialog() {
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
            Text('توسعه‌دهنده: تیم طراحی و توسعه'),
            SizedBox(height: 4),
            Text('طراح UI/UX: تیم طراحی'),
            SizedBox(height: 4),
            Text('پشتیبانی: support@innerhero.com'),
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
