-- مرحله ۶: پیدا کردن هم‌مسیر و درخواست‌ها
-- سیاست‌های افزایشی (اگر RLS روی این جدول‌ها خاموش باشد بی‌اثرند)

-- ۱) هر کاربر بتواند کاربرانی را که «دنبال هم‌مسیر» هستند ببیند
drop policy if exists "read buddy candidates" on public.user_personalities;
create policy "read buddy candidates" on public.user_personalities
  for select to authenticated
  using (user_id = auth.uid() or is_looking_for_buddy::text in ('true','t'));

-- ۲) طرفین درخواست بتوانند آن را ببینند
drop policy if exists "buddy_requests participants select" on public.buddy_requests;
create policy "buddy_requests participants select" on public.buddy_requests
  for select to authenticated
  using (from_user_id = auth.uid() or to_user_id = auth.uid());

-- ۳) فرستنده بتواند درخواست بفرستد/لغو کند، گیرنده بتواند پاسخ بدهد
drop policy if exists "buddy_requests sender insert" on public.buddy_requests;
create policy "buddy_requests sender insert" on public.buddy_requests
  for insert to authenticated with check (from_user_id = auth.uid());

drop policy if exists "buddy_requests sender delete" on public.buddy_requests;
create policy "buddy_requests sender delete" on public.buddy_requests
  for delete to authenticated using (from_user_id = auth.uid() or to_user_id = auth.uid());

drop policy if exists "buddy_requests receiver update" on public.buddy_requests;
create policy "buddy_requests receiver update" on public.buddy_requests
  for update to authenticated using (to_user_id = auth.uid());
