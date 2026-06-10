-- ── Atomic coupon usage increment ──────────────────────────────
-- Prevents race conditions when multiple orders use the same coupon
-- Run this in Supabase SQL Editor

CREATE OR REPLACE FUNCTION increment_coupon_usage(coupon_code TEXT)
RETURNS void AS $$
BEGIN
  UPDATE public.coupons
  SET used_count = used_count + 1
  WHERE code = coupon_code
    AND is_active = TRUE
    AND used_count < max_uses;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
