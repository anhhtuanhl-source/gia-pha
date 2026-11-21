-- Bảng gia phả cho website Gia Phả. Chạy một lần trong Supabase > SQL Editor.
create table if not exists public.family_trees (
  id uuid primary key default gen_random_uuid(),
  owner uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null default 'Gia phả',
  data jsonb not null default '{"people":[]}'::jsonb,
  is_public boolean not null default false,
  editors text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists family_trees_owner_idx on public.family_trees(owner);

alter table public.family_trees enable row level security;

drop policy if exists "ft_select" on public.family_trees;
drop policy if exists "ft_insert" on public.family_trees;
drop policy if exists "ft_update" on public.family_trees;
drop policy if exists "ft_delete" on public.family_trees;

-- Xem: chủ cây, người được mời sửa, hoặc bất kỳ ai nếu cây đang mở công khai
create policy "ft_select" on public.family_trees for select to anon, authenticated
  using (is_public or owner = auth.uid() or lower(coalesce(auth.jwt()->>'email','')) = any(editors));
-- Tạo: chỉ cho chính mình
create policy "ft_insert" on public.family_trees for insert to authenticated
  with check (owner = auth.uid());
-- Sửa: chủ cây và người được mời
create policy "ft_update" on public.family_trees for update to authenticated
  using (owner = auth.uid() or lower(coalesce(auth.jwt()->>'email','')) = any(editors))
  with check (owner = auth.uid() or lower(coalesce(auth.jwt()->>'email','')) = any(editors));
-- Xoá: chỉ chủ cây
create policy "ft_delete" on public.family_trees for delete to authenticated
  using (owner = auth.uid());

-- Người được mời chỉ sửa được nội dung, không đổi chủ, quyền chia sẻ hay danh sách người sửa.
-- Mỗi lần lưu tự cập nhật updated_at để phát hiện hai người sửa cùng lúc.
create or replace function public.family_trees_guard() returns trigger
language plpgsql as $$
begin
  if tg_op = 'UPDATE' then
    if old.owner <> coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid) then
      new.owner := old.owner;
      new.is_public := old.is_public;
      new.editors := old.editors;
    end if;
    new.owner := old.owner;
    new.created_at := old.created_at;
  end if;
  new.editors := coalesce((select array_agg(distinct lower(trim(e))) from unnest(new.editors) e where trim(e) <> ''), '{}');
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists family_trees_guard on public.family_trees;
create trigger family_trees_guard before insert or update on public.family_trees
  for each row execute function public.family_trees_guard();

grant select on public.family_trees to anon;
grant select, insert, update, delete on public.family_trees to authenticated;
