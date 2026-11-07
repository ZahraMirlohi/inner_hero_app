-- تصویر کارت‌ها: آدرس (URL) تصویر را در این ستون‌ها بگذارید.
-- تصویر را در Supabase Storage (باکت عمومی) آپلود کنید و Public URL را اینجا بنویسید.
alter table public.challenges add column if not exists image_url text;
alter table public.packages   add column if not exists image_url text;
alter table public.quests     add column if not exists image_url text;
