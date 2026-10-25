# Thiết kế: đưa bill vào hàng đợi phát hành hóa đơn và trợ lý thiết lập cho chủ quán

Trạng thái: **bản thiết kế để Chủ quán duyệt, chưa viết mã**. Quyết định đã chốt (17/10/2026): dùng **cách A** (phát hành thẳng qua cổng meInvoice, MISA ký số); LPM hỗ trợ chủ quán thiết lập toàn diện; MISA bán chữ ký số và gói hóa đơn.
Liên quan: `tich-hop-misa.md`, `einvoice-ap-migration-checklist.md`, migration `20261016_einvoice_foundation_v1.sql`.

## 1. Nguyên tắc

1. Thanh toán và phát hành hóa đơn là **hai việc tách rời**. Phát hành lỗi, mất mạng hoặc MISA ngừng chạy không được làm chậm hay hủy thanh toán.
2. Không sửa `settle_ban_session_v5` và đường thanh toán bán trực tiếp. Chương trình chạy ngầm **quét** các bill đã thanh toán xong, không chen vào giao dịch thanh toán.
3. Mỗi bill chỉ có **một** hóa đơn gốc: khóa chống trùng `(store_id, provider, ref_id)` đã có trong bảng `einvoice_documents`. `ref_id` là mã duy nhất của bill (dạng GUID, đúng yêu cầu `RefID` của MISA).
4. Chỉ bill thanh toán **sau thời điểm bật công tắc** mới được xét. Không phát hành bù bill cũ.
5. Mọi bill vẫn ghi đủ doanh thu dù công tắc bật hay tắt.

## 2. Nguồn bill cần quét

| Đường bán | Bảng nguồn | `source_type` | Ghi chú |
|---|---|---|---|
| Bán theo bàn | `payment_settlements` (status `completed`) | `settlement` | Một hóa đơn cho cả phiên bàn, số tiền `total_amount` |
| Bán trực tiếp (mang đi, quầy) | `orders` (status `completed`, **không** nằm trong `ban_session_orders`) | `order` | Một hóa đơn cho mỗi đơn |

Đơn QR đã nằm trong phiên bàn thì tính theo settlement của phiên, không tạo hóa đơn thứ hai. Cần kiểm tra bằng dữ liệu thật, vì đường QR quầy (thanh toán trước khi gửi bếp) có thể đi theo đường `orders`.

## 3. Luồng chạy ngầm

1. **Quét** (mỗi 1–2 phút): với quán đang bật công tắc, tìm bill hoàn tất sau `enabled_since` chưa có dòng trong `einvoice_documents` → tạo dòng `queued`.
2. **Phát hành** (tuần tự theo từng ký hiệu, đúng yêu cầu MISA): lấy token (lưu lại, không gọi liên tục) → lấy mẫu hóa đơn máy tính tiền (ký hiệu có ký tự thứ 5 là `M`) → gửi bill → đọc kết quả bên trong dữ liệu trả về, không chỉ cờ `Success` → lưu `TransactionID`, số hóa đơn, mã cơ quan thuế.
3. **Hỏi lại trạng thái** sau 3–5 giây, tối đa 3 lần, rồi chuyển sang quét lại ở vòng sau nếu chưa rõ.
4. **Xử lý lỗi:**
   - `InvoiceDuplicated`, `InvoiceNumberNotCotinuous`: thử lại sau vài giây, giữ nguyên `ref_id`.
   - Lỗi mạng hoặc `SystemError`: thử lại tăng dần khoảng chờ, đếm `attempts`.
   - Chưa mua gói (`LicenseInfo_NotBuy`), sai ký hiệu, token hỏng: đánh dấu `failed`, **dừng gửi cho quán đó** và báo chủ quán (không thử lại vô hạn).
   - Cơ quan thuế từ chối cấp mã: trạng thái `rejected`, hiện trong báo cáo để xử lý.
5. Mỗi quán chỉ một chương trình chạy ngầm xử lý tại một thời điểm (khóa theo quán) để không gửi trùng.

Số thứ tự hóa đơn do MISA cấp, nên không gửi song song cùng ký hiệu.

## 4. Thay đổi cần có trong cơ sở dữ liệu (phiên bản 2, chưa viết)

- `einvoice_store_config`: thêm `enabled_since timestamptz` (đặt lúc bật), `provider_status` (chưa cấu hình / sẵn sàng / lỗi xác thực), `last_error`.
- Bảng thông tin kết nối theo quán, **chỉ chương trình chạy ngầm đọc được**: mã số thuế, tên đăng nhập tài khoản phụ, mật khẩu **mã hóa**, mẫu hóa đơn đã chọn. Người dùng app không có quyền đọc hay ghi trực tiếp; lưu qua hàm riêng có kiểm tra quyền Chủ quán.
- Hàm cho chương trình chạy ngầm: lấy lô bill cần xử lý, ghi kết quả.
- Công tắc **không bật được** khi `provider_status` chưa là "sẵn sàng".

## 5. Trợ lý thiết lập cho chủ quán (mục tiêu: chủ quán không rành công nghệ vẫn làm được)

Một màn hình "Hóa đơn điện tử" có các bước, mỗi bước hiện trạng thái xong/chưa, kèm hướng dẫn ngắn và nút gọi hỗ trợ:

1. **Kiểm tra hồ sơ quán:** mã số thuế của hộ kinh doanh, tên hộ, địa chỉ.
2. **Mua chữ ký số và gói hóa đơn** tại MISA (LPM hỗ trợ làm hộ qua đường giới thiệu đối tác nếu MISA cho phép).
3. **Đăng ký sử dụng hóa đơn máy tính tiền với cơ quan thuế** (LPM hướng dẫn từng bước hoặc làm hộ).
4. **Tạo tài khoản phụ** trên meInvoice cho tích hợp, rồi nhập vào app.
5. **Thử kết nối:** app lấy token và danh sách mẫu hóa đơn, báo "Kết nối thành công" hoặc lỗi dễ hiểu.
6. **Chọn mẫu hóa đơn máy tính tiền** từ danh sách MISA trả về.
7. **Bật công tắc** (đã có), từ lúc bật các bill mới được phát hành.

## 6. Giấy tờ cá nhân của chủ quán (CCCD)

Đây là dữ liệu cá nhân nhạy cảm. Đề xuất:
- Ưu tiên để **chủ quán tự tải giấy tờ trực tiếp lên trang của MISA** theo hướng dẫn của LPM. Nếu LPM phải thu hộ, dùng kênh có mã hóa, ghi lại sự đồng ý rõ ràng của chủ quán, chỉ giữ đến khi MISA nhận xong rồi xóa.
- **Không lưu ảnh CCCD** trong cơ sở dữ liệu hay nhật ký của Quán Nhỏ, và không gửi qua kênh trò chuyện thường.
- Cần xem lại điều khoản với MISA về việc LPM đứng ra thu hộ hồ sơ, và quy định bảo vệ dữ liệu cá nhân đang có hiệu lực (cần luật sư hoặc tư vấn pháp lý xác nhận, chưa kiểm chứng ở đây).

## 7. Ký hiệu hóa đơn

Ký hiệu có 7 ký tự: ký tự 1 là loại hóa đơn (1 GTGT, 2 bán hàng), ký tự 2 là `C` có mã hoặc `K` không mã (**không đổi được**, do quy định thuế), ký tự 3–4 là năm, ký tự 5 là `T` thường hoặc `M` máy tính tiền, ký tự 6–7 do người bán tự đặt (tài liệu MISA ghi `YY`, ví dụ `AA`, `AD`). Muốn gắn nhãn "QN" thì đặt ở **hai ký tự cuối**, ví dụ `2C26MQN`. Cần MISA xác nhận hai ký tự cuối của mẫu hóa đơn máy tính tiền có tự chọn được không.

## 8. Việc cần xác nhận với MISA trước khi viết mã

1. Hóa đơn máy tính tiền của hộ kinh doanh qua cách A có cần chữ ký số riêng của quán, hay MISA ký sau (loại ký số 5)?
2. Hóa đơn bán hàng của hộ kinh doanh có phải tách thuế không?
3. Hủy, thay thế, điều chỉnh hóa đơn đã cấp mã.
4. Môi trường thử, giới hạn số lần gọi, thời gian chờ.
5. Một `ClientID` dùng cho nhiều quán, điều khoản đối tác, phí gói hóa đơn, hai ký tự cuối ký hiệu.
6. LPM đứng ra thu hồ sơ của chủ quán gửi MISA có được không, theo điều khoản nào.

## 9. Thứ tự làm sau khi được duyệt

1. Áp migration v1 lên bản thử (đã có danh sách kiểm tra).
2. Migration v2 và hàm lưu thông tin kết nối.
3. Chương trình chạy ngầm chỉ **đọc** (lấy token, lấy mẫu) để thử kết nối với tài khoản thử.
4. Trợ lý thiết lập trong app.
5. Phát hành thử một hóa đơn trên một quán thử, đối chiếu từng con số.
6. Mở cho quán thật, bật dần từng quán.
