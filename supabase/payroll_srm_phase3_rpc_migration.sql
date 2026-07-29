-- ─────────────────────────────────────────────────────────────────────────────
-- Quán Nhỏ POS — Phase 3: Payroll SRM RPCs (Nguyên tử, Idempotent)
-- Module: Lương (Tích hợp Điểm Tâm/Tuệ)
-- Migration: Forward-only, additive, rerunnable
-- ─────────────────────────────────────────────────────────────────────────────

-- ============================================================================
-- 1. HELPERS
-- ============================================================================

-- 1.1 Lấy ID user thực (Custom Auth)
-- Lưu ý Trust Boundary: x-user-id qua custom auth giúp giảm thiểu accidental bypass,
-- nhưng CHƯA PHẢI là cryptographic identity.
-- Cần signed auth (ví dụ JWT) để hardening trước khi lên production môi trường high-trust.
CREATE OR REPLACE FUNCTION public.payroll_srm_current_user_id()
RETURNS uuid
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_headers text;
    v_user_id text;
BEGIN
    BEGIN
        v_headers := current_setting('request.headers', true);
        IF v_headers IS NULL OR v_headers = '' THEN
            RETURN '00000000-0000-0000-0000-000000000000'::uuid;
        END IF;

        v_user_id := v_headers::json->>'x-user-id';

        IF v_user_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' THEN
            RETURN v_user_id::uuid;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        -- PL/pgSQL exception-safe: Bắt mọi lỗi parse JSON hoặc malformed
        RETURN '00000000-0000-0000-0000-000000000000'::uuid;
    END;
    RETURN '00000000-0000-0000-0000-000000000000'::uuid;
END;
$$;

-- 1.2 Helper kiểm tra quyền hành động (Internal - Không cấp cho PUBLIC)
CREATE OR REPLACE FUNCTION public.payroll_srm_has_permission(
    p_store_id uuid,
    p_action text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'pg_catalog', 'public'
AS $$
DECLARE
    v_user_id uuid;
    v_sm record;
    v_store_actions jsonb;
    v_setting_value text;
BEGIN
    IF p_store_id IS NULL OR p_action IS NULL OR btrim(p_action) = '' THEN
        RETURN false;
    END IF;

    v_user_id := public.payroll_srm_current_user_id();
    IF v_user_id = '00000000-0000-0000-0000-000000000000'::uuid THEN
        RETURN false;
    END IF;

    -- Lấy record store_members bằng alias sm
    SELECT sm.*
    INTO v_sm
    FROM public.store_members sm
    WHERE sm.store_id = p_store_id AND sm.user_id = v_user_id;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    -- Kiểm tra is_owner (xử lý an toàn null)
    IF COALESCE(v_sm.is_owner, false) THEN
        RETURN true;
    END IF;

    -- Kiểm tra store_members.actions (đọc qua jsonb để không crash compile nếu thiếu cột)
    BEGIN
        v_setting_value := to_jsonb(v_sm)->>'actions';
        IF v_setting_value IS NOT NULL THEN
            v_store_actions := v_setting_value::jsonb;
            IF jsonb_typeof(v_store_actions) = 'array' THEN
                RETURN v_store_actions ? p_action;
            END IF;
            -- Direct actions non-null nhưng không phải array -> fail-closed
            RETURN false;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RETURN false; -- Malformed JSON
    END;

    -- Kiểm tra app_settings nếu store_members.actions là null
    BEGIN
        SELECT value INTO v_setting_value
        FROM public.app_settings
        WHERE store_id = p_store_id AND key = 'action_perms_' || v_sm.role;

        IF v_setting_value IS NOT NULL THEN
            v_store_actions := v_setting_value::jsonb;
            IF jsonb_typeof(v_store_actions) = 'array' THEN
                RETURN v_store_actions ? p_action;
            END IF;
            -- Setting non-null nhưng không phải array -> fail-closed
            RETURN false;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RETURN false; -- Malformed/Error deny
    END;

    -- KHÔNG CÒN hardcoded fallback manager. SQL high-risk bắt buộc fail-closed.
    RETURN false;
END;
$$;

-- 1.3 Helper xác minh tính toàn vẹn của Point Ledger (Internal - Không cấp cho PUBLIC)
CREATE OR REPLACE FUNCTION public.payroll_srm_verify_ledger(
    p_proposal_id uuid,
    p_store_id uuid,
    p_target_user_id uuid,
    p_dimension text,
    p_points integer
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'pg_catalog', 'public'
AS $$
DECLARE
    v_event public.payroll_srm_point_events;
BEGIN
    SELECT * INTO v_event FROM public.payroll_srm_point_events WHERE proposal_id = p_proposal_id;
    IF NOT FOUND THEN
        RETURN false;
    END IF;

    IF v_event.store_id IS DISTINCT FROM p_store_id OR
       v_event.target_user_id IS DISTINCT FROM p_target_user_id OR
       v_event.dimension IS DISTINCT FROM p_dimension OR
       v_event.points IS DISTINCT FROM p_points THEN
        RETURN false;
    END IF;

    RETURN true;
END;
$$;


-- ============================================================================
-- 2. RPCs
-- ============================================================================

-- 2.1 Cập nhật thiết lập (Upsert)
CREATE OR REPLACE FUNCTION public.payroll_srm_update_settings(
    p_enable_tam boolean,
    p_enable_tue boolean,
    p_point_rules jsonb
)
RETURNS public.payroll_srm_settings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'pg_catalog', 'public'
AS $$
DECLARE
    v_store_id uuid;
    v_actor uuid;
    v_result public.payroll_srm_settings;
    v_before jsonb;
    v_after jsonb;
BEGIN
    v_store_id := public.current_store_id();
    v_actor := public.payroll_srm_current_user_id();

    IF v_store_id IS NULL OR v_actor = '00000000-0000-0000-0000-000000000000'::uuid THEN
        RAISE EXCEPTION 'Invalid store or user';
    END IF;

    IF NOT public.payroll_srm_has_permission(v_store_id, 'tinhluong.srm_settings') THEN
        RAISE EXCEPTION 'Permission denied';
    END IF;

    IF jsonb_typeof(p_point_rules) IS DISTINCT FROM 'object' THEN
        RAISE EXCEPTION 'point_rules must be a JSON object';
    END IF;

    SELECT to_jsonb(s.*) INTO v_before
    FROM public.payroll_srm_settings s
    WHERE s.store_id = v_store_id FOR UPDATE;

    INSERT INTO public.payroll_srm_settings (store_id, enable_tam, enable_tue, point_rules)
    VALUES (v_store_id, p_enable_tam, p_enable_tue, p_point_rules)
    ON CONFLICT (store_id) DO UPDATE
    SET enable_tam = p_enable_tam, enable_tue = p_enable_tue, point_rules = p_point_rules, updated_at = NOW()
    RETURNING * INTO v_result;

    v_after := to_jsonb(v_result.*);

    INSERT INTO public.payroll_srm_audit_events
    (store_id, actor_user_id, entity_type, entity_id, action, before_data, after_data)
    VALUES (v_store_id, v_actor, 'settings', v_store_id, 'UPDATE_SETTINGS', COALESCE(v_before, '{}'::jsonb), v_after);

    RETURN v_result;
END;
$$;

-- 2.2 Đề xuất điểm (Submit)
CREATE OR REPLACE FUNCTION public.payroll_srm_submit_proposal(
    p_target_user_id uuid,
    p_dimension text,
    p_proposal_type text,
    p_title text,
    p_description text,
    p_evidence jsonb,
    p_proposed_points integer,
    p_idempotency_key text
)
RETURNS public.payroll_srm_proposals
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'pg_catalog', 'public'
AS $$
DECLARE
    v_store_id uuid;
    v_actor uuid;
    v_settings public.payroll_srm_settings;
    v_result public.payroll_srm_proposals;
    v_after jsonb;
BEGIN
    v_store_id := public.current_store_id();
    v_actor := public.payroll_srm_current_user_id();

    IF v_store_id IS NULL OR v_actor = '00000000-0000-0000-0000-000000000000'::uuid THEN
        RAISE EXCEPTION 'Invalid store or user';
    END IF;

    -- Normalize & Validate
    p_title := btrim(p_title);
    p_idempotency_key := btrim(p_idempotency_key);
    p_dimension := lower(btrim(p_dimension));
    p_proposal_type := lower(btrim(p_proposal_type));

    IF p_title IS NULL OR p_title = '' THEN
        RAISE EXCEPTION 'Title cannot be empty';
    END IF;
    IF p_idempotency_key IS NULL OR p_idempotency_key = '' THEN
        RAISE EXCEPTION 'Idempotency key cannot be empty';
    END IF;
    IF p_dimension IS NULL OR p_dimension = '' THEN
        RAISE EXCEPTION 'Dimension cannot be empty';
    END IF;
    IF p_proposal_type IS NULL OR p_proposal_type = '' THEN
        RAISE EXCEPTION 'Proposal type cannot be empty';
    END IF;
    IF p_target_user_id IS NULL THEN
        RAISE EXCEPTION 'Target user ID cannot be null';
    END IF;
    IF p_proposed_points IS NULL OR p_proposed_points < 0 THEN
        RAISE EXCEPTION 'Points must be non-negative';
    END IF;
    IF jsonb_typeof(p_evidence) IS DISTINCT FROM 'object' THEN
        RAISE EXCEPTION 'evidence must be a JSON object';
    END IF;

    -- Kiểm tra Membership của actor
    IF NOT EXISTS (SELECT 1 FROM public.store_members WHERE store_id = v_store_id AND user_id = v_actor) THEN
        RAISE EXCEPTION 'Actor is not a store member';
    END IF;

    -- Kiểm tra Membership của target
    IF NOT EXISTS (SELECT 1 FROM public.store_members WHERE store_id = v_store_id AND user_id = p_target_user_id) THEN
        RAISE EXCEPTION 'Target is not a store member';
    END IF;

    -- Kiểm tra settings xem feature có bật không (FOR SHARE để không lock submit lẫn nhau, nhưng chặn UPDATE xen ngang)
    SELECT * INTO v_settings FROM public.payroll_srm_settings WHERE store_id = v_store_id FOR SHARE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'SRM settings not found';
    END IF;

    IF p_dimension = 'tam' AND NOT COALESCE(v_settings.enable_tam, false) THEN
        RAISE EXCEPTION 'Tâm dimension is not enabled';
    END IF;
    IF p_dimension = 'tue' AND NOT COALESCE(v_settings.enable_tue, false) THEN
        RAISE EXCEPTION 'Tuệ dimension is not enabled';
    END IF;

    -- Idempotency check: insert an toàn
    INSERT INTO public.payroll_srm_proposals
    (store_id, target_user_id, proposed_by_user_id, dimension, proposal_type, title, description, evidence, proposed_points, idempotency_key)
    VALUES (v_store_id, p_target_user_id, v_actor, p_dimension, p_proposal_type, p_title, p_description, p_evidence, p_proposed_points, p_idempotency_key)
    ON CONFLICT (store_id, idempotency_key) DO NOTHING
    RETURNING * INTO v_result;

    IF NOT FOUND THEN
        SELECT * INTO v_result
        FROM public.payroll_srm_proposals
        WHERE store_id = v_store_id AND idempotency_key = p_idempotency_key;

        -- Kiểm tra toàn bộ payload bằng IS DISTINCT FROM
        IF v_result.target_user_id IS DISTINCT FROM p_target_user_id OR
           v_result.proposed_by_user_id IS DISTINCT FROM v_actor OR
           v_result.dimension IS DISTINCT FROM p_dimension OR
           v_result.proposal_type IS DISTINCT FROM p_proposal_type OR
           v_result.title IS DISTINCT FROM p_title OR
           v_result.description IS DISTINCT FROM p_description OR
           v_result.evidence IS DISTINCT FROM p_evidence OR
           v_result.proposed_points IS DISTINCT FROM p_proposed_points THEN
            RAISE EXCEPTION 'Conflict on idempotency key with different payload';
        END IF;

        -- Idempotent return (trả về row cũ do payload khớp 100%)
        RETURN v_result;
    END IF;

    v_after := to_jsonb(v_result.*);
    INSERT INTO public.payroll_srm_audit_events
    (store_id, actor_user_id, entity_type, entity_id, action, after_data)
    VALUES (v_store_id, v_actor, 'proposal', v_result.id, 'SUBMIT', v_after);

    RETURN v_result;
END;
$$;


-- 2.3 Duyệt / Từ chối đề xuất (Review)
CREATE OR REPLACE FUNCTION public.payroll_srm_review_proposal(
    p_proposal_id uuid,
    p_decision text,
    p_notes text
)
RETURNS public.payroll_srm_proposals
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'pg_catalog', 'public'
AS $$
DECLARE
    v_store_id uuid;
    v_actor uuid;
    v_row public.payroll_srm_proposals;
    v_before jsonb;
    v_after jsonb;
BEGIN
    v_store_id := public.current_store_id();
    v_actor := public.payroll_srm_current_user_id();

    IF v_store_id IS NULL OR v_actor = '00000000-0000-0000-0000-000000000000'::uuid THEN
        RAISE EXCEPTION 'Invalid store or user';
    END IF;

    p_decision := lower(btrim(p_decision));
    IF p_decision IS NULL OR p_decision NOT IN ('approved', 'rejected') THEN
        RAISE EXCEPTION 'Invalid decision. Must be approved or rejected';
    END IF;

    IF NOT public.payroll_srm_has_permission(v_store_id, 'tinhluong.srm_review') THEN
        RAISE EXCEPTION 'Permission denied';
    END IF;

    SELECT * INTO v_row FROM public.payroll_srm_proposals
    WHERE id = p_proposal_id AND store_id = v_store_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Proposal not found';
    END IF;

    v_before := to_jsonb(v_row.*);

    -- Idempotent check cho việc retry cùng reviewer + cùng decision
    IF v_row.status != 'pending' THEN
        IF v_row.status = p_decision AND v_row.reviewer_user_id = v_actor THEN
            -- Retry successful, nhưng nếu là approved và points > 0 thì verify ledger phải đúng (bảo vệ ledger bị miss)
            IF p_decision = 'approved' AND v_row.proposed_points > 0 THEN
                IF NOT public.payroll_srm_verify_ledger(v_row.id, v_store_id, v_row.target_user_id, v_row.dimension, v_row.proposed_points) THEN
                    RAISE EXCEPTION 'Ledger verification failed for approved proposal retry';
                END IF;
            END IF;
            RETURN v_row;
        END IF;
        RAISE EXCEPTION 'Proposal is not pending (current status: %)', v_row.status;
    END IF;

    IF v_row.proposed_by_user_id = v_actor THEN
        RAISE EXCEPTION 'Cannot self-approve proposal';
    END IF;

    UPDATE public.payroll_srm_proposals
    SET status = p_decision, review_notes = p_notes, reviewer_user_id = v_actor, reviewed_at = NOW(), updated_at = NOW()
    WHERE id = p_proposal_id AND store_id = v_store_id
    RETURNING * INTO v_row;

    v_after := to_jsonb(v_row.*);

    -- Tạo point event nếu approved và points > 0
    IF p_decision = 'approved' AND v_row.proposed_points > 0 THEN
        INSERT INTO public.payroll_srm_point_events
        (proposal_id, store_id, target_user_id, dimension, points, created_by_user_id)
        VALUES (v_row.id, v_store_id, v_row.target_user_id, v_row.dimension, v_row.proposed_points, v_actor)
        ON CONFLICT (proposal_id) DO NOTHING;

        -- Xác minh ledger sau khi insert (tránh DO NOTHING rơi vào im lặng do data mismatch)
        IF NOT public.payroll_srm_verify_ledger(v_row.id, v_store_id, v_row.target_user_id, v_row.dimension, v_row.proposed_points) THEN
            RAISE EXCEPTION 'Point ledger verification failed after review insertion';
        END IF;
    END IF;

    INSERT INTO public.payroll_srm_audit_events
    (store_id, actor_user_id, entity_type, entity_id, action, before_data, after_data)
    VALUES (v_store_id, v_actor, 'proposal', v_row.id, 'REVIEW', v_before, v_after);

    RETURN v_row;
END;
$$;


-- 2.4 Huỷ đề xuất (Cancel)
CREATE OR REPLACE FUNCTION public.payroll_srm_cancel_proposal(
    p_proposal_id uuid
)
RETURNS public.payroll_srm_proposals
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'pg_catalog', 'public'
AS $$
DECLARE
    v_store_id uuid;
    v_actor uuid;
    v_row public.payroll_srm_proposals;
    v_before jsonb;
    v_after jsonb;
BEGIN
    v_store_id := public.current_store_id();
    v_actor := public.payroll_srm_current_user_id();

    IF v_store_id IS NULL OR v_actor = '00000000-0000-0000-0000-000000000000'::uuid THEN
        RAISE EXCEPTION 'Invalid store or user';
    END IF;

    -- Kiểm tra Membership của actor TRƯỚC khi SELECT, bảo vệ chống quét
    IF NOT EXISTS (SELECT 1 FROM public.store_members WHERE store_id = v_store_id AND user_id = v_actor) THEN
        RAISE EXCEPTION 'Actor is not a store member';
    END IF;

    SELECT * INTO v_row FROM public.payroll_srm_proposals
    WHERE id = p_proposal_id AND store_id = v_store_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Proposal not found';
    END IF;

    -- Kiểm tra proposed_by_user_id trước nhánh status = cancelled
    -- Điều này bảo vệ an toàn idempotent retry chỉ dành cho proposer thực sự.
    IF v_row.proposed_by_user_id != v_actor THEN
        RAISE EXCEPTION 'Proposal not found or permission denied';
    END IF;

    v_before := to_jsonb(v_row.*);

    IF v_row.status = 'cancelled' THEN
        RETURN v_row; -- Idempotent retry
    END IF;

    IF v_row.status != 'pending' THEN
        RAISE EXCEPTION 'Cannot cancel a proposal that is not pending';
    END IF;

    UPDATE public.payroll_srm_proposals
    SET status = 'cancelled', updated_at = NOW()
    WHERE id = p_proposal_id AND store_id = v_store_id
    RETURNING * INTO v_row;

    v_after := to_jsonb(v_row.*);

    INSERT INTO public.payroll_srm_audit_events
    (store_id, actor_user_id, entity_type, entity_id, action, before_data, after_data)
    VALUES (v_store_id, v_actor, 'proposal', v_row.id, 'CANCEL', v_before, v_after);

    RETURN v_row;
END;
$$;


-- ============================================================================
-- 3. PERMISSION BOUNDARIES
-- ============================================================================

-- 3.1 REVOKE/GRANT Table level
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.payroll_srm_settings FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.payroll_srm_proposals FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.payroll_srm_point_events FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.payroll_srm_audit_events FROM PUBLIC, anon, authenticated;

-- Chỉ có SELECT được giữ lại cho Client trực tiếp
GRANT SELECT ON public.payroll_srm_settings TO anon, authenticated;
GRANT SELECT ON public.payroll_srm_proposals TO anon, authenticated;
GRANT SELECT ON public.payroll_srm_point_events TO anon, authenticated;
GRANT SELECT ON public.payroll_srm_audit_events TO anon, authenticated;

-- 3.2 REVOKE/GRANT Function level
-- Tước quyền mặc định PUBLIC, anon, authenticated cho Helpers (chỉ dùng nội bộ)
REVOKE EXECUTE ON FUNCTION public.payroll_srm_current_user_id() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.payroll_srm_has_permission(uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.payroll_srm_verify_ledger(uuid, uuid, uuid, text, integer) FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.payroll_srm_update_settings(boolean, boolean, jsonb) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.payroll_srm_submit_proposal(uuid, text, text, text, text, jsonb, integer, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.payroll_srm_review_proposal(uuid, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.payroll_srm_cancel_proposal(uuid) FROM PUBLIC;

-- Cấp quyền chỉ cho Entrypoints (RPC gọi từ Client) tới anon/authenticated
GRANT EXECUTE ON FUNCTION public.payroll_srm_update_settings(boolean, boolean, jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.payroll_srm_submit_proposal(uuid, text, text, text, text, jsonb, integer, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.payroll_srm_review_proposal(uuid, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.payroll_srm_cancel_proposal(uuid) TO anon, authenticated;


-- ============================================================================
-- 4. PREFLIGHT / VERIFY
-- ============================================================================

-- Hiển thị thông tin Functions
SELECT p.proname, p.prosecdef, p.proconfig
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname LIKE 'payroll_srm_%';

-- Hiển thị Grants cho RPC
SELECT routine_name, grantee, privilege_type
FROM information_schema.routine_privileges
WHERE routine_schema = 'public'
  AND routine_name LIKE 'payroll_srm_%'
  AND grantee IN ('anon', 'authenticated');
