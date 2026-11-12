-- مرحله ۶ (ادامه): ادمین گروه بتواند پیام اعضا را حذف کند
-- (فقط وقتی RLS روی messages فعال است معنا دارد؛ اگر فعال نیست بی‌اثر است)
drop policy if exists "group admins delete messages" on public.messages;
create policy "group admins delete messages" on public.messages
  for delete to authenticated
  using (public.is_conv_admin(conversation_id, auth.uid()));
