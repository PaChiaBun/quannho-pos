# Kế hoạch: Trang quản trị Quán Nhỏ (quannho.lpm.vn/admin)

Ngày lập: 25/10/2026 — Chủ Quán chốt:
- Trang web riêng tại `/admin`.
- Xem lịch sử trò chuyện với Boom **đầy đủ, kể cả số**.
- "Đang dùng tích cực" nghĩa là quán **có đơn trong 7 ngày**.
- Phần Boom gồm **xem + chấm câu trả lời**.

Chốt thêm cùng ngày:
- Giữ 4 mặc định ở mục 4.
- Danh sách quán thêm **số nhân viên** và **số món trong menu**.
- Phần AI theo dõi luôn **những gì đã dạy cho Boom**.

Chưa làm gì; mọi bước đụng production đều hỏi trước.

## 1. Trang có gì

### A. Tổng quan khách hàng (các quán)

**Thẻ số:**
- Tổng số quán.
- Quán mới: hôm nay, 7 ngày, 30 ngày.
- Đang dùng tích cực (có đơn trong 7 ngày).
- Có đơn trong 30 ngày.
- "Ngủ": không có đơn trên 30 ngày.
- Chưa từng bán đơn nào.

**Biểu đồ:**
- Quán mới theo ngày.
- Số quán tích cực theo tuần.

**Danh sách quán:**
- Cột: tên, mã, ngày tạo, gói / dùng thử (hạn), số đơn 7 ngày, ngày có đơn cuối, số thiết bị, lần mở app cuối,
  **số nhân viên** (tài khoản còn trong quán, tách chủ / quản lý / nhân viên), **số món trong menu** (món đang bán, không tính nguyên liệu và món đã xoá).
- Lọc: tích cực / ngủ / chưa bán / mới; tìm theo tên hoặc mã.

**Số thật hiện tại (đọc 25/10):**
- 180 quán, trong đó 167 tạo trong 30 ngày (nhiều quán là quán thử).
- 49 quán có đơn trong 30 ngày, 8 quán có đơn trong 7 ngày.

### B. AI Boom — xem và chấm

**Danh sách hội thoại:**
- Lọc theo quán, ngày, loại câu trả lời: hướng dẫn / tư vấn / số liệu / chuỗi / từ chối / chưa trả lời được / lỗi.
- Lọc riêng các câu chủ quán bấm 👎.

**Xem từng lượt:**
- Câu hỏi và câu trả lời **nguyên văn**.
- Boom đã dùng gì để trả lời: bài hướng dẫn nào, có đọc số không.
- Thời gian trả lời, chi phí.
- 👍/👎 kèm lý do của chủ quán.

**Anh/chị chấm:**
- Đúng / Chưa đúng / Sai.
- Ghi chú.
- Đánh dấu "cần dạy lại", để sau này Claude dùng làm hàng chờ cải thiện.

**Số đếm đơn giản:** tổng câu, % 👍/👎, % chưa trả lời được, chi phí tuần. Phần chỉ số chi tiết thì để sau.

### C. AI Boom — những gì đã dạy (chỉ xem)

**1. Bộ hướng dẫn app đã đăng:**
- Phiên bản, ngày đăng, số đoạn theo từng module (hiện 331 đoạn / 16 module).
- Bấm xem nguyên văn từng đoạn.
- Mỗi đoạn có số lần Boom dùng nó để trả lời, và số 👍/👎 của các câu trả lời đó.

**2. Bộ nhớ câu trả lời đã duyệt:**
- Câu hỏi mẫu, các cách hỏi, câu trả lời.
- Số lượt dùng, 👍/👎, trạng thái, ghi chú.
- Hiện đang trống; 7 câu đề xuất ngày 24/10 chưa áp.

**3. Luật và kiến thức nền của Boom:**
- Nguyên văn lời dặn đang chạy: phạm vi được và không được trả lời, kiến thức nghề (luật lao động, an toàn thực phẩm, định giá…), cách tư vấn số liệu.
- Kèm mã phiên bản của hàm đang chạy.
- Hàm boom-chat thêm chế độ chỉ cho admin để lấy nguyên văn này, nên luôn khớp đúng bản đang chạy.

**4. Nhật ký dạy Boom:**
- Mỗi lần áp bản mới có một dòng: ngày giờ, phiên bản, đã dạy / sửa gì, kết quả kiểm tra.
- Nhập sẵn các lần từ 23/10 đến nay, lấy từ nhật ký dự án:
  - trí nhớ 5 giờ;
  - gỡ luật quá chặt;
  - tư vấn số liệu;
  - so sánh chi nhánh;
  - đọc số 5 mục;
  - …
- Từ nay mỗi lần áp, thêm một dòng. Lưu ở bảng `boom_changelog`.

**5. Năng lực đọc số:**
- Danh sách những gì Boom đọc được (doanh thu, món, chuỗi, thu chi, kho, chấm công, khách, khuyến mãi), kèm quyền từng vai trò.
- Danh sách những gì Boom chưa đọc được.
- Để biết Boom đang "biết" tới đâu.

## 2. Cách làm (an toàn trước)

### Đăng nhập và quyền
- Dùng tài khoản Quán Nhỏ của anh/chị (số điện thoại + mật khẩu), đăng nhập qua cổng xác thực hiện có.
- Thêm bảng `platform_admins`, chỉ có tài khoản của anh/chị.
- Mọi số liệu trên trang đi qua các hàm máy chủ riêng `admin_*_v1`. Mỗi hàm kiểm tra người gọi có trong `platform_admins`; không có thì từ chối.
- Trang web **không giữ khoá quản trị máy chủ** (service key).
- Vé đăng nhập lưu trong cookie an toàn, hết hạn sau 12 giờ, đăng nhập sai nhiều lần thì bị chặn tạm.

### Lịch sử Boom đầy đủ
- Hiện sổ `boom_qa_log` không lưu câu trả lời có số liệu, vì quản lý quán đọc được sổ đó.
- Thêm bảng mới `boom_qa_full`: hàm boom-chat ghi nguyên văn câu hỏi + câu trả lời vào đây.
  - Bảng này **khoá hoàn toàn**: chỉ hàm `admin_*_v1` đọc được; chủ quán và quản lý quán không đọc được.
- Che số điện thoại, tài khoản ngân hàng trong câu hỏi như sổ hiện tại.
- Tự xoá sau 90 ngày.
- Cập nhật trang Chính sách riêng tư: câu hỏi gửi Boom có thể được đội ngũ Quán Nhỏ xem để cải thiện chất lượng.

### Số liệu quán
- Hàm `admin_store_overview_v1` / `admin_store_list_v1` chỉ trả số tổng hợp: số đơn, ngày đơn cuối, số thiết bị, số nhân viên, số món trong menu.
- **Không** trả doanh thu và **không** trả dữ liệu khách của quán.

### Web
- Thêm nhóm trang `(admin)` vào website Next.js hiện có (`/var/www/lpm-web`), không đụng app POS.
- Giao diện gọn, xem tốt trên điện thoại.
- Robots chặn index; trang không có liên kết công khai.

## 3. Các bước

1. **Máy chủ:**
   - migration `platform_admins`, `boom_qa_full`, `boom_admin_reviews` (bảng chấm của anh/chị), `boom_changelog` (nhật ký dạy Boom, nhập sẵn các lần trước);
   - các hàm `admin_*_v1` và job dọn 90 ngày;
   - test trên bản sao, có file hoàn tác (ROLLBACK).
2. **Hàm boom-chat:**
   - ghi thêm vào `boom_qa_full` (không ảnh hưởng câu trả lời nếu ghi lỗi);
   - thêm chế độ chỉ admin để xem lời dặn đang chạy;
   - test.
3. **Web `/admin`:** đăng nhập, Tổng quan quán, Danh sách quán, Boom (hội thoại, chấm, Những gì đã dạy); test.
4. **QC độc lập nhiều vòng:**
   - quyền: người không phải admin không đọc được gì;
   - rò dữ liệu;
   - đúng số so với truy vấn trực tiếp;
   - hiển thị trên điện thoại.
5. **Hỏi duyệt rồi mới áp:** migration → hàm boom-chat → web. Cập nhật chính sách riêng tư. Ghi nhật ký.

**Ước lượng:** 1–2 phiên làm việc. Thêm máy chủ: không cần; bảng mới vài MB.

## 4. Còn cần anh/chị chốt (đang để mặc định)

1. **Quán thử / quán demo:** có loại khỏi số liệu không?
   - Mặc định: có nút đánh dấu "quán thử" trên trang để loại ra.
2. **Danh sách quán có hiện doanh thu không?**
   - Mặc định: KHÔNG, chỉ số đơn.
3. **Ai được vào trang?**
   - Mặc định: chỉ tài khoản của anh/chị; sau này thêm người thì thêm vào `platform_admins`.
4. **Lưu lịch sử Boom đầy đủ bao lâu?**
   - Mặc định: 90 ngày.
5. **Lịch sử trước ngày triển khai** (các câu trả lời có số đã bị che từ 25/10) **không khôi phục được**. Trang chỉ có lịch sử đầy đủ từ lúc áp.
