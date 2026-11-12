// lib/features/auth/screens/verify_email_screen.dart
//
// بعد از ثبت‌نام: لینک تایید به ایمیل رفته. با باز شدن لینک، رویداد signedIn
// کاربر را وارد می‌کند و این صفحه خودش بسته می‌شود.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/l10n/app_strings.dart';
import '/providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _sent = false;
  String? _error;

  Future<void> _resend() async {
    try {
      await context.read<AuthProvider>().resendConfirmation(widget.email);
      if (mounted) {
        setState(() {
          _sent = true;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = authErrorText(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.select<AuthProvider, bool>((a) => a.isLoggedIn);
    if (loggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      });
    }
    return AuthShell(
      title: context.tr('auth.verify_title'),
      subtitle: context.tr('auth.verify_body', {'email': widget.email}),
      children: [
        if (_error != null) AuthMessage(text: _error!),
        if (_sent)
          AuthMessage(text: context.tr('auth.verify_sent'), isError: false),
        ResendButton(onResend: _resend),
        const SizedBox(height: 12),
        AuthButton(
          label: context.tr('auth.verify_back'),
          filled: false,
          onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
        ),
      ],
    );
  }
}
