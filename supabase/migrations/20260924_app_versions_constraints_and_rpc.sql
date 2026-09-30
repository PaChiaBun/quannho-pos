-- =============================================================================
-- Migration: 20260924_app_versions_constraints_and_rpc.sql
-- Mục tiêu:
-- 1. Bổ sung ràng buộc UNIQUE (platform, build_number) trên bảng app_versions
--    ngăn chặn trùng lặp bản dựng khi phát hành tự động.
-- 2. Tạo RPC public.get_latest_app_version_v1(p_platform text) trả về các cột của bảng.
-- 3. Tạo RPC public.publish_app_version_v1(...) với SECURITY DEFINER hỗ trợ upsert bản phát hành.
-- 4. Phân quyền EXECUTE phù hợp cho các vai trò Supabase (anon, authenticated, service_role).
-- 5. Seed dữ liệu ban đầu cho bản phát hành hiện tại (1.0.2+7).
-- =============================================================================

BEGIN;

-- 1. Làm sạch dữ liệu trùng lặp nếu có trước khi thêm constraint (giữ lại bản ghi mới nhất)
DELETE FROM public.app_versions a
USING public.app_versions b
WHERE a.platform = b.platform
  AND a.build_number = b.build_number
  AND a.created_at < b.created_at;

-- 2. Bổ sung ràng buộc Unique (platform, build_number)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'uq_app_versions_platform_build'
    ) THEN
        ALTER TABLE public.app_versions
            ADD CONSTRAINT uq_app_versions_platform_build UNIQUE (platform, build_number);
    END IF;
END $$;

-- 3. RPC: Lấy phiên bản mới nhất cho từng platform (Public) trả về các cột của bảng
CREATE OR REPLACE FUNCTION public.get_latest_app_version_v1(
    p_platform text
)
RETURNS TABLE (
    id uuid,
    platform text,
    version_name text,
    build_number integer,
    download_url text,
    changelog text,
    is_force_update boolean,
    created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $$
    SELECT 
        av.id,
        av.platform,
        av.version_name,
        av.build_number,
        av.download_url,
        av.changelog,
        av.is_force_update,
        av.created_at
    FROM public.app_versions av
    WHERE (
        p_platform IS NULL 
        OR trim(p_platform) = '' 
        OR av.platform = lower(trim(p_platform))
    )
    ORDER BY av.build_number DESC
    LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.get_latest_app_version_v1(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_latest_app_version_v1(text) TO anon, authenticated, service_role;

-- 4. RPC: Xuất bản hoặc cập nhật phiên bản mới an toàn (Chỉ service_role)
CREATE OR REPLACE FUNCTION public.publish_app_version_v1(
    p_platform text,
    p_version_name text,
    p_build_number integer,
    p_download_url text,
    p_changelog text DEFAULT '',
    p_is_force_update boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $$
DECLARE
    v_record public.app_versions%ROWTYPE;
BEGIN
    IF p_platform IS NULL OR trim(p_platform) = '' THEN
        RAISE EXCEPTION 'INVALID_ARGUMENT: platform is required' USING ERRCODE = '22023';
    END IF;

    IF lower(trim(p_platform)) NOT IN ('android', 'ios', 'macos', 'windows') THEN
        RAISE EXCEPTION 'INVALID_ARGUMENT: invalid platform %', p_platform USING ERRCODE = '22023';
    END IF;

    IF p_version_name IS NULL OR trim(p_version_name) = '' THEN
        RAISE EXCEPTION 'INVALID_ARGUMENT: version_name is required' USING ERRCODE = '22023';
    END IF;

    IF p_build_number IS NULL OR p_build_number <= 0 THEN
        RAISE EXCEPTION 'INVALID_ARGUMENT: build_number must be positive' USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.app_versions (
        platform,
        version_name,
        build_number,
        download_url,
        changelog,
        is_force_update,
        created_at
    )
    VALUES (
        lower(trim(p_platform)),
        trim(p_version_name),
        p_build_number,
        NULLIF(trim(p_download_url), ''),
        COALESCE(trim(p_changelog), ''),
        COALESCE(p_is_force_update, false),
        NOW()
    )
    ON CONFLICT (platform, build_number) DO UPDATE
    SET version_name = EXCLUDED.version_name,
        download_url = EXCLUDED.download_url,
        changelog = EXCLUDED.changelog,
        is_force_update = EXCLUDED.is_force_update,
        created_at = NOW()
    RETURNING * INTO v_record;

    RETURN jsonb_build_object(
        'success', true,
        'id', v_record.id,
        'platform', v_record.platform,
        'version_name', v_record.version_name,
        'build_number', v_record.build_number,
        'download_url', v_record.download_url,
        'changelog', v_record.changelog,
        'is_force_update', v_record.is_force_update,
        'created_at', v_record.created_at
    );
END;
$$;

REVOKE ALL ON FUNCTION public.publish_app_version_v1(text, text, integer, text, text, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.publish_app_version_v1(text, text, integer, text, text, boolean) TO service_role;

-- 5. Nạp phiên bản chuẩn v1.0.2+7 cho các nền tảng chính thức
INSERT INTO public.app_versions (platform, version_name, build_number, download_url, changelog, is_force_update)
VALUES 
    ('android', '1.0.2', 7, 'https://quannho.lpm.vn/download/QuanNhoPOS-latest.apk', 'Cập nhật hệ thống tự động tải và cài đặt APK đè không gián đoạn.', false),
    ('windows', '1.0.2', 7, 'https://quannho.lpm.vn/download/QuanNhoPOS-latest.exe', 'Bản cài đặt Windows POS tự động cập nhật, bảo toàn dữ liệu bán hàng.', false),
    ('ios', '1.0.2', 7, 'https://apps.apple.com/app/id6795376140', 'Cải tiến hiệu năng và độ ổn định trên App Store.', false),
    ('macos', '1.0.2', 7, 'https://quannho.lpm.vn/download/QuanNhoPOS-latest-macOS.zip', 'Phiên bản dành cho máy Mac.', false)
ON CONFLICT (platform, build_number) DO UPDATE
SET version_name = EXCLUDED.version_name,
    download_url = EXCLUDED.download_url,
    changelog = EXCLUDED.changelog,
    is_force_update = EXCLUDED.is_force_update;

COMMIT;

NOTIFY pgrst, 'reload schema';
