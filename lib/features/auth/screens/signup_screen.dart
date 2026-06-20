import 'package:flutter/material.dart';
import '/services/appwrite_service.dart';
import '/features/home/screens/main_screen.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _appwrite = AppwriteService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لطفاً قوانین و مقررات را بپذیرید'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _appwrite.signup(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ثبت‌نام با موفقیت انجام شد!'),
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
        String errorMessage = e.toString().replaceFirst('Exception: ', '');

        // ترجمه خطاهای رایج
        if (errorMessage.contains('user already exists')) {
          errorMessage = 'این ایمیل قبلاً ثبت‌نام کرده است';
        } else if (errorMessage.contains('invalid email')) {
          errorMessage = 'ایمیل وارد شده معتبر نیست';
        } else if (errorMessage.contains('weak password')) {
          errorMessage = 'رمز عبور بسیار ضعیف است';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در ثبت‌نام: $errorMessage'),
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
              const SizedBox(height: 20),

              // هدر
              _buildHeader(),

              const SizedBox(height: 30),

              // فرم ثبت‌نام
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildNameField(),
                    const SizedBox(height: 16),
                    _buildEmailField(),
                    const SizedBox(height: 16),
                    _buildPasswordField(),
                    const SizedBox(height: 16),
                    _buildConfirmPasswordField(),
                    const SizedBox(height: 8),
                    _buildTermsCheckbox(),
                    const SizedBox(height: 24),
                    _buildSignupButton(),
                    const SizedBox(height: 16),
                    _buildDivider(),
                    const SizedBox(height: 16),
                    _buildLoginButton(),
                  ],
                ),
              ),
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
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF4A90E2).withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_add_alt_1,
            size: 40,
            color: Color(0xFF4A90E2),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'ایجاد حساب کاربری',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'برای شروع سفر قهرمانی خود ثبت‌نام کنید',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: 'نام و نام خانوادگی',
        hintText: 'مثال: علی محمدی',
        prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF4A90E2)),
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
          return 'لطفاً نام خود را وارد کنید';
        }
        if (value.length < 3) {
          return 'نام باید حداقل ۳ کاراکتر باشد';
        }
        return null;
      },
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
      textInputAction: TextInputAction.next,
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
          return 'لطفاً رمز عبور را وارد کنید';
        }
        if (value.length < 6) {
          return 'رمز عبور باید حداقل ۶ کاراکتر باشد';
        }
        if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(value)) {
          return 'رمز عبور باید شامل حروف و اعداد باشد';
        }
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: _obscureConfirmPassword,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: 'تکرار رمز عبور',
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF4A90E2)),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
          ),
          onPressed: () {
            setState(() {
              _obscureConfirmPassword = !_obscureConfirmPassword;
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
          return 'لطفاً رمز عبور را تکرار کنید';
        }
        if (value != _passwordController.text) {
          return 'رمز عبور با تکرار آن مطابقت ندارد';
        }
        return null;
      },
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: _agreeToTerms,
          onChanged: (value) {
            setState(() {
              _agreeToTerms = value ?? false;
            });
          },
          activeColor: const Color(0xFF4A90E2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _agreeToTerms = !_agreeToTerms;
              });
            },
            child: Text.rich(
              TextSpan(
                text: 'من ',
                style: TextStyle(color: Colors.grey.shade700),
                children: [
                  TextSpan(
                    text: 'قوانین و مقررات',
                    style: const TextStyle(
                      color: Color(0xFF4A90E2),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: ' را می‌پذیرم',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignupButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleSignup,
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
              'ثبت‌نام',
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

  Widget _buildLoginButton() {
    return OutlinedButton(
      onPressed: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
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
        'ورود به حساب کاربری',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}
