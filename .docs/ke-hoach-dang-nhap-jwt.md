# Kế hoạch: chỉ tin danh tính đã ký (JWT), tắt header tự khai `x-user-id`

> Ngày khảo sát: 22/10/2026. **Chỉ đọc** production (truy vấn trong giao dịch `read only`), không áp gì, không commit.
> Tài liệu này dành cho Chủ Quán và các phiên làm việc sau. Mọi bước ghi production đều phải hỏi Chủ Quán trước.

---

## 0. Tóm tắt nhanh (đọc phần này là đủ để quyết định)

1. **Tiền đề cần sửa lại:** app **đã có** đăng nhập bằng JWT từ trước (từ 10–13/10/2026). Máy chủ gateway `services/pos_jwt_auth_service.py` (cổng `/api/auth/pos-jwt`, `/refresh`, …) ký JWT sau khi kiểm SĐT + mật khẩu, và bản release trên mọi nền tảng đều dùng nó (`lib/core/services/pos_jwt_auth_service.dart`). Hiện có **64 refresh token còn sống, 36 người, 22 quán**; bảng `anon_write_audit` (ghi nhận mọi lần ghi bằng vai `anon` trên 49 bảng) **không có dòng nào từ 14/10 23:00 UTC**. Nghĩa là: app bình thường hầu như đã chạy bằng JWT.
2. **Lỗ hổng thật nằm ở máy chủ:** máy chủ **vẫn chấp nhận đường cũ** "khóa công khai (anon key) + header `x-user-id` tự khai". Ai có anon key (nằm sẵn trong app/web) và biết UUID của chủ quán là giả danh được — qua RLS của 58 bảng anon có quyền ghi, và qua các RPC "chỉ Chủ/Quản lý" vừa khóa hôm nay (nạp ví, xóa thu chi, duyệt/trả lương…).
3. **Việc cần làm không phải "xây đăng nhập JWT" mà là "đóng cửa sau":** đo xem còn máy nào dùng đường cũ → app mới bỏ hẳn `x-user-id` → tắt đường cũ **từng quán** bằng một công tắc trên máy chủ → dọn dẹp quyền `anon`.
4. **Khuyến nghị:** giữ gateway JWT hiện có (không chuyển sang Supabase Auth hay Edge Function). Lý do ở mục 4.
5. **Có 3 lỗ khẩn, sửa được ngay, độc lập với lộ trình** (mục 3.4): `publish_app_version_v1` cho **anon** đăng bản cập nhật giả (kèm link tải tùy ý, có thể ép cập nhật); `lookup_staff_by_phone` cho anon tra UUID nhân viên + UUID quán từ số điện thoại (chính là "chìa khóa" để giả danh); `revoke_store_member` chỉ tin header nên **cả người đã đăng nhập JWT** cũng giả được chủ quán để xóa nhân viên.
6. Ước lượng: Pha 0 (vá khẩn) ~½ ngày; đo đạc ~½ ngày + **quan sát ≥ 7 ngày**; bản app mới ~1,5–2 ngày + thời gian duyệt store; tắt đường cũ ~1 ngày; dọn dẹp 1–2 ngày rải rác. Tổng thời gian lịch: **khoảng 3–4 tuần**, phụ thuộc tốc độ các máy cập nhật app.

---

## 1. Thuật ngữ (giải thích ngắn)

| Thuật ngữ | Nghĩa trong dự án này |
|---|---|
| **JWT** (JSON Web Token) | "Thẻ ra vào" điện tử do máy chủ ký bằng khóa bí mật. Trong thẻ ghi: ai (`sub` = id người dùng), quán nào (`store_id`), hết hạn lúc nào (`exp`). Máy khách không sửa được nội dung vì sẽ sai chữ ký. |
| **Header tự khai** (`x-user-id`, `x-store-id`) | Dòng thông tin app tự gắn vào mỗi yêu cầu. Ai cũng gõ được giá trị bất kỳ → **không phải bằng chứng danh tính**. |
| **anon key** | Khóa công khai của Supabase, nằm sẵn trong app/web. Dùng nó thì yêu cầu chạy với vai `anon` (khách vãng lai). |
| **Vai `anon` / `authenticated`** | Hai "vai" trong PostgreSQL. `anon` = chưa đăng nhập; `authenticated` = có JWT hợp lệ. |
| **RLS** (Row Level Security) | Luật trong database quyết định mỗi người thấy/sửa được dòng nào. Ở đây luật dựa vào `current_store_id()` và `qn_caller_id()`. |
| **RPC** | Hàm trong database mà app gọi qua API (ví dụ `topup_customer_wallet_v1`). |
| **`SECURITY DEFINER`** | Hàm chạy với quyền của người tạo hàm (quyền cao), bỏ qua RLS → bên trong hàm phải tự kiểm tra người gọi. |
| **Gateway** | Dịch vụ Python `services/pos_gateway_server.py` trên VPS, nhận SĐT + mật khẩu và trả JWT. |
| **Access token / refresh token** | Access token = JWT dùng để gọi API (hiện sống 30 ngày). Refresh token = vé dài hạn để xin access token mới mà không phải nhập mật khẩu; chỉ lưu bản băm trên máy chủ (`pos_refresh_tokens`). |
| **Fallback header** | Nhánh "dự phòng" trong hàm máy chủ: nếu không có JWT thì đọc `x-user-id`. Đây chính là cửa sau cần đóng. |
| **pre-request hook** | Hàm PostgREST (`db-pre-request`) chạy **trước mọi yêu cầu API**. Dùng để đo đạc và để chặn yêu cầu kiểu cũ ở một chỗ duy nhất. |
| **Bản sao (stage)** | Database tạm tạo bằng `pg_dump` từ production (chỉ đọc production), áp thử migration rồi xóa. Script mẫu: `db-fix/chuoi_stage_dryrun.sh`. |

---

## 2. Hiện trạng đã xác minh

### 2.1 Các luồng đăng nhập

| Luồng | Cách làm hiện tại | Danh tính máy chủ nhận được | Ghi chú |
|---|---|---|---|
| **Chủ quán / nhân viên đăng nhập** (cùng một cách: SĐT + mật khẩu trong `user_accounts`) | `UserAuthService.login` (`lib/core/services/user_auth_service.dart:440`) → RPC `verify_user_login_v4` → nếu có đúng 1 quán: gateway `/api/auth/pos-jwt` cấp JWT + refresh token (`pos_jwt_auth_service.py:267`). Thất bại thì **báo lỗi, không lùi về anon** (dòng ~586–606). | JWT (`sub`, `store_id`, `staff_role`) | Bản release luôn trỏ `https://quannho.lpm.vn` (`_resolveBackendUrl`), kể cả khi build quên `--dart-define`. |
| **Tài khoản chưa có quán / nhiều quán** | Gateway `/api/auth/onboarding-jwt` cấp JWT "tạm" 10 phút không có `store_id` → chọn quán → `/api/auth/exchange-store-jwt` đổi sang JWT của quán (`selectStore`, dòng 1101). | JWT | Tạo quán mới: `create_store_with_owner_v4` (dùng `auth.uid()`). |
| **Mở lại app** | `restoreSessionOnStartup` (dòng 1347): dùng JWT đã lưu → nếu hết hạn thì refresh → **mất mạng mà còn refresh token thì vẫn vào app** (dòng ~1422). | JWT; **riêng trường hợp mất mạng lúc mở app: chạy anon + header** cho tới khi bộ hẹn giờ refresh thành công | Đây là một chỗ app mới phải sửa trước khi tắt header (mục 5, Pha 2). |
| **Đăng xuất** | `applyAuthToSupabase(null)` → quay về anon key; log `[Auth] REST/Realtime dung anon key`. | anon | 10 lần log "anon" trong 3 ngày khớp 10 lần "Dang xuat" → các log anon trong `app_logs` chủ yếu là lúc đăng xuất, không phải máy chạy anon. |
| **PIN quản lý** (duyệt hủy món, giảm món ở Bàn) | `_verifyManagerApproval` (`lib/screens/ban_screen.dart:4806`) → RPC `verify_manager_quick_pin_v4`: chỉ dùng `auth.uid()`, PIN 6 số so với `user_accounts.quick_pin` (bcrypt), giới hạn 5 lần sai / 5 phút. | JWT (anon bị từ chối) | **Không** có đăng nhập bằng PIN của `staff_members` trong app hiện tại; cột `staff_members.pin_hash` là di sản và vẫn đọc được bởi mọi thành viên quán (đã ghi ở nhật ký 22/10). |
| **Tài khoản demo cho Apple/Google duyệt** | Chỉ khi build với `ENABLE_REVIEWER_ACCOUNT=true`: tạo phiên cục bộ cho quán demo `…9999`, **không có JWT** → chạy anon + header. | header | Thiết bị "Quán Nhỏ POS (Demo)" có log anon ngày 18/10. Tắt header sẽ làm hỏng tài khoản demo → phải cho nó JWT thật (Pha 2). |
| **Khách quét QR gọi món** | Web QR gọi gateway `/api/auth/qr-ticket` (vé HMAC 5 phút + Turnstile chống bot) rồi các RPC anon `get_qr_menu_v4`, `submit_qr_order_v4`, `get_qr_request_status_v4`, `get_qr_channel_info_v4`. | Không cần danh tính người (danh tính = mã kênh QR + vé) | **Giữ nguyên.** Không gửi `x-user-id` nên không bị ảnh hưởng khi tắt header. |
| **Kiểm tra bản cập nhật** | `get_latest_app_version_v1` (anon) và gateway `GET /api/versions`. | Không cần | Giữ anon. |

### 2.2 Những chỗ máy chủ đọc header (xác minh trên production)

Truy vấn mọi hàm `public` có chữ `x-user-id` / `x-store-id` / `request.headers`:

| Hàm | Đọc gì | Mức tin cậy hiện tại |
|---|---|---|
| `qn_caller_id()` | Có JWT `authenticated` → lấy `sub`. **Không có JWT → lấy header `x-user-id`.** | JWT: an toàn. anon: giả được. |
| `current_store_id()` | Ưu tiên header `x-store-id`, không có thì `store_id` trong JWT; sau đó **kiểm người gọi (`qn_caller_id`) có phải thành viên quán đó**. | Với JWT: an toàn (header chỉ chọn quán, thành viên được kiểm bằng `sub` đã ký). Với anon: người gọi lấy từ header → giả được. **⇒ `x-store-id` có thể giữ lại; chỉ `x-user-id` là vấn đề.** |
| `verify_staff_qr_membership_v4()` | `auth.uid()` → `request.jwt.claim.sub` → `request.jwt.claims.sub` → **header `x-user-id`** → **GUC kiểu cũ `request.header.x-user-id`** (PostgREST đang bật `PGRST_DB_USE_LEGACY_GUCS`). | Như trên. Cả 2 nhánh header phải bỏ. |
| `revoke_store_member()` | **Chỉ** đọc header `x-user-id`, không nhìn JWT. Quyền gọi: `authenticated` (anon không gọi được). | **Lỗ ngay cả với JWT**: nhân viên đã đăng nhập gửi kèm `x-user-id` = id chủ quán là xóa được nhân viên khác. App hiện **không gọi** hàm này (grep `lib/` không thấy). |
| `qn_anon_write_audit()` | Chỉ ghi nhận có/không có header (trigger quan sát). | Không phải kiểm tra danh tính. |
| `qn_log_module_config()` | Ghi log lịch sử module, dùng `qn_caller_id()` + thông tin client. | Ghi log, không cấp quyền. |
| `qr_client_ip_hash_v4()` | Đọc header IP để chống phá QR. | Không phải danh tính người dùng. |

**Các chốt "chỉ Chủ quán/Quản lý" dựa trên các hàm trên** (gián tiếp tin header khi gọi bằng anon):

- Qua `verify_staff_qr_membership_v4` → `qr_staff_ctx_v4`: `approve_and_send_table_v4`, `cancel_qr_order_v4`, `claim_qr_request_v4`, `get_qr_request_detail_v4`, `manage_qr_channel_v4`, `pay_and_send_counter_v4`, `rotate_qr_channel_v4`, `set_qr_order_table_v4`, `update_qr_order_items_v4`, **`topup_customer_wallet_v1`** (anon gọi được), **`delete_manual_finance_record_v1`** (anon gọi được).
- Qua `verify_staff_qr_membership_v4` → `payroll_actor_v1`: trigger **`guard_payroll_periods_v1`**, **`guard_payroll_records_v1`**.
- Trực tiếp `verify_staff_qr_membership_v4` (anon gọi được): `complete_pos_sale_v1`, `settle_ban_session_v5`, `reconcile_ban_settlement_v1`, `reconcile_pos_sale_v1`, `generate_daily_order_number_v1`, `batch_soft_delete_products_v1` (chỉ authenticated).
- Qua `current_store_id()` (anon gọi được): `complete_production_order_v1`, `confirm_stock_count_v1`, `record_stock_waste_v1`, và **toàn bộ chính sách RLS `*_isolation`** của các bảng.
- Qua `qn_caller_id()`: `qn_is_manager`, `qn_is_member`, `qn_shares_store_with`, `qn_guard_module_config`, `qn_guard_staff_members_write` (trigger khóa phân quyền hôm nay), các hàm chuỗi cửa hàng.

**Các hàm đã an toàn (chỉ dùng `auth.uid()`, anon bị từ chối):** `admin_create_staff_member_v4`, `admin_update_staff_role_v4`, `admin_set_staff_status_v4`, `admin_revoke_staff_membership_v4`, `change_user_password_v4`, `create_store_with_owner_v4`, `join_store_by_code_v4`, `set_user_quick_pin_v4`, `verify_manager_quick_pin_v4`, `has_active_store_access_v4`, `get_store_staff_directory_v4`.

### 2.3 Mức độ phơi nhiễm của vai `anon` (đọc từ production)

- `anon` có quyền **INSERT/UPDATE/DELETE trên ~52 bảng** (tổng 58 bảng có quyền, kể cả `orders`, `finance_records`, `payroll_*`, `store_members`, `staff_members`, `balance_transactions`, `customers`…), `app_versions` còn có cả `TRUNCATE`. RLS bật nên chỉ ghi được "quán của mình" — nhưng "quán của mình" xác định bằng header.
- `anon` gọi được **47 hàm** (không tính trigger), trong đó có các RPC tiền bạc nêu trên.
- Thực tế sử dụng: không có lần ghi anon nào lên 49 bảng được theo dõi từ 14/10; 16 quán có log trong 7 ngày; 64 refresh token còn sống. **Chưa đo được** các lần anon **đọc** dữ liệu hay **gọi RPC** bằng header (trigger chỉ bắt ghi bảng) → Pha 1 bổ sung đo đạc này.

### 2.4 Chuỗi tấn công cụ thể (để thấy vì sao cần làm)

1. Lấy anon key: có sẵn trong `main.dart.js` của web `/pos/`.
2. Gọi `POST /rest/v1/rpc/lookup_staff_by_phone` bằng anon với SĐT của một nhân viên/chủ quán → nhận `id` + `store_id`. (Hoặc đọc `store_roles` vốn mở SELECT cho mọi người.)
3. Gửi bất kỳ yêu cầu nào kèm `x-user-id: <id chủ quán>`, `x-store-id: <id quán>` → `qn_caller_id()` tin header → RLS và các RPC coi kẻ tấn công là chủ quán: nạp ví khách, xóa thu chi, duyệt/trả lương, sửa đơn, đọc doanh thu…

---

## 3. Phát hiện cần Chủ Quán biết ngay

### 3.1 Tiền đề "app không đăng nhập Supabase" không còn đúng
App không dùng Supabase Auth (GoTrue), nhưng **có** JWT do gateway riêng ký, cùng khóa bí mật với Supabase nên PostgREST chấp nhận như JWT chuẩn. Việc còn lại là đóng đường cũ ở máy chủ.

### 3.2 Header `x-store-id` không cần bỏ
Khi có JWT, `current_store_id()` kiểm thành viên bằng `sub` đã ký → khai sai `x-store-id` chỉ làm mình thấy… không gì cả. Giữ để không phải sửa ~25 chỗ trong app (`core_product_repository.dart`, `log_viewer_screen.dart`, `bar_label_template_provider.dart`…).

### 3.3 Hàm "khóa" hôm nay sẽ tự mạnh lên
Tất cả chốt P0 (22/10) đều đi qua `verify_staff_qr_membership_v4` / `qn_caller_id` / `current_store_id`. Khi 3 hàm này thôi tin `x-user-id`, các chốt đó chặn được cả người gọi API trực tiếp — **không phải viết lại từng chốt**.

### 3.4 Ba lỗ khẩn (sửa riêng, không phải chờ lộ trình)

| # | Lỗ | Hậu quả | Cách vá đề xuất | Ảnh hưởng app |
|---|---|---|---|---|
| K1 | `publish_app_version_v1`: `SECURITY DEFINER`, **anon gọi được**, không kiểm tra ai gọi | Bất kỳ ai đăng được "bản cập nhật" giả cho android/ios/windows/macos với `download_url` tùy ý và `is_force_update=true` → app hiển thị cập nhật, dẫn người dùng tải file lạ | `REVOKE EXECUTE … FROM anon, authenticated, PUBLIC`; chỉ `service_role`. `scripts/qn_release.py` đã ưu tiên `SUPABASE_SERVICE_ROLE_KEY` (dòng 95) | Không (app chỉ đọc) — cần kiểm lại `app_update_manager.dart` không gọi hàm này |
| K2 | `lookup_staff_by_phone`: anon gọi được, trả `id`, `store_id`, tên, vai trò | Lộ UUID cần để giả danh + lộ thông tin nhân viên | `REVOKE EXECUTE` khỏi anon (app `lib/` không gọi; cần grep thêm `services/`, web QR) | Không thấy dùng |
| K3 | `revoke_store_member`: chỉ tin header, kể cả với JWT | Nhân viên có JWT giả danh chủ quán để xóa nhân viên | `REVOKE EXECUTE` khỏi `authenticated` (app dùng `admin_revoke_staff_membership_v4`) hoặc sửa dùng `qn_caller_id()` | Không thấy dùng |

Ngoài ra (ít khẩn hơn): `verify_password_hash_v4` anon gọi được (người gọi tự đưa hash nên không lộ dữ liệu, nhưng nên thu hồi); `store_roles` SELECT mở cho mọi người (đã có trong kế hoạch "Pha 1b" ngày 13/10).

---

## 4. Chọn cách cấp JWT

| Phương án | Ưu | Nhược | Kết luận |
|---|---|---|---|
| **A. Giữ gateway hiện có** (`pos_jwt_auth_service.py`: SĐT + mật khẩu → JWT HS256, refresh token xoay vòng, giới hạn sai 5 lần/5 phút) | Đã chạy production; app đã tích hợp đủ (đăng nhập, đổi quán, refresh, đăng xuất thu hồi); `store_id` nằm trong token; có test Dart/Python | Access token 30 ngày (Chủ Quán chọn 13/10) → bị lộ thì dùng được tới hạn; thu hồi tức thì chỉ bằng đổi khóa bí mật | **Khuyến nghị.** Không cần xây mới. |
| B. Supabase Auth (GoTrue, container `supabase-auth` đã có) | Chuẩn, có sẵn quản lý phiên | Phải chuyển `user_accounts` sang `auth.users`, đổi luồng mật khẩu, số điện thoại, đổi quán; app viết lại phần đăng nhập; rủi ro lớn mà không thêm bảo vệ so với A | Không làm. |
| C. Edge Function / RPC ký token trong Postgres | Bỏ được dịch vụ Python | Viết lại thứ đã có; ký JWT trong SQL phải để khóa bí mật trong DB (xấu hơn) | Không làm. |

Cải tiến nhỏ nên làm cùng phương án A (không bắt buộc cho việc tắt header):
- App gửi `client_label` (nền tảng + build) khi xin token → cột `pos_refresh_tokens.client_label` hiện **null 100%**, nên không biết máy nào đang chạy bản nào.
- Cân nhắc hạ access token xuống 1–7 ngày khi refresh đã ổn định (đã có refresh tự động). Quyết định của Chủ Quán.

---

## 5. Lộ trình chuyển dần (app cũ vẫn chạy cho tới khi tắt từng quán)

```
Pha 0  Vá khẩn K1–K3                        (độc lập, làm được ngay sau khi duyệt)
Pha 1  Đo: ai còn dùng anon + x-user-id     (≥ 7 ngày, gồm cuối tuần)
Pha 2  App mới: bỏ x-user-id, sửa chỗ lùi về anon   (song song với Pha 1)
Pha 3  Công tắc tắt fallback: thử 1 quán → nhiều quán → toàn bộ
Pha 4  Dọn dẹp: bỏ code header, thu hồi quyền anon từng bảng, áp lại FIX 11
```

### Pha 0 — Vá khẩn (migration `20261023_va_khan_rpc_anon_v1.sql` + `_ROLLBACK.sql`)
- `REVOKE EXECUTE` `publish_app_version_v1` khỏi `anon, authenticated, PUBLIC`; `lookup_staff_by_phone` và `verify_password_hash_v4` khỏi `anon, PUBLIC`; `revoke_store_member` khỏi `anon, authenticated, PUBLIC`.
- Trước khi áp: grep toàn bộ `lib/`, `services/`, `web/`, `scripts/`, trang QR khách để chắc không ai gọi bằng anon.
- Hoàn tác: `GRANT EXECUTE` lại đúng như cũ (ghi sẵn trong file ROLLBACK).

### Pha 1 — Đo đạc (migration `20261023_do_header_auth_v1.sql`)
**Vì sao không gắn đo đạc vào `qn_caller_id()`:** hàm này khai báo `STABLE`, PostgreSQL không cho `INSERT` bên trong hàm `STABLE`. Dùng **pre-request hook** thay thế:
- Hàm `public.qn_pre_request()` (VOLATILE, `SECURITY DEFINER`): nếu vai hiện tại là `anon` **và** có header `x-user-id` → cộng dồn 1 vào bảng `qn_header_auth_seen(ngay_gio, store_id_header, client_info, path, so_lan)` bằng `INSERT … ON CONFLICT DO UPDATE`. Không lưu giá trị `x-user-id`, không lưu nội dung. Mọi lỗi bị nuốt (không bao giờ làm hỏng yêu cầu).
- Bật hook: `ALTER ROLE authenticator SET pgrst.db_pre_request = 'public.qn_pre_request'; NOTIFY pgrst, 'reload config';` (PostgREST v14.12, chế độ cấu hình trong DB đang bật mặc định — đã kiểm `PGRST_DB_CONFIG` không bị tắt).
- Bảng thứ hai: số yêu cầu `anon` **không** có `x-user-id` theo `path` (để biết QR khách / kiểm tra phiên bản dùng gì) — giúp Pha 4.
- Báo cáo: script `db-fix/do_header_auth_bao_cao.sh` (chỉ đọc) liệt kê theo quán/ngày.
- Hoàn tác: `ALTER ROLE authenticator RESET pgrst.db_pre_request; NOTIFY pgrst, 'reload config';` + xóa hàm/bảng.

### Pha 2 — Bản app mới (1.0.5+21 hoặc 1.0.6)
| Việc | File | Lý do |
|---|---|---|
| Thôi gắn `x-user-id` (giữ `x-store-id`) | `session_provider.dart:77,146`, `staff_service.dart:315`, `boom_telemetry_service.dart:110` | Với JWT thì thừa; để lại sẽ làm số đo Pha 1 khó đọc |
| Sửa kiểm tra ngữ cảnh lương đang **đòi** header `x-user-id` khớp | `payroll_srm_repository.dart:285` (`_validateContext`) | Nếu bỏ header mà không sửa, màn Lương ném lỗi `Context mismatch` |
| Mở app khi mất mạng: không gọi API bằng anon; chờ refresh xong mới đồng bộ (hoặc dùng access token cũ nếu còn hạn) | `user_auth_service.dart` ~1422, `pos_jwt_auth_service.dart` (bộ hẹn giờ refresh) | Hiện tại nhánh này chạy anon + header |
| Web: đợt đọc đầu trang trước khi gắn JWT (đã thấy trong vụ KAY mất module) — chờ `restoreSessionOnStartup` xong mới đọc | `main.dart`, các provider đọc sớm | Sau khi tắt header các lần đọc này trả rỗng/lỗi rõ hơn |
| Tài khoản demo duyệt store: cấp JWT thật qua gateway cho quán demo `…9999` | `user_auth_service.dart:449`, gateway | Nếu không, bản duyệt Apple/Google hỏng sau Pha 3 |
| Gửi `client_label` = `"<nền tảng> <version>+<build>"` | `requestPosJwt`, `refreshPosJwt` | Biết máy nào còn bản cũ |
| Khi máy chủ trả lỗi "phiên kiểu cũ" (mã lỗi Pha 3) → đăng xuất mềm, hiện "Vui lòng đăng nhập lại" | `restoreSessionOnStartup`, bộ bắt lỗi chung | Người dùng không kẹt ở màn trắng |
| Test: cập nhật test JWT (`test/.../user_auth_service_pos_jwt_test.dart`), thêm test "không còn header `x-user-id`" | `test/` | |

Phát hành: web `/pos/` (ngay), Windows (Chủ Quán đã cho toàn quyền), Android/iOS (chờ duyệt). **Không** cần ép cập nhật: bản cũ từ sau 10/10 đã dùng JWT; bản mới chỉ dọn header.

### Pha 3 — Công tắc tắt fallback, từng quán
Migration `20261030_tat_header_fallback_v1.sql` (+ `_ROLLBACK.sql`):
- Bảng cấu hình `qn_auth_policy` (1 dòng): `header_fallback` = `'all' | 'allowlist' | 'off'`, và bảng `qn_header_fallback_stores(store_id, han_den)` cho quán còn máy cũ.
- Hàm `qn_header_fallback_allowed(p_store uuid)` (STABLE, chỉ đọc 2 bảng trên).
- Sửa 3 hàm lõi: nhánh đọc `x-user-id` (và `request.header.x-user-id`) **chỉ chạy khi** `qn_header_fallback_allowed(store trong x-store-id)` = true. Nhánh JWT giữ nguyên.
- `qn_pre_request()`: khi vai `anon` + có `x-user-id` + quán **không** được phép → `RAISE` mã lỗi riêng (`PT401`, thông báo "Phiên đăng nhập kiểu cũ, vui lòng cập nhật app và đăng nhập lại") → app mới bắt được, app cũ thấy lỗi rõ ràng thay vì dữ liệu rỗng.
- Bước bật: (1) áp migration với `'all'` (không đổi hành vi) → (2) `'allowlist'` với tất cả quán còn số đo > 0 → (3) thử tắt **một quán ít rủi ro** (quán demo / Mộc Sâm) 24 giờ → (4) tắt các quán còn lại theo số đo → (5) `'off'`.
- Hoàn tác **tức thì, không cần migration**: `UPDATE qn_auth_policy SET header_fallback='all';` (một câu lệnh, Chủ Quán chạy được).

**Tiêu chí chuyển bước:** quán có 0 lần `anon + x-user-id` trong 7 ngày gần nhất (gồm cuối tuần), máy thu ngân Windows của quán đã có log `[Auth] … POS JWT` hoặc refresh token mới trong 3 ngày.

### Pha 4 — Dọn dẹp (sau khi `'off'` ổn định ≥ 14 ngày)
- Xóa hẳn nhánh header khỏi `qn_caller_id`, `current_store_id` (phần người gọi), `verify_staff_qr_membership_v4`; bỏ `PGRST_DB_USE_LEGACY_GUCS` nếu không còn hàm nào cần (đổi cấu hình container → hỏi riêng).
- Thu hồi quyền ghi của `anon` từng bảng theo số đo Pha 1 (tiếp "Pha 2" của kế hoạch anon 13/10), cuối cùng `orders`, `store_members`; **áp lại FIX 11** (kèm test anon + header).
- Danh sách anon được giữ: `get_qr_menu_v4`, `get_qr_channel_info_v4`, `submit_qr_order_v4`, `get_qr_request_status_v4`, `verify_user_login_v4`, `register_user_account_v4`, `get_latest_app_version_v1`, `consume_onboarding_exchange_v4` (kiểm lại — gateway gọi bằng service role, có thể thu hồi), `normalize_*`.
- Dọn `x-store-id` không cần thiết trong app (không gấp).

---

## 6. Ước lượng công việc

| Pha | Việc | Thời gian làm | Thời gian lịch |
|---|---|---|---|
| 0 | Migration vá khẩn + test + script áp | 3–4 giờ | 1 ngày (chờ duyệt) |
| 1 | Hook đo đạc + bảng + báo cáo + test | 4–6 giờ | + quan sát ≥ 7 ngày |
| 2 | Sửa app (6 điểm), test Dart, build 4 nền tảng | 1,5–2 ngày | Web/Windows: ngay; Android/iOS: 1–7 ngày duyệt; chờ máy cập nhật |
| 3 | Công tắc + sửa 3 hàm lõi + test + script áp | 1 ngày | Bật dần 1–2 tuần |
| 4 | Dọn code header, thu hồi quyền anon từng nhóm bảng, FIX 11 | 1–2 ngày rải | 2–4 tuần |

Tổng: khoảng **5–6 ngày công**, **3–4 tuần lịch** tới trạng thái `'off'`.

---

## 7. Rủi ro và cách giảm

| Rủi ro | Khả năng | Hậu quả | Giảm thiểu |
|---|---|---|---|
| Máy thu ngân Windows ở quán còn bản cũ chạy anon (đã xảy ra: sự cố FIX 11 ngày 10/10) | Trung bình | Không bán được, in bếp lỗi | Số đo Pha 1 theo quán; tắt từng quán; hoàn tác 1 câu lệnh |
| Máy mở app lúc mất mạng → chạy anon tới khi refresh | Cao (quán hay rớt mạng) | Sau Pha 3: lỗi tạm tới khi refresh xong | Sửa ở Pha 2 trước khi tắt quán đó |
| Pre-request hook chậm hoặc lỗi làm hỏng mọi yêu cầu | Thấp | Toàn hệ thống lỗi | Hàm nhỏ, nuốt lỗi, chỉ ghi khi anon; đo thời gian trên bản sao; hoàn tác bằng `RESET` + `NOTIFY` |
| Tài khoản demo duyệt store hỏng | Cao nếu quên | Bị từ chối duyệt | Pha 2 cho demo JWT; kiểm trước khi gửi duyệt |
| Gateway sập → không ai đăng nhập được (đã đúng như hiện nay, không lùi về anon) | Thấp | Không đăng nhập mới; máy đang chạy vẫn dùng token 30 ngày | Theo dõi `/api/auth/health`; không thay đổi trong kế hoạch này |
| Access token 30 ngày bị lộ | Thấp | Kẻ có token làm được việc của người đó tới hết hạn | Các chốt kiểm thành viên còn hoạt động (`qr_is_active_member_v4`); cân nhắc giảm TTL |
| `store_id` trong JWT khác `x-store-id` (chủ chuỗi xem nhiều quán) | Thấp | Không phải lỗ (thành viên kiểm bằng `sub`) | Giữ hành vi hiện tại, ghi chú trong test |
| Thu hồi quyền anon ở Pha 4 làm hỏng trang QR khách | Trung bình | Khách không gọi món được | Danh sách giữ lại + test QR (`qr_v4_full_suite_test.sql`) trên bản sao |

---

## 8. Kế hoạch kiểm thử trên bản sao

Script có sẵn `db-fix/chuoi_stage_dryrun.sh` nhận biến `MIG`, `TEST`, `TAG` (dựng DB tạm `chuoi_stage` bằng `pg_dump` chỉ đọc → áp → test tự ROLLBACK → xóa DB tạm). Dùng:

```bash
MIG=quan_nho/supabase/migrations/20261030_tat_header_fallback_v1.sql TEST=quan_nho/supabase/tests/tat_header_fallback_v1_test.sql TAG=jwt bash db-fix/chuoi_stage_dryrun.sh
```

Nếu cần áp nhiều migration nối tiếp (Pha 0 + 1 + 3), gộp tạm thành một file trong scratchpad hoặc viết `db-fix/jwt_stage_dryrun.sh` theo mẫu `phan_quyen_stage_dryrun.sh`.

Cách giả lập trong SQL (giống các test hôm nay): `SET LOCAL role anon|authenticated;` + `set_config('request.jwt.claims', '{"role":"authenticated","sub":"…","store_id":"…"}', true)` + `set_config('request.headers', '{"x-user-id":"…","x-store-id":"…"}', true)`.

Các ca test (bộ `tat_header_fallback_v1_test.sql`, mỗi ca PASS/FAIL, cuối file ROLLBACK):

| # | Ca | Kỳ vọng ở `'off'` | Kỳ vọng ở `'all'` |
|---|---|---|---|
| T1 | anon + `x-user-id` = chủ quán → `topup_customer_wallet_v1` | Bị từ chối | Chạy (giữ hành vi cũ) |
| T2 | anon + header chủ quán → `delete_manual_finance_record_v1` | Bị từ chối | Chạy |
| T3 | anon + header chủ quán → UPDATE `payroll_periods` sang duyệt (trigger `guard_payroll_*`) | Bị từ chối | Chạy |
| T4 | anon + header → SELECT `orders` của quán | 0 dòng | Có dòng |
| T5 | anon + header → INSERT `finance_records` | Bị RLS chặn | Chạy |
| T6 | JWT thu ngân + header `x-user-id` = chủ quán → `topup_customer_wallet_v1` | Bị từ chối (dùng `sub`, bỏ qua header) | Bị từ chối |
| T7 | JWT chủ quán, không header → các RPC trên | Chạy | Chạy |
| T8 | JWT chủ quán + `x-store-id` quán khác mà chủ **không** thuộc | `current_store_id()` = NULL | Như cũ |
| T9 | JWT chủ chuỗi + `x-store-id` quán thứ hai mình sở hữu | Trả đúng quán thứ hai | Như cũ |
| T10 | Chế độ `'allowlist'`: quán A trong danh sách, quán B không → anon + header | A chạy, B bị từ chối | — |
| T11 | `qn_pre_request()` với anon + header ở quán bị tắt | RAISE đúng mã lỗi | Không RAISE, có cộng số đo |
| T12 | `qn_pre_request()` với anon **không** header (khách QR) | Không RAISE | Không RAISE |
| T13 | QR khách: `get_qr_menu_v4`, `submit_qr_order_v4` bằng anon | Chạy (chạy kèm `qr_v4_full_suite_test.sql`) | Chạy |
| T14 | Pha 0: anon gọi `publish_app_version_v1`, `lookup_staff_by_phone`; authenticated gọi `revoke_store_member` | `permission denied` | — |
| T15 | Hoàn tác: `UPDATE qn_auth_policy SET header_fallback='all'` → T1 chạy lại | — | Chạy |
| T16 | Chạy lại các bộ test đã áp hôm nay (`nap_vi_an_toan_v1_test`, `xoa_thu_chi_an_toan_v1_test`, `khoa_duyet_tra_luong_v1_test`, `khoa_ghi_phan_quyen_v1_test`, `chan_dong_phien_ban_v1_test`, `cung_co_p0_v2_test`) ở cả hai chế độ | Đều PASS (với ca anon+header đổi kỳ vọng thành bị chặn) | PASS |
| T17 | Đo thời gian `qn_pre_request()` 10.000 lần | < 0,1 ms/lần | |

Kiểm thử đầu-cuối thật (sau bản sao): pre-request hook chỉ chạy khi đi qua PostgREST nên **không** thử được trong bản sao SQL. Cách thử an toàn: bật hook ở chế độ `'all'` (chỉ đo) trên production → gọi `curl` bằng anon + header vào một quán thử (quán demo `…9999`) → xác nhận có số đo; rồi `'allowlist'` không có quán demo → `curl` nhận đúng lỗi; app mới đăng nhập quán demo chạy bình thường. Mọi bước này cần Chủ Quán duyệt trước.

Kiểm thử app (Pha 2): `flutter test` bộ auth (`user_auth_service_pos_jwt_test.dart`, `onboarding_jwt_exchange_test`), thêm test không gửi `x-user-id`, test `_validateContext` mới; chạy thử web cục bộ trỏ staging nếu có.

---

## 9. Việc cần Chủ Quán quyết

1. Duyệt **Pha 0** (vá khẩn K1–K3) — có thể làm ngay, độc lập.
2. Duyệt bật **đo đạc Pha 1** trên production (không đổi hành vi, có hoàn tác).
3. Chọn quán thử tắt đầu tiên ở Pha 3 (gợi ý: quán demo, rồi Mộc Sâm, KAY cuối cùng).
4. Có giảm thời hạn access token từ 30 ngày không (không bắt buộc cho kế hoạch này).

## 10. Nguồn đã đọc

- App: `lib/core/providers/session_provider.dart`, `lib/core/services/user_auth_service.dart`, `lib/core/services/pos_jwt_auth_service.dart`, `lib/screens/ban_screen.dart` (PIN quản lý), `lib/modules/tinhluong/repository/payroll_srm_repository.dart`, `lib/core/services/staff_service.dart`, `lib/features/ai_assistant/services/boom_telemetry_service.dart`.
- Gateway: `services/pos_jwt_auth_service.py`, `services/pos_gateway_server.py`, `scripts/qn_release.py`.
- Production (chỉ đọc, 22/10/2026 tối): định nghĩa `qn_caller_id`, `current_store_id`, `verify_staff_qr_membership_v4`, `revoke_store_member`, `payroll_actor_v1`, `qr_staff_ctx_v4`, `verify_manager_quick_pin_v4`, `lookup_staff_by_phone`, `publish_app_version_v1`; quyền bảng/hàm của `anon`; chính sách RLS; `anon_write_audit`; `pos_refresh_tokens`; `app_logs` (tag `auth`); cấu hình container PostgREST v14.12 (chỉ tên biến môi trường).
- Kế hoạch trước: `supabase/migrations/20261013_anon_pha0_quan_sat.sql`, nhật ký mục "THU HỒI QUYỀN anon DẦN DẦN" (13/10) và "FIX 11" (10/10).
