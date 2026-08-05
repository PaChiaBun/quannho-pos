# Checklist Xác Minh Môi Trường Staging & Kiểm Thử Runtime V3
File: `supabase/staging_verification_checklist.md`
Date: 2026-08-01

---

## 1. CHECKLIST HARD GATES CHỨNG MINH HẠ TẦNG STAGING ĐỘC LẬP

- [ ] **Native Healthchecks (HEALTHY):** Services có probe (`staging-db`, `staging-auth`, `staging-rest`, `staging-kong`) trả về trạng thái `HEALTHY`.
- [ ] **Application Probes (RUNNING & FUNCTIONAL):** Services không có native probe được xác minh qua container probe riêng trong cùng network:
  - [ ] **PgMeta:** `curl -sf http://staging-meta:8080/health` -> HTTP 200
  - [ ] **Studio:** `curl -sf http://staging-studio:3000/api/profile` -> HTTP 200
  - [ ] **Storage:** `curl -sf http://staging-storage:5000/status` -> HTTP 200
  - [ ] **Realtime:** `curl -sf http://staging-realtime:4000/api/health` -> HTTP 200
  - [ ] **Imgproxy:** `curl -sf http://staging-imgproxy:8080/health` -> HTTP 200
- [ ] **Kong Key-Auth Routing Functional:** Kong Gateway routing thành công các tuyến API. Request `/rest/v1/` thiếu header `apikey` bị từ chối 401 Unauthorized.
- [ ] **OAuth Public Callbacks Unauthenticated:** Các tuyến `/auth/v1/callback`, `/auth/v1/verify`, `/auth/v1/authorize` hoạt động bình thường không đòi apikey header.
- [ ] **Realtime WebSocket Functional:** Kết nối WebSocket thành công tới `wss://quannho-staging.lpm.vn/realtime/v1/websocket`.
- [ ] **Dedicated API Endpoint:** API Staging chạy tại ROOT `https://quannho-staging.lpm.vn/` (không trùng với API Production `quannho.lpm.vn/supabase/`).
- [ ] **JWT & Secret Isolation:** JWT Staging thất bại khi dùng trên Production và ngược lại.
- [ ] **Zero Secret Leak:** Git diff và log không chứa bất kỳ secret key hay password thật nào. Unresolved `${...}` placeholder count = 0 trong file `kong.staging.yml` runtime.

---

## 2. CHECKLIST CHỨNG MINH DATABASE ĐỘC LẬP (PORT MAPPING & ISOLATION PROOF)

- [ ] **Docker Compose Project Label:** Container mang label `com.docker.compose.project=quannho_staging`.
- [ ] **Mounted Volume Path:** Database mount đúng volume `quannho_staging_staging_db_data`.
- [ ] **Docker Network:** Container thuộc network `quannho_staging_default`.
- [ ] **Host Port Mapping:** Host port `5433` được map tới container port `5432` qua Docker (`127.0.0.1:5433->5432/tcp`).
- [ ] **Internal DB Queries:**
  - `SELECT current_database();` -> Trả về `postgres` (hoặc `postgres_staging`).
  - `SELECT inet_server_addr();` -> Trả về IP container nội bộ (`172.x.x.x`).
  - `SELECT inet_server_port();` -> Trả về port `5432` trong container.
- [ ] **Zero Production Store Leakage:** `SELECT COUNT(*) FROM stores WHERE store_code IN ('QN-S6YC', 'QN-4EJP')` trả về **chính xác 0**.
- [ ] **Zero Production Store UUIDs:** `SELECT COUNT(*) FROM public.stores WHERE id IN ('3b164035-0a7b-4086-843e-87ab44885076', '79fd45e9-14c3-4dd2-81ba-aa288a45b472')` trả về **chính xác 0**.
- [ ] **Zero Business Table Leakage:** `SELECT COUNT(*) FROM public.orders WHERE store_id IN ('3b164035-0a7b-4086-843e-87ab44885076', '79fd45e9-14c3-4dd2-81ba-aa288a45b472')` trả về **chính xác 0**.
- [ ] **Fake Data Only:** Duy nhất store `KAY STAGING TEST` (store_id `00000000-0000-0000-0000-000000000099`) tồn tại trên Staging.

---

## 3. CHECKLIST KIỂM THỬ MIGRATION V3 THÀNH CÔNG

- [ ] **Preflight PRE Mode PASS:** `SELECT public.verify_staging_preflight('PRE')` trả về status PASS.
- [ ] **5 Files Migration V3 Applied Cleanly:** Không có lỗi SQL syntax hay dependency crash.
- [ ] **Migration Idempotency PASS:** Chạy lại 5 file migration V3 lần 2 trên Staging không gây lỗi và không ghi đè metadata PRE-state.

---

## 4. CHECKLIST KIỂM THỬ KỊCH BẢN RUNTIME (RUNTIME TESTS)

- [ ] **Public QR Menu & Order:**
  - [ ] QR token sai bị từ chối.
  - [ ] Menu trả đúng món store test. Món inactive/hết hàng bị ẩn/chặn.
  - [ ] Topping sai link/store/hết hàng bị REJECT fail-closed.
  - [ ] Giá và tổng tiền được tính hoàn toàn phía server.
  - [ ] Idempotency key trùng trong cùng channel không tạo đơn lặp.
  - [ ] Idempotency key trùng ở 2 channel khác nhau hoạt động bình thường.
- [ ] **Bootstrap & POS Device Auth:**
  - [ ] PIN sai bị từ chối `INVALID_CREDENTIAL`.
  - [ ] Non-owner không bootstrap được.
  - [ ] Store owner bootstrap lần đầu thành công.
  - [ ] Bootstrap lần hai trả `ALREADY_BOOTSTRAPPED` (bền vững qua `pos_store_bootstrap_state`).
  - [ ] Pairing code hết hạn hoặc dùng lại bị từ chối. Client không tự phong role manager.
- [ ] **Workflow Nhân Viên & Gửi Bếp:**
  - [ ] Luồng chuyển trạng thái `pending_staff` -> `processing` -> `confirmed` -> `sent_kitchen` chính xác.
  - [ ] Nhánh `rejected` từ `pending_staff`/`processing` chính xác.
  - [ ] Claim đồng thời duy nhất 1 nhân viên thắng.
  - [ ] Table QR thiếu/sai/inactive table bị REJECT.
  - [ ] Counter QR tự động dùng đúng bàn Mang đi của store test.
  - [ ] `orders.total`, `order_items.unit_price`, `ban_sessions.total_amount`, `ban_session_items.subtotal`, `kitchen_tickets` đồng nhất tổng tiền.

---

## 5. CHECKLIST KIỂM THỬ ROLLBACK & FORWARD MIGRATION

- [ ] **Rollback Execution PASS:** `rollback_qr_architecture_v3.sql` chạy thành công trong transaction block `BEGIN; ... COMMIT;`.
- [ ] **Metadata Preflight Protection:** Dừng ngay bằng `RAISE EXCEPTION` nếu thiếu metadata.
- [ ] **Index V2 Restored:** Khôi phục đúng index V2 `idx_qr_requests_idempotency_unique`.
- [ ] **Object Ownership Preserved:** Xóa đúng các cột/bảng/index V3 có `existed_before = false`, giữ nguyên các đối tượng có sẵn.
- [ ] **Forward-after-rollback PASS:** Apply lại Migration V3 thành công lần 2 chứng minh khả năng khôi phục forward/rollback 100%.
