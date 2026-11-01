-- مرحله ۱: تابع حذف حساب کاربری (برنامه با rpc('delete_user_account') صدایش می‌زند)
-- امن برای اجرای چندباره (create or replace).
-- این تابع همهٔ ردیف‌های کاربر را از هر جدول عمومی که ستون user_id یا sender_id دارد پاک می‌کند
-- و در آخر خود حساب (auth.users) را حذف می‌کند.

create or replace function public.delete_user_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  uid uuid := auth.uid();
  r record;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  for r in
    select c.table_name, c.column_name
    from information_schema.columns c
    join information_schema.tables t
      on t.table_schema = c.table_schema and t.table_name = c.table_name
    where c.table_schema = 'public'
      and t.table_type = 'BASE TABLE'
      and c.column_name in ('user_id', 'sender_id')
  loop
    begin
      execute format('delete from public.%I where %I = $1', r.table_name, r.column_name)
        using uid;
    exception when others then
      -- مثلاً ستونی با نوع غیر uuid؛ از آن رد می‌شویم
      raise notice 'skip %.%: %', r.table_name, r.column_name, sqlerrm;
    end;
  end loop;

  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_user_account() from public;
grant execute on function public.delete_user_account() to authenticated;
