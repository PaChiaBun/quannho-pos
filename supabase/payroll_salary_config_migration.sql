-- Quán Nhỏ POS — Cấu hình lương theo nhân viên
-- Additive, forward-only, rerunnable.

CREATE TABLE IF NOT EXISTS public.staff_salary_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.user_accounts(id) ON DELETE CASCADE,
    staff_name TEXT NOT NULL DEFAULT '',
    role TEXT NOT NULL DEFAULT '',
    salary_mode TEXT NOT NULL DEFAULT 'M1',
    base_salary NUMERIC NOT NULL DEFAULT 0 CHECK (base_salary >= 0),
    hourly_rate NUMERIC NOT NULL DEFAULT 0 CHECK (hourly_rate >= 0),
    daily_rate NUMERIC NOT NULL DEFAULT 0 CHECK (daily_rate >= 0),
    expected_days INTEGER NOT NULL DEFAULT 26
        CHECK (expected_days BETWEEN 1 AND 31),
    deduction_per_late NUMERIC NOT NULL DEFAULT 50000
        CHECK (deduction_per_late >= 0),
    ot_threshold_hours NUMERIC NOT NULL DEFAULT 8
        CHECK (ot_threshold_hours > 0 AND ot_threshold_hours <= 24),
    ot_multiplier NUMERIC NOT NULL DEFAULT 1.5
        CHECK (ot_multiplier >= 1 AND ot_multiplier <= 10),
    fixed_bonus NUMERIC NOT NULL DEFAULT 0 CHECK (fixed_bonus >= 0),
    attendance_bonus NUMERIC NOT NULL DEFAULT 0
        CHECK (attendance_bonus >= 0),
    fixed_allowance NUMERIC NOT NULL DEFAULT 0
        CHECK (fixed_allowance >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_staff_salary_configs_store_user UNIQUE (store_id, user_id)
);

ALTER TABLE public.staff_salary_configs
    ADD COLUMN IF NOT EXISTS fixed_bonus NUMERIC NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS attendance_bonus NUMERIC NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS fixed_allowance NUMERIC NOT NULL DEFAULT 0;

-- Nâng constraint ở những môi trường đã có bảng để nhận chế độ M5 (Tùy chỉnh).
DO $$
DECLARE
    constraint_name TEXT;
BEGIN
    FOR constraint_name IN
        SELECT con.conname
        FROM pg_constraint con
        JOIN pg_class rel ON rel.oid = con.conrelid
        JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
        WHERE nsp.nspname = 'public'
          AND rel.relname = 'staff_salary_configs'
          AND con.contype = 'c'
          AND pg_get_constraintdef(con.oid) ILIKE '%salary_mode%'
    LOOP
        EXECUTE format(
            'ALTER TABLE public.staff_salary_configs DROP CONSTRAINT IF EXISTS %I',
            constraint_name
        );
    END LOOP;
END $$;

ALTER TABLE public.staff_salary_configs
    ADD CONSTRAINT chk_staff_salary_configs_mode
    CHECK (salary_mode IN ('M1', 'M2', 'M3', 'M4', 'M5'));

CREATE INDEX IF NOT EXISTS idx_staff_salary_configs_store
    ON public.staff_salary_configs(store_id);

ALTER TABLE public.staff_salary_configs ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "salary_configs_store_select"
    ON public.staff_salary_configs
    FOR SELECT
    USING (store_id = public.current_store_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "salary_configs_store_insert"
    ON public.staff_salary_configs
    FOR INSERT
    WITH CHECK (store_id = public.current_store_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "salary_configs_store_update"
    ON public.staff_salary_configs
    FOR UPDATE
    USING (store_id = public.current_store_id())
    WITH CHECK (store_id = public.current_store_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Chỉ cấp đúng quyền ứng dụng cần. TRUNCATE không chịu tác động của RLS,
-- vì vậy phải thu hồi rõ ràng các quyền từng được GRANT ALL ở schema cũ.
REVOKE DELETE, TRUNCATE, REFERENCES, TRIGGER
    ON public.staff_salary_configs FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.staff_salary_configs
    TO anon, authenticated;

SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'staff_salary_configs'
ORDER BY ordinal_position;
