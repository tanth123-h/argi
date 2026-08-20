-- Run this entire file once in Supabase Dashboard -> SQL Editor.
-- It creates the table required by the Flutter farm mapping screen.

create table if not exists public.farms (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  location text not null,
  size numeric not null default 0,
  polygon_coordinates jsonb,
  crop_type text not null default 'rice',
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create index if not exists idx_farms_user_id on public.farms(user_id);
create index if not exists idx_farms_created_at on public.farms(created_at desc);

alter table public.farms enable row level security;

grant select, insert, update, delete on public.farms to authenticated;

drop policy if exists "Users can view their own farms" on public.farms;
create policy "Users can view their own farms"
  on public.farms for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert their own farms" on public.farms;
create policy "Users can insert their own farms"
  on public.farms for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own farms" on public.farms;
create policy "Users can update their own farms"
  on public.farms for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own farms" on public.farms;
create policy "Users can delete their own farms"
  on public.farms for delete to authenticated
  using ((select auth.uid()) = user_id);

-- Ask PostgREST to see the new table immediately.
notify pgrst, 'reload schema';
