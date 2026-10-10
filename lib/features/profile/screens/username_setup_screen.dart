// lib/features/profile/screens/username_setup_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '/services/supabase_service.dart';
import '/providers/theme_provider.dart';

class UsernameSetupScreen extends StatefulWidget {
  final String userId;
  final String? currentUsername;
  final bool isFirstTime; // اگر true باشد، اجازه بازگشت نمی‌دهیم
  final VoidCallback? onCompleted;

  const UsernameSetupScreen({
    super.key,
    required this.userId,
    this.currentUsername,
    this.isFirstTime = false,
    this.onCompleted,
  });

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final SupabaseService _supabase = SupabaseService();
  final TextEditingController _controller = TextEditingController();

  Timer? _debounce;

  String? _statusMessage;
  Color? _statusColor;
  bool _isChecking = false;
  bool _isAvailable = false;
  bool _isSaving = false;
  int _secondsUntilChange = 0;

  @override
  void initState() {
    super.initState();
    if (widget.currentUsername != null) {
      _controller.text = widget.currentUsername!;
      _isAvailable = true;
      _statusMessage = 'نام کاربری فعلی شما';
      _statusColor = Colors.blue;
    }
    _checkChangeCooldown();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkChangeCooldown() async {
    if (widget.currentUsername == null) return;

    final seconds = await _supabase.secondsUntilUsernameChange(widget.userId);
    if (mounted) {
      setState(() {
        _secondsUntilChange = seconds;
      });
    }
  }

  void _onUsernameChanged(String value) {
    _debounce?.cancel();
    setState(() {
      _statusMessage = null;
      _isAvailable = false;
    });

    if (value.isEmpty) return;

    if (value.length < 3) {
      setState(() {
        _statusMessage = 'حداقل ۳ کاراکتر لازم است';
        _statusColor = Colors.orange;
      });
      return;
    }

    // چک فرمت
    final regex = RegExp(r'^[a-z][a-z0-9_.]{2,29}$');
    if (!regex.hasMatch(value)) {
      setState(() {
        _statusMessage = 'فقط حروف کوچک انگلیسی، اعداد، _ و . (شروع با حرف)';
        _statusColor = Colors.orange;
      });
      return;
    }

    // اگر همان username فعلی است
    if (value == widget.currentUsername) {
      setState(() {
        _isAvailable = true;
        _statusMessage = 'نام کاربری فعلی شما';
        _statusColor = Colors.blue;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _checkAvailability(value);
    });
  }

  Future<void> _checkAvailability(String username) async {
    if (!mounted) return;

    setState(() {
      _isChecking = true;
      _statusMessage = null;
    });

    final available = await _supabase.isUsernameAvailable(username);

    if (!mounted) return;

    setState(() {
      _isChecking = false;
      _isAvailable = available;
      if (available) {
        _statusMessage = '✅ این نام کاربری آزاد است';
        _statusColor = Colors.green;
      } else {
        _statusMessage = '❌ این نام کاربری قبلاً انتخاب شده';
        _statusColor = Colors.red;
      }
    });
  }

  Future<void> _save() async {
    if (!_isAvailable || _controller.text.isEmpty) return;

    // چک محدودیت ۱ دقیقه
    if (_secondsUntilChange > 0) {
      _showError(
        'لطفاً $_secondsUntilChange ثانیه دیگر صبر کنید',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // چک مجدد eligibility
      final canChange = await _supabase.canChangeUsername(widget.userId);
      if (!canChange) {
        if (mounted) {
          final seconds =
              await _supabase.secondsUntilUsernameChange(widget.userId);
          _showError('لطفاً $seconds ثانیه دیگر صبر کنید');
          setState(() => _secondsUntilChange = seconds);
        }
        return;
      }

      await _supabase.setUsername(widget.userId, _controller.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 نام کاربری با موفقیت ذخیره شد'),
            backgroundColor: Colors.green,
          ),
        );

        if (widget.onCompleted != null) {
          widget.onCompleted!();
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('خطا: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final primaryColor = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.currentUsername == null
              ? 'انتخاب نام کاربری'
              : 'ویرایش نام کاربری',
          style: TextStyle(color: theme.textColor),
        ),
        backgroundColor: theme.surfaceColor,
        elevation: 0,
        foregroundColor: theme.textColor,
        automaticallyImplyLeading: !widget.isFirstTime,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // آیکون و توضیح
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.alternate_email,
                    size: 50,
                    color: primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  widget.currentUsername == null
                      ? 'یک نام کاربری یکتا انتخاب کن'
                      : 'نام کاربری جدیدت را وارد کن',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'این نام کاربری برای شناسایی تو در اپلیکیشن استفاده می‌شود.\nدوستانت می‌توانند با آن تو را پیدا کنند.',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.textSecondaryColor,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),

              // فیلد ورودی
              Text(
                'نام کاربری',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                onChanged: _onUsernameChanged,
                enabled: !_isSaving && _secondsUntilChange == 0,
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 16,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[a-z0-9_.]'),
                  ),
                  LengthLimitingTextInputFormatter(30),
                ],
                decoration: InputDecoration(
                  hintText: 'مثال: ali_ahmadi',
                  hintStyle: TextStyle(
                    color: theme.textSecondaryColor,
                  ),
                  prefixIcon: Icon(
                    Icons.alternate_email,
                    color: primaryColor,
                  ),
                  suffixIcon: _isChecking
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.isDarkMode
                      ? const Color(0xFF2A2A2A)
                      : Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // پیام وضعیت
              if (_statusMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_statusColor ?? Colors.grey).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          (_statusColor ?? Colors.grey).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isAvailable ? Icons.check_circle : Icons.info_outline,
                        color: _statusColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            fontSize: 13,
                            color: _statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // محدودیت زمانی
              if (_secondsUntilChange > 0)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        color: Colors.orange,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'برای تغییر مجدد، $_secondsUntilChange ثانیه دیگر صبر کنید',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // قوانین
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📋 قوانین نام کاربری',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildRule('حداقل ۳ و حداکثر ۳۰ کاراکتر'),
                    _buildRule('فقط حروف کوچک انگلیسی (a-z) و اعداد (0-9)'),
                    _buildRule('می‌توانی از _ و . استفاده کنی'),
                    _buildRule('باید با یک حرف شروع شود'),
                    _buildRule('بین هر تغییر، ۱ دقیقه فاصله لازم است'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // دکمه ذخیره
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      (_isAvailable && !_isSaving && _secondsUntilChange == 0)
                          ? _save
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    disabledBackgroundColor: theme.isDarkMode
                        ? Colors.grey.shade800
                        : Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.currentUsername == null
                              ? 'ذخیره و ادامه'
                              : 'ذخیره تغییرات',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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

  Widget _buildRule(String text) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(color: theme.textSecondaryColor),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: theme.textSecondaryColor,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
