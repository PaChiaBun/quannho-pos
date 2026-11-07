-- Hoàn tác 20261103_topping_ban_tru_kho_v1.sql: trả settle_ban_session_v5 về nguyên văn fix09 —
-- số topping lại luôn quantity × số món (L7), tuỳ chọn có "id" lại bị đem trừ kho (L10), dữ liệu lạ lại
-- làm lỗi ép kiểu (Q6). Nhận cả bản mới lẫn bản vá 03/11 (chưa có Q6). Phiếu kho đã ghi giữ nguyên.

DO $rollback$
DECLARE
  v_fn constant regprocedure :=
    'public.settle_ban_session_v5(uuid, uuid, text, text, uuid, integer, numeric, text, numeric)'::regprocedure;
  -- {nguyên văn fix09, bản vá 03/11 (chưa có Q6), bản mới, số lần} — giống hệt migration
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
    IF v_old = v_want AND v_mid = 0 AND v_new = 0 THEN
      CONTINUE; -- chỗ này chưa vá
    ELSIF v_new = v_want AND v_old = 0 AND v_mid = 0 THEN
      v_def := replace(v_def, v_patches[i][3], v_patches[i][1]);
    ELSIF v_mid = v_want AND v_old = 0 AND v_new = 0 THEN
      v_def := replace(v_def, v_patches[i][2], v_patches[i][1]);
    ELSE
      RAISE EXCEPTION 'TOPPING_BAN_ROLLBACK: chỗ % cần đúng % lần, thấy fix09 % / vá 03/11 % / mới % — dừng',
        i, v_want, v_old, v_mid, v_new;
    END IF;
    v_done := v_done + 1;
  END LOOP;
  IF v_done = 0 THEN
    RAISE NOTICE 'TOPPING_BAN_ROLLBACK: hàm chưa được vá — không làm gì';
    RETURN;
  END IF;
  EXECUTE v_def;
  RAISE NOTICE 'TOPPING_BAN_ROLLBACK: đã trả % chỗ của settle_ban_session_v5 về bản fix09', v_done;
END
$rollback$;
