# KẾ HOẠCH GIAO ANTIGRAVITY TRIỂN KHAI QR ORDER V4

> Dự án: Quán Nhỏ POS  
> Ngày lập: 2026-08-26  
> Mức ưu tiên: P0  
> Trạng thái: kế hoạch giao việc; chưa cho phép apply database, deploy production, build release hoặc push Git.

## 1. Mệnh lệnh thực thi

Antigravity phải triển khai QR Order theo kiến trúc đã chốt, không tiếp tục hoàn thiện các giả định V3 cũ.

Kết quả cuối cần đạt:

```text
TABLE_SHARED
  khách quét một QR chung của quán
  → đặt món
  → nhận QR bàn giao động
  → nhân viên quét bằng app đã đăng nhập
  → atomic claim
  → chọn bàn
  → đọc lại/chỉnh món
  → gắn đúng một order vào ban_session
  → gửi Bếp
  → thanh toán toàn bộ bàn sau

COUNTER
  khách quét QR mang đi tại quầy
  → đặt món
  → nhận QR bàn giao động + pickup code
  → nhân viên/Thu ngân quét
  → kiểm tra/chỉnh món
  → thanh toán bởi actor có pos.checkout
  → gửi Bếp
```

Chỉ có hai QR tĩnh cho mỗi cửa hàng:

- Một QR `TABLE_SHARED` dùng chung cho toàn bộ bàn.
- Một QR `COUNTER` chỉ dùng cho mang đi.

Mỗi lần khách submit phải tạo đúng một `qr_request` và đúng một `order_id`. Không có bất kỳ nhánh retry, checkout hoặc gửi Bếp nào được tạo order thứ hai.

## 2. Cách khởi động bắt buộc

1. Chọn reasoning model mức High/Thinking.
2. Từ root repo chạy workflow `/qn` bằng file `.agents/workflows/qn.md`.
3. Đọc toàn bộ các nguồn sau trước khi hành động:
   - `.agents/workflows/qn.md`
   - `.docs/qr-order-kien-truc-muc-tieu.md`
   - `.docs/ke-hoach-trien-khai-qr-order.md`
   - `.docs/trien-khai-sap-toi.md`, chỉ mục QR và các quy tắc checkout/kho/quyền liên quan
   - `.docs/kien-truc.md`
   - `.docs/kien-truc-data.md`
   - `maqr.md`, chỉ để nhận diện legacy V3, không dùng làm thiết kế mục tiêu
   - mục `Tiếp theo` gần nhất trong `nhat_ky.md`
4. Kiểm tra `git status --short`; mọi thay đổi có sẵn thuộc về người dùng, không được reset hoặc ghi đè.
5. Dùng đúng một truy vấn Graphify tổng quan để định hướng code–docs–schema.
6. Dùng CodeGraph để truy source/call path/blast radius trước khi đọc rời rạc hoặc sửa file.

Truy vấn khởi đầu đề nghị:

```bash
graphify query "QR Order V4 TABLE_SHARED COUNTER dynamic handoff QR staff auth store membership table assignment checkout kitchen idempotency"

codegraph status .
codegraph explore "QR V3 implementation baseline to replace: per-table QR channel creation, customer submit/status, PosDeviceTokenService, review sheet, BanScreen/PosScreen integration, checkout and kitchen dispatch"
```

## 3. Nguồn sự thật và cách xử lý mâu thuẫn

Thứ tự ưu tiên:

1. Source hiện tại + schema/migration đã thực sự apply + test chạy thật.
2. `.docs/qr-order-kien-truc-muc-tieu.md` cho hành vi mục tiêu.
3. Quyết định nghiệp vụ trong `.agents/workflows/qn.md` và `.docs/trien-khai-sap-toi.md`.
4. Tài liệu/kế hoạch legacy chỉ dùng làm lịch sử.

Nếu tài liệu nói đã có nhưng source/schema thật chưa có, báo `chưa có`. Nếu source V3 trái đặc tả V4, V4 thắng nhưng phải ghi rõ blast radius trước khi thay.

## 4. Phạm vi được phép

### Được phép sửa sau khi qua cổng Phase 0

- `lib/modules/qr_order/**`
- Entry point QR trong `lib/main.dart`
- Điểm tích hợp QR có liên quan trực tiếp trong:
  - `lib/screens/ban_screen.dart`
  - `lib/screens/pos_screen.dart`
  - `lib/screens/settings_screen.dart`
- Auth/permission adapter tối thiểu để QR tái sử dụng session hiện hành; không thay toàn bộ hệ thống đăng nhập.
- Repository/service checkout, Bếp, finance và stock chỉ ở phần cần thiết để đảm bảo một-order/idempotency.
- `pubspec.yaml` và cấu hình Android/iOS cần thiết cho camera scanner.
- Migration/RPC/RLS/test SQL mới cho QR V4.
- Test Flutter/backend liên quan.
- Tài liệu kiến trúc QR, kiến trúc data và tính năng sau khi source thực sự thay đổi.

### Không được tự thực hiện

- Không apply migration lên production.
- Không sửa dữ liệu production.
- Không deploy web/VPS, upload App Store/Play Store, build release hoặc push Git.
- Không dùng tài khoản thật, mật khẩu thật, reviewer credential hoặc token thật trong log/test/report.
- Không thay auth toàn hệ thống, print server, AI Bum, payroll hoặc module ngoài blast radius nếu chưa có bằng chứng cần thiết.
- Không xóa migration V3 chỉ vì người dùng nói chưa apply; phải xác minh schema/migration history trước.
- Không tái sử dụng PIN quản lý làm credential QR hoặc pairing thiết bị.
- Không thêm QR Payment tự động/webhook ngoài phạm vi.

## 5. Bất biến bắt buộc

### Store và auth

- Mọi dữ liệu/RPC phải cô lập theo `store_id`.
- Nhân viên dùng account SĐT + mật khẩu, active `store_members`, role/modules/actions hiện hành.
- Mã quán `QN-XXXX` chỉ dùng khi tham gia quán.
- Không có POS device pairing/session riêng cho QR.
- `device_id` nếu lưu chỉ là metadata audit/idempotency, không phải credential.
- Quyền quan trọng được kiểm tra server-side, fail-closed.

### Order và side effect

- `qr_request → order_id` là quan hệ một-một.
- Submit retry cùng idempotency key trả lại request/order cũ.
- Claim chỉ một actor thành công.
- Một order chỉ có tối đa một kitchen dispatch thành công cho cùng round/idempotency key.
- Payment/finance/stock/kitchen retry không tạo side effect thứ hai.
- Không rollback kitchen ticket sau commit nếu có nguy cơ in lại.
- Kho chỉ trừ sau thanh toán.

### TABLE

- QR tĩnh không chứa `table_id`.
- Khách không chọn/nhập bàn.
- Nhân viên nhập/chọn bàn sau atomic claim và xác nhận gán bàn riêng trước bước gửi Bếp.
- Trước gán bàn, request chỉ nằm trong hàng chờ chung.
- Sau gán bàn, request hiển thị đúng trên module Bàn; canonical order và `ban_session` được materialize idempotent khi gửi Bếp.
- TABLE được gửi Bếp trước thanh toán; checkout thanh toán toàn bộ order hợp lệ trong session.

### COUNTER

- COUNTER chỉ là mang đi, không chọn bàn, không tạo/gắn `ban_session`.
- COUNTER không gửi Bếp trước trạng thái `paid`.
- Chỉ actor có `pos.checkout` được xác nhận thanh toán.
- Khách chọn tiền mặt hoặc chuyển khoản tại Thu ngân; Thu ngân kiểm tra tiền đã nhận trước khi xác nhận.
- VietQR hiển thị hoặc ảnh chuyển khoản không tự chứng minh đã trả tiền.

### Chỉnh sửa

- Nhân viên được chỉnh trước kitchen commit: thêm/xóa món, số lượng, topping và ghi chú.
- Server tính lại giá/availability/topping/station sau chỉnh sửa.
- Audit phải giữ before/after, actor và thời điểm; không overwrite mất lịch sử.
- Sau kitchen commit dùng quy tắc hủy món Owner/Manager + lý do + phê duyệt + audit hiện hành.

## 6. Contract trạng thái mục tiêu

### TABLE

```text
pending_staff
  → processing
  → confirmed
  → assigned_table
  → sent_kitchen

pending_staff | processing | confirmed | assigned_table
  → rejected | expired
```

Nếu không muốn thêm `assigned_table` vào enum, có thể giữ `confirmed` kèm `assigned_table_id/session_id`, nhưng phải chứng minh invariant và test rõ. Không được dùng string trạng thái tùy tiện khác nhau giữa Dart/SQL.

### COUNTER

```text
pending_staff
  → processing
  → confirmed
  → awaiting_payment
  → paid
  → sent_kitchen

pending_staff | processing | confirmed | awaiting_payment
  → rejected | expired
```

### Terminal và retry

- `sent_kitchen`, `rejected`, `expired` là terminal cho luồng duyệt.
- Gọi lại dispatch của `sent_kitchen` phải trả success reconciliation cùng `order_id`/ticket hiện có.
- Request đã claim bởi actor khác phải trả lỗi typed như `ALREADY_CLAIMED`, không dùng message text để client suy luận.

## 7. Contract QR bàn giao động

Payload QR khách nhìn thấy chỉ chứa URL công khai với opaque token, ví dụ logic:

```text
https://<public-domain>/qr-handoff?t=<raw-one-time-token>
```

Không khóa cứng URL trên nếu routing hiện tại yêu cầu dạng khác; phải giữ các thuộc tính sau:

- Raw token entropy tối thiểu 128 bit từ CSPRNG.
- Server chỉ lưu hash token, không lưu raw token.
- Bind token với `store_id`, `request_id`, `order_id`.
- Single-use atomic claim.
- TTL mặc định 20 phút; cấu hình hợp lệ 5–60 phút nếu tạo setting.
- Revoke khi claim/reject/expire.
- Không log raw token, không trả token qua staff queue API.
- Rate limit scan/claim và public status endpoint.
- QR không tự gán bàn, thanh toán hoặc dispatch Bếp.
- Có fallback mã ngắn hoặc mở từ hàng chờ khi camera lỗi; fallback gọi cùng claim transaction và không bypass auth.

## 8. Contract dữ liệu dự kiến

Tên cột có thể điều chỉnh theo schema thật, nhưng quan hệ và constraint không được bỏ.

### `qr_channels`

- `store_id`
- `type`: `table_shared | counter`
- `channel_code_hash` hoặc token lookup an toàn theo thiết kế hiện hữu
- `is_active`
- Unique active channel theo `(store_id, type)`.
- Không còn `table_id` bắt buộc/per-table channel.

### `qr_requests`

- `store_id`, `channel_id`, `type`
- `order_id NOT NULL` sau submit và unique
- status canonical
- authoritative total + customer note
- `pickup_code` chỉ COUNTER
- claimed actor/time
- assigned table/session chỉ TABLE, ban đầu null
- idempotency key unique theo store/channel/client scope
- timestamps UTC

### `qr_request_items`

- Snapshot item khách submit và current approved representation.
- Stable item ID để edit/audit/idempotency.
- Product/topping IDs authoritative, quantity, unit price, note/modifiers.

### `qr_handoff_tokens`

- `store_id`, `request_id`, `order_id`
- token hash unique
- `expires_at`, `claimed_at`, `revoked_at`
- claimed actor
- Không có raw token.

### Audit

- Claim, edit, assign table, confirm, reject, payment transition và dispatch.
- Actor dùng `staff_members.id`/user account ID theo auth contract thật.
- Payload edit có before/after; không chứa secret/token raw.

### Unique/idempotency guards

- Unique order source: `(store_id, source_type='qr_order', source_id=request_id)` hoặc constraint tương đương.
- Unique request-to-order.
- Unique kitchen dispatch key/order round.
- Unique payment/finance/stock side effect theo transaction/order key.
- Index cho active queue theo `store_id + status + created_at` và expiry cleanup.

## 9. Contract RPC dự kiến

Tên RPC cuối cùng có thể dùng hậu tố V4. Không sửa V3 âm thầm mà để client/schema lệch signature.

### Public RPC

1. `get_qr_menu_v4(channel_code)`
   - Chỉ trả menu của active channel/store.
   - Filter `is_active=true`, `is_available=true`, `is_deleted=false`.
   - Hết tồn chỉ cảnh báo, không khóa bán.

2. `submit_qr_order_v4(channel_code, items, note, idempotency_key)`
   - Validate payload/limits.
   - Tính lại giá/topping từ DB.
   - Tạo request + order + items + handoff token trong một transaction.
   - Retry trả lại cùng request/order/token còn hợp lệ hoặc rotate token có audit nếu contract yêu cầu.

3. `get_qr_request_status_v4(tracking_token)`
   - Chỉ trả dữ liệu tối thiểu cho khách.
   - Không lộ staff IDs, store internals hoặc handoff token.

### Staff RPC

1. `claim_qr_handoff_v4(raw_handoff_token)`
   - Xác minh account/membership/store/action.
   - Hash token, lock row, kiểm tra expiry/single-use.
   - Atomic claim và trả request/order chi tiết cần review.

2. `update_qr_order_items_v4(request_id, expected_version, items)`
   - Chỉ claimant hợp lệ.
   - Optimistic version hoặc row lock chống lost update.
   - Reprice authoritative, update request/order items và ghi audit atomically.

3. `assign_qr_order_table_v4(request_id, table_id)`
   - TABLE only.
   - Validate table cùng store và active.
   - Lock/reuse hoặc mở `ban_session` đúng cách.
   - Gắn order/item vào session idempotently.

4. `confirm_qr_order_v4(request_id, expected_version)`
   - Revalidate item/price/availability/station.
   - Nếu thay đổi, trả typed discrepancy để UI xác nhận lại.

5. `reject_qr_order_v4(request_id, reason)`
   - Reason bắt buộc, audit đầy đủ, revoke token.

6. `send_qr_order_to_kitchen_v4(request_id, idempotency_key)`
   - TABLE cần assigned session; COUNTER cần paid.
   - Tạo ticket/items atomically hoặc reconcile ticket đã có.
   - Không tạo order mới.

7. Payment/checkout RPC
   - COUNTER: chỉ actor có `pos.checkout`; transaction authoritative chuyển paid và tạo payment/finance/stock theo contract thật.
   - TABLE: checkout toàn `ban_session`; hoàn tất các order hợp lệ mà không tạo order QR khác.

RPC staff không được dựa vào `PosDeviceTokenService` hoặc raw POS device token V3.

## 10. Các phase giao việc

## PHASE 0 — Điều tra hiện trạng và khóa contract

### Mục tiêu

Không sửa production code/schema. Xác minh mọi giả định trước khi thiết kế migration.

### Việc bắt buộc

1. Chụp `git status` và liệt kê thay đổi có sẵn.
2. Graphify một lần để xác định domain QR → auth → Bàn → checkout → Bếp → kho/finance.
3. CodeGraph truy:
   - `QrOrderRepository`
   - `QrOrderScreen._loadData`/`ensureChannelForTable`
   - `CustomerQrOrderScreen`
   - `QrOrderReviewSheet`
   - `PosDeviceTokenService` và toàn bộ callers
   - điểm tích hợp `BanScreen`, `PosScreen`, `SettingsScreen`
   - TABLE/POS checkout, finance, stock, kitchen dispatch
4. Kiểm tra migration history/schema thật bằng read-only tooling được cấu hình. Nếu không có quyền DB, báo `chưa xác minh`, không giả định.
5. Xác định auth thật của staff RPC: Supabase auth, POS JWT/custom header hay adapter khác. Không tự dùng `auth.uid()` nếu runtime hiện không cấp đúng principal.
6. Xác định schema payment/finance/stock và cách TABLE checkout hiện tạo/hoàn tất order.
7. Lập bảng `đã có / có một phần / chưa có / legacy phải bỏ`.
8. Lập blast radius file/symbol/test/migration/platform.

### Đầu ra bắt buộc

Tạo `.docs/qr-v4-phase0-audit.md` gồm:

- Source/migration/schema evidence có line/path.
- Auth contract thật.
- Những migration QR nào đã/chưa apply.
- Sơ đồ current flow và target flow.
- Danh sách constraint/index/RPC cần tạo.
- Rủi ro và quyết định còn thiếu.
- Kế hoạch patch tối thiểu theo thứ tự.

### Cổng dừng

Sau Phase 0 phải dừng và báo cáo. Không viết migration hay code khi:

- Chưa xác định auth principal staff RPC.
- Chưa xác định migration QR V3 có apply hay không.
- Chưa hiểu TABLE checkout hiện xử lý `orders` thế nào.
- Phát hiện thay đổi user chồng lên file cần sửa mà chưa có phương án bảo toàn.

## PHASE 1 — Migration, RLS, RPC và test SQL

### Mục tiêu

Tạo backend contract V4 hoàn chỉnh nhưng chưa apply production.

### Việc bắt buộc

1. Nếu xác nhận V3 chưa apply ở mọi môi trường mục tiêu, thay/squash chuỗi V3 thành migration V4 sạch; ghi rõ file legacy nào sẽ không còn được chạy.
2. Nếu có môi trường đã apply một phần V3, viết compatibility migration forward-only, không drop dữ liệu thiếu kiểm soát.
3. Tạo schema/constraint/index/token/audit theo contract.
4. Tạo RPC public và staff V4 với typed response thống nhất:

```json
{
  "success": true,
  "data": {},
  "error_code": null,
  "message": null
}
```

5. Mọi error quan trọng có `error_code` ổn định: `INVALID_TOKEN`, `TOKEN_EXPIRED`, `ALREADY_CLAIMED`, `MEMBERSHIP_REVOKED`, `PERMISSION_DENIED`, `VERSION_CONFLICT`, `RECONFIRM_REQUIRED`, `PAYMENT_REQUIRED`, `ALREADY_DISPATCHED`.
6. Public EXECUTE grants tối thiểu; staff RPC không mở cho anon.
7. RLS/RPC kiểm tra `store_id` server-side.
8. Tạo cleanup expiry an toàn; không bắt buộc cron production trong phase này nếu hạ tầng chưa chốt.

### Test SQL bắt buộc

- Hai store không đọc/claim/sửa chéo.
- Token raw không lưu DB/log.
- Token dùng lần hai thất bại.
- Token hết hạn thất bại.
- Hai transaction claim đồng thời chỉ một success.
- Submit cùng idempotency key chỉ một request/order.
- Submit retry sau timeout trả cùng order.
- Hai lần assign TABLE chỉ một session link/item set.
- Edit version conflict không overwrite.
- Giá/topping/availability thay đổi trả discrepancy.
- COUNTER chưa paid không dispatch.
- Actor thiếu `pos.checkout` không paid.
- Dispatch retry chỉ một ticket/item set.
- TABLE không trừ kho lúc dispatch.
- Payment/checkout retry không trùng finance/stock.

### Cổng dừng

- Chạy test SQL trên DB test/staging disposable, không production.
- Báo schema diff, test results và rollback/forward strategy.
- Không tiếp tục Flutter nếu response contract còn thay đổi.

## PHASE 2 — Repository/model/provider và auth integration

### Mục tiêu

Flutter dùng V4 contract, bỏ auth thiết bị QR riêng và phân biệt current/terminal/error typed.

### Việc bắt buộc

1. Cập nhật model canonical cho channel type/status/payment state/version/assigned table.
2. Repository parse wrapper `success/data/error_code/message` nhất quán; không coi response Map bất kỳ là success.
3. Thay `ensureChannelForTable` bằng đảm bảo đúng một `TABLE_SHARED` channel/store.
4. Giữ đúng một COUNTER channel/store.
5. Thay staff calls dùng session/membership hiện hành.
6. Gỡ callers QR của `PosDeviceTokenService`; chỉ xóa service/card/migration sau CodeGraph impact xác nhận không consumer hợp lệ khác.
7. Provider active queue cô lập store, autoDispose, không emit snapshot giống nhau và phục hồi request do chính actor claim.
8. Không log secret, tracking token hoặc handoff raw token.

### Test Flutter bắt buộc

- Parse tất cả typed success/error.
- Store switch không giữ queue/cache quán cũ.
- Missing/revoked membership fail-closed.
- Snapshot equality không phát state thừa.
- Claim recovery sau dispose/reopen.
- Không còn QR caller yêu cầu POS device pairing.

## PHASE 3 — Web khách và QR bàn giao

### Mục tiêu

Khách dùng hai QR tĩnh, submit idempotent và nhận QR bàn giao động.

### Việc bắt buộc

1. Route public nhận channel code an toàn, phân biệt TABLE_SHARED/COUNTER từ server.
2. TABLE không hiện/chấp nhận chọn bàn.
3. COUNTER ghi rõ mang đi và pickup flow.
4. Submit dùng một idempotency key ổn định cho mỗi draft; double tap không đổi key.
5. Sau submit render QR bàn giao từ raw token chỉ giữ trong memory/page state cần thiết; không log.
6. Status polling/realtime không tạo request mới khi refresh.
7. Hiển thị expiry countdown và cách tạo lại handoff token an toàn nếu contract cho phép.
8. Trạng thái khách rõ ràng: chờ nhân viên, đang xác nhận, đã gán bàn/đã thanh toán, đã gửi Bếp, từ chối, hết hạn.
9. COUNTER `customer_qr_optional` chỉ là lựa chọn UX; chưa có reconciliation thì vẫn chờ Thu ngân xác nhận authoritative.

### Test bắt buộc

- TABLE/COUNTER đúng nội dung.
- Double tap/refresh/network timeout không trùng order.
- QR encode đúng token/URL và không lộ IDs.
- Token expired/rejected UI.
- Product unavailable hard block; stock thấp chỉ warning.
- Responsive mobile web và base href `/pos/` không bị phá.

## PHASE 4 — Scanner nhân viên, review editor và chọn bàn

### Mục tiêu

Điện thoại cá nhân của nhân viên quét QR động, claim, chỉnh món, chọn bàn cho TABLE và gửi Bếp.

### Việc bắt buộc

1. Chọn scanner package đang được duy trì, tương thích Flutter/Android/iOS hiện tại; ghi lý do và pin version trong `pubspec.lock`.
2. Thêm camera permission Android/iOS với mô tả tiếng Việt phù hợp.
3. Scanner chống đọc lặp frame: khóa sau lần decode đầu, chỉ mở lại khi RPC thất bại có thể retry.
4. Validate scheme/host/path/token trước RPC; không mở URL tùy ý từ QR.
5. Có fallback nhập mã ngắn hoặc mở hàng chờ chung.
6. Sau claim TABLE:
   - mở danh sách `ban_dining_tables` đúng store;
   - tìm theo tên/khu vực;
   - hiển thị trống/đang mở;
   - không nhận text bàn tự do;
   - xử lý bàn vừa đổi trạng thái bằng server response.
7. Review editor cho thêm/xóa/số lượng/topping/note, hiển thị giá trước/sau và typed discrepancy.
8. Assign order/session bằng RPC, sau success invalidate/realtime module Bàn.
9. TABLE gửi Bếp không mở payment sheet.
10. COUNTER nếu thiếu `pos.checkout` chuyển hàng chờ Thu ngân; không ẩn đơn hoặc báo paid giả.
11. Giữ fallback mở active request từ queue nhưng vẫn dùng atomic claim/ownership contract.

### Test bắt buộc

- Unit/widget test scanner state/debounce/invalid QR.
- Hai nhân viên quét đồng thời.
- Claim thành công rồi app kill/reopen.
- TABLE chọn bàn trống và bàn đang mở.
- Bàn bị thiết bị khác đóng/chuyển trong lúc chọn.
- Edit đồng thời/version conflict.
- Reprice required.
- Module Bàn hiển thị đúng sau assign.
- COUNTER không xuất hiện trong module Bàn.
- Android/iOS permission denied/permanently denied.

## PHASE 5 — Checkout, payment gate, kho, finance và kitchen commit

### Mục tiêu

Khép kín side effect P0 mà không tạo trùng dữ liệu.

### TABLE

1. Checkout session lấy mọi order hợp lệ chưa thanh toán đã gắn session.
2. Request chưa claim/gán bàn không vào hóa đơn.
3. Hoàn tất đúng các order hiện có, không tạo aggregate QR order mới trùng.
4. Payment/finance/stock/COGS chạy transaction/idempotency theo schema thật.
5. Lưu actor tạo/claim/edit/send/pay riêng biệt.

### COUNTER

1. `confirmed → awaiting_payment`.
2. Chỉ `pos.checkout` được ghi paid.
3. Chưa có webhook: chuyển khoản phải được Thu ngân xác nhận thủ công.
4. Chỉ sau paid mới dispatch Bếp.
5. Nếu payment commit thành công nhưng response timeout, retry phải reconcile paid, không thu/ghi sổ lần hai.

### Kitchen

1. Chỉ materialize đúng một canonical order tại dispatch nếu request chưa có order; retry không tạo order thứ hai.
2. Revalidate station/item trước commit.
3. Ticket/items tạo atomically và unique theo dispatch key.
4. Sau commit không rollback ticket; status retry/reconcile.
5. TABLE label đúng bàn/khu vực; COUNTER label `Mang đi #Qxx`.

### Test bắt buộc

- TABLE nhiều QR order + món nhân viên, checkout toàn bàn một lần.
- Hai checkout đồng thời chỉ một payment completion.
- Crash/timeout trước và sau payment commit.
- COUNTER dispatch trước paid bị chặn server-side.
- Actor thiếu quyền checkout bị chặn dù gọi RPC trực tiếp.
- Dispatch đồng thời/retry chỉ một ticket.
- Stock trừ đúng một lần sau payment.
- Finance/COGS đúng nguồn quỹ và không trùng.
- Thiếu tồn vẫn checkout; `is_available=false` bị chặn/reconfirm.

## PHASE 6 — UI cấu hình/in QR, dọn legacy và tài liệu

### Việc bắt buộc

1. Thay tab QR theo từng bàn/in tem hàng loạt bằng cấu hình/in poster TABLE_SHARED duy nhất.
2. Giữ designer COUNTER nhưng cập nhật hướng dẫn payment/handoff.
3. Xóa `PosDeviceSessionCard` khỏi Settings QR.
4. Chỉ xóa file/service/RPC/migration legacy sau `codegraph impact` và search consumer xác nhận an toàn.
5. Cấu hình responsive Mobile `<600`, Tablet/PC `>=600`.
6. PDF QR đen thuần, QR đủ quiet zone/contrast và test quét bản in thật.
7. Cập nhật:
   - `.docs/qr-order-kien-truc-muc-tieu.md`
   - `.docs/ke-hoach-trien-khai-qr-order.md`
   - `.docs/kien-truc.md`
   - `.docs/kien-truc-data.md`
   - `.docs/tinh-nang.md`
   - `.docs/trien-khai-sap-toi.md`
   - `maqr.md`
   - `nhat_ky.md` chỉ sau khi công việc thực sự nghiệm thu

## PHASE 7 — Staging E2E và pilot KAY

### Không được dùng production cho lần nghiệm thu đầu

1. Apply migration vào staging/disposable DB có backup/rollback rõ ràng.
2. Chạy toàn bộ SQL security/concurrency suite.
3. Chạy Flutter test/analyze.
4. Test ít nhất hai điện thoại nhân viên cùng store và một account không quyền checkout.
5. Test Chrome khách + Android/iOS staff.

### Kịch bản E2E bắt buộc

#### TABLE

1. Quét QR TABLE_SHARED duy nhất.
2. Khách submit và nhận QR động.
3. Hai nhân viên cùng quét; chỉ một claim.
4. Claimant chọn bàn đang trống, chỉnh món, gửi Bếp.
5. Module Bàn thiết bị khác hiện đúng món/order.
6. Khách gọi thêm lần hai; request/order mới nhưng cùng session.
7. Nhân viên thêm món thủ công.
8. Checkout toàn bàn; tất cả order hợp lệ paid đúng một lần.

#### COUNTER

1. Quét QR COUNTER, nhận pickup code/QR động.
2. Nhân viên phục vụ không quyền checkout quét và chỉnh; đơn dừng chờ Thu ngân.
3. Thu ngân thanh toán và gửi Bếp.
4. Retry payment/dispatch không trùng.

#### Security/recovery

1. Token hết hạn/replay.
2. Quét token store khác.
3. Membership bị thu hồi sau login.
4. Camera bị từ chối.
5. Mất mạng sau submit/claim/assign/payment/dispatch.
6. App kill sau claim và sau assign.
7. Product đổi giá/unavailable giữa submit và confirm.

### Bằng chứng bàn giao

- Log đã khử secret/PII.
- SQL test output.
- Flutter test/analyze output.
- Video/screenshot E2E TABLE và COUNTER.
- Query DB chứng minh một request–một order, một payment, một dispatch.
- Danh sách migration đã apply staging.
- Rollback/forward-fix plan.

## 11. Lệnh kiểm tra bắt buộc

Điều chỉnh target test theo file thực tế đã tạo, nhưng tối thiểu:

```bash
dart format --output=none --set-exit-if-changed <files-da-sua>
flutter analyze <targets-lien-quan>
flutter test test/core
git diff --check

codegraph affected <moi-file-code-da-sua>
codegraph sync .
codegraph status .
codegraph explore "QR Order V4 entry point repository RPC scanner table assignment checkout kitchen flow"

graphify update .
graphify query "QR Order V4 TABLE_SHARED COUNTER handoff scanner table assignment payment kitchen"
```

Nếu có thay đổi schema/tài liệu quan trọng, phải chạy semantic Graphify update theo công cụ `/graphify . --update` khả dụng trong Antigravity. Không báo hoàn tất nếu graph còn stale hoặc module mới không truy vấn được.

## 12. Definition of Done

Chỉ được báo hoàn tất khi tất cả điều kiện sau đúng:

- [ ] Production schema/migration history đã được xác minh, không giả định.
- [ ] Chỉ có TABLE_SHARED và COUNTER static channel per store.
- [ ] QR handoff token hash, single-use, expiry, rate limit và audit hoạt động.
- [ ] Staff dùng account/membership hiện hành, không POS device pairing QR.
- [ ] Hai nhân viên claim đồng thời chỉ một người thành công.
- [ ] TABLE chọn bàn sau claim và xuất hiện đúng module Bàn.
- [ ] TABLE checkout toàn session, không tạo order QR thứ hai.
- [ ] COUNTER paid trước Bếp và server kiểm tra `pos.checkout`.
- [ ] Nhân viên chỉnh món trước Bếp, server reprice và audit before/after.
- [ ] Retry/crash không trùng order/payment/finance/stock/ticket.
- [ ] RLS/cross-store/permission tests pass.
- [ ] Flutter unit/widget/integration tests pass.
- [ ] Staging E2E TABLE/COUNTER pass trên ít nhất hai điện thoại.
- [ ] CodeGraph up to date và truy ra flow V4.
- [ ] Graphify thấy code–docs–schema V4.
- [ ] Tài liệu khớp source và migration thật.
- [ ] Chưa deploy/apply production khi chưa có phê duyệt riêng.

## 13. Mẫu báo cáo sau mỗi phase

```markdown
## Phase N — <tên phase>

### Hiện trạng/bằng chứng
- ...

### Thay đổi
- File/symbol/migration: ...

### Data flow
- UI → provider/service/repository → RPC/schema → realtime/cache

### Bất biến đã kiểm tra
- store_id/auth/RLS/audit/idempotency: ...

### Kiểm thử
- Lệnh: ...
- Kết quả pass/fail/skip: ...

### CodeGraph/Graphify
- Status/query: ...

### Rủi ro hoặc blocker
- ...

### Quyết định cần Chủ quán duyệt
- ...
```

Không dùng từ “hoàn tất”, “production-ready” hoặc “đã deploy” nếu chưa có bằng chứng tương ứng.

## 14. Prompt khởi động để gửi Antigravity

Sao chép nguyên khối sau:

```text
Hãy làm việc tại repo Quán Nhỏ POS theo kế hoạch `ke-hoach-qr-antigravity-v4.md`.

Bắt buộc gọi workflow `/qn`, đọc `.docs/qr-order-kien-truc-muc-tieu.md`, dùng Graphify một lần để định hướng và CodeGraph để truy source/call path trước khi sửa.

Chỉ thực hiện PHASE 0 trong lượt đầu: audit source, migration, schema thật, auth staff RPC, checkout TABLE, payment/finance/stock/kitchen và blast radius. Tạo `.docs/qr-v4-phase0-audit.md`, chạy kiểm tra read-only, rồi dừng để tôi duyệt.

Không sửa production code/schema trong Phase 0. Không apply database, không deploy, không build release, không push Git và không làm mất thay đổi có sẵn trong worktree. Không dùng POS device pairing/PIN cho QR; kiến trúc mục tiêu là một TABLE_SHARED QR, một COUNTER QR, dynamic handoff QR, staff chọn bàn sau claim, TABLE trả toàn bàn sau và COUNTER trả trước Bếp.
```
