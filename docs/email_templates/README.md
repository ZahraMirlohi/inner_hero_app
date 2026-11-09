# تنظیمات ورود در Supabase (داشبورد، یک‌بار)

برنامه حالا ثبت‌نام و بازیابی رمز را با **کد ۶ رقمی ایمیل** انجام می‌دهد (نه لینک). برای کار کردنش:

## ۱) قالب ایمیل‌ها
Authentication ← Emails ← Templates:

| قالب | Subject | Body |
|---|---|---|
| Confirm signup | `کواک! کد تایید حسابت | Quack! Your verification code` | محتوای `confirm_signup.html` |
| Reset password | `کواک! کد بازیابی رمز | Quack! Your password reset code` | محتوای `reset_password.html` |

هر دو قالب از `{{ .Token }}` استفاده می‌کنند (همان کد ۶ رقمی). قالب Magic Link و Change Email در برنامه استفاده نمی‌شود.

## ۲) تنظیمات امنیتی
- Authentication ← Providers ← Email: **Confirm email = ON**
- همان‌جا: **Minimum password length = 8**؛ «Password requirements» روی letters + digits
- Authentication ← Sessions/Attack Protection: **Enable leaked password protection** (در پلن Pro)، و CAPTCHA (hCaptcha/Turnstile) اگر ثبت‌نام انبوه دیدی
- Authentication ← Rate Limits: ارسال ایمیل و تلاش تایید کد را پایین نگه دار
- OTP expiry = **600** ثانیه، OTP length = **6**
- Authentication ← URL Configuration: Site URL را بگذار؛ چون دیگر لینک ایمیل نداریم، لینک عمیق برای ریست لازم نیست

## ۳) SMTP اختصاصی (مهم)
SMTP پیش‌فرض Supabase فقط چند ایمیل در ساعت می‌فرستد و فرستنده‌اش عمومی است؛ برای عمومی‌شدن برنامه حتماً SMTP خودت را وصل کن (Resend، Brevo، Postmark، ...) و فرستنده را مثلاً `Dacko <hello@دامنه‌ی‌تو>` بگذار. همراه با SPF و DKIM دامنه تا ایمیل‌ها در اسپم نیفتند.

## ۴) گوگل
وقتی فعال شد در `lib/providers/auth_provider.dart` مقدار `googleEnabled` را `true` کن.
