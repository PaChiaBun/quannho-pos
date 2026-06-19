# 👥 Module: Nhân Viên

**Trạng thái:** ✅ Hoàn thành  
**Cập nhật:** 17/05/2026

---

## Mục Đích
Quản lý hồ sơ nhân viên, phân quyền theo vai trò, và gán ca làm việc.

## Tính Năng Chính
- Thêm/xóa nhân viên bằng số điện thoại
- Tạo và quản lý Vai trò (Role): tên, màu sắc, biểu tượng (50+ icon)
- Phân quyền module cho từng vai trò
- Đổi vai trò của nhân viên
- Đặt/đổi PIN đăng nhập
- Ảnh đại diện nhân viên
- **[MỚI] Tạo và quản lý Ca làm việc (Shift)**
- **[MỚI] Gán nhân viên vào Ca làm việc**

---

## Hệ Thống Vai Trò & Quyền
- Mỗi nhân viên có 1 vai trò
- Vai trò quyết định module nào hiển thị trên app nhân viên
- Thay đổi quyền → realtime ngay lập tức (không cần đăng xuất)
- Nhân viên vẫn có thể đổi thứ tự các tab trong giới hạn quyền của mình

---

## 🕐 Hệ Thống Ca Làm Việc (Shift) — v2, 17/05/2026

### Vị trí
Tab **Phân quyền** → section **Ca làm việc** (nằm dưới danh sách vai trò)

### Tạo Ca
Nhấn **"+ Thêm ca"** → form mở ra với:
- **4 Chip gợi ý nhanh:** Ca Sáng (06:00–14:00), Ca Chiều (14:00–22:00), Ca Tối (17:00–23:00), Ca Khuya (22:00–06:00)
- Tên ca (tự nhập hoặc chọn chip)
- Giờ bắt đầu / Kết thúc (time picker)
- Màu sắc ca

### Gán Nhân Viên vào Ca
- Nhấn nút **"Nhân viên ∨"** trên card ca → expand
- Nhấn **"+ Thêm"** → sheet chọn nhân viên chưa có ca
- Nhân viên được gán ca hiển thị dạng chip có thể xóa (× để bỏ ca)
- Mỗi nhân viên chỉ thuộc 1 ca tại 1 thời điểm

### Database
| Bảng | Cột mới |
|------|---------|
| `store_shift_configs` | Bảng mới: id, store_id, name, start_hour, start_minute, end_hour, end_minute, color, sort_order, is_active |
| `store_members` | `shift_config_id UUID` (FK → store_shift_configs) |

> **Lưu ý kỹ thuật:** `store_shift_configs` đã tắt RLS và đã GRANT ALL cho role `authenticated`. `store_members` đã có `shift_config_id`.

---

## Ví Dụ Vai Trò
| Vai trò | Module được cấp |
|---------|----------------|
| Nhân viên bàn | Bán hàng, Bàn, Bếp |
| Thu ngân | Bán hàng, Thu Chi |
| Quản kho | Kho, Bán hàng |
| Quản lý | Hầu hết module |

---

## Câu Hỏi Thường Gặp
- *"Thêm nhân viên mới?"* → Nhân Viên → "+" → nhập SĐT, chọn vai trò, đặt PIN
- *"Thay đổi quyền có hiệu lực ngay không?"* → Có, realtime — nhân viên không cần đăng xuất
- *"Nhân viên quên PIN?"* → Chủ quán vào hồ sơ → Đặt lại PIN
- *"Thêm vai trò mới?"* → Nhân Viên → tab Phân quyền → Vai trò → "+"
- *"Tạo ca làm việc?"* → Nhân Viên → tab Phân quyền → Ca làm việc → "+ Thêm ca"
- *"Gán nhân viên vào ca?"* → Ca làm việc → card Ca → nhấn "Nhân viên ∨" → "+ Thêm"
- *"1 nhân viên có thể làm nhiều ca không?"* → Không — mỗi nhân viên chỉ có 1 ca chính trong `store_members.shift_config_id`
