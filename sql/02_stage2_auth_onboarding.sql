-- مرحلهٔ ۲: ثبت‌نام و معرفی اولین ورود. امن برای اجرای چندباره.

-- ۱) شناسهٔ یکتای کاربر (به‌جای تولید ضعیف سمت برنامه): INNER-XXXXXXXX
create or replace function public.generate_unique_id()
returns text
language plpgsql
as $$
declare
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  candidate text;
  i int;
begin
  loop
    candidate := 'INNER-';
    for i in 1..8 loop
      candidate := candidate || substr(chars, 1 + floor(random() * length(chars))::int, 1);
    end loop;
    exit when not exists (select 1 from public.profiles where unique_id = candidate);
  end loop;
  return candidate;
end;
$$;

-- هر کاربر فقط یک پروفایل و یک user_progress
-- ردیف‌های تکراری (اگر هستند) پاک می‌شوند: برای هر کاربر ردیفی با بیشترین XP می‌ماند
delete from public.profiles p
 using (
   select ctid as rid, row_number() over (
            partition by user_id order by coalesce(total_xp, 0) desc, ctid) as rn
     from public.profiles
 ) d
 where p.ctid = d.rid and d.rn > 1;

delete from public.user_progress p
 using (
   select ctid as rid, row_number() over (
            partition by user_id order by coalesce(total_xp, 0) desc, ctid) as rn
     from public.user_progress
 ) d
 where p.ctid = d.rid and d.rn > 1;

create unique index if not exists profiles_user_id_key on public.profiles (user_id);
create unique index if not exists user_progress_user_id_key on public.user_progress (user_id);

-- ۲) با ساخته شدن حساب (حتی قبل از تایید ایمیل) پروفایل و user_progress خودکار ساخته می‌شود؛
--    دیگر لازم نیست برنامه آن‌ها را با RLS دستی بسازد (علت خراب شدن ثبت‌نام با تایید ایمیل).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  -- هر کدام جدا و محافظت‌شده: اگر ساخت پروفایل خطا بدهد، ثبت‌نام خراب نمی‌شود
  -- (برنامه خودش در صورت نبودن پروفایل آن را می‌سازد).
  begin
    if not exists (select 1 from public.profiles where user_id = new.id) then
      insert into public.profiles (user_id, email, name, unique_id, total_xp)
      values (
        new.id,
        new.email,
        coalesce(new.raw_user_meta_data ->> 'name', new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1)),
        public.generate_unique_id(),
        0
      );
    end if;
  exception when others then
    raise warning 'handle_new_user profiles: %', sqlerrm;
  end;

  begin
    if not exists (select 1 from public.user_progress where user_id = new.id) then
      insert into public.user_progress (user_id, total_xp) values (new.id, 0);
    end if;
  exception when others then
    raise warning 'handle_new_user user_progress: %', sqlerrm;
  end;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ۳) پاسخ‌های سوال‌های معرفی
create table if not exists public.user_onboarding (
  user_id uuid primary key references auth.users (id) on delete cascade,
  goals text[] not null default '{}',
  obstacle text,
  level text,
  wake_time text,
  remind_time text,
  language text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ستون‌های نسخهٔ دوم سوال‌ها (اگر جدول را از قبل ساخته‌اید، این‌ها اضافه می‌شوند)
alter table public.user_onboarding add column if not exists goal text;
alter table public.user_onboarding add column if not exists first_task text;
alter table public.user_onboarding add column if not exists energy text;
alter table public.user_onboarding add column if not exists planning_style text;

alter table public.user_onboarding enable row level security;

drop policy if exists "onboarding_select_own" on public.user_onboarding;
create policy "onboarding_select_own" on public.user_onboarding
  for select using (auth.uid() = user_id);

drop policy if exists "onboarding_insert_own" on public.user_onboarding;
create policy "onboarding_insert_own" on public.user_onboarding
  for insert with check (auth.uid() = user_id);

drop policy if exists "onboarding_update_own" on public.user_onboarding;
create policy "onboarding_update_own" on public.user_onboarding
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ۴) تنظیمات دستی در داشبورد Supabase (SQL نیست):
--    Authentication > URL Configuration > Redirect URLs:  io.supabase.innerhero://login-callback/
--    Authentication > Providers > Google: روشن کنید و Client ID/Secret گوگل را بدهید.
--    Authentication > Sign In / Providers > Email: «Confirm email» را به‌دلخواه روشن/خاموش کنید (برنامه هر دو را پشتیبانی می‌کند).
