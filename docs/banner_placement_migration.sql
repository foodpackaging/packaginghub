-- Adds banner placement support for separate home page banner slots.
-- Existing banners are kept as hero carousel banners.

ALTER TABLE banners
ADD COLUMN IF NOT EXISTS placement TEXT NOT NULL DEFAULT 'hero';

ALTER TABLE banners
DROP CONSTRAINT IF EXISTS banners_placement_check;

ALTER TABLE banners
ADD CONSTRAINT banners_placement_check
CHECK (placement IN ('hero', 'category'));

CREATE INDEX IF NOT EXISTS banners_placement_created_at_idx
ON banners (placement, created_at DESC);
