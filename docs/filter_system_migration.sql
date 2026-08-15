-- ============================================================
-- B2B Store: Dynamic Filter System Migration
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor)
-- ============================================================

-- 1. NEW: filters table (global / category / subcategory scoped)
CREATE TABLE IF NOT EXISTS filters (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key            TEXT NOT NULL,                          -- e.g. 'capacity_ml', 'brand'
  label          TEXT NOT NULL,                          -- e.g. 'Capacity', 'Brand'
  scope          TEXT NOT NULL DEFAULT 'global'
                   CHECK (scope IN ('global','category','subcategory')),
  category_id    BIGINT REFERENCES categories(id) ON DELETE CASCADE,
  subcategory_id BIGINT REFERENCES categories(id) ON DELETE CASCADE,
  ui_type        TEXT NOT NULL DEFAULT 'multiselect'
                   CHECK (ui_type IN ('single-select','multiselect','chip-selection','range','boolean','rating')),
  data_type      TEXT NOT NULL DEFAULT 'string'
                   CHECK (data_type IN ('string','number','boolean')),
  options        JSONB DEFAULT '[]',                     -- array of option values
  sort_order     INT DEFAULT 0,
  is_active      BOOLEAN DEFAULT true,
  created_at     TIMESTAMPTZ DEFAULT now()
);

-- Unique key per scope combination (prevent duplicates)
CREATE UNIQUE INDEX IF NOT EXISTS uq_filters_key_scope
  ON filters (key, scope, COALESCE(category_id, -1), COALESCE(subcategory_id, -1));

-- 2. Add attributes column to products (non-breaking, defaults to empty object)
ALTER TABLE products
  ADD COLUMN IF NOT EXISTS attributes JSONB DEFAULT '{}';

-- 3. GIN index for performant JSONB attribute filtering
CREATE INDEX IF NOT EXISTS idx_products_attributes
  ON products USING GIN (attributes jsonb_path_ops);

-- 4. Supabase RPC: merge global + category + subcategory filters
--    Called as: supabase.rpc('get_filters_for_subcategory', { p_subcategory_id: 123 })
CREATE OR REPLACE FUNCTION get_filters_for_subcategory(p_subcategory_id BIGINT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_category_id BIGINT;
  v_result      JSONB;
BEGIN
  -- Resolve parent category from subcategory
  SELECT parent_id INTO v_category_id
    FROM categories
   WHERE id = p_subcategory_id;

  -- Merge global + category + subcategory filters, ordered by sort_order
  SELECT jsonb_agg(
    jsonb_build_object(
      'id',             f.id,
      'key',            f.key,
      'label',          f.label,
      'scope',          f.scope,
      'category_id',    f.category_id,
      'subcategory_id', f.subcategory_id,
      'ui_type',        f.ui_type,
      'data_type',      f.data_type,
      'options',        f.options,
      'sort_order',     f.sort_order
    )
    ORDER BY f.sort_order ASC, f.created_at ASC
  )
  INTO v_result
  FROM filters f
  WHERE f.is_active = true
    AND (
      f.scope = 'global'
      OR (f.scope = 'category'    AND f.category_id    = v_category_id)
      OR (f.scope = 'subcategory' AND f.subcategory_id = p_subcategory_id)
    );

  RETURN COALESCE(v_result, '[]'::JSONB);
END;
$$;

-- 5. RPC: get_filters_for_category (for category-level product listing pages)
CREATE OR REPLACE FUNCTION get_filters_for_category(p_category_id BIGINT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'id',             f.id,
      'key',            f.key,
      'label',          f.label,
      'scope',          f.scope,
      'category_id',    f.category_id,
      'subcategory_id', f.subcategory_id,
      'ui_type',        f.ui_type,
      'data_type',      f.data_type,
      'options',        f.options,
      'sort_order',     f.sort_order
    )
    ORDER BY f.sort_order ASC, f.created_at ASC
  )
  INTO v_result
  FROM filters f
  WHERE f.is_active = true
    AND (
      f.scope = 'global'
      OR (f.scope = 'category' AND f.category_id = p_category_id)
    );

  RETURN COALESCE(v_result, '[]'::JSONB);
END;
$$;

-- 6. Seed default global filters
INSERT INTO filters (key, label, scope, ui_type, data_type, options, sort_order)
VALUES
  ('price',        'Price',        'global', 'range',       'number',  '[]',                       0),
  ('availability', 'Availability', 'global', 'boolean',     'boolean', '[]',                       1),
  ('brand',        'Brand',        'global', 'multiselect', 'string',  '[]',                       2),
  ('discount',     'Discount',     'global', 'chip-selection','number','[10, 20, 30, 50]',         3),
  ('rating',       'Rating',       'global', 'rating',      'number',  '[1, 2, 3, 4, 5]',         4)
ON CONFLICT DO NOTHING;

-- ============================================================
-- DONE. Verify with:
SELECT * FROM filters;
SELECT column_name FROM information_schema.columns
WHERE table_name='products' AND column_name='attributes';
SELECT get_filters_for_subcategory(YOUR_SUBCATEGORY_ID);
-- ============================================================
