---
module: kitchen
ten: Bếp
phien_ban: 1.0.5+20
cap_nhat: 2026-10-31
nguon:
  - lib/screens/kitchen_screen.dart
  - lib/core/repositories/kitchen_repository.dart (lọc phiếu, trạng thái, dọn phiếu, thông báo huỷ)
  - supabase/migrations/20260912_atomic_send_kitchen_ticket_v2.sql (station_code lấy từ products)
  - test/screens/kitchen_sound_policy_test.dart
---

# Bếp

> Màn hình phiếu bếp (KDS) cho bếp và quầy pha chế: nhận phiếu theo thời gian thực, đánh dấu từng món xong, nhận thông báo huỷ/sửa món, chuông báo phiếu mới và phiếu trễ.

## Ai dùng được
- Người có module **Bếp** (mặc định **tắt**, Chủ quán bật ở mục "Chức năng" trên Trang chủ). Quán mới tạo, trong các vai trò có sẵn chỉ **Bếp** có module này (Thu ngân, Nhân viên thì không); Chủ quán thêm module cho vai trò bất kỳ ở **Nhân viên → Vai trò**.
- **Chuông báo chỉ kêu trên máy đăng nhập bằng vai trò có chữ "Bếp" trong tên** (vd Bếp, Bếp chính, Phụ bếp, Bếp bar). Vai trò đặt tên **"Pha chế"** (không có chữ "Bếp") sẽ **không** kêu — đổi tên vai trò thành vd "Bếp pha chế". Máy Chủ quán, Quản lý, Thu ngân, Phục vụ mở màn Bếp cũng không kêu.

## Phiếu đến từ đâu
| Nơi gửi | Khi nào |
|---|---|
| **Quản lý Bàn** | Bấm "Gửi bếp (N)" — mỗi lần là một **đợt** |
| **QR Gọi Món** | Nhân viên bấm "DUYỆT & GỬI BẾP" / "ĐÃ THU TIỀN & GỬI BẾP" |
| **Bán hàng (điện thoại)** | Bấm nút "Bếp" trên thanh giỏ hàng — phiếu ghi "Mang di" (không dấu) |

> Nếu máy tính bảng / PC không thấy nút "Bếp" ở màn Bán hàng, phiếu bếp chỉ in ra giấy khi thanh toán; muốn phiếu lên màn Bếp hãy gọi món qua Quản lý Bàn.

## Màn hình gồm những gì
- Tiêu đề **"🔥 BẾP" / "Phiếu bếp"**, nút **"Thống kê hôm nay"** và nút **"Tắt tiếng" / "Bật tiếng"** chuông.
- **Lọc trạm**: **"Tất cả"**, **"Bếp nóng"**, **"Bếp nước"**.
- **Máy tính bảng / PC**: ba cột **"Chờ xử lý"**, **"Đang làm"**, **"Hoàn thành"**.
- **Điện thoại**: ba tab **"Chờ"**, **"Đang làm"**, **"Xong"**.
- **Thẻ phiếu**: tên bàn (hoặc "Mang di" với đơn gửi từ Bán hàng), **"Đợt N"**, số món còn lại, đồng hồ chờ, nhãn **"MỚI"** / **"LÀM"** / **"TRỄ 30P!"**, danh sách món kèm số lượng, topping, ghi chú (📌), và nút **"In phiếu"**.

## Các việc thường làm

### 1. Nhận và làm phiếu
1. Phiếu mới hiện ở cột/tab **Chờ**, chuông kêu (máy vai trò Bếp).
2. Bấm **"Bắt đầu làm"** → phiếu sang **Đang làm**. Phục vụ thấy món chuyển "Đang làm".
3. Làm xong từng món: **chạm vòng tròn** bên trái món để đánh dấu món xong (chạm lại để bỏ). Xong hết món → phiếu tự sang Hoàn thành.
4. Hoặc bấm **"Xong"** để đánh dấu cả phiếu xong.
5. Phục vụ/thu ngân nhận thông báo "<bàn>: Món ăn đã sẵn sàng!" và món hiện **"Bếp xong"** ở Quản lý Bàn.

### 2. Mở lại, dọn phiếu
- Phiếu Hoàn thành làm thiếu/sai: **"Mở lại"** → về Đang làm ("↩ Đã mở lại phiếu …").
- **"Dọn phiếu"**: ẩn phiếu Hoàn thành khỏi màn hình ("🧹 Đã dọn phiếu …"). Không dọn thì phiếu Hoàn thành tự ẩn sau **15 phút**, hoặc khi bàn đã thanh toán.

### 3. Ghi chú nội bộ cho món
- Chạm vào món → **"Ghi chú nội bộ bếp (không hiển thị cho khách)"** → nhập (vd "làm chín kỹ, không cay") → **"Lưu ghi chú"**.

### 4. In phiếu
- Bấm **"In phiếu"** / **"In"** trên thẻ để in phiếu bếp ra máy in bếp (theo cài đặt In Hoá Đơn).

### 5. Lọc theo trạm
- Chọn **"Bếp nóng"** hoặc **"Bếp nước"** để mỗi màn hình chỉ thấy món của trạm mình; trạng thái phiếu tính theo món của trạm đó.
- Món cài **"Bộ phận chế biến" = Bếp Bar** ở Kho hàng luôn vào **Bếp nước**. Món để mặc định Bếp nóng thì màn Bếp **đoán theo tên** (trà, cà phê, sữa, sinh tố, nước, kem, soda, cam… → Bếp nước; còn lại → Bếp nóng). Đồ uống tên lạ bị vào Bếp nóng → sửa "Bộ phận chế biến" thành Bếp Bar. Món thêm nhanh bằng dấu + ở Bán hàng luôn vào **Bếp nóng**.

### 6. Thông báo huỷ / sửa món
Chỉ món **đã gửi bếp** mới báo bếp; huỷ trước khi gửi thì bếp không thấy gì.
- **Huỷ cả phiếu** (huỷ bàn, hoặc thu ngân bấm "Huỷ phiếu bếp" ở Bán hàng): đầu màn hiện **thẻ đỏ "ĐÃ HUỶ"** (tên bàn/khu, "Huỷ lúc HH:mm", các món bị gạch ngang) trong **15 phút**. Bấm **"Đã xem"** để ẩn thẻ trên máy này. Phiếu huỷ không còn rơi vào cột "Hoàn thành".
- **Huỷ một món** trong phiếu còn món khác: món đó bị **gạch ngang**, có nhãn đỏ **"HUỶ"**, không bấm xong được — đừng làm món này.
- Đầu màn còn dải **"THÔNG BÁO SỬA ĐƠN"** cho món bị huỷ / giảm trên phiếu đang hiện (bàn, món, số lượng, lý do, "Duyệt: <tên>"). Bấm **"Đã hiểu ✓"** hoặc chờ 30 giây để ẩn.
- In lại phiếu thì món đã huỷ không in ra.

### 7. Phiếu trễ
- Phiếu chờ/đang làm quá **30 phút**: nhãn **"TRỄ 30P!"** và chuông báo động (máy vai trò Bếp).

### 8. Thống kê hôm nay
- Nút **"Thống kê hôm nay"** → **"Bếp hôm nay"**: Phiếu hôm nay, Đang xử lý, Đã hoàn thành, Huỷ bàn/bill, **TB thời gian chờ**, **Nhanh nhất**, **Chậm nhất**, **Tỷ lệ hoàn thành**.

## Lỗi thường gặp
| Thấy gì | Vì sao | Làm gì |
|---|---|---|
| "Gián đoạn kết nối máy chủ Bếp" | Mất mạng / máy chủ chập chờn | Chờ tự kết nối lại hoặc bấm **"Thử kết nối lại ngay"** |
| Không nghe chuông | Vai trò của máy không có chữ "Bếp" trong tên (vd "Pha chế"), đang "Tắt tiếng", hoặc âm lượng thiết bị nhỏ | Đăng nhập tài khoản vai trò có chữ "Bếp" (hoặc đổi tên vai trò); bật tiếng |
| Món nằm sai trạm (vd món tráng miệng có chữ "kem" vào Bếp nước) | Màn Bếp đoán trạm theo tên món | Tạm thời dùng "Tất cả"; xem Ghi chú cho Chủ Quán |
| Đơn bán ở quầy PC không lên màn Bếp | Màn Bán hàng trên máy đó không có nút "Bếp", thanh toán chỉ in phiếu giấy | Dùng phiếu giấy, hoặc gọi món qua Quản lý Bàn |
| Phiếu cũ biến mất | Phiếu gửi hơn 4 giờ trước không còn hiện | Kiểm tra lại ở Quản lý Bàn |
| "Bếp đang yên tĩnh" | Chưa có phiếu | — |

## Liên quan module khác
- **Quản lý Bàn / QR Gọi Món / Bán hàng**: gửi phiếu; nhận trạng thái "Đang làm", "Bếp xong".
- **In Hoá Đơn**: in phiếu bếp nóng / bếp bar, tem ly.
- **Kho hàng**: "Bộ phận chế biến" của món.

## Ghi chú cho Chủ Quán (không đưa cho khách)

### Khác biệt với bản app cũ (cho Chủ Quán)
- App cũ không dùng "Bộ phận chế biến" = Bếp Bar để xếp món vào Bếp nước — mọi món đều đoán theo tên.

1. **[ĐÃ SỬA trong app 23/10 — chưa phát hành]** Lỗi cũ — **Lọc trạm không dùng "Bộ phận chế biến" của món**: phiếu lưu `station_code` từ `products` (`bep_nong`, `bep_bar`, `thu_ngan`), nhưng `_classifyStation` ở `kitchen_screen.dart` chỉ nhận `nong` / `nuoc` → mọi món (trừ món lưu `nong`, xem ghi chú 8) đều rơi vào đoán theo tên (từ khoá "kem", "cam", "nước"…). Món "Bánh flan kem" vào Bếp nước, "Cơm cam" cũng vậy. Nay `_classifyStation`: mã chuẩn hoá = bar (bep_bar/bar/nuoc) → Bếp nước; `nong` (POS gán theo danh mục) → Bếp nóng; còn lại (gồm `bep_nong` — mặc định của món mới) vẫn đoán theo tên, để quán chưa cài bộ phận cho đồ uống không bị dồn sang Bếp nóng (QC 23/10). Muốn theo hẳn "Bộ phận chế biến" thì quán phải cài Bar cho đồ uống trước. Production 23/10: phiếu bếp lưu bep_nong 17.055, bep_bar 10.729, nong 62.
2. **Phiếu gửi hơn 4 giờ** không còn được tải (`_fetchActiveTickets` lọc `sent_at` 4 giờ) — phiếu bị quên quá lâu sẽ biến mất khỏi màn Bếp dù chưa làm.
3. **Thanh toán quầy PC không tạo phiếu trên màn Bếp** (chỉ in giấy) — quán chỉ dùng màn hình bếp sẽ không thấy các đơn này. Theo code: `_PosKitchenSendBtn` chỉ có trong `_buildCartBar` (bố cục điện thoại), bố cục rộng dùng `_CartPanel(isPanel:true)`. Chủ Quán (22/10) nói PC vẫn gửi bếp được — [cần xác nhận bằng ảnh chụp màn hình Bán hàng trên PC khi giỏ có món] (đồng bộ với Ghi chú 3 bài Bán hàng). Bài cho khách chỉ giữ câu trung tính "nếu không thấy nút Bếp…".
4. Chuông chỉ theo vai trò Bếp (`shouldPlayKitchenSoundsForRole`): quán nhỏ để thu ngân kiêm xem bếp sẽ không nghe chuông.
5. **[ĐÃ SỬA 23/10 — chưa phát hành]** Thông báo lỗi kết nối bỏ mã "502 Bad Gateway": nay "Mất kết nối tới máy chủ. Kiểm tra mạng rồi bấm thử lại." (màn này không tự thử lại).
6. Chuông: `shouldPlayKitchenSoundsForRole` = `canonicalRole(role)=="kitchen"`; `canonicalRole` chỉ nhận bếp/bep/chef/cook/kitchen → vai trò "Pha chế" không kêu (bài cũ ghi nhầm "gồm Pha chế").
7. Phiếu từ POS điện thoại ghi tên bàn "Mang di" (không dấu, `pos_screen.dart`).
8. Món thêm nhanh ở POS (dấu +) lưu `station_code='nong'` (`core_product_repository.dart` ~215) nên `_classifyStation` trả thẳng `nong` — luôn vào Bếp nóng, không đoán theo tên. Món sửa ở Kho hàng lưu `bep_nong`/`bep_bar`/`thu_ngan` → rơi vào đoán theo tên.
9. Vai trò mặc định quán mới (`seedDefaults`): chỉ "Bếp" `["kitchen","ban"]` có `kitchen`; Thu ngân `["pos","ban","report"]`, Nhân viên `["ban"]` không có (bài cũ ghi "Phục vụ, Thu ngân có sẵn").
