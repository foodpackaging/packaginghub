-- Optional access migration for the current React admin dashboard.
-- The dashboard currently uses the Supabase anon/publishable key plus an in-app login,
-- so these policies allow that dashboard to read orders and set delivery ETA.
-- For production, replace the hardcoded admin login with Supabase Auth + is_admin policies.

DROP POLICY IF EXISTS "Admin dashboard can view orders" ON public.orders;
CREATE POLICY "Admin dashboard can view orders"
ON public.orders
FOR SELECT
TO anon
USING (true);

DROP POLICY IF EXISTS "Admin dashboard can update order ETA" ON public.orders;
CREATE POLICY "Admin dashboard can update order ETA"
ON public.orders
FOR UPDATE
TO anon
USING (true)
WITH CHECK (true);

DROP POLICY IF EXISTS "Admin dashboard can view order items" ON public.order_items;
CREATE POLICY "Admin dashboard can view order items"
ON public.order_items
FOR SELECT
TO anon
USING (true);

DROP POLICY IF EXISTS "Admin dashboard can view profiles" ON public.profiles;
CREATE POLICY "Admin dashboard can view profiles"
ON public.profiles
FOR SELECT
TO anon
USING (true);
