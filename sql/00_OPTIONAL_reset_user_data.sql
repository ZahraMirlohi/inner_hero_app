-- ⚠️ اختیاری و خطرناک: همهٔ دادهٔ «کاربران» را پاک می‌کند (نه کاتالوگ چالش/بسته/ماموریت).
-- فقط اگر می‌خواهید از صفر شروع کنید اجرا کنید. حساب‌ها (auth.users) پاک نمی‌شوند.
-- جدول‌هایی که وجود ندارند نادیده گرفته می‌شوند.

do $$
declare
  t text;
  tables text[] := array[
    'habit_completions','habits','tasks','user_daily_activity','user_progress',
    'user_challenges','challenge_completions','user_packages','user_quests','user_badges',
    'messages','message_reactions','typing_status','conversation_members','conversations',
    'buddy_requests','blocked_users','user_personalities','challenge_invites','xp_gifts'
  ];
begin
  foreach t in array tables loop
    if to_regclass('public.' || t) is not null then
      execute format('truncate table public.%I restart identity cascade', t);
    end if;
  end loop;
end $$;
