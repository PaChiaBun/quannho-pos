-- ═══════════════════════════════════════════════════════════════════════════
-- QUÁN NHỎ POS & KAY RESTAURANT — STAGING CLEANUP TEST DATA SCRIPT (VERIFIED SCHEMA)
-- File: supabase/staging_cleanup_test_data.sql
-- Note: Safely deletes all test records associated ONLY with KAY STAGING TEST store.
-- ═══════════════════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_store_id uuid := '00000000-0000-0000-0000-000000000099'::uuid;
BEGIN
  -- Delete QR Request Items & Requests
  DELETE FROM qr_request_items WHERE request_id IN (SELECT id FROM qr_requests WHERE store_id = v_store_id);
  DELETE FROM qr_requests WHERE store_id = v_store_id;

  -- Delete QR Channels
  DELETE FROM qr_channels WHERE store_id = v_store_id;

  -- Delete Product Topping Links
  DELETE FROM product_topping_links WHERE product_id IN (SELECT id FROM products WHERE store_id = v_store_id);

  -- Delete Products
  DELETE FROM products WHERE store_id = v_store_id;

  -- Delete Dining Tables & Zones (ban_dining_tables and ban_zones)
  DELETE FROM ban_dining_tables WHERE store_id = v_store_id;
  DELETE FROM ban_zones WHERE store_id = v_store_id;

  -- Delete Test Store
  DELETE FROM stores WHERE id = v_store_id;

  RAISE NOTICE 'Staging Test Data Cleaned Up Successfully for Store KAY STAGING TEST (%)', v_store_id;
END $$;
