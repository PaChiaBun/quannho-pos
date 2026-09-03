# Nhật ký tiếp tục fix trùng bill — 2026-09-02

## Checkpoint mới nhất — sau rà soát và chạy PostgreSQL thật

Các mục bên dưới là lịch sử, không dùng trạng thái “chưa có PostgreSQL” làm hiện trạng nữa.

- Đã cài PostgreSQL 17.11 bằng Homebrew và psycopg2 trong virtualenv tạm. Chỉ chạy cluster riêng `/private/tmp/qn-pg-review.jHHjbQ/data` trên loopback; không bật brew service, không truy cập production.
- PostgreSQL runtime gate **PASS** cả hai database có/không coupons, SQL integration và 7 tests concurrency/auth mỗi nhánh. Dùng hàm membership V4 thật trích từ migration, không còn dùng mock permissive. Hai database/roles test đã được cleanup.
- Sửa replay/reconcile bỏ sót record có NULL; món hủy không tính tiền/trừ kho; canonical order totals/điểm phân bổ khớp settlement; bill >=1000 không bị cắt số.
- Unique finance chuyển sang `checkout_reference_id` do trigger phân loại, không chặn topup customer lặp; dashboard bỏ auto-income không gắn order/settlement completed.
- POS đóng/ghi liên kết phiên bếp cùng transaction; khóa phiên chung với Bàn; guard thay đổi tiền/món sau khi paid, vẫn cho KDS cập nhật tiến độ. Session có món hủy/giỏ khác bị chặn để đối soát, không tự bỏ session ID.
- Manual discount POS kiểm tra quyền server, audit; giá từng món được đối chiếu; ví trừ trong transaction. Test lỗi finance xác nhận rollback ví/order/kho/phiên.
- Pending POS lưu full intent, giữ đến acknowledge; có nút phục hồi kể cả giỏ trống. Legacy key thiếu intent dùng `reconcile_pos_sale_v1`, không thấy kết quả thì giữ khóa, không xóa mù.
- Bỏ timeout ngoài Future; cả desktop panel/mobile dùng `openPosCheckout` có guard đồng bộ trước await. In bếp chỉ gửi line chưa gửi, replay không auto-print; manual reprint có log.
- Test đã qua: **90 Flutter tests**, **67 Python static/unit tests**, runtime SQL + **7 tests x 2 database**. Thay đổi cuối gom hai entrypoint UI đang được kiểm tra lại riêng.
- Analyzer không có error, còn warning/info legacy/style. Không sửa lan rộng để làm sạch warning.
- Graphify structural đã cập nhật 8.999 nodes; semantic docs/SQL chưa refresh. CodeGraph sync báo already up to date nhưng status vẫn thấy 1 added + 9 modified: cần rebuild index ở lần tiếp theo, không coi graph đã fresh.
- Chưa deploy/build/push; chưa sửa bill lịch sử. Trước rollout cần schema/RLS staging khớp production, Windows/máy in thật và luồng refund/hủy bill đã paid với guard mới.
- Người dùng yêu cầu chốt phạm vi, tránh vòng sửa lan rộng. Không bổ sung feature/refactor mới; chỉ xác minh và chốt các sửa đổi hiện có.

## Cập nhật phiên tiếp tục (đọc mục này trước; các mục dưới là checkpoint cũ)

Đã tiếp tục sau khi đọc workflow và kiểm tra source/graph:

- POS RPC đã hỗ trợ ví: customer store-scoped `FOR UPDATE`, bonus cap/expiry, fail-closed thiếu số dư/schema, cập nhật số dư + balance_transactions trong cùng transaction. Snapshot `wallet_real_used/wallet_bonus_used` được lưu để replay.
- Flutter đã bỏ `spendWallet()` sau commit; cả hai chỗ dựng bill đều dùng subtotal/discount/total server, không ghi đè bằng cart total.
- POS persistent manager serializes key creation trong cùng isolate; 50 concurrent callers dùng cùng key. Không ghi đè key cũ khi đổi intent hoặc dữ liệu pending hỏng. Xóa key theo exact idempotency key; chỉ xóa sau success hoặc structured rejection trước commit.
- Cart quy đổi points theo `loyaltyRedeemRate`, cap số điểm theo giá trị đơn; checkout sheet đọc tỷ lệ theo store. Wallet selection xóa điểm đã chọn. RPC thêm `p_expected_total` để từ chối quote khác số tiền xác nhận.
- Dashboard không phân loại wallet thành bank; báo cáo voucher mở theo UUID.
- UI chặn tương tác/đóng sheet khi đang xử lý.
- Baseline PostgreSQL test đã thêm schema ví; SQL suite có wallet success/replay snapshot/expiry/insufficient/customer-required/cross-store/quote-change. **SQL này chưa chạy runtime.**
- Test chạy thực tế: 86 Flutter tests pass; 62 Python gate/schema tests pass và 5 static wallet contract tests pass. Static/unit mocks không phải PostgreSQL thật.
- Analyzer cuối phiên: không có error; 13 warning/info (unused legacy, casts/style/deprecation), exit 2 do warnings. `git diff --check` và `bash -n` pass.
- CodeGraph sync/status mới: 276 files, 7.636 nodes, index up to date; đã truy vấn xác nhận manager mới và liên kết test. Graphify structural update: 8.945 nodes; query thấy PosSaleOperationManager. Semantic extraction cho docs/SQL chưa được làm mới qua LLM, không coi structural update là xác minh schema/runtime.

Việc còn lại trước khi gọi là hoàn thiện:

1. Máy vẫn không có docker/podman/psql/postgres; cần runtime PostgreSQL cô lập để chạy gate thật và sửa lỗi phát hiện từ runtime, không deploy trực tiếp.
2. Cần test concurrency ví bằng nhiều kết nối DB thật, fault injection rollback khi balance_transactions/finance insert lỗi và kiểm thử Windows/máy in.
3. Pending POS khác intent hiện fail-closed; cần UX phục hồi/reconcile nếu người dùng đã làm mất giỏ cũ sau restart (không hướng dẫn xóa pending key để tiếp tục).
4. Rà soát migration unique auto-income với các nghiệp vụ khác: nạp ví cũ dùng customer ID làm reference nên có thể nhiều dòng hợp lệ; không tự xóa các dòng đó để vượt preflight.
5. Kiểm tra giảm giá thủ công POS (RPC hiện chỉ chấp nhận discount authoritative từ coupon/points), luồng POS đã gửi bếp/table, quyền server và source schema thật trước release.
6. Tiền nạp ví và tiền tiêu ví là hai sự kiện khác nhau; dashboard/fund queries cần E2E với dữ liệu thật để không cộng đôi, không gộp wallet vào cash/bank.
7. Bill lịch sử 060/061 chưa được sửa; cần xác nhận thanh toán thực trước mọi điều chỉnh production.

Lệnh test mới:

```bash
flutter test --no-pub test/core/pos_atomic_checkout_test.dart test/core/settlement_v5_client_test.dart test/core/qr_order_v4_test.dart test/core/comprehensive_fix_test.dart
python3 -m unittest test.backend.test_phase1_docker_gate_static test.backend.test_phase1_docker_gate_behavior test.backend.test_phase1_gate_runner_unit test.backend.test_settlement_v5_sql_schema_validator test.backend.test_pos_wallet_contract
```

## 1. Mục tiêu và giới hạn

- Sự cố P0: thu ngân Windows có thể bấm thanh toán nhiều lần, tạo nhiều `orders`, nhiều `finance_records` và in bill trùng.
- Trường hợp đối chiếu: `QN-20260901-060` / `QN-20260901-061` cùng bàn, cùng món, cùng 59.000đ, cách nhau khoảng 12 giây nhưng khác UUID và phương thức thanh toán.
- Bill trùng **có tính vào doanh thu/thu ngân** nếu đã tạo dòng `finance_records` auto-income thứ hai.
- Phạm vi hiện tại: sửa mã nguồn và test. **Chưa deploy database production, chưa build release, chưa push Git.**
- Phải đọc `.agents/workflows/qn.md` trước khi làm tiếp và dùng CodeGraph trước khi grep/đọc code vì repo có `.codegraph/`.

## 2. Kết luận nguyên nhân

- UI/client cũ không khóa thao tác đủ sớm và checkout gồm nhiều side effect rời rạc.
- Hai lần bấm/retry có thể tạo hai order UUID khác nhau; server không có một idempotency key bền vững và transaction duy nhất bao trọn order, tài chính, kho, loyalty/coupon.
- Chỉ debounce UI không đủ. Cần đồng thời: UI guard + persistent idempotency + single-flight + RPC atomic + unique constraints + replay không side effect/in lại.

## 3. Những phần đã thực hiện

### Phase 1 — PostgreSQL atomic/idempotency

- Migration mới: `supabase/migrations/20260902_atomic_settlement_v5.sql`.
- Có RPC `settle_ban_session_v5`, `reconcile_ban_settlement_v1`, `complete_pos_sale_v1`.
- Có bảng/counter/idempotency, unique index finance auto-income, coupon redemption, transaction order/items/finance/kho/loyalty.
- Ghi `cashier_staff_id` vào `payment_settlements` để báo cáo thu ngân dùng dữ liệu canonical.
- Có SQL test và Python harness trong `supabase/tests/` và `test/backend/`.
- Docker runner đã được harden, có static/behavior/unit tests và cleanup guard.

### Phase 2 — checkout bàn trên Flutter

- `lib/modules/qr_order/services/settlement_operation_manager.dart`: persistent key theo store/session, SHA256 fingerprint, fail-closed khi lưu key thất bại.
- `lib/core/repositories/ban_repository.dart`: gọi V5, single-flight, reconcile khi kết quả mạng không chắc chắn.
- `lib/screens/ban_screen.dart`: guard trước await, quote reconfirmation, dùng dữ liệu server, replay không tự in, chỉ xóa key sau server success/replay.
- Legacy checkout đã bị loại khỏi executable path và hiện nằm trong block comment để review.
- `lib/modules/bill_printer/providers/printer_settings_provider.dart`: in theo task key bền vững `<settlement_id>:cashier`.

### Phase 3 — finance/report/detail

- `FinanceRecordModel` parse `reference_id`.
- `finance_screen.dart` mở chi tiết bằng canonical reference ID.
- `order_detail_dialog.dart` hỗ trợ `orderId`, resolve settlement sang toàn bộ order liên quan, phân biệt thu ngân thanh toán và nhân viên phục vụ.
- `dashboard_repository.dart` lấy doanh thu/cash/bank/cashier từ canonical auto-income + settlement/order metadata; order count vẫn lấy từ orders.

### Phase 4 — POS bán nhanh

- `lib/modules/pos/services/pos_sale_operation_manager.dart`: persistent POS idempotency theo store + cart fingerprint.
- `lib/modules/pos/repository/pos_repository.dart`: `PosSaleResult`, gọi `complete_pos_sale_v1`, single-flight, chỉ clear key sau success/replay.
- `lib/modules/pos/providers/pos_providers.dart`: guard `isProcessing`, trả canonical result.
- `lib/modules/pos/screens/checkout_sheet.dart`: dùng order number/total server, replay không tự in.
- `lib/modules/qr_order/repository/qr_order_repository.dart`: chuyển sang settlement V5.
- Legacy POS sale đã bị loại khỏi executable path và nằm trong block comment.

### Tài liệu

- `.docs/duplicate-bill-settlement-v5.md`
- `ke-hoach-fix-trung-bill-antigravity.md`

## 4. Kiểm thử đã chạy và đạt

- Python Phase 1 static/behavior/unit: **62 passed**.
- Schema validator: **9 passed**.
- Flutter tests chọn lọc (`settlement_v5_client_test.dart`, `qr_order_v4_test.dart`, `comprehensive_fix_test.dart`): **76 passed**.
- `flutter analyze` trên các file thay đổi: **không có error**; còn warning/info style và một số unused từ legacy comment.
- `git diff --check`: pass.
- `bash -n`: pass.
- Python compile với `PYTHONPYCACHEPREFIX=/private/tmp/qn-pycache`: pass.
- CodeGraph đã index lại: 274 files, 7.606 nodes, 20.987 edges, trạng thái up to date.
- `graphify update .` đã hoàn tất và cập nhật `graphify-out`.

## 5. Blocker/gate chưa hoàn tất

- Máy hiện tại không có `docker`, `podman`, `postgres` hoặc `psql`.
- Vì vậy **chưa chạy được PostgreSQL runtime gate thật** cho migration/RPC/concurrency. Không được tuyên bố production-ready hoặc deploy trước khi gate này pass.
- Chưa đối soát/xóa dữ liệu lịch sử `060/061`; không được tự sửa production vì chưa xác định giao dịch thực và phương thức đúng.

## 6. Phần đang làm dở — ưu tiên đầu tiên khi quay lại

CodeGraph vừa phát hiện một lỗ hổng còn lại trong POS wallet:

- `checkout_sheet.dart` vẫn gọi `LoyaltyRepository.spendWallet()` **sau khi** `complete_pos_sale_v1` đã commit.
- RPC hiện chỉ cho `cash/transfer/card/bank`, nên `wallet` bị từ chối; nếu mở whitelist mà vẫn giữ client side effect thì lại không atomic.
- Đây phải được sửa triệt để, không vá vòng lặp.

Việc cần làm tiếp:

1. Đưa thanh toán ví vào cùng transaction `complete_pos_sale_v1`:
   - cho phép `wallet` nhưng bắt buộc `customer_id`;
   - khóa customer `FOR UPDATE`;
   - tính bonus theo `bonus_cap_pct`, bỏ bonus hết hạn, rồi dùng real balance;
   - fail-closed nếu tổng ví không đủ;
   - cập nhật `customers.real_balance/bonus_balance` và ghi `balance_transactions` trong cùng transaction;
   - `fund_type = 'wallet'`, không cộng nhầm cash/bank của thu ngân;
   - lưu `wallet_real_used`, `wallet_bonus_used` trong `pos_idempotency_operations` để replay trả đúng dữ liệu, không trừ lần hai;
   - response RPC trả hai giá trị wallet used.
2. Mở rộng `PosSaleResult` với wallet amounts và dùng chúng để dựng nhãn bill.
3. Xóa lời gọi `spendWallet()` sau commit trong `checkout_sheet.dart`; tuyệt đối không để side effect ví ở client.
4. Sửa báo cáo voucher dùng exact order UUID:
   - thêm `orderId` vào `_VoucherUseRow` trong `lib/screens/report_screen.dart`;
   - map từ `o['id']`;
   - gọi `showOrderDetailDialog(context, row.orderNumber, orderId: row.orderId)`.
5. Rà lại hiển thị quy đổi loyalty: `CartState.total` hiện trừ `loyaltyPtsUsed` theo tỷ lệ 1:1 trong khi server dùng `loyalty_redeem_rate`. Không để UI preview khác total canonical.
6. Bổ sung test chống regression cho wallet atomic/replay và static invariant rằng Flutter không gọi `spendWallet()` sau POS commit.
7. Chạy lại toàn bộ test/analyzer/diff check và index lại CodeGraph/Graphify sau sửa.

## 7. Lệnh kiểm tra khi tiếp tục

```bash
cd "/Users/banhbao/Quan Nho/quan_nho"
codegraph status
codegraph explore "Trace POS wallet payment from CheckoutSheet through complete_pos_sale_v1 and balance_transactions"
git status --short
git diff --check
```

Sau khi sửa, chạy lại các suite đã nêu ở mục 4. Nếu có máy Docker/PostgreSQL cô lập thì chạy:

```bash
bash test/backend/run_phase1_docker_gate.sh
```

Chỉ chuyển phase/deploy khi output có `PHASE 1 RUNTIME GATE: ALL TESTS PASSED`, exit code 0 và xác minh cleanup không còn container/volume test.

## 8. Trạng thái Git hiện tại

- Worktree có nhiều file modified/untracked thuộc đúng công việc này.
- Không reset/checkout/xóa các thay đổi.
- Diff hiện khoảng 2.903 additions / 1.211 deletions ở tracked files; lớn một phần vì `dart format` và legacy code được chuyển vào block comment.
- Không có commit hoặc push nào được thực hiện.
