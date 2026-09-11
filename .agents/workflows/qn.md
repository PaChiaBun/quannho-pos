---
description: Điều phối Graphify để hiểu kiến trúc và CodeGraph để truy nguyên, sửa lỗi Quán Nhỏ POS
---

# Workflow `/qn` — Quán Nhỏ POS

Đây là workflow `qn.md` chuẩn của dự án. Khi gọi `/qn` hoặc đính kèm file này, làm việc theo luồng dưới đây. Không gọi hai graph lặp lại cho cùng mục đích.

## 0. Điều phối nhanh — kiểm duyệt bài AI Bum

Khi Chủ Quán gọi **`/qn vào kiểm tra ai bum đã làm bài chuẩn chưa`**, hoặc diễn đạt tương đương như “kiểm duyệt bài Bum”, “xem Bum học tới đâu, bài có đúng không”, tự chọn nhánh này. Đây là yêu cầu **kiểm tra nội dung và chủ động kiểm duyệt**, không chỉ xem dịch vụ/job còn chạy. Nếu người dùng nói rõ chỉ xem trạng thái, chỉ báo cáo, hoặc không duyệt thì tuân theo phạm vi hẹp đó.

**Ủy quyền đã có:** Chủ Quán giao Codex quyết định `approved` / `needs_revision` / `rejected`, kèm lý do; không hỏi lại quyền duyệt từng bài hoặc mỗi lần gọi. Tiết kiệm quota là yêu cầu mặc định.

Luồng thực hiện:

1. Đọc đúng `../ai-bum-implementation/training/REVIEW_DESIGN.md` (đường dẫn tính từ root `quan_nho`), rồi manifest/checkpoint kiểm duyệt hiện có. Không nạp lại toàn bộ nhật ký, source, bài cũ hoặc hai graph cho công việc đọc/duyệt dataset thông thường. Chỉ dùng quy trình điều tra code bên dưới nếu phát hiện lỗi cần truy nguyên.
2. Kiểm tra metadata hiện tại của dịch vụ/job và số bài chờ duyệt. Không tạo/resume lô mới chỉ để kiểm duyệt; không coi nhật ký cũ là trạng thái đang chạy.
3. Dùng `review_queue.py pack` theo tài liệu thiết kế trên snapshot được phép xử lý. Đọc manifest rồi lần lượt các trang chưa có quyết định; ưu tiên xử lý tại nơi lưu dữ liệu, không tự sao chép toàn bộ kho sang máy khác. Nếu quyền truy cập hoặc công cụ chưa sẵn sàng, nói rõ phần bị chặn, không báo đã kiểm tra nội dung khi mới xem số lượng.
4. Đọc đầy đủ dữ kiện, câu hỏi và đáp án dự tuyển; dùng phép tính deterministic hỗ trợ. Chỉ mở bài làm/nhận xét của Thầy khi cần đối chiếu. Gộp duyệt chỉ cho nội dung trùng chính xác; không duyệt theo điểm, theo mẫu đại diện cho bài khác nội dung hoặc theo bản tóm tắt bị cắt ngắn.
5. Ghi quyết định ngắn theo hash/version, đáp án được duyệt và danh tính reviewer. Lưu checkpoint sau mỗi trang; tiếp tục phần còn lại, không đọc lại nhóm đã duyệt còn nguyên phiên bản. Bài không đủ căn cứ phải giữ chờ hoặc đánh dấu cần sửa, không cố duyệt cho hết.
6. Phân biệt hai kết luận: **Bum làm đúng hay sai** và **đáp án chuẩn có đủ tốt để dạy Bum hay không**. Điểm học viên thấp vẫn có thể đi cùng đáp án tham chiếu tốt. Nếu đáp án tham chiếu sai, không duyệt nó chỉ vì phần feedback có đáp án sửa đúng.
7. Báo ngắn: số bài/nhóm đã kiểm tra; duyệt/cần sửa/từ chối/còn chờ; lỗi chính; checkpoint và trạng thái đồng bộ. Không chép lại cả bài làm hoặc mọi lý do vào câu trả lời.

**Ranh giới triển khai hiện tại (08/09/2026):** Công cụ kiểm duyệt mới và ledger chạy local; chưa tích hợp ghi quyết định về dashboard. Quyết định local không được báo thành trạng thái đã đổi trên BunServer. Khi đã có đường ghi server được xác minh, dùng kiểm tra hash/version và audit; chưa có thì giữ ledger và báo rõ thiếu đồng bộ. Không dùng export cũ làm dataset chuẩn vì còn lẫn câu trả lời học viên. AI Bum hiện sử dụng Qwen2.5 làm base model, được nạp và tối ưu huấn luyện/suy luận bằng framework Unsloth. Quán Nhỏ sở hữu dữ liệu tự tạo và LoRA adapter do dự án huấn luyện, trong phạm vi giấy phép của base model và các dependency liên quan. Kiểm duyệt không tự cấp quyền fine-tune, promote kiến thức, deploy POS, tạo job hoặc chạy lịch định kỳ khi chưa có chỉ thị từ Chủ Quán.

### Kích hoạt chương trình dạy AI Bum (Theo lệnh & Chạy đêm)

Chủ Quán có thể điều phối chương trình đào tạo của AI Bum qua các khẩu lệnh:
- **Theo lệnh tức thì:** Khi Chủ Quán gọi **`/qn dạy bum [số_bài]`** (ví dụ: `/qn dạy bum 10 bài`), thực hiện lệnh:
  `python3 ../ai-bum-implementation/training/run_bum_class.py run --count [số_bài]` (tính từ root `quan_nho`).
- **Chạy lớp học đêm:** Khi Chủ Quán gọi **`/qn chạy lớp học đêm`**, thực hiện lệnh:
  `python3 ../ai-bum-implementation/training/run_bum_class.py overnight --count [số_bài] --start-time 23:00` (hoặc cờ `--now` nếu Chủ Quán yêu cầu chạy ngay).
- **Kiểm tra trạng thái:** Dùng `python3 ../ai-bum-implementation/training/run_bum_class.py status` để báo cáo số bài đã duyệt, chờ duyệt và điểm trung bình hiện tại.
- **Quy tắc an toàn lớp học:**
  1. Người Thầy (Codex) ra đề và chấm bài rèn luyện tư duy 3 bước: Phân loại câu hỏi $\rightarrow$ Tra cứu đối chiếu dữ kiện RAG SQLite FTS5 $\rightarrow$ Đưa ra câu trả lời thiết thực (có Immediate Action SOP trong 30 giây).
  2. Tuyệt đối không tự ý can thiệp CSDL production hay POS; toàn bộ bài học dừng ở trạng thái `pending` cho tới khi được duyệt.


## 1. Context cố định

- Quán Nhỏ POS là ứng dụng quản lý F&B viết bằng Flutter; Android/Web đã hoạt động, iOS đang phát hành.
- Supabase là nguồn dữ liệu chuẩn. Drift/SQLite còn trong code nhưng chưa tạo thành offline hoàn chỉnh.
- Mọi dữ liệu và quyền phải cô lập theo `store_id`; kiến trúc phải hỗ trợ một Chủ quán quản lý nhiều cửa hàng.
- Pilot chính thức tại quán KAY.
- P0 ưu tiên tính đúng đắn, bảo mật và chống mất/trùng dữ liệu trong POS → Bàn → Bếp → Thanh toán → Kho/Thu Chi.
- Offline thuộc bản nâng cấp đầu; POS → KDS qua LAN làm sau.

Quy tắc nghiệp vụ lõi:

- Đăng nhập bằng số điện thoại + mật khẩu; mã quán dùng khi tham gia quán. PIN chỉ dùng phê duyệt quản lý.
- Nhiều nhân viên được order cùng bàn; lưu người mở bàn và người thêm từng món.
- Món đã gửi Bếp chỉ Chủ quán/Quản lý được hủy, bắt buộc lý do, phê duyệt và audit.
- Chỉ trừ kho sau thanh toán. Thiếu tồn chỉ cảnh báo; `is_available=false` mới khóa bán.
- QR COUNTER/mang đi phải thanh toán trước khi gửi Bếp. QR TABLE được gán vào phiên bàn sau khi nhân viên quét/xác nhận và thanh toán toàn bộ bàn theo luồng TABLE.
- AI Bum chỉ tư vấn/nhắc nhở, không tự tạo hiệu lực kho hoặc tài chính.

## 2. Quy chuẩn sản phẩm đã hợp nhất

### Nguồn sự thật và trạng thái

- Source hiện tại + migration đã apply + test là nguồn sự thật. Bản release/tài liệu cũ chỉ là lịch sử; không coi “offline 100%”, “đã deploy”, “đã duyệt store” hoặc số phiên bản là hiện trạng nếu chưa kiểm chứng.
- Supabase là data source chuẩn. Offline/hybrid, auto sync hai chiều và POS → KDS qua LAN là mục tiêu nâng cấp, không được báo đã hoàn chỉnh chỉ vì còn Drift/SQLite hoặc tài liệu cũ mô tả như vậy.
- Không đưa mật khẩu, tài khoản reviewer, IP riêng, Tailscale hoặc secret vào workflow, log, report hay output công khai.

### UI/UX và responsive

- Mobile `< 600px`; Tablet/PC `>= 600px`. Giữ Bottom Navigation cho Mobile và Navigation Rail/Sidebar cho Tablet/PC; không tự tạo nhánh Desktop riêng.
- Màn hình cấu hình phải dùng tốt trên Mobile/Tablet/PC, ưu tiên grid/card ngang gọn, vùng chạm rõ. `childAspectRatio` tham chiếu: Mobile `1.5–1.8`, Tablet/PC `2.0–2.5`; font card `13–17`, nhưng phải kiểm tra thực tế ở breakpoint thay vì áp số máy móc.

### Data, quyền và audit

- `staff_members` là bảng nhân viên chuẩn; tra cứu tên theo `staff_members.id → name`.
- **Lego Modules (`store_roles.modules`) là nguồn sự thật duy nhất cho phân quyền vai trò (Single Source of Truth)**:
  1. **Không tạo hay phụ thuộc bảng phụ `app_settings`**: Phân quyền nhân viên được cấu hình trực tiếp bằng việc bật/tắt các Lego Modules trong vai trò (`store_roles.modules`). Client và Server tuyệt đối không bắt buộc phải có bản ghi cấu hình `app_settings` (`action_perms_*`) thì mới cho phép thao tác.
  2. **Cơ chế suy diễn quyền hành động tự động (`deriveActionPermsFromModules`)**:
     - `pos` $\rightarrow$ Tự động cấp các quyền: `pos.checkout`, `pos.cancel_bill`, `pos.apply_discount`, `pos.edit_price`, `pos.view_history`.
     - `ban` $\rightarrow$ Tự động cấp: `ban.manage_structure`, `pos.checkout`.
     - `kho` / `kho_pro` $\rightarrow$ Tự động cấp: `kho.edit_quantity`, `kho.delete_item`.
     - `finance` $\rightarrow$ Tự động cấp: `finance.view_all`.
     - `report` $\rightarrow$ Tự động cấp: `report.view`.
     - `tinhluong` $\rightarrow$ Tự động cấp: `tinhluong.view_all`, `tinhluong.manage_config`, `tinhluong.approve_payroll`, `tinhluong.srm_settings`, `tinhluong.srm_review`.
     - `bill_printer` $\rightarrow$ Tự động cấp: `printer.manage_server`.
  3. **Vai trò chuẩn & Fail-safe mặc nhiên**:
     - Vai trò `owner` (hoặc `is_owner = true`): Có toàn quyền tất cả action permissions trong POS và toàn bộ 9 quyền AI Bum.
     - Vai trò `manager`: Có toàn quyền tất cả action permissions của POS (`kAllActions`: bán hàng, bàn, kho, thu chi, báo cáo, tính lương, máy in) để điều hành ca làm việc tại quán; nhưng **tuyệt đối KHÔNG tự động được cấp các quyền dữ liệu nhạy cảm qua AI Bum** (`ai_bum.sales`, `ai_bum.inventory`, `ai_bum.finance`, `ai_bum.operations`, `ai_bum.team_shift`, `ai_bum.all_payroll`). Mặc định qua AI Bum, Manager chỉ có 3 quyền an toàn cá nhân (`ai_bum.help`, `ai_bum.my_shift`, `ai_bum.my_payroll`), các quyền nhạy cảm khác phải suy trực tiếp từ Lego Modules (`store_roles.modules`) hoặc được Chủ Quán cấp chủ động; nếu chưa được cấp phải **fail-closed**.
     - Vai trò `cashier` hoặc tên vai trò có chứa `"thu ngân"`, `"quầy"`: Mặc nhiên có quyền thanh toán `pos.checkout`, xem lịch sử `pos.view_history`, giảm giá `pos.apply_discount`.
  4. **Quy chuẩn Server RPC xác thực quyền (`verify_staff_qr_membership_v4`, `settle_ban_session_v5`)**:
     - Xác thực nhận diện user qua 4 tầng: `auth.uid()`, `request.jwt.claim.sub`, `request.headers -> x-user-id`, `request.header.x-user-id`.
     - Kiểm tra quyền ưu tiên: `is_owner OR role IN ('owner', 'manager', 'cashier', 'admin') OR store_roles.modules ? 'pos'/'ban' OR app_settings fallback`.
     - `GRANT EXECUTE` bắt buộc cho cả 3 vai trò: `anon, authenticated, service_role`.
  5. **Quy chuẩn RLS & SELECT cho Thống kê / Báo cáo / Dashboard**:
     - Các bảng giao dịch: `payment_settlements`, `ban_session_orders`, `ban_session_order_items`, `finance_records`, `orders`, `order_items` bắt buộc phải được `GRANT SELECT` cho `anon, authenticated, service_role` và tạo chính sách RLS `CREATE POLICY ... FOR ALL TO public USING (true)` để các stream báo cáo, biểu đồ doanh thu theo giờ và doanh thu thu ngân không bị nghẽn (42501 Unauthorized) làm xoay vô tận màn hình.
- `app_logs` dùng cho lỗi/hoạt động; `void_audit_logs` cho hủy món/bill; `coupons` cho khuyến mãi. Khi có sự cố, ưu tiên log/stack trace và dữ kiện thiết bị, không đoán mò.
- Thu chi phải phân biệt tiền mặt/tiền gửi, hoàn đúng nguồn khi rollback và xuất báo cáo có tồn đầu kỳ/running balance khi nghiệp vụ yêu cầu.
- Dọn dữ liệu chỉ khi được phép và phải xét FK theo luồng `kitchen_tickets → ban_sessions → orders → finance_records → stock_movements`; không dùng chuỗi này như lệnh xóa tự động.

### In ấn, thiết bị và phát hành

- Tách template/cấu hình Hóa đơn Thu ngân, Bếp nóng và Bếp bar; định tuyến theo bộ phận chế biến. Tem ly của Bar in theo từng số lượng món.
- PDF nhiệt dùng đen thuần cho chữ/đường kẻ; tránh màu xám/opacity làm mờ. Logo bitmap/Base64 và QR động/tĩnh phải tương thích máy in thực tế.
- Cấu hình máy in tách theo `device_id`, tự lưu có debounce/focus hợp lý, không ghi đè thiết bị khác. Realtime phải tránh nhận/in trùng.
- Windows installer/auto-update, Web `/pos/`, Android/iOS là luồng phát hành riêng. Không build, deploy, upload store, push Git hoặc thay hạ tầng nếu người dùng chưa yêu cầu; trạng thái phát hành phải đọc từ tài liệu/console hiện hành.

### QR Order và AI Bum

- Mỗi cửa hàng dùng một QR TABLE_SHARED chung và một QR COUNTER mang đi; không in QR riêng từng bàn. Sau khi khách submit, web sinh QR bàn giao động; nhân viên dùng account/membership hiện hành quét, atomic claim, chọn bàn cho TABLE, đọc lại/chỉnh món rồi gửi Bếp.
- QR TABLE/COUNTER phải dùng giá authoritative từ server, atomic claim chống hai nhân viên duyệt trùng và commit boundary rõ ràng. Một request hội tụ vào đúng một order; không rollback sau khi vé Bếp đã commit nếu việc đó có thể in trùng; retry chỉ reconcile trạng thái idempotent.
- QR COUNTER phải thanh toán trước Bếp bởi Thu ngân hoặc actor có `pos.checkout`. QR TABLE gửi Bếp trước và thanh toán toàn bộ `ban_session` sau. Không có QR Payment tự động trong phạm vi hiện tại; không được tự giả định đã thu tiền chỉ vì đã hiển thị VietQR.
- Nhân viên đã kết nối quán bằng tài khoản + mã quán; QR không tạo POS device pairing/PIN riêng. `device_id` nếu dùng chỉ là metadata audit/idempotency, không phải credential người dùng.
- **Nền tảng công nghệ AI Bum (Qwen2.5 + Unsloth Framework):** AI Bum hiện sử dụng Qwen2.5 làm base model, được nạp và tối ưu huấn luyện/suy luận bằng framework Unsloth (`FastLanguageModel`). Quán Nhỏ sở hữu dữ liệu tự tạo và LoRA adapter do dự án huấn luyện, trong phạm vi giấy phép của base model và các dependency liên quan. Các tuyên bố hiệu năng như giảm 70% VRAM hay tăng tốc 2–5x là số liệu tham khảo của framework Unsloth, không phải kết quả đã nghiệm thu của dự án trên cấu hình BunServer. `MAX_SEQ_LENGTH = 512` là cấu hình hiện hành đã được sử dụng/quan sát với ngưỡng VRAM guard; 1024 chưa được nghiệm thu trên BunServer. Không nâng lên 1024 trong đợt này.
- **Kiến trúc hai tầng của AI Bum (Dual-Layer Architecture):**
  - **Tầng 1 (RAG Cấp tốc):** Tra cứu tức thì qua SQLite FTS5 index 26 Chuyên đề nghiệp vụ F&B và 17 Cây ma trận quyết định phản xạ thực chiến (< 2ms) phục vụ hỏi đáp thời gian thực cho nhân viên quán mà không tiêu hao tài nguyên mô hình lớn.
  - **Tầng 2 (SFT Huấn luyện chuyên sâu):** Sử dụng framework Unsloth (`FastLanguageModel`) nạp base model Qwen2.5 + LoRA adapter từ kho dữ liệu bài học đã được kiểm duyệt/phê duyệt, tuyệt đối tuân thủ Zero Verbatim Ingestion, Zero PII, Zero Business Secrets.
- AI Bum phải read-only với nghiệp vụ, chỉ đóng vai trò trợ lý/tư vấn/nhắc nhở, không tự tạo hiệu lực kho hoặc tài chính, khử PII trước cloud fallback, có quota/circuit breaker và cô lập conversation/feedback/memory theo `store_id`.

## 3. Phân vai hai graph

| Nhu cầu | Công cụ chính | Kết quả cần lấy |
|---|---|---|
| Hiểu hệ thống, module, tài liệu và luồng xuyên miền | Graphify | Community, god node, quan hệ code–docs–schema, câu hỏi kiến trúc |
| Chẩn đoán lỗi, tìm symbol và nguyên nhân | CodeGraph | Source hiện tại, call path, callers, dynamic dispatch, blast radius |
| Xác định file/test bị ảnh hưởng trước và sau khi sửa | CodeGraph | `impact`, `affected`, source và đường gọi |
| Cập nhật bản đồ tổng quan sau thay đổi | Graphify | Graph/report/HTML mới |

Nguyên tắc:

- **Graphify là bản đồ**, dùng để định hướng và nhìn hệ thống ở mức tổng quan.
- **CodeGraph là kính hiển vi**, dùng để đi sâu vào code và truy nguyên lỗi.
- Không dùng cạnh `INFERRED` hoặc `AMBIGUOUS` của Graphify làm bằng chứng kết luận lỗi.
- Khi kết quả hai graph khác nhau, ưu tiên source hiện tại do CodeGraph trả về, sau đó kiểm tra schema/migration và test.

## 4. Chế độ phân tích sâu

Khi dùng Antigravity, ưu tiên chọn reasoning model ở mức **High** hoặc model có nhãn **Thinking** trước khi gọi `/qn`. Workflow này bắt buộc quy trình phân tích sâu, nhưng không thể tự thay đổi model/effort trong model selector.

Luôn bật chế độ phân tích sâu khi công việc liên quan P0, schema/data, phân quyền, nhiều module, retry/concurrency, offline/realtime hoặc chưa rõ nguyên nhân. Trước khi sửa phải tạo một bản phân tích ngắn, có thể kiểm chứng, gồm:

1. Triệu chứng, dữ kiện đã biết và phần chưa biết.
2. Từ 2–4 giả thuyết nguyên nhân, xếp theo khả năng và mức ảnh hưởng.
3. Luồng Graphify ở mức module/domain và luồng CodeGraph ở mức symbol/call path.
4. Đường đi dữ liệu: UI → provider/service/repository → RPC/schema → realtime/cache.
5. Các bất biến phải giữ: `store_id`, auth server-side, RLS, audit, idempotency và không tạo bản ghi trùng.
6. Blast radius: caller/callee, module, migration, test và nền tảng bị ảnh hưởng.
7. Kế hoạch sửa tối thiểu cùng test có thể bác bỏ từng giả thuyết chính.

Không chấp nhận nguyên nhân hợp lý đầu tiên nếu chưa tìm bằng chứng phản chứng. Nếu chưa đủ dữ kiện, ghi rõ `chưa kết luận` và tiếp tục kiểm tra; không đoán rồi sửa. Chỉ báo cáo bằng chứng và quyết định cần thiết.

## 5. Luồng bắt buộc khi tìm hiểu hoặc fix lỗi

### Bước A — Chốt triệu chứng và phạm vi

Ghi rõ:

- Hành vi hiện tại và hành vi mong đợi.
- Module, màn hình, vai trò người dùng và `store_id` liên quan.
- Lỗi xảy ra online/offline, trên nền tảng nào và có tái hiện được không.
- Người dùng đang yêu cầu **chẩn đoán** hay đã cho phép **sửa code**.

Nếu chỉ yêu cầu chẩn đoán, không sửa code/database.

### Bước B — Dùng Graphify để định hướng kiến trúc

Nếu `graphify-out/graph.json` tồn tại, chạy tối đa một truy vấn tổng quan ban đầu:

```bash
graphify query "<luồng nghiệp vụ hoặc các module liên quan đến lỗi>"
```

Chỉ dùng thêm khi thực sự cần:

```bash
graphify path "<khái niệm A>" "<khái niệm B>"
graphify explain "<module hoặc khái niệm>"
```

Mục tiêu của bước này là xác định module, tài liệu, schema và ranh giới hệ thống cần điều tra. Không đọc toàn bộ `graph.json`. Nếu graph chưa có hoặc đang lỗi, ghi nhận rồi tiếp tục bằng CodeGraph; không để Graphify chặn việc sửa lỗi.

### Bước C — Dùng CodeGraph để truy nguyên nguyên nhân

Từ root `quan_nho`, kiểm tra index và ưu tiên một truy vấn đủ cụ thể:

```bash
codegraph status .
codegraph explore "<triệu chứng + màn hình/repository/symbol nghi ngờ + luồng cần lần theo>"
```

Khi cần đào sâu thêm:

```bash
codegraph node "<symbol hoặc file>"
codegraph callers "<symbol>"
codegraph callees "<symbol>"
codegraph impact "<symbol>"
```

CodeGraph phải cung cấp source hiện tại, call path và blast radius. Không grep/read lại những source đã được CodeGraph trả về đầy đủ; chỉ mở thêm phần chưa có trong kết quả.

### Bước D — Đối chiếu nguồn sự thật

Trước khi kết luận nguyên nhân:

1. Đối chiếu source hiện tại và đường gọi.
2. Kiểm tra migration/RPC/RLS liên quan trong `supabase/migrations/`.
3. Mở đúng phần tài liệu nghiệp vụ; không nạp toàn bộ tài liệu dài.
4. Kiểm tra test hiện có và khoảng trống kiểm thử.
5. Phân biệt rõ `đã có`, `có một phần`, `chưa có`, `nợ kỹ thuật`.

Tài liệu định tuyến:

- `.docs/tong-quan.md`: phạm vi và tổng quan sản phẩm.
- `.docs/trien-khai-sap-toi.md`: quyết định nghiệp vụ, hiện trạng và P0/P1/P2.
- `.docs/kien-truc-data.md`: schema và luồng dữ liệu.
- `.docs/kien-truc.md`: kiến trúc kỹ thuật.
- `.docs/tinh-nang.md`: chức năng hiện hành.
- `.docs/lam-viec.md`: quy chuẩn code và giao diện.
- `.docs/deploy_ios_android.md`, `.docs/store_listing.md`: phát hành; phải xác minh vì dễ lỗi thời.
- `maqr.md`: QR Order; đối chiếu migration/source trước khi tin trạng thái triển khai.
- `nhat_ky.md`: chỉ đọc mục `Tiếp theo` gần nhất khi công việc liên quan tiến độ hiện tại.

Không coi roadmap hoặc tài liệu cũ là tính năng đang chạy. Nếu tài liệu mâu thuẫn code, nêu rõ mâu thuẫn.

### Bước E — Sửa tối thiểu, đúng nguyên nhân

Chỉ sửa khi người dùng đã yêu cầu triển khai/fix. Bản sửa phải:

- Giải quyết nguyên nhân gốc, không chỉ che triệu chứng.
- Giữ cô lập `store_id`, phân quyền server, audit và idempotency.
- Không làm trùng order, payment, kitchen ticket, stock movement hoặc finance record.
- Không âm thầm mở rộng phạm vi sang module khác.
- Có kiểm thử tương xứng với rủi ro retry, concurrency, crash và mất mạng.

### Bước F — Xác minh và cập nhật hai graph

Sau khi sửa:

```bash
codegraph affected <file đã sửa>
codegraph sync .
codegraph status .
```

Chạy test/lint phù hợp, sau đó cập nhật bản đồ Graphify:

```bash
graphify update .
```

- CodeGraph tự đồng bộ source; `status` phải báo index mới.
- `graphify update .` cập nhật cấu trúc code không cần LLM.
- Nếu thay đổi tài liệu/kiến trúc quan trọng, chạy `$graphify . --update` để cập nhật cả semantic graph và report trực quan.

### Bước G — Thay đổi schema/data hoặc thêm module mới

Nếu có migration, RPC, table/column/index/policy mới, thay đổi quan hệ dữ liệu hoặc thêm module/provider/service/repository mới thì bắt buộc:

1. Cập nhật source, migration và tài liệu kiến trúc tương ứng; tối thiểu kiểm tra `.docs/kien-truc-data.md`, `.docs/kien-truc.md` và `.docs/tinh-nang.md`.
2. Đồng bộ và xác nhận CodeGraph nhìn thấy code mới:

```bash
codegraph sync .
codegraph status .
codegraph explore "<module mới + entry point + repository/service + luồng gọi>"
```

3. Nếu file code mới không xuất hiện sau `sync`, chạy `codegraph index .` để rebuild toàn bộ rồi kiểm tra lại. CodeGraph tập trung vào symbol và call path của source; với SQL/schema, phải xác nhận migration trực tiếp và dùng Graphify để bao phủ quan hệ code–docs–schema.
4. Cập nhật Graphify và kiểm tra module/schema mới đã xuất hiện:

```bash
graphify update .
graphify query "<module hoặc thay đổi data mới liên kết với luồng nghiệp vụ nào>"
```

5. Với thay đổi schema, tài liệu hoặc ranh giới kiến trúc, chạy thêm `$graphify . --update` để làm mới semantic graph và report. `graphify-out/` tiếp tục chỉ dùng local, không đưa lên web hoặc Git nếu người dùng không yêu cầu.
6. Không báo hoàn tất nếu một trong hai graph còn stale, module mới không truy vấn được, migration/RLS chưa được kiểm tra hoặc tài liệu kiến trúc chưa khớp source.

## 6. Cách báo cáo kết quả

Báo ngắn gọn theo thứ tự:

1. **Triệu chứng và nguyên nhân gốc.**
2. **Luồng ảnh hưởng:** module → symbol → dữ liệu/test.
3. **File/symbol đã sửa.**
4. **Kiểm thử và kết quả xác minh.**
5. **Trạng thái CodeGraph và Graphify**, đặc biệt khi có schema/data/module mới.
6. **Rủi ro hoặc việc còn lại.**

Không trình bày suy luận của Graphify như sự thật nếu chưa được CodeGraph/source/test xác nhận.
