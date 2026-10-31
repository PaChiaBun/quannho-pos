# 📦 Module: Kho Hàng

**Trạng thái:** ✅ Hoàn thành (v2 — cập nhật 05/05/2026)

---

## Mục Đích
Theo dõi tồn kho nguyên liệu và hàng hóa — biết còn bao nhiêu, cần nhập thêm gì.

---

## Phân Loại Sản Phẩm (product_type)

> ⚠️ **Quan trọng:** `product_type` KHÔNG hiển thị cho user. Được tự động tính dựa vào **Danh mục**.

| Danh mục chọn | product_type ghi DB | Hiển thị ở tab |
|---------------|--------------------|--------------------|
| Nguyên liệu   | `ingredient`       | Tab "Nguyên liệu"  |
| Đồ ăn / Đồ uống / Tráng miệng / Combo / Tùy chỉnh | `finished` | Tab "Hàng hoá & Menu" |

> **Lý do thiết kế:** Không tạo thêm trường "Loại sản phẩm" riêng vì gây phức tạp cho user. Dùng chip Danh mục quen thuộc để phân loại ngầm.

---

## Tabs Kho Hàng (Kho cơ bản)

```
Tất cả  |  Hàng hoá & Menu  |  Nguyên liệu  |  Cảnh báo  |  [Phiếu nhập - bật/tắt]
```

| Tab | Hiển thị |
|-----|----------|
| Tất cả | Toàn bộ sản phẩm |
| Hàng hoá & Menu | `finished` + `purchased` |
| Nguyên liệu | `ingredient` + `semi_finished` |
| Cảnh báo | SP trạng thái `low` hoặc `outOfStock` — hết hàng lên đầu |
| Phiếu nhập | Màn hình tạo phiếu nhập từ NCC (bật/tắt trong Cài đặt) |

---

## Phiếu Nhập Hàng

- **Hiện tất cả sản phẩm** trong picker — không filter theo loại
- Lý do: nhiều quán mua sẵn món ăn từ nơi khác về bán lại → cần nhập cả `finished`
- Nhà cung cấp là **tùy chọn** (không bắt buộc)

---

## Form Thêm / Sửa Sản Phẩm

**Chip Danh mục chuẩn:** Đồ ăn · Đồ uống · Tráng miệng · Combo · Nguyên liệu

**Chip tùy chỉnh:** Tap nút `+ Thêm` → nhập tên → chip màu tím xuất hiện, có thể xóa

> **Quy tắc:** Chọn "Nguyên liệu" → SP vào tab Nguyên liệu. Mọi danh mục khác → vào tab Hàng hoá & Menu.

---

## Module Kho Chuyên Nghiệp (kho_pro)

Dành cho nhà hàng lớn, chạy **song song** với Kho cơ bản:

| Tính năng | Mô tả |
|-----------|-------|
| Công thức định lượng | Gắn nguyên liệu + định lượng cho từng món |
| Lệnh sản xuất | Tạo lệnh → trừ kho nguyên liệu → cộng kho thành phẩm |
| Báo cáo food cost | % giá vốn / doanh thu theo từng món |

**Filter trong Kho CN:**
- Tab Nguyên liệu: chỉ hiện `ingredient` + `semi_finished`
- Dropdown chọn NL trong Công thức: chỉ `ingredient` + `semi_finished`

---

## Tính Năng Chính
- Xem tồn kho với màu cảnh báo (đỏ = hết, cam = sắp hết)
- Nhập hàng thủ công hoặc qua Phiếu nhập từ NCC
- Xuất hàng thủ công + lịch sử nhập/xuất
- Tab Cảnh báo gộp sắp hết + hết hàng (hết hàng ưu tiên lên đầu)

## Kết Nối Module Khác
- **← Bán hàng (POS):** Mỗi đơn bán → tự động trừ nguyên liệu (nếu bật Kho CN + cài công thức)
- **→ Thu Chi:** Nhập hàng → có thể ghi chi phí vào Thu Chi
- **↔ Kho CN:** Chạy song song — Kho CN quản lý công thức/lệnh SX, Kho cơ bản quản lý tồn kho thực tế

## Câu Hỏi Thường Gặp
- *"Tồn kho không tự trừ sau khi bán?"* → Cần bật module Kho CN + cài Công thức cho món
- *"Hàng nào sắp hết?"* → Vào tab "Cảnh báo" trong Kho
- *"Nhập hàng ở đâu?"* → Kho → tab "Phiếu nhập" (cần bật trong Cài đặt)
- *"Tại sao chọn Nguyên liệu thì vào tab riêng?"* → Giúp tách biệt nguyên liệu thô với hàng bán, tránh nhầm lẫn khi kiểm kho
