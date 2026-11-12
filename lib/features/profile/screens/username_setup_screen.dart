// lib/features/profile/screens/username_setup_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '/core/app_palette.dart';
import '/l10n/app_strings.dart';
import '/services/supabase_service.dart';
import '/providers/theme_provider.dart';

/// نوع پیام وضعیت زیر فیلد (رنگ در build از تم گرفته می‌شود)
enum _StatusKind { info, warn, ok, bad }

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

  String? _statusKey;
  _StatusKind _statusKind = _StatusKind.info;
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
      _statusKey = 'pm.un.current';
      _statusKind = _StatusKind.info;
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
      _statusKey = null;
      _isAvailable = false;
    });

    if (value.isEmpty) return;

    if (value.length < 3) {
      setState(() {
        _statusKey = 'pm.un.tooShort';
        _statusKind = _StatusKind.warn;
      });
      return;
    }

    // چک فرمت
    final regex = RegExp(r'^[a-z][a-z0-9_.]{2,29}$');
    if (!regex.hasMatch(value)) {
      setState(() {
        _statusKey = 'pm.un.badFormat';
        _statusKind = _StatusKind.warn;
      });
      return;
    }

    // اگر همان username فعلی است
    if (value == widget.currentUsername) {
      setState(() {
        _isAvailable = true;
        _statusKey = 'pm.un.current';
        _statusKind = _StatusKind.info;
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
      _statusKey = null;
    });

    final available = await _supabase.isUsernameAvailable(username);

    if (!mounted) return;

    setState(() {
      _isChecking = false;
      _isAvailable = available;
      if (available) {
        _statusKey = 'pm.un.free';
        _statusKind = _StatusKind.ok;
      } else {
        _statusKey = 'pm.un.taken';
        _statusKind = _StatusKind.bad;
      }
    });
  }

  Future<void> _save() async {
    if (!_isAvailable || _controller.text.isEmpty) return;

    // چک محدودیت ۱ دقیقه
    if (_secondsUntilChange > 0) {
      _showError(
        context.tr('pm.un.wait', {'n': '$_secondsUntilChange'}),
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
          _showError(context.tr('pm.un.wait', {'n': '$seconds'}));
          setState(() => _secondsUntilChange = seconds);
        }
        return;
      }

      await _supabase.setUsername(widget.userId, _controller.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('pm.un.saved')),
            backgroundColor:
                Provider.of<ThemeProvider>(context, listen: false)
                    .successColor,
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
        _showError(context.tr('pm.un.error', {'e': e.toString()}));
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
        backgroundColor:
            Provider.of<ThemeProvider>(context, listen: false).errorColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final accent = theme.effectivePrimary;
    final onAccent =
        theme.isDarkMode ? theme.onPrimaryColor : const Color(0xFF090909);
    final isNew = widget.currentUsername == null;
    final text = _controller.text;
    final canSave = _isAvailable && !_isSaving && _secondsUntilChange == 0;

    // قوانین زنده
    final okLen = text.length >= 3;
    final okChars = text.isNotEmpty && RegExp(r'^[a-z0-9_.]+$').hasMatch(text);
    final okStart = text.isNotEmpty && RegExp(r'^[a-z]').hasMatch(text);

    Color statusColor() {
      switch (_statusKind) {
        case _StatusKind.ok:
          return theme.successColor;
        case _StatusKind.bad:
          return theme.errorColor;
        case _StatusKind.warn:
          return theme.tone(Tone.peach).fg;
        case _StatusKind.info:
          return theme.tone(Tone.sky).fg;
      }
    }

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // سربرگ
                    Row(
                      children: [
                        if (!widget.isFirstTime) ...[
                          GestureDetector(
                            onTap: () => Navigator.maybePop(context),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                shape: BoxShape.circle,
                                boxShadow: theme.softShadow,
                              ),
                              child: Icon(Icons.arrow_back_rounded,
                                  size: 22, color: theme.textColor),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(
                            context.tr(
                                isNew ? 'pm.un.titleNew' : 'pm.un.titleEdit'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: theme.textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // تصویر و توضیح
                    Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(36),
                        ),
                        child: Icon(Icons.alternate_email_rounded,
                            size: 46, color: onAccent),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      context.tr(isNew ? 'pm.un.headNew' : 'pm.un.headEdit'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: theme.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('pm.un.sub'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ورودی
                    Container(
                      height: 64,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: theme.softShadow,
                      ),
                      child: Row(
                        children: [
                          Text(
                            '@',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: theme.textSecondaryColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              onChanged: _onUsernameChanged,
                              enabled: !_isSaving && _secondsUntilChange == 0,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.left,
                              cursorColor: accent,
                              style: TextStyle(
                                color: theme.textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-z0-9_.]'),
                                ),
                                LengthLimitingTextInputFormatter(30),
                              ],
                              decoration: InputDecoration(
                                hintText: context.tr('pm.un.hint'),
                                hintStyle: TextStyle(
                                  color: theme.textSecondaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                filled: false,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_isChecking)
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: accent),
                            )
                          else if (_isAvailable)
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.check_rounded,
                                  size: 18, color: onAccent),
                            ),
                        ],
                      ),
                    ),

                    // پیام وضعیت
                    if (_statusKey != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                        child: Text(
                          context.tr(_statusKey!),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: statusColor(),
                          ),
                        ),
                      ),

                    // محدودیت زمانی
                    if (_secondsUntilChange > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.tone(Tone.peach).bg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.timer_outlined,
                                color: theme.tone(Tone.peach).fg, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                context.tr('pm.un.cooldown',
                                    {'n': '$_secondsUntilChange'}),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.tone(Tone.peach).fg,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 14),

                    // قوانین
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: theme.softShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildRule(theme, context.tr('pm.un.rule1'), okLen),
                          const SizedBox(height: 12),
                          _buildRule(
                              theme, context.tr('pm.un.rule2'), okChars),
                          const SizedBox(height: 12),
                          _buildRule(
                              theme, context.tr('pm.un.rule3'), okStart),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // دکمه ذخیره
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canSave ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.isDarkMode
                        ? theme.primaryColor
                        : const Color(0xFF090909),
                    foregroundColor: theme.isDarkMode
                        ? theme.onPrimaryColor
                        : theme.effectivePrimary,
                    disabledBackgroundColor: theme.disabledButtonBackground,
                    disabledForegroundColor: theme.textSecondaryColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.effectivePrimary,
                          ),
                        )
                      : Text(
                          context.tr(isNew ? 'pm.un.saveNew' : 'pm.un.save'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRule(ThemeProvider theme, String text, bool done) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: done ? theme.primarySoft : theme.cardSecondaryColor,
            shape: BoxShape.circle,
          ),
          child: done
              ? Icon(Icons.check_rounded, size: 14, color: theme.textColor)
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: theme.textColor),
          ),
        ),
      ],
    );
  }
}
