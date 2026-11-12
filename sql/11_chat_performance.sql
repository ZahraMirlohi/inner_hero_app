-- سرعت چت: آخرین پیام و شمارنده‌ی خوانده‌نشده با یک کوئری (به‌جای دانلود همه‌ی پیام‌ها)
create index if not exists messages_conv_created_idx
  on public.messages (conversation_id, created_at desc);
create index if not exists message_reactions_msg_idx
  on public.message_reactions (message_id);
create index if not exists conversation_members_user_idx
  on public.conversation_members (user_id);

create or replace function public.chat_last_messages(p_conv_ids uuid[])
returns table(conversation_id uuid, content text, created_at timestamptz, sender_id uuid, type text)
language sql stable security invoker set search_path = public as $$
  select distinct on (m.conversation_id)
         m.conversation_id, m.content, m.created_at, m.sender_id, m.type
    from messages m
   where m.conversation_id = any(p_conv_ids) and coalesce(m.is_deleted, false) = false
   order by m.conversation_id, m.created_at desc;
$$;

create or replace function public.chat_unread_counts(p_conv_ids uuid[])
returns table(conversation_id uuid, unread bigint)
language sql stable security invoker set search_path = public as $$
  select m.conversation_id, count(*)
    from messages m
   where m.conversation_id = any(p_conv_ids)
     and coalesce(m.is_deleted, false) = false
     and m.sender_id <> auth.uid()
     and coalesce(m.status, 'sent') <> 'seen'
   group by m.conversation_id;
$$;

grant execute on function public.chat_last_messages(uuid[]) to authenticated;
grant execute on function public.chat_unread_counts(uuid[]) to authenticated;
