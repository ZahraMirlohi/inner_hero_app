-- مرحله ۵: کاوش
-- ستون package_id برای حذف دقیق عادت‌های یک بسته
alter table public.habits add column if not exists package_id text;
create index if not exists habits_package_id_idx on public.habits(package_id);
