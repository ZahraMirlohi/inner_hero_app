// lib/features/auth/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/l10n/app_strings.dart';
import '/providers/auth_provider.dart';
import '/providers/theme_provider.dart';
import '/services/sound_service.dart';
import '../widgets/auth_widgets.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  bool _googleLoading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    try {
      await auth.signInWithEmail(_email.text, _password.text);
      // صفحهٔ اصلی خودکار باز می‌شود (HeroApp به وضعیت ورود گوش می‌دهد)
    } catch (e) {
      SoundService.instance.play(Sfx.error);
      if (mounted) setState(() => _error = authErrorText(context, e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    try {
      await auth.signInWithGoogle();
    } catch (e) {
      if (mounted) setState(() => _error = context.tr('auth.err_google'));
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return AuthShell(
      title: context.tr('auth.login_title'),
      subtitle: context.tr('auth.login_sub'),
      children: [
        if (_error != null) AuthMessage(text: _error!),
        Form(
          key: _formKey,
          child: Column(
            children: [
              AuthField(
                controller: _email,
                label: context.tr('auth.email'),
                icon: Icons.mail_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: (v) => AuthValidators.email(context, v),
              ),
              const SizedBox(height: 14),
              AuthField(
                controller: _password,
                label: context.tr('auth.password'),
                icon: Icons.lock_rounded,
                isPassword: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _login(),
                validator: (v) => (v == null || v.isEmpty)
                    ? context.tr('auth.err_password_required')
                    : null,
              ),
            ],
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ForgotPasswordScreen(initialEmail: _email.text.trim()),
              ),
            ),
            child: Text(context.tr('auth.forgot')),
          ),
        ),
        const SizedBox(height: 4),
        AuthButton(
          label: context.tr('auth.login_btn'),
          onPressed: _login,
          isLoading: _loading,
        ),
        const SizedBox(height: 18),
        if (AuthProvider.googleEnabled) ...[
        Row(
          children: [
            Expanded(child: Divider(color: theme.borderColor)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                context.tr('auth.or'),
                style: TextStyle(color: theme.textSecondaryColor),
              ),
            ),
            Expanded(child: Divider(color: theme.borderColor)),
          ],
        ),
        const SizedBox(height: 18),
        AuthButton(
          label: context.tr('auth.google'),
          icon: Icons.g_mobiledata_rounded,
          filled: false,
          onPressed: _google,
          isLoading: _googleLoading,
        ),
        ],
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              context.tr('auth.no_account'),
              style: TextStyle(color: theme.textSecondaryColor),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SignupScreen()),
              ),
              child: Text(context.tr('auth.go_signup')),
            ),
          ],
        ),
      ],
    );
  }
}
