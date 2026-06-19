# Quán Nhỏ POS — Tổng Quan Dự Án

> 📌 Đọc file này để hiểu nhanh toàn bộ dự án.

## Thông tin cơ bản
- **Tên app**: Quán Nhỏ POS
- **Package**: `quannho_pos`
- **Mô tả**: App quản lý cửa hàng/quán xá nhỏ dành cho mobile & desktop
- **Nền tảng**: Android, iOS, Windows (đang thêm Mac)
- **Version**: 1.0.0+1

## Tầm Nhìn & Mục Tiêu
- **Ngắn hạn**: Test áp dụng tại quán của chính chủ (quán vừa nước vừa đồ ăn)
- **Dài hạn**: Thương mại hoá — phục vụ mọi loại quán xá nhỏ
- **Triết lý cốt lõi**: **Module hoá** — mỗi quán tự ghép hệ thống phù hợp với mình
  - Tạp hoá, cafe, trà sữa, quán ăn, phòng trọ, sân cầu lông, pickleball... đều dùng được
  - Mỗi tính năng (kho, báo cáo, bàn...) có thể bật/tắt theo nhu cầu

## Brand Identity
- **Màu Navy**: `#1C2151` — màu chủ đạo
- **Màu Cam**: `#FF6B35` — accent/action
- **Màu Kem**: `#FFF8F0` — background
- **Font**: Outfit (Google Fonts)
- **Mascot**: **Bum** 🐘 — AI assistant (đang xây dựng)

## Công Nghệ Sử Dụng
| | |
|---|---|
| Nền tảng | Flutter (Dart SDK ^3.11.5) |
| Quản lý trạng thái | Riverpod 3 (`flutter_riverpod`) |
| Cơ sở dữ liệu local | Drift + SQLite |
| Backup đám mây | Google Drive (sync khi có mạng) |
| Hiệu ứng động | `flutter_animate` |
| Âm thanh | `audioplayers` |
| Đa ngôn ngữ | `intl` |

> **Kiến trúc data**: Offline-first — SQLite là nguồn chính, Google Drive làm cầu nối backup khi online.

## Thư mục dự án
```
/Users/banhbao/Quan Nho/quan_nho/
```

## Điều Hướng
- **Thanh dưới**: 4 ô tuỳ chỉnh (giữ lâu để đổi)
- **Nút Bum**: Nút tròn giữa thanh dưới, trợ lý AI (đang xây dựng)
- **Luồng khởi động**: Splash → Giới thiệu → Màn hình PIN → Màn chính

## 9 Màn Hình Chính
| Số thứ tự | Tab | Màn hình |
|---|---|---|
| 0 | Trang chủ | Bảng điều khiển |
| 1 | Bán hàng | Màn hình bán hàng (POS) |
| 2 | Kho | Quản lý kho |
| 3 | Thu Chi | Tài chính |
| 4 | Điểm | Tích điểm khách hàng |
| 5 | Báo cáo | Thống kê doanh thu |
| 6 | Cài đặt | Cài đặt ứng dụng |
| 7 | Bàn | Sơ đồ bàn |
| 8 | Bếp | Màn hình bếp (Kanban) |

## Ưu Tiên Phát Triển Hiện Tại
1. **Menu/POS** — grid ảnh chia nhóm (Nước / Mì cay / Ăn vặt...)
2. **Bàn** — sơ đồ kéo thả + chia khu vực (trong/ngoài, tầng...)
3. **Bếp** — Kanban (Chờ → Đang làm → Xong) + âm thanh + đếm thời gian
4. **Kho** — 2 chế độ (cơ bản và chuyên nghiệp)
5. **Báo cáo** — widget bật/tắt theo nhu cầu

## Chi Tiết Nghiệp Vụ Quan Trọng

### Luồng Order
- Nhân viên order qua app (tablet/điện thoại)
- Khách tự order qua QR code
- → Đồng bộ real-time đến màn hình bếp

### Thanh Toán
- Tiền mặt, chuyển khoản QR, Momo, VNPay, thẻ ngân hàng

### Kho — 2 Chế Độ
- **Cơ bản**: Nhập/xuất thủ công, xem tồn kho (cho quán nhỏ quản lý theo cảm quan)
- **Chuyên nghiệp**: Định lượng công thức + tự trừ kho theo bán + cảnh báo hết hàng

### Báo Cáo — Tuỳ Chỉnh Widget
- Doanh thu theo ngày/tuần/tháng
- Món bán chạy / chậm nhất
- Giờ cao điểm
- User tự bật/tắt từng loại báo cáo

### Phân Quyền Nhân Viên
- Tuỳ chỉnh hoàn toàn: chủ quán tự tạo role và gán quyền

### Onboarding
- Setup: Tên quán → Logo → Danh mục → Sơ đồ bàn → Chọn modules → Tài khoản nhân viên
- Cho phép skip bước không cần thiết

### Bum AI — Tầm Nhìn
- Phân tích doanh thu, gợi ý kinh doanh
- Trả lời câu hỏi nhanh (hôm nay bán bao nhiêu, món nào chạy...)
- Cảnh báo tự động khi kho sắp hết
- (Đang xây dựng — coming soon)

## Tài Nguyên (Assets)
```
assets/
├── icons/        ← Biểu tượng
├── images/       ← Hình ảnh
├── sounds/       ← Âm thanh thông báo
├── lottie/       ← Hoạt ảnh Lottie
├── i18n/         ← File đa ngôn ngữ
└── branding/     ← Logo (logo_head.png, app_icon.png)
```

## Nghiệp Vụ Nâng Cao

### Order & Bàn
- **Gọi thêm món**: Thêm vào bill cũ HOẶC tách bill mới, tuỳ tình huống
- **Huỷ món**: Bếp xác nhận + nhân viên ghi lý do huỷ (chống gian lận)
- **Chuyển bàn**: Kéo toàn bộ order sang bàn mới
- **Ghép bàn**: 2 nhóm khách → 1 bill chung
- **Tách bàn**: 1 nhóm → tách trả tiền riêng

### Thanh Toán & Checkout
- Màn hình checkout: danh sách món + giá + thuế + giảm giá + tổng + tiền thừa
- **Giảm giá**: Thủ công (% hoặc số tiền) + voucher/mã + happy hour tự động theo giờ
- **Phương thức**: Tiền mặt, QR chuyển khoản, Momo, VNPay, thẻ ngân hàng
- **Bill**: In bill khách + phiếu bếp (optional) + bill tạm xem trước

### Lịch Sử & Audit
- Xem lại bill đã thanh toán theo ngày/bàn/nhân viên
- Trace huỷ món, giảm giá, chỉnh sửa — biết ai làm gì lúc nào

### Ca Làm Việc
- Mở ca: nhập tiền đầu ca
- Đóng ca: báo cáo cuối ca
- Theo dõi doanh thu từng nhân viên theo ca

### Quản Lý Menu
- Thêm/sửa/xoá món + ảnh + giá
- Công thức nguyên liệu liên kết kho
- Combo / set meal
- Ẩn/hiện món theo mùa hoặc hết hàng

### Khuyến Mãi
- Giảm giá thủ công, voucher, happy hour

## Timeline
- **Mục tiêu test thực tế tại quán**: 1–3 tháng tới
- **Trạng thái hiện tại**: Module Bàn + Bếp vừa xong, đang test

---
*Cập nhật: 2026-04-22 — sau 30 câu Q&A*
