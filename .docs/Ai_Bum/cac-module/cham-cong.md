# 🖐️ Module: Chấm Công

**Trạng thái:** ✅ Hoàn thành
**Cập nhật:** 29/04/2026

---

## Mục Đích
Theo dõi giờ làm việc của nhân viên với xác minh ảnh và GPS.

## Hai Góc Nhìn

### Phía Nhân Viên (Staff View)
- Bấm **VÀO CA** khi bắt đầu làm
- Bấm **RA CA** khi kết thúc
- Tự động chụp selfie để xác minh danh tính
- Tự động ghi GPS (vị trí chấm công)
- Xem lịch sử ca làm của bản thân

### Phía Chủ Quán / Quản Lý (Manager View)
- Xem tất cả ca làm của mọi nhân viên
- Lọc: Hôm nay / Tuần này / Tháng này
- Section "Đang làm ca" với badge LIVE (biết ai đang ở quán)
- Phân nhóm theo từng nhân viên (có thể mở/đóng nhóm)
- Tổng giờ làm của từng người trong kỳ

## Lưu Ý Kỹ Thuật
- Mặc định **TẮT** — chủ quán bật trong Cài đặt module
- Ảnh selfie: lưu Google Drive (fallback: Supabase Storage)
- Timestamp: UTC → hiển thị theo local timezone

## Câu Hỏi Thường Gặp
- *"Chấm công không cho chụp ảnh?"* → Vào Cài đặt điện thoại → Ứng dụng → cấp quyền Camera
- *"Không bấm Ra ca thì sao?"* → Ca ở trạng thái "mở", chủ quán thấy LIVE — cần bấm Ra ca thủ công
- *"Xem ảnh selfie chấm công?"* → Nhấn vào ca làm → xem chi tiết → có ảnh selfie
- *"Tính lương theo giờ?"* → Chức năng tính lương đang phát triển
