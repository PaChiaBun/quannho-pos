# QUY TRÌNH STAGING QR GỌI MÓN — QUÁN NHỎ POS & WEBSITE KAY

> [!CAUTION]
> **QUY TẮC AN TOÀN TUYỆT ĐỐI**
> - KHÔNG thực thi bất kỳ lệnh SQL nào trên Supabase Production.
> - KHÔNG deploy `kay.lpm.vn` hoặc ứng dụng Production.
> - XÁC MINH NGOẠI GIAO: Operator phải kiểm tra trực tiếp URL/Project Ref trên Supabase Dashboard, đảm bảo không trùng với `quannho.lpm.vn/supabase` hoặc database Production trước khi thao tác!

---

## ⚠️ CẢNH BÁO FILE MIGRATION CỦ (LEGACY WARNING)

> [!WARNING]
> File migration `supabase/migration_kay_public_ordering_v2.sql` là **LEGACY / UNSAFE FOR ARCHITECTURE V3 — DO NOT EXECUTE**. File này dùng `auth.uid()` và chữ ký RPC cũ không tương thích với Custom Auth. Tuyệt đối không thực thi hoặc sửa chồng lên file cũ này.

---

## 📋 THỨ TỰ 11 BƯỚC TRIỂN KHAI VÀ PREFLIGHT STAGING

### BƯỚC 1: XÁC MINH STAGING & KHỞI TẠO ENVIRONMENT GUARD MARKER
1. Đăng nhập Supabase SQL Editor của **Dự Án Staging Riêng**.
2. Kiểm tra thủ công URL/Project Ref và ghi lại URL đã kiểm tra vào `staging_qr_qc_report.md`.
3. Tạo Marker Bảo Vệ Môi Trường (Database marker KHÔNG THỂ tự chứng minh URL; đây là lớp bảo vệ bổ sung):
   ```sql
   CREATE TABLE IF NOT EXISTS environment_guard (
     environment        text PRIMARY KEY,
     project_identifier text NOT NULL,
     created_at         timestamptz DEFAULT now()
   );
   INSERT INTO environment_guard (environment, project_identifier) 
   VALUES ('staging', 'qn_staging_project_v1') 
   ON CONFLICT (environment) DO NOTHING;
   ```

---

### BƯỚC 2: AUDIT DEPENDENCY & TẠO SCHEMA-ONLY MANIFEST TỪ SCHEMA ĐÃ XÁC NHẬN
- Lập manifest schema-only từ cấu trúc đã xác nhận.
- Kiểm tra trùng bảng, cột, policy và function giữa các SQL legacy.
- Manifest phải được QC và phê duyệt trước khi chạy.
- **Không được coi `schema.sql + migration_full.sql` là một chuỗi an toàn khi chưa audit dependency.**

---

### BƯỚC 3: CÀI ĐẶT PREFLIGHT FUNCTION VÀ CHẠY PRE-MODE
1. Chạy DDL file `supabase/staging_schema_preflight_pos_qr.sql` để tạo hàm:
   `public.verify_staging_preflight(p_mode text)` *(Sử dụng `SECURITY INVOKER` và `REVOKE ALL FROM PUBLIC, anon, authenticated`)*.
2. Chạy kiểm tra PRE mode:
   ```sql
   SELECT public.verify_staging_preflight('PRE');
   ```
3. **Kết quả mong đợi:** Xuất ra `[PREFLIGHT PASSED: PRE MODE]`.

---

### BƯỚC 4: LƯU TRỮ OUTPUT LOG CHẠY PRE PREFLIGHT
Lưu lại toàn bộ log output của lệnh `SELECT public.verify_staging_preflight('PRE');` làm bằng chứng nghiệm thu trong `staging_qr_qc_report.md`. Chỉ khi PRE thành công 100% mới được tiến hành Bước 5.

---

### BƯỚC 5: THỰC THI MIGRATIONS MỚI DỰ KIẾN (SAU KHUYẾN NGHỊ & PHÊ DUYỆT)
> [!IMPORTANT]
> Chỉ được thực thi khi tài liệu được phê duyệt, migration thật được tạo, static SQL QC đạt, Staging URL được xác nhận và PRE preflight đạt.

Danh sách các file migration dự kiến:
- `PLANNED_NOT_CREATED: 20260731_create_pos_device_sessions.sql` — DO NOT EXECUTE
- `PLANNED_NOT_CREATED: 20260731_create_qr_public_rpc_v3.sql` — DO NOT EXECUTE
- `PLANNED_NOT_CREATED: 20260731_create_qr_staff_rpc_v3.sql` — DO NOT EXECUTE
- `PLANNED_NOT_CREATED: 20260731_qr_permissions_v3.sql` — DO NOT EXECUTE
- `PLANNED_NOT_CREATED: 20260731_qr_audit_and_constraints_v3.sql` — DO NOT EXECUTE
- `PLANNED_NOT_CREATED: rollback_qr_architecture_v3.sql` — DO NOT EXECUTE

---

### BƯỚC 6: POST PREFLIGHT — HIỆN ĐANG KHÓA
- POST không được phép chạy ở giai đoạn hiện tại.
- Architecture v3 migrations đang ở trạng thái `PLANNED_NOT_CREATED`.
- Lệnh sau hiện phải trả lỗi an toàn:
  ```sql
  SELECT public.verify_staging_preflight('POST');
  ```
- **Kết quả bắt buộc hiện tại:** `POST PREFLIGHT DISABLED`.
- **Không được ghi hoặc mong đợi POST PASSED.**
- Chỉ mở POST sau khi toàn bộ migration v3 được tạo, static SQL QC đạt và chủ dự án phê duyệt.

---

### BƯỚC 7: KÍCH HOẠT POST SAU KHI ĐƯỢC PHÊ DUYỆT
Sau khi migrations v3 được tạo và phê duyệt:
1. Cập nhật POST expectations theo schema thật.
2. Kiểm tra lại toàn bộ chữ ký RPC bằng `to_regprocedure`.
3. Kiểm tra quyền database, constraints, token hash và audit.
4. QC lại file preflight.
5. Chạy POST chỉ trên Supabase Staging.
6. Lưu toàn bộ output vào `staging_qr_qc_report.md`.

---

### BƯỚC 8: SEED DỮ LIỆU TEST MẪU (`staging_seed_test_data.sql`)
Chạy script `supabase/staging_seed_test_data.sql` tạo dữ liệu cho store `KAY-STAGING-TEST`:
- 2 Khu Vực (`KHU-A`, `KHU-B`).
- 2 Bàn: Bàn **T1-01** và Bàn **T2-01**.
- 1 QR Bàn (Bàn T1-01), 1 QR Quầy (`#Q01`).

---

### BƯỚC 9: THỰC THI THỬ NGHIỆM PHÂN QUYỀN VÀ CÁCH LY CỬA HÀNG (SECURITY & CROSS-STORE TESTS)
1. Kiểm thử phân quyền action `qr_order.*` với từng vai trò nhân viên qua RPCs.
2. Dùng Token POS thuộc Store A để gọi RPC yêu cầu dữ liệu Store B $\rightarrow$ Hệ thống phản hồi lỗi từ chối truy cập.

---

### BƯỚC 10: THỰC THI THỬ NGHIỆM ĐỒNG THỜI VÀ IDEMPOTENCY (CONCURRENCY & IDEMPOTENCY TESTS)
1. Gửi trùng `idempotency_key` 2 lần liên tiếp $\rightarrow$ RPC trả lại kết quả đã xử lý, không tạo 2 đơn trùng.
2. 2 thiết bị cùng claim 1 đơn pending $\rightarrow$ Chỉ 1 thiết bị claim thành công (`processing`), thiết bị còn lại nhận thông báo lỗi.

---

### BƯỚC 11: CLEANUP DỮ LIỆU TEST & THỰC THI TEST ROLLBACK
1. Chạy `supabase/staging_cleanup_test_data.sql` để xóa sạch dữ liệu test.
2. Thực thi script rollback `rollback_qr_architecture_v3.sql` (khi đã được tạo) để kiểm chứng rollback.
3. Ghi tổng hợp toàn bộ kết quả nghiệm thu vào `staging_qr_qc_report.md`.
