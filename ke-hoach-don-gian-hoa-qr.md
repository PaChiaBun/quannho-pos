# Kế hoạch đơn giản hóa module QR Gọi Món

> Lập 2026-10-13 sau khi rà soát toàn bộ `lib/modules/qr_order/`, phần tích hợp ở `pos_screen`/`ban_screen`/`main.dart` và SQL QR V4.
> Trạng thái: **kế hoạch, chưa sửa code, chưa apply migration.**
> Các mục ghi "chưa chắc" do rà soát đọc code, chưa chạy trên DB thật.

## 1. Mục tiêu và quyết định đã chốt

- Đơn giản, dễ dùng cho quán nhỏ.
- **Khách tự chọn số bàn** khi đặt (TABLE). Nhân viên chỉ xem lại và sửa nếu sai.
- **Bỏ QR động và camera quét.** Đơn mới hiện trong hàng chờ chung kèm chuông.
- TABLE: một nút "Duyệt & gửi bếp"; trả tiền cả bàn khi checkout như hiện nay.
- COUNTER (mang đi): một nút "Đã thu tiền & gửi bếp", chỉ người có `pos.checkout`; người khác chỉ "Chuyển thu ngân".
- Giữ nguyên: giá do server tính, chống nhận trùng, chống trùng vé bếp, VietQR không tự chứng minh đã trả tiền.

## 2. Lỗi và phi logic tìm thấy

### P0 — phải xử lý trước khi cho khách dùng

| # | Vấn đề | Vị trí |
|---|---|---|
| 1 | **Server chưa có hàm QR.** App gọi 13 RPC `*_v4`, nhưng SQL chỉ nằm trong `.docs/evidence/qr-v4-phase0-20260826/proposed_qr_order_v4.sql` (ghi "không deploy"). Khảo sát 27/08: production chưa có bảng/hàm QR. | `supabase/migrations/` |
| 2 | **SQL V4 sai schema thật:** `assigned_table_id uuid` trỏ FK tới `ban_dining_tables.id` (kiểu text) làm cả migration lỗi; `UPDATE ban_dining_tables SET status` trong khi bảng không có cột `status`. | proposed V4 :45, :92, :1563, ~:2980 |
| 3 | **`mark_qr_order_paid_v4` không kiểm trạng thái/người nhận:** thanh toán được đơn chưa nhận, đã hủy hoặc hết hạn, rồi tạo order, ghi finance, trừ kho. | V4 :1660 |
| 4 | **Phân quyền thu tiền chỉ ở UI/RPC chưa kiểm:** nút thu tiền không kiểm `pos.checkout` trong app; phía server chưa xác minh. | `qr_order_review_sheet.dart:242-336` |
| 5 | **Khóa chống trùng (idempotency key) tạo mới mỗi lần mở sheet:** thu tiền/gửi bếp đã commit mà mất phản hồi, mở lại sheet là key mới, có thể thu hoặc gửi bếp hai lần. | `review_sheet:57-58, 242-285` |
| 6 | **Khách reload trang là mất đơn** (tracking token không lưu), quay lại menu trống, gửi lại tạo đơn thứ hai, COUNTER có thể trả tiền hai lần. | `customer_qr_order_screen.dart:840, 1485` |
| 7 | **Mất mạng khi gửi đơn:** khóa chống trùng bị reset khi khách sửa giỏ, có thể thành đơn trùng. Lỗi mạng sau commit không đồng bộ lại trạng thái. | `customer:445, 634, 659, 769`; `review_sheet:182-187, 336-376` |
| 8 | **`settle_ban_session_v5` được app gọi nhưng V4 chỉ định nghĩa `_v4`.** V4 còn có `settle_ban_session_v4` trùng chức năng, nguy cơ trừ kho hai lần. | `repository:~503`; V4 :2253 |
| 9 | (chưa chắc) `search_path` của hàm V4 không có schema `extensions`, có thể không gọi được `digest()` / `gen_random_bytes()`. | V4 toàn bộ hàm |
| 10 | (chưa chắc) V4 dùng `ban_dining_tables.label`, nhưng preflight V3 liệt kê cột `name`. | V4 :1039, :1221… |

### P1 — nên sửa trong đợt này

- `send_qr_order_to_kitchen_v4` không kiểm trạng thái/người nhận; tìm-hoặc-tạo `ban_sessions` không khóa nên hai đơn cùng lúc cho bàn trống có thể tạo hai phiên mở (V4 :1973, :2106).
- `update_qr_order_items_v4` sửa được đơn người khác/đã trả tiền và không giữ snapshot món khách gửi (V4 :1329). `cancel_qr_order_v4` hủy đơn đã vào bếp mà không đảo order/kho/tiền (V4 :3037).
- Mã mang đi `pickup_code` chỉ có 99 giá trị quay vòng, không reset theo ngày, không unique (V4 :932).
- `submit_qr_order_v4` cho khách ẩn danh không giới hạn tần suất/kích thước; cast uuid ngoài khối bắt lỗi (V4 :827).
- V4 ghi đè `verify_staff_qr_membership_v4` và tạo lại các bảng đã có trong `20260901_settlement_v5_prerequisites.sql` (trùng, cấu hình mâu thuẫn). Rollback V4 xóa cả bảng thanh toán dùng chung.
- Bàn có đơn QR đang chờ **chặn không cho mở bàn thật**: bấm vào bàn luôn ra sheet duyệt (`ban_screen.dart:2000-2042`).
- Hai nguồn trạng thái bật/tắt kênh (`app_settings` và `qr_channels.is_active`) lệch nhau; `saveSettings` nuốt lỗi, báo "đã lưu" giả; lưu tên miền khi settings chưa tải sẽ ghi đè mất cấu hình poster/ngân hàng (`qr_settings_tab.dart`, `repository:74-87`).
- Hai tab poster **ghi cứng tên miền** và in QR dù chưa có kênh hoặc kênh đã tắt (mã giả `TBL_DEFAULT`/`CTR_CHUA_MIGRATE`) (`table_shared_poster_tab.dart:137-183`, `counter_qr_design_tab.dart`).
- Màn hình khách: polling không bắt lỗi và có thể chồng request; "Gọi thêm món" không hủy timer; hết hạn tính bằng đếm ngược cục bộ 30 phút thay vì giờ server; "tạo lại QR" không chống bấm đúp; hiện token thô; lỗi mạng lộ chi tiết nội bộ cho khách; topping hiện sai tập (`customer:165-189, 1196, 1253-1353, 275, 427`).
- COUNTER: màn khách không xử lý `awaiting_payment`, `ready_for_kitchen` bị hiện là "Đã gửi bếp" dù chưa thu tiền.
- Validate tên miền bỏ sót dải `172.16-31.*`, `169.254.*`, `[::1]`, userinfo, và chặn nhầm host `10.example.com` (`qr_order_model.dart:703-720`).
- Pipeline poll 5-6 giây lấy đầy đủ dữ liệu, kể cả lúc nền; lỗi fetch vẫn hiện danh sách cũ như bình thường ở màn Bàn.

### P2 — dọn dẹp

- Cast không an toàn null khi parse món/giá; `itemKey` có thể va chạm; `computeCanonicalPayloadHash` sắp xếp không ổn định; `expired` không có tiêu đề riêng.
- PDF: quiet zone tem bàn thấp hơn 4 module; font Noto tải qua mạng (offline lỗi); emoji trong poster hiện ô vuông; mật khẩu WiFi in nguyên văn.
- `reasonCtrl` không dispose; `setState`/controller sau dispose ở vài màn; `_resetCounterSettings` không hỏi xác nhận.
- Enum trạng thái/loại kênh có hai bộ giá trị song song (hoa/thường), nhiều nhánh chết.

## 3. Code chết và phần thừa (xóa được sau khi bỏ QR động)

Đã grep xác nhận không còn nơi dùng, trừ khi ghi chú:

- `screens/tabs/table_qr_list_tab.dart` (435 dòng), `screens/tabs/batch_table_print_tab.dart` (694 dòng).
- `widgets/qr_scanner_dialog.dart` (449 dòng) cùng nút quét ở `ban_screen.dart:746-770`, import `ban_screen.dart:47`, và dependency `mobile_scanner` nếu không còn ai dùng.
- Repository: `claimHandoffToken`, `regenerateHandoffToken`; `ensureTableSharedChannel`/`ensureCounterChannel` (kiểm tra test trước khi xóa).
- `ban_screen.dart:3848-4090` khối `_checkoutLegacyUnused` (đang nằm trong comment); nhánh `NO_POS_TOKEN` ở `pos_screen.dart:406`; dấu vết pairing ở `core/services/pos_device_token_service.dart` (cần kiểm caller).
- `qr_pdf_service.dart`: `generateA4DecalSheetPdf`, `batchItems`, `renderAsA4Sheet`, `TableQrItemData` nếu chỉ còn in một mã.
- SQL: bảng `qr_handoff_tokens`, `regenerate_handoff_token_v4`, `claim_qr_handoff_v4`, `assign_qr_order_table_v4`, `table_hint`.
- Tính năng thừa trong poster quầy (đề xuất bỏ, cần bạn xác nhận): 4 theme, WiFi/hotline/giờ mở cửa/footer, khổ tùy chỉnh, bleed/crop marks. Cấu hình VietQR có thể giữ nếu quán thu chuyển khoản tại quầy.
- Migration V3 cũ (`20260731_*`, `20260814*_qr_v3_*`, `rollback_qr_architecture_v3.sql`) và `maqr.md`: chuyển vào thư mục lưu trữ.

## 4. Thiết kế đích

**Khách:** quét QR → (TABLE) chọn bàn từ danh sách bàn của quán → chọn món → Gửi. Sau đó thấy "Đã gửi, chờ quán xác nhận" → "Đã vào bếp" / "Quán từ chối". Mã đơn lưu `localStorage`, reload không mất.

**Nhân viên:** đơn mới vào hàng chờ chung kèm chuông; mở đơn → xem/sửa món → một nút duy nhất:
- TABLE: "Duyệt & gửi bếp" (gắn vào phiên bàn của bàn khách chọn).
- COUNTER: "Đã thu tiền & gửi bếp" (cần `pos.checkout`), hoặc "Chuyển thu ngân".

**Trạng thái (server):** `submitted → claimed → sent_kitchen`, nhánh `rejected`/`expired`; COUNTER thêm `paid` nằm trong cùng một bước RPC. Bỏ `confirmed`, `awaiting_payment`, `staff_review`, `pending_staff` khỏi code.

**Màn "Mã QR":** hai thẻ (Tại bàn / Mang đi). Mỗi thẻ có công tắc gắn trực tiếp với `qr_channels.is_active`, nút In/Tải PDF chỉ bật khi kênh bật và link hợp lệ. Link dựng bằng **một hàm** `QrUrlBuilder` (mặc định `https://quannho.lpm.vn/pos`), không ghi cứng, không mã giả. Ô tên miền tùy chỉnh dời vào mục nâng cao.

**RPC mới/đổi:**
- `submit_qr_order_v4(..., p_table_id text)`: bắt buộc cho TABLE, kiểm bàn thuộc đúng `store_id`; giới hạn tần suất và kích thước.
- `claim_qr_request_v4(p_request_id)`: nhận đơn từ hàng chờ, atomic.
- `approve_and_send_table_v4(p_request_id, p_version)` và `pay_and_send_counter_v4(p_request_id, p_version, p_payment_method)`: gom nhận → sửa giá → (thu tiền) → gửi bếp trong một giao dịch; kiểm `pos.checkout` ở server; khóa chống trùng suy ra từ `request_id`.
- Giữ `cancel`, `update_items` nhưng chỉ cho người đang giữ đơn và trước khi gửi bếp.

## 5. Các bước thực hiện

**Bước 0 — Kiểm chứng (không sửa gì).** Chạy truy vấn chỉ-đọc trên Supabase thật: có bảng/hàm QR chưa; `ban_dining_tables` có `name` hay `label`, `id` kiểu gì; `pgcrypto` ở schema nào; `store_members` có cột trạng thái không; các hàm settle V5 đã apply chưa. Kết quả quyết định phần còn lại.

**Bước 1 — SQL (staging trước).** Viết lại V4 gọn theo mục 4: bỏ handoff token và `settle_v4`, sửa kiểu bàn/cột/`search_path`, không tạo lại bảng đã có ở prerequisites V5, `pickup_code` theo ngày có unique, khóa bàn khi tạo phiên, kiểm trạng thái và quyền ở mọi RPC. Rollback chỉ gỡ đối tượng QR. Test SQL phải `SET ROLE anon/authenticated`, kiểm chéo quán, đua nhận đơn, thu tiền/gửi bếp lặp. Đưa vào `supabase/migrations/` chỉ sau khi chạy xanh trên staging.

**Bước 2 — Web khách.** Chọn bàn; lưu và khôi phục đơn khi reload; khóa chống trùng bám theo giỏ đã gửi; polling có kiểm lỗi/chống chồng; hết hạn theo giờ server; bỏ khối QR động và token thô; thông báo lỗi thân thiện; xử lý `rejected`/`expired`/chờ thu tiền.

**Bước 3 — App nhân viên.** Hàng chờ chung + chuông; sheet duyệt rút gọn một nút; ẩn nút thu tiền nếu thiếu `pos.checkout`; khóa chống trùng ổn định theo `request.id`; refetch khi lỗi mạng; không chặn mở bàn thật; xóa scanner và code pairing/legacy.

**Bước 4 — Màn "Mã QR".** Gộp thành hai thẻ như mục 4; xóa hai tab in hàng loạt/danh sách bàn; sửa hai nguồn bật/tắt; `saveSettings` trả kết quả thật; hàm validate tên miền đúng dải riêng tư.

**Bước 5 — Dọn và tài liệu.** Lưu trữ V3, viết lại `maqr.md`, cập nhật `qn.md` mục QR Order và `.docs/qr-order-kien-truc-muc-tieu.md` (bỏ QR động, khách chọn bàn), `.docs/kien-truc-data.md`, `.docs/tinh-nang.md`, `nhat_ky.md`. Chạy `flutter analyze`/test, `codegraph sync .`, `graphify update .`.

**Bước 6 — Thử nghiệm.** Staging với hai điện thoại nhân viên và một khách; sau đó pilot tại KAY. Chỉ apply production sau checklist backup/rollback và bạn xác nhận thủ công.

## 6. Điều kiện nghiệm thu

- Khách chọn bàn, gửi một lần, reload trang vẫn thấy đơn, bấm đúp hoặc mất mạng không sinh đơn thứ hai.
- Hai nhân viên cùng mở một đơn: chỉ một người duyệt được.
- Thu ngân không có `pos.checkout` không thu tiền được (kiểm cả ở server).
- COUNTER không vào bếp khi chưa thu tiền; TABLE trừ kho chỉ khi checkout cả bàn.
- Mã QR in ra luôn khớp kênh đang bật; kênh tắt thì không in được.
- Không còn code scanner, handoff token, pairing; `flutter analyze` sạch cho `lib/modules/qr_order/`.

## 7. Việc cần bạn quyết

1. Có bỏ các tùy biến poster quầy (theme, WiFi, hotline, khổ tùy chỉnh) không?
2. Có giữ VietQR trong module QR không?
3. Khách chọn nhầm bàn: nhân viên đổi bàn ở sheet duyệt là đủ, hay cần thêm bước nào?
4. Cho phép tôi chạy truy vấn chỉ-đọc ở Bước 0 trên Supabase thật (hay bạn tự chạy và gửi kết quả)?
