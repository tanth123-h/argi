-- Run once in Supabase SQL Editor.
-- The live database had an older point-count rule, so a 14-point survey was rejected.
alter table public.soil_surveys
  drop constraint if exists soil_surveys_point_count_check;

alter table public.soil_surveys
  add constraint soil_surveys_point_count_check
  check (point_count between 1 and 20);

notify pgrst, 'reload schema';
