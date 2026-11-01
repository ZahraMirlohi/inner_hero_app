// lib/features/auth/screens/verify_email_screen.dart
//
// بعد از ثبت‌نام، اگر Supabase تایید ایمیل بخواهد این صفحه نشان داده می‌شود.
// کاربر با زدن لینک ایمیل، وارد می‌شود (از طریق رویداد signedIn).

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
  bool _loading = false;
  bool _sent = false;
  String? _error;

  Future<void> _resend() async {
    setState(() {
      _loading = true;
      _error = null;
      _sent = false;
    });
    final auth = context.read<AuthProvider>();
    try {
      await auth.resendConfirmation(widget.email);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _error = authErrorText(context, e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: context.tr('auth.verify_title'),
      subtitle: context.tr('auth.verify_body', {'email': widget.email}),
      children: [
        if (_error != null) AuthMessage(text: _error!),
        if (_sent)
          AuthMessage(text: context.tr('auth.verify_sent'), isError: false),
        AuthButton(
          label: context.tr('auth.verify_resend'),
          onPressed: _resend,
          isLoading: _loading,
        ),
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
