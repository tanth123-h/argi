-- Apply once to the connected Supabase project.
-- SamplingPointGenerator supports 5..60 points; 9 rai produces 14 points.
alter table public.soil_surveys
  drop constraint if exists soil_surveys_point_count_check;

alter table public.soil_surveys
  add constraint soil_surveys_point_count_check
  check (point_count between 1 and 60);

notify pgrst, 'reload schema';
