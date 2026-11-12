# تنظیمات ورود در Supabase (داشبورد، یک‌بار)

برنامه ثبت‌نام و بازیابی رمز را با **لینک ایمیل** انجام می‌دهد (قالب‌های پیش‌فرض Supabase کافی است؛ لازم نیست SMTP اختصاصی بگذاری).

## ۱) مهم‌ترین مورد: آدرس بازگشت (Redirect URL)
Authentication ← **URL Configuration**:
- در بخش **Redirect URLs** این را اضافه کن و Save بزن:
  `io.supabase.innerhero://login-callback/`
- بدون این، لینک ایمیل برنامه را باز نمی‌کند یا به سایت می‌رود.

## ۲) تنظیمات امنیتی
- Authentication ← Providers ← Email: **Confirm email = ON**
- همان‌جا: **Minimum password length = 8**
- Authentication ← Rate Limits: ارسال ایمیل را پایین نگه دار

## ۳) اختیاری (فقط اگر SMTP اختصاصی گرفتی)
قالب‌های `confirm_signup.html` و `reset_password.html` در این پوشه نسخهٔ «کد ۶ رقمی» هستند و با روش لینک سازگار نیستند؛ استفاده‌شان نکن مگر قالب لینک بسازی (`{{ .ConfirmationURL }}`).
