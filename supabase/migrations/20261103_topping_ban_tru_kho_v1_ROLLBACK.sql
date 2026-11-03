-- Hoàn tác 20261103_topping_ban_tru_kho_v1.sql: trả settle_ban_session_v5 về nguyên văn fix09 —
-- số topping lại luôn quantity × số món (L7), tuỳ chọn có "id" lại bị đem trừ kho (L10).
-- Phiếu kho đã ghi giữ nguyên.

DO $rollback$
DECLARE
  v_fn constant regprocedure :=
    'public.settle_ban_session_v5(uuid, uuid, text, text, uuid, integer, numeric, text, numeric)'::regprocedure;
  -- {nguyên văn fix09, bản vá, số lần} — giống hệt migration
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
    v_hits := (length(v_def) - length(replace(v_def, v_new, ''))) / length(v_new);
    IF v_hits = 0 THEN
      CONTINUE; -- chỗ này chưa vá
    END IF;
    IF v_hits <> v_patches[i][3]::int THEN
      RAISE EXCEPTION 'TOPPING_BAN_ROLLBACK: chỗ % cần đúng % lần, thấy % — dừng', i, v_patches[i][3], v_hits;
    END IF;
    v_def := replace(v_def, v_new, v_old);
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
