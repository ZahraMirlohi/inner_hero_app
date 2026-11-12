// lib/features/auth/screens/forgot_password_screen.dart
//
// بازیابی رمز با لینک ایمیل: ایمیل را می‌گیرد و لینک می‌فرستد.
// با باز شدن لینک، برنامه خودش صفحهٔ «رمز جدید» (ResetPasswordScreen) را نشان می‌دهد.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/l10n/app_strings.dart';
import '/providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailKey = GlobalKey<FormState>();
  late final TextEditingController _email =
      TextEditingController(text: widget.initialEmail);
  bool _sent = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_emailKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _error = authErrorText(context, e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    try {
      await context.read<AuthProvider>().sendPasswordReset(_email.text);
    } catch (e) {
      if (mounted) setState(() => _error = authErrorText(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    // اگر لینک باز شد و صفحهٔ رمز جدید جای صفحهٔ اصلی نشست، این صفحه باید کنار برود
    final needsReset = context.select<AuthProvider, bool>((a) => a.needsPasswordReset);
    if (needsReset) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      });
    }
    return AuthShell(
      title: context.tr('auth.forgot_title'),
      subtitle: context.tr('auth.forgot_body'),
      showBack: true,
      children: [
        if (_error != null) AuthMessage(text: _error!),
        if (_sent)
          AuthMessage(text: context.tr('auth.forgot_sent'), isError: false),
        Form(
          key: _emailKey,
          child: AuthField(
            controller: _email,
            label: context.tr('auth.email'),
            icon: Icons.mail_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _send(),
            validator: (v) => AuthValidators.email(context, v),
          ),
        ),
        const SizedBox(height: 20),
        if (!_sent)
          AuthButton(
            label: context.tr('auth.forgot_send'),
            onPressed: _send,
            isLoading: _loading,
          )
        else ...[
          ResendButton(onResend: _resend),
          const SizedBox(height: 12),
          AuthButton(
            label: context.tr('auth.verify_back'),
            filled: false,
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
          ),
        ],
      ],
    );
  }
}
