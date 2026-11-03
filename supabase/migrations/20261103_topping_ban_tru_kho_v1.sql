-- =============================================================================
-- Thanh toán bàn trừ kho topping / tuỳ chọn đúng (kiểm luồng bán quán demo 03/11/2026):
--
-- L7 — số topping. Màn Quản lý bàn ghi topping {"qty": N} = TỔNG số phần của cả dòng (2 ly + 1 trân
-- châu → qty 1, thu 5.000 đ). settle_ban_session_v5 chỉ đọc khoá "quantity" (kiểu đơn QR = số phần
-- MỖI món) nên với món bàn luôn trừ 1 × số món: bán 1 trân châu cho 2 ly bị trừ 2; 1 ly + 3 trân châu
-- chỉ trừ 1. Sửa: có "qty" → trừ đúng qty, không nhân số món; không có → giữ cách QR
-- (quantity × số món, thiếu thì 1).
--
-- L10 — tuỳ chọn hương vị. App ghi cả dòng product_modifiers ("Ít đá"…, có "id" của tuỳ chọn) vào
-- modifiers_json; hàm coi mọi phần tử có "id" là món để trừ kho → stock_movements.product_id = id tuỳ
-- chọn → lỗi khoá ngoại stock_movements_product_id_fkey, cả lần thu tiền bàn bị huỷ. Sửa: chỉ trừ kho
-- phần tử mà "id" là món của quán; tuỳ chọn bỏ qua (giá đã cộng vào đơn giá dòng).
--
-- Vá đúng các chỗ trên trong bản ĐANG CHẠY (pg_get_functiondef + replace), phần còn lại của hàm giữ
-- nguyên văn, quyền GRANT giữ nguyên (CREATE OR REPLACE). Mỗi chỗ phải thấy đúng số lần như bản fix09,
-- không thì dừng; chỗ đã vá thì bỏ qua (chạy lại lần 2 không làm gì).
--
-- Hoàn tác: 20261103_topping_ban_tru_kho_v1_ROLLBACK.sql. Test: supabase/tests/topping_ban_tru_kho_v1_test.sql
-- =============================================================================

DO $migration$
DECLARE
  v_fn constant regprocedure :=
    'public.settle_ban_session_v5(uuid, uuid, text, text, uuid, integer, numeric, text, numeric)'::regprocedure;
  -- {nguyên văn fix09, bản vá, số lần}
  v_patches constant text[][] := ARRAY[
    [$o1$(COALESCE((v_mod->>'quantity')::numeric, 1)) * v_item.quantity$o1$,
     $n1$COALESCE((v_mod->>'qty')::numeric, COALESCE((v_mod->>'quantity')::numeric, 1) * v_item.quantity)$n1$,
     '3'],
    [$o2$IF (v_mod->>'id') IS NOT NULL THEN$o2$,
     $n2$IF (v_mod->>'id') IS NOT NULL AND EXISTS (SELECT 1 FROM public.products WHERE id = (v_mod->>'id')::uuid AND store_id = p_store_id) THEN$n2$,
     '1']
  ];
  v_def  text := pg_get_functiondef(v_fn);
  v_old  text;
  v_new  text;
  v_hits int;
  v_done int := 0;
BEGIN
  FOR i IN 1 .. array_length(v_patches, 1) LOOP
    v_old := v_patches[i][1];
    v_new := v_patches[i][2];
    v_hits := (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old);
    IF v_hits = 0 AND position(v_new IN v_def) > 0 THEN
      CONTINUE; -- chỗ này đã vá
    END IF;
    IF v_hits <> v_patches[i][3]::int THEN
      RAISE EXCEPTION 'TOPPING_BAN_PATCH: chỗ % cần đúng % lần, thấy % — hàm đã khác bản fix09, dừng',
        i, v_patches[i][3], v_hits;
    END IF;
    v_def := replace(v_def, v_old, v_new);
    v_done := v_done + 1;
  END LOOP;
  IF v_done = 0 THEN
    RAISE NOTICE 'TOPPING_BAN_PATCH: hàm đã được vá trước đó — bỏ qua';
    RETURN;
  END IF;
  EXECUTE v_def;
  RAISE NOTICE 'TOPPING_BAN_PATCH: đã vá % chỗ trong settle_ban_session_v5 (số topping + bỏ qua tuỳ chọn)', v_done;
END
$migration$;
