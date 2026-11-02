-- اصلاح ثبت‌نام: تریگر ساخت پروفایل دیگر باعث شکست ثبت‌نام نمی‌شود.
-- اگر فایل 02 را قبلاً اجرا کرده‌اید، فقط همین فایل را یک بار اجرا کنید.
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
