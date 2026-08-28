# TÀI LIỆU LEGACY — MODULE QR GỌI MÓN V3
**Dự án:** Quán Nhỏ POS (`quan_nho`)  
**Ngày đánh dấu legacy:** 26/08/2026
**Trạng thái:** Mô tả source/migration V3 hiện có để phục vụ chuyển đổi; **không còn là kiến trúc mục tiêu** và migration QR V3 chưa apply Supabase.
**Nguồn mục tiêu mới:** `.docs/qr-order-kien-truc-muc-tieu.md`.
**Kế hoạch triển khai:** `.docs/ke-hoach-trien-khai-qr-order.md`.

> Cảnh báo: các phần bên dưới còn mô tả QR riêng từng bàn, POS device pairing và luồng gửi Bếp V3. Không dùng các mô tả đó để triển khai mới. Kiến trúc đã chốt dùng một QR TABLE_SHARED cho cả quán, một QR COUNTER mang đi, QR bàn giao động theo request, nhân viên chọn bàn sau khi claim, và tái sử dụng account/membership hiện hành.

---

## MỤC LỤC
1. [Mục Tiêu & Phạm Vi Module](#1-mục-tiêu--phạm-vi-module)
2. [Luồng Nghiệp Vụ Chế Độ TABLE (Gọi Tại Bàn)](#2-luồng-nghiệp-vụ-chế-độ-table-gọi-tại-bàn)
3. [Luồng Nghiệp Vụ Chế Độ COUNTER (Gọi Tại Quầy & Pickup Code)](#3-luồng-nghiệp-vụ-chế-độ-counter-gọi-tại-quầy--pickup-code)
4. [Trạng Thái (State Machine), Atomic Claim & Kitchen Commit Boundary](#4-trạng-thái-state-machine-atomic-claim--kitchen-commit-boundary)
5. [Kiến Trúc Database, RLS, RPC Security & Giá Authoritative](#5-kiến-trúc-database-rls-rpc-security--giá-authoritative)
6. [Cấu Trúc File Dart & Các Điểm Tích Hợp Hệ Thống](#6-cấu-trúc-file-dart--các-điểm-tích-hợp-hệ-thống)
7. [Hằng Số Hệ Thống Mang Đi (Takeaway Constants)](#7-hằng-số-hệ-thống-mang-đi-takeaway-constants)
8. [Quản Lý & In Ấn Mã QR, Cấu Trúc URL](#8-quản-lý--in-ấn-mã-qr-cấu-trúc-url)
9. [Hướng Dẫn Áp Dụng Migration SQL & Deploy (Chờ Thực Hiện)](#9-hướng-dẫn-áp-dụng-migration-sql--deploy-chờ-thực-hiện)
10. [Checklist Test Staging / E2E & Kịch Bản Bảo Mật](#10-checklist-test-staging--e2e--kịch-bản-bảo-mật)
11. [Hạn Chế Hiện Tại & Cảnh Báo Linter](#11-hạn-chế-hiện-tại--cảnh-báo-linter)
12. [Các Nguyên Tắc Bắt Buộc Khi Phát Triển Tiếp](#12-các-nguyên-tắc-bắt-buộc-khi-phát-triển-tiếp)

---

## 1. MỤC TIÊU & PHẠM VI MODULE

### 1.1. Mục tiêu
Module **QR Gọi Món** cho phép khách hàng tự chọn món ăn/đồ uống qua giao diện web di động bằng cách quét mã QR đặt tại bàn hoặc quầy thu ngân. Đơn hàng từ khách được gửi về hệ thống dưới dạng yêu cầu chờ duyệt (`pending_staff`), giúp nhân viên nhà hàng kiểm tra, chỉnh sửa số lượng hoặc từ chối trước khi chính thức ghi nhận và chuyển xuống bếp chế biến.

### 1.2. Phạm vi MVP (Đã hoàn thiện trong mã nguồn)
- **2 Chế độ hoạt động:** 
  1. `TABLE` (Gọi tại bàn): Khách quét mã riêng của từng bàn.
  2. `COUNTER` (Gọi tại quầy): Khách quét mã tại quầy thu ngân, nhận mã lấy món (Pickup Code `#Q01`, `#Q02`...).
- **Quyền hạn khách hàng:** Khách chỉ được xem menu live, chọn topping, nhập ghi chú, gửi đơn chờ duyệt và theo dõi trạng thái đơn hàng.
- **Không có các tính năng ngoài phạm vi:**
  - ❌ **KHÔNG** tích hợp QR Payment / Thanh toán trực tuyến.
  - ❌ **KHÔNG** có nút "Gọi phục vụ".
  - ❌ **KHÔNG** có nút "Yêu cầu thanh toán".

---

## 2. LUỒNG NGHIỆP VỤ CHẾ ĐỘ TABLE (GỌI TẠI BÀN)

```
[Khách quét QR Bàn]
       │
       ▼
[Giao diện Web Khách]
  └─ Xem Menu live (RPC get_qr_menu)
  └─ Chọn món, topping, ghi chú
  └─ Bấm GỬI ĐƠN HÀNG (RPC submit_qr_order)
       │
       ▼ (Tạo record status = 'pending_staff')
[Hệ thống POS / BanScreen (Nhân viên)]
  └─ Âm thanh Chime + Rung Haptic phát tại thiết bị nhân viên
  └─ Bàn tương ứng hiển thị Viền Vàng Nhấp Nháy (Animated Pulse)
  └─ Bàn hiển thị Badge màu vàng: ⚡ QR (N món)
       │
       ▼ (Nhân viên bấm vào Bàn)
[Mở QrOrderReviewSheet trượt từ dưới lên]
  └─ Hiển thị danh sách món khách gọi
  └─ Nhân viên có thể tăng/giảm số lượng món hoặc xóa món
  └─ Bấm nút TỪ CHỐI -> Cập nhật status = 'rejected'
  └─ Bấm nút XÁC NHẬN & GỬI BẾP:
       ├─ Gọi RPC claim_qr_request(id) (Khóa đơn atomic)
       ├─ Mở/Tìm session của bàn (BanRepository.openSession)
       ├─ Chèn chính xác các món QR vào ban_session_items (kitchen_status = 'chua_gui')
       ├─ Tạo kitchen_tickets (status = 'cho', round = N) & kitchen_ticket_items
       ├─ Cập nhật ban_session_items -> kitchen_status = 'da_gui'
       └─ Cập nhật qr_requests.status = 'sent_kitchen'
```

---

## 3. LUỒNG NGHIỆP VỤ CHẾ ĐỘ COUNTER (GỌI TẠI QUẦY & PICKUP CODE)

1. **Khách quét mã QR Quầy:** Màn hình khách mở URL chứa `channel_code` dạng `CTR_` + 16 ký tự hex (Entropy 64-bit).
2. **Khách đặt món:** Khách chọn món, nhập ghi chú. Khi bấm gửi đơn, RPC `submit_qr_order` sinh mã **Pickup Code** dạng `#Q01`, `#Q02`... tính theo số lượng đơn counter trong ngày (`COUNT(*)+1`).
3. **Hiển thị trên POS Thu Ngân:** Trên thanh Header của `PosScreen` hiển thị badge cảnh báo: **`⚡ QR Quầy (N) #Q01`**.
4. **Nhân viên duyệt:** 
   - Nhân viên bấm vào badge trên POS để mở `QrOrderReviewSheet`.
   - Khi bấm **XÁC NHẬN & GỬI BẾP**, hệ thống tự động chèn món vào bàn hệ thống **Mang đi** (`kSysPosTakeawayTableId`), tạo `kitchen_tickets` với `table_label` ghi rõ `Mang đi (#Q01)`, `status = 'cho'`.
   - Cập nhật `qr_requests.status = 'sent_kitchen'`.

---

## 4. TRẠNG THÁI (STATE MACHINE), ATOMIC CLAIM & KITCHEN COMMIT BOUNDARY

### 4.1. Vòng đời Trạng thái Đơn QR (`qr_requests.status`)

| Trạng thái | Ý nghĩa | Hành động tiếp theo |
| :--- | :--- | :--- |
| `pending_staff` | Khách vừa gửi đơn, chờ nhân viên duyệt. | Hiển thị viền nhấp nháy trên Bàn / Badge POS. Nhân viên mở Review Sheet. |
| `processing` | Đang được một nhân viên mở và xác nhận (Atomic Claim). | Ngăn chặn nhân viên/thiết bị khác duyệt trùng đơn. |
| `sent_kitchen` | Nhân viên đã duyệt thành công, món đã ghi vào Bàn/POS và gửi bếp. | Hoàn tất luồng duyệt. Trang khách chuyển sang trạng thái "Đang chế biến". |
| `rejected` | Nhân viên bấm Từ Chối đơn hàng. | Kết thúc đơn. Khách nhận thông báo "Đơn bị từ chối". |
| `expired` | Giá trị dự phòng trong ràng buộc `CHECK`. | *Lưu ý: Hiện chưa có cron job / background worker tự động hết hạn.* |

### 4.2. Khóa Atomic Claim (`claim_qr_request`)
Để chống lỗi **Double-Confirm** (nhiều nhân viên cùng bấm xác nhận 1 đơn trên nhiều máy POS khác nhau):
- Trước khi chèn dữ liệu ghi bếp, client gọi RPC `claim_qr_request(p_request_id)`.
- SQL thực hiện lệnh `UPDATE qr_requests SET status = 'processing' WHERE id = p_request_id AND status = 'pending_staff' AND store_id IN (SELECT store_id FROM store_members WHERE user_id = auth.uid())`.
- Nếu số dòng ảnh hưởng = 0 (đơn đã bị máy khác nhận hoặc từ chối), hệ thống lập tức chặn lại và báo: *"Đơn hàng này đã được xử lý bởi nhân viên khác hoặc bạn không có quyền!"*.

### 4.3. Quy tắc Kitchen Commit Boundary & Rollback 2 Giai Đoạn

```
                [Bấm XÁC NHẬN & GỬI BẾP]
                           │
             ┌─────────────┴─────────────┐
             ▼                           ▼
    [Thất bại Phase 1]          [Thành công Phase 1]
 (Lỗi chèn Session/Ticket)      (Đã chèn Kitchen Ticket 
             │                  & cập nhật da_gui)
             ▼                           │
 ── ROLLBACK PHASE 1 ──                  │ (KITCHEN COMMIT BOUNDARY REACHED)
 1. Xóa kitchen_tickets đã tạo           ▼
 2. Xóa ban_session_items đã tạo  [Thực hiện Phase 2 Status Sync]
 3. Xóa ban_sessions nếu mới tạo   Cập nhật qr_requests -> 'sent_kitchen'
 4. Revert QR status -> 'pending_staff'  │
             │                           ├─ Lỗi Sync? Retry 3 lần, KHÔNG rollback
             ▼                           │  vì vé bếp đã in ra!
      [Báo lỗi cho NV]                   ▼
                                 [Hoàn tất & phát chuông]
```

- **Giai đoạn 1 (Pre-Commit):** Nếu xảy ra lỗi khi tạo `ban_session_items` hoặc `kitchen_tickets`, ứng dụng sẽ chủ động xóa các record dở dang đã tạo, khôi phục `qr_requests.status` về lại `pending_staff` và báo lỗi cho nhân viên.
- **Giai đoạn 2 (Post-Commit):** Khi vé bếp đã được chèn và món đã đánh dấu `da_gui`, việc gửi bếp được coi là **ĐÃ HOÀN TẤT THÀNH CÔNG**. Nếu việc cập nhật `qr_requests.status = 'sent_kitchen'` bị lỗi mạng, ứng dụng **KHÔNG ĐƯỢC ROLLBACK** (vì sẽ làm nhân viên bấm lại gây trùng vé bếp). Ứng dụng sẽ tự động thử lại 3 lần hoặc cảnh báo nhân viên kiểm tra đồng bộ.

---

## 5. KIẾN TRÚC DATABASE, RLS, RPC SECURITY & GIÁ AUTHORITATIVE

### 5.1. Bảng Cơ Sở Dữ Liệu (`supabase/migration_qr_ordering.sql`)
1. **`qr_channels`**: Quản lý thông tin mã QR của từng bàn hoặc quầy.
   - `id` (uuid), `store_id` (uuid), `type` (`table` | `counter`), `table_id` (uuid nullable), `channel_code` (text unique - mã ngẫu nhiên 64-bit entropy gồm tiền tố + 16 ký tự hex, ví dụ: `TBL_A1B2C3D4E5F67890`), `name` (text), `is_active` (boolean).
2. **`qr_requests`**: Lưu các đơn đặt hàng từ khách.
   - `id` (uuid), `store_id` (uuid), `channel_id` (uuid), `type` (`table` | `counter`), `table_id` (uuid), `table_name` (text), `pickup_code` (text), `tracking_token` (text unique), `status` (`pending_staff` | `processing` | `sent_kitchen` | `rejected` | `expired`), `note` (text), `total_amount` (numeric).
3. **`qr_request_items`**: Chi tiết từng món trong đơn QR.
   - `id` (uuid), `request_id` (uuid), `product_id` (uuid), `product_name` (text), `unit_price` (numeric), `quantity` (int 1..99), `modifiers_json` (text), `note` (text).

### 5.2. Chính Sách Bảo Mật Row Level Security (RLS)
- File `migration_qr_ordering.sql` **chỉ bật RLS cho 3 bảng QR** (`qr_channels`, `qr_requests`, `qr_request_items`), cho phép người dùng xác thực (`authenticated`) thuộc `store_members` truy cập.
- File migration **KHÔNG cấu hình hay can thiệp RLS trên các bảng core** (`ban_sessions`, `kitchen_tickets`, `products`...).
- ⚠️ **Khuyến cáo trước khi Production:** Cần audit và thiết lập phân quyền RLS/GRANT riêng cho các bảng core trước khi ra mắt chính thức.

### 5.3. Hệ Thống RPC Public (Security Definer)
Khách hàng không tài khoản tương tác hoàn toàn qua 4 hàm RPC bảo mật:
1. `get_qr_menu(p_channel_code text)`: Trả về thông tin cửa hàng, danh sách sản phẩm active (`is_topping = false`), danh sách topping (`is_topping = true`) và liên kết `product_topping_links`.
2. `submit_qr_order(p_channel_code text, p_items jsonb, p_note text)`:
   - Validate số lượng món trong đơn ($\le 50$), số lượng từng món ($1..99$), độ dài ghi chú.
   - **Tính giá Authoritative & Validate Topping:** Đọc giá gốc từ bảng `products` của store. Kiểm tra từng topping bắt buộc phải có `is_topping = true` AND có liên kết hợp lệ trong `product_topping_links` với món chính. Nếu sai sẽ `RAISE EXCEPTION`. Không tin tưởng giá hay thông tin client gửi lên.
   - Sinh `tracking_token` ngẫu nhiên và `pickup_code` (nếu là Counter).
3. `claim_qr_request(p_request_id uuid)`: Kiểm tra `auth.uid()` thuộc `store_members` của `store_id` đơn hàng và chuyển trạng thái `pending_staff` $\rightarrow$ `processing` một cách nguyên tử.
4. `get_qr_request_status(p_tracking_token text)`: Nhận `tracking_token` và trả về thông tin trạng thái đơn gồm các trường: `id`, `status`, `table_name`, `pickup_code`, `total_amount`, `updated_at`.

---

## 6. CẤU TRÚC FILE DART & CÁC ĐIỂM TÍCH HỢP HỆ THỐNG

### 6.1. Thư mục chính: `lib/modules/qr_order/`
- **`models/qr_order_model.dart`**: Các class `QrOrderSettingsModel`, `QrChannelModel`, `QrRequestModel`, `QrRequestItemModel`.
- **`services/qr_sound_service.dart`**: Phát âm thanh Chime (`notification.mp3`) và rung haptic hai nhịp (`HapticFeedback.heavyImpact()`).
- **`repository/qr_order_repository.dart`**: Quản lý cài đặt `QrOrderSettingsModel` lưu trong bảng KV core `app_settings` (key `'qr_order_settings'`), upsert kênh QR với token entropy 64-bit, thực thi các hàm RPC (`fetchQrMenu`, `submitQrOrder`, `claimRequest`, `checkRequestStatus`), và stream danh sách đơn chờ `watchPendingRequests`.
- **`providers/qr_order_providers.dart`**: Các provider Riverpod (`qrOrderRepoProvider`, `qrOrderSettingsProvider`, `pendingQrRequestsStreamProvider`, `pendingTableQrRequestsProvider`, `pendingCounterQrRequestsProvider`). Lắng nghe số lượng đơn chờ tăng lên để kích hoạt âm thanh/rung trên máy nhân viên.
- **`services/qr_pdf_service.dart`**: Dịch vụ dùng chung (`QrPdfService`) chịu trách nhiệm tạo file PDF Vector kích thước thật cho:
  - Tem Bàn đơn lẻ (Single Decal PDF).
  - Hàng loạt Tem Bàn (Multi-page Decal PDF, mỗi trang 1 tem).
  - Poster Quầy Thu Ngân (Counter Poster PDF khổ A5, A4 hoặc Custom size).
- **`screens/tabs/qr_settings_tab.dart`**: Widget Tab 1 — Thiết lập hệ thống (Bật/tắt chế độ, cài đặt tên miền HTTPS công khai).
- **`screens/tabs/table_qr_list_tab.dart`**: Widget Tab 2 — Quản lý danh sách QR Bàn (Nhóm theo khu vực, tìm kiếm/lọc, xem trước, sao chép link & in lẻ).
- **`screens/tabs/batch_table_print_tab.dart`**: Widget Tab 3 — Quản lý in tem bàn hàng loạt & tùy chỉnh kích thước mm/bleed/crop marks/template.
- **`screens/tabs/counter_qr_design_tab.dart`**: Widget Tab 4 — Quản lý & Thiết kế Poster QR Quầy (Merchant Designer, theme presets, khối thông tin tùy chọn).
- **`screens/qr_order_screen.dart`**: Màn hình chính Hub QR nhẹ nhàng, điều phối 4 Tab độc lập.
- **`screens/customer_qr_order_screen.dart`**: Màn hình Khách hàng tự gọi món.
- **`screens/table_qr_print_screen.dart`**: Màn hình xem trước & gọi hộp thoại in ấn hệ thống (System Print Dialog).

---

## 11. HẠN CHẾ HIỆN TẠI & LƯU Ý LOGO
- **Giới hạn Logo Upload:** Do hệ thống chưa khởi tạo bucket Supabase Storage riêng cho việc upload ảnh logo tùy chỉnh của quán, Poster QR hiện tại sử dụng **tên quán dạng Text Vector sắc nét hoặc logo asset mặc định của ứng dụng (`assets/images/logo.png`)** để tránh phát sinh chi phí hạ tầng hay làm phức tạp hóa storage.
- **Ràng buộc QR Quầy:** Mã QR Quầy là kênh cố định duy nhất cho mỗi cửa hàng, sinh mã Pickup Code `#Q01`, `#Q02`... và **tuyệt đối KHÔNG có thanh toán trực tuyến**.

### 6.2. Điểm tích hợp vào dự án chính
- **`lib/core/repositories/module_repository.dart`**: Khai báo mã module `'qr_order'` trong `_kAllModules`.
- **`lib/shared/widgets/module_tile.dart`**: Đăng ký thông tin biểu tượng, màu sắc và tiêu đề module QR trong `kModuleConfigs`.
- **`lib/screens/ban_screen.dart`**:
  - Tích hợp `pendingTableQrRequestsProvider`.
  - Thêm widget `_PulsingTableBorder` sử dụng `AnimationController` làm viền bàn phát sáng/nhấp nháy màu vàng liên tục khi có đơn QR chờ duyệt.
  - Thêm tag badge `⚡ QR (N món)`. Khi bấm vào bàn sẽ mở `QrOrderReviewSheet`.
- **`lib/screens/pos_screen.dart`**:
  - Tích hợp `pendingCounterQrRequestsProvider`.
  - Thêm badge **`⚡ QR Quầy (N) #Q01`** trên thanh Header Bar. Khi bấm vào sẽ mở `QrOrderReviewSheet`.
- **`lib/main.dart`**: Đăng ký route `'/qr_order'` và xử lý query parameter `code` trong `onGenerateRoute` để dẫn trực tiếp vào `CustomerQrOrderScreen(channelCode: code)`.
- **`lib/screens/dashboard_screen.dart`**: Điều hướng route `'/qr_order'` tới `QrOrderScreen`.

---

## 7. HẰNG SỐ HỆ THỐNG MANG ĐỊ (TAKEAWAY CONSTANTS)

Khi duyệt đơn QR Chế độ COUNTER (Gọi tại quầy), dữ liệu món được ghi vào Bàn hệ thống Mang Đi chuẩn của POS. Các hằng số được sử dụng đồng bộ chính xác 100% với `lib/screens/pos_screen.dart`:

```dart
// Khai báo trong lib/modules/qr_order/widgets/qr_order_review_sheet.dart:
static const String kSysPosTakeawayZoneId  = '00000000-0000-0000-0001-000000000001';
static const String kSysPosTakeawayTableId = '00000000-0000-0000-0001-000000000002';
```

---

## 8. QUẢN LÝ & IN ẤN MÃ QR, CẤU TRÚC URL

### 8.1. Cấu Trúc URL & Quy Tắc Quản Lý Tên Miền (Public Base URL)
Mã QR quét ra liên kết có cấu trúc Hash Routing tương thích Web Flutter:
```
https://<domain_quán_nhỏ>/#/qr_order?code=<CHANNEL_CODE>
```

#### Quy tắc Cấu hình & Bảo mật Tên miền:
1. **Giải thích nghiệp vụ:** Tên miền Public là URL trang web công khai đã deploy của quán được nhúng vào mã QR để điện thoại khách sau khi quét có thể mở giao diện gọi món di động.
2. **ExpansionTile Custom Domain (Nâng cao):** Cấu hình Custom Base URL được đặt gọn trong `ExpansionTile` ("Cấu hình Tên miền Tùy chỉnh (Nâng cao)").
3. **Chuẩn hóa & Validate HTTPS:**
   - Tự động loại bỏ ký tự gạch chéo `/` ở cuối chuỗi URL (`_normalizeUrl`).
   - Yêu cầu bắt buộc giao thức `https://`. Tự động chặn các URL không an toàn hoặc chứa `localhost`, `127.0.0.1`, IP nội bộ (`192.168.x.x`, `10.x.x.x`).
   - **Không hardcode tên miền production giả:** Nếu chưa cấu hình domain public hợp lệ, hệ thống hiển thị banner cảnh báo và **tự động khóa xuất/in mã QR** (`_buildTableQrUrl` và `_buildCounterQrUrl` trả về `null`).
4. **Tính năng "Kiểm Tra / Mở Thử":** Tích hợp nút kiểm tra cho phép mở thử URL trên trình duyệt web hoặc sao chép link thử nghiệm.

### 8.2. In ấn Thẻ QR & Xuất PDF Vector Decal Hàng Loạt
Trong màn hình `QrOrderScreen` (Tab **In Tem Bàn**), hệ thống hỗ trợ cấu hình in ấn chuyên nghiệp phục vụ việc gửi file cho các xưởng/nhà in decal:

1. **Chế độ Chọn Bàn In (Multi-select):**
   - **Tất Cả Bàn:** Tự động tạo tem decal cho toàn bộ bàn ăn trong quán.
   - **Theo Khu Vực:** Chọn in tem theo từng khu vực cụ thể.
   - **Từng Bàn Cụ Thể:** Cho phép tích chọn/bỏ chọn từng bàn linh hoạt qua giao diện Grid Checkboxes.
2. **Kích Thước Decal & Bleed (Thích hợp cho nhà in):**
   - Presets kích thước chuẩn: `60x90 mm`, `70x100 mm` (Mặc định), `80x120 mm` và `Custom Width/Height mm`.
   - Tràn lề (Bleed): Tùy chọn `0 mm`, `2 mm` (Khuyên dùng), `3 mm`.
   - Safe Area Margin: Lề an toàn `3 mm` bên trong viền tem.
   - Dấu cắt góc (Crop Marks): Tùy chọn hiển thị dấu cắt căn chỉnh góc cho xưởng in.
3. **Chỉnh Sửa Template Mẫu Dùng Chung (Edit Template):**
   - **Tiêu đề chính (Header Title):** Mặc định `"QUÉT QR GỌI MÓN"`.
   - **Lời hướng dẫn:** Mặc định `"Quét mã QR bằng ứng dụng Zalo, Camera hoặc trình duyệt di động để xem Menu"`.
   - **Ghi chú xác nhận bắt buộc (Confirm Note):** Mặc định `"Sau khi đặt xong, vui lòng gọi nhân viên đến đọc lại và xác nhận món. Món chỉ được gửi xuống bếp sau khi nhân viên xác nhận."`.
4. **Xem Trước Trực Quan (Live Interactive Preview):** Hiển thị ô xem trước mô phỏng tem decal thực tế theo tỷ lệ thực trước khi bấm xuất file.
5. **Xuất PDF Vector Kích Thước Thật (True-size Multi-page Decal PDF):**
   - Tạo file PDF Vector kích thước thật, trong đó **mỗi trang PDF là 1 tem decal đúng kích thước chuẩn mm** (không bó hẹp trong khổ giấy A4/A5 thông thường), hỗ trợ các thiết bị in tem nhãn/decal cuộn và máy in công nghiệp.
   - Mã QR được đặt trong khung **Quiet Zone** (nền trắng bao quanh) với độ tương phản cao (đen/trắng), kích thước tối thiểu an toàn $\ge 25 \times 25$ mm.
### 8.3. Thiết Kế & In Poster QR Quầy Động (Merchant Counter Poster Designer)
Trong màn hình `QrOrderScreen` (Tab **Thiết Kế QR Quầy**), chủ quán/thu ngân có thể tự do tùy biến mẫu Poster đặt tại quầy thu ngân mà không bị đóng cứng thiết kế:

1. **Presets Chủ Đề Giao Diện (Theme Presets):** `Cam Quán Nhỏ`, `Tím Hiện Đại`, `Đen Vàng Sang Trọng`, `Trắng Tối Giản`.
2. **Form Khối Nội Dung Tùy Chỉnh (Editable Blocks):**
   - Tiêu đề chính, Subtitle / Lời gọi hành động (CTA), Hướng dẫn các bước.
   - Khối Lưu Ý Bắt Buộc (Toggle ON/OFF & Chỉnh sửa nội dung).
   - Khối thông tin bổ sung tùy chọn (Optional Blocks): Tên/Mật khẩu WiFi, Hotline hỗ trợ, Giờ mở cửa, Khuyến mãi/Lời nhắn Footer.
3. **QR Code Area An Toàn (Safe & Quiet Zone):** Khung chứa mã QR được cô lập cấu trúc cố định với viền lề an toàn (Quiet zone), tuyệt đối không để các khối văn bản hay nội dung đè lên mã QR.
4. **Lưu Cấu Hình Per-Store Trên Bảng Key-Value Core `app_settings` (Tương Thích Ngược 100%):** Cấu hình `QrOrderSettingsModel` được lưu dưới dạng JSON trong bảng KV dùng chung `app_settings` (`store_id`, `key = 'qr_order_settings'`). Cơ chế này giúp toàn bộ thiết bị POS / nhân viên trong cùng cửa hàng đồng bộ cấu hình QR tức thì, đồng thời **hoàn toàn KHÔNG đòi hỏi bất kỳ migration SQL hay bảng DB mới nào**.
5. **Bộ Chọn Kích Thước Khổ Giấy Poster (A5 / A4 / Custom mm):**
   - Presets chuẩn: `A5 (148 x 210 mm)` (Mặc định), `A4 (210 x 297 mm)` và `Custom mm`.
   - Khi chọn `Custom mm`: Mở 2 ô nhập chiều rộng và chiều cao (mm) kèm validation giới hạn hợp lý ($80..500$ mm rộng, $80..700$ mm cao).
   - Live Preview hiển thị động nhãn khổ giấy được chọn và truyền chính xác kích thước `widthMm` / `heightMm` sang `CounterQrPrintScreen` và file PDF Vector.
6. **Thao Tác Quản Lý & Xuất PDF Poster:**
   - **Sao chép Link:** Sao chép URL Kênh QR Quầy.
   - **Quét / Mở Thử:** Thử nghiệm chạy URL trên trình duyệt di động qua `url_launcher`.
   - **Reset Mẫu:** Khôi phục về thiết kế poster mặc định ban đầu.
   - **Xuất PDF Poster A5 / A4 / Custom:** Xuất file PDF poster chất lượng cao theo kích thước khổ A5, A4 hoặc khổ tùy chỉnh.
   - **Bảo toàn ràng buộc nghiệp vụ:** QR Quầy vẫn là 1 channel duy nhất per store với mã Pickup Code `#Q01`, `#Q02`..., tuyệt đối không tích hợp thanh toán trực tuyến.

## 9. HƯỚNG DẪN ÁP DỤNG MIGRATION SQL & DEPLOY (CHỜ THỰC HIỆN)

> [!IMPORTANT]
> **TRẠNG THÁI HIỆN TẠI: BƯỚC NÀY CHƯA DÙNG / CHƯA CHẠY.**  
> File migration `supabase/migration_qr_ordering.sql` đã được tạo hoàn chỉnh nhưng **CHƯA ĐƯỢC CHẠY** trên Supabase production hay bất kỳ môi trường nào.

### Các bước áp dụng khi sẵn sàng triển khai (Release Phase):
1. **Áp dụng Migration SQL lên Supabase:**
   - Mở Supabase Dashboard $\rightarrow$ SQL Editor.
   - Mở file `supabase/migration_qr_ordering.sql`.
   - Sao chép toàn bộ nội dung và bấm **Run**.
2. **Kiểm tra hàm RPC & RLS:**
   - Kiểm tra các hàm `get_qr_menu`, `submit_qr_order`, `claim_qr_request`, `get_qr_request_status` đã xuất hiện trong Schema `public`.
   - Kiểm tra các bảng `qr_channels`, `qr_requests`, `qr_request_items` đã bật RLS.
3. **Build & Deploy ứng dụng Web Khách:**
   - Run `flutter build web --release`
   - Deploy hosting (Firebase Hosting / Vercel / Supabase Hosting).
   - Cập nhật tên miền Web Domain trong màn hình Cài đặt QR của ứng dụng POS.

---

## 10. CHECKLIST TEST STAGING / E2E & KỊCH BẢN BẢO MẬT

Sau khi chạy Migration SQL trên môi trường Staging, thực hiện checklist kiểm thử E2E:

- [ ] **Test TABLE Mode:**
  1. Quét QR Bàn A01 $\rightarrow$ Kiểm tra menu tải đúng tên quán và tên bàn.
  2. Chọn món + topping + ghi chú $\rightarrow$ Bấm Gửi đơn $\rightarrow$ Kiểm tra tạo record `pending_staff`.
  3. Trên máy POS nhân viên $\rightarrow$ Kiểm tra phát tiếng kêu Chime + Rung $\rightarrow$ Bàn A01 viền vàng nhấp nháy pulse + badge ⚡ QR.
  4. Bấm mở Review Sheet $\rightarrow$ Sửa số lượng $\rightarrow$ Bấm XÁC NHẬN & GỬI BẾP.
  5. Kiểm tra `ban_session_items` ghi đúng món, `kitchen_tickets` tạo đúng status `'cho'`, vé bếp in ra đúng station.
  6. Màn hình khách tự chuyển sang trạng thái "Đang chế biến".
- [ ] **Test COUNTER Mode:**
  1. Quét QR Quầy $\rightarrow$ Gửi đơn món $\rightarrow$ Kiểm tra nhận Pickup Code `#Q01`.
  2. Màn hình POS thu ngân hiển thị badge `⚡ QR Quầy (1) #Q01`.
  3. Nhân viên xác nhận gửi bếp $\rightarrow$ Kiểm tra món nạp vào Bàn Mang đi (`kSysPosTakeawayTableId`), vé bếp hiển thị `Mang đi (#Q01)`.
- [ ] **Test Bảo Mật & Error Handling:**
  1. Thử dùng Postman/Curl gọi `submit_qr_order` với ID sản phẩm không tồn tại hoặc gửi giá sai $\rightarrow$ RPC phải tự từ chối và tính lại giá chuẩn từ DB.
  2. Thử truyền `topping_id` của sản phẩm thường không nằm trong `product_topping_links` $\rightarrow$ RPC phải báo lỗi.
  3. Mở Review Sheet cùng 1 đơn trên 2 máy POS khác nhau, bấm xác nhận cùng lúc $\rightarrow$ Chỉ 1 máy claim thành công, máy còn lại báo lỗi đơn đã được xử lý.

---

## 11. HẠN CHẾ HIỆN TẠI & CẢNH BÁO LINTER

1. **Race Condition Trùng Pickup Code (Chế độ Counter):**
   - Hàm `submit_qr_order` hiện sinh `pickup_code` bằng câu lệnh `COUNT(*)+1`. Khi có nhiều lượt gửi đơn đồng thời, có thể xảy ra race condition trùng mã `pickup_code` do chưa có DB Sequence / Advisory Lock / Unique Constraint.  
   - 🛠️ **Cần gia cố trước Production:** Cần bổ sung DB Sequence hoặc Unique Constraint + Retry trong SQL.
2. **Foreground Polling / Realtime:**
   - Ứng dụng POS hiện đang sử dụng cơ chế Polling liên tục (mỗi 3 giây) kết hợp Stream để lắng nghe đơn hàng QR mới khi ứng dụng đang mở (Foreground). Chưa hỗ trợ Push Notification khi ứng dụng POS bị đóng hoàn toàn (Background/Killed).
3. **Chưa Test E2E Thực Sự Trên DB:**
   - Do tuân thủ yêu cầu không chạy Migration SQL lên Supabase production, toàn bộ dữ liệu hiện tại khi test trên giao diện sẽ hiển thị thông báo cảnh báo hệ thống chưa được cấu hình.
4. **Cảnh Báo Linter Trong Module QR (`flutter analyze lib/modules/qr_order/`):**
   - Mã nguồn module QR biên dịch thành công với **0 lỗi (0 errors)**.
   - Hiện còn 11 linter warnings/infos nằm trong chính thư mục `lib/modules/qr_order/` (như ép kiểu thừa `as Map`, tham số chưa dùng `_updateCartQty`, warning `activeColor` bị deprecated).

---

## 12. CÁC NGUYÊN TẮC BẮT BUỘC KHI PHÁT TRIỂN TIẾP

Khi bảo trì hoặc mở rộng module QR Gọi Món trong tương lai, các lập trình viên **BẮT BUỘC** tuân thủ các nguyên tắc sau:

1. 🚫 **KHÔNG ghi trực tiếp từ Client Khách vào Bảng Core:** Khách hàng tuyệt đối không được cấp quyền ghi trực tiếp vào `ban_sessions`, `orders`, hay `kitchen_tickets`. Mọi thao tác đặt hàng của khách **phải đi qua RPC `submit_qr_order`**.
2. 🛡️ **GIỮ NGUYÊN Kitchen Commit Boundary & Rollback 2 Giai Đoạn:** Không được xóa bỏ logic xóa dở dang khi bị lỗi ở Phase 1, và không được phép reset đơn về `pending_staff` khi Phase 2 (Sync status) bị lỗi sau khi vé bếp đã tạo thành công.
3. 🔐 **LUÔN kiểm tra Store Membership trong RPC Claim:** Hàm `claim_qr_request` phải luôn chứa điều kiện kiểm tra `store_id IN (SELECT store_id FROM store_members WHERE user_id = auth.uid())` để tránh tài khoản quán khác claim nhầm đơn.
4. 💰 **KHÔNG tin tưởng giá từ Client:** Tất cả tính toán giá món và topping phải do SQL RPC đảm nhiệm dựa trên dữ liệu authoritative từ bảng `products`.
5. 📌 **BẢO TỒN HẰNG SỐ MANG ĐỊ:** Không thay đổi giá trị 2 hằng số `kSysPosTakeawayZoneId` và `kSysPosTakeawayTableId` để tránh làm lệch dữ liệu với `lib/screens/pos_screen.dart`.
