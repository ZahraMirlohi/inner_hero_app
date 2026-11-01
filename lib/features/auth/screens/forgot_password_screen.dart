// lib/features/auth/screens/forgot_password_screen.dart

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
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email =
      TextEditingController(text: widget.initialEmail);

  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    try {
      await auth.sendPasswordReset(_email.text);
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
      title: context.tr('auth.forgot_title'),
      subtitle: context.tr('auth.forgot_body'),
      showBack: true,
      children: [
        if (_error != null) AuthMessage(text: _error!),
        if (_sent)
          AuthMessage(text: context.tr('auth.forgot_sent'), isError: false),
        Form(
          key: _formKey,
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
        AuthButton(
          label: context.tr('auth.forgot_send'),
          onPressed: _send,
          isLoading: _loading,
        ),
      ],
    );
  }
}
