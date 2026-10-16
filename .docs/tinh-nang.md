# Quán Nhỏ POS — Features & Modules

## Bản sửa checkout V5 đang kiểm thử (chưa production)

- Đã chạy PostgreSQL thật cô lập: hai nhánh có/không coupons, race 50 callers, POS/Bàn cùng phiên, ví đồng thời và rollback khi ghi thu chi lỗi. Chưa kiểm thử máy Windows/máy in thực tế.
- POS có nút phục hồi giao dịch bị gián đoạn kể cả sau restart/giỏ trống; kết quả được giữ đến khi người dùng xác nhận. Không tự in lại khi reconcile.
- Món hủy không tính tiền/trừ kho; canonical orders và tổng điểm được phân bổ khớp một settlement. Thu nhập nạp ví không bị cộng vào dashboard bán hàng.
- Giảm giá thủ công POS kiểm tra quyền server và audit; đóng phiên POS gửi bếp cùng transaction thu tiền.

- Chống click thanh toán lặp, giữ khóa retry POS sau timeout/restart và chặn đổi phương thức khi giao dịch trước chưa rõ kết quả.
- Thanh toán ví POS có trừ số dư/lịch sử ví cùng transaction; bonus hết hạn không được dùng, thiếu ví từ chối trước ghi đơn.
- Điểm thưởng quy đổi theo cấu hình quán; bill dùng tổng server; báo cáo voucher mở đúng order UUID.
- Chưa tuyên bố hoàn tất trước PostgreSQL runtime gate, Windows/print E2E và đối soát dữ liệu trùng lịch sử được chủ quán phê duyệt.

## QR Gọi Món — mục tiêu đang chờ triển khai

- Một QR gọi món tại bàn dùng chung và một QR mang đi tại quầy cho mỗi cửa hàng.
- Sau khi khách xác nhận, web hiển thị QR động của đơn; nhân viên quét, chọn bàn cho TABLE, đọc lại và chỉnh món trước khi gửi Bếp.
- TABLE xuất hiện trong module Bàn sau bước gán bàn và thanh toán toàn bộ bàn sau; COUNTER thanh toán trước Bếp và không vào module Bàn.
- Nhân viên dùng tài khoản/mã quán/phân quyền hiện hành, không ghép POS device riêng.
- Đây là phạm vi mục tiêu, chưa phải tính năng production. Xem `.docs/qr-order-kien-truc-muc-tieu.md`.

## Màn Hình Chính

### 🏠 Dashboard (index 0)
- `screens/dashboard_screen.dart` (59KB)
- Tổng quan doanh thu, đơn hàng, nhanh chóng

### 🛒 Bán Hàng / POS (index 1)
- `screens/pos_screen.dart` (63KB)
- `modules/pos/` (3 files)
- Tạo đơn, chọn món, thanh toán

### 📦 Kho (index 2)
- `screens/inventory_screen.dart` (63KB)
- `modules/inventory/` + `modules/kho/` (3 files)
- Quản lý tồn kho, nhập xuất hàng

### 💰 Thu Chi (index 3)
- `screens/finance_screen.dart` (24KB)
- `modules/finance/` (3 files)
- Ghi thu, ghi chi, báo cáo tài chính

### 🏆 Điểm / Loyalty (index 4)
- `screens/loyalty_screen.dart` (61KB)
- `modules/loyalty/` (1 file)
- Tích điểm khách hàng, đổi quà

### 📊 Báo Cáo (index 5)
- `screens/report_screen.dart` (40KB)
- `modules/report/`
- Doanh thu theo ngày/tuần/tháng

### ⚙️ Cài Đặt (index 6)
- `screens/settings_screen.dart` (41KB)
- `features/settings/`
- Cấu hình quán, PIN, in ấn, v.v.

### 🪑 Bàn (index 7)
- `screens/ban_screen.dart` (187KB — lớn nhất)
- Sơ đồ bàn, gán đơn vào bàn, chuyển bàn

### 👨‍🍳 Bếp / Kitchen (index 8)
- `screens/kitchen_screen.dart` (60KB)
- Màn hình Kanban cho bếp
- Nhận phiếu gọi món, cập nhật trạng thái

### 👥 Nhân Viên (index 9)
- `screens/nhan_vien_screen.dart` (78KB)
- Quản lý hồ sơ nhân viên, thêm/xóa, đổi role
- Phân quyền: xem, chỉnh sửa danh sách vai trò + module
- `screens/role_manager_screen.dart` — Màn hình quản lý vai trò & quyền chi tiết

### 🖐️ Chấm Công (index 10)
- `screens/chamcong_screen.dart`
- **Staff view**: Bấm VÀO CA / RA CA, chụp selfie, ghi GPS tự động
- **Manager view**: Báo cáo tổng hợp tất cả ca làm
- Ảnh selfie upload lên Google Drive (fallback: Supabase Storage)
- Mặc định TẮT — chủ quán bật thủ công trong Cài đặt module

### 🍽️ Kho Chuyên Nghiệp (index 11)
- `modules/kho_chuyen_nghiep/` (8 screens + 1 repo + 1 provider)
- Định lượng công thức, lệnh sản xuất, trừ kho nguyên liệu tự động
- Tích hợp POS: bán 1 món → tự trừ nguyên liệu theo công thức
- Mặc định TẮT — dành cho nhà hàng/quán cần quản lý COGS

### 💰 Lương (index 12)
- `modules/tinhluong/` — trung tâm chính sách, kỳ lương, phiếu lương và báo cáo vận hành
- 5 chế độ: M1 theo giờ / M2 cố định / M3 cố định + OT / M4 theo ngày / M5 tùy chỉnh
- Thiết lập chính sách theo **vị trí** trước, cho phép ghi đè riêng theo **nhân viên**
- Chính sách tách rõ: cách tính lương, thưởng & phụ cấp, OT và khấu trừ
- Tạo kỳ từ dữ liệu chấm công; bắt buộc rà soát cấu hình và ca bất thường trước khi gửi duyệt
- Luồng duyệt: Nháp → Chờ duyệt → Duyệt → Trả lương; trả lương tự ghi expense vào Finance
- Báo cáo dạng bảng theo nhân viên, có tìm kiếm, lọc, sắp xếp và khu vực “Cần rà soát”
- **Migration:** `supabase/payroll_salary_config_migration.sql`

---

## Features

### 🤖 AI Assistant (Bum)
- `features/ai_assistant/`
- **Trạng thái**: Đang xây dựng — "Coming Soon"
- Mascot: Bum 🐘, hiện tại chỉ hiển thị bottom sheet thông báo

### 💾 Backup
- `features/backup/`
- Backup dữ liệu local/cloud

### 🧾 Bill Designer
- `features/bill_designer/`
- Thiết kế mẫu hoá đơn in

### 🏪 Module Store
- `features/module_store/`
- Mua thêm tính năng/module

### 📋 Module Picker
- `screens/module_picker_screen.dart` (18KB)
- Chọn module hiển thị trên nav bar

---

## Chi Tiết Các Module Kỹ Thuật

### bill_printer — In Hoá Đơn
- In hoá đơn qua Bluetooth/WiFi

### menu — Quản Lý Thực Đơn
- Quản lý danh mục món, giá bán, hình ảnh

---

## 🏗️ Kiến Trúc Phân Quyền Module Trực Tiếp (Bắt buộc đọc khi thêm module mới)

### Luồng hoạt động (Cập nhật 2026-07-28 — Gán Module Trực Tiếp cho NV)
```
Chủ quán/Quản lý gán trực tiếp module X cho nhân viên (trong NhanVienScreen)
    → staff_members.modules + store_members.modules cập nhật trên Supabase
    → Thiết bị nhân viên nhận Postgres Realtime event
    → permsVersionProvider.bump()
    → _staffPermsProvider đọc trực tiếp mảng modules của NV
    → activeModules filter lại → tile & tab hiển thị đúng 100%
```

### Checklist khi thêm module mới

| # | Việc cần làm | File | Ví dụ chamcong |
|---|---|---|---|
| **0** | **Bọc màn hình bằng `ResponsiveLayout`** | màn hình mới | xem mẫu bên dưới |
| 1 | Đăng ký screen trong `ActiveModuleHost` | `main.dart` | index 10; chỉ mount khi active |
| 2 | Khai báo `_kTabMeta` | `main.dart` | `chamcong` |
| 3 | Khai báo `kModuleConfigs` | `shared/widgets/module_tile.dart` | route `/chamcong` |
| 4 | Seed vào SQLite local | `core/database/app_database.dart` | migration v12 + beforeOpen |
| 5 | Thêm vào `permMap` | `dashboard_screen.dart` | `'chamcong': 'chamcong'` |
| 6 | Thêm vào `_navigateTo tabMap` | `dashboard_screen.dart` | `'/chamcong': 10` |
| 7 | Thêm vào `_kModuleNames` | `role_manager_screen.dart` | checkbox phân quyền |
| **8** | **Nút bấm tối thiểu 52px height** (cảm ứng desktop) | màn hình mới | `SizedBox(height: 52, ...)` |

> ⚠️ Thiếu bất kỳ bước nào trong 8 bước trên → module không hoạt động đúng

### Mẫu Responsive Bắt Buộc (Bước 0)

```dart
import '../core/utils/responsive.dart';

class TenManHinhScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ BẮT BUỘC từ 2026-04-30 — tất cả màn hình mới phải dùng
    return ResponsiveLayout(
      mobile:  _TenManHinhMobile(),
      tablet:  _TenManHinhTablet(),   // bỏ qua nếu giống mobile
      desktop: _TenManHinhDesktop(),  // layout 2 cột, nút to hơn
    );
  }
}
```

### Realtime Permissions — Quy tắc vàng

> **KHÔNG** đặt subscription realtime trong màn hình có điều kiện quyền truy cập.

**Lý do:** Nếu nhân viên không có quyền vào module X, màn hình X không mount → subscription không chạy → realtime không hoạt động.

**Đúng:** Đặt subscription trong `DashboardScreen` — màn hình **luôn mount** với mọi user đã đăng nhập.

**File chịu trách nhiệm realtime:**
- `dashboard_screen.dart` → `_subscribeStoreRolesRealtime()` — watch `store_roles` table
- `permsVersionProvider` (NotifierProvider) — counter trigger refetch
- `_staffPermsProvider` — watch counter, refetch `getModulePermissions`

### SQL bắt buộc khi deploy
```sql
-- Bật Realtime cho bảng store_roles (chỉ cần chạy 1 lần)
ALTER PUBLICATION supabase_realtime ADD TABLE store_roles;
```

---

## Hóa đơn điện tử (nền tảng, chưa phát hành tự động)

- Cài đặt → công tắc "Hóa đơn điện tử": chỉ Chủ quán thấy, cần PIN duyệt nhanh, có audit. Mặc định tắt. Tắt/bật không ảnh hưởng doanh thu.
- Báo cáo → tab "Hóa đơn": số tiền đã xuất hóa đơn, đối chiếu với doanh thu bill cùng kỳ, chờ xử lý, lỗi/từ chối, danh sách hóa đơn cần xử lý. Số liệu là 0 cho đến khi có worker phát hành meInvoice.
- Cần áp migration `20261016_einvoice_foundation_v1.sql` trước khi dùng; trước đó tab báo cáo hiện thông báo lỗi tải.

## Báo cáo chuỗi cửa hàng (Chủ quán)
- **Module `chain`** — ô **"Báo Cáo Nhiều Cửa Hàng / Chuỗi"** (màu xanh chanh) trong lưới Modules ở Trang chủ. CHỈ Chủ quán thấy (lọc cứng ở `dashboard_screen.dart`, không cấp qua vai trò/`store_roles.modules`); Quản lý và nhân viên không thấy, server cũng kiểm lại.
- Tự bật MỘT LẦN cho mỗi cửa hàng khi Chủ quán sở hữu từ 2 cửa hàng trở lên hoặc đã có chuỗi (`ChainModuleOffer`, cờ `chain_module_offered_<storeId>`); sau đó Chủ quán gỡ/thêm lại như mọi module trong chế độ Sửa, không tự quay lại. Chủ chỉ có 1 cửa hàng thì chưa tự bật nhưng vẫn thêm tay được từ bộ chọn module.
- Màn **Báo cáo chuỗi** = báo cáo **SO SÁNH các cửa hàng**, thiết kế theo đúng ngôn ngữ của module Báo cáo (header navy + 2 thẻ hero kem, chọn kỳ Hôm nay/Tuần này/Tháng này + thanh ‹ kỳ › để xem kỳ cũ):
  - **Nhận xét nhanh** (quy tắc cố định, KHÔNG phải AI; mọi ngưỡng ở `InsightConfig`, `lib/core/utils/chain_insights.dart`). Nguyên tắc: chỉ nói điều dữ liệu đủ chứng minh.
    - Tăng/giảm chỉ được nêu khi vượt **mức dao động bình thường** (đo thật: so 1 ngày với cùng thứ tuần trước lệch P80 = 26% số đơn / 34% doanh thu; kỳ nhiều ngày thu hẹp theo 1/√số ngày, sàn 5%/6%), mỗi bên ≥ 15 đơn; so theo **ngày có bán** (tuần nghỉ 3 ngày không bị báo "nhu cầu giảm"); kèm nguyên nhân (số đơn hay giá trị mỗi đơn) và dòng giải thích ngưỡng.
    - Cảnh báo riêng: quán im lặng (kỳ này 0 đơn, cùng kỳ trước ≥ 5 đơn), ngày không có đơn khi kỳ trước bán đều, hủy món/bàn ≥ 5% doanh thu và ≥ 1,8× các quán khác, giảm giá ≥ 4% giá trị bán và ≥ 2× các quán khác (cần ≥ 30 đơn), TB/đơn thấp ≤ 80% trung bình chuỗi. Nêu: quán dẫn đầu/tập trung ≥ 70%, TB/đơn cao ≥ 115%, quán mới, quán chưa từng có đơn. Tối đa 6 nhận xét, cảnh báo xếp trước.
    - Không kết luận khi: mẫu ít (chip "Ít dữ liệu"), quán mới ("Quán mới"), kỳ trước không có gốc ("Mới"), không tải được kỳ so sánh, máy chủ chưa gửi trường (coi là "không rõ", không phải 0).
    - Ngày được so với **cùng thứ tuần trước** (cuối tuần bán nhiều hơn ngày thường ~40%); tuần/tháng so kỳ liền trước; kỳ đang diễn ra so với phần đã trôi của kỳ trước.
  - **Xếp hạng doanh thu:** thứ hạng, màu riêng mỗi quán, thanh so sánh, số đơn/TB/tỷ trọng và chip so với cùng kỳ trước — chỉ tô xanh/đỏ khi vượt dao động bình thường; chạm chip xem lý do.
  - **So sánh theo chỉ số:** Doanh thu / Số đơn / TB/đơn / Giảm giá, vạch trung bình chuỗi, nhãn Cao nhất/Thấp nhất.
  - **Cơ cấu thanh toán:** cột chồng 100% tiền mặt/chuyển khoản/thẻ từng quán. **Xu hướng theo ngày:** mỗi quán một đường (không vẽ ngày chưa tới).
  - So kỳ ĐANG diễn ra với phần đã trôi của kỳ trước (không so nửa ngày/nửa tuần với cả kỳ trước). Màu quán cố ý tránh lục/xanh dương/vàng (dành cho phương thức thanh toán). Biểu tượng cửa hàng trên màn đó mở bảng quản lý chuỗi (tạo chuỗi, thêm/gỡ cửa hàng). Biểu tượng cửa hàng ở header màn Báo cáo vẫn là lối phụ.
- Không có KPI cá nhân nhân viên xuyên chuỗi; muốn xem chi tiết hãy chuyển sang cửa hàng đó. Cần migration `20261017_chuoi_cua_hang_v1.sql` (đã áp production 17/10/2026).

## Lưu Ý Quan Trọng
- Màn hình lớn nhất: `ban_screen.dart` (187KB) — phức tạp nhất, chứa logic sơ đồ bàn
- Màn hình bếp dùng giao diện Kanban (kéo thả trạng thái đơn)
- **Thêm module mới**: Bắt buộc đi qua đủ 7 bước trong bảng checklist ở trên
- Giữ lâu vào ô điều hướng → mở bảng chọn tab để thay đổi
- `chamcong` mặc định `isActive = false` trong SQLite — chủ bật thủ công
