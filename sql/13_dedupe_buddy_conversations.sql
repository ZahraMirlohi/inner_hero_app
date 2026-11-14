-- 13: ادغام گفتگوهای هم‌مسیر تکراری (بین یک جفت کاربر)
-- پیام‌های همه‌ی تکراری‌ها به قدیمی‌ترین گفتگو منتقل می‌شود و بقیه حذف می‌شوند.
-- قبل از اجرا یک بکاپ بگیرید. اگر جدول پیام‌ها اسم دیگری دارد، فقط خط UPDATE را عوض کنید.
begin;

create temp table _dups on commit drop as
with pairs as (
  select c.id, c.created_at,
         (select string_agg(m.user_id::text, '|' order by m.user_id::text)
            from public.conversation_members m where m.conversation_id = c.id) as pair
  from public.conversations c
  where c.type = 'buddy'
), ranked as (
  select id, pair,
         first_value(id) over (partition by pair order by created_at, id) as keep_id,
         row_number()    over (partition by pair order by created_at, id) as rn
  from pairs
  where pair is not null
)
select id as dup_id, keep_id from ranked where rn > 1;

update public.messages m
   set conversation_id = d.keep_id
  from _dups d
 where m.conversation_id = d.dup_id;

-- اعضا و خود گفتگوهای تکراری (اعضا با cascade هم پاک می‌شوند)
delete from public.conversations where id in (select dup_id from _dups);

commit;
