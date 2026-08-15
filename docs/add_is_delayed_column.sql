-- Migration: Add `is_delayed` flag to orders table to support the Delay Order feature.

ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS is_delayed BOOLEAN DEFAULT false;

-- Also update the policy if we are restricting updates to certain columns
-- Since the existing policy uses FOR UPDATE TO anon USING (true) WITH CHECK (true), 
-- it automatically grants access to update this new column, so no policy changes are strictly necessary.
