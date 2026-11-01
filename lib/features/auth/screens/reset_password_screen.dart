// lib/features/auth/screens/reset_password_screen.dart
//
// بعد از باز شدن لینک «بازیابی رمز» در برنامه نشان داده می‌شود.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/l10n/app_strings.dart';
import '/providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final done = context.tr('auth.reset_done');
    try {
      await auth.updatePassword(_password.text);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (mounted) setState(() => _error = authErrorText(context, e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: context.tr('auth.reset_title'),
      subtitle: context.tr('auth.reset_body'),
      children: [
        if (_error != null) AuthMessage(text: _error!),
        Form(
          key: _formKey,
          child: Column(
            children: [
              AuthField(
                controller: _password,
                label: context.tr('auth.password'),
                icon: Icons.lock_rounded,
                isPassword: true,
                textInputAction: TextInputAction.next,
                validator: (v) => AuthValidators.password(context, v),
              ),
              const SizedBox(height: 14),
              AuthField(
                controller: _confirm,
                label: context.tr('auth.confirm_password'),
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
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
          onPressed: _save,
          isLoading: _loading,
        ),
      ],
    );
  }
}
