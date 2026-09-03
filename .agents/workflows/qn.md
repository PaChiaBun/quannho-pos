---
description: Điều phối Graphify để hiểu kiến trúc và CodeGraph để truy nguyên, sửa lỗi Quán Nhỏ POS
---

# Workflow `/qn` — Quán Nhỏ POS

Đây là workflow `qn.md` chuẩn của dự án. Khi gọi `/qn` hoặc đính kèm file này, làm việc theo luồng dưới đây. Không gọi hai graph lặp lại cho cùng mục đích.

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
- **Lego Modules (`store_roles.modules`) là nguồn sự thật duy nhất cho phân quyền vai trò**: Mọi quyền hành động (bao gồm thanh toán hoá đơn `pos.checkout`) được tự động suy ra trực tiếp từ danh sách Modules của vai trò (`pos`, `ban`, `kitchen`, `kho`, v.v.) hoặc vai trò chuẩn (`owner`, `manager`, `cashier`); tuyệt đối không bắt buộc phải tạo hay phụ thuộc vào bản ghi phụ trong `app_settings` để tránh lỗi khóa quyền nhân viên/thu ngân mới.
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
- AI Bum phải read-only với nghiệp vụ, khử PII trước cloud fallback, có quota/circuit breaker và cô lập conversation/feedback/memory theo `store_id`.

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
