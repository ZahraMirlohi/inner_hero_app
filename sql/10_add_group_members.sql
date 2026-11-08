-- افزودن هم‌مسیرهای خودِ ادمین به گروه (سمت سرور فقط هم‌مسیرهای واقعی و غیرمسدود پذیرفته می‌شوند)
create or replace function public.add_group_members(p_conversation_id uuid, p_user_ids uuid[])
returns int language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); n int := 0; u uuid;
begin
  if me is null then raise exception 'not authenticated'; end if;
  if not is_conv_admin(p_conversation_id, me) then raise exception 'admin only'; end if;
  foreach u in array p_user_ids loop
    if not exists (
      select 1
      from conversation_members a
      join conversation_members b on b.conversation_id = a.conversation_id
      join conversations c on c.id = a.conversation_id
      where c.type = 'buddy' and a.user_id = me and b.user_id = u
    ) then continue; end if;
    if exists (select 1 from conversation_bans where conversation_id = p_conversation_id and user_id = u) then continue; end if;
    insert into conversation_members (conversation_id, user_id, role, joined_at)
    values (p_conversation_id, u, 'member', now()) on conflict do nothing;
    if found then n := n + 1; end if;
  end loop;
  return n;
end $$;
grant execute on function public.add_group_members(uuid, uuid[]) to authenticated;
