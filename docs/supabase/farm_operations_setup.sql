-- Run once in Supabase SQL Editor after farms_table_setup.sql.

create table if not exists public.farm_cycles (
  id uuid primary key default gen_random_uuid(),
  farm_id uuid not null references public.farms(id) on delete cascade,
  crop_type text not null,
  variety text,
  planted_at date not null,
  expected_harvest_at date,
  status text not null default 'active' check (status in ('planned', 'active', 'harvested', 'cancelled')),
  created_at timestamptz not null default now()
);

create table if not exists public.farm_actions (
  id bigint generated always as identity primary key,
  farm_id uuid not null references public.farms(id) on delete cascade,
  cycle_id uuid references public.farm_cycles(id) on delete set null,
  action_type text not null check (action_type in ('planting', 'watering', 'fertilizing', 'spraying', 'inspection', 'harvest', 'other')),
  amount double precision,
  unit text,
  note text,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.device_calibrations (
  id bigint generated always as identity primary key,
  farm_id uuid not null references public.farms(id) on delete cascade,
  device_id text not null,
  moisture_offset double precision not null default 0,
  ph_offset double precision not null default 0,
  ec_multiplier double precision not null default 1 check (ec_multiplier > 0),
  calibrated_at timestamptz not null default now(),
  note text
);

create index if not exists farm_cycles_farm_status_idx on public.farm_cycles(farm_id, status);
create index if not exists farm_actions_farm_time_idx on public.farm_actions(farm_id, occurred_at desc);
create index if not exists farm_actions_cycle_time_idx on public.farm_actions(cycle_id, occurred_at desc);
create index if not exists device_calibrations_device_time_idx on public.device_calibrations(device_id, calibrated_at desc);
create index if not exists device_calibrations_farm_idx on public.device_calibrations(farm_id);

alter table public.farm_cycles enable row level security;
alter table public.farm_actions enable row level security;
alter table public.device_calibrations enable row level security;

grant select, insert, update, delete on public.farm_cycles to authenticated;
grant select, insert, update, delete on public.farm_actions to authenticated;
grant select, insert, update, delete on public.device_calibrations to authenticated;
grant usage, select on sequence public.farm_actions_id_seq to authenticated;
grant usage, select on sequence public.device_calibrations_id_seq to authenticated;

drop policy if exists "Owners manage farm cycles" on public.farm_cycles;
create policy "Owners manage farm cycles" on public.farm_cycles
for all to authenticated
using (exists (select 1 from public.farms where farms.id = farm_cycles.farm_id and farms.user_id = (select auth.uid())))
with check (exists (select 1 from public.farms where farms.id = farm_cycles.farm_id and farms.user_id = (select auth.uid())));

drop policy if exists "Owners manage farm actions" on public.farm_actions;
create policy "Owners manage farm actions" on public.farm_actions
for all to authenticated
using (exists (select 1 from public.farms where farms.id = farm_actions.farm_id and farms.user_id = (select auth.uid())))
with check (
  exists (select 1 from public.farms where farms.id = farm_actions.farm_id and farms.user_id = (select auth.uid()))
  and (farm_actions.cycle_id is null or exists (
    select 1 from public.farm_cycles
    where farm_cycles.id = farm_actions.cycle_id
      and farm_cycles.farm_id = farm_actions.farm_id
  ))
);

drop policy if exists "Owners manage device calibrations" on public.device_calibrations;
create policy "Owners manage device calibrations" on public.device_calibrations
for all to authenticated
using (exists (select 1 from public.farms where farms.id = device_calibrations.farm_id and farms.user_id = (select auth.uid())))
with check (exists (select 1 from public.farms where farms.id = device_calibrations.farm_id and farms.user_id = (select auth.uid())));

notify pgrst, 'reload schema';
