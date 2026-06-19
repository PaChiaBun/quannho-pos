# Quán Nhỏ POS — Features & Modules

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

### 💰 Tính Lương (index 12)
- `modules/tinhluong/` (3 screens + 1 repo + 1 provider)
- 4 chế độ lương: M1 (giờ) / M2 (cố định) / M3 (cố định+OT) / M4 (ngày)
- Auto-generate từ dữ liệu chấm công
- Luồng duyệt: Nháp → Chờ duyệt → Duyệt → Trả lương
- Khi trả lương → tự ghi expense vào Finance
- **SQL Migration cần chạy:** `sql_migration_payroll.sql`

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

## 🏗️ Kiến Trúc Phân Quyền Module (Bắt buộc đọc khi thêm module mới)

### Luồng hoạt động
```
Chủ quán bật module X cho role Y (trong RoleManagerScreen)
    → store_roles.modules cập nhật trên Supabase
    → Dashboard nhân viên nhận Postgres Realtime event
    → permsVersionProvider.bump()
    → _staffPermsProvider refetch
    → activeModules filter lại → tile hiện/ẩn
```

### Checklist khi thêm module mới

| # | Việc cần làm | File | Ví dụ chamcong |
|---|---|---|---|
| **0** | **Bọc màn hình bằng `ResponsiveLayout`** | màn hình mới | xem mẫu bên dưới |
| 1 | Thêm screen vào IndexedStack | `main.dart` | index 10 |
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

## Lưu Ý Quan Trọng
- Màn hình lớn nhất: `ban_screen.dart` (187KB) — phức tạp nhất, chứa logic sơ đồ bàn
- Màn hình bếp dùng giao diện Kanban (kéo thả trạng thái đơn)
- **Thêm module mới**: Bắt buộc đi qua đủ 7 bước trong bảng checklist ở trên
- Giữ lâu vào ô điều hướng → mở bảng chọn tab để thay đổi
- `chamcong` mặc định `isActive = false` trong SQLite — chủ bật thủ công
