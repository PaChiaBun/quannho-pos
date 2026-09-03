# 🐘 Module: AI Bum (Trợ Lý AI)

**Trạng thái:** ✅ Hoàn thành  
**Cập nhật:** 13/08/2026

---

## Mục Đích
Quản lý trợ lý AI Bum, cấu hình bật/tắt module AI theo vai trò nhân viên, và phân quyền 9 hành động nhạy cảm của AI Bum.

---

## Tính Năng Chính
- Công tắc bật/tắt module AI Bum (`ai_bum`) theo vai trò trong **Quản lý Vai trò** (`role_manager_screen.dart`).
- Hiển thị danh mục module AI Bum và 9 hành động nhạy cảm trong **Phân Quyền Nhân Viên** (`nhan_vien_screen.dart`).
- **Pre-Query Security Guard**: Kiểm tra quyền truy cập của người dùng ngay trước khi thực thi các truy vấn dữ liệu kinh doanh.
- **Read-Only Guarantee**: AI Bum chỉ thực hiện đọc dữ liệu (`BumReadOnlyDataService`), không được tạo/sửa/xóa/duyệt dữ liệu.
- **Fail-Closed Auto-Seed**: Khi module `ai_bum` được bật từ OFF $\rightarrow$ ON, tự động cấp 3 quyền an toàn cá nhân (`help`, `my_shift`, `my_payroll`).

---

## 🔑 9 Hành Động Nhạy Cảm (`ai_bum.*`)

| Action Permission | Tên Hành Động | Mức Độ | Mô Tả & Kiểm Soát |
|-------------------|---------------|--------|-------------------|
| `ai_bum.help` | Trợ giúp & Hướng dẫn | An toàn (Auto-seed) | Hỏi đáp về tính năng, thao tác sử dụng app. |
| `ai_bum.my_shift` | Ca làm cá nhân | An toàn (Auto-seed) | Hỏi lịch làm việc, ca làm của chính mình. |
| `ai_bum.my_payroll` | Lương cá nhân | An toàn (Auto-seed) | Hỏi thông tin bảng lương, thu nhập cá nhân. |
| `ai_bum.team_shift` | Ca làm toàn quán | Nhạy cảm | Hỏi lịch làm việc của đồng nghiệp / toàn quán. |
| `ai_bum.sales` | Doanh thu & Bán hàng | Nhạy cảm | Hỏi báo cáo doanh thu, số đơn, mặt hàng bán chạy. |
| `ai_bum.inventory` | Kho hàng | Nhạy cảm | Hỏi tồn kho, nguyên liệu sắp hết, báo cáo kho. |
| `ai_bum.finance` | Thu chi & Tài chính | Nhạy cảm | Hỏi báo cáo dòng tiền, các khoản thu/chi. |
| `ai_bum.operations` | Nhiệm vụ Vận hành | Nhạy cảm | Hỏi tiến độ hoàn thành nhiệm vụ vận hành toàn quán. |
| `ai_bum.all_payroll` | Lương toàn bộ nhân viên | Rất nhạy cảm | Hỏi chi tiết bảng lương, thu nhập của nhân viên khác. |

---

## Quy Tắc Kiểm Soát Vai Trò (Role Control Rules)

1. **Owner (Chủ quán)**:
   - Được xác nhận qua `store_members` hoặc `stores.owner_user_id`.
   - Luôn có toàn bộ 9 quyền AI Bum cố định.

2. **Manager (Quản lý)**:
   - Đọc `action_perms_manager` từ `app_settings`.
   - **Không tự động vượt quyền**: Nếu Chủ quán chưa cấp quyền `ai_bum.sales` hay `ai_bum.finance`, Quản lý sẽ bị chặn khi truy vấn doanh thu hay thu chi.

3. **Staff (Nhân viên)**:
   - Phải được Chủ quán bật module `ai_bum`.
   - Khi bật module (`OFF` $\rightarrow$ `ON`), tự động nhận 3 quyền an toàn (`help`, `my_shift`, `my_payroll`).
   - Các quyền nhạy cảm khác do Chủ quán chủ động bật/tắt trong giao diện Phân quyền.
