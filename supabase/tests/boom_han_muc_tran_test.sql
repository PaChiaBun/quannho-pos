-- ============================================================================
-- TEST: 20261119_boom_han_muc_tran.sql — hàm giữ chỗ trả thêm trần bị chạm ("scope"). Kết thúc ROLLBACK.
-- Trần = 0 thì luôn chạm (tổng tiền >= 0), nên không cần dựng sẵn dòng tốn tiền.
-- Dùng quán Demo có sẵn, KHÔNG thêm quán / tài khoản thử: test này còn được chạy thử ngay trên máy chủ thật
-- (trong giao dịch, ROLLBACK ở cuối) nên tránh mọi trigger của bảng stores / user_accounts.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._bt_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

DO $test$
DECLARE
  S uuid := '00000000-0000-0000-0000-000000009999';   -- quán Demo
  A uuid;
  r jsonb;
  n0 integer;
  n integer;
BEGIN
  RAISE NOTICE '>>> BOOM HẠN MỨC TRẦN: BẮT ĐẦU <<<';
  SELECT owner_user_id INTO A FROM public.stores WHERE id = S AND COALESCE(status, 'trial') IN ('trial', 'active');
  IF A IS NULL THEN RAISE EXCEPTION '❌ FAIL: không thấy quán Demo đang hoạt động'; END IF;
  SELECT count(*) INTO n0 FROM public.boom_qa_log WHERE store_id = S;

  EXECUTE 'SET LOCAL ROLE service_role';
  -- tham số: …, lượt / người / giờ, lượt không bài / giờ, trần ngày quán, trần tháng quán, trần tháng hệ thống
  r := public.boom_ai_reserve_v1(S, A, 'x', '{}', 'advice', 99, 99, 0, 9, 1e9);
  PERFORM public._bt_ok(r = '{"ok": false, "status": "budget", "scope": "day"}'::jsonb, '1 chỉ chạm trần ngày → scope day — ' || r);
  r := public.boom_ai_reserve_v1(S, A, 'x', '{}', 'advice', 99, 99, 9, 0, 1e9);
  PERFORM public._bt_ok(r->>'status' = 'budget' AND r->>'scope' = 'month', '2 chạm trần tháng của quán → scope month');
  r := public.boom_ai_reserve_v1(S, A, 'x', '{}', 'advice', 99, 99, 0, 0, 1e9);
  PERFORM public._bt_ok(r->>'scope' = 'month', '3 chạm cả ngày lẫn tháng → báo theo tháng (ngày mai vẫn bị chặn)');
  r := public.boom_ai_reserve_v1(S, A, 'x', '{}', 'advice', 99, 99, 9, 9, 0);
  PERFORM public._bt_ok(r->>'status' = 'budget' AND r->>'scope' = 'system', '4 chạm trần tháng của cả hệ thống → scope system');
  r := public.boom_ai_reserve_v1(S, A, 'x', '{}', 'advice', 0, 99, 9, 9, 1e9);
  PERFORM public._bt_ok(r = '{"ok": false, "status": "rate_limited"}'::jsonb, '5 quá số câu / giờ → y như cũ, không có khoá scope — ' || r);
  SELECT count(*) INTO n FROM public.boom_qa_log WHERE store_id = S;
  PERFORM public._bt_ok(n = n0, '6 lượt bị chặn không ghi dòng nào vào sổ — ' || n0 || ' → ' || n);
  r := public.boom_ai_reserve_v1(S, A, 'x', '{}', 'advice', 99, 99, 9, 9, 1e9);
  PERFORM public._bt_ok((r->>'ok')::boolean AND r->>'status' = 'pending' AND r->>'id' IS NOT NULL AND NOT r ? 'scope', '7 còn hạn mức → giữ chỗ như cũ');
  EXECUTE 'RESET ROLE';

  RAISE NOTICE '>>> BOOM HẠN MỨC TRẦN: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
