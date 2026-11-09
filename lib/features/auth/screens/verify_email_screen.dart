// lib/features/auth/screens/verify_email_screen.dart
//
// بعد از ثبت‌نام: کد ۶ رقمی ایمیل را می‌نویسد؛ با تایید، وارد می‌شود (رویداد signedIn).

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
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    try {
      await auth.verifySignupCode(widget.email, normalizeCode(_code.text));
      // ورود موفق: HeroApp پشتهٔ صفحه‌ها را عوض می‌کند؛ این را هم می‌بندیم
      if (mounted) navigator.popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) setState(() => _error = authErrorText(context, e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    final auth = context.read<AuthProvider>();
    try {
      await auth.resendConfirmation(widget.email);
      if (mounted) setState(() {
        _sent = true;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = authErrorText(context, e));
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
        Form(
          key: _formKey,
          child: AuthField(
            controller: _code,
            label: context.tr('auth.code_label'),
            icon: Icons.pin_rounded,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            onSubmitted: (_) => _verify(),
            validator: (v) => AuthCodeValidator.check(context, v),
          ),
        ),
        const SizedBox(height: 20),
        AuthButton(
          label: context.tr('auth.code_btn'),
          onPressed: _verify,
          isLoading: _loading,
        ),
        const SizedBox(height: 12),
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
