-- اجرا در Supabase SQL Editor
alter table public.profiles
  add column if not exists allow_buddy_requests boolean not null default true;

create or replace function public.block_disallowed_buddy_request()
returns trigger language plpgsql security definer as $$
begin
  if exists (select 1 from public.profiles
             where user_id = new.to_user_id and allow_buddy_requests = false) then
    raise exception 'user_not_accepting_requests';
  end if;
  return new;
end $$;

drop trigger if exists trg_block_disallowed_buddy_request on public.buddy_requests;
create trigger trg_block_disallowed_buddy_request
  before insert on public.buddy_requests
  for each row execute function public.block_disallowed_buddy_request();
