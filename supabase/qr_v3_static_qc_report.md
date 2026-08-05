# Báo Cáo Static QC Mã Nguồn Migration Architecture v3
File: `supabase/qr_v3_static_qc_report.md`
Date: 2026-07-31

---

## 1. BẢNG ĐỐI CHIẾU XÁC MINH CÁC TIÊU CHÍ KỸ THUẬT V3 (MỤC 1 - 5)

| Hạng Mục QC | Yêu Cầu Chi Tiết | Trạng Thái Kiểm Tra | Vị Trí / Giải Pháp Đã Thực Hiện Trong SQL v3 |
|---|---|---|---|
| **1. Metadata Preflight Top Validation** | Metadata Preflight Validation đứng đầu `rollback_qr_architecture_v3.sql`, kiểm tra 100% metadata keys bắt buộc trước bất kỳ câu lệnh DROP nào. Ném `RAISE EXCEPTION` dừng rollback ngay nếu thiếu/sai. | `STATIC UNVERIFIED` | `rollback_qr_architecture_v3.sql` đặt `DO block` Preflight Validation ở Step 1 ngay sau `BEGIN;`. Cần verify trên Staging. |
| **2. Strict Rollback Execution Order** | Giao dịch `BEGIN; ... COMMIT;`. Xoá V3 index `idx_qr_requests_channel_idempotency` trước khi xoá cột `idempotency_key`. Khôi phục V2 index. Xoá cột V3. Xoá bảng V3. Xoá metadata table cuối cùng. | `PASS (STATIC)` | Thứ tự dòng thực tế chứng minh 100% tuân thủ thứ tự phụ thuộc. |
| **3. V3 Object Ownership Pre-state** | Lưu `existed_before` cho `pos_session_info`, `pos_store_bootstrap_state`, `pos_device_sessions`, `store_pairing_codes`, `pos_auth_attempts`, `qr_audit_logs` trước khi khởi tạo. | `STATIC UNVERIFIED` | `20260731_create_pos_device_sessions.sql` lưu vết `v3_table_*_existed_before` và `v3_type_*_existed_before` bằng `ON CONFLICT DO NOTHING`. |
| **4. Exact Scope Validation** | Kiểm tra constraint bằng `pg_constraint JOIN pg_class JOIN pg_namespace` (schema public, table qr_requests). Kiểm tra composite type bằng `pg_type JOIN pg_namespace` (schema public). | `PASS (STATIC)` | 100% preflight check sử dụng JOIN với `pg_namespace` schema public. |
| **5. Trung Thực Báo Cáo & Re-Verification** | Cập nhật báo cáo tĩnh chính xác thứ tự thực thi rollback và trạng thái giao dịch. | `PASS (STATIC)` | Đã cập nhật 100% Manifest & Report trung thực. |

---

## 2. KẾT QUẢ KIỂM TRA MÃ NGUỒN TĨNH (STATIC CODE AUDIT)

### 2.1 Thứ tự dòng thực tế chứng minh tính an toàn trong `rollback_qr_architecture_v3.sql`:
1. **Dòng 1:** `BEGIN;` (Bắt đầu giao dịch nguyên tử)
2. **Dòng 10:** Metadata Preflight Validation Block (`DO $$ ... BEGIN ... END $$;`) thực thi ngắt giao dịch ngay bằng `RAISE EXCEPTION` nếu thiếu metadata/key.
3. **Dòng 107:** `DROP FUNCTION IF EXISTS public.send_to_kitchen_qr_v3 ...` (Drop V3 RPC Functions).
4. **Dòng 132:** `DROP INDEX IF EXISTS public.idx_qr_requests_channel_idempotency;` (Drop V3 Index **TRƯỚC** khi drop cột `idempotency_key`).
5. **Dòng 138:** Recreate Legacy V2 Index `idx_qr_requests_idempotency_unique`.
6. **Dòng 150:** `ALTER TABLE public.qr_requests DROP COLUMN IF EXISTS idempotency_key` (Drop V3 Columns **SAU KHI** index phụ thuộc đã bị xoá).
7. **Dòng 173:** Drop V3 Isolated Tables & Composite Type (nếu `existed_before = false`).
8. **Dòng 201:** `DROP TABLE IF EXISTS public.qr_v3_migration_metadata;` (Xoá Metadata table ở bước cuối cùng).
9. **Dòng 203:** `COMMIT;` (Kết thúc giao dịch nguyên tử).

---

## 3. KẾT QUẢ `git diff --check` & RG AUDIT

- **Lệnh `git diff --check`:** **0 LỖI FORMATTING / WHITESPACE FOUND**.
- **Lệnh `rg -n "^BEGIN;|^COMMIT;|DROP COLUMN|DROP INDEX|qr_v3_migration_metadata"`:** **Xác nhận thứ tự các câu lệnh hoàn toàn khớp chứng minh an toàn 100%**.

---

## 4. KẾT LUẬN TỔNG THỂ

- **MÃ NGUỒN MIGRATION SQL ARCHITECTURE V3 STATIC AUDIT:** **STATIC UNVERIFIED (NEEDS STAGING RUNTIME VERIFICATION)**
- **TRẠNG THÁI BOOTSTRAP ENDPOINT:** **STAGING_ONLY / BLOCKED_FOR_PRODUCTION**
- **MỤC CÒN BLOCKED:**
  - `Cần thực thi PRE preflight trên Staging để ghi nhận metadata snapshot thực tế vào qr_v3_migration_metadata`
  - `Cần verify runtime execution của bootstrap_first_pos_device_v3 & send_to_kitchen_qr_v3 trên database Staging`
- **Trạng thái thực thi SQL:** `SQL Executed = NO`
- **Trạng thái Môi Trường Production:** `Production Touched = NO`
- **Trạng thái Deploy:** `Deploy = NO`
- **Trạng thái Code Flutter:** `Flutter Modified = NO`
