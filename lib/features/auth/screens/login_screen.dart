import 'package:flutter/material.dart';
import '/services/appwrite_service.dart';
import '/features/home/screens/main_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _appwrite = AppwriteService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _appwrite.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        // ذخیره وضعیت لاگین در صورت نیاز
        if (_rememberMe) {
          // می‌توانید از SharedPreferences برای ذخیره وضعیت استفاده کنید
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خوش آمدید!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطا در ورود: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              // لوگو و عنوان
              _buildHeader(),

              const SizedBox(height: 40),

              // فرم ورود
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildEmailField(),
                    const SizedBox(height: 16),
                    _buildPasswordField(),
                    const SizedBox(height: 8),
                    _buildRememberMeRow(),
                    const SizedBox(height: 24),
                    _buildLoginButton(),
                    const SizedBox(height: 16),
                    _buildDivider(),
                    const SizedBox(height: 16),
                    _buildSignupButton(),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              _buildForgotPasswordButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFF4A90E2).withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.emoji_events,
            size: 50,
            color: Color(0xFF4A90E2),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'قهرمان درون',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'به سفر قهرمانی خود خوش آمدید',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: 'ایمیل',
        hintText: 'example@email.com',
        prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF4A90E2)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'لطفاً ایمیل خود را وارد کنید';
        }
        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
        if (!emailRegex.hasMatch(value)) {
          return 'لطفاً یک ایمیل معتبر وارد کنید';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: 'رمز عبور',
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF4A90E2)),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'لطفاً رمز عبور خود را وارد کنید';
        }
        if (value.length < 6) {
          return 'رمز عبور باید حداقل ۶ کاراکتر باشد';
        }
        return null;
      },
    );
  }

  Widget _buildRememberMeRow() {
    return Row(
      children: [
        Checkbox(
          value: _rememberMe,
          onChanged: (value) {
            setState(() {
              _rememberMe = value ?? false;
            });
          },
          activeColor: const Color(0xFF4A90E2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        const Text('مرا به خاطر بسپار', style: TextStyle(fontSize: 14)),
        const Spacer(),
      ],
    );
  }

  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleLogin,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        minimumSize: const Size(double.infinity, 50),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text(
              'ورود',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('یا', style: TextStyle(color: Colors.grey.shade500)),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    );
  }

  Widget _buildSignupButton() {
    return OutlinedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SignupScreen()),
        );
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF4A90E2),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: const BorderSide(color: Color(0xFF4A90E2)),
        minimumSize: const Size(double.infinity, 50),
      ),
      child: const Text(
        'ثبت‌نام',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildForgotPasswordButton() {
    return TextButton(
      onPressed: () {
        // TODO: پیاده‌سازی بازیابی رمز عبور
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('بازیابی رمز عبور به زودی اضافه می‌شود'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Text(
        'رمز عبور خود را فراموش کرده‌اید؟',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
      ),
    );
  }
}
