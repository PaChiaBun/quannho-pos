# Quy chuẩn Agent chi tiết — Quán Nhỏ POS

Tài liệu lưu lại toàn bộ quy chuẩn và quyết định chi tiết trước đây của workflow `/qn`. Agent không đọc toàn bộ theo mặc định; bắt đầu từ `.agents/workflows/qn.md`, sau đó chỉ mở phần liên quan tại đây hoặc trong `.docs/trien-khai-sap-toi.md`.

Khi cần tra cứu quy chuẩn cũ, bắt đầu từ file chuẩn duy nhất:
`/Users/banhbao/Quan Nho/quan_nho/.agents/workflows/qn.md`

## Bước 0 — Xác định phạm vi

Không đọc toàn bộ tài liệu dài theo mặc định. Xác định module/vấn đề user đang hỏi, sau đó chỉ mở phần liên quan trong:
`/Users/banhbao/Quan Nho/quan_nho/.docs/trien-khai-sap-toi.md`

Trước khi sửa code, dùng CodeGraph từ root repo để dò cấu trúc và phạm vi ảnh hưởng:
`codegraph sync .` → `codegraph explore "<nghiệp vụ/lỗi>"` → `codegraph node/callers/impact <symbol>`.
CodeGraph không thay thế việc đọc code hoặc tài liệu nghiệp vụ; kết luận phải đối chiếu cả hai.

## Bước 1 — Đọc tổng quan dự án
Đọc file: `/Users/banhbao/Quan Nho/quan_nho/.docs/tong-quan.md`

## Bước 2 — Đọc kiến trúc kỹ thuật
Đọc file: `/Users/banhbao/Quan Nho/quan_nho/.docs/kien-truc.md`

## Bước 3 — Đọc kiến trúc data toàn hệ thống
Đọc file: `/Users/banhbao/Quan Nho/quan_nho/.docs/kien-truc-data.md`
Đây là tài liệu quan trọng nhất về luồng data — đọc kỹ trước khi dev bất kỳ module nào.
Bao gồm: schema Supabase, luồng từng module, quy tắc vàng, thông tin kết nối.

> **⚠️ Lưu ý kiến trúc (cập nhật 2026-05-02 & 2026-07-06):**
> Toàn bộ UI layer đã migration **100% sang Supabase** — không còn Drift/SQLite trong screens.
> - `pos_screen`, `ban_screen`, `inventory_screen` → dùng Repository pattern (Supabase)
> - Timestamp: **ISO 8601 String** (không phải epoch int) — luôn dùng `DateTime.parse()`
> - Các file dead code: `ban_sync_service.dart`, `product_sync_service.dart`, `app_event_bus.dart` — đã deprecated, có thể xóa
> - **Phân giải màn hình (Thống nhất 2026-07-06):** Thiết bị điện thoại hiển thị UI Mobile (< 600px). Máy tính/PC hiển thị UI Tablet (>= 600px). Cấu hình `Responsive.isDesktop` luôn trả về `false`.

## Bước 4 — Đọc tính năng & modules
Đọc file: `/Users/banhbao/Quan Nho/quan_nho/.docs/tinh-nang.md`

## Bước 5 — Đọc phong cách làm việc & thiết kế
Đọc file: `/Users/banhbao/Quan Nho/quan_nho/.docs/lam-viec.md`
Sau khi đọc, ghi nhớ và áp dụng các nguyên tắc này trong suốt hội thoại.
Bao gồm: quy tắc làm việc, nguyên tắc code, thiết kế UI, responsive rules.

## Bước 6 — Đọc nhật ký công việc
Đọc file duy nhất: `/Users/banhbao/Quan Nho/quan_nho/nhat_ky.md`
Ghi nhớ mục **"Tiếp theo"** của ngày gần nhất — đây là context quan trọng nhất.

> **Quy ước:** `nhat_ky.md` ở thư mục gốc là nhật ký chuẩn duy nhất của dự án.
> Không tạo thêm `.docs/nhat-ky.md`, `nhat-ky.md` hoặc nhật ký trùng lặp ở vị trí khác.

## Bước 7 — Báo cáo
Sau khi đọc xong, tóm tắt ngắn gọn cho user biết:
- Đang làm dự án gì
- Các module chính
- Ngày làm gần nhất đang ở đâu (từ nhật ký)
- Trạng thái kiến trúc hiện tại (Supabase migration status)
- Hỏi user muốn làm gì tiếp theo

---

# Quy Chuẩn & Cung Cách Làm Việc (Quán Nhỏ POS)

## 1. Nguyên Tắc Thiết Kế Giao Diện (UI/UX)
* **Tương thích đa thiết bị:** Giao diện cấu hình phải hoạt động tốt trên cả Điện thoại (Mobile), Máy tính bảng (Tablet) và Máy tính (PC).
* **Multi-staff table ordering:** Không cần Presence. Table card hiển thị unique `added_by` của các item chưa hủy dưới dạng `NV: tên 1, tên 2...` như hiện trạng `ban_screen.dart`. Nhiều staff được thêm món; mutation atomic/idempotent, realtime và audit đúng item creator.
* Same item khác actor hoặc khác confirmation batch/order round phải là separate lines; chỉ merge cùng actor+batch+product+price+modifiers+note. Persist immutable actor ID + name snapshot atomically at insert; idempotency includes batch/actor.
* Nợ kỹ thuật: current `add_session_items` RPC, client fallback và unique draft index merge không xét actor/batch; client còn session-wide fill mọi null `added_by`. Sửa authenticated RPC payload/context + merge/index key và bỏ post-update để không gộp/gán sai tên xuyên máy.
* Future kitchen attribution: card/printed ticket header `Đợt N · NV name`; snapshot ordered_by ID/name từ authenticated dispatch actor, không repeat per item.
* Không xây kitchen→ordering-staff callback/notification workflow; sự cố món xử lý trực tiếp ngoài app trong scope hiện tại.
* Kitchen completed-ticket **Mở lại** đã có: `xong -> dang_lam`, reset item done và sync table item status; không phải future feature.
* `kitchen.reopen_ticket`: Kitchen staff/Head Chef và Owner/Manager override được phép; Waiter/Cashier/other staff không được UI hoặc server action dù xem được Bếp. Enforce active membership + action/authority server-side.
* Reopen confirmation có optional reason, cho skip. Immutable audit luôn lưu ticket/from-to/actor/role/session/device/time và reason nếu nhập.
* Reopen không auto-print/redispatch. Manual reprint reuse same ticket/round ID, mark `REPRINT` và audit; không tạo new order round.
* Reopen không play new-ticket sound/badge/notification; chỉ move sang in-progress và temporary highlight.
* `kitchen.archive_ticket`: Kitchen staff/Head Chef + Owner/Manager; chỉ hide completed ticket, không delete hoặc mutate completion history.
* Completed-ticket auto-hide per store, Owner-configurable 5/10/15/30m+, default 30m. Manual archive immediate; visibility only, preserve `done_at`.
* Trong `Bếp hôm nay/Thống kê hôm nay`, card `Đã hoàn thành` mở list mọi completed ticket hôm nay gồm visible/manual-archived/auto-hidden; newest first, ticket/items/timestamps/duration/archive state. Không tạo module history riêng.
* Kitchen “today” dùng store timezone + same `business_day_cutoff` (default 04:00); card aggregate và detail list dùng identical boundary.
* Kitchen staff/Head Chef + Owner/Manager xem today list; detail read-only, chỉ `kitchen.reopen_ticket` actor được reopen bằng same audited transition.
* Nợ kỹ thuật archive: current `archiveTicket()` backdate `done_at` một ngày; thay bằng `archived_at/by` + session/device RPC/audit, giữ immutable `done_at`. Auto-hide 15m dùng visibility rule, không mutation.
* Nợ kỹ thuật kitchen history: `_StatsDrawer` completed card chưa clickable và active stream filter mất old done tickets. Thêm server-authorized paginated provider/query riêng theo store+business-day, không tải history vào realtime board.
* Nợ kỹ thuật reopen: waiter default/fallback đang có Kitchen module; current UI không action guard; repository multi-step direct updates. Bỏ non-kitchen default access, thêm action permission và idempotent transition RPC + immutable audit.
* Nợ kỹ thuật role canonicalization: substring `trưởng` có thể phân loại `Bếp trưởng` thành Manager trước Kitchen. Dùng canonical role/department ID, không infer security từ display name.
* Nợ kỹ thuật kitchen waiter: ticket model thiếu actor; card chỉ round và print đang map `orderNote` thành `waiterName`. Thêm schema/model/repository/UI/printer mapping; legacy unknown không infer từ note.
* **Table attribution:** Báo cáo số bàn chỉ credit `ban_sessions.waiter_id` là người mở bàn. Các item contributor khác giữ `added_by` để display/audit nhưng không tăng table count.
* Opener logout/end-shift không khóa bàn; authorized staff khác được tiếp tục add items/checkout. Giữ original `waiter_id`, còn mọi action/payment ghi actor/session/device thực tế.
* Không cho sửa/reassign table opener sau khi session được tạo, kể cả Owner/Manager; original `waiter_id` immutable cho reporting/audit.
* Merge occupied tables giữ attribution của mọi source session: mỗi original opener nhận một table count dù checkout chung. Link source sessions với merged target/invoice và idempotent để không double-count retry.
* Split items/bill tạo derived session/table không tăng table-service count. Link `derived_from/source_session`, giữ original attribution và idempotent qua repeated split/retry.
* Full move sang empty table giữ same service lineage/opener và một table count; audit source/target/actor/time, không close-reopen tạo count mới.
* Empty/opened-by-mistake session không tính table service. Chỉ count khi lineage có >=1 non-cancelled item và linked invoice paid; giữ session audit với count 0.
* Takeaway/counter/POS orders không tính table-service metric; báo cáo riêng order channel và không dùng fake table để credit staff.
* Paid takeaway/counter order count credit order creator trong metric riêng. Draft/canceled/failed payment không count; idempotent theo order ID để sync/retry không double-count.
* Creator/cashier attribution tách riêng: order count/sales credit creator; payment count/collected amount credit cashier. Persist actor/session/device trên order và payment, không overwrite creator.
* Dine-in attribution: table count → original opener; item → `added_by`; payment → actual cashier. Ba lớp độc lập, aggregation không overwrite/infer lẫn nhau.
* Một original table lineage chỉ count một service sau khi toàn bộ split invoices/items hoàn tất và table đóng. Mỗi invoice/payment vẫn report riêng nhưng không tăng table count.
* Split table có nhiều successful payments thì mỗi payment credit một cashier transaction; table lineage vẫn một service count.
* Nợ kỹ thuật report: `DashboardRepository` đang count mỗi order có `waiter_id` và suy cashier/payment từ order. Thêm unique table-service lineage fact + payment facts/ledger, aggregate idempotent theo source IDs.
* **Bố cục dạng lưới (Grid Layout) tối giản:** 
  * Các danh mục lựa chọn hoặc chức năng cấu hình lớn cần được đưa về dạng hình chữ nhật nằm ngang gọn gàng.
  * Tỷ lệ khung hình (`childAspectRatio`) lý tưởng trên Tablet/PC là từ `2.0` đến `2.5`, trên Mobile từ `1.5` đến `1.8`.
  * Font chữ tiêu đề và phụ đề trên các thẻ danh mục cần to rõ (`fontSize` từ `13` đến `17`), đảm bảo dễ đọc và dễ chạm trên màn hình cảm ứng của Tablet.

---

## 2. Phân Hệ Thiết Kế In Ấn (Bill Printer Module)
### Phân chia Trạm in độc lập
* Tách biệt hoàn toàn phần thiết kế cấu hình và mẫu in của **Hoá Đơn Thu Ngân**, **Phiếu Bếp Nóng** và **Phiếu Bếp Bar (Bếp Nước)**.
* Mỗi trạm sở hữu một template độc lập được lưu trữ và đồng bộ hóa qua Supabase Database:
  * `billTemplateProvider` cho Hoá đơn.
  * `kitchenTicketTemplateBepNongProvider` cho Bếp Nóng.
  * `kitchenTicketTemplateBepBarProvider` cho Bếp Bar.

### Quy chuẩn In nhiệt (Thermal Printing)
* **Độ sắc nét 100% (Pure Black):** Khi thiết kế file PDF hoá đơn để in nhiệt, tuyệt đối **không sử dụng** các màu xám (`PdfColors.grey600`, `PdfColors.grey700`, v.v.) hay opacity mờ. Mọi văn bản, đường kẻ (divider) và thông tin phụ phải sử dụng màu đen thuần **`PdfColors.black`** để máy in nhiệt đốt kim rõ nét nhất.
* **Logo hoá đơn dạng Base64:** Hình ảnh logo được người dùng tải lên từ thiết bị sẽ được chuyển đổi sang định dạng chuỗi Base64 siêu nhẹ, đồng bộ lên đám mây và kết xuất trực tiếp dưới dạng ảnh Bitmap/MemoryImage trong PDF để tối ưu độ tương thích của máy in.
* **Mã QR Code linh hoạt:** Hỗ trợ 2 chế độ: (1) QR Động tự động điền số tiền hoá đơn và mã đơn hàng `bill.orderNumber`, và (2) QR Tĩnh chỉ chứa thông tin tài khoản ngân hàng để khách tự nhập tiền. Cấu hình này được lưu trong block parameter `qrType` (`dynamic` hoặc `static_amount`).

---

## 3. Kiến Trúc Dữ Liệu Hiện Tại & Đa Cửa Hàng
* **Supabase là source of truth:** Luồng nghiệp vụ hiện tại dùng Supabase. `AppDatabase`/Drift là legacy; chưa có luồng bán offline rồi đồng bộ lại đã được nối và kiểm thử.
* **Multi-store:** Một tài khoản có thể sở hữu hoặc tham gia nhiều cửa hàng. Mọi repository và thao tác dữ liệu phải filter theo `store_id`.
* **Cô lập dữ liệu:** Menu/sản phẩm, kho, nhân viên, bàn và doanh thu thuộc riêng từng cửa hàng. Việc dùng lại dữ liệu giữa các cửa hàng phải thực hiện bằng thao tác sao chép, không dùng chung bản ghi.
* **Ví/loyalty:** Quán lẻ tách khách hàng, Ví và điểm theo `store_id`; các cửa hàng chính thức thuộc cùng một chuỗi có thể dùng chung các dữ liệu này trong phạm vi chuỗi. Dữ liệu vận hành còn lại vẫn cô lập theo cửa hàng.
* **Membership chuỗi:** Cùng chủ sở hữu không đồng nghĩa cùng chuỗi. Chủ phải chủ động tạo chuỗi và thêm từng cửa hàng; chỉ membership đang hiệu lực mới cho dùng chung Ví/điểm. Thay đổi membership phải được phân quyền và audit.
* **Migration vào chuỗi:** Khi thêm quán lẻ đang hoạt động, phải đưa toàn bộ tiền thật, bonus còn hiệu lực và điểm cũ vào ledger chung của chuỗi. Migration phải idempotent, giữ nguồn gốc số dư/lô, có tổng trước–sau và audit; không chỉ dùng chung giao dịch mới.
* **Nhận diện khách chuỗi:** Dùng số điện thoại đã chuẩn hóa để ghép hồ sơ. Cùng số thì cộng số dư vào khách chung; khác số không tự động ghép dù trùng tên. Luôn giữ mapping về customer ID nguồn tại từng cửa hàng.
* **Bắt buộc số điện thoại:** Không tạo customer nếu không có số hợp lệ. Không có khái niệm customer loyalty/Ví cục bộ thiếu số. Chuẩn hóa về canonical phone trước khi deduplicate, lưu hoặc tra cứu.
* **Không OTP khi tạo customer:** Nhân viên được tạo hồ sơ chỉ bằng số khách cung cấp để gom dữ liệu. Lưu trạng thái phone chưa xác minh; không suy ra quyền sở hữu số hoặc consent marketing từ thao tác này.
* **Quyền tạo customer:** Waiter và Cashier được tạo nhanh customer trong POS/bàn; Owner/Manager cũng có quyền. Dedup bằng canonical phone và audit người/store tạo.
* **Quyền sửa customer:** Chỉ Owner/Manager được sửa; Cashier/Waiter chỉ tạo, tra cứu và chọn. Audit actor + before/after; đổi canonical phone phải kiểm tra trùng theo quán/chuỗi.
* **Đổi phone:** Không cần OTP hoặc duyệt hai người. Owner/Manager tự xác nhận nhưng bắt buộc lý do. Audit bất biến gồm phone cũ/mới, số dư wallet/bonus/points, actor, store/chain, device và timestamp để kiểm tra lạm quyền.
* Sau khi đổi phone, gửi cảnh báo bảo mật tối giản đến số cũ và số mới; không chứa số dư. Lưu delivery result; gửi lỗi không rollback thay đổi phone đã commit.
* Security notice đổi phone vẫn gửi khi khách opt-out marketing, nhưng tuyệt đối không kèm khuyến mãi/CTA. Opt-out tiếp tục chặn mọi tin chăm sóc khác.
* **Nợ kỹ thuật:** `store_members` hỗ trợ nhiều membership qua `(user_id, store_id)`, nhưng `staff_members` hiện chỉ gắn một `userId` với một `store_id`. Cần thiết kế lại hồ sơ nhân viên để vai trò, quyền, ca và lương tách riêng theo từng cửa hàng.
* **Nợ kỹ thuật mô hình chuỗi:** Chưa có organization/chain entity hoặc `chain_id`; không được chia sẻ bằng cách bỏ filter `store_id`. Cần membership cửa hàng–chuỗi, customer identity, ledger Ví/điểm cấp chuỗi, RLS và cơ chế đối soát giữa chi nhánh.
* Cash close: Cashier nhập actual cash; server tính expected cash từ opening balance + valid cash ledger và variance. Variance khác 0 bắt buộc reason; Manager confirm. Không sửa sales/finance source records để ép khớp.
* Mỗi shift có một primary Cashier chịu trách nhiệm shared cash session; mọi cash transaction của staff trong ca link cùng session. Primary Cashier submit count, Manager confirm.
* Cash session opening: incoming Cashier count/confirm opening float. Default từ prior confirmed handover; first session dùng store-configured float. Variance cần reason + Manager approval trước open.
* Manager vắng mặt không block next session: matched handover mở ngay/pending review; variance cần outgoing+incoming acknowledgement, urgent alert và immutable pending reconciliation để Manager duyệt sau.
* Open/unpaid orders không block cash close và không tính expected cash. Payment thuộc cash session đang mở tại thời điểm checkout; preserve order/service/payment actors riêng.
* Mid-shift cash add/drop cần movement amount+reason và Manager approval; included in expected cash. Approved movement immutable; sửa sai bằng linked reversal, không update/delete.
* Confirm reconciliation tạo linked finance entry riêng: shortage = expense, overage = other income; không mutate sales/source ledger. Tạo atomic/idempotent với unique reconciliation link.
* Cash shortage không auto-deduct payroll. Manager investigate/propose; Owner approve linked deduction với evidence/reason/employee notification và dispute/audit support.
* Nợ kỹ thuật cash reconciliation: handover hiện chỉ có issues/notes/pending tasks. Thêm cash session/reconciliation fields/model, server-calculated expected, Cashier submit/Manager confirm, immutable audit và idempotent close.
* **Nợ kỹ thuật customer phone:** Schema, form và repository hiện vẫn cho phone null; lookup chưa normalize. Phải enforce ở UI + RPC/database, migration dữ liệu cũ và unique canonical phone theo đúng phạm vi quán/chuỗi.
* **Nợ kỹ thuật customer.create:** Waiter mặc định không có module Loyalty, trong khi POS/bàn chưa có tạo nhanh đầy đủ. Cần action/RPC `customer.create`, nút tạo khi lookup không thấy, server validation/dedup/audit.
* **Nợ kỹ thuật customer.update:** Repository hiện update trực tiếp, chưa có server guard. Cần action `customer.update` chỉ Owner/Manager và RPC fail-closed có audit.
* Phone phải chỉ đổi qua RPC transaction: reason bắt buộc, kiểm tra duplicate, ghi immutable audit và chặn direct column update từ client.
* Cần transactional outbox + SMS/Zalo provider cho cảnh báo đổi phone, retry idempotent và delivery audit.

### Luồng QR gọi món
* Luồng hiện tại: khách quét QR bàn/quầy và gửi đơn; nhân viên xử lý từ hàng chờ theo ba bước `claim` $\rightarrow$ `confirm` $\rightarrow$ `send_to_kitchen`.
* Quy tắc COUNTER/mang đi: chỉ được gửi bếp sau khi thanh toán thành công.
* Phương án tương lai đang cân nhắc: web sinh QR riêng sau khi khách tạo đơn; nhân viên quét QR, đối chiếu với khách, xác nhận rồi gửi bếp. Không coi đây là tính năng đã triển khai.
* Nợ kỹ thuật: checkout QR phải hội tụ vào một `order` duy nhất. Không tạo order thứ hai khi thanh toán QR tại bàn; QR quầy phải hoàn tất thanh toán, trừ kho và ghi tài chính trước khi gửi bếp.

### Hủy món và phê duyệt
* Nhân viên được sửa/xóa món nháp chưa gửi bếp. Món đã gửi/đang làm/đã xong chỉ Owner hoặc Manager mới được phê duyệt hủy.
* Quản lý phê duyệt bằng PIN 6 số ngay trên thiết bị của nhân viên; bắt buộc lý do và audit đủ người yêu cầu/người duyệt/giá trị/hao hụt.
* Hóa đơn đã `paid`/`completed` là bất biến: không hủy, không hoàn tiền trong phiên bản hiện tại, kể cả bằng PIN quản lý.
* Không cho phép cấp quyền hủy cho role thường. Cần chuyển xác minh PIN + hủy + audit thành một RPC/transaction phía server; UI guard không phải ranh giới bảo mật.
* `PosRepository.cancelOrder()` là mã legacy không có caller nhưng vẫn có thể đảo kho/loyalty/tài chính; cần xóa hoặc khóa cứng phía server.

### Trừ kho và checkout
* Chỉ trừ kho khi thanh toán hóa đơn thành công; không trừ kho khi gửi bếp.
* Món có công thức trừ nguyên liệu theo định lượng; món/topping không có công thức trừ tồn trực tiếp.
* Khi hủy món đã gửi bếp, Quản lý xác nhận hao hụt theo thực tế: bếp đã làm thì ghi `loss`, chưa làm thì không trừ kho. `deductAsLoss` phải mặc định `false`; code hiện tại đang mặc định `true` cho cả `da_gui` là bug.
* Nợ kỹ thuật: hoàn tất order + kho/COGS + tài chính phải idempotent trong một RPC/transaction server. Không được nuốt lỗi side effect rồi vẫn báo checkout thành công.
* Cho phép bán âm kho: thiếu tồn chỉ cảnh báo, không chặn thêm món/checkout. Vẫn ghi stock movement sau thanh toán và cho phép `stock_qty` âm.
* `is_available=false`, inactive hoặc deleted là hard block trên POS, bàn và web QR. Phân biệt: hết tồn chỉ warning; Chủ quán tạm ngừng bán thì block.
* Bug hiện tại: POS/bàn disable khi `stockQty <= 0 && minStock > 0`, web QR disable khi `stockQty <= 0`. Phải đổi cả ba luồng thành cảnh báo thống nhất.
* Bug availability: web QR đã validate availability phía server, POS/bàn chưa chặn `is_available=false`. Checkout cần validate lại phía server để chống stale UI.

### Thanh toán và quỹ
* **Phạm vi tạm hoãn:** Khách hàng, loyalty, Ví, bonus, CRM và Ví/điểm dùng chung theo chuỗi là đặc tả cho giai đoạn sau. Không tự triển khai các hạng mục này hoặc tiếp tục đặt câu hỏi chi tiết cho tới khi user chủ động mở lại phạm vi.
* Mỗi hóa đơn hiện chỉ có một payment method; chưa hỗ trợ split payment. `cash` vào quỹ tiền mặt; `transfer`/`card` vào quỹ ngân hàng.
* Transfer confirmation ưu tiên bank/provider webhook match account+order reference+amount+unused transaction. Nếu manual, Cashier phải kiểm tra tiền thật vào tài khoản và lưu actor/time/reference/proof; ảnh khách không đủ làm bằng chứng duy nhất.
* Underpayment giữ order unpaid và cho nhiều transfer cùng link một order đến khi đủ. Overpayment tạo cảnh báo và refund phần dư bằng linked expense/payment record, không sửa order total.
* Overpayment refund: Cashier create request, Manager/Owner approve; no self-approval. Refund verified original sender/source where possible và lưu beneficiary/reference/proof/actors.
* Mỗi provider transaction chỉ allocate cho một order, tối đa transaction amount; allocation + paid amount + completion phải atomic/idempotent.
* Nợ kỹ thuật: VietQR/SePay UI chưa phải bank confirmation. Cần signed webhook inbox, provider transaction idempotency, reconciliation matching và manual-confirm RPC/audit; QR shown không đồng nghĩa paid.
* Split payment là khả năng tương lai, không giả định đã có schema/UI.
* `wallet` là tính năng chính thức sẽ hoàn thiện sau, không xóa. Nợ kỹ thuật: order/finance đang commit trước khi trừ ví và `wallet` bị map vào `fund_type=cash`; cần transaction idempotent và bút toán/quỹ riêng cho Ví.
* Ví và loyalty là hai hệ thống độc lập: Ví gồm `real_balance`/`bonus_balance` để thanh toán; loyalty dùng `loyalty_pts` để đổi ưu đãi hoặc giảm giá. Có thể dùng điểm giảm hóa đơn rồi dùng Ví thanh toán phần còn lại; không gộp hai số dư.
* Tiền thật trong Ví không hết hạn. Chỉ bonus quán tặng có hạn dùng do từng quán cấu hình.
* Mỗi lần tặng bonus là một lô riêng có nguồn, số tiền và hạn dùng. Khi thanh toán phải tiêu theo FEFO (lô gần hết hạn trước), sau đó mới dùng tiền thật.
* Từng quán cấu hình tỷ lệ tối đa của hóa đơn được thanh toán bằng bonus; không hard-code 15%. Phần còn lại dùng tiền thật trong Ví.
* Khi chưa có split payment, chỉ cho chọn `wallet` nếu bonus hợp lệ + tiền thật trong Ví đủ trả toàn bộ hóa đơn. Nếu thiếu, phải chọn hoàn toàn phương thức khác; không kết hợp Ví với tiền mặt/chuyển khoản/thẻ.
* Tạo customer và tích điểm không cần OTP. Mỗi lần thanh toán bằng Ví (tiền thật hoặc bonus) phải được khách xác nhận cho đúng order/amount: ưu tiên Zalo, SMS OTP 6 số dự phòng; token one-time, hết hạn khoảng 3 phút, rate-limited và enforced server-side.
* Không cho nhân viên/quản lý bypass xác nhận Ví. Nếu xác nhận thất bại thì dùng payment method khác. Verify authorization + debit bonus/real + complete order phải atomic/idempotent và có audit.
* Nợ kỹ thuật hạn bonus: hiện chỉ có một `customers.bonus_expires_at`, lần nạp mới có thể ghi đè hạn toàn bộ bonus; UI chọn thủ công 6/12 tháng, chưa dùng setting theo quán. Cần ledger nhiều lô, giao dịch hết hạn và đối soát `bonus_balance` từ các lô còn hiệu lực.
* Nợ kỹ thuật bonus cap: hiện lưu `bonus_cap_pct` theo khách và mặc định 15%; cần setting theo `store_id` và snapshot chính sách trên giao dịch để audit.
* Nợ kỹ thuật xác nhận Ví: hiện lookup số điện thoại là có thể chọn `wallet`; chưa có Zalo/SMS challenge, transaction binding, rate limit hoặc server gate. Không coi luồng Ví đủ an toàn để phát hành.
* Đổi điểm do từng quán cấu hình qua danh mục phần thưởng/ưu đãi riêng theo `store_id`; không có tỷ lệ tiền cố định toàn hệ thống.
* Đổi điểm không cần Zalo/SMS OTP; nhân viên xác nhận trực tiếp với khách tại quầy và chọn reward hợp lệ. Audit phải có customer, reward, points, order, store và staff.
* Chỉ Owner, Manager và Cashier được đổi điểm; Waiter không được thực hiện.
* Chỉ Owner/Manager được tạo, sửa, bật hoặc ngừng reward. Cashier chỉ áp dụng reward đang hiệu lực.
* Chỉ Owner/Manager được đổi tỷ lệ tích điểm, hạn điểm, hạn bonus, bonus cap và chính sách loyalty/Ví. Cashier và role thường không được chỉnh.
* Tỷ lệ tích điểm cũng do từng quán cấu hình bằng `app_settings.loyalty_rate`: số điểm nhận được là `floor(tổng tiền thực trả / loyalty_rate)`. Giá trị mặc định khi tạo quán hiện là 10.000đ = 1 điểm.
* Thời hạn sử dụng điểm do từng quán cấu hình riêng theo `store_id`; không dùng một hạn chung toàn hệ thống. Áp dụng mô hình inactivity: toàn bộ điểm hết hạn sau N ngày không có hoạt động; mua hàng, đổi thưởng và nạp Ví đều làm mới mốc. Không hết hạn theo từng lô điểm.
* Nợ kỹ thuật loyalty: `loyalty_rewards` đã tồn tại theo quán nhưng checkout vẫn trừ `loyalty_pts_used` trực tiếp khỏi tiền như `1 điểm = 1 đồng`. Phải đổi sang chọn ưu đãi hợp lệ của quán và commit việc đổi điểm nguyên tử cùng hóa đơn.
* Nợ kỹ thuật authorization: chưa có action `loyalty.redeem` hoặc server guard riêng. Phải thêm quyền Owner/Manager/Cashier và fail-closed phía server, không chỉ ẩn nút.
* Cần action `loyalty.manage_rewards` chỉ cho Owner/Manager; các RPC/RLS tạo/sửa/ngừng reward phải enforce server-side.
* Cần quyền quản trị `loyalty.manage_settings` chỉ cho Owner/Manager, không được ủy quyền cho role thường; thay đổi phải enforce server-side và audit giá trị trước/sau.
* Nợ kỹ thuật hết hạn điểm: chưa có setting số ngày, mốc hoạt động loyalty gần nhất hoặc tác vụ hết hạn. Khi triển khai phải ghi giao dịch `expired` có audit và bảo đảm xử lý idempotent.
* Roadmap CRM: cho phép từng quán cấu hình nhắc điểm sắp hết hạn qua điện thoại/SMS và Zalo. Chỉ gửi khi khách đã opt-in; opt-out phải có hiệu lực ngay và chặn các lần gửi sau. Phải lưu consent theo kênh, nguồn, thời gian và audit theo cửa hàng. Hiện chưa có tích hợp gửi tin, template, scheduler, delivery log hoặc consent; không mô tả như tính năng đang chạy.

### Nhân viên, phân ca và chấm công
* Phân ca theo từng ngày; một nhân viên có thể làm các ca khác nhau ở các ngày khác nhau.
* Chỉ ca đã được phân công trong ngày mới được check-in và tính công. Không có assignment thì không tạo chấm công hợp lệ.
* Check-in được sớm tối đa 15 phút. Vào trễ nhưng trước giờ kết thúc vẫn ghi công và lưu `late_minutes`; trước cửa sổ hoặc sau khi ca kết thúc thì block.
* Dùng server time theo store timezone, không tin giờ thiết bị; xử lý ca qua đêm đúng ngày assignment.
* Check-out sớm vẫn hợp lệ nhưng lưu phút về sớm. Phần sau giờ kết thúc là OT pending; chỉ OT được Manager duyệt mới tính lương.
* Quên check-out: server tự đóng tại scheduled end, gắn `forgot_clockout`, không tính OT và đưa vào hàng chờ Manager xác nhận/sửa.
* `forgot_clockout` tự trừ 50% tiền công của ca. Manager được sửa clock-out hoặc waive penalty với reason/audit, nhưng không xóa lịch sử vi phạm.
* Check-in bắt buộc live selfie + GPS trong geofence; cấm ảnh thư viện. Check-out không cần ảnh nhưng vẫn bắt buộc GPS trong geofence. GPS lỗi/ngoài vùng thì block luồng thường.
* Geofence lat/lng/radius tách theo store; Owner/Manager cấu hình, mặc định có thể 200m. Thay đổi phải audit before/after.
* GPS/thiết bị lỗi không cho employee bypass. Employee gửi attendance adjustment request; Owner/Manager xác nhận mới tạo/sửa công. Reason, incident type, requester, approver, proposed time và before/after là bắt buộc.
* Duyệt adjustment trong module bằng session Owner/Manager; không nhập manager PIN trên máy employee. Employee chỉ submit và xem pending/approved/rejected.
* Không self-approval. Adjustment của Manager chỉ Owner duyệt; Manager khác không duyệt thay. Server so beneficiary/requester với approver và fail-closed.
* Owner/Manager trực tiếp phân và sửa lịch. Employee chỉ xem; không có swap/request-swap giữa nhân viên. Sửa lịch đã publish phải audit before/after + reason.
* Assignment add/change/cancel phải realtime vào lịch employee và phát notification đúng người, gồm store/date/before-after/actor; delivery idempotent.
* Không draft/publish schedule. Mỗi assignment mutation của Owner/Manager có hiệu lực ngay, audit và notify ngay.
* Assignment locked khi đã có check-in. Không direct edit/delete; dùng adjustment workflow và giữ original. Attendance-linked assignment không hard-delete.
* Một employee có thể có nhiều assignments trong một ngày; từng ca có attendance/violation/OT/pay riêng.
* Overlap không hard-block: cảnh báo Owner/Manager nhưng cho xác nhận. Mỗi attendance chỉ gắn một assignment để không double count.
* Unresolved: khi nhiều overlapping assignments cùng eligible, chưa chốt manual selection hay auto-selection. Không đoán; cảnh báo Manager để tránh ambiguity cho tới khi user mở lại quyết định.
* Late/early_leave tự sinh khoản trừ cố định theo setting quán. Manager được waive từng vi phạm với reason/audit; waiver một lỗi không ảnh hưởng lỗi khác.
* Mỗi shift template có grace minutes do Owner/Manager cấu hình. Trong grace không phạt; vượt grace mới tạo late violation. Role thường không được chỉnh.
* Khi đã vượt grace, `late_minutes` tính từ scheduled start. Ví dụ 08:00 + grace 5, check-in 08:06 = trễ 6 phút.
* Mỗi shift template có early-leave grace riêng do Owner/Manager cấu hình. Trong grace không phạt; vượt grace mới tạo `early_leave` violation.
* Khi vượt early grace, `early_leave_minutes` tính toàn bộ đến scheduled end. Ví dụ end 17:00 + grace 5, clock-out 16:54 = về sớm 6 phút.
* Attendance phải gắn `store_id` và `shift_assignment` cụ thể để tính lương/audit.
* Nợ kỹ thuật: `clockIn()` hiện insert ca trước rồi mới gọi `detectLateArrival()` bằng giờ local client; không có assignment vẫn chấm công và lỗi detect bị nuốt. Cần RPC server atomic kiểm tra membership + assignment + time window/timezone + open-shift uniqueness trước insert.
* Nợ kỹ thuật check-out: hiện chỉ lưu clock_out; payroll suy OT theo ngưỡng 8h thay vì shift end và xử lý early/overnight chưa chắc đúng. RPC phải snapshot assignment, lưu `early_leave_minutes` + `overtime_minutes_pending`; OT approval cần actor/reason/audit.
* Nợ kỹ thuật forgot clock-out: hiện tự đóng theo clock-in + 8h và suy vi phạm nếu >14h. Giữ chính sách phạt 50% nhưng chuyển sang scheduler/job đóng tại assignment end, violation/waiver riêng, không OT và Manager review có audit.
* Nợ kỹ thuật geofence: check-in GPS optional và out-of-range vẫn cho tiếp tục; check-out không lấy GPS. Enforce server-side cho cả hai với coordinate + accuracy + captured_at; check-in yêu cầu selfie, check-out không ảnh.
* Setting geofence đang update trực tiếp. Cần action/RPC chỉ Owner/Manager, validation và immutable audit.
* Nợ kỹ thuật attendance adjustment: `updateShift()` đang sửa trực tiếp không reason/role guard. Thay bằng request/approval workflow + RPC Owner/Manager, giữ original timestamps và audit.
* Thêm `attendance.approve_adjustment` chỉ Owner/Manager và enforce server session; không dùng manager PIN/client guard.
* Approval hierarchy: Manager chỉ duyệt staff thường; Owner duyệt Manager. Chặn self-approval và cross-manager workaround.
* Assignment mutation chỉ Owner/Manager qua server RPC/action; employee read-only, không direct update.
* Nợ kỹ thuật assignment lock: repository đang update/delete trực tiếp. RPC phải reject mutation sau check-in; adjustment tạo correction record thay vì đổi/xóa gốc.
* Nợ kỹ thuật multi-shift/day: unique/upsert hiện dùng `(store_id,user_id,assigned_date)` nên ghi đè ca thứ hai. Đổi constraint/model và clock-in lookup để chọn đúng assignment, hỗ trợ nhiều ca tuần tự.
* Nợ kỹ thuật schedule notification: assignments mới chỉ fetch; chưa có realtime/outbox/push/delivery log. Attendance realtime controller không thay thế. Thêm assignment events + in-app/push idempotent.
* Nợ kỹ thuật penalty waiver: hiện tính phạt lúc render và dùng cờ override cấp ca, chưa miễn riêng late/early. Cần immutable violation ledger + fixed-amount snapshot + per-violation waiver; không dùng cờ khôi phục toàn bộ ca.
* Nợ kỹ thuật grace: template CRUD chưa có server authorization; `detectLateArrival` đang tính từ grace deadline thay vì scheduled start. Phải sửa và snapshot grace khi phân ca/chấm công.
* Nợ kỹ thuật early grace: payroll đang hard-code 5 phút và template chưa có field. Thêm `early_leave_grace_minutes`, server authorization và snapshot khi assignment/attendance được tạo.

### Cấu hình tính lương
* Mỗi employee có salary mode/rate riêng theo store: hourly, daily hoặc monthly; không chia sẻ salary config giữa stores.
* Code có M1 hourly, M2 monthly, M3 fixed + OT, M4 daily và M5 custom; UI/schema cuối cần tên nghiệp vụ rõ ràng.
* Salary authorization: Owner xem/sửa mọi staff trong stores thuộc quyền sở hữu; Manager chỉ xem/sửa regular staff tại store mình quản lý, không được truy cập salary của Owner/Manager khác; employee chỉ self-read.
* Salary changes có effective date; chỉ áp dụng từ mốc đó. Closed attendance/payroll giữ rate cũ, không recalc.
* Chỉ cho backdate effective date trong payroll period chưa chốt. Period đã chốt là immutable; chênh lệch của kỳ cũ phải thành adjustment có reason/audit và được cộng/trừ ở kỳ kế tiếp.
* Snapshot mode/rates/OT/allowance/bonus/penalty policy trên attendance/payroll để lịch sử độc lập current settings.
* Nợ kỹ thuật: `staff_salary_configs` đang one-row upsert theo store+user, không version/effective dates; reporting có thể dùng current config. Thêm policy versions + immutable snapshots và migrate config hiện tại.
* Nợ kỹ thuật salary authorization: UI permission không đủ. RLS hiện chỉ lọc current store và GRANT trực tiếp cho anon/authenticated; repository direct CRUD. Chuyển read/write sang authenticated RPC/RLS kiểm tra membership + role hierarchy + target role, employee self-read và immutable audit.
* Payroll cycle là setting riêng theo store: weekly, semi-monthly, monthly hoặc custom date range. Mọi period phải persist immutable `from_date`, `to_date`, `period_type`.
* Nợ kỹ thuật payroll cycle: code hỗ trợ period type + explicit date range nhưng chưa có store default/recurring proposal. Bổ sung cycle setting, overlap validation và timezone-safe boundaries.
* Payroll approval: Manager tạo/tính lại/gửi duyệt; Owner final approve/lock. Nếu không có Manager, Owner được tự tạo và chốt. Sau lock chỉ adjustment, không mutate dữ liệu gốc.
* Nợ kỹ thuật payroll transition: code có draft -> pending_review -> approved -> paid nhưng update status trực tiếp. Thay bằng atomic server RPC kiểm tra actor/role/store, blocking conditions, snapshot lock và immutable audit; chỉ Owner được approve.
* Sau payout, employee bắt buộc chọn `received_in_full` hoặc mở dispute kèm nội dung. Pending confirmation chỉ cảnh báo, không reverse payout.
* Confirmation deadline là 3 ngày sau payout. Gửi reminder; quá hạn vẫn pending + overdue warning cho Owner, không auto-confirm.
* Dispute hierarchy: Manager review/propose cho regular staff trong store; Owner final-approve mọi monetary adjustment và tự xử lý dispute của Manager. Giữ evidence, replies, actors, timestamps và adjustment linkage.
* Payroll payout hỗ trợ cash, bank transfer hoặc split cash+transfer. Lưu amount từng leg; transfer có reference/proof, cash dùng employee confirmation làm receipt; tổng legs phải bằng actual paid amount.
* Salary advance: employee request amount+reason; Manager review/propose, Owner final approve và payout. Deduct tự động từ kỳ kế tiếp; thiếu thì carry outstanding balance qua kỳ sau. Giữ immutable request/payout/deduction ledger và idempotency.
* Advance hard cap: tổng outstanding không vượt 50% eligible earned salary tại thời điểm duyệt. Owner có thể duyệt thấp hơn, không override vượt trần.
* Eligible earned salary = lương thực tế từ ca hợp lệ đến lúc duyệt - known penalties/deductions - outstanding advances; không tính projected future salary/shifts.
* Code đã có `pending_staff_confirm` + disputes nhưng direct table operations chưa đủ trust boundary. Dùng idempotent RPC kiểm tra record ownership, khóa paid amount và audit confirmation/dispute.
* Thêm server-owned `confirmation_due_at`, overdue derivation và notification outbox; không client timer/auto-confirm.
* Nợ kỹ thuật dispute: UI đang direct update resolve/dismiss. Thay bằng server workflow tách manager proposal/owner decision, role hierarchy checks và adjustment linkage.
* Nợ kỹ thuật payout: code chỉ có một `payment_method`. Thêm immutable payout-leg ledger + proof metadata, amount reconciliation và atomic/idempotent Owner-authorized transition.
* Nợ kỹ thuật salary advance: code chưa có nền tảng. Xây mới request workflow, outstanding ledger và payroll linkage; chỉ khấu trừ khoản đã thực chi.

### Xin nghỉ và vắng ca
* Employee gửi leave request theo shift/date + reason. Manager duyệt regular staff; Owner duyệt Manager; không self-approval.
* Approved leave cập nhật assignment outcome, không tính unexcused absence và phải notification + immutable state history.
* Store cấu hình leave types đơn giản: paid, unpaid hoặc custom label; snapshot paid rule trên leave/payroll.
* Không xây annual/monthly leave accrual, leave balance hoặc carry-over ở giai đoạn này; xét từng request riêng.
* Không có open-shift/replacement workflow khi duyệt nghỉ; Manager tự phân công lại bằng schedule hiện có nếu cần.
* Unexcused absence chỉ khi có assignment nhưng không clock-in và không có approved leave gắn đúng assignment.
* Unexcused absence = không trả lương ca + immutable violation; store có optional fixed penalty. Manager propose waiver, Owner final approve; snapshot/audit đầy đủ.
* Nợ kỹ thuật: chưa có leave workflow; payroll còn suy absent bằng `expected_days - worked_days`. Thêm leave/assignment outcome ledger và server job, payroll chỉ dùng confirmed assignment absence + deduction snapshot.
* Không xây offboarding/final-settlement workflow ở giai đoạn này; chỉ deactivate staff cơ bản và giữ lịch sử.

### Nhập hàng và nhà cung cấp
* Warehouse staff/Manager tạo purchase request với supplier, planned qty/cost. Manager approve trong store limit; Owner approve nếu vượt configurable threshold.
* Receiver nhập actual qty/cost + invoice proof. Variance cần Manager re-approval; nếu actual total vượt limit thì Owner approve.
* Chỉ approved `received` mới mutate stock/cost và tạo payable/expense; snapshot plan/actual/actors/approvals/proof.
* PO hỗ trợ multiple receipts; mỗi receipt có actual lines/receiver/time/proof và chỉ phần duyệt mới tăng stock/AP. Remaining giữ open/backorder; Manager close remainder với reason.
* Per-line received không vượt ordered nếu thiếu variance approval; derive PO state partial/received/closed_short từ receipts.
* Item có optional `track_expiry`; khi bật, receipt bắt buộc lot qty+expiry. Consumption FEFO; expired stock chỉ giảm qua approved wastage movement, không auto-delete.
* Owner cấu hình expiry-warning days mặc định theo store và override per item; server scheduler dùng store timezone, không hard-code client.
* Expired disposal dùng wastage request theo lot+qty, mandatory reason, proof requirement configurable by Owner. Manager approve trong value limit, Owner nếu vượt; final approval atomically tạo lot/stock movement + expense snapshot.
* Stock count hỗ trợ all/category scope và blind entry; reveal variance only after submit. Manager approve trong limit, Owner nếu vượt; adjustment luôn bằng immutable movement.
* Stock count không block operations: lưu per-item `counted_at` + snapshot, reconcile movements sau cutoff trước variance. Approval phải concurrency-safe/transactional để không lost update.
* Out of scope hiện tại: multi-unit/conversion. Mỗi item dùng một stock unit duy nhất cho purchase/movement/count.
* Owner cấu hình min/target stock per item. Low-stock alert cho Owner/Manager và gợi ý qty đến target; chỉ explicit confirmation mới tạo purchase-request draft, never auto-order.
* Recipe versioning: Owner/Manager edit tạo version mới có effective time; order sent-to-kitchen snapshot recipe version/ingredients/cost. Historical versions immutable; recalc projected cost cho version mới.
* Production batch dùng recipe version + planned/actual yield; completion trừ actual inputs, cộng semi-finished output và ghi wastage variance cần Manager approval. Snapshot costs/lots và commit atomic/idempotent.
* Production roles: Manager/Head Chef create+assign; kitchen staff start/enter actual inputs+yield. Head Chef approve regular kitchen staff within limit, no self-approval; Head Chef own variance -> Manager, over-limit -> Owner.
* Ingredient substitution là per order/batch request + reason, Head Chef/Manager approve. Deduct actual ingredient/lot và recalc actual cost; không mutate canonical recipe version.
* Semi-finished recipe có default shelf life do Owner/Head Chef đặt. Batch completion đề xuất output-lot expiry; override cần reason/audit. Output lot dùng expiry alerts + FEFO.
* Aggregate stock phải reconcile từ lot balances + non-lot balance; consumption/return/wastage có immutable lot allocations.
* Purchase settlement hỗ trợ cash/transfer immediate, full credit hoặc partial payment. Persist payable total, allocations, outstanding, due date; mỗi repayment là linked finance ledger entry. Alert upcoming/overdue; corrections bằng reversal.
* Supplier return là partial line return linked original receipt, qty/reason/proof; Manager approve trong limit, Owner nếu vượt. Approval atomically giảm stock+payable hoặc tạo supplier refund receivable nếu đã paid. Không return vượt net received qty.
* Supplier refund settlement hỗ trợ cash, transfer hoặc offset AP/future purchase. Persist amount/method/date/proof/reference + return linkage; allocations bounded và idempotent.
* Nợ kỹ thuật: `createPurchaseOrder()` hiện direct `received` rồi multi-step client writes, finance silent-fail. Thêm PO state machine và transactional/idempotent receive RPC cho items + movements + stock/cost + finance.
* Nợ kỹ thuật AP: `payment_terms` hiện chỉ là text; chưa có payable/partial-payment/balance/due date. Thêm AP ledger, atomic allocation/reversal và notification outbox.
* Nợ kỹ thuật supplier return: code chỉ full `cancelPurchaseOrder()`. Thêm return header/lines, evidence, approval và atomic stock/AP/refund RPC; không dùng cancel cho partial return.
* Nợ kỹ thuật lot/expiry: hiện chỉ aggregate `stock_qty`, chưa có lots/FEFO. Thêm lot ledger, allocations, expiry job/notification và reconciliation; không dùng một expiry field trên product.
* Nợ kỹ thuật stock count: hiện multi-step client confirm + set `stock_qty`, chưa atomic/role/threshold/blind enforcement. Dùng cutoff snapshot và transactional approval RPC cho movement + aggregate/lot balances.
* Nợ kỹ thuật replenishment: min_stock/dashboard có sẵn, chưa target/draft generation/delivery ledger. Thêm target + suggestion + idempotent create-draft action.
* Nợ kỹ thuật recipe: current update overwrites row + delete/reinsert ingredients; permissive RLS/anon CRUD. Thêm version/effective snapshots và authenticated Owner/Manager RPC/RLS; revoke anon writes.
* Nợ kỹ thuật production: current order chỉ planned quantity, không actual output/lot/variance; completion multi-step và permissive RLS. Thêm input/output ledger + transactional complete RPC + secure state machine.

### Menu và giá bán
* Owner/Manager change price bằng version + effective time (now/future), audit before/after/actor/reason.
* Server-accepted order line snapshot unit/topping price version; existing/paid lines không recalc, new lines sau effective dùng giá mới. Client cart display không phải committed price trước server accept.
* Owner/Manager create promotion versions có active window/conditions/value/cap. Cashier chỉ apply promotion server xác nhận hợp lệ.
* Max one promotion/voucher per order, no stacking/config override. Server enforce unique redemption; replace phải remove/reverse previous first.
* Manual discount cần Owner/Manager approval; Manager cap do Owner set, over-cap Owner only. Snapshot original price + discount components/source/version/requester/approver/reason.
* Không direct-edit order-line price, kể cả Manager. Ưu đãi dùng discount component; menu price chỉ qua version workflow, server reject unit-price override.
* Không hỗ trợ service charge/surcharge trong checkout hiện tại; server reject surcharge khác 0 và bill không render dòng này.
* E-invoice/VAT integration out of scope hiện tại; chỉ internal sales receipt. Không xây tax/provider/digital-signature/tax-adjustment workflow cho đến khi Owner mở lại.
* Tip/gratuity out of scope; không đưa vào checkout/cash/payroll. Server reject tip mới khác 0, preserve legacy history.
* Nợ kỹ thuật: current `products.sell_price` direct overwrite, chưa history/schedule và có legacy permissive update policy. Thêm price versions, timezone resolver, secure mutation RPC/RLS và order-line snapshots.
* Nợ kỹ thuật discount: coupon CRUD/client calculation/direct order discount; Cashier default manual permission. Thêm promotion/redemption/component ledger + checkout validation/approval token, tách active promo apply khỏi manual override.
* Nợ kỹ thuật `pos.edit_price`: loại bỏ POS line-price override/default permission; chỉ cho secure menu price-version mutation.
* Nợ kỹ thuật surcharge: legacy table/POS/bill có field/logic surcharge; disable server-side cho giao dịch mới, giữ historical audit.

### Vận hành offline
* Offline cho mở bàn, thêm/sửa món và cash checkout. Persist durable outbox với stable local IDs/revision/idempotency/dependency order; mọi aggregate/payment chưa sync phải hiện rõ `Chưa đồng bộ` và pending count.
* Chưa xây POS→KDS LAN transport ở giai đoạn này; làm sau. Không mark `Đã gửi Bếp` nếu chưa có durable receipt acknowledgment từ Bếp/server. Khi mất Internet, giữ `Chưa gửi/Chưa đồng bộ` và cảnh báo staff báo bếp thủ công. LAN relay tương lai phải reuse ticket ID/delivery state và reconnect không reprint/redispatch.
* Offline invoice identity: stable UUID/idempotency + temporary `date-device-sequence`; receipt in temp ref. Server sync cấp official number nhưng preserve mapping/timestamps/actors/amounts/payload hash.
* Offline time integrity: lưu device time + monotonic offset + server received_at. Drift >5m vẫn sync nhưng Manager warning; reporting dùng normalized time và preserve raw timestamp audit.
* Offline cash được phép. Transfer chỉ được ghi nhận khi Cashier chủ động xác nhận đã kiểm tra/đã nhận tiền; lưu manual-offline-confirmation actor/device/time và không mô tả là bank verification. Các online/automatic payment khác, sensitive approvals và config/permission/price/recipe mutations bị khóa.
* Offline auth lease tối đa 24h từ last successful server validation; hết hạn read-only local/outbox, block new mutations đến khi revalidate account/membership/device/permissions.
* Không new login/user switch offline; chỉ resume server-validated principal trên đúng device trong lease. Không dùng guessed default role permissions.
* Reconnect auto-sync theo dependency order; server revalidate actor/store/payload/revision/state và dedupe order/payment/kitchen ticket/stock/finance effects. Concurrent offline edits cùng bàn vào Manager conflict queue, không silent overwrite; preserve immutable local cash receipt/audit.
* Nợ kỹ thuật: `BanRepository`/`PosRepository` direct Supabase; open/add/send-kitchen/checkout đều cần mạng. Drift tables không được nối vào các aggregate này, còn `PendingEvents` chỉ queue event của module bị tắt chứ không phải network outbox. Basic open-session guard/UUID chưa đủ replay safety; transfer checkout chưa có manual-offline confirmation/audit riêng. Xây aggregate/outbox, unsynced UI, idempotent RPC replay, kitchen delivery ack, conflict UX và fault-injection tests trước khi tuyên bố offline-ready.
* Nợ kỹ thuật offline auth: cached deviceRole/default permission guess/test offline bypass chưa đủ an toàn. Dùng signed encrypted device-bound lease và strip test bypass khỏi production.
* Device onboarding: tải app → online login bằng phone/password → chọn authorized store (auto-enter nếu chỉ một store) → server auto-register installation/device và tạo session. Không pairing code; permissions lấy từ account/membership, không từ fixed device role.
* Multi-device login được phép, không hard limit. Mỗi installation có device ID/session riêng để audit, track sync/last-seen và revoke từng máy độc lập.
* Password change/reset giữ current device session và revoke mọi session khác; online logout ngay, offline fail khi reconnect/revalidate; bulk revoke phải audit.
* Shared POS chỉ một active account tại một thời điểm. Đổi người phải logout rồi login bằng phone/password của người mới; không PIN quick-switch. Mọi transaction/audit gắn đúng account/session/device.
* Sau employee check-out, hỏi có logout POS không; không force logout. Nếu có unfinished orders/actions hoặc pending outbox, hiển thị cảnh báo/count trước lựa chọn.
* Shared POS auto-lock theo store-configurable inactivity timeout, default 30m. Lock che data/chặn action nhưng giữ same session/account; unlock bằng account password, không PIN.
* Background/screen-off time tính vào inactivity; resume quá hạn phải lock trước khi show data/actions. Attendance shift vẫn tiếp tục.
* Owner có thể bật per-device trusted kitchen always-on exemption khỏi inactivity auto-lock. Không infer từ role, Manager/staff không tự bật; UI badge + audit config changes.
* Kitchen always-on không bypass password reset/change, remote revoke, account/membership disable, restart re-auth hoặc security checks; các sự kiện này fail-closed như device thường.
* Trusted kitchen always-on tiếp tục offline/local ticket operations trong auth lease <=24h; không extend/bypass lease. Offline actions vẫn durable-outbox + idempotent.
* Kitchen offline lease expiry → read-only existing tickets; block claim/in-progress/done/cancel/edit đến khi full server revalidation thành công.
* Auto-lock dùng overlay, không dispose order screen; same-process unlock giữ in-memory input. Không persist/restore unconfirmed item draft qua app restart vì dễ nhầm đã gửi; committed table items không ảnh hưởng.
* Auto-lock không mutate auth principal hoặc `staff_shifts`, không clock-out/check-in lại; active shift tiếp tục khi locked/background. Unlock/resume refetch open shift và duration; checkout chỉ explicit/approved workflow.
* Nợ kỹ thuật: chưa có inactivity detector/lock route; legacy 4-digit `PinLockScreen` không có caller. Thay bằng password re-auth overlay và lifecycle tests; không xây durable cart draft.
* Không reuse legacy `PinLockScreen` success route sang `/staff_login`; overlay mới re-auth same principal rồi dismiss, tránh xung đột attendance/session.
* Device management: Owner quản lý/thu hồi mọi device trong owned stores; Manager chỉ device của managed store. Hiển thị device/current account role/session/last-seen/offline/pending-outbox; rename/revoke đều audit.
* Lost device revoke có hiệu lực server ngay; reconnect invalidates local lease/keys/session và chặn mutation. Khi còn offline chỉ dùng đến hết lease 24h; unsynced outbox phải quarantine để Owner xử lý, không silent delete.
* Nợ kỹ thuật onboarding: QR V3 đang có pairing-code table/RPC. Chuyển canonical POS sang authenticated auto-registration; migration/compatibility phải giữ an toàn session/QR cũ trước khi retire pairing components.

### Báo cáo cuối ngày
* Auto daily report per store: revenue by payment, discounts/void anomalies, cash variance, purchases/AP due, wastage/low stock, estimated labor. In-app Owner delivery; Zalo later.
* Owner cấu hình business-day cutoff per store, default 04:00 store timezone. Revenue business date theo normalized payment completion time; open-before/pay-after cutoff thuộc ngày mới.
* Manager report scope chỉ managed stores; Owner per-store + consolidated owned stores, drill-down. Manager daily report chỉ labor aggregate; individual regular-staff salary access vẫn theo payroll-module policy riêng.
* Export PDF + Excel/CSV, metadata store/range/revision/cutoff/export actor/time. Apply same scope/redaction; Manager không export individual payroll qua report.
* Report snapshots/revisions never hard-delete; Owner chỉ archive/hide. Corrections create new revision, preserve prior artifacts/audit.
* Realtime Owner alerts cho high-value void/cancel, unusual manual discount, cash variance, large wastage/stock adjustment, long offline/sync failure. Threshold per event/store do Owner set; alert link source record, idempotent và immutable.
* Alert channels hiện tại: in-app + Owner mobile push; Zalo later. Critical alert stays unacknowledged until explicit Owner action; push delivery/read không auto-close.
* Metrics drill down canonical sources và có cutoff/source version. Late sync/adjustment tạo report revision, preserve prior snapshot.
* Report Revenue drill-down: KPI/order chart theo active day/week/month/range mở paginated invoice list; row order/payment time/channel-table/creator/cashier/method/discount/total/status. Detail read-only items/modifiers/notes/price snapshots/discount components/payments/actors/source/audit.
* General report UX: mọi quantity KPI/card/chart point có source records phải clickable, preserve store/range/tab/filters; `3 orders` → period list, `7h` bar → hour list. Clear affordance; zero → empty state.
* Product tab aggregate qty/revenue/avg by period/category đã có từ completed order items. Giữ aggregate; add product-card drill-down tới matching invoice/order lines, paid non-cancelled default, canceled separate filter.
* Monetary KPI/chart (revenue/cost/discount/profit) drill-down ledger/source transactions with signed amount/type/reference/time/actor; filtered rows reconcile KPI and expose adjustment/revision differences.
* Percentage/rate KPI display-only, no click drill-down; optional concise formula tooltip only.
* Drill-down list export Excel/CSV giữ store/range/source/search/filter/sort; server exports full authorized result, not current page. Include metadata/generated actor/time/row count, redaction + formula-injection protection.
* Không PDF whole drill-down table; PDF chỉ summary report snapshot/revision hoặc single invoice/document. Detail data chuẩn là Excel/CSV.
* Authorized old-invoice PDF/reprint giữ immutable data, watermark `BẢN SAO`, actor/time/count audit; không new invoice number/payment.
* Reprint permission: Report → Owner/Manager; POS sales history → Cashier/Manager/Owner. Waiter/others blocked UI+server; enforce action + store scope, view access không imply print.
* Invoice customer phone: Owner/Manager authorized scope full; Cashier masked `090****789`; customer-facing PDF/print masked. Redact server-side, không ship full phone rồi UI-mask.
* Invoice list server search/filter: order number, customer name/normalized phone, creator/cashier, table/channel, payment method. Debounce+pagination; intersect authorized store+active range; redaction preserved.
* Invoice sort default newest payment/completion; alternatives oldest, total high/low, discount high. Server sort + stable order-ID tie-breaker; export preserves sort.
* Paid KPI/list reconcile; canceled/failed/unpaid chỉ qua separate filter. Manager managed stores, Owner owned stores; server-authorized order-ID + store-scope query, business-day boundary, pagination.
* Nợ kỹ thuật: Revenue tab aggregate-only; Voucher đã reuse `showOrderDetailDialog`, nhưng helper lookup bằng order_number không explicit store scope và direct multi-table reads. Refactor order-ID + authorized-store RPC/RLS trước broad reuse.
* Nợ kỹ thuật product detail: card chưa onTap; aggregate client-side theo order `created_at`, lệch canonical paid business time. Thêm server aggregate/detail contract cùng paid boundary, product/price snapshots và pagination.
* Live table detail đã hiển thị `item (ordering employee)`, qty/price, notes và modifier/topping chips. Historical invoice detail trong Report phải tái hiện cùng dữ liệu ở chế độ read-only từ immutable checkout snapshots, không lookup phiên bàn hiện tại.
* Nợ kỹ thuật checkout line snapshot: table checkout hiện persist `modifiers_json` nhưng bỏ `item.note`, `added_by` actor ID/name, source session-item và batch; grouping key cũng thiếu actor/batch nên có thể gộp dòng của hai nhân viên. Thêm actor/batch/source snapshots và chỉ merge cùng actor + batch + product + price + modifiers + note.
* Nợ kỹ thuật invoice-detail DTO/UI: `showOrderDetailDialog()` chỉ select basic name/qty/price/subtotal và `OrderItemModel` không có note/modifiers/ordering actor. Refactor sang authorized order-ID/store-scoped DTO/RPC, render note/modifiers/actor snapshots; bỏ fallback suy một nhân viên từ latest table session/store member.
* Historical invoice detail includes pre-payment voided lines as read-only `Đã hủy` with original qty/value, reason, requester, Owner/Manager approver, time and wastage decision; exclude from paid totals and reuse the same immutable void audit source shown in Hủy/Duyệt.
* Historical line modifiers show only actually selected options/toppings with quantity and immutable add-on price snapshot. Never render the current full option catalog or resolve old invoices against current modifier names/prices.
* Invoice detail has a collapsed processing timeline: table opened, each kitchen dispatch round, item/round completion and payment. Use canonical event timestamps + actors, store-timezone display and preserve raw/normalized audit time; never infer timeline from latest `updated_at`.
* Every timeline event shows its own actor (table opener, round dispatcher, kitchen completion actor/team, cashier) using immutable actor ID + display-name/role snapshots. Later staff rename/role/store/employment changes do not rewrite history.
* Invoice-detail UX shows staff names only; do not add a device/IP/session audit panel. Security metadata may remain in internal audit storage but is outside this report UI.
* Dine-in invoice snapshots guest count at payment. Report may calculate paid dine-in revenue per guest using valid guest-count rows only; takeaway/counter/missing-invalid counts are not coerced to 1, and KPI exposes data coverage.
* Staff may edit guest count while the table session is open. Successful checkout snapshots the last committed value; paid invoice guest count is immutable. Any future correction uses an audited adjustment/revision, never an overwrite.
* New dine-in table defaults guest count to 1, adjustable before open confirmation and never below 1.
* Current state/debt: `_OpenTableSheet` + `openSession` already default/persist 1 and allow initial +/- selection, but there is no open-session guest-count update mutation. Add authorized open-state update + before/after audit and atomic checkout snapshot.
* Open-session guest count may be edited by Waiter, Cashier, Manager and Owner in authorized store; Kitchen/Head Chef cannot. Enforce action permission + server membership/open-state, not UI role-label checks only.
* Guest-count edits require no reason, PIN or manager approval; automatically audit lineage/session, before/after count, actor ID/name snapshot and event time.
* Guest count above table seat capacity triggers a warning only; allow operation because extra seating is possible. Never clamp silently; server validates integer >=1 only.
* Merging occupied tables defaults merged guest count to the sum of both sessions, editable until payment. Preserve source-session lineage and before/after counts so reporting does not double-count merged sessions.
* Split invoices/payments share one service-lineage guest count. Invoice detail may show table + total guests, but revenue-per-guest aggregates all paid invoices in the lineage and counts the final guest snapshot once.
* Full table transfer preserves service lineage + guest count and appends source/destination/time/actor transfer history. It changes location only and does not create another served-table or guest KPI fact.
* Split-payment invoice detail includes a `Hóa đơn liên quan` section for sibling invoices and full-lineage total. Resolve strictly by immutable lineage ID, not table/time heuristics; related rows open authorized read-only detail while preserving report context.
* Related invoices show per-invoice status/amount plus lineage paid total and remaining balance. Report stays strictly read-only—no collection, item edits or status mutation; remaining collection occurs only in authorized POS workflow.
* Payment detail shows method, amount, completion time, cashier snapshot and genuine bank/provider reference when present. No transfer screenshot storage in current scope; client-supplied reference must not promote an unverified transfer to paid.
* Cash payment optionally snapshots tendered amount and computed change; detail shows both when entered, otherwise only amount received. Tendered/change are cash-handling metadata and never increase revenue or invoice total.
* Cash checkout requires tendered >= due; canonical change = tendered - due and is never manually editable. Insufficient tender blocks paid transition in both UI and transactional server RPC.
* Current bug: checkout UI calculates/displays change or shortage, but Confirm remains enabled and result payload omits tendered/change, so neither validation nor snapshot is guaranteed. Add client guard plus server enforcement/persistence.
* Cash revenue/expected-drawer facts use actual invoice amount due/paid only. Tendered and change are metadata on that payment, not separate finance income/expense rows.
* Put revenue-per-guest KPI in Report → Revenue beside average order. It preserves active store/business-day/range filters; drill-down lists contributing service lineages with guest count + paid total, deduping split invoices.
* Report → Staff separates attribution: served tables = original opener/lineage once; ordered items = ordering actor snapshot on each paid non-voided line; cashier revenue = actual payment cashier. Each metric uses its own canonical drill-down and reconciles to same-period facts.
* Ordered-items metric sums actual line quantity per ordering actor. Never assign full invoice revenue to an ordering employee; optional ordered-value sums only that actor's immutable paid line values and remains distinct from cashier revenue.
* Staff report has separate voided-items quantity/original-value column attributed to the ordering actor. Exclude these lines from successful ordered metrics; treat void column as audit signal only, never automatic payroll penalty or fault verdict.
* Voided-items drill-down is read-only and shows line/qty/original value, ordering actor, void requester, Owner/Manager approver, reason, event time and wastage decision. Keep actor roles as distinct fields; never collapse into one ambiguous staff name.
* Staff-report void aggregate/detail/export is Owner/Manager only within authorized store scope. Waiter/Cashier/Kitchen/others must not receive other employees' void data; enforce server query/export authorization, not client hiding.
* Inactive/departed staff remain in historical reports under immutable display-name snapshot with an `Đã nghỉ` current-status label. Never collapse to hidden staff, exclude facts or retroactively rewrite old name/role.
* Group staff facts by immutable employee/principal ID within tenant/store lineage, never phone or display name. Reused phones, duplicate names and renames must not merge identities; snapshots are display-only.
* Rehiring the same person reactivates the existing immutable identity/membership; create a new ID only for a genuinely different person. Audit reactivation and do not blindly restore old permissions/shifts/pay configuration.
* Current scope keeps staff identity/KPIs strictly per store, even within a chain. Do not consolidate or auto-link cross-store staff by phone/account; multi-store identity/transfer reporting is deferred advanced scope.
* Owner multi-store summary exposes aggregate headcount/labor cost only, not cross-chain individual KPI/void tables. Individual performance requires selecting exactly one store and re-authorizing/querying that scope.
* Staff table may sort by served tables, ordered quantity or cashier revenue. Do not generate good/bad labels, rankings-as-judgment or a composite performance score across different roles/shifts; metrics are operational evidence only.
* Current scope excludes per-hour/utilization/composite productivity metrics and does not join attendance for performance normalization. Show actual period facts only; defer hourly/shift metrics until paid-time/break/role allocation semantics exist.
* Kitchen reporting is store/business-day team-level only: ticket counts/statuses, average/fastest/slowest wait, completion rate and late item/ticket list. No individual kitchen scoring/ranking because tickets may be collaborative across staff/stations.
* Kitchen staff, Head Chef, Manager and Owner in authorized store share access to today/history and kitchen-report export; no separate Head-Chef tier. Scope the server response/export to kitchen dataset only—this does not imply access to all reports.
* Kitchen-role report response/UI/export includes operational ticket/item/table-zone/time/status fields only; exclude prices, invoices/payments, revenue/profit and customer PII at server response level. Financial reporting remains Manager/Owner general-report scope.
* Kitchen timing semantics: queue = started_at-sent_at; preparation = done_at-started_at; total = done_at-sent_at. Require valid endpoints, use live interval for active states and preserve transition history across cancel/reopen.
* Current state/debt: model/repository already persist sent/started/done timestamps and UI has correct state lanes. Stats currently calculate done-sent only but call it wait/avgWait, while live timer always counts from sent even during preparation. Rename this metric total and add separate queue/prep metrics.
* Keep one total-from-sent live timer on kitchen ticket cards; state lane/badge distinguishes queued vs doing. Do not add a second prep timer to cards; split queue/prep/total only in report stats/detail.
* Mark a ticket late when total-from-sent exceeds store setting `kitchen_late_threshold_minutes`, default 30m, in both queued and doing states; starting work never resets deadline. Report and realtime warning use the same effective threshold/version.
* Current scope uses one late threshold per store for all stations/products; defer station/category/item-specific SLAs to avoid conflicting rules and unreconciled reports.
* Late alarm fires once when a ticket first crosses the threshold in a running kitchen screen; retain late styling until it leaves active state and do not replay each poll. Current `_overdueAlertedIds` already dedupes per screen lifetime, but threshold/label are hard-coded 30/`TRỄ 30P!`; bind effective store setting and consider persisted/device event dedupe across restart.
* Deferred sound-toggle issue: UI toggles in-memory mute, but eligibility hard-requires canonical role `kitchen`; Owner/Manager/misclassified Head Chef may see icon change while bell/done audio never runs, and static mute can desync after recreation. Record only; role/device eligibility and persistence behavior are not decided in current scope.
* Canceled tickets are excluded from average/fastest/slowest queue-prep-total metrics and completion-rate numerator/denominator. Show a separate authorized canceled count/list with reason/actor/time; never coerce canceled to done to stop timing.
* Reopened completed ticket remains one ticket/done fact; use final completion time, expose reopen count/events/actor/reason where present, and preserve prior completion transition history.
* Reopen timing: total = final done - sent; preparation = sum actual doing-state intervals, excluding completed-to-reopen gaps; queue = first start - sent. Add append-only transition events because mutable sent/started/done summary columns cannot reconstruct multiple cycles.
* Ticket reaches done/completion metrics only when all non-voided items are done. Partial item completion keeps ticket doing; item timestamps support progress/detail but never increment ticket done or close duration early.
* Multi-station ticket completes only after all non-voided items across stations finish. Each station views/mutates its scoped items; station completion updates progress only and must not close ticket, announce whole order ready or set final done early.
* Kitchen report filters All/Hot/Drinks like realtime screen, using immutable station snapshot on ticket items; later menu-station changes do not rewrite history. Late threshold remains store-wide.
* All-station ticket KPI counts unique tickets. Station-filter workload counts item quantity/portions, not whole tickets per station; label units explicitly. Realtime cards may remain ticket-based, but report aggregation uses item facts.
* Station report includes top processed items by non-voided quantity with snapshot name and operational item drill-down; no price/revenue/profit fields.
* Station report may rank frequently late items only with >=5 valid observations in active range/filter; show sample size, omit low-sample labels while retaining detail access.
* Late-item row shows late count/total, late rate and sample size; default sort by late rate then count/quantity with stable tie-breaker. Drill-down must reconcile numerator/denominator under identical filters.
* Item lateness uses that line's done_at - ticket sent_at, not final ticket completion; exclude voided lines so fast items are not penalized by other items/stations.
* Current item-timing debt: local schema has item started/done timestamps, but model reads only done bool and toggle updates only bool. Add atomic item transition/actor timestamps and server aggregates; ticket done time is not a valid substitute.
* Completion is per ticket-item line. A quantity x3 line completes all three portions with one tick; no 1/3 or 2/3 progress. Different completion times require distinct immutable source/dispatch lines.
* Item late rate uses line occurrences: x3 line = one processing observation/event, while affected/late portions records quantity 3. Keep observation rate and impacted quantity as separate metrics.
* Exclude legacy rows without valid item done_at from item-level late numerator/denominator, show insufficient-data/coverage, and never infer from final ticket done. They may remain in ticket metrics when ticket timestamps are valid; do not fake-backfill.
* Current state/debt: `_filterByStation()` already filters visible items using station code/name fallback and station tabs exist, but badges count filtered ticket cards and global stats ignore station filter. Add server item/station snapshot aggregates; avoid keyword fallback in historical reporting.
* Report → Inventory item/ingredient click opens paginated movement ledger under same store/range/filter: receipts, sale/recipe consumption, wastage, counts, returns and adjustments. Show signed qty/unit snapshot, optional before/after balance, occurred time, actor and immutable source reference; never infer history from current stock.
* Inventory report reconciles opening + movements to expected closing/current canonical balance. On mismatch show expected/actual/difference and suspicious sources; never auto-fix/backdate/insert hidden balancing movement. Resolution requires audited count/adjustment workflow.
* Sale-consumption movement links to authorized invoice/order and line→recipe-version/quantity snapshot→ingredient deduction breakdown. Never recalculate old consumption using current recipe; preserve units/conversion/source IDs.
* Ledger presentation may group same ingredient+checkout deductions into one total row, but immutable allocations remain per order line/recipe component. Detail/export exposes item sold, qty, recipe version, dosage and contributed deduction.
* Receipt movement opens authorized purchase/receipt detail with supplier, ordered vs actual received quantity, unit/cost snapshot, receiver/approver and time. Stock increases only on accepted actual receipt; partial receipts append events against purchase line, never overwrite prior receipts.
* Warehouse staff see operational qty/unit, supplier contact needed for receipt and source document only. Cost/totals/payment/AP debt are Owner/Manager only. Redact fields server-side in detail/export; never ship financial supplier data then hide client-side.
* Expiry-tracked item detail breaks stock down by immutable lots: receipt/source, received/expiry dates, original/remaining qty and normal/near-expiry/expired status. Keep aggregate total but preserve lot movement/allocation and FEFO traceability.
* Expired lot qty remains physical/on-hand until approved disposal movement, but is excluded from available-to-consume/sell and shown red. Never auto-delete at expiry; allocators reject expired lots and must make negative-stock fallback explicit rather than consuming expired stock.
* One per-store `expiry_warning_days` setting, default 3, controls near-expiry lot status; no per-item/category override. Compute by store date/timezone, and separate already-expired lots from near-expiry count.
* In-app expiry alerts target Warehouse, Manager and Owner in authorized store only; exclude Waiter/Cashier/Kitchen roles at server audience query.
* Future roadmap may add Zalo/Telegram channels. Current scope has no provider/binding/verification/template/delivery/retry/dedupe/opt-out implementation; in-app remains canonical.
* Near-expiry notifications are one daily digest per store/business date. First transition of each lot to expired emits one red alert keyed idempotently by store+lot+transition; current-state badge/list remains visible independently of one-time delivery.
* Active lot alert resolves only when remaining qty reaches zero via valid consumption or approved disposal/adjustment. Read/ack changes notification state only, never lot/warning; audit alert creation, acknowledgment and resolution source separately.
* Report → Finance category rows drill down to the constituent finance transactions under the same store/period/category. Show amount, occurred time, typed source document and creator/approver audit where applicable; reuse the existing Thu Chi transaction list rather than create a disconnected ledger.
* Current finance state/debt: Thu Chi already lists dated records and auto POS income can open an invoice by parsing its description, but Report Finance category `TableRow`s are aggregate-only. `FinanceRecordModel` drops `reference_id` and has no creator/approver fields, so add typed immutable source linkage and actor audit; never use description parsing as the canonical relationship.
* Revenue hour/day bars already support selection/highlight plus tooltip (time, revenue, order count) through `_selectedBar`; this is not invoice drill-down. Preserve that interaction and add an explicit path from the selected bucket to its reconciled invoice list under identical canonical filters.
* Revenue-bucket invoice drill-down is lazy only: no invoice-list preload with chart data. Server-page about 20 rows per request under indexed store+time filters, fetch minimal list projections, and load full invoice detail only on selection.
* Revenue-bucket invoice list supports combinable quick filters for cash/bank payment and cashier, default All. Recompute visible invoice count and amount from the identical server filter; use payment/cashier snapshots and immutable cashier ID, never description parsing.
* Add debounced server-side search by invoice code or table snapshot within the active revenue bucket/payment/cashier filters. Keep pagination and count/amount reconciliation under the identical predicate; never broaden search outside the selected store/period.
* Do not add a dedicated CSV/Excel export for a revenue-bucket invoice list; keep it as an on-screen audit/drill-down and rely on the canonical consolidated report export.
* Exclude canceled invoices from revenue-bucket drill-down entirely because they are not part of canonical revenue. Keep canceled/void audit in Hủy/Duyệt and never mix its counts or amounts into the revenue bucket list.
* Revenue report invoice drill-down is Owner/Manager only. Enforce role/action plus store scope server-side for list, search, count, totals and detail; UI hiding is not authorization.
* Finance expense-category drill-down does not show paid/unpaid or debt status. Keep AP/payroll obligation state in its authorized source module; the report list represents recognized finance records only and must not invent debt state from missing payment data.
* Manual expense records support receipt/document image attachments visible from Thu Chi and authorized report detail. Current sheet/model has no attachment or creator actor; add private object storage plus store-scoped attachment metadata, short-lived signed access and server authorization. Never store image base64 in `finance_records` or expose a public bucket URL.
* Manual-expense attachment is optional: camera/library are convenience paths, absence must not block creation or exclude the record from finance totals. Show missing evidence neutrally, not as an invalid transaction.
* A manual expense may have multiple ordered image attachments. Store immutable per-file metadata/hash/uploader/time, audit removal/replacement, and render an authorized gallery; do not overwrite an old storage object in place.
* Cap manual-expense evidence at five images. Normalize orientation and compress/resize client-side while preserving legibility, then enforce count/MIME/size again server-side and reject unsafe content regardless of client validation.
* After creation, only Owner/Manager may mutate expense attachments. Enforce on server and audit add/remove/replace/reorder with actor/time; read access never implies attachment mutation.
* Only Owner/Manager create manual finance records. Add distinct server-enforced actions for create/edit/void/approve instead of treating module or `finance.view_all` access as mutation permission.
* Manual finance records are editable by Owner/Manager only with mandatory reason and append-only before/after version audit. Aggregate the current effective version while retaining full history.
* Never hard-delete a manual finance record. Void with mandatory reason/actor/time; exclude the voided record from active totals and expose it only through authorized control history.
* Auto finance records from POS/Inventory/Payroll/source modules are immutable in Thu Chi. Correct them through typed source reversal/adjustment events, never direct finance-row mutation.
* Owner configures one expense approval threshold per store; unset means approval disabled. Manager-created records above it become pending and only Owner approves; Owner-created records auto-approve with an auditable actor/event.
* Pending expense has no cash-fund or P&L effect. Approval atomically/idempotently activates it exactly once. Rejection requires reason and retains a rejected record; notify Owner in-app within the store.
* Editing an approved expense amount such that it remains above threshold invalidates effective approval and routes the new immutable version for reapproval; retain earlier version and approval history.
* Evaluate approval threshold per transaction, not daily aggregate, with one common per-store amount across categories and cash/bank funds.
* Manager can see status/reason for submitted records, revise a rejected record as a new version and resubmit, or withdraw a pending record with mandatory reason. Withdrawal is audited and has no ledger effect.
* Owner approves inside the authenticated module without PIN. Show a store-scoped pending badge. No bulk approval: review/approve/reject each record with details, evidence and history visible.
* Manual income uses the same Owner/Manager edit + soft-void reason/version audit as manual expense, but expense approval threshold never applies to income.
* Manual income supports the same optional private evidence gallery capped at five images.
* Manual records may choose business `occurred_at`, never a future timestamp. Manager backdating requires reason; always preserve separate immutable created_at/creator so reports can use occurred_at without hiding late entry.
* Owner/Manager manage finance categories. Referenced categories are archived/inactivated, never deleted; retain immutable category name/type snapshot on finance facts so later renames do not rewrite history.
* Each store currently needs exactly one cash fund and one bank fund. Bank/transfer never affects drawer cash; scope all balances and mutations by fund type.
* Owner establishes opening balances through auditable opening-ledger events, never by overwriting a computed total.
* Cashier records counted opening cash at shift start and actual cash at close, linked to the cashier/attendance shift while remaining a separate finance fact. Expected close = opening cash + cash sales + manual cash income - manual cash expense +/- authorized adjustments.
* Cash discrepancy requires reason and Manager approval. Preserve expected/actual/delta/counter/time/approver/decision and never auto-insert a hidden balancing transaction.
* Fund report separates sales, manual income, manual expense and adjustments with reconcilable source drill-down.
* Current state/debt: fund tabs/filter already exist. UI shows income/expense/profit rather than a canonical balance; CSV derives opening balance from all prior rows. Ops contains textual cash-count checklist items only, not persisted count/reconciliation/approval records.
* One shared drawer per store, never per cashier/device. Enforce one active custody session while allowing many POS devices to post cash sales into it.
* Cashier handoff requires outgoing close/count plus incoming recount/acceptance, preserving both actors/times/amounts and transferring custody explicitly.
* Prefill opening count from prior actual close/handoff but require recount. Opening discrepancy needs reason and Manager approval before custody acceptance.
* Cashier drawer close is a prerequisite to attendance checkout. Manager may close on behalf only with reason/audit and must remain the true actor. No mid-shift cash-drop feature; counts store total only, not denomination breakdown.
* Drawer close is blind: do not reveal expected cash before cashier submits actual count. Cashier cannot edit after submission; Manager resolves through auditable workflow.
* Store configures one discrepancy tolerance. Persist every delta, but require reason/escalated warning only above tolerance.
* Approved discrepancy creates an explicit balancing adjustment event rather than mutating balance. Preserve expected/actual/delta/short-or-over/reason/shift/custodian/approver/time and notify Owner in-app; mark above-tolerance alerts high priority.
* No drawer photo and no dedicated printed/exported close slip; retain the authorized close record in-app.
* Delta within tolerance auto-accepts and emits an explicit adjustment, with no Manager approval/reason, while retaining an `auto_accepted_within_tolerance` fact for trend/audit.
* Default tolerance is VND 20,000 and Owner-only per-store configurable, prospectively only.
* Enforce segregation of duties: drawer custodian cannot approve own above-tolerance discrepancy. Manager custodian requires Owner approval.
* Owner may reopen an approved close only with reason and append-only revision/audit; never overwrite the old close or delete its prior adjustment.
* Do not pause cash checkout during handoff. Use an atomic custody cutoff so concurrent cash payments belong exactly once to the old or new session.
* Offline close remains local draft and blocks attendance checkout until server sync, or Manager closes on behalf with reason. Make submission/retry idempotent to prevent duplicate closes/adjustments.
* Block cash checkout without an active store drawer-custody session and show a clear business message/action to open or accept drawer. Bank transfer remains available.
* Many cashiers/devices may post cash concurrently into one active shared custody session. Preserve both transaction cashier and drawer custodian/session on each invoice; never conflate them.
* Cashier/Manager/Owner may open/accept drawer. On custodian logout or shift end, prompt close/handoff and never silently transfer custody.
* Drawer close/discrepancy reports are Owner/Manager only. Trend deltas by cashier/time for control, but never auto-label fraud or deduct pay.
* Above-tolerance discrepancy sends immediate Owner alert and appears in Owner daily report with source close/reason/decision link.
* Separate cash flow from profit. Cash flow uses actual fund movements; profit uses revenue minus COGS and recognized operating expenses. Never label raw finance income-minus-expense as profit.
* Recognize utilities/rent/repairs as operating expense and payroll expense only after Owner-approved/finalized payroll.
* Owner contributions and withdrawals are capital flows, not revenue/expense, and require explicit ledger dimensions/categories excluded from P&L.
* If recipe/cost coverage is incomplete, show profit as unavailable/partial with coverage, never zero-fill COGS and display 100% margin.
* Critical current debt: inventory receipt writes purchase amount as finance expense and recipe consumption writes COGS expense, while FinanceStats subtracts all expense rows together. Introduce typed double-entry/ledger dimensions or equivalent canonical classification so purchase cash outflow/inventory asset and sale COGS cannot double-count P&L.
* Receipt purchase reduces fund cash and increases inventory value without immediate COGS. Sale consumption transfers recipe quantity cost from inventory to COGS in the related revenue period; remaining inventory retains value. Approved spoilage/disposal becomes loss expense only on its own movement.
* Allocate ingredients FEFO and price COGS from immutable receipt-lot cost. Include plain Owner-facing setup/workflow explanations so cost changes are traceable, not black-box behavior.
* Legacy rows without valid lots may use explicitly labeled current weighted-average fallback; never synthesize false historical lots or present fallback as exact lot cost.
* Snapshot recipe/version, costs and allocations at checkout. Later receipt/recipe/menu edits affect future facts only.
* Direct/topping products without recipes use their own allocated inventory/lot cost.
* Missing recipe/cost/stock warns but does not block sale. List missing ingredient and, for stock shortage, required/available/short qty with unit conversion. Preserve negative movements as agreed and mark incomplete P&L coverage.
* Discount/voucher reduces net revenue only, not physical consumption/COGS. Report wastage separately from sale COGS.
* Product-level revenue/COGS/profit drill-down is Owner/Manager only and server authorized, with immutable recipe/lot allocation evidence.
* Put the costing readiness checklist inside **Professional Inventory**, adjacent to Recipes/Quantities, not Settings: units → opening lots/receipt costs → recipes → validation. Deep-link to canonical screens and never duplicate forms/truth sources.
* Incomplete checklist never blocks POS. Report shows coverage/unavailable profit and routes back to Professional Inventory. Progress counts active inventory-managed sellable items only; exclude inactive/deleted/non-stock-managed items and deep-link missing rows.
* Stock role records lots/expiry/receipt cost; Owner/Manager alone mutate recipes. Missing receipt cost warns but may save, retaining explicit incomplete-cost state.
* Owner daily report lists missing-cost items. Label only fallback-valued figures as `Estimated` with source/reason when weighted average substitutes for exact lot allocation.
* Current state/debt: professional inventory already has recipe list/detail/form, quantities and cost previews plus receipt-cost input, but no centralized readiness checklist/coverage/deep links or exact-vs-estimated report provenance.
* Owner/Manager see the full checklist; Stock sees assigned receipt/lot/cost steps only. Completed checklist collapses green but stays reopenable, and automatically becomes incomplete when a newly active item lacks required data.
* Send one daily missing-cost digest, not per-transaction spam. Operational required/available/short ingredient warnings are Kitchen/authorized management only, not Waiter/Cashier; cost/profit details remain Owner/Manager only.
* On kitchen ticket arrival, render shortage warning on the ticket and Kitchen notification area with ingredient required/available/short quantities and units, without obscuring preparation notes.
* Kitchen can acknowledge only and cannot mutate stock/lots/recipes. Do not add an in-app shortage-report/chat action; store staff coordinate via their external group chat and current scope has no outbound group integration.
* Dedupe repeated ingredient shortage notifications while retaining per-ticket evidence. Recompute and silently clear shortage state after replenishment; no replenished notification.
* Shortage never auto-disables menu availability. Only Owner/Manager may change `is_available`; Kitchen has no availability mutation permission.
* Kitchen acknowledges one grouped shortage, not each ticket. Ack mutes/unreads only; per-ticket shortage marker remains until availability recovers.
* Dedupe sound per store+ingredient for 90 minutes while still rendering/logging each new affected ticket; allow sound again after window on a new shortage event.
* Ingredient shortage and overdue-food alerts have equal priority and must coexist without suppression by priority.
* Owner/Manager view daily shortage history and top shortage ingredients with occurrence/affected-ticket/quantity evidence for purchasing support. Never auto-punish or infer staff fault/payroll deduction.
* Professional Inventory suggests purchase quantity from current available stock, recipe demand and recent sales velocity. Default horizon 7 days with 3/7/14 quick choices.
* Suggestion is advisory only. Owner/Manager/Stock may view scoped explanations/input/coverage, but system never auto-orders or receives stock.
* Multi-select suggestions can create a purchase draft only. Authorized user must verify supplier/price/unit/qty and confirm; draft has zero stock/cash effect.
* Future AI Bum may explain scoped suggestions and prepare drafts after explicit user request, but cannot send/approve/receive/create ledger effects autonomously. Require confirmation, server authorization and audit for every write.
* AI Bum is advisory/reminder-only. Enforce row/field-level caller permissions in retrieval and response; Stock must not receive cost/profit unless explicitly authorized.
* AI suggestions cite current stock, average sales, forecast horizon, proposed qty and data timestamp. Explicitly label estimate/missing coverage and never fabricate certainty.
* `Create a 7-day purchase draft` requires preview of ingredients/qty/rationale and explicit confirmation, and creates draft only with no stock/fund effect.
* Allow one deduped daily proactive shortage forecast reminder to authorized store recipients. No autonomous Zalo/Telegram/supplier messaging in current scope.
* Model many suppliers per ingredient with one preferred relation and purchase-unit/packaging/latest-price provenance; do not serialize supplier lists into product text.
* Purchase draft prefills preferred supplier plus latest valid price for the exact ingredient-supplier pair, always editable before confirmation.
* Show supplier-specific price history. Warn Owner/Manager when new price exceeds the last valid same-pair receipt by per-store threshold, default 10%; advise only and never auto-select cheapest supplier.
* Archive/inactivate departed suppliers while preserving immutable PO/price/contact snapshots.
* Current state/debt: supplier CRUD/optional PO selection/unit-cost lines/soft-delete already exist, but quick receipt uses product-wide latest cost and there is no many-to-many preferred mapping, pair price history or increase alert.
* Stock may draft ingredient/qty/supplier but cannot read or mutate monetary price fields. Owner/Manager alone enter/view/edit/approve purchase prices; redact server response, not client-only hiding.
* Price-increase comparison normalizes package/unit conversions and is visible only to Owner/Manager. Above-threshold warning does not block receipt, but acceptance requires reason and audit of old/new/percent/unit/actor/time.
* Store simple factual supplier receipt evaluation: on-time/late from expected-vs-received time, complete/short from ordered-vs-accepted qty, and receiver-selected quality OK/Issue with optional note.
* Supplier detail shows factual history/metrics only. No stars, automatic good/bad label, ranking or autonomous supplier selection, especially on small samples.
* Support multiple immutable receipt events per PO line with clear ordered/accepted/remaining/rejected progress and receiver/time on each event.
* Capture quality per received line. Immediate rejected qty requires evidence and never creates stock lot, available qty or purchase financial effect.
* Post-receipt defects move by movement into quarantine, excluded from available/FEFO, before authorized return/exchange/disposal handling.
* Supplier return stores ingredient/lot/qty/reason/actor/time and optional images. Financial outcome is explicit cash refund/bank refund/supplier credit/exchange/no compensation and activates only on confirmed outcome.
* Confirmed receipts are immutable; correct with append-only receipt/adjustment/quarantine/return/disposal events.
* Current state/debt: PO creation marks received and applies stock/finance once; no multi-receipt accepted/rejected quality evidence, quarantine or supplier-return state machine exists.
* Immediate rejection and later-discovered defect each require at least one private, authorized, audited image attached to the exact receipt/lot/defect event.
* Stock proposes return/exchange/disposal; Owner/Manager approves. Provide an Owner-facing guided flow: detect → evidence → quarantine → choose/approve → confirm handoff/disposal → inventory/finance effect.
* Quarantine remains physical on-hand but unavailable. Quarantine transfer decreases available/increases quarantine with no total change; actual supplier handoff/disposal atomically decreases quarantine and physical exactly once. Approval alone does not remove physical stock.
* Exchange removes defective lot on handoff and adds replacement only through a new receipt. Refund records actual cash/bank finance link; supplier credit activates only with confirmation and optional reference/image evidence.
* Physical stock decreases only on authorized `handed_to_supplier`, not approval. Stock/Manager/Owner may confirm with actual qty/time/actor and optional supplier receiver identity.
* Support partial handoffs, leaving remainder quarantined. Before handoff, authorized cancellation may restore available stock only after reinspection with reason/audit.
* Confirmed handoff/movement is immutable; correct with a linked adjustment event.
* Owner/Manager report pending/resolved defective stock by item/lot/supplier/age. Include unresolved quarantine older than three days in Owner daily report.
* Stock count supports full or selected scope and blind entry: hide system expected until Stock submits actual.
* Every variance requires reason and Owner/Manager approval. Lot-tracked inventory is counted per immutable lot/expiry.
* Keep POS/inventory live. Capture count snapshot/cutoff and server-reconcile intervening movements before computing variance; never overwrite concurrent sales/receipts with stale actual.
* Approval atomically/idempotently emits append-only item/lot adjustment movements and preserves scope/snapshot/actual/variance/reason/counter/approver/times.
* Current state/debt: repository has draft counts/items and client-side confirm/movement/status, but no complete UI, approval/reason/lot count or server snapshot reconciliation; direct `stock_qty=actualQty` can erase intervening movements.
* Split count scope among multiple Stock staff but assign each item/lot to exactly one counter per count round with server conflict protection.
* Allow drafts. Submission locks staff edits; Manager-requested recount appends a new attempt/revision and preserves old/new/reason.
* Only approved count facts emit stock adjustments. Draft/submitted/recount-pending has no inventory effect. Keep records in-app only; no dedicated print/export.
* Approve the whole count only after all lines/recounts resolve, not line-by-line, to preserve one reconciliation boundary. Owner/Manager approves, but Manager who counted any part cannot self-approve; Owner required.
* Zero-variance lines need no reason. Show Assigned/Counting/Submitted/Recount/Complete progress with scope and assignee.
* Owner configures weekly/monthly count reminders. Overdue/pending-approval counts appear in Owner daily report and never auto-adjust stock.
* Offline count is local draft only. Submit/recount/approve/adjust require successful server sync with revision/idempotency/conflict handling; never last-write-wins inventory.
* Platform database backup/restore is app-operator responsibility, not store Owner/Manager/staff self-service. Do not expose full DB download/restore in tenant UI.
* Plan automated weekly backup. Operator later defines retention/encryption/off-host copy/restore testing and scope. Keep infrastructure backup distinct from tenant reports/exports, audit every operation, and preserve multi-store isolation/RLS during recovery.
* Delivery priority: correctness, security and loss/duplicate prevention before feature expansion. Stabilize POS + Tables + Kitchen + Payment + Inventory first; unrelated modules do not enter P0 unless they block this core flow.
* Offline is required in the first upgrade, except POS→KDS LAN transport remains deferred. Offline P0 is local open/add, explicit unsynced state, cash checkout, audited manual transfer confirmation, idempotent auto-sync and Manager conflict handling.
* Design new schema/auth/API as multi-store-capable now, but defer the complete multi-store management UI. Never introduce new single-store Owner assumptions.
* Android/Web already exist; iOS publishing is in progress. Preserve current Android/Web behavior and keep core changes iOS-compatible instead of treating all three clients as greenfield.
* Pilot store is KAY. Current pilot acceptance is manual end-to-end verification with recorded build/device/account/time/result evidence across table→kitchen→payment→inventory→finance plus offline/reconnect cases.
* Manual pilot testing does not prove idempotency/concurrency/crash safety. Keep integration, fault-injection and duplicate-prevention tests as P0 debt required before broad rollout, though they do not block the first KAY pilot loop.
* Classify all documented work P0/P1/P2 and implement P0 only first: P0 = core correctness/security/required operation; P1 = important operating improvements after stabilization; P2 = future expansion/automation/integrations. Document order is not implementation order.
* Do not add recurring expense reminders in current scope.
* Current finance mutation debt: UI has add + permanent-delete only; delete dialog has no reason and repository issues `.delete().eq('is_auto', false)`. There is no edit/version/soft-void/threshold approval/deferred ledger effect, and finance permissions only expose module plus `finance.view_all`. Existing reason capture belongs to voided food/bills, not finance records.
* Nợ kỹ thuật void-to-invoice linkage: current soft-cancel + `void_audit_logs` preserves audit, but checkout excludes `kitchen_status='huy'`; void references session-item while paid order `source_id` stores table ID rather than immutable session/lineage. Persist order-session lineage and link void/source lines so invoice detail cannot mix later occupants of the same table.
* Build reusable authorized drill-down primitive/source-filter contract across report tabs; same canonical aggregate/list boundary, server pagination, no per-card ad-hoc direct queries.
* Nợ kỹ thuật: hiện chủ yếu live dashboards/kitchen stats; chưa snapshot/scheduler. Thêm timezone/business-day job, canonical aggregation, revision/reconciliation và notification outbox.
* Nợ kỹ thuật export: existing finance CSV/module PDFs chưa phải daily revision artifact. Thêm secure server export, audit, signed download và CSV formula-injection escaping.
* Nợ kỹ thuật alerts: hiện event bus/direct notification inserts, chưa durable outbox/delivery/retry/dedupe. Thêm server rules, thresholds, delivery ledger và dead-letter monitoring.

---

## 4. Cấu Trúc Cơ Sở Dữ Liệu Self-Hosted & Quy Chuẩn Tra Cứu Dữ Liệu (Database Architecture)
* **Domain & Router Gateway:**
  * Supabase Studio: `https://quannho-db.lpm.vn` (Proxy tới Studio port 3003).
  * API Gateway: `https://quannho.lpm.vn/supabase/` (Proxy ưu tiên `^~ /supabase/` tới Kong Gateway port 8000).
  * POS Web: `https://quannho.lpm.vn/pos/` (Phục vụ từ `/var/www/quannho/pos`).
* **Bảng Dữ liệu Nhân viên chuẩn (`staff_members`):**
  * Toàn bộ nhân viên thu ngân và phục vụ của quán được lưu trữ duy nhất tại bảng **`public.staff_members`** (`id`, `store_id`, `name`, `role`, `phone`, `is_active`, `modules`, `actions`).
  * Mọi truy vấn báo cáo (`DashboardRepository`, `ReportScreen`, `PosRepository`, `BanRepository`) phải tra cứu trực tiếp từ bảng `staff_members` thay vì bảng cũ `store_members` để tránh lỗi hiển thị *"Nhân viên ẩn"*.
  * **Quy chuẩn Phân quyền Trực Tiếp (Direct Per-User Permissions - Thống nhất 2026-07-28):** Hệ thống không dùng Role trung gian rắc rối để cấp quyền nữa. Mỗi nhân viên được lưu trực tiếp danh sách `modules` (`["pos","table","kitchen","log_viewer"]`) và `actions` (`["pos.cancel_bill"]`) ngay trong `staff_members`. AI Bum và toàn bộ ứng dụng đọc trực tiếp danh sách này để hiển thị UI chính xác 100%.
* **Bảng Nhật Ký Hoạt Động & Khuyến Mãi (`app_logs`, `coupons`, `void_audit_logs`):**
  * **`public.app_logs`**: Nhật ký hoạt động và theo dõi lỗi ứng dụng (`id`, `store_id`, `device_id`, `staff_name`, `level`, `tag`, `message`, `details`, `created_at`).
  * **`public.coupons`**: Bảng quản lý khuyến mãi & voucher (`id`, `store_id`, `code`, `description`, `discount_type`, `value`, `min_order_amount`, `max_discount_amount`, `is_active`, `start_date`, `end_date`).
  * **`public.void_audit_logs`**: Bảng nhật ký hủy món & hủy bill (`id`, `store_id`, `void_type`, `reference_id`, `label`, `reason`, `amount`, `details_json`).
* **Quy trình Audit & Dọn dẹp dữ liệu:**
  * Thứ tự xóa dữ liệu thử nghiệm đúng chuẩn khóa ngoại Foreign Key: `kitchen_tickets` $\rightarrow$ `ban_sessions` $\rightarrow$ `orders` $\rightarrow$ `finance_records` $\rightarrow$ `stock_movements`.

---

## 5. Phát Hành & Đăng Ký Nhà Phát Triển (App Distribution & Store Status)

### Google Play Store (CH Play / Android)
* **Tên gói (Package Name):** `vn.lpm.quannho_pos`
* **Trạng thái xuất bản:** **Phát hành công khai (LIVE 100%)** từ ngày 22/06/2026.
* **Xác minh Nhà phát triển:** Đã đăng ký xác minh tên gói chính chủ cho doanh nghiệp `LPM Digital`, đáp ứng 100% tiêu chuẩn bảo mật Android 2026.
* **Phân phối thiết bị POS:** Trích xuất file Universal APK từ *Trình khám phá gói ứng dụng* để cài đặt trực tiếp trên các dòng máy POS Android F&B/Retail (Sunmi, iMin...).

### Apple App Store (iOS)
* **Tài khoản Doanh nghiệp:** `LPM DIGITAL COMPANY LIMITED` (Team ID: `V4HN95W2C7`).
* **Mã định danh App (Bundle ID):** `vn.lpm.quannhoPos`.
* **Tài khoản Reviewer mặc định (Embedded Auth):**
  * SĐT Đăng nhập: `0999996666`
  * Mật khẩu: `112233`
  *(Đã tích hợp sẵn fallback trong `UserAuthService` giúp người kiểm duyệt của Apple / Google đăng nhập ngay lập tức cả online lẫn offline).*
* **Trạng thái nộp duyệt App Store:** 
  * Gói build: Version `1.0.2 (Build 4)` - Dung lượng 50.6 MB.
  * Chứng chỉ phát hành: `Apple Distribution Certificate` & Profile `QuanNhoPOS_AppStore`.
  * **Đã nộp duyệt thành công (Submit for Review) ngày 28/07/2026** (Trạng thái: 🟡 *Waiting for Review* | Submission ID: `51953799-d687-4464-a0a3-5a026c418b7f`).

---

## 6. Phân Hệ Trợ Lý AI Bum (AI Bum Assistant Pilot - Quán Kay) — Cập nhật 07/08/2026

### Hạ tầng Máy chủ Server Host (`BunServer`)
* **OS:** Ubuntu Desktop 24.04.4 LTS (Kernel `7.0.0-28-generic`).
* **Tailscale IP:** `100.113.221.116`.
* **Phần cứng:** Dual Intel Xeon E5-2680 v4 (56 threads), 128 GB RAM, NVIDIA GeForce RTX 2060 (6 GB VRAM, Driver `595.84`, CUDA `13.2`).
* **Ổ đĩa:** Ubuntu trên Kingston SATA SSD `/dev/sda`. Ổ Windows 10 NVMe `/dev/nvme0n1` được bảo vệ nguyên vẹn 100% (Rollback Plan).
* **An ninh & Vận hành:** Firewall UFW fail-closed (chỉ mở 22/SSH, 3389/XRDP trong Tailscale/LAN), mask 4 target sleep/suspend, Docker Engine `29.7.2` + NVIDIA Container Toolkit `1.19.1`.

### Kiến trúc AI Bum Gateway & Engine
* **Mô hình AI Local:** `Qwen2.5 3B 4-bit` chạy trên container Ollama GPU (`bum-ollama` port `127.0.0.1:11434`), đạt tốc độ **45–55 tokens/s**, TTFT `~0.25s`, VRAM chiếm `1.9 GB`.
* **Flutter Client (`lib/features/ai_assistant/`):**
  * `BumChatScreen`: Bottom Sheet Responsive (Mobile `< 600px`, Tablet/PC `>= 600px`).
  * `IntentClassifier V1`: Phân loại ý định bằng Rules & Semantic Matching (**Accuracy 96.25%**, **Macro-F1 0.9643**).
  * `RagEngine V1`: Tra cứu tài liệu nghiệp vụ 11 module (**Precision@1 96.67%**, **Precision@3 96.67%**).
  * `PiiRedactor` & `OpenAiFallbackService`: Khử 100% SĐT, email, mã PIN trước khi gửi Cloud Fallback; hỗ trợ Circuit Breaker & Quota per Store.
  * `FeedbackMemoryService`: Lưu phản hồi 👍/👎 và Trí nhớ riêng của quán cô lập theo `store_id`.
  * `ShadowTestFeatureFlag`: Kích hoạt Shadow Mode thử nghiệm độc quyền cho **Quán Kay** và tài khoản Owner.
* **Database Supabase (`supabase/migrations/20260807000000_ai_bum_phase2_readonly_tools.sql`):**
  * 4 Bảng AI: `bum_conversations`, `bum_messages`, `bum_feedback`, `bum_memories` (có RLS).
  * 10 Read-Only RPCs: `get_today_sales_summary`, `compare_sales_periods`, `get_top_products`, `get_slow_products`, `get_low_stock_items`, `get_stock_forecast_inputs`, `get_finance_summary`, `get_staff_on_shift`, `get_pending_operations_tasks`, `get_store_context_for_bum`.
  * Khử 100% PII, cô lập tuyệt đối theo `store_id`.
