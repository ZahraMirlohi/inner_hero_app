// lib/features/auth/screens/forgot_password_screen.dart
//
// بازیابی رمز با کد ایمیل، در سه مرحله روی همین صفحه: ایمیل ← کد ← رمز جدید.

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
  final _codeKey = GlobalKey<FormState>();
  final _passKey = GlobalKey<FormState>();
  late final TextEditingController _email =
      TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  int _stage = 0; // 0 ایمیل، 1 کد، 2 رمز جدید
  bool _loading = false;
  String? _error;
  late final AuthProvider _auth = context.read<AuthProvider>();

  @override
  void dispose() {
    // وسط مرحلهٔ رمز جدید بسته شد: نشست موقت را ببند
    if (_stage == 2) _auth.cancelRecovery();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() job) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await job();
    } catch (e) {
      if (mounted) setState(() => _error = authErrorText(context, e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendCode() async {
    if (!_emailKey.currentState!.validate()) return;
    await _run(() async {
      await _auth.sendPasswordReset(_email.text);
      if (mounted) setState(() => _stage = 1);
    });
  }

  Future<void> _verifyCode() async {
    if (!_codeKey.currentState!.validate()) return;
    await _run(() async {
      await _auth.verifyRecoveryCode(_email.text, normalizeCode(_code.text));
      if (mounted) setState(() => _stage = 2);
    });
  }

  Future<void> _savePassword() async {
    if (!_passKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final done = context.tr('auth.reset_done');
    await _run(() async {
      await _auth.completeRecovery(_password.text);
      messenger.showSnackBar(SnackBar(content: Text(done)));
      if (mounted) navigator.popUntil((r) => r.isFirst);
    });
  }

  @override
  Widget build(BuildContext context) {
    final email = _email.text.trim();
    return AuthShell(
      title: _stage == 2
          ? context.tr('auth.reset_title')
          : context.tr('auth.forgot_title'),
      subtitle: switch (_stage) {
        0 => context.tr('auth.forgot_body'),
        1 => context.tr('auth.forgot_code_body', {'email': email}),
        _ => context.tr('auth.reset_body'),
      },
      showBack: true,
      children: [
        if (_error != null) AuthMessage(text: _error!),
        if (_stage == 0) ...[
          Form(
            key: _emailKey,
            child: AuthField(
              controller: _email,
              label: context.tr('auth.email'),
              icon: Icons.mail_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _sendCode(),
              validator: (v) => AuthValidators.email(context, v),
            ),
          ),
          const SizedBox(height: 20),
          AuthButton(
            label: context.tr('auth.forgot_send'),
            onPressed: _sendCode,
            isLoading: _loading,
          ),
        ],
        if (_stage == 1) ...[
          AuthMessage(text: context.tr('auth.forgot_sent'), isError: false),
          Form(
            key: _codeKey,
            child: AuthField(
              controller: _code,
              label: context.tr('auth.code_label'),
              icon: Icons.pin_rounded,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              onSubmitted: (_) => _verifyCode(),
              validator: (v) => AuthCodeValidator.check(context, v),
            ),
          ),
          const SizedBox(height: 20),
          AuthButton(
            label: context.tr('auth.code_btn'),
            onPressed: _verifyCode,
            isLoading: _loading,
          ),
          const SizedBox(height: 12),
          ResendButton(onResend: () => _auth.sendPasswordReset(_email.text)),
        ],
        if (_stage == 2) ...[
          Form(
            key: _passKey,
            child: Column(
              children: [
                AuthField(
                  controller: _password,
                  label: context.tr('auth.password'),
                  icon: Icons.lock_rounded,
                  isPassword: true,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (v) => AuthValidators.password(context, v),
                ),
                const SizedBox(height: 14),
                AuthField(
                  controller: _confirm,
                  label: context.tr('auth.confirm_password'),
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _savePassword(),
                  validator: (v) => v != _password.text
                      ? context.tr('auth.err_password_mismatch')
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AuthButton(
            label: context.tr('auth.reset_btn'),
            onPressed: _savePassword,
            isLoading: _loading,
          ),
        ],
      ],
    );
  }
}
