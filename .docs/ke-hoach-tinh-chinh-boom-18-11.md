# Kế hoạch tinh chỉnh AI Boom sau khi thử trên quán thật (lập 18/11/2026)

**Trạng thái:** Chủ Quán duyệt bắt đầu 18/11 ("Bắt đầu"). Giai đoạn 1 XONG 18/11. Giai đoạn 2 chờ Chủ Quán đồng ý cho soi số 5 quán thật còn lại.

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
