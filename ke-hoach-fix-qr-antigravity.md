# KẾ HOẠCH GIAO ANTIGRAVITY FIX MODULE QR ORDER V3

> Ngày lập: 13/08/2026  
> Trạng thái: Kế hoạch thực thi — chưa sửa code, chưa chạy migration, chưa deploy  
> Mục tiêu: đưa QR Order V3 về một contract duy nhất, chạy được trên staging, có test chống hồi quy, sau đó mới xin phép triển khai production.

## 1. Mệnh lệnh thực thi

Antigravity phải làm tuần tự theo từng phase trong tài liệu này. Sau mỗi phase phải báo cáo kết quả và dừng chờ duyệt. Không tự chuyển phase, không tự deploy production, không sửa lan sang module khác.

Thứ tự bắt buộc:

```text
Đọc context
  -> Chụp schema thực tế (read-only)
  -> Khóa contract QR V3
  -> Sửa schema/RPC trên code
  -> Test SQL trên staging
  -> Sửa Flutter theo contract đã khóa
  -> Test end-to-end staging
  -> Xin duyệt production
```

Không được sửa Flutter trước khi contract SQL/RPC của Phase 1 được chốt.

## 2. Tài liệu phải đọc trước khi làm

Đọc đầy đủ theo đúng thứ tự:

1. `.agents/workflows/qn.md`
2. `.docs/tong-quan.md`
3. `.docs/kien-truc.md`
4. `.docs/kien-truc-data.md`
5. `.docs/tinh-nang.md`
6. `.docs/lam-viec.md`
7. `nhat_ky.md` — mục mới nhất
8. `maqr.md`
9. `qr_auth_compatibility_plan.md`
10. `qr_supabase_actual_architecture_audit.md`
11. `supabase/qr_v3_schema_manifest.md`
12. `supabase/qr_v3_static_qc_report.md`
13. `ke-hoach-fix-qr-antigravity.md`

Sau khi đọc, Antigravity báo ngắn:

- Hiểu luồng khách, nhân viên, bàn/quầy và bếp như thế nào.
- Production đang thiếu những RPC nào.
- Nguồn quyền thực tế đang nằm ở đâu.
- Worktree đang bẩn ở những file nào.
- Phase hiện tại được phép làm gì và không được làm gì.

Không viết code trước báo cáo này.

## 3. Phạm vi được phép và vùng cấm

### Được phép sửa

- `lib/modules/qr_order/**`
- `lib/core/services/pos_device_token_service.dart`
- Phần logout/store switch liên quan trực tiếp QR trong `lib/core/services/user_auth_service.dart`
- Route QR liên quan trực tiếp trong `lib/main.dart`
- Danh sách quyền QR liên quan trực tiếp trong `lib/core/services/staff_service.dart`
- Migration QR mới trong `supabase/migrations/`
- Test QR mới trong `test/modules/qr_order/` và `supabase/tests/`
- Tài liệu QR và mục nhật ký của chính đợt sửa này sau khi hoàn tất phase

### Không được sửa nếu chưa có phê duyệt riêng

- Bill Printer ngoài phần đọc contract station hiện có
- POS, Bàn, Bếp, Kho hoặc Settings không liên quan trực tiếp điểm tích hợp QR
- Auth toàn hệ thống ngoài cleanup phiên QR
- Migration lịch sử không thuộc QR
- File đang có thay đổi của người dùng nhưng không thuộc nhiệm vụ
- Không format toàn project, không rename hàng loạt, không refactor thẩm mỹ
- Không commit, push, deploy hoặc chạy SQL production

Nếu cần chạm file ngoài allowlist, dừng và báo lý do, file, dòng và thay đổi tối thiểu dự kiến.

## 4. Quy tắc chống vòng lặp và phát sinh lỗi

1. Mỗi lỗi chỉ có một nguồn sửa. Không vá cùng một quy tắc ở cả UI, repository và SQL nếu SQL có thể làm nguồn sự thật.
2. Không tạo RPC V4, V5 hoặc tên tạm. Giữ duy nhất bộ tên `_v3` hiện có và thay contract có kiểm soát.
3. Không tạo fallback dữ liệu giả như `#Q01`, giá `0`, station `nong` hoặc báo thành công khi chưa có dữ liệu thật.
4. Không `catch` rồi nuốt lỗi. Repository phải trả lỗi có mã ổn định; UI chuyển mã lỗi thành thông báo thân thiện.
5. Không sửa migration cũ theo kiểu chắp vá rồi thêm hotfix nối tiếp. Sau Phase 0 phải tạo chuỗi migration canonical mới, forward-only, có preflight và test.
6. Không dùng direct table mutation từ Flutter cho QR. Mọi thay đổi trạng thái phải qua protected RPC.
7. Không copy logic gửi bếp. Phải đối chiếu luồng POS/Bàn hiện hành và dùng cùng quy ước station, session, ticket, round và audit.
8. Một phase chỉ hoàn thành khi test của phase đó xanh. Nếu test đỏ, sửa nguyên nhân gốc; không nới assertion để cho qua.
9. Tối đa một lượt sửa lại trong cùng phase sau review. Nếu vẫn thất bại, dừng, báo nguyên nhân và đề xuất quyết định; không tiếp tục vá đoán.
10. Mỗi phase phải có diff review. Loại bỏ thay đổi ngoài phạm vi trước khi bàn giao.

## 5. Contract QR V3 phải khóa

Antigravity lập file `supabase/qr_v3_canonical_contract.md` trong Phase 1. Contract tối thiểu phải xác định:

### State machine

```text
pending_staff -> processing -> confirmed -> sent_kitchen
      |              |             |
      +--------------+-------------+-> rejected
pending_staff/processing -> expired (theo chính sách timeout)
```

- Không gửi thẳng từ `pending_staff` xuống bếp.
- `confirmed` phải reject được trước khi đã gửi bếp để không tạo đơn kẹt.
- Mọi transition dùng row lock, kiểm tra actor, store và quyền phía server.
- RPC trả `success`, `error_code`, `message` ổn định; lỗi nghiệp vụ không phụ thuộc parse chuỗi exception.

### Kiểu dữ liệu canonical

- `qr_channels.table_id`: UUID nullable.
- `qr_requests.table_id`: UUID nullable.
- `qr_request_items.modifiers_json`: JSONB, mặc định `[]`.
- `quantity`: integer dương.
- `subtotal`: numeric và luôn bằng `unit_price * quantity` tại thời điểm snapshot.
- `tracking_token`: token ngẫu nhiên, không log raw token.
- `idempotency_key`: unique theo channel, retry cùng key trả lại cùng request.
- `pickup_code`: server sinh atomically cho counter, không được dùng fallback giả ở Flutter hoặc SQL.

### URL public canonical

```text
https://quannho.lpm.vn/pos/#/qr_order?code={code}
```

- Custom URL có thể dùng placeholder `{code}`.
- URL phải được tạo bằng `Uri`, không nối chuỗi thủ công.
- Route public phải mở thẳng `CustomerQrOrderScreen` và không yêu cầu đăng nhập.

### Permission canonical

- Action keys giữ duy nhất tám key `qr_order.*` đang có.
- Owner override chỉ sau khi xác minh membership đúng store.
- Nhân viên phải được cấp quyền từ nguồn quyền thực tế đã chứng minh bằng schema/code production.
- UI cấp quyền và SQL resolver phải đọc cùng một nguồn; không được duy trì hai nguồn quyền song song.
- Token POS phải bị revoke/clear khi logout, đổi nhân viên hoặc đổi store.

### Kitchen canonical

- Station lấy từ `products.station_code`, sau đó normalize theo quy ước hiện hành (`nong`, `bar`/`nuoc`). Không hardcode toàn bộ về `nong`.
- Việc tạo order, session, session items, ticket items và chuyển `sent_kitchen` nằm trong một transaction.
- Chống tạo hai open session cho cùng bàn và chống trùng ticket round khi hai request chạy đồng thời.
- Price/availability thay đổi phải trả lỗi có hướng xử lý và vẫn cho phép reject; không để request kẹt ở `confirmed`.

## 6. Các phase giao việc

## PHASE 0 — Chụp hiện trạng và bảo vệ worktree

### Mục tiêu

Không sửa gì. Chứng minh schema và trạng thái deploy thực tế trước khi thiết kế migration.

### Việc phải làm

1. Chạy `git status --short`; ghi rõ file bẩn có trước nhiệm vụ.
2. Liệt kê toàn bộ file QR Flutter, migration, RPC, test và điểm tích hợp.
3. Kiểm tra read-only production/staging:
   - Bảng/cột/type/constraint/index thực tế.
   - Chữ ký và quyền execute của toàn bộ RPC `_v3`.
   - RLS/grants của `qr_*`, session token và pairing tables.
   - Kiểu/cột thực tế của `products`, `ban_dining_tables`, `ban_sessions`, `kitchen_tickets`.
   - Nguồn quyền thực tế: `staff_members`, `store_members` hay `app_settings`.
4. Xác minh production URL public và route `/pos/#/qr_order` bằng request không ghi dữ liệu.
5. Nếu staging chưa truy cập được, dừng phase với trạng thái `BLOCKED_STAGING`; không lấy production làm nơi thử migration.

### Đầu ra

- `supabase/qr_v3_runtime_schema_snapshot.md`
- Không thay đổi code/migration.
- Báo cáo điểm khác nhau giữa repo và DB thật.

### Điều kiện hoàn thành

- Có bằng chứng schema runtime.
- Không có write lên database.
- Chủ dự án duyệt snapshot và cho sang Phase 1.

## PHASE 1 — Khóa contract và thiết kế migration

### Mục tiêu

Chốt một kiến trúc duy nhất trước khi viết SQL hoặc Flutter.

### Việc phải làm

1. Tạo `supabase/qr_v3_canonical_contract.md` theo Mục 5.
2. Lập bảng mapping từng field: DB type -> RPC JSON -> Dart type.
3. Lập matrix RPC gồm actor, input, output, permission, state đầu/cuối, audit và idempotency.
4. Lập migration plan forward-only dựa trên snapshot runtime.
5. Chọn chính xác nguồn permission; không ghi “fallback nhiều nguồn”.
6. Chọn cơ chế pickup code atomic và điều kiện unique.
7. Chọn cơ chế serialize session/ticket theo đúng schema thật.
8. Chốt cách route web ở `/pos/` và custom URL.

### Tên migration dự kiến

```text
supabase/migrations/20260813090000_qr_v3_schema_contract.sql
supabase/migrations/20260813091000_qr_v3_rpc_contract.sql
supabase/migrations/20260813092000_qr_v3_security_permissions.sql
```

Tên có thể điều chỉnh theo timestamp hiện hành, nhưng không được tạo chuỗi hotfix rời rạc.

### Điều kiện hoàn thành

- Contract không còn cột/type mâu thuẫn.
- Không còn quyết định “để lúc code tính sau”.
- Chưa viết migration thực thi.
- Chủ dự án duyệt contract.

## PHASE 2 — Sửa schema, RPC và permission trong repository

### Mục tiêu

Tạo bộ migration canonical có thể cài trên staging từ đúng schema thực tế.

### Việc phải làm

1. Viết preflight fail-fast:
   - Kiểm tra environment là staging.
   - Kiểm tra dependencies và kiểu cột.
   - Kiểm tra dữ liệu status/duplicate trước khi đổi constraint/index.
2. Schema migration:
   - Xử lý constraint status cũ trước khi thêm constraint canonical.
   - Đồng bộ UUID/JSONB/subtotal/idempotency/pickup code.
   - Không drop dữ liệu im lặng.
3. Public RPC:
   - Menu chỉ trả channel active và tôn trọng setting table/counter.
   - Server xác minh món, topping, giá, availability và store.
   - Submit sinh tracking token, idempotency và pickup code atomic.
   - Status không lộ dữ liệu ngoài tracking token hợp lệ.
4. Staff RPC:
   - Token hash, expiry, revoked, device/store/actor đều được kiểm tra.
   - State transition đúng contract và có row lock.
   - Reject cho phép từ `confirmed` trước khi sent.
   - Gửi bếp atomic, route station thật, chống race session/round.
5. Permission:
   - Resolver và Flutter permission UI dùng cùng nguồn.
   - Manager/staff có thể được cấp đúng tám QR actions.
6. Grants/RLS:
   - `anon` không được direct CRUD bảng QR.
   - Chỉ RPC public/staff cần thiết được execute.
7. Viết SQL test chạy trong transaction và rollback dữ liệu test.

### Test bắt buộc

Tạo tối thiểu:

```text
supabase/tests/qr_v3_schema_contract_test.sql
supabase/tests/qr_v3_security_test.sql
supabase/tests/qr_v3_state_machine_test.sql
supabase/tests/qr_v3_kitchen_dispatch_test.sql
supabase/tests/qr_v3_concurrency_test.sql
```

Test phải phủ:

- Table và counter submit.
- Hai retry cùng idempotency key chỉ tạo một request.
- Hai counter request đồng thời không trùng pickup code.
- Sai token, token hết hạn, token khác store, thiếu quyền.
- Toàn bộ transition hợp lệ và transition cấm.
- Reject từ confirmed.
- Món đổi giá/ngừng bán không làm request kẹt.
- Station nóng/bar đúng.
- Hai request cùng bàn không tạo hai open session hoặc trùng round.
- Một lỗi giữa dispatch rollback toàn transaction.

### Điều kiện hoàn thành

- Static SQL check sạch.
- Tất cả SQL test xanh trên staging.
- Không chạy production.
- Diff chỉ gồm SQL/test/tài liệu đã cho phép.

## PHASE 3 — Sửa Flutter theo contract đã khóa

### Mục tiêu

Flutter chỉ phản ánh contract server, không tự bù dữ liệu hoặc đoán trạng thái.

### Nhóm việc A — URL và customer flow

- Tách URL builder thành hàm/service thuần có unit test.
- Sinh URL canonical `/pos/#/qr_order?code=...` bằng `Uri`.
- Bảo đảm deep-link mở màn khách không qua auth.
- Thêm submit lock chống double tap.
- Idempotency key tồn tại xuyên suốt một lần retry, chỉ đổi khi tạo cart/order mới.
- Polling không chồng request, dừng ở terminal state và khi widget dispose/background.
- Không hiển thị exception/PostgREST thô.
- Hiển thị pickup code server trả; nếu thiếu thì báo dữ liệu lỗi, không dùng `#Q01`.

### Nhóm việc B — staff queue và state

- Fetch một contract active queue có thứ tự thời gian rõ ràng; không ghép ba list gây ưu tiên sai.
- Polling theo session/store, pause background, có exponential backoff.
- UI chỉ hiện action hợp lệ cho state hiện tại.
- Reject confirmed theo contract.
- Hiển thị lỗi price/availability có hướng xử lý, không để modal trong trạng thái giả thành công.

### Nhóm việc C — token và permission

- Save token session nhất quán; thất bại phải cleanup phần đã ghi.
- Phân biệt device identity với active staff session.
- Logout/store switch/staff switch: revoke best-effort phía server và luôn clear raw token local trong `finally`.
- Expiry mới null không được giữ expiry cũ.
- Thêm tám QR action keys và metadata UI theo nguồn permission đã khóa.
- Bổ sung UI tạo pairing code cho owner/manager nếu contract giữ pairing flow.

### Nhóm việc D — settings, print và logging

- `saveSettings` phải throw/return failure thật; UI chỉ báo thành công sau khi server xác nhận.
- Switch table/counter phải có hiệu lực server-side.
- Validate kích thước batch PDF và custom URL.
- QR PDF có font fallback offline hoặc asset font; không phụ thuộc bắt buộc vào mạng.
- Log user action cho quản lý channel, settings, pairing, revoke và in QR; tuyệt đối không log token/PIN/password.

### Nhóm việc E — bảo mật TLS

- Xóa global `badCertificateCallback => true` khỏi release.
- Nếu development cần chứng chỉ local, chỉ cho phép bằng compile-time debug guard và không tồn tại trong release path.

### Test Flutter bắt buộc

```text
test/modules/qr_order/qr_url_builder_test.dart
test/modules/qr_order/qr_order_model_test.dart
test/modules/qr_order/qr_order_repository_test.dart
test/modules/qr_order/customer_qr_order_controller_test.dart
test/modules/qr_order/staff_qr_queue_controller_test.dart
test/modules/qr_order/pos_device_token_service_test.dart
test/modules/qr_order/qr_permission_test.dart
```

Ngoài unit test, chạy:

```bash
dart format --output=none --set-exit-if-changed <chỉ các file đã sửa>
flutter analyze <phạm vi QR và điểm tích hợp>
flutter test test/modules/qr_order
flutter test
git diff --check
```

### Điều kiện hoàn thành

- Analyze không có error/warning mới trong phạm vi.
- Toàn bộ test QR và full suite xanh.
- Không còn fallback `#Q01`, hardcode URL `/goi-mon`, direct QR table mutation hoặc global bad certificate override.
- Không sửa lan sang module ngoài allowlist.

## PHASE 4 — End-to-end trên staging

### Mục tiêu

Chứng minh luồng thật trên Web, mobile/desktop POS và database staging.

### Kịch bản bắt buộc

1. Owner tạo/pair thiết bị.
2. Cấp quyền QR cho manager, cashier và waiter; kiểm tra deny khi thiếu từng action.
3. In một QR bàn và một QR quầy.
4. Mở QR bằng trình duyệt ẩn danh và điện thoại.
5. Đặt món có topping, note và quantity > 1.
6. Retry cùng idempotency key.
7. Claim -> confirm -> gửi bếp.
8. Kiểm tra đúng table/counter, pickup code, station nóng/bar, order, session, ticket và audit log.
9. Reject ở pending, processing và confirmed.
10. Thử price change, unavailable, token hết hạn, logout, đổi store và hai request đồng thời.
11. Tắt QR bàn/quầy rồi xác minh public RPC thực sự từ chối.
12. Kiểm tra không có direct table access bằng anon.

### Bằng chứng bàn giao

- `supabase/qr_v3_staging_qc_report_20260813.md`
- Log test đã che token/credential.
- Screenshot/video ngắn cho customer flow và staff flow.
- Query đối soát số record trước/sau.
- Danh sách lỗi còn lại theo P0–P3.

### Điều kiện hoàn thành

- Không còn P0/P1.
- P2 còn lại phải được chủ dự án chấp thuận rõ.
- Staging chạy ổn định tối thiểu một vòng test hoàn chỉnh.
- Dừng chờ duyệt production.

## PHASE 5 — Chuẩn bị và triển khai production

### Cấm tự động

Phase này chỉ được bắt đầu khi chủ dự án viết rõ: “được phép deploy QR production”.

### Trước deploy

1. Backup/snapshot database.
2. Chụp schema và row count các bảng bị tác động.
3. Chạy production preflight read-only.
4. Xác nhận đúng commit/diff đã pass staging; không sửa code trong lúc deploy.
5. Chuẩn bị rollback đã test trên staging.
6. Chốt maintenance window và người quan sát POS/Bếp.

### Thứ tự deploy

1. Migration schema contract.
2. Migration RPC contract.
3. Migration security/permission.
4. Postflight SQL read-only.
5. Deploy Flutter Web/POS build đã test.
6. Smoke test một QR test riêng, không dùng QR bàn thật trước khi pass.
7. Theo dõi lỗi, duplicate, latency và audit log.

### Tiêu chí rollback

- RPC thiếu/không gọi được.
- Sai store isolation hoặc permission.
- Duplicate order/session/ticket.
- Dispatch sai station hoặc sai tổng tiền.
- Customer route 404.
- Error rate vượt ngưỡng đã chốt trong maintenance window.

Không “hotfix tại production”. Nếu smoke test fail, rollback về bản đã biết tốt, phân tích ở staging rồi tạo bản sửa mới.

## 7. Definition of Done toàn module

Module chỉ được coi là hoàn thành khi đáp ứng đồng thời:

- QR đã in mở đúng customer route production.
- Customer load menu, submit và theo dõi trạng thái bằng public RPC.
- Counter có pickup code thật, không trùng trong phạm vi vận hành.
- Nhân viên có quyền phù hợp claim/confirm/reject/send được; thiếu quyền bị deny.
- Logout/đổi nhân viên/đổi store không kế thừa token cũ.
- State machine không có đường kẹt ở confirmed.
- Gửi bếp atomic, đúng station và không tạo session/round trùng khi concurrency.
- Settings table/counter có hiệu lực server-side.
- Anonymous không direct CRUD được bảng QR.
- Release không bỏ qua TLS certificate validation.
- Có test SQL, test Flutter và E2E staging chống hồi quy.
- Không còn P0/P1; P2 được ghi nhận và duyệt.
- Tài liệu cùng `nhat_ky.md` phản ánh đúng trạng thái đã thực thi, không ghi “đã deploy” nếu chưa deploy.

## 8. Mẫu báo cáo bắt buộc sau mỗi phase

Antigravity phải báo đúng bảy mục:

1. Phase vừa hoàn thành.
2. Việc đã làm.
3. File đã thay đổi.
4. Migration/test đã chạy ở môi trường nào.
5. Kết quả test cụ thể.
6. Rủi ro hoặc blocker còn lại.
7. Đề nghị duyệt sang phase nào.

Sau đó dừng. Không tự động bắt đầu phase kế tiếp.

## 9. Prompt khởi động gửi cho Antigravity

```text
Bạn đang làm dự án Quán Nhỏ POS tại:
/Users/banhbao/Quan Nho/quan_nho

Hãy đọc và tuân thủ tuyệt đối:
1. .agents/workflows/qn.md và toàn bộ context workflow yêu cầu
2. maqr.md
3. qr_auth_compatibility_plan.md
4. qr_supabase_actual_architecture_audit.md
5. supabase/qr_v3_schema_manifest.md
6. supabase/qr_v3_static_qc_report.md
7. ke-hoach-fix-qr-antigravity.md

Nhiệm vụ hiện tại chỉ là PHASE 0 — Chụp hiện trạng và bảo vệ worktree.

Không viết code, không sửa migration, không chạy SQL ghi dữ liệu, không deploy,
không commit/push và không format toàn project.

Yêu cầu quan trọng:
- Giữ nguyên mọi thay đổi có sẵn của người dùng.
- Production hiện thiếu các RPC QR V3 và URL /goi-mon đang 404.
- Không dùng production làm staging.
- Nếu staging không truy cập được, báo BLOCKED_STAGING và dừng.
- Mọi kết luận phải có bằng chứng file/dòng hoặc schema runtime.

Hãy hoàn thành đúng đầu ra Phase 0, báo cáo theo mẫu bảy mục và dừng chờ duyệt.
```
