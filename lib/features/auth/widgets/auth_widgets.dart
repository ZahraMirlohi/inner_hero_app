// lib/features/auth/widgets/auth_widgets.dart
//
// اجزای مشترک صفحه‌های ورود/ثبت‌نام/بازیابی: همه با رنگ تم، گوشه‌های کاملاً گرد و بدون حاشیه.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '/l10n/app_strings.dart';
import '/providers/theme_provider.dart';

/// قالب کلی صفحه‌های احراز هویت
class AuthShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool showBack;

  const AuthShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: showBack
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
            )
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.bolt_rounded,
                        size: 38,
                        color: theme.onPrimaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.textSecondaryColor,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// فیلد متنی گرد و بدون حاشیه
class AuthField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;
  final Iterable<String>? autofillHints;

  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.isPassword = false,
    this.keyboardType,
    this.validator,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    OutlineInputBorder border([Color? c]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: c == null
              ? BorderSide.none
              : BorderSide(color: c, width: 1.5),
        );

    return TextFormField(
      controller: widget.controller,
      obscureText: widget.isPassword && _obscure,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      autofillHints: widget.autofillHints,
      style: TextStyle(color: theme.textColor),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: TextStyle(color: theme.textSecondaryColor),
        filled: true,
        fillColor: theme.cardColor,
        prefixIcon: Icon(widget.icon, color: theme.textSecondaryColor),
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: theme.textSecondaryColor,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: border(),
        enabledBorder: border(),
        focusedBorder: border(theme.primaryColor),
        errorBorder: border(theme.errorColor),
        focusedErrorBorder: border(theme.errorColor),
      ),
    );
  }
}

/// دکمهٔ اصلی (کاملاً گرد). با isLoading اسپینر نشان می‌دهد.
class AuthButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool filled;
  final IconData? icon;

  const AuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.filled = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final bg = filled ? theme.primaryColor : theme.cardColor;
    final fg = filled ? theme.onPrimaryColor : theme.textColor;
    final enabled = onPressed != null && !isLoading;

    return SizedBox(
      height: 56,
      child: Material(
        color: enabled ? bg : theme.disabledButtonBackground,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: enabled ? onPressed : null,
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: fg,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: fg, size: 22),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          color: fg,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// جعبهٔ پیام خطا / موفقیت داخل صفحه
class AuthMessage extends StatelessWidget {
  final String text;
  final bool isError;
  const AuthMessage({super.key, required this.text, this.isError = true});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isError ? theme.errorBg : theme.successBg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isError ? theme.errorColor : theme.successColor,
          height: 1.5,
        ),
      ),
    );
  }
}

/// تبدیل هر خطای ورود/ثبت‌نام به متن قابل فهم (بر اساس زبان فعلی)
String authErrorText(BuildContext context, Object error) {
  String tr(String key) => AppStrings.t(
        Localizations.localeOf(context).languageCode,
        key,
      );

  if (error is TimeoutException) {
    return tr('auth.err_network');
  }
  final raw = (error is AuthException ? error.message : error.toString())
      .toLowerCase();
  final code = error is AuthException ? (error.code ?? '') : '';

  if (code == 'invalid_credentials' || raw.contains('invalid login credentials')) {
    return tr('auth.err_invalid_credentials');
  }
  if (code == 'email_not_confirmed' || raw.contains('email not confirmed')) {
    return tr('auth.err_email_not_confirmed');
  }
  if (code == 'user_already_exists' ||
      raw.contains('already registered') ||
      raw.contains('already been registered')) {
    return tr('auth.err_user_exists');
  }
  if (code == 'weak_password' || raw.contains('password should be')) {
    return tr('auth.err_password_short');
  }
  if (raw.contains('rate limit') || raw.contains('too many')) {
    return tr('auth.err_rate_limit');
  }
  if (raw.contains('socketexception') ||
      raw.contains('failed host lookup') ||
      raw.contains('clientexception') ||
      raw.contains('network')) {
    return tr('auth.err_network');
  }
  if (raw.contains('signups not allowed') || raw.contains('signup_disabled')) {
    return tr('auth.err_signup_disabled');
  }
  if (raw.contains('database error')) {
    return tr('auth.err_db');
  }
  if (raw.contains('invalid') && raw.contains('email')) {
    return tr('auth.err_email_invalid');
  }
  // دلیل فنی را کوتاه نشان می‌دهیم تا اگر خطای تازه‌ای بود، پیدا کردنش راحت باشد
  var detail = (error is AuthException ? error.message : error.toString())
      .replaceAll('\n', ' ')
      .trim();
  if (detail.length > 140) detail = '${detail.substring(0, 140)}...';
  return '${tr('auth.err_generic')}\n($detail)';
}

/// اعتبارسنجی‌های مشترک
class AuthValidators {
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(BuildContext c, String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return c.tr('auth.err_email_required');
    if (!_email.hasMatch(t)) return c.tr('auth.err_email_invalid');
    return null;
  }

  static String? password(BuildContext c, String? v) {
    final t = v ?? '';
    if (t.isEmpty) return c.tr('auth.err_password_required');
    if (t.length < 8) return c.tr('auth.err_password_short');
    return null;
  }
}
