-- ============================================================
-- مرحله ۳: منطق XP و روزهای هفته
-- می‌شود چندبار اجرا کرد (idempotent). در Supabase > SQL Editor اجرا کنید.
-- ============================================================

-- ۱) تغییر اتمیک XP (برنامه اگر این تابع باشد از آن استفاده می‌کند، وگرنه روش قدیمی)
--    فقط برای خود کاربر؛ هیچ‌کس نمی‌تواند XP دیگری را عوض کند.
create or replace function public.adjust_xp(p_user_id uuid, p_delta int)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  new_total int;
begin
  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'not allowed';
  end if;

  -- سقف منطقی برای هر عملیات (جلوی عدد بزرگ دستکاری‌شده)
  if abs(p_delta) > 1000 then
    raise exception 'delta too large';
  end if;

  insert into public.user_progress (user_id, total_xp)
  values (p_user_id, greatest(0, p_delta))
  on conflict (user_id) do update
    set total_xp = greatest(0, public.user_progress.total_xp + p_delta)
  returning total_xp into new_total;

  update public.profiles
     set total_xp = new_total
   where user_id = p_user_id;

  return new_total;
end;
$$;

revoke all on function public.adjust_xp(uuid, int) from public;
grant execute on function public.adjust_xp(uuid, int) to authenticated;

-- ۲) روزهای هفتگی عادت‌ها: کدگذاری جدید شنبه=۰ ... جمعه=۶
--    قبلاً صفحهٔ ساخت عادت با «دوشنبه=۰ ... یکشنبه=۶» ذخیره می‌کرد.
--    فقط یک بار اجرا شود! (برای اطمینان، با یک علامت محافظت شده)
create table if not exists public.app_migrations (
  name text primary key,
  applied_at timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from public.app_migrations where name = 'weekly_days_sat0') then
    update public.habits
       set weekly_days = (
         select coalesce(array_agg(((d + 2) % 7) order by ((d + 2) % 7)), '{}')
         from unnest(weekly_days) as d
       )
     where weekly_days is not null
       and array_length(weekly_days, 1) is not null;

    insert into public.app_migrations (name) values ('weekly_days_sat0');
  end if;
end $$;

alter table public.app_migrations enable row level security;
-- هیچ سیاستی نمی‌گذاریم: فقط داشبورد/سرویس به این جدول دسترسی دارد.
