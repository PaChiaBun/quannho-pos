# KẾ HOẠCH GIAO ANTIGRAVITY FIX TRIỆT ĐỂ LỖI THANH TOÁN TRÙNG BILL

## 1. Mục tiêu và nguyên tắc làm việc

Antigravity phải sửa triệt để lỗi một phiên bàn có thể bị thanh toán nhiều lần khi nhân viên click nhanh, mở nhiều checkout sheet, retry do mạng, khởi động lại ứng dụng hoặc có nhiều client cùng thao tác.

Kết quả bắt buộc:

- Một `ban_session` chỉ có đúng một settlement thành công.
- Retry cùng financial intent phải trả lại đúng settlement cũ, không tạo side effect mới.
- Order, order items, finance, kho, loyalty và đóng bàn phải cùng commit hoặc cùng rollback.
- Không tạo trùng `order_number`.
- Không tự động in lại bill khi response là replay.
- Thu ngân, Dashboard, Báo cáo và Thu–Chi phải cùng nguồn số liệu.
- Phải giữ cô lập `store_id`, xác minh quyền `pos.checkout` ở server và ghi audit đầy đủ.

Đây là lỗi P0. Phải làm theo workflow `/qn` và chế độ phân tích sâu. Không chấp nhận vá UI đơn thuần.

Không được tự ý:

- Xóa/sửa dữ liệu production.
- Chạy cleanup bill `060/061/064`.
- Deploy production, build release, upload installer hoặc push Git.
- Sửa lan sang module không liên quan.
- Bỏ qua test concurrency vì thấy UI đã disable nút.

Sau mỗi phase, Antigravity phải báo cáo bằng chứng và dừng chờ duyệt trước khi sang phase kế tiếp.

---

## 2. Tài liệu và source phải đọc trước

Đọc theo thứ tự:

1. `.agents/workflows/qn.md`
2. `AGENTS.md`
3. `.docs/kien-truc-data.md`
4. `.docs/kien-truc.md`
5. `.docs/tinh-nang.md`
6. `.docs/trien-khai-sap-toi.md` — chỉ phần thanh toán, thu chi, báo cáo, kho và audit
7. `lib/screens/ban_screen.dart`
8. `lib/core/repositories/ban_repository.dart`
9. `lib/modules/qr_order/services/settlement_operation_manager.dart`
10. `lib/modules/pos/repository/pos_repository.dart`
11. `lib/modules/pos/providers/pos_providers.dart`
12. `lib/modules/bill_printer/providers/printer_settings_provider.dart`
13. `lib/modules/finance/repository/finance_repository.dart`
14. `lib/core/repositories/dashboard_repository.dart`
15. `lib/core/widgets/order_detail_dialog.dart`
16. `supabase/migrations/20260827_qr_order_v4.sql` — phần `payment_settlements` và `settle_ban_session_v4`
17. Các test QR V4 và test backend concurrency hiện có.

Nếu `.codegraph/` tồn tại, bắt buộc dùng CodeGraph trước khi grep/read source. Dùng tối đa một Graphify query để định hướng, sau đó dùng CodeGraph cho symbol, call path và blast radius.

Trước khi sửa, báo ngắn:

- Triệu chứng và dữ kiện đã xác minh.
- Nguyên nhân gốc.
- Source/RPC hiện đang tham gia luồng.
- Migration và test dự kiến thay đổi.
- Rủi ro dữ liệu và kế hoạch rollback.

---

## 3. Dữ kiện production đã được xác minh

### Cặp `QN-20260901-060` / `QN-20260901-061`

- Cùng cửa hàng, cùng bàn Mang Về 2.
- Cùng món `Mì Cay Kim Chi Bò VN`, cùng tổng `59.000đ`.
- Hai order khác UUID, tạo cách nhau khoảng 12 giây.
- `060` là `cash`; `061` là `transfer`.
- App log ghi hai checkout thành công trên cùng thiết bị thu ngân Võ Anh Thư.
- Cùng một session bàn, nhưng hệ thống tạo hai order và hai dòng doanh thu.

### Cặp `QN-20260901-064` / `QN-20260901-064`

- Cùng cửa hàng, cùng bàn C03.
- Cùng món `Cà Phê pha máy số 1` và `Trà Ổi`, cùng tổng `64.000đ`.
- Hai order khác UUID, tạo cách nhau khoảng 24 giây.
- Cùng `order_number`, cùng `cash`.
- App log ghi hai checkout thành công trên cùng thiết bị thu ngân.
- Lần đóng session thứ hai ghi đè `closed_at`, chứng minh session đã đóng vẫn bị checkout lại.

Quét 76 orders ngày 01/09/2026 chỉ phát hiện hai cặp đáng ngờ nêu trên.

Sai lệch đã biết:

- `060/061`: thừa `59.000đ` tổng doanh thu, đồng thời sai phân bổ cash/bank.
- `064/064`: thừa `64.000đ` tiền mặt.
- Tổng cộng hệ thống bị tăng thừa `123.000đ` và thêm 2 order.

Không được dùng các UUID/dữ kiện trên làm lệnh cleanup tự động.

---

## 4. Nguyên nhân gốc đã xác minh

Luồng bàn thường trong `ban_screen.dart` vẫn chạy client-side:

1. Mỗi checkout tạo `orderId = Uuid().v4()` mới.
2. `order_number` được sinh bằng cách đếm orders trong ngày rồi `+1`.
3. Order `completed` được insert trước khi session đóng.
4. `closeSession()` update theo `session_id`, không có điều kiện `status = open`.
5. Finance idempotency chỉ kiểm tra theo `reference_id = orderId`; UUID mới làm check luôn bỏ lọt lần checkout sau.
6. Kho, finance và loyalty là các side effect client-side, có phần chạy nền/silent fail, không cùng transaction với order.
7. `_isCheckingOut` chỉ là state của một widget và được bật sau khi checkout sheet trả kết quả.
8. Nút `Thanh toán` có thể nhận hai click trước khi guard được bật.
9. Nút `Xác nhận` chưa có submitting/loading guard.
10. Database chưa có unique chung cho `(store_id, order_number)` của order thường.
11. Database chưa bắt buộc mọi thanh toán bàn đi qua atomic settlement RPC.

`settle_ban_session_v4` hiện đã có phần lớn kiến trúc đúng:

- Server-side membership/permission.
- `pg_advisory_xact_lock` theo idempotency key.
- `FOR UPDATE` session.
- Unique settlement theo session.
- Financial fingerprint.
- Authoritative quote.
- Order/finance/kho/loyalty/session trong một transaction.

Vấn đề chính là ứng dụng chỉ gọi RPC này khi session có QR Order; bàn thường vẫn đi đường legacy.

---

## 5. Kiến trúc mục tiêu bắt buộc

### 5.1. Thanh toán bàn

Mọi `ban_session`, có hoặc không có QR Order, phải đi qua một atomic settlement RPC duy nhất.

Nguồn sự thật:

- `payment_settlements`: lần thu tiền của phiên bàn.
- `ban_session_orders`: liên kết settlement/session với canonical orders.
- `finance_records`: bút toán quỹ được tạo đúng một lần từ settlement.
- `orders/order_items`: chi tiết bán hàng.

Không cho client tự insert order bàn, finance auto, stock movement thanh toán hoặc tự đóng session.

### 5.2. Idempotency

Idempotency key phải ổn định theo:

```text
store_id + session_id + normalized financial intent
```

Financial intent tối thiểu gồm:

- Payment method.
- Customer ID.
- Points used.
- Coupon code.
- Surcharge.
- Expected discount/quote.

Quy tắc:

- Cùng key + cùng fingerprint: trả settlement cũ với `is_replay=true`.
- Cùng key + fingerprint khác: `IDEMPOTENCY_CONFLICT`.
- Key khác + session đã settle: `SESSION_ALREADY_SETTLED`.
- Session không `open`: không side effect.

### 5.3. Số order

Không dùng `COUNT + 1`.

Tạo counter atomic theo:

```text
store_id + business_date + prefix
```

Dùng `INSERT ... ON CONFLICT DO UPDATE ... RETURNING` hoặc cơ chế Postgres tương đương. Ngày kinh doanh phải tính theo timezone cửa hàng; pilot KAY mặc định `Asia/Ho_Chi_Minh` nếu chưa có cấu hình timezone.

Sau khi dữ liệu trùng cũ được reconcile, thêm unique:

```sql
UNIQUE (store_id, order_number)
```

### 5.4. In bill

Task key hóa đơn thu ngân phải dựa trên `settlement_id`, không dựa trên `order_number`.

```text
settlement_id:cashier
```

- Dùng `PrintCoordinator` và cache lưu đĩa.
- `is_replay=true` không được auto-print.
- In lại thủ công phải có nút riêng và audit actor/reason.

---

## 6. Phase 0 — Preflight và báo cáo thiết kế

Chưa sửa code trong phase này.

Antigravity phải:

1. Chạy `codegraph status .`.
2. Chạy tối đa một Graphify query định hướng luồng thanh toán bàn → finance → kho → báo cáo.
3. Dùng CodeGraph truy nguyên:
   - `_openCheckout`
   - `_checkout`
   - `BanRepository.closeSession`
   - `BanRepository.settleBanSession`
   - `SettlementOperationManager`
   - `PrintCoordinator.processOrderData`
   - `FinanceRepository.getStats`
   - `DashboardRepository.getTodayStats/_aggregateStats`
4. Kiểm tra catalog production/staging ở chế độ read-only:
   - `payment_settlements`
   - constraint/index liên quan
   - signature và grant của `settle_ban_session_v4`
   - RLS/policy/direct insert hiện hành
5. Xác định bản Windows production hiện đang chạy version/build nào.
6. Lập blast radius file, migration, test và rollout.

Báo cáo phase 0 phải kết luận rõ:

- Có thể tái sử dụng nguyên trạng `settle_ban_session_v4` hay cần RPC version mới.
- Cách giữ tương thích QR TABLE hiện hành.
- Cách giữ định dạng `QN-YYYYMMDD-XXX`.
- Cách chặn client Windows cũ đi đường legacy.
- Cách xử lý network timeout sau commit.

Dừng chờ duyệt.

---

## 7. Phase 1 — Migration database atomic checkout

Chỉ làm sau khi Phase 0 được duyệt.

Tạo migration mới, không chỉnh sửa migration cũ đã phát hành.

Migration tối thiểu phải có:

1. Atomic daily order counter.
2. Settlement uniqueness:
   - Unique `(store_id, idempotency_key)`.
   - Unique `session_id`.
3. Finance uniqueness cho income auto của settlement, sau preflight dữ liệu.
4. RPC settlement dùng cho mọi session bàn.
5. `FOR UPDATE` session trước mọi side effect.
6. Authoritative subtotal từ `ban_session_items`/canonical orders.
7. Server-side validation cho payment, coupon, points, surcharge và `store_id`.
8. Một transaction cho:
   - canonical order/order items
   - settlement
   - finance
   - kho/recipe/topping
   - loyalty
   - đóng session
   - audit
9. Response ổn định gồm:
   - `session_id`
   - `settlement_id`
   - `canonical_order_ids`
   - `order_number` hoặc danh sách order number
   - authoritative subtotal/discount/surcharge/total
   - payment method
   - `is_replay`
10. RPC read-only để reconcile trạng thái khi client không chắc request đã commit.

Phải bảo toàn contract QR V4 đang chạy. Nếu tạo RPC version mới, cần adapter rõ ràng và kế hoạch chuyển cả QR/non-QR.

Không được thêm constraint full unique nếu dữ liệu production cũ chưa sạch và migration sẽ fail. Phải có preflight query và fail-safe rõ ràng.

Dừng chờ duyệt sau khi migration và SQL tests pass trên local/staging.

---

## 8. Phase 2 — Hợp nhất Flutter/Windows checkout

Chỉ làm sau khi Phase 1 được duyệt.

### 8.1. Loại bỏ đường legacy

Trong `ban_screen.dart`:

- Mọi session gọi atomic settlement RPC.
- Không branch theo `hasQrOrders` để chọn client checkout.
- Không còn client insert `orders`, `order_items`, `finance_records`, `stock_movements`, loyalty hoặc gọi `closeSession()` cho checkout.
- Không chạy side effect thanh toán bằng `unawaited`/background silent fail.

### 8.2. Single-flight

Tạo single-flight dùng chung theo `store_id:session_id` ở service/repository, không chỉ trong widget.

Nếu hai widget hoặc hai checkout sheet cùng gọi:

- Không được tạo hai network operations độc lập.
- Lần sau phải chờ/cùng nhận kết quả của operation đang chạy hoặc được server trả replay.

### 8.3. UI guard

- Set `_isOpeningCheckout=true` trước bất kỳ `await` nào.
- Disable nút `Thanh toán` ngay click đầu tiên.
- Không cho mở hai checkout sheet.
- Nút `Xác nhận` có `_isSubmitting`, spinner và disabled state.
- Chặn pop/close trong lúc submit.
- Hiển thị trạng thái `Đang kiểm tra thanh toán` khi response không chắc chắn.

### 8.4. Idempotency persistence

`SettlementOperationManager` phải lưu pending operation vào `SharedPreferences`, scope theo store/session/fingerprint.

Không clear key khi:

- Timeout.
- Network error không rõ server đã commit hay chưa.
- App bị đóng/restart.

Chỉ clear khi server xác nhận kết quả cuối cùng hoặc người dùng hủy intent trước commit.

### 8.5. Printing

- Dùng `PrintCoordinator.processOrderData` hoặc coordinator tương đương với task key theo settlement.
- Không auto-print replay.
- Retry/restart không được tự in thêm bill.

Dừng chờ duyệt sau khi Flutter tests và Windows interaction tests pass.

---

## 9. Phase 3 — Thu ngân, báo cáo và chi tiết bill

1. `FinanceRecordModel` phải giữ `reference_id`/settlement reference.
2. Bấm một dòng Thu–Chi phải mở bằng settlement/order ID, không bằng `order_number.limit(1)`.
3. Popup phải phân biệt:
   - Thu ngân thanh toán (`staff_id`).
   - Nhân viên phục vụ (`waiter_id`).
4. Báo cáo tiền/ca thu ngân phải dựa trên settlement/finance canonical, không cộng mù mọi order completed.
5. Báo cáo số món/order có thể dùng orders, nhưng phải định nghĩa rõ khác với số lần thu tiền.
6. Cash/bank phải lấy từ payment method authoritative của settlement.
7. Nếu settlement replay, UI không được tạo thêm dòng Thu–Chi.

Dừng chờ duyệt.

---

## 10. Phase 4 — Bịt cùng lỗ hổng ở POS bán nhanh

`PosRepository.completeSale()` có cùng kiểu rủi ro: UUID mới, số order client-side và nhiều side effect rời.

Thiết kế RPC `complete_pos_sale_v1` hoặc giải pháp atomic tương đương:

- Idempotency key + cart fingerprint.
- Server-side permission/store isolation.
- Atomic order number.
- Authoritative product/price validation theo contract POS.
- Một transaction cho order/items/finance/kho/loyalty/coupon.
- Replay trả order cũ.
- Client Windows lưu key qua timeout/restart.

Không để module Bàn được fix nhưng POS bán nhanh vẫn có thể tạo bill trùng.

Dừng chờ duyệt.

---

## 11. Phase 5 — Data reconciliation có audit

Phase này chỉ lập script/RPC và test. Không chạy production nếu chưa có xác nhận riêng của chủ quán.

Không hard-delete.

Thiết kế quy trình:

1. Chọn `canonical_order_id` và `duplicate_order_id`.
2. Bắt buộc nhập phương thức thanh toán thực tế.
3. Khóa dữ liệu cần reconcile.
4. Đánh dấu order thừa là duplicate/cancelled và liên kết với canonical order.
5. Ghi reversal finance đúng quỹ cash/bank.
6. Chỉ hoàn kho khi chứng minh side effect kho đã chạy.
7. Chỉ hoàn loyalty khi có transaction thực tế.
8. Không reverse hai lần; reconciliation phải idempotent.
9. Ghi `void_audit_logs` với actor, reason, timestamp và before/after.
10. Có dry-run trả về toàn bộ thay đổi dự kiến trước khi commit.

Đối với `060/061`, phải hỏi thu ngân khách thực trả cash hay transfer. Không tự suy đoán.

Dừng chờ duyệt trước mọi thao tác production.

---

## 12. Bộ test bắt buộc

### 12.1. PostgreSQL concurrency thật

Phải chạy trên PostgreSQL thật, không chỉ mock:

1. 50 request cùng key, cùng session:
   - 1 settlement
   - các request còn lại replay cùng ID
2. 50 request key khác nhau, cùng session:
   - 1 success
   - còn lại `SESSION_ALREADY_SETTLED`
3. Hai payment method khác nhau cùng session:
   - chỉ một intent thắng
4. Timeout sau commit rồi retry cùng key:
   - không có side effect mới
5. Session closed:
   - không order/finance/kho/loyalty mới
6. Hai session khác nhau cùng store:
   - chạy song song bình thường
7. Hai store:
   - không đọc/ghi chéo
8. Quote thay đổi:
   - trả `FINANCIAL_QUOTE_CHANGED`
   - zero side effect trước xác nhận lại
9. Unique order number dưới concurrency.
10. Retry không tạo thêm print job.

Sau mỗi case phải assert số lượng:

- settlement
- canonical order
- finance income
- stock movements/tổng delta
- loyalty transaction
- session close
- audit log

### 12.2. Flutter/widget/Windows

1. Double-click nút `Thanh toán`.
2. Double-click nút `Xác nhận`.
3. Hai checkout sheet/widget cùng session.
4. Hai cửa sổ cùng session.
5. Network timeout trước request.
6. Network timeout sau server commit.
7. Tắt app lúc thanh toán và mở lại.
8. Retry/replay không in lại.
9. Cancel sheet phải giải phóng UI guard đúng cách.
10. Permission bị thu hồi giữa luồng phải fail-closed.

Không báo hoàn tất nếu chưa có concurrency test chứng minh một session chỉ commit một lần.

---

## 13. Rollout production

Chỉ thực hiện khi có yêu cầu riêng.

Thứ tự:

1. Backup/snapshot production.
2. Chạy preflight catalog và duplicate scan.
3. Apply migration additive.
4. Smoke test RPC bằng store/test session riêng.
5. Phát hành Windows build mới.
6. Bắt buộc minimum version cho máy thu ngân.
7. Theo dõi ít nhất một ca pilot KAY.
8. Khóa đường client legacy.
9. Reconcile dữ liệu cũ sau phê duyệt.
10. Thêm constraint cuối cùng sau khi dữ liệu sạch.

Không rollback bằng cách xóa settlement đã commit. Migration phải có kế hoạch rollback code path/feature flag mà không phá audit tài chính.

---

## 14. Observability và cảnh báo

Mỗi checkout log tối thiểu:

- `store_id`
- `session_id`
- `settlement_id`
- canonical `order_id/order_number`
- idempotency key dạng rút gọn/hash, không log secret
- financial fingerprint dạng rút gọn
- `is_replay`
- cashier/user/device
- payment method
- total
- print task status

Cần query/cảnh báo khi:

- Một session có hơn một settlement.
- Trùng `(store_id, order_number)`.
- Một settlement có hơn một finance income.
- Một settlement bị trừ kho nhiều lần.
- Một settlement có nhiều auto print success.
- Replay rate tăng bất thường.

---

## 15. File dự kiến bị ảnh hưởng

Tối thiểu kiểm tra:

- `lib/screens/ban_screen.dart`
- `lib/core/repositories/ban_repository.dart`
- `lib/modules/qr_order/services/settlement_operation_manager.dart`
- `lib/modules/bill_printer/providers/printer_settings_provider.dart`
- `lib/modules/finance/repository/finance_repository.dart`
- `lib/core/repositories/dashboard_repository.dart`
- `lib/core/widgets/order_detail_dialog.dart`
- `lib/modules/pos/repository/pos_repository.dart`
- `lib/modules/pos/providers/pos_providers.dart`
- migration mới trong `supabase/migrations/`
- SQL/backend concurrency tests
- Flutter/widget tests
- `.docs/kien-truc-data.md`
- `.docs/kien-truc.md`
- `.docs/tinh-nang.md`
- `.docs/trien-khai-sap-toi.md`

Không coi danh sách này là quyền sửa toàn bộ file. Chỉ sửa phần cần thiết theo blast radius đã xác minh.

---

## 16. Điều kiện nghiệm thu

Chỉ báo hoàn tất khi chứng minh được:

- Double-click 50 lần vẫn chỉ có 1 settlement/bill.
- Hai client thanh toán cùng session vẫn chỉ 1 success.
- Timeout/restart không tạo thêm order, finance, stock hoặc loyalty.
- Retry/replay không tự in thêm bill.
- Một session không thể bị đóng/thanh toán lần hai.
- Order number không trùng dưới concurrency.
- Thu ngân, Dashboard và Thu–Chi khớp số tiền.
- Cash/bank khớp phương thức authoritative.
- Client Windows cũ không thể đi vòng qua RPC sau rollout bắt buộc.
- Data reconciliation có dry-run, idempotency và audit.
- Test, analyzer/lint liên quan đều pass.
- CodeGraph index mới và không còn stale.
- Graphify đã được cập nhật sau thay đổi code/schema/docs.

---

## 17. Cấu trúc báo cáo Antigravity sau mỗi phase

Antigravity phải báo đúng các mục:

1. Phase đã thực hiện.
2. Root cause/contract được xử lý.
3. File và symbol đã thay đổi.
4. Migration/RLS/constraint/RPC đã thay đổi.
5. Test đã chạy và kết quả cụ thể.
6. Bằng chứng concurrency/idempotency.
7. Rủi ro còn lại.
8. Trạng thái CodeGraph và Graphify.
9. Việc cần chủ quán duyệt trước phase tiếp theo.

Không được chỉ báo “đã fix double-click” nếu chưa chứng minh database chỉ commit đúng một lần.

---

## 18. Prompt khởi động để gửi Antigravity

```text
Hãy làm việc tại repo Quán Nhỏ POS theo kế hoạch `ke-hoach-fix-trung-bill-antigravity.md`.

Đây là lỗi P0 thanh toán trùng bill trên máy thu ngân Windows. Bắt buộc đọc `.agents/workflows/qn.md`, `AGENTS.md` và toàn bộ mục “Tài liệu và source phải đọc trước” trong kế hoạch. Dùng tối đa một Graphify query để định hướng, sau đó dùng CodeGraph để truy nguyên source/call path/blast radius.

Chỉ thực hiện Phase 0: preflight, kiểm tra source/schema/RPC/test và lập báo cáo thiết kế có bằng chứng. Chưa sửa code, chưa tạo migration, chưa thay đổi dữ liệu, chưa deploy, chưa build release và chưa push Git. Sau Phase 0 phải dừng chờ tôi duyệt.
```
