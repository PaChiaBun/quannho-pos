# Kế hoạch tinh chỉnh AI Boom sau khi thử trên quán thật (lập 18/11/2026)

**Trạng thái:** Giai đoạn 1 XONG 18/11. Giai đoạn 2: đã soi đủ 6 quán thật, ra 10 lỗi mới (bảng ở mục 7). Lô 1 (B1, B2, B3, B5, B7, B9) ĐÃ ÁP production 18/11 16:48 (lần 255, TS `20261118_164850`). Lô 2 (B4, B6, B8, B10, giờ lẻ tẻ còn sót) ĐÃ ÁP production 19/11 11:36 (lần 256, TS `20261119_113621`). Giai đoạn 2 xong phần soi và sửa. **Giai đoạn 3 như thiết kế KHÔNG chạy (19/11):** bộ kín không đo được các lần sửa này (xem mục 7); chờ Chủ Quán chọn cách đo thay thế. Còn tồn: "món nào nên bỏ" sót nhóm khác; câu gõ không dấu bị hiểu ngược; kỳ so sánh 0 đơn khi kỳ này cũng chưa có đơn.

Bản đang chạy khi lập: Boom máy chủ lần 254 (commit `8dddfe6`, TS `20261118_161027`); câu tư vấn dùng `gpt-6-sol`, hướng dẫn dùng `gpt-6-luna`; hạn mức mỗi quán 1,5 USD / ngày, 3 USD / tháng, cả hệ thống 10 USD / tháng.

## 1. Căn cứ (số đọc ngày 18/11)

- **Thử trên quán thật Bò Đen, khoảng 30 câu:** mọi số chính khớp sổ, không bịa số. Lộ ra 5 lỗi, cả 5 nằm ở phần MÃ chuẩn bị số đưa cho mô hình (lần 250–254), không lỗi nào do mô hình suy luận sai. Cả 5 đều nhìn thấy được ngay trong "khối số" (đoạn số liệu mã ghép sẵn gửi cho mô hình), trước khi gọi mô hình.
- **Bộ câu tự viết không bắt được các lỗi này:** chấm mù 15/11 trên 180 câu kín cho 15,07 / 16, dùng được 171 / 180 — nhưng các quán mẫu a–d không có ngày nghỉ đột xuất, không có nhóm "Nguyên liệu", không bán lệch hẳn một buổi.
- **Người dùng thật, 30 ngày qua:** 26 quán có đơn; 6 quán thật có từ 30 đơn (4 quán từ 300 đơn). Số lượt hỏi Boom của 6 quán: 59, 37 (27 lượt là hỏi thử), 27, 2, 0, 0. Cả hệ thống có 1 lượt chê, 0 lượt khen.
- **Giá vốn gần như trống:** số món có giá vốn của 6 quán là 13 / 174, 14 / 32 (phần lớn là nguyên liệu), 0 / 12, 0 / 2, 0 / 305, 0 / 105. Bò Đen chưa có phiếu chi nào. Vì vậy Boom không trả lời được câu lời lỗ, là câu đáng giá nhất.
- **Lời dặn đã chạm trần:** các lô 05–10/11 thêm lời dặn cho kết quả không rõ hoặc âm (xem `ke-hoach-day-do-boom-sau-thoi-tiet.md`).
- **Soi số không tốn tiền là làm được:** ba hàm `boom_sales_raw_v1`, `get_report_stats_for_range_v1`, `get_daily_revenue_for_range_v1` gọi được từ kết nối nội bộ chỉ đọc trên máy chủ (đã thử với Bò Đen: 576 đơn, 57.247.400đ, 15 ngày có đơn). Ghép với `dungFacts` + `soBaoCao` + `parseFacts` + `formatFacts` là dựng lại đúng khối số Boom nhận, không gọi mô hình, không trừ hạn mức của quán, không cần đăng nhập.

## 2. Nguyên tắc

1. **Tìm lỗi ở khối số trước, hỏi mô hình sau.** Khối số sai thì mô hình nào cũng khuyên sai; soi khối số thì miễn phí.
2. **Mã trước lời dặn.** Không thêm lời dặn, câu mẫu. Sửa dòng tính sẵn và mã kiểm; thay vế, không cộng vế (giữ từ kế hoạch 09/11).
3. **Mỗi lỗi sửa có một test dựng lại đúng tình huống của quán** (như lần 250–254).
4. **Giữ hạn mức cho chủ quán.** Hỏi thử trên quán thật không quá nửa hạn mức ngày còn lại; hỏi nhiều thì dùng công cụ soi số hoặc quán Demo.
5. **Tiền và production phải hỏi.** Mỗi lượt đo tốn tiền OpenAI báo số ước trước; mỗi lần áp production chạy `KHO=1` trước và chờ Chủ Quán duyệt.
6. **Dữ liệu quán thật không vào repo.** Số đọc về để soi nằm ở thư mục tạm của phiên; test dùng số dựng lại, không chép tên khách, tên nhân viên.

## 3. Các giai đoạn

### Giai đoạn 1 — Công cụ soi khối số quán thật (0 đồng)

- Viết `tool/boom_do/soi_so/`: một lệnh nhận mã quán và kỳ (hôm nay, tuần này, tháng này, tháng trước), đọc số qua ssh chỉ đọc, dựng khối số cho khoảng 12 câu hỏi mẫu (doanh thu, so kỳ trước, món chạy / chậm, giờ, thứ, tăng giá, bỏ món, dự báo, lời lỗ, kho, khuyến mãi, nhân viên) rồi in ra.
- Kèm bộ **kiểm bất biến** chạy tự động trên khối số, in cảnh báo khi:
  - tổng theo thứ, theo giờ, theo ngày lệch doanh thu kỳ;
  - trung bình theo thứ × số ngày không ra tổng của thứ đó; số ngày mở bán lớn hơn số ngày có đơn;
  - giờ / thứ được gọi "vắng nhất", "yếu bất thường" mà chỉ có vài đơn;
  - "món chưa bán" có mặt hàng không phải món bán; món bị gọi "chậm nhất" trong khi nhóm khác có món chậm hơn;
  - dự báo cả kỳ nhỏ hơn số đã có; nhãn trung bình khác số dùng để tính;
  - kỳ so sánh rỗng mà không có dòng nói rõ.
- **Xong khi:** chạy được cho Bò Đen và Demo, ra đúng các số đã đối chiếu tay hôm 18/11; chạy lại trên bản mã trước lần 250 thì bộ bất biến phải báo được ít nhất 4 / 5 lỗi đã biết (đây là phép thử xem bộ kiểm có bắt được lỗi thật không).

### Giai đoạn 2 — Soi 6 quán thật, sửa lỗi chuẩn bị số theo lô (0 đồng cho tới khi áp)

- Chạy công cụ trên 6 quán thật, mỗi quán 4 kỳ. Đọc cảnh báo, đối chiếu với sổ bằng truy vấn chỉ đọc như đã làm với Bò Đen. Ghi mỗi lỗi một dòng: quán, câu hỏi, dòng sai, số đúng, đếm được ở mấy quán.
- Ưu tiên quán khác kiểu Bò Đen: quán 2.262 đơn với 174 món; quán 305 món mà ít đơn; quán chỉ có 2 món; quán có chi nhánh.
- Sửa theo lô, mỗi lô nhiều nhất 5 chỗ, mỗi chỗ có test. Lô đầu gồm cả việc tồn đã biết:
  - "món nào nên bỏ" sót món chậm ở nhóm khác;
  - câu hỏi riêng một buổi ("buổi chiều vắng") vẫn khuyên theo giờ lẻ tẻ;
  - hồ sơ quán ghi "có bán 16h–24h" lệch với "giờ bán chính 18h–24h";
  - kỳ so sánh 0 đơn chưa được nói rõ khi chính kỳ này cũng chưa có đơn;
  - câu gõ không dấu "e khach" bị hiểu ngược (chỉ sửa nếu làm được bằng mã, không bằng lời dặn).
- **Xong khi:** cả 6 quán chạy qua bộ bất biến không còn cảnh báo đúng nào chưa xử lý; đã áp 1–2 lô (lần 255 trở đi).

### Giai đoạn 3 — Đo một lần để chốt (tốn tiền, cần duyệt)

- Mục đích: chắc rằng lần 250 trở đi không làm XẤU câu trả lời ở quán khác kiểu. Không nhằm chứng minh tốt hơn.
- Cách đo: lấy 60 câu trong 180 câu kín `de_kin18` + `de_kin21`, chia đều theo lĩnh vực. Bản cũ (lần 249) đã có sẵn câu trả lời từ 15/11 nên chỉ sinh câu trả lời bản mới. Chấm mù bằng Claude như 15/11.
- Tiền: khoảng 2,2 USD theo giá đủ (60 câu × 0,036). Công cụ đo đã ghi được % token lưu đệm nên lượt này cũng cho biết giá thật.
- **Ngưỡng:** mới − cũ không thấp hơn −0,3 / 16 và số câu sai số không tăng thì giữ. Thấp hơn thì tìm lần sửa gây ra và hoàn tác riêng lần đó.

> **19/11 — thiết kế trên không dùng được.** So nguyên văn lời nhắc của mã trước lần 250 với mã lần 256 trên cả 180 câu `de_kin18` + `de_kin21`: 180 / 180 giống hệt từng chữ. Bốn quán mẫu a–d không có tình huống nào mà lần 250–256 sửa. Đo 60 câu này chỉ đo độ ngẫu nhiên của mô hình. Cách thay thế đề xuất ở mục 7.

### Giai đoạn 4 — Gỡ nghẽn dữ liệu: giá vốn và ghi chi

- Đo trước (bằng công cụ giai đoạn 1): với mỗi quán, 10 món doanh thu cao nhất có bao nhiêu món đã có giá vốn; 30 ngày qua có bao nhiêu phiếu chi.
- Phần Boom, làm bằng mã: khi câu hỏi cần giá vốn hoặc chi phí mà thiếu, dòng tính sẵn nêu đúng 3 món bán chạy nhất chưa có giá vốn để nhập trước, thay vì nhắc chung chung. Kiểm xem dòng này đã có chưa trước khi viết.
- Phần app, cần Chủ Quán quyết và phải phát hành: màn nhập nhanh giá vốn cho các món bán chạy; lời nhắc ghi chi. Nằm ngoài hàm Boom nên kế hoạch này chỉ đề xuất.
- **Xong khi:** có số đo ban đầu cho 6 quán và Chủ Quán đã quyết làm hay không làm phần app.

### Giai đoạn 5 — Vận hành: hạn mức, báo hết lượt, theo dõi người dùng thật

- **Báo hết lượt:** hiện khi quán vượt hạn mức, app lặng lẽ trả câu dự phòng thô. Sửa để app nói rõ đã hết lượt hỏi trong ngày. Cần phát hành app và web.
- **Hạn mức tháng:** đặt từ thời mô hình rẻ. Với giá mới, 3 USD / quán chỉ còn khoảng 45–100 câu. Tháng 11 cả hệ thống mới dùng khoảng 2,5 USD nên chưa gấp; đề xuất nâng khi có quán chạm 70% hạn mức tháng.
- **Đo thời gian:** số giây trong sổ chỉ đo từ lúc gọi mô hình. Ghi thêm thời gian đọc số để biết lần 253 (đọc thêm trọn kỳ trước) có làm chậm không.
- **Theo dõi hằng tuần:** đọc sổ thật — số lượt, lượt lỗi, lượt chê, thời gian, tiền — và nội dung các lượt bị chê; báo Chủ Quán 5 dòng. Đọc nội dung cần Chủ Quán cho phép thường xuyên.

## 4. Không làm trong kế hoạch này

- Thêm lời dặn, câu mẫu vào lời nhắc.
- Đổi mô hình, hoặc bật mức suy nghĩ cao hơn.
- Cho Boom tự gọi công cụ đọc số (đã đo, −1,19).
- Đo lớn 180 câu theo lịch.

## 5. Thứ tự và phụ thuộc

1. Giai đoạn 1 làm trước, không cần gì thêm.
2. Giai đoạn 2 cần giai đoạn 1 và cần Chủ Quán đồng ý cho đọc số bán của 6 quán để soi.
3. Giai đoạn 3 làm sau khi áp xong các lô của giai đoạn 2, cần duyệt tiền.
4. Giai đoạn 4 và 5 làm song song với 2 và 3; phần app theo lịch phát hành.

## 6. Việc cần Chủ Quán quyết

| Việc | Đề xuất |
|---|---|
| Đọc số bán của 6 quán thật để soi (chỉ đọc, không lưu vào repo) | Đồng ý |
| Đọc nội dung các lượt hỏi Boom bị chê, hằng tuần | Đồng ý |
| Chi khoảng 2,2 USD cho lượt đo ở giai đoạn 3 | Đồng ý, khi tới giai đoạn 3 sẽ hỏi lại |
| Hạn mức tháng mỗi quán | Giữ 3 USD, nâng khi có quán chạm 70% |
| Phần app: báo hết lượt hỏi; nhập nhanh giá vốn | Làm "báo hết lượt" trong bản phát hành tới; "nhập nhanh giá vốn" quyết sau khi có số đo giai đoạn 4 |

## 7. Nhật ký thực hiện

### 18/11 — Giai đoạn 1 xong

- Công cụ: `tool/boom_do/soi_so/soi.ts` (đọc số + dựng khối số bằng chính mã Boom) và `kiem.ts` (bộ kiểm bất biến K1–K10, có `kiem_test.ts`). Chạy: `deno run -A tool/boom_do/soi_so/soi.ts <mã quán> [--ma <thư mục boom-chat khác>] [--now <giờ>] [--ra <thư mục ngoài repo>] [--in]`. Khoảng 13 giây mỗi quán, 15–16 câu hỏi mẫu, 0 đồng.
- Cách đọc số: thay `fetch` của `docBanHang` bằng lệnh psql chỉ đọc qua ssh (đặt `default_transaction_read_only`), nên chạy đúng đường mã thật, kể cả lượt đọc thêm trọn kỳ trước của lần 253.
- Đối chiếu: Bò Đen ra đúng các số đã kiểm tay (tháng 11: 576 đơn, 57.247.400đ, 15 ngày có đơn; tuần này 59 đơn, 4.952.000đ; tháng 10: 84 đơn, 8.375.000đ, 3 ngày). Demo: tháng 11 487 đơn, 41.290.000đ, 10 ngày có đơn.
- **Phép thử bắt lỗi (đạt 5 / 5):** chạy trên bản mã trước lần 250 (commit `557bb82`) với cùng mốc giờ, bộ kiểm báo 24 cảnh báo thuộc K2 K3 K4 K5 K6 K7 K8 K9 K10 — đủ cả 5 lỗi đã sửa ở lần 250–254 (món chưa bán gồm nhóm Nguyên liệu; trung bình theo thứ chia cả ngày nghỉ; "ngày nào trong tuần" ra Tuần này; 11h bị xếp vắng nhất; kỳ so sánh 0 đơn không nói gì + câu tăng giá gọi tắt không ra dòng; số ngày mở bán 18 so với 15) và cả lỗi nhãn dự báo. Trên bản lần 254: Demo 0 cảnh báo, Bò Đen 1 cảnh báo.
- **Lỗi mới bộ kiểm tìm ra (đưa vào lô đầu giai đoạn 2):** "có nên tăng giá trà sữa thêm 5 nghìn không" — menu Bò Đen có 2 món bắt đầu bằng "trà sữa" nhưng khối số tự tính cho Trà Sữa Hong Kong. `kichBanGia` chỉ xét trùng tên trong các món Boom nhìn thấy (3 chạy + 3 chậm mỗi nhóm), không phải cả menu.
- Giới hạn: mới soi số BÁN HÀNG. Thu Chi, kho, khách, khuyến mãi, nhân sự (đọc qua nhiều bảng theo quyền người hỏi) chưa dựng lại. Bộ kiểm chưa bắt được loại "món nào nên bỏ sót nhóm khác" vì đó là lựa chọn của mô hình, không nằm trong khối số.

### 18/11 — Giai đoạn 2: soi 5 quán thật còn lại (bản lần 254)

Chạy `soi.ts` trên 5 quán thật còn lại: 40 giây, 0 đồng. Bộ kiểm báo 7 cảnh báo (2 quán không có cảnh báo). Đọc khối số bằng mắt ra thêm lỗi mà bộ kiểm chưa bao. Các điểm nghi ngờ đã đối chiếu sổ bằng truy vấn chỉ đọc.

Theo nguyên tắc 6, quán ghi bằng mã, không ghi tên và doanh thu: **A** quán lớn nhất, bán ăn sáng–trưa; **B** quán nước mới mở cuối tháng 10; **C** quán chỉ có 2 món; **D** tiệm dịch vụ làm đẹp mới có đơn 4 ngày; **E** quán menu hơn 100 món mà mỗi ngày vài đơn; **T** quán đã thử trên Sunmi ở giai đoạn trước.

| Mã | Quán | Lỗi trong khối số | Đối chiếu sổ | Bộ kiểm bắt được |
|---|---|---|---|---|
| B1 | A | Kỳ này quán không có đơn nào từ 18h (kỳ trước 19–21h có bán), khối số ghi "kéo khách lại đúng 19h và 20h bằng ưu đãi… bớt 2.000đ / đơn" và "ĐƠN ĐANG TỤT" | Có: đơn buổi tối về 0 từ một ngày cuối tháng 10, liên tục 4 tuần | Chưa |
| B2 | D | Quán mới có đơn giữa tháng nhưng các ngày trước đó trong tháng bị tính là ngày mở: "nghỉ Thứ 2, Thứ 5, Chủ nhật", "quán NGHỈ (không mở bán)" | Có | Chưa |
| B3 | D, E, A (kỳ tuần) | Kỳ quá ngắn hoặc quá ít đơn vẫn liệt kê hơn trăm "món chưa bán" và dặn "hướng đúng là ẨN khỏi menu" | Có | K5 (một phần) |
| B4 | D | Hồ sơ ghi "quán ăn (đồ ăn 100% doanh thu)" cho một tiệm dịch vụ, không bán đồ ăn | Có | Chưa |
| B5 | C | Cùng kỳ tháng trước chỉ có 1 đơn, khối số ghi tăng hơn 2.000%, số đơn tăng hơn 5.000% và cả đoạn "tăng ở đâu" | Có | Chưa |
| B6 | T, D | Tên gọi tắt ứng nhiều món trong menu nhưng dòng tăng giá tự tính cho một món | Có | K9 |
| B7 | A, T | Nhóm "Nguyên liệu" vẫn hiện là "N món đang bán", nằm trong "Các nhóm quán đang bán" và "Bình quân mỗi đơn" (lần 250 mới bỏ khỏi số món chưa bán) | Có | Chưa |
| B8 | B | Gợi ý combo ghép một món vốn đã là combo, giá combo gấp hơn 3 lần đơn trung bình | Chưa | Chưa |
| B9 | D (kỳ tuần) | Ngày không có đơn vẫn tính là ngày mở bán (ghi 3 ngày, sổ có 2) | Có | K6 |
| B10 | E | Quán khoảng 4 đơn mỗi ngày vẫn bị gọi một thứ là "yếu bất thường, bằng 30% ngày thường" từ đúng 1 ngày | Có | Chưa |

Cảnh báo sai của bộ kiểm cần chỉnh: K4 báo một giờ vắng nằm GIỮA hai giờ bán của quán E (theo thiết kế lần 252 vẫn là giờ bán) → K4 chỉ nên bắt giờ ở rìa.

**Lô 1 đề xuất (5 chỗ):** B1, B2 (gộp B9, cùng hàm đếm ngày), B3, B5, B7. Trước khi sửa, thêm phép kiểm cho B1, B2, B5, B7 vào `kiem.ts` để đo được "xong".
**Lô 2:** B4, B6, B8, B10 và việc tồn ở giai đoạn 2 (bỏ món sót nhóm khác; hỏi riêng một buổi; hồ sơ quán lệch giờ bán chính; câu không dấu).

### 18/11 — Giai đoạn 2, lô 1: đã sửa trong mã (chưa áp)

Làm theo thứ tự: thêm phép kiểm trước (K11 ngày nghỉ của quán mới, K12 khuyên kéo khách ở giờ không có đơn, K13 tính % trên nền quá nhỏ, K14 nhóm nguyên liệu ghi là đang bán, K15 nêu món chưa bán khi kỳ dưới 7 ngày có đơn; K4 chỉ còn bắt giờ ở rìa) → chạy trên 6 quán thật + Demo với mã lần 254: **40 cảnh báo khác nhau** → sửa → chạy lại: **2 cảnh báo**, cả hai là B6 của lô 2.

| Lỗi | Sửa ở đâu | Cách sửa |
|---|---|---|
| B7 | `parseFacts` | Bỏ nhóm nguyên liệu / vật tư không bán phần nào ngay khi đọc số, nên mọi dòng phía sau đều không còn nhóm này |
| B3 | `formatFacts` | Kỳ dưới 7 ngày có đơn: không liệt kê món chưa bán, không khuyên ẩn món; thay bằng một dòng nói rõ chưa đủ ngày |
| B2 + B9 | `ngayBan`, `ngayMoBan`, `moBanTb` | Kỳ so sánh và trọn kỳ trước đều 0 đơn thì chỉ đếm thứ từ ngày đầu có đơn (`batDau`), thêm dòng "quán CHỈ có đơn từ …"; số ngày mở bán = số ngày CÓ ĐƠN (`coDon`) khi số từng ngày đáng tin, thay cho trường `cuoi` của lần 254 |
| B5 | `docBanHang`, `parseFacts`, `formatFacts` | Kỳ so sánh dưới 10 đơn VÀ dưới 10% số đơn kỳ này: không gửi số kỳ trước để tính %, báo "KỲ SO SÁNH GẦN NHƯ CHƯA BÁN" kèm số đơn, tiền thật và trọn kỳ trước |
| B1 | `caNgung` (mới), `formatFacts`, hướng tăng doanh thu | Giờ kỳ trước bán thật (≥ 1%) mà nay 0đ hoặc chỉ còn đơn lẻ, gộp từ 5% doanh thu kỳ trước: thêm dòng "CA NGỪNG BÁN" (bao nhiêu % mức giảm là do các giờ này, mức tăng giảm riêng các giờ còn bán), dặn hỏi chủ quán; hai chỗ chọn "giờ mất nhiều nhất" chỉ xét giờ bán chính |

- Test hàm 231 qua (thêm 2 test, số dựng lại, không dùng tên hay số của quán thật). Test bộ kiểm 2 qua.
- Đã đọc lại bằng mắt khối số thật sau khi sửa của quán A (dòng ca ngừng bán: các giờ chiều tối chiếm khoảng một phần ba doanh thu kỳ trước và khoảng 70% mức giảm; riêng các giờ còn bán giảm khoảng 19%), quán D (chỉ tính từ ngày đầu có đơn, không còn "nghỉ Thứ …") và quán C (không còn % nghìn lần).
- Chưa làm: chưa áp production; chưa hỏi mô hình câu nào trên bản này; B4, B6, B8, B10 còn nguyên.
- **Đã áp 18/11 16:48 (lần 255):** Chủ Quán duyệt "Áp lên"; `KHO=1` trước, máy chủ đúng bản 254; chép `logic.ts` + `ban_hang.ts`; hàm chạy lại bình thường. Hoàn tác: `ROLLBACK=1 bash db-fix/boom_l255_ap_dung.sh 20261118_164850`.

### 18/11 — Giai đoạn 2, lô 2: đã sửa trong mã (chưa áp)

Cùng cách làm: thêm phép kiểm trước (K16 loại hình quán, K17 "bất thường" khi quá ít số liệu, K18 combo ghép món vốn là combo, K19 hồ sơ ghi giờ bán gồm giờ lẻ tẻ, K20 hỏi riêng một buổi không phải giờ bán; thêm 3 câu hỏi mẫu theo buổi) → chạy trên 7 quán với mã lần 255: **21 cảnh báo khác nhau** → sửa → **0 cảnh báo**.

| Lỗi | Sửa ở đâu | Cách sửa |
|---|---|---|
| B4 | `loaiQuan` (mới), `shopProfile` | Chỉ gọi "quán ăn" khi tên nhóm hoặc tên món bán chạy có chữ đồ ăn (từ 30% doanh thu); không thấy đồ ăn lẫn đồ uống thì ghi rõ có thể là tiệm dịch vụ, dặn không khuyên kiểu quán ăn; kỳ 0đ không suy loại hình |
| B6 | `docBanHang` gửi thêm `ten_mon` (tên mọi món, không in vào khối số), `kichBanGia` | Tên gọi tắt ứng từ 2 món trong CẢ menu → dòng "TÊN MÓN CHƯA RÕ", dặn hỏi lại chủ quán thay vì tự chọn một món |
| B8 | dòng "Combo tính sẵn" | Không ghép món có tên bắt đầu bằng "combo"; tiệm không phải ăn uống thì không gợi ý combo món |
| B10 | dòng "Bất thường (tính sẵn)" | Một thứ chỉ bị gọi yếu bất thường khi có từ 2 ngày bán và quán từ 10 đơn mỗi ngày mở bán |
| Giờ lẻ tẻ còn sót | `khungBan`, nhánh hỏi riêng một buổi | Hồ sơ "có bán a–b" dùng chung giờ bán chính với dòng theo giờ; hỏi về một buổi không có giờ bán chính thì ra dòng "Buổi … KHÔNG phải giờ bán của quán", không ra việc ưu đãi cho buổi đó |
| Kỳ không có đơn nào | `formatFacts` | Không liệt kê cả menu là "chưa bán" (lộ ra khi soi câu "tháng trước" của quán mới mở tháng này) |

- Test hàm 232 qua (thêm 1 test, sửa 1 test cũ có mẫu 10 đơn cả tháng cho hợp luật B10). Test bộ kiểm 2 qua.
- Đã đọc lại bằng mắt trên số thật: quán T (câu "tăng giá trà sữa" ra dòng hỏi lại, hồ sơ ghi 18h–24h), quán D (hồ sơ không còn "quán ăn", không có combo), quán B (không còn combo vô lý), quán A (hỏi buổi tối ra dòng "không phải giờ bán").
- Chưa làm: chưa áp production; chưa hỏi mô hình trên bản này; ba việc tồn ghi ở dòng Trạng thái.
- **Đã áp 19/11 11:36 (lần 256):** Chủ Quán duyệt "Áp lên"; `KHO=1` trước, máy chủ đúng bản 255; chép `logic.ts` + `ban_hang.ts`; hàm chạy lại bình thường. Hoàn tác: `ROLLBACK=1 bash db-fix/boom_l256_ap_dung.sh 20261119_113621`.

### 19/11 — Giai đoạn 3: dừng trước khi tốn tiền, đề xuất cách đo thay thế

- Chủ Quán duyệt "Chạy đo" (60 câu kín, ~2,2 USD). Trước khi đưa lệnh cần khoá OpenAI, chạy thử không khoá thì thấy độ dài lời nhắc bản mới bằng bản cũ ở cả 60 câu. Viết `tool/boom_do/do_15_11/so_loi_nhac.ts` so nguyên văn lời nhắc + số gốc của hai bản mã: **180 / 180 câu giống hệt từng chữ.** Quán mẫu a–d: 0 ngày không đơn, số từng ngày không phủ đủ kỳ, 0 giờ lẻ tẻ, không ca ngừng bán, không nhóm nguyên liệu, đều là quán ăn uống. → KHÔNG chạy lượt đo, không tốn đồng nào.
- Hệ quả 1: với quán "bình thường" như quán mẫu, lần 250–256 không đổi gì trong lời nhắc nên không thể làm câu trả lời xấu đi. Phần "không làm xấu" của giai đoạn 3 đạt mà không cần đo.
- Hệ quả 2: bộ kín hiện có không nhìn thấy các tình huống của quán thật. Đây cũng là lý do nó không bắt được lỗi nào trong số 15 lỗi đã sửa.
- Ngược lại, trên 6 quán thật + Demo (`soi.ts` chạy bằng cả hai bản mã, cùng mốc giờ): **128 / 130 câu hỏi mẫu có khối số đổi.**
- **Cách đo thay thế đề xuất (3b):** chấm mù theo cặp trên chính khối số quán thật. Mỗi quán lấy 4–6 câu hỏi mẫu có khối số đổi; sinh câu trả lời bằng `gpt-6-sol` cho cả bản mã cũ lẫn bản mới (cùng số thật, chỉ khác phần mã chuẩn bị số); Claude chấm mù, có khối số mới và số đã đối chiếu sổ làm mốc. Ước 28–42 cặp, 2,8–4,2 USD. Số liệu quán chỉ nằm ở thư mục tạm; khi gọi mô hình thì đi tới OpenAI đúng như khi chính quán đó hỏi Boom. Cần viết thêm phần sinh câu trả lời từ khối số của `soi.ts` và cần Chủ Quán chạy lệnh có khoá trong Terminal.
- Công cụ đo `do_tang.ts` thêm biến `BAN` (chỉ sinh một bản) cho các lượt sau.
- **19/11, 3b được duyệt ("Đo cách mới").** `soi.ts --xuat` ghi lời nhắc + số gốc + sổ thật (đọc thẳng số thô, không qua mã Boom) của 130 câu cho từng bản mã, cùng mốc giờ 18/11 21:00 (mã mới 0 cảnh báo, mã cũ 158). `sinh.ts` chọn 28 cặp xoay vòng qua 9 loại câu, mỗi quán 4 câu (cách "lấy câu đổi nhiều dòng nhất" bị bỏ vì sót hẳn loại giờ / tăng giá / món), gọi mô hình tư vấn đang chạy, kiểm số + viết lại bằng mã kiểm của chính bản đó. Người chấm đối chiếu sổ thật trước, khối số bản mới sau. Ước ~2 USD, chạm 4,5 USD thì tự dừng. Đã thử trọn đường bằng máy chủ giả trên máy (trần tiền, chạy tiếp phần thiếu, viết lại, trộn mù). Chờ Chủ Quán chạy lệnh có khoá.
- **19/11, Chủ Quán quyết KHÔNG đo 3b.** Giai đoạn 3 đóng ở đây, không tốn tiền OpenAI. Điều đã biết: bộ kiểm bất biến trên 7 quán từ 158 cảnh báo (mã trước lần 250) xuống 0 (lần 256); quán kiểu quán mẫu thì lời nhắc không đổi một chữ. Điều CHƯA biết: mô hình diễn đạt các dòng tính sẵn mới thế nào trên quán thật (chưa có câu trả lời nào được chấm). `sinh.ts` giữ lại để dùng khi cần; đừng tự đề xuất đo lại nếu không có lý do mới.

### 19/11 — Giai đoạn 5: báo hết lượt, thời gian đọc số, theo dõi tuần

- **Báo hết lượt.** App đã biết báo hết lượt từ bản 38 (commit `38cd677`, 10/11), nhưng chỉ ở đường cũ (`advise`). Đường hỏi mới — máy chủ tự lấy số, bật cho app từ 08/11 — khi bị máy chủ trả 429 thì `askServer` trả rỗng, app rơi về đường cũ và với câu số liệu thì tự trả bằng số tính trên máy, không nói gì. Đó chính là câu "giảm 100.0%" trên máy quán T ngày 18/11. Sửa trong `boom_chat_provider.dart`: giữ câu báo của lượt `askServer` rồi ghép vào cuối câu trả lời (không lặp khi đường cũ đã tự báo; lượt không hỏi máy chủ không đọc nhầm mã của lượt trước). Test mới trong `boom_ai_route_test.dart`. **Chưa phát hành** — đi cùng bản app kế.
- **Còn hở:** máy chủ trả chung một mã `BUDGET_EXCEEDED` cho cả ba trần (ngày của quán, tháng của quán, tháng của hệ thống), nên app luôn nói "hỏi lại vào ngày mai" — sai khi quán chạm trần tháng. **Đã sửa trong mã (lần 257, Chủ Quán bảo "Sửa đi" 19/11), CHƯA áp:** migration `20261119_boom_han_muc_tran.sql` cho hàm `boom_ai_reserve_v1` trả thêm `scope` (`month` | `system` | `day`, trần tháng xét trước trần ngày), `index.ts` chuyển `scope` cho app, app nói "hỏi lại vào đầu tháng sau" khi chạm trần tháng. Tương thích hai chiều với máy chủ và app cũ. Test SQL 7 bước đã chạy thử ngay trên máy chủ trong giao dịch rồi ROLLBACK (máy chủ không đổi). Kịch bản áp: `db-fix/boom_l257_ap_dung.sh`.
- **Hạn mức tháng.** Đang đặt: 1,5 USD / quán / ngày, 3 USD / quán / tháng, 10 USD cả hệ thống / tháng. Ngày 19/11: cả hệ thống 2,51 USD (25%); quán cao nhất 45% (quán T, phần lớn là câu hỏi thử ngày 18/11), các quán khác dưới 20%. Chưa quán nào tới 70% → giữ nguyên như đã chốt ở mục 6.
- **Thời gian đọc số.** Không thêm cột vào sổ: đo thẳng từng lượt đọc trên máy chủ. Số bán một tháng 40–150 ms ở quán nhiều đơn nhất, các lượt còn lại 2–20 ms. Lượt đọc thêm của lần 253 (trọn kỳ trước) chỉ chạy khi kỳ so sánh gần như chưa bán, tức quán mới, nên chỉ thêm khoảng 10 ms. So với 3–7 giây chờ mô hình thì không đáng kể → lần 253 không làm chậm.
- **Theo dõi hằng tuần.** `tool/boom_tuan.sh [số ngày]`: chỉ đọc, chỉ in số đếm (lượt, lỗi, chê, thời gian, tiền, % hạn mức từng quán), không in nội dung câu. Tuần 13–19/11: 138 lượt, 18 quán, 19 người; trả lời được 107, lỗi 25 (toàn bộ rơi vào 15–16/11, lúc khoá OpenAI hỏng), không có bài 6; 0 khen, 1 chê; chờ mô hình giữa 3,3 giây, 9 trên 10 lượt dưới 7,1 giây, không lượt nào quá 12 giây; tiền 2,01 USD. Lượt bị chặn vì hết lượt không có trong sổ (máy chủ không ghi dòng); kịch bản đếm qua câu báo app ghi vào lịch sử nên chỉ thấy từ bản app mới.
- **Lịch tự chạy (Chủ Quán duyệt 19/11):** tác vụ `bao-cao-boom-tuan` của app Claude trên máy Mac, 08:05 sáng thứ Hai, chạy `tool/boom_tuan.sh 7` rồi báo 5 dòng; chỉ đọc, không đọc nội dung câu. Chỉ chạy khi app Claude đang mở (đóng thì chạy bù lúc mở lại).
- Chưa làm: đọc nội dung lượt bị chê — chờ Chủ Quán cho phép.

