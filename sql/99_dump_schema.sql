-- فقط خواندنی: ساختار واقعی جدول‌ها و ستون‌ها. در SQL Editor اجرا کنید و خروجی را بفرستید.
select c.table_name, c.ordinal_position as n, c.column_name, c.data_type,
       c.is_nullable as nullable, c.column_default as default_value
from information_schema.columns c
join information_schema.tables t
  on t.table_schema = c.table_schema and t.table_name = c.table_name and t.table_type = 'BASE TABLE'
where c.table_schema = 'public'
order by c.table_name, c.ordinal_position;
