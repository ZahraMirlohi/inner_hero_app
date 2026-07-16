// lib/features/profile/widgets/terms_and_conditions_screen.dart

import 'package:flutter/material.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('قوانین و مقررات'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A2E),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              '📋 مقدمه',
              'به اپلیکیشن قهرمان درون خوش آمدید. این اپلیکیشن با هدف کمک به شما در ایجاد عادت‌های مثبت و دستیابی به اهداف شخصی طراحی شده است. لطفاً قوانین زیر را به دقت مطالعه کنید.',
            ),
            const SizedBox(height: 24),

            _buildSection(
              '1️⃣ ثبت‌نام و حساب کاربری',
              '• برای استفاده از اپلیکیشن باید یک حساب کاربری ایجاد کنید.\n'
                  '• اطلاعات ثبت‌نامی باید صحیح و کامل باشد.\n'
                  '• شما مسئول حفظ امنیت رمز عبور خود هستید.\n'
                  '• در صورت مشاهده هرگونه فعالیت مشکوک، مراتب را به پشتیبانی اطلاع دهید.',
            ),
            const SizedBox(height: 16),

            _buildSection(
              '2️⃣ رفتار کاربران',
              '• با سایر کاربران با احترام رفتار کنید.\n'
                  '• از ارسال پیام‌های توهین‌آمیز یا نامناسب خودداری کنید.\n'
                  '• محتوای ارسالی نباید شامل مطالب غیراخلاقی باشد.\n'
                  '• تخلف از این قوانین منجر به مسدود شدن حساب کاربری خواهد شد.',
            ),
            const SizedBox(height: 16),

            _buildSection(
              '3️⃣ حریم خصوصی',
              '• اطلاعات شخصی شما نزد ما محفوظ است.\n'
                  '• از اطلاعات شما برای بهبود تجربه کاربری استفاده می‌شود.\n'
                  '• اطلاعات شما بدون رضایت شما به شخص ثالث داده نمی‌شود.\n'
                  '• شما می‌توانید در هر زمان حساب خود را حذف کنید.',
            ),
            const SizedBox(height: 16),

            _buildSection(
              '4️⃣ امتیازها و پاداش‌ها',
              '• با انجام عادت‌ها و تسک‌ها امتیاز (XP) دریافت می‌کنید.\n'
                  '• امتیازها قابل تبدیل به پول نقد نیستند.\n'
                  '• در صورت تقلب، امتیازهای شما باطل خواهد شد.\n'
                  '• پاداش‌ها فقط برای کاربران فعال در نظر گرفته می‌شوند.',
            ),
            const SizedBox(height: 16),

            _buildSection(
              '5️⃣ تعهدات کاربر',
              '• تعهد می‌دهید که از اپلیکیشن برای اهداف قانونی استفاده کنید.\n'
                  '• در بهبود و توسعه اپلیکیشن با تیم توسعه همکاری کنید.\n'
                  '• بازخورد خود را برای بهبود اپلیکیشن ارائه دهید.\n'
                  '• از کپی‌برداری یا مهندسی معکوس اپلیکیشن خودداری کنید.',
            ),
            const SizedBox(height: 16),

            _buildSection(
              '6️⃣ تغییرات در قوانین',
              '• تیم توسعه حق تغییر این قوانین را در آینده محفوظ می‌دارد.\n'
                  '• تغییرات از طریق اطلاعیه درون‌برنامه‌ای اعلام می‌شود.\n'
                  '• ادامه استفاده از اپلیکیشن به معنای پذیرش قوانین جدید است.',
            ),
            const SizedBox(height: 16),

            _buildSection(
              '7️⃣ تماس با ما',
              'اگر سوال یا پیشنهادی دارید، از طریق پشتیبانی اپلیکیشن با ما در ارتباط باشید.\n'
                  'ما همیشه خوشحال می‌شویم نظرات شما را بشنویم.',
            ),
            const SizedBox(height: 32),

            // دکمه تایید
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'متوجه شدم',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
