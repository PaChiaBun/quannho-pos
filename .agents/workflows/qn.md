---
description: Nạp toàn bộ context dự án Quán Nhỏ POS và quy chuẩn làm việc vào đầu hội thoại
---

# Workflow: /qn — Context & Quy Chuẩn Quán Nhỏ POS

Khi user gọi `/qn`, thực hiện các bước sau **theo thứ tự**:

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

## 3. Kiến Trúc Dữ Liệu Hybrid Online/Offline & Khả Năng Mở Rộng (Data Architecture & Scalability)
* **Vận hành Hybrid Seamless (Online & Offline Song Hành):**
  * Đã tối ưu hóa cấu trúc dữ liệu cho phép ứng dụng hoạt động hoàn hảo 100% trong mọi điều kiện kết nối: hoạt động mượt mà khi **Online** (kết nối Cloud Realtime) và tiếp tục bán hàng, tính tiền, in hóa đơn không ngắt quãng khi **Offline** (lưu trữ local database).
  - Tự động chuyển đổi chế độ và đồng bộ bất đối xứng 2 chiều khi có mạng trở lại, đảm bảo 0% rủi ro mất đơn hàng, trùng lặp hay sai lệch kho.
* **Linh hoạt thích ứng mọi quy mô (Từ Quán Nhỏ đến Nhà Hàng Lớn & Chuỗi Chi Nhánh):**
  * Kiến trúc thiết kế đáp ứng hoàn hảo cho mọi cấp độ kinh doanh: từ **Quán nhỏ lẻ / Hộ kinh doanh cá thể**, **Nhà hàng quy mô lớn**, cho đến **Chuỗi chi nhánh nhượng quyền mở rộng (Multi-branch Franchise Chains)**.
  * Hỗ trợ quản lý đa cửa hàng (`store_id`), chuyển đổi chi nhánh siêu tốc và tổng hợp báo cáo kinh doanh toàn chuỗi theo thời gian thực.

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
