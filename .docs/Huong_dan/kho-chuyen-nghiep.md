---
module: kho_pro
ten: Kho Chuyên Nghiệp
phien_ban: 1.0.5+20
cap_nhat: 2026-10-23
nguon:
  - lib/modules/kho_chuyen_nghiep/screens/*.dart (kho_chuyen_nghiep_screen, dashboard, ingredient_list, recipe_list/detail/form, production_order, stock_count, stock_waste, report)
  - lib/modules/kho_chuyen_nghiep/repository/kho_chuyen_nghiep_repository.dart
  - supabase/migrations/20261008_fix09_quy_doi_don_vi_cong_thuc.sql (trừ kho theo công thức khi bán), 20261008_fix10_kiem_ke_hao_hut.sql, 20261010_fix11_lenh_san_xuat_cong_thanh_pham.sql
  - nhat_ky.md 08–10/10/2026 (kiểm kê, hao hụt, lệnh sản xuất, ví dụ cốt trà đen)
---

# Kho Chuyên Nghiệp

> Công thức món (định lượng nguyên liệu), tự trừ nguyên liệu khi bán, pha chế/sơ chế bán thành phẩm (cốt trà, nước dùng…), kiểm kê, ghi hao hụt và theo dõi giá vốn (food cost).

Dùng **cùng danh sách hàng** với module Kho hàng: nguyên liệu và món tạo ở Kho hàng; Kho Chuyên Nghiệp thêm phần công thức và sản xuất.

## Ai dùng được
- Người có module **Kho Chuyên Nghiệp** (mặc định **tắt**, Chủ quán bật trong Modules). Quán mới tạo, các vai trò có sẵn (Thu ngân, Nhân viên, Bếp) đều **chưa** có module này; Chủ quán thêm module cho vai trò bất kỳ ở **Nhân viên → Vai trò** (mẫu gợi ý "Kho hàng" khi tạo vai trò mới có sẵn Kho Chuyên Nghiệp).

## Màn hình gồm những gì
Tiêu đề **"Kho Chuyên Nghiệp"**, hai nút trên đầu: **"Kiểm kê kho"** và **"Ghi hao hụt"**. Năm tab:
- **"Tổng quan"** — số công thức, "SX hôm nay", số nguyên liệu, "Sắp hết kho"; **"Lệnh sản xuất hôm nay"** (+ "Tạo lệnh sản xuất hôm nay"), **"Cần nhập hàng"**, **"Công thức gần đây"**.
- **"Nguyên liệu"** — nguyên liệu và bán thành phẩm, kèm tồn.
- **"Công thức"** — mỗi công thức hiện số nguyên liệu, khẩu phần, **Giá vốn**, **Giá bán**, **Lãi gộp**, **Food cost %**, và nhãn **"Đã gắn menu POS — Tự trừ kho khi bán"** nếu đã gắn.
- **"Sản xuất"** — lệnh sản xuất theo ngày, lọc Tất cả / Chờ / Đang làm / Hoàn thành / Đã hủy.
- **"Báo cáo"** — chọn **Từ → Đến**: tổng giá vốn, trung bình/ngày, chi phí theo ngày, nguyên liệu tiêu thụ nhiều, thống kê lệnh sản xuất.

## Các việc thường làm

### 1. Chuẩn bị nguyên liệu (ở Kho hàng)
1. Kho hàng → **"Thêm sản phẩm"**, danh mục **"Nguyên liệu"**, đơn vị theo cách mua (gói, lon, kg…), giá vốn.
2. Nguyên liệu mua theo gói/lon nhưng công thức dùng g/ml: khai **"Quy cách pha chế"** (vd 1 gói = 500 g). Nếu thiếu, form công thức sẽ cảnh báo lệch đơn vị và giá vốn có thể sai.

### 2. Tạo công thức món
Muốn mỗi ly / phần bán ra tự trừ nguyên liệu (cà phê, sữa, thịt…) trong kho: tạo công thức cho món và gắn với món bán.
1. Tab **"Công thức"** → **"Tạo công thức"**.
2. **"Thông tin món"**: **"Tên món *"**, mô tả, danh mục (Món chính, Khai vị, Tráng miệng, Đồ uống, Súp & Cháo, Khác), **khẩu phần** (số + đơn vị: phần, tô, đĩa, ly, g, kg, ml, lít).
3. **"Gắn menu POS"** → **"Chọn sản phẩm bán hàng tương ứng"**. Gắn rồi app ghi "Khi bán "<món>" → tự động trừ kho".
4. **"Định lượng nguyên liệu"** → **"Thêm nguyên liệu"**: chọn nguyên liệu, **"Số lượng"**, **"Đơn vị"** (gram, kg, ml, lít, hộp, lon, chai, gói, chiếc, cái, muỗng, chén, phần, ly). App tính "= <chi phí>" từng dòng.
5. **"Hao phí sơ chế"** (%): phần mất khi rửa, lặt, cắt gọt. Ví dụ công thức cần 200 g rau, hao phí 20% → kho trừ 200 ÷ 0,8 = 250 g. Bấm **"Hao phí sơ chế là gì?"** để xem bảng gợi ý (rau 15–25%, thịt 10–20%, tôm 35–45%…).
6. Xem **"Giá vốn/phần"** → **"Lưu công thức"** (hoặc **"LƯU"** góc trên).

> Mỗi lần **thanh toán** món đã gắn công thức (Bán hàng, Bàn, QR mang đi), máy chủ tự trừ từng nguyên liệu theo định lượng, có quy đổi đơn vị và hao phí. Gửi bếp chưa trừ.

### 3. Bán thành phẩm: pha cốt, nấu nước dùng (lệnh sản xuất)
Ví dụ minh hoạ: nguyên liệu **Trà đen khô** (gói, 1 gói = 500 g) → pha **"Cốt trà"** (bán thành phẩm, ml): 1 mẻ = 10 lít từ 500 g trà. Món Trà chanh dùng 200 ml cốt.
1. Kho hàng: tạo "Cốt trà", danh mục **Nguyên liệu**, đơn vị ml.
2. Công thức "Cốt trà": khẩu phần **10 lít**, nguyên liệu 500 g trà, **gắn** với sản phẩm "Cốt trà". Form báo: "Hoàn thành lệnh sản xuất 1 mẻ → nhập 10000 ml "Cốt trà" vào kho."
3. Công thức món Trà chanh: dùng **200 ml Cốt trà** thay vì trà khô.
4. Mỗi lần pha: tab **"Sản xuất"** → **"Tạo lệnh SX"** → chọn **"Công thức *"**, số mẻ → xem "Tổng giá vốn ước tính" → **"Tạo lệnh sản xuất"**.
5. Bấm **"Bắt đầu"**, pha xong bấm **"Hoàn thành"**. Hệ thống trừ trà, **cộng cốt vào kho** và cập nhật giá vốn của cốt (vd "Đã nhập 10000 ml Cốt trà vào kho" — tên hiện đúng như tên sản phẩm đã đặt).
6. Thiếu nguyên liệu: hỏi **"⚠️ Thiếu nguyên liệu"** → **"Vẫn hoàn thành"** hoặc **"Huỷ"**.
7. **"Hủy lệnh"**: lệnh chuyển "Đã hủy", **kho không đổi**.

> Bấm "Hoàn thành" nhiều lần không trừ/cộng thêm. Mọi bước chạy trong một giao dịch ở máy chủ: lỗi giữa chừng thì không thay đổi gì.

### 4. Kiểm kê kho
1. Nút **"Kiểm kê kho"** → màn **"Kiểm kê kho"**. Lọc **Tất cả / Nguyên liệu / Hàng bán**, ô **"Tìm mặt hàng..."**.
2. Mỗi mặt hàng hiện **"Sổ sách: <số>"**; nhập số đếm được vào ô **"Thực tế"**. Không cần đếm hết, mặt hàng bỏ trống được giữ nguyên.
3. Bấm **"Hoàn tất kiểm kê (N đã đếm)"** → xem danh sách lệch → **"Xác nhận"**.
4. Hệ thống áp **phần chênh lệch** lên tồn hiện tại — bán hàng xen giữa lúc đếm không bị ghi đè.

### 5. Ghi hao hụt
1. Nút **"Ghi hao hụt"** → chọn **"Mặt hàng"**.
2. Lý do: **"Đổ bỏ / hao hụt"**, **"Hết hạn"**, **"Hư hỏng"**, **"Đổ vỡ"**, **"Mất / thất thoát"**.
3. **"Số lượng hao hụt"** — chọn đơn vị kho hoặc đơn vị quy cách (vd ml cho lon sữa).
4. **"Ghi chú (tuỳ chọn)"** → **"Ghi hao hụt"**. Xem lại ở **"Hao hụt gần đây"**.
5. Hao hụt chỉ trừ tồn, **không** ghi thu chi.

### 6. Xem giá vốn và lợi nhuận món
- Chạm một công thức: **"Giá vốn/phần"**, **"Tồn kho đủ nấu"** (bao nhiêu phần), bảng nguyên liệu – số lượng – chi phí, **"Food Cost Ratio"** và thanh so sánh **Giá vốn / Lãi gộp**.
- Food cost quán F&B thường nhắm 25–35% [tham khảo ngành, tuỳ mô hình quán].

## Lỗi thường gặp
| Thấy gì | Vì sao | Làm gì |
|---|---|---|
| Cảnh báo vàng lệch đơn vị trong form công thức | Đơn vị công thức (g/ml) không quy đổi được sang đơn vị kho (gói/lon) | Khai "Quy cách pha chế" cho nguyên liệu ở Kho hàng |
| Giá vốn/phần cao bất thường (gấp ~1.000 lần) | Thiếu quy cách khi kho tính gói/lon | Khai quy cách rồi mở công thức lưu lại |
| Bán món mà nguyên liệu không giảm | Công thức chưa **gắn menu POS** | Sửa công thức, chọn sản phẩm bán hàng |
| Tồn nguyên liệu âm | Bán nhiều hơn tồn, chưa nhập hàng / kiểm kê | Nhập hàng hoặc kiểm kê |
| Hoàn thành lệnh mà bán thành phẩm không tăng | Công thức không gắn sản phẩm, hoặc sản phẩm gắn không phải Nguyên liệu/Bán thành phẩm | Gắn đúng sản phẩm loại Nguyên liệu |
| "Công thức của lệnh này không còn tồn tại, không thể hoàn thành." | Công thức đã bị xoá | Hủy lệnh, tạo công thức và lệnh mới |
| "Máy chủ chưa cập nhật (FIX 11): chỉ trừ nguyên liệu, chưa cộng thành phẩm vào kho" | Máy chủ chưa được cập nhật | Báo chủ app |
| Nguyên liệu không hiện ở tab Nguyên liệu | Mặt hàng không thuộc danh mục "Nguyên liệu" (vd lon sữa bán lẻ để danh mục Đồ uống) | Kho hàng → sửa mặt hàng, đổi danh mục sang Nguyên liệu |

## Liên quan module khác
- **Kho hàng**: tạo nguyên liệu, quy cách, nhập hàng, giá nhập.
- **Bán hàng / Quản lý Bàn / QR Gọi Món**: thanh toán → trừ nguyên liệu theo công thức.
- **Quản lý Bàn**: huỷ món bếp đang làm / đã xong → trừ nguyên liệu như hao hụt (công tắc **"Trừ kho nguyên liệu (hao hụt)"** bật sẵn; người huỷ tắt đi thì kho không đổi). Món mới gửi, bếp chưa làm thì không trừ.
- **Thu Chi**: huỷ món ở trường hợp trên chỉ trừ kho, không ghi khoản nào vào Thu Chi. Nhập nhanh nguyên liệu ghi chi "Nhập nhanh: …".
- **Báo cáo**: lãi gộp theo giá vốn.

## Ghi chú cho Chủ Quán (không đưa cho khách)

### Khác biệt với bản app cũ (cho Chủ Quán)
- App cũ: huỷ món bếp đang làm / đã xong (món có công thức) ghi thêm khoản chi "Giá vốn NL" vào Thu Chi; bản mới chỉ trừ kho hao hụt.
- Trước bản 22/10/2026, huỷ món mới gửi (bếp chưa làm) vẫn có thể trừ nguyên liệu.

1. **Đơn bán vẫn ghi `order_items.cost_price` bằng giá của chính món** chứ không phải giá vốn theo công thức (nhật ký 10/10, cần migration riêng) → báo cáo lãi gộp theo đơn có thể lệch.
2. **[ĐÃ SỬA trong app 23/10 — chưa phát hành] Huỷ món có công thức ở Quản lý Bàn ghi một khoản chi "Giá vốn NL"** vào Thu Chi trong khi nguyên liệu đã ghi chi lúc nhập hàng → trừ lợi nhuận hai lần. Nay `deductIngredients` chỉ trừ kho + ghi `stock_movements`. Dữ liệu cũ: 64 phiếu (5.486.170đ) gạch bỏ trên production 23/10 08:52; sau kiểm toán đã khôi phục 6 phiếu của 3 quán nhỏ (lệnh sản xuất, nguyên liệu tồn đầu chưa ghi chi) lúc 09:14 — chỉ còn 58 phiếu của Kay gạch bỏ (xem Ghi chú 4 bài Thu Chi).
3. Tên "FIX 11" bị dùng cho **hai** migration khác nhau (thu hồi quyền anon bill đã hoàn tác, và lệnh sản xuất đã áp) — dễ nhầm khi đọc nhật ký/thông báo lỗi.
4. Kiểm kê và hao hụt **không ghi thu chi** — giá trị hàng hỏng/thất thoát không hiện trong lợi nhuận Thu Chi; chỉ thấy ở tồn kho.
5. Tab Nguyên liệu chỉ hiện `product_type` = `ingredient` / `semi_finished`, ẩn `finished` và `purchased`. Form Kho hàng đặt loại theo danh mục: "Nguyên liệu" → `ingredient`, còn lại → `finished` (`inventory_screen.dart` ~1145). Vai trò mặc định quán mới (`seedDefaults`) không có `kho_pro`.
6. Ví dụ ở mục 3 đã đổi sang số liệu minh hoạ chung; dữ liệu thật (cốt trà đen của quán Bò Đen, 16 lít / 1.000 g, Trà Tắc 550 ml) xem nhật ký 08–10/10. "Giá vốn NL" (app cũ, trước 23/10) ghi khi `deductAsLoss` = true (`ban_screen.dart`); lỗi cũ: món `da_gui` bị ẩn công tắc nhưng vẫn true — ĐÃ SỬA trong app 22/10 (xem Ghi chú 9 bài Quản lý Bàn).
