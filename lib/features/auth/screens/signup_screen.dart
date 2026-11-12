// lib/features/auth/screens/signup_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/features/profile/screens/terms_and_conditions_screen.dart';
import '/l10n/app_strings.dart';
import '/providers/auth_provider.dart';
import '/providers/theme_provider.dart';
import '/services/sound_service.dart';
import '../widgets/auth_widgets.dart';
import 'verify_email_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _agree = false;
  bool _loading = false;
  bool _googleLoading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agree) {
      setState(() => _error = context.tr('auth.err_terms'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    try {
      final result = await auth.signUpWithEmail(
        email: _email.text,
        password: _password.text,
        name: _name.text,
      );
      if (!mounted) return;
      if (result == SignUpResult.needsEmailConfirmation) {
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (_) => VerifyEmailScreen(email: _email.text.trim()),
          ),
        );
      } else {
        // وارد شد؛ HeroApp خودش معرفی را نشان می‌دهد. این صفحه باید بسته شود.
        navigator.popUntil((r) => r.isFirst);
      }
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
      title: context.tr('auth.signup_title'),
      subtitle: context.tr('auth.signup_sub'),
      showBack: true,
      children: [
        if (_error != null) AuthMessage(text: _error!),
        Form(
          key: _formKey,
          child: Column(
            children: [
              AuthField(
                controller: _name,
                label: context.tr('auth.name'),
                icon: Icons.person_rounded,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? context.tr('auth.err_name_required')
                    : null,
              ),
              const SizedBox(height: 14),
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
                onSubmitted: (_) => _signup(),
                validator: (v) => v != _password.text
                    ? context.tr('auth.err_password_mismatch')
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _agree,
          onChanged: (v) => setState(() => _agree = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.tr('auth.agree_terms'),
            style: TextStyle(color: theme.textColor, fontSize: 13),
          ),
          subtitle: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TermsAndConditionsScreen(),
              ),
            ),
            child: Text(
              context.tr('auth.terms_link'),
              style: TextStyle(
                color: theme.primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        AuthButton(
          label: context.tr('auth.signup_btn'),
          onPressed: _signup,
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
              context.tr('auth.have_account'),
              style: TextStyle(color: theme.textSecondaryColor),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('auth.go_login')),
            ),
          ],
        ),
      ],
    );
  }
}
