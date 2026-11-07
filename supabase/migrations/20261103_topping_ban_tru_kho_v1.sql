-- =============================================================================
-- Thanh toán bàn trừ kho topping / tuỳ chọn đúng (kiểm luồng bán quán demo 03/11/2026; QC 04/11):
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
-- Q6 (QC 04/11) — dữ liệu lạ không làm hỏng lần thu tiền: "qty"/"quantity" không phải số coi như thiếu,
-- "id" không phải uuid bỏ qua (trước: lỗi ép kiểu, huỷ cả lần thu tiền). Không dùng CASE + ép kiểu: biến
-- PL/pgSQL thành hằng khi lập kế hoạch nên 'abc'::numeric vẫn bị tính sẵn và lỗi — đọc số bằng
-- jsonb_path_query_first(…, '$.qty.double()', …, silent = true), so mã món dạng chữ (id::text).
--
-- Vá đúng các chỗ trên trong bản ĐANG CHẠY (pg_get_functiondef + replace), phần còn lại của hàm giữ
-- nguyên văn, quyền GRANT giữ nguyên (CREATE OR REPLACE). Mỗi chỗ nhận nguyên văn bản fix09 hoặc bản vá
-- 03/11 (chưa có Q6) và thay bằng bản mới; số lần phải đúng, không thì dừng; đã là bản mới thì bỏ qua.
--
-- Hoàn tác: 20261103_topping_ban_tru_kho_v1_ROLLBACK.sql. Test: supabase/tests/topping_ban_tru_kho_v1_test.sql
-- =============================================================================

DO $migration$
DECLARE
  v_fn constant regprocedure :=
    'public.settle_ban_session_v5(uuid, uuid, text, text, uuid, integer, numeric, text, numeric)'::regprocedure;
  -- {nguyên văn fix09, bản vá 03/11 (chưa có Q6), bản mới, số lần}
  v_patches constant text[][] := ARRAY[
    [$o1$(COALESCE((v_mod->>'quantity')::numeric, 1)) * v_item.quantity$o1$,
     $m1$COALESCE((v_mod->>'qty')::numeric, COALESCE((v_mod->>'quantity')::numeric, 1) * v_item.quantity)$m1$,
     $n1$COALESCE((jsonb_path_query_first(v_mod, '$.qty.double()', '{}', true))::numeric, COALESCE((jsonb_path_query_first(v_mod, '$.quantity.double()', '{}', true))::numeric, 1) * v_item.quantity)$n1$,
     '3'],
    [$o2$IF (v_mod->>'id') IS NOT NULL THEN$o2$,
     $m2$IF (v_mod->>'id') IS NOT NULL AND EXISTS (SELECT 1 FROM public.products WHERE id = (v_mod->>'id')::uuid AND store_id = p_store_id) THEN$m2$,
     $n2$IF (v_mod->>'id') IS NOT NULL AND EXISTS (SELECT 1 FROM public.products WHERE store_id = p_store_id AND id::text = (v_mod->>'id')) THEN$n2$,
     '1']
  ];
  v_def  text := pg_get_functiondef(v_fn);
  v_want int;
  v_old  int;
  v_mid  int;
  v_new  int;
  v_done int := 0;
BEGIN
  FOR i IN 1 .. array_length(v_patches, 1) LOOP
    v_want := v_patches[i][4]::int;
    v_old := (length(v_def) - length(replace(v_def, v_patches[i][1], ''))) / length(v_patches[i][1]);
    v_mid := (length(v_def) - length(replace(v_def, v_patches[i][2], ''))) / length(v_patches[i][2]);
    v_new := (length(v_def) - length(replace(v_def, v_patches[i][3], ''))) / length(v_patches[i][3]);
    IF v_new = v_want AND v_old = 0 AND v_mid = 0 THEN
      CONTINUE; -- chỗ này đã là bản mới
    ELSIF v_old = v_want AND v_mid = 0 AND v_new = 0 THEN
      v_def := replace(v_def, v_patches[i][1], v_patches[i][3]);
    ELSIF v_mid = v_want AND v_old = 0 AND v_new = 0 THEN
      v_def := replace(v_def, v_patches[i][2], v_patches[i][3]);
    ELSE
      RAISE EXCEPTION 'TOPPING_BAN_PATCH: chỗ % cần đúng % lần, thấy fix09 % / vá 03/11 % / mới % — hàm đã khác, dừng',
        i, v_want, v_old, v_mid, v_new;
    END IF;
    v_done := v_done + 1;
  END LOOP;
  IF v_done = 0 THEN
    RAISE NOTICE 'TOPPING_BAN_PATCH: hàm đã được vá trước đó — bỏ qua';
    RETURN;
  END IF;
  EXECUTE v_def;
  RAISE NOTICE 'TOPPING_BAN_PATCH: đã vá % chỗ trong settle_ban_session_v5 (số topping, bỏ qua tuỳ chọn, dữ liệu lạ)', v_done;
END
$migration$;
