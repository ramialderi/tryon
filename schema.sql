-- الصق هذا الملف كاملًا في Supabase → SQL Editor ثم Run

create table shops(
  id uuid primary key references auth.users on delete cascade,
  name text not null, city text,
  approved boolean not null default true,   -- للتجربة. غيّرها إلى false عند بناء لوحة الإدارة
  created_at timestamptz default now());
create table shop_contacts(shop_id uuid primary key references shops on delete cascade, phone text not null);
create table glasses(
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops on delete cascade,
  name text not null, img_url text not null, img_path text not null,
  scale real default 2.3, y_off real default 0, avail boolean not null default true,
  created_at timestamptz default now());
create table bookings(
  code text primary key, shop_id uuid not null references shops,
  glass_ids uuid[] not null, status text not null default 'reserved',
  cust text, created_at timestamptz default now(), sold_at timestamptz);

alter table shops enable row level security;
alter table shop_contacts enable row level security;
alter table glasses enable row level security;
alter table bookings enable row level security;

revoke insert, update on shops from authenticated, anon;
grant insert (id,name,city) on shops to authenticated;
grant update (name,city) on shops to authenticated;

create policy shops_read on shops for select using (approved or id=auth.uid());
create policy shops_add on shops for insert to authenticated with check (id=auth.uid());
create policy shops_edit on shops for update to authenticated using (id=auth.uid());
create policy contacts_own on shop_contacts for all to authenticated using (shop_id=auth.uid()) with check (shop_id=auth.uid());
create policy glasses_read on glasses for select using (exists(select 1 from shops s where s.id=shop_id and s.approved));
create policy glasses_add on glasses for insert to authenticated with check (shop_id=auth.uid());
create policy glasses_edit on glasses for update to authenticated using (shop_id=auth.uid());
create policy glasses_del on glasses for delete to authenticated using (shop_id=auth.uid());
create policy bookings_shop on bookings for select to authenticated using (shop_id=auth.uid());

-- الزبون لا يسجّل دخولًا: يتعامل مع الحجوزات عبر هذه الدوال فقط
create function reserve(p_shop uuid, p_glasses uuid[]) returns text
language plpgsql security definer set search_path=public as $$
declare c text; a text:='ABCDEFGHJKMNPQRSTUVWXYZ23456789'; i int;
begin
  if cardinality(p_glasses)=0 or (select count(*) from glasses g join shops s on s.id=g.shop_id
     where g.id=any(p_glasses) and g.shop_id=p_shop and g.avail and s.approved)<>cardinality(p_glasses)
  then raise exception 'invalid'; end if;
  loop
    c:=''; for i in 1..5 loop c:=c||substr(a,1+floor(random()*length(a))::int,1); end loop;
    begin insert into bookings(code,shop_id,glass_ids) values(c,p_shop,p_glasses); return c;
    exception when unique_violation then null; end;
  end loop;
end $$;

create function my_bookings(p_codes text[])
returns table(code text, shop_name text, city text, phone text, glass_ids uuid[], status text, cust text, created_at timestamptz)
language sql security definer set search_path=public as $$
  select b.code, s.name, s.city, c.phone, b.glass_ids, b.status, b.cust, b.created_at
  from bookings b join shops s on s.id=b.shop_id left join shop_contacts c on c.shop_id=b.shop_id
  where b.code = any(p_codes) $$;

create function set_cust(p_code text, p_v text) returns void
language sql security definer set search_path=public as $$
  update bookings set cust=p_v where code=upper(p_code) and p_v in ('bought','no') $$;

create function confirm_sale(p_code text) returns void
language plpgsql security definer set search_path=public as $$
begin
  update bookings set status='sold', sold_at=now()
  where code=upper(p_code) and shop_id=auth.uid() and status='reserved';
  if not found then raise exception 'not found'; end if;
end $$;

-- صور النظارات
insert into storage.buckets(id,name,public) values('glasses','glasses',true) on conflict do nothing;
create policy gl_read on storage.objects for select using (bucket_id='glasses');
create policy gl_add on storage.objects for insert to authenticated with check (bucket_id='glasses' and (storage.foldername(name))[1]=auth.uid()::text);
create policy gl_del on storage.objects for delete to authenticated using (bucket_id='glasses' and (storage.foldername(name))[1]=auth.uid()::text);
