# 🪑 Module: Quản Lý Bàn

**Trạng thái:** ✅ Hoàn thành
**Cập nhật:** 14/05/2026

---

## Mục Đích
Quản lý sơ đồ bàn trực quan — biết bàn nào trống, bàn nào có khách, bàn nào đang chờ thanh toán.

## Tính Năng Chính
- Sơ đồ bàn theo khu vực (trong nhà, ngoài trời, VIP...) — xem dạng lưới hoặc sơ đồ kéo thả
- Trạng thái bàn: Trống / Có khách
- Mở đơn → gọi món → gửi bếp → tính tiền — tất cả trong 1 luồng
- Chuyển bàn (kéo toàn bộ đơn sang bàn khác)
- Thêm/sửa/xóa bàn và khu vực (Chủ quán/Quản lý hoặc nhân viên được phân quyền qua `'ban.manage_structure'`)

## Luồng Gọi Món & Gửi Bếp
```
Mở bàn → chọn số khách
    → Gọi món: tìm kiếm hoặc chọn từ menu
    → Ghi chú bếp từng món (tùy chọn)
    → Nhấn "Gửi bếp" → phiếu xuất hiện ngay trên màn hình bếp
    → Có thể gọi thêm món (thêm đợt mới) bất kỳ lúc nào
    → Tính tiền → chọn phương thức → thanh toán → in hoá đơn
```

## Quy Tắc Huỷ Món Sau Khi Gửi Bếp

> **Sau khi gửi bếp: không được tăng/giảm số lượng — chỉ được xoá trực tiếp.**

- **Chưa gửi bếp:** tăng/giảm/xoá tự do, không cần lý do
- **Đã gửi bếp** (`da_gui` / `dang_lam`): chỉ xoá, **bắt buộc chọn lý do** (Khách đổi ý / Nhân viên nhập nhầm / Hết món / Khác)
- **Bếp đã xong** (`xong`): **không cho xoá** — hiện cảnh báo màu vàng
- Khi xoá: bếp tự nhận thông báo huỷ qua banner đỏ "THÔNG BÁO SỬA ĐƠN"
- Nhân viên **dùng bộ đàm** báo bếp dừng làm — không dựa hoàn toàn vào app

## Audit Trail — Lịch Sử Huỷ Món
Mọi lần huỷ món đã gửi bếp đều được ghi vào `ban_session_void_logs`:
- Tên món, tên bàn, số lượng cũ/mới
- Lý do huỷ
- Tên nhân viên thực hiện
- Thời điểm

Chủ quán có thể xem lại để kiểm soát gian lận.

## In Hoá Đơn
- Sau thanh toán: nhấn **"In hoá đơn"** → xem trước PDF 80mm → in qua máy in nhiệt Bluetooth/WiFi hoặc chia sẻ
- Hoá đơn gồm: tên quán, SĐT, địa chỉ, danh sách món, tổng tiền, lời cuối (cài trong Settings)

## Kết Nối Module Khác
- **→ Bếp:** Gửi bếp → phiếu xuất hiện ngay trên màn hình bếp (realtime)
- **→ Bếp:** Huỷ món → banner thông báo trên màn hình bếp
- **→ Thu Chi:** Thanh toán xong → tự ghi bản ghi doanh thu (is_auto=true)
- **→ Kho CN:** Bán món → tự trừ nguyên liệu theo công thức

## Câu Hỏi Thường Gặp
- *"Thêm bàn mới / Thêm khu vực mới?"* → Cần có vai trò **Chủ quán / Quản lý** hoặc nhân viên có quyền `'ban.manage_structure'` (được phân quyền động). Vào tab Bàn → nhấn "+" ở góc dưới bên phải.
- *"Thanh toán hoá đơn bàn?"* → Cần có vai trò **Chủ quán / Quản lý** hoặc nhân viên được phân quyền `'pos.checkout'` (ví dụ: Thu ngân). Phục vụ thông thường không được phép thanh toán trừ khi được cấp quyền này.
- *"Truy vết ai gọi món?"* → Tên nhân viên gọi món được tự động lưu vào hệ thống (`added_by`) và hiển thị trên Sơ đồ bàn, Sidebar chi tiết, hóa đơn tạm tính và góc trên cùng của phiếu bếp để dễ dàng kiểm tra.
- *"Chuyển khách sang bàn khác?"* → Giữ lâu vào thẻ bàn → Chuyển bàn → chọn bàn đích
- *"Gọi thêm món cho bàn đang có khách?"* → Mở bàn → thêm món → gửi bếp lần 2 (đợt 2)
- *"Huỷ món đã gửi bếp?"* → Nhấn 🗑️ vào món → chọn lý do → xác nhận → nhớ báo bếp qua bộ đàm
- *"Xem lịch sử huỷ món?"* → Hiện chưa có UI — dữ liệu lưu trong `ban_session_void_logs` trên Supabase
- *"Bếp không nhận được thông báo huỷ?"* → Kiểm tra bếp có đang mở app không + kết nối internet
