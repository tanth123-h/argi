-- Run after farms_table_setup.sql in Supabase SQL Editor.
-- One schema supports both handheld samples and stationary ESP32 readings.

create table if not exists public.plots (
  id uuid primary key default gen_random_uuid(),
  farm_id uuid not null references public.farms(id) on delete cascade,
  name text not null,
  area numeric not null default 0,
  crop_type text not null default 'rice',
  boundary jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create index if not exists idx_plots_farm_id on public.plots(farm_id);

create table if not exists public.soil_surveys (
  id uuid primary key default gen_random_uuid(),
  farm_id uuid not null references public.farms(id) on delete cascade,
  status text not null default 'in_progress'
    check (status in ('in_progress', 'completed', 'cancelled')),
  point_count integer not null default 5 check (point_count between 1 and 20),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

-- Existing projects may still have an older point-count check (for example,
-- exactly 5 points). Replace it so the generator can scale with farm size.
alter table public.soil_surveys drop constraint if exists soil_surveys_point_count_check;
alter table public.soil_surveys add constraint soil_surveys_point_count_check
  check (point_count between 1 and 20);

create table if not exists public.soil_sampling_points (
  id uuid primary key default gen_random_uuid(),
  survey_id uuid not null references public.soil_surveys(id) on delete cascade,
  farm_id uuid not null references public.farms(id) on delete cascade,
  sampling_key text not null,
  sequence integer not null check (sequence > 0),
  latitude double precision not null,
  longitude double precision not null,
  status text not null default 'pending'
    check (status in ('pending', 'sampled', 'skipped')),
  sampled_at timestamptz,
  created_at timestamptz not null default now(),
  unique (survey_id, sequence),
  unique (survey_id, sampling_key)
);

create index if not exists idx_soil_surveys_farm_time
  on public.soil_surveys(farm_id, created_at desc);
create index if not exists idx_soil_sampling_points_survey
  on public.soil_sampling_points(survey_id, sequence);

create table if not exists public.soil_readings (
  id uuid primary key default gen_random_uuid(),
  client_reading_id uuid not null default gen_random_uuid(),
  farm_id uuid not null references public.farms(id) on delete cascade,
  plot_id uuid references public.plots(id) on delete set null,
  survey_id uuid references public.soil_surveys(id) on delete set null,
  sampling_point_id text,
  source text not null check (source in ('handheld', 'fixed_sensor')),
  device_id text not null,
  latitude double precision,
  longitude double precision,
  moisture double precision,
  temperature double precision,
  humidity double precision,
  ec double precision,
  ph double precision,
  nitrogen double precision,
  phosphorus double precision,
  potassium double precision,
  modbus_ok boolean not null default true,
  rssi integer,
  recorded_at timestamptz not null default now(),
  raw_payload jsonb,
  note text,
  created_at timestamptz not null default now()
);

-- Keep this migration safe for projects where soil_readings already existed.
alter table public.soil_readings add column if not exists survey_id uuid
  references public.soil_surveys(id) on delete set null;
alter table public.soil_readings add column if not exists client_reading_id uuid;
update public.soil_readings
set client_reading_id = gen_random_uuid()
where client_reading_id is null;
alter table public.soil_readings alter column client_reading_id set not null;
create unique index if not exists idx_soil_readings_client_reading_id
  on public.soil_readings(client_reading_id);

create index if not exists idx_soil_readings_farm_time
  on public.soil_readings(farm_id, recorded_at desc);
create index if not exists idx_soil_readings_plot_time
  on public.soil_readings(plot_id, recorded_at desc);
create index if not exists idx_soil_readings_device_time
  on public.soil_readings(device_id, recorded_at desc);
create index if not exists idx_soil_readings_survey_point_time
  on public.soil_readings(survey_id, sampling_point_id, recorded_at desc);

alter table public.plots enable row level security;
alter table public.soil_surveys enable row level security;
alter table public.soil_sampling_points enable row level security;
alter table public.soil_readings enable row level security;

grant select, insert, update, delete on public.plots to authenticated;
grant select, insert, update, delete on public.soil_surveys to authenticated;
grant select, insert, update, delete on public.soil_sampling_points to authenticated;
grant select, insert, update, delete on public.soil_readings to authenticated;

drop policy if exists "Users can view surveys in their farms" on public.soil_surveys;
create policy "Users can view surveys in their farms" on public.soil_surveys
  for select to authenticated using (exists (
    select 1 from public.farms
    where farms.id = soil_surveys.farm_id and farms.user_id = (select auth.uid())
  ));
drop policy if exists "Users can insert surveys in their farms" on public.soil_surveys;
create policy "Users can insert surveys in their farms" on public.soil_surveys
  for insert to authenticated with check (exists (
    select 1 from public.farms
    where farms.id = soil_surveys.farm_id and farms.user_id = (select auth.uid())
  ));
drop policy if exists "Users can update surveys in their farms" on public.soil_surveys;
create policy "Users can update surveys in their farms" on public.soil_surveys
  for update to authenticated using (exists (
    select 1 from public.farms
    where farms.id = soil_surveys.farm_id and farms.user_id = (select auth.uid())
  )) with check (exists (
    select 1 from public.farms
    where farms.id = soil_surveys.farm_id and farms.user_id = (select auth.uid())
  ));

drop policy if exists "Users can view sampling points in their farms" on public.soil_sampling_points;
create policy "Users can view sampling points in their farms" on public.soil_sampling_points
  for select to authenticated using (exists (
    select 1 from public.farms
    where farms.id = soil_sampling_points.farm_id and farms.user_id = (select auth.uid())
  ));
drop policy if exists "Users can insert sampling points in their farms" on public.soil_sampling_points;
create policy "Users can insert sampling points in their farms" on public.soil_sampling_points
  for insert to authenticated with check (exists (
    select 1 from public.farms
    where farms.id = soil_sampling_points.farm_id and farms.user_id = (select auth.uid())
  ));
drop policy if exists "Users can update sampling points in their farms" on public.soil_sampling_points;
create policy "Users can update sampling points in their farms" on public.soil_sampling_points
  for update to authenticated using (exists (
    select 1 from public.farms
    where farms.id = soil_sampling_points.farm_id and farms.user_id = (select auth.uid())
  )) with check (exists (
    select 1 from public.farms
    where farms.id = soil_sampling_points.farm_id and farms.user_id = (select auth.uid())
  ));

drop policy if exists "Users can view their own plots" on public.plots;
create policy "Users can view their own plots" on public.plots
  for select to authenticated
  using (exists (
    select 1 from public.farms
    where farms.id = plots.farm_id and farms.user_id = (select auth.uid())
  ));

drop policy if exists "Users can insert plots in their farms" on public.plots;
create policy "Users can insert plots in their farms" on public.plots
  for insert to authenticated
  with check (exists (
    select 1 from public.farms
    where farms.id = plots.farm_id and farms.user_id = (select auth.uid())
  ));

drop policy if exists "Users can update plots in their farms" on public.plots;
create policy "Users can update plots in their farms" on public.plots
  for update to authenticated
  using (exists (
    select 1 from public.farms
    where farms.id = plots.farm_id and farms.user_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.farms
    where farms.id = plots.farm_id and farms.user_id = (select auth.uid())
  ));

drop policy if exists "Users can delete plots in their farms" on public.plots;
create policy "Users can delete plots in their farms" on public.plots
  for delete to authenticated
  using (exists (
    select 1 from public.farms
    where farms.id = plots.farm_id and farms.user_id = (select auth.uid())
  ));

drop policy if exists "Users can view readings in their farms" on public.soil_readings;
create policy "Users can view readings in their farms" on public.soil_readings
  for select to authenticated
  using (exists (
    select 1 from public.farms
    where farms.id = soil_readings.farm_id and farms.user_id = (select auth.uid())
  ));

drop policy if exists "Users can insert readings in their farms" on public.soil_readings;
create policy "Users can insert readings in their farms" on public.soil_readings
  for insert to authenticated
  with check (exists (
    select 1 from public.farms
    where farms.id = soil_readings.farm_id and farms.user_id = (select auth.uid())
  ) and (soil_readings.survey_id is null or exists (
    select 1 from public.soil_surveys
    where soil_surveys.id = soil_readings.survey_id
      and soil_surveys.farm_id = soil_readings.farm_id
  )) and (soil_readings.plot_id is null or exists (
    select 1 from public.plots
    where plots.id = soil_readings.plot_id
      and plots.farm_id = soil_readings.farm_id
  )) and (soil_readings.sampling_point_id is null or exists (
    select 1 from public.soil_sampling_points
    where soil_sampling_points.id::text = soil_readings.sampling_point_id
      and soil_sampling_points.farm_id = soil_readings.farm_id
      and (soil_readings.survey_id is null or soil_sampling_points.survey_id = soil_readings.survey_id)
  )));

drop policy if exists "Users can delete readings in their farms" on public.soil_readings;
create policy "Users can delete readings in their farms" on public.soil_readings
  for delete to authenticated
  using (exists (
    select 1 from public.farms
    where farms.id = soil_readings.farm_id and farms.user_id = (select auth.uid())
  ));

notify pgrst, 'reload schema';
