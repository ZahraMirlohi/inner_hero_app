-- =====================================================================
-- مرحله ۶: گروه‌ها و کانال‌ها (ادمین/عضو، کد دعوت، عمومی/خصوصی، ریپورت، واکنش)
-- امن برای اجرای چندباره. بعد از فایل‌های قبلی اجرا شود.
-- نکته: گروه = conversations با type='squad'، کانال چالش = type='arena'.
-- =====================================================================

-- ---------- ستون‌های جدید ----------
alter table public.conversations
  add column if not exists description text,
  add column if not exists avatar_url text,
  add column if not exists is_public boolean not null default false,
  add column if not exists invite_code text,
  add column if not exists reactions_enabled boolean not null default true,
  add column if not exists posting_mode text not null default 'all';

do $$ begin
  alter table public.conversations
    add constraint conversations_posting_mode_chk check (posting_mode in ('all','admins'));
exception when duplicate_object then null; end $$;

create unique index if not exists conversations_invite_code_key
  on public.conversations (invite_code) where invite_code is not null;

alter table public.conversation_members
  add column if not exists muted boolean not null default false;

-- ---------- جدول‌های جدید ----------
create table if not exists public.conversation_bans (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null,
  banned_by uuid,
  created_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create table if not exists public.member_reports (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  reporter_id uuid not null,
  reported_user_id uuid not null,
  reason text not null,
  details text,
  status text not null default 'open',   -- open | reviewed | dismissed
  created_at timestamptz not null default now()
);
create index if not exists member_reports_conv_idx on public.member_reports (conversation_id);

-- ---------- توابع کمکی ----------
create or replace function public.is_conv_member(cid uuid, uid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from conversation_members where conversation_id = cid and user_id = uid);
$$;

create or replace function public.is_conv_admin(cid uuid, uid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from conversation_members
                 where conversation_id = cid and user_id = uid and role = 'admin');
$$;

create or replace function public.gen_invite_code()
returns text language plpgsql as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code text; i int;
begin
  loop
    code := '';
    for i in 1..8 loop
      code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from conversations where invite_code = code);
  end loop;
  return code;
end $$;

-- ---------- RPC ها (همه security definer؛ بررسی دسترسی داخل خود تابع) ----------

-- ساخت گروه: هر کاربری می‌تواند بسازد؛ سازنده ادمین می‌شود
create or replace function public.create_group(
  p_name text, p_description text default null,
  p_is_public boolean default false, p_member_ids uuid[] default '{}'
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid(); cid uuid; m uuid;
begin
  if me is null then raise exception 'not authenticated'; end if;
  if p_name is null or length(trim(p_name)) = 0 then raise exception 'group name required'; end if;

  insert into conversations (type, name, description, created_by, is_public, invite_code, is_active, last_message_at)
  values ('squad', trim(p_name), p_description, me, coalesce(p_is_public,false), gen_invite_code(), true, now())
  returning id into cid;

  insert into conversation_members (conversation_id, user_id, role, joined_at)
  values (cid, me, 'admin', now());

  foreach m in array coalesce(p_member_ids,'{}') loop
    if m <> me then
      insert into conversation_members (conversation_id, user_id, role, joined_at)
      values (cid, m, 'member', now()) on conflict do nothing;
    end if;
  end loop;
  return cid;
end $$;

-- پیوستن با کد دعوت
create or replace function public.join_group_by_code(p_code text)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); c conversations;
begin
  if me is null then raise exception 'not authenticated'; end if;
  select * into c from conversations
   where invite_code = upper(trim(p_code)) and is_active and type in ('squad','arena');
  if not found then raise exception 'invalid invite code'; end if;
  if exists (select 1 from conversation_bans where conversation_id = c.id and user_id = me) then
    raise exception 'you are banned from this group';
  end if;
  insert into conversation_members (conversation_id, user_id, role, joined_at)
  values (c.id, me, 'member', now()) on conflict do nothing;
  return c.id;
end $$;

-- پیوستن به گروه عمومی بدون کد
create or replace function public.join_public_group(p_conversation_id uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); c conversations;
begin
  if me is null then raise exception 'not authenticated'; end if;
  select * into c from conversations where id = p_conversation_id and is_active and is_public and type = 'squad';
  if not found then raise exception 'group is not public'; end if;
  if exists (select 1 from conversation_bans where conversation_id = c.id and user_id = me) then
    raise exception 'you are banned from this group';
  end if;
  insert into conversation_members (conversation_id, user_id, role, joined_at)
  values (c.id, me, 'member', now()) on conflict do nothing;
  return c.id;
end $$;

-- جستجوی گروه‌های عمومی
create or replace function public.search_public_groups(p_query text default '')
returns table (id uuid, name text, description text, avatar_url text, member_count bigint)
language sql stable security definer set search_path = public as $$
  select c.id, c.name, c.description, c.avatar_url,
         (select count(*) from conversation_members m where m.conversation_id = c.id)
    from conversations c
   where c.type = 'squad' and c.is_active and c.is_public
     and (coalesce(p_query,'') = '' or c.name ilike '%' || p_query || '%')
   order by c.last_message_at desc
   limit 50;
$$;

-- ویرایش گروه (فقط ادمین)
create or replace function public.update_group(
  p_conversation_id uuid, p_name text default null, p_description text default null,
  p_is_public boolean default null, p_reactions_enabled boolean default null,
  p_posting_mode text default null, p_avatar_url text default null
) returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_conv_admin(p_conversation_id, auth.uid()) then raise exception 'admin only'; end if;
  update conversations set
    name = coalesce(nullif(trim(p_name),''), name),
    description = coalesce(p_description, description),
    is_public = coalesce(p_is_public, is_public),
    reactions_enabled = coalesce(p_reactions_enabled, reactions_enabled),
    posting_mode = coalesce(p_posting_mode, posting_mode),
    avatar_url = coalesce(p_avatar_url, avatar_url)
  where id = p_conversation_id;
end $$;

-- ساخت کد دعوت جدید (کد قبلی باطل می‌شود)
create or replace function public.regenerate_invite_code(p_conversation_id uuid)
returns text language plpgsql security definer set search_path = public as $$
declare code text;
begin
  if not is_conv_admin(p_conversation_id, auth.uid()) then raise exception 'admin only'; end if;
  code := gen_invite_code();
  update conversations set invite_code = code where id = p_conversation_id;
  return code;
end $$;

-- ادمین کردن / برداشتن ادمینی
create or replace function public.set_member_role(p_conversation_id uuid, p_user_id uuid, p_role text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_role not in ('admin','member') then raise exception 'bad role'; end if;
  if not is_conv_admin(p_conversation_id, auth.uid()) then raise exception 'admin only'; end if;
  -- آخرین ادمین نمی‌تواند خودش را پایین بیاورد
  if p_role = 'member' and (select count(*) from conversation_members
        where conversation_id = p_conversation_id and role = 'admin') <= 1
     and is_conv_admin(p_conversation_id, p_user_id) then
    raise exception 'group needs at least one admin';
  end if;
  update conversation_members set role = p_role
   where conversation_id = p_conversation_id and user_id = p_user_id;
end $$;

-- حذف عضو (فقط ادمین؛ اختیاری: مسدود کردن)
create or replace function public.remove_group_member(
  p_conversation_id uuid, p_user_id uuid, p_ban boolean default false
) returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_conv_admin(p_conversation_id, auth.uid()) then raise exception 'admin only'; end if;
  if p_user_id = auth.uid() then raise exception 'use leave_group'; end if;
  delete from conversation_members where conversation_id = p_conversation_id and user_id = p_user_id;
  if p_ban then
    insert into conversation_bans (conversation_id, user_id, banned_by)
    values (p_conversation_id, p_user_id, auth.uid()) on conflict do nothing;
  end if;
end $$;

-- ترک گروه؛ اگر آخرین ادمین بود، قدیمی‌ترین عضو ادمین می‌شود
create or replace function public.leave_group(p_conversation_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); next_admin uuid;
begin
  delete from conversation_members where conversation_id = p_conversation_id and user_id = me;
  if not exists (select 1 from conversation_members where conversation_id = p_conversation_id and role = 'admin') then
    select user_id into next_admin from conversation_members
     where conversation_id = p_conversation_id order by joined_at asc limit 1;
    if next_admin is null then
      update conversations set is_active = false where id = p_conversation_id;
    else
      update conversation_members set role = 'admin'
       where conversation_id = p_conversation_id and user_id = next_admin;
    end if;
  end if;
end $$;

-- حذف کامل گروه (فقط ادمین)
create or replace function public.delete_group(p_conversation_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_conv_admin(p_conversation_id, auth.uid()) then raise exception 'admin only'; end if;
  delete from message_reactions where message_id in (select id from messages where conversation_id = p_conversation_id);
  delete from messages where conversation_id = p_conversation_id;
  delete from conversation_members where conversation_id = p_conversation_id;
  delete from conversations where id = p_conversation_id;
end $$;

-- گزارش عضو (هر عضو گروه)
create or replace function public.report_member(
  p_conversation_id uuid, p_user_id uuid, p_reason text, p_details text default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare rid uuid;
begin
  if not is_conv_member(p_conversation_id, auth.uid()) then raise exception 'members only'; end if;
  if p_user_id = auth.uid() then raise exception 'cannot report yourself'; end if;
  insert into member_reports (conversation_id, reporter_id, reported_user_id, reason, details)
  values (p_conversation_id, auth.uid(), p_user_id, p_reason, p_details) returning id into rid;
  return rid;
end $$;

-- بی‌صدا کردن گروه برای خودم
create or replace function public.set_group_muted(p_conversation_id uuid, p_muted boolean)
returns void language sql security definer set search_path = public as $$
  update conversation_members set muted = p_muted
   where conversation_id = p_conversation_id and user_id = auth.uid();
$$;

grant execute on function
  public.create_group(text,text,boolean,uuid[]), public.join_group_by_code(text),
  public.join_public_group(uuid), public.search_public_groups(text),
  public.update_group(uuid,text,text,boolean,boolean,text,text),
  public.regenerate_invite_code(uuid), public.set_member_role(uuid,uuid,text),
  public.remove_group_member(uuid,uuid,boolean), public.leave_group(uuid),
  public.delete_group(uuid), public.report_member(uuid,uuid,text,text),
  public.set_group_muted(uuid,boolean)
to authenticated;

-- ---------- تریگرها (اجرای قوانین حتی اگر کلاینت دور بزند) ----------

-- پیام: مسدودها نمی‌فرستند؛ در حالت «فقط ادمین‌ها» فقط ادمین می‌تواند پیام بدهد
create or replace function public.trg_messages_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare mode text;
begin
  if exists (select 1 from conversation_bans where conversation_id = new.conversation_id and user_id = new.sender_id) then
    raise exception 'you are banned from this group';
  end if;
  select posting_mode into mode from conversations where id = new.conversation_id;
  if mode = 'admins' and not is_conv_admin(new.conversation_id, new.sender_id) then
    raise exception 'only admins can post in this group';
  end if;
  return new;
end $$;
drop trigger if exists messages_guard on public.messages;
create trigger messages_guard before insert on public.messages
  for each row execute function public.trg_messages_guard();

-- واکنش‌ها (استیکر): فقط وقتی ادمین فعال گذاشته
create or replace function public.trg_reactions_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare enabled boolean;
begin
  select c.reactions_enabled into enabled
    from messages m join conversations c on c.id = m.conversation_id
   where m.id = new.message_id;
  if coalesce(enabled, true) = false then
    raise exception 'reactions are disabled in this group';
  end if;
  return new;
end $$;
drop trigger if exists reactions_guard on public.message_reactions;
create trigger reactions_guard before insert or update on public.message_reactions
  for each row execute function public.trg_reactions_guard();

-- ---------- RLS ----------
alter table public.conversation_bans enable row level security;
alter table public.member_reports enable row level security;

drop policy if exists bans_admin_read on public.conversation_bans;
create policy bans_admin_read on public.conversation_bans for select
  using (public.is_conv_admin(conversation_id, auth.uid()));

drop policy if exists reports_admin_read on public.member_reports;
create policy reports_admin_read on public.member_reports for select
  using (public.is_conv_admin(conversation_id, auth.uid()) or reporter_id = auth.uid());
-- درج گزارش فقط از طریق report_member (security definer)

-- سیاست‌های زیر «افزایشی» هستند (با سیاست‌های موجود OR می‌شوند) و تا وقتی RLS روی
-- جدول فعال نباشد اثری ندارند. فعال‌سازی در انتهای فایل به‌صورت کامنت آمده.
drop policy if exists conv_select_member_or_public on public.conversations;
create policy conv_select_member_or_public on public.conversations for select
  using (public.is_conv_member(id, auth.uid()) or (is_public and is_active) or created_by = auth.uid());

drop policy if exists conv_insert_self on public.conversations;
create policy conv_insert_self on public.conversations for insert
  with check (created_by = auth.uid());

drop policy if exists conv_update_member on public.conversations;
create policy conv_update_member on public.conversations for update
  using (public.is_conv_member(id, auth.uid()));

drop policy if exists conv_delete_admin on public.conversations;
create policy conv_delete_admin on public.conversations for delete
  using (public.is_conv_admin(id, auth.uid()) or created_by = auth.uid());

drop policy if exists members_select on public.conversation_members;
create policy members_select on public.conversation_members for select
  using (public.is_conv_member(conversation_id, auth.uid()));

drop policy if exists members_insert on public.conversation_members;
create policy members_insert on public.conversation_members for insert
  with check (
    user_id = auth.uid()
    or public.is_conv_admin(conversation_id, auth.uid())
    or exists (select 1 from conversations c where c.id = conversation_id and c.created_by = auth.uid())
  );

drop policy if exists members_update on public.conversation_members;
create policy members_update on public.conversation_members for update
  using (user_id = auth.uid() or public.is_conv_admin(conversation_id, auth.uid()));

drop policy if exists members_delete on public.conversation_members;
create policy members_delete on public.conversation_members for delete
  using (user_id = auth.uid() or public.is_conv_admin(conversation_id, auth.uid()));

-- ---------- فعال‌سازی RLS روی جدول‌های اصلی (بعد از تست دستی، یکی‌یکی) ----------
-- alter table public.conversations enable row level security;
-- alter table public.conversation_members enable row level security;
-- توجه: قبل از فعال‌کردن، مطمئن شوید برای messages / message_reactions هم سیاست دارید.
