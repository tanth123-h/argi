-- Run once in Supabase SQL Editor.
ALTER TABLE public.farms
  ADD COLUMN IF NOT EXISTS crop_type TEXT NOT NULL DEFAULT 'rice';
