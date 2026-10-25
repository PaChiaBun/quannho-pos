# Gói module gợi ý — Trà sữa mang đi

> Giai đoạn 3 của [kế hoạch](ke-hoach-trien-khai-boom.md). Viết 23/10/2026, đối chiếu code và các bài hướng dẫn hiện có.
> Tài liệu cho Chủ Quán (không đưa vào Boom). Mỗi khoảng trống ở cuối là **một đề xuất riêng** — Chủ Quán quyết làm hay không.

## Quán như thế nào
Quầy order + quầy pha, khách mua mang đi (có thể vài ghế ngồi chờ); bán theo ly, nhiều topping, chọn đường/đá, có size;
một phần đơn qua GrabFood/ShopeeFood; 2–6 nhân viên chia ca.

## Một ly trà sữa đi qua app thế nào (hiện tại)
1. **Bán hàng (quầy):** chạm món → giỏ → "Thanh toán" (tiền mặt / chuyển khoản / thẻ / ví khách). In bill, mở két.
2. **In:** bill thu ngân + **tem dán ly** (mỗi ly 1 tem, 2 ly cùng món → 1/2, 2/2).
3. **Kho:** bán xong tự trừ tồn (theo công thức nếu dùng Kho Chuyên Nghiệp); hết món → "Tắt bán".
4. **Thu Chi / Báo cáo:** tự ghi thu; xem doanh thu theo giờ, món bán chạy, lãi lỗ.

## Module nên bật

| Mức | Module | Vì sao với quán trà sữa mang đi |
|---|---|---|
| **Cần** | Bán hàng | Bán tại quầy, thanh toán, gửi pha chế |
| **Cần** | In Hoá Đơn | Bill + **tem dán ly** (đã có) |
| **Cần** | Kho hàng | Topping, tắt bán khi hết trân châu, nhập hàng, quy cách (mua hộp, trừ ml) |
| **Cần** | Thu Chi | Sổ quỹ, chi nguyên liệu, tiền điện |
| **Cần** | Báo cáo | Doanh thu theo giờ (giờ cao điểm), món bán chạy |
| **Cần** | Nhân viên, Chấm công | Ca sáng/chiều/tối, vào/ra ca có ảnh + GPS |
| Có thể cần | Khách hàng | Tích điểm, ví trả trước, voucher — hợp quán có khách quen/sinh viên |
| Có thể cần | Kho Chuyên Nghiệp | Định lượng từng ly (ml trà, g đường, ml sữa) → giá vốn/ly thật; cần người nhập công thức |
| Có thể cần | QR Gọi Món | Khách tự gọi, có **mã lấy món #Qxx** — hợp giờ đông |
| Có thể cần | Bếp | Màn pha chế khi có ≥ 2 người pha / quầy pha tách quầy thu |
| Có thể cần | Lương | Tính lương theo giờ từ chấm công |
| Có thể cần | Vận Hành | Checklist mở/đóng ca; có sẵn **bộ mẫu "Takeaway"** (quầy take-away, Grab/Shopee, bao bì) |
| Có thể cần | Nhật Ký Log | Tra sự cố in, ai huỷ đơn |
| Không cần | Quản lý Bàn | Trừ khi quán có chỗ ngồi phục vụ tại bàn |
| Không cần | Báo cáo chuỗi | Trừ khi có ≥ 2 cửa hàng |

## Khoảng trống — mỗi mục một đề xuất (chờ Chủ Quán quyết)

### Đ1. Topping và chọn đường / đá ở quầy — **quan trọng nhất**
- **Hiện tại:** topping và "Tùy chọn món" (nhóm + giá thêm) **chỉ có ở Quản lý Bàn và QR**. Màn Bán hàng (quầy) chưa có;
  quán đang bán topping như món riêng → tem/phiếu pha không biết topping đi với ly nào; đường/đá phải gõ ghi chú.
- **Đề xuất:** làm Phần B của [kế hoạch topping & giảm giá](../ke-hoach-topping-giam-gia-pos.md) + đưa "Tùy chọn món" lên quầy,
  có **nhóm bắt buộc chọn 1** (Đường: 0/30/50/70/100%, Đá: không/ít/bình thường). Tem ly in kèm lựa chọn.
- Cần sửa máy chủ (`complete_pos_sale_v1` đang tự tính lại giá, chưa nhận topping) — hỏi trước khi áp.

### Đ2. Size M / L
- **Hiện tại:** chưa có khái niệm size. Cách tạm: 2 món riêng ("Trà sữa M", "Trà sữa L") hoặc tùy chọn +giá (chỉ ở Bàn).
- **Đề xuất:** size là nhóm tùy chọn bắt buộc có giá thêm, dùng chung với Đ1; báo cáo món bán chạy gộp theo món, tách theo size khi cần.

### Đ3. Định lượng theo size / topping
- **Hiện tại:** công thức (Kho Chuyên Nghiệp) theo **món**; topping trừ kho như món riêng; đường/đá không trừ kho.
- **Đề xuất:** tùy chọn được gắn định lượng (vd "Size L" +50% công thức, "Thêm sữa" +20 ml) → giá vốn/ly đúng hơn. Làm sau Đ1–Đ2.

### Đ4. Gọi khách lấy món khi bán ở quầy
- **Hiện tại:** đơn QR mang đi có mã lấy món #Qxx; bán ở quầy chỉ có số đơn trên bill, chưa có màn hình gọi số.
- **Đề xuất:** in **số lấy món cỡ lớn** trên bill + tem ly (số ngắn theo ngày, 1–999); tuỳ chọn màn hình "Đã xong — mời số …" cho máy thứ hai.

### Đ5. Đơn GrabFood / ShopeeFood
- **Hiện tại:** app không kết nối các app giao hàng; chỉ có checklist mẫu "Takeaway". Đơn app thường được bấm như đơn quầy
  → doanh thu lẫn, không trừ chiết khấu app.
- **Đề xuất (không kết nối API, làm được ngay):** chọn **kênh bán** ở quầy (Tại quầy / Grab / Shopee / Be), mỗi kênh có thể có
  bảng giá riêng và % chiết khấu; Báo cáo + Thu Chi tách theo kênh. Kết nối API từng hãng là việc lớn, tính sau.

### Đ6. Giảm giá tay ở quầy
- **Hiện tại:** chưa có ô nhập; quyền giảm giá phía máy chủ đang tính sai cho Thu ngân/Quản lý.
- **Đề xuất:** Phần A của [kế hoạch topping & giảm giá](../ke-hoach-topping-giam-gia-pos.md) (đã viết, chờ duyệt).

## Bắt đầu nhanh cho quán mới (làm được ngay với app hiện tại)
1. Bật module theo bảng trên: trang chủ, mục Modules → **"+ Thêm module"**.
2. Kho hàng: tạo danh mục (Trà sữa, Trà trái cây, Topping…), món, topping; nguyên liệu mua theo hộp thì nhập "Quy cách pha chế".
3. In Hoá Đơn: cài máy in bill + máy in tem (chọn đúng khổ decal), thiết kế tem.
4. Nhân viên: vai trò Thu ngân / Pha chế, ca làm việc; Chấm công: cài vị trí quán.
5. Vận Hành (nếu dùng): nạp bộ mẫu "Takeaway".
6. Khách hàng (nếu dùng): gói nạp ví, voucher khai trương.
