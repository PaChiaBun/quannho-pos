# Kế hoạch tinh chỉnh AI Boom sau khi thử trên quán thật (lập 18/11/2026)

**Trạng thái:** Giai đoạn 1 XONG 18/11. Giai đoạn 2: đã soi đủ 6 quán thật, ra 10 lỗi mới (bảng ở mục 7). Lô 1 (B1, B2, B3, B5, B7, B9) ĐÃ ÁP production 18/11 16:48 (lần 255, TS `20261118_164850`). Lô 2 (B4, B6, B8, B10, giờ lẻ tẻ còn sót) ĐÃ ÁP production 19/11 11:36 (lần 256, TS `20261119_113621`). Giai đoạn 2 xong phần soi và sửa. **Giai đoạn 3 như thiết kế KHÔNG chạy (19/11):** bộ kín không đo được các lần sửa này (xem mục 7); cách đo thay thế 3b Chủ Quán quyết không đo. Giai đoạn 5 xong 19/11 (lần 257 ĐÃ ÁP 16:54, phần app chưa phát hành). **Giai đoạn 4 (19/11):** đã đo 6 quán, lần 258 ĐÃ ÁP máy chủ 20/11 13:40 (mốc hoàn tác `20261120_134013`); lần 259 (giá vốn theo công thức, làm ở máy chủ, commit `b84a161`) ĐÃ ÁP máy chủ 20/11 14:13 (mốc hoàn tác `20261120_141333`); lần 260 (khối số mang đủ món giữa nhóm, đếm đúng món có giá vốn, commit `c0919a6`) ĐÃ ÁP máy chủ 21/11 02:03 (mốc hoàn tác `20261121_020327`); lần 261 (ba lỗi nhỏ còn tồn: hỏi bỏ món sót nhóm khác, chữ "e" không dấu, kỳ so sánh 0 đơn khi kỳ này chưa có đơn, commit `49a9239`) ĐÃ ÁP máy chủ 21/11 02:40 (mốc hoàn tác `20261121_024051`); lần 262 (kỳ chưa có đơn thì không in sẵn "giảm 100%", commit `d2d0fb8`) ĐÃ ÁP máy chủ 21/11 04:00 (mốc hoàn tác `20261121_040057`); lần 263 (câu nối tiếp ngắn dùng lại bài hướng dẫn, commit `faf6c76`) ĐÃ ÁP máy chủ 22/11 05:18 (mốc hoàn tác `20261122_051844`) và 8 mục hướng dẫn mới ĐÃ ĐĂNG 22/11 (bản hướng dẫn `202611212224`); hỏi thử: bài mới chạy, câu nối tiếp dùng lại được bài nhưng vẫn trả lời "gọi Hotline" → lần 264 (commit `7a33cff`) ĐÃ ÁP máy chủ 22/11 16:22 (mốc hoàn tác `20261122_162207`), hỏi lại câu nối tiếp đã đúng; đề xuất app 2 (màn nhập nhanh giá vốn): Chủ Quán mở phiên riêng 21/11 rồi bảo "cái này ko cần đâu", xác nhận bỏ hẳn 22/11, chưa viết mã; đề xuất 3 chờ Chủ Quán quyết (mục 7).

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
- **Còn hở:** máy chủ trả chung một mã `BUDGET_EXCEEDED` cho cả ba trần (ngày của quán, tháng của quán, tháng của hệ thống), nên app luôn nói "hỏi lại vào ngày mai" — sai khi quán chạm trần tháng. **Đã sửa (lần 257, Chủ Quán bảo "Sửa đi" 19/11) và ĐÃ ÁP máy chủ 19/11 16:54 (Chủ Quán bảo "Áp lên"); phần app CHƯA phát hành:** migration `20261119_boom_han_muc_tran.sql` cho hàm `boom_ai_reserve_v1` trả thêm `scope` (`month` | `system` | `day`, trần tháng xét trước trần ngày), `index.ts` chuyển `scope` cho app, app nói "hỏi lại vào đầu tháng sau" khi chạm trần tháng. Tương thích hai chiều với máy chủ và app cũ. Test SQL 7 bước đã chạy thử ngay trên máy chủ trong giao dịch rồi ROLLBACK (máy chủ không đổi). Kịch bản áp: `db-fix/boom_l257_ap_dung.sh`; mốc hoàn tác `20261119_165346`. Kiểm sau khi áp: hàm cơ sở dữ liệu chỉ khác bản cũ đúng ba chỗ đã định, quyền gọi hàm giữ nguyên (chỉ `service_role`), gọi thử ở chế độ chỉ đọc trả `scope: month`, hàm Boom khởi động lại không lỗi. Chưa có lượt hỏi thật nào đi qua đường báo hết lượt mới; chủ quán chỉ thấy câu "đầu tháng sau" khi app bản mới được phát hành.
- **Hạn mức tháng.** Đang đặt: 1,5 USD / quán / ngày, 3 USD / quán / tháng, 10 USD cả hệ thống / tháng. Ngày 19/11: cả hệ thống 2,51 USD (25%); quán cao nhất 45% (quán T, phần lớn là câu hỏi thử ngày 18/11), các quán khác dưới 20%. Chưa quán nào tới 70% → giữ nguyên như đã chốt ở mục 6.
- **Thời gian đọc số.** Không thêm cột vào sổ: đo thẳng từng lượt đọc trên máy chủ. Số bán một tháng 40–150 ms ở quán nhiều đơn nhất, các lượt còn lại 2–20 ms. Lượt đọc thêm của lần 253 (trọn kỳ trước) chỉ chạy khi kỳ so sánh gần như chưa bán, tức quán mới, nên chỉ thêm khoảng 10 ms. So với 3–7 giây chờ mô hình thì không đáng kể → lần 253 không làm chậm.
- **Theo dõi hằng tuần.** `tool/boom_tuan.sh [số ngày]`: chỉ đọc, chỉ in số đếm (lượt, lỗi, chê, thời gian, tiền, % hạn mức từng quán), không in nội dung câu. Tuần 13–19/11: 138 lượt, 18 quán, 19 người; trả lời được 107, lỗi 25 (toàn bộ rơi vào 15–16/11, lúc khoá OpenAI hỏng), không có bài 6; 0 khen, 1 chê; chờ mô hình giữa 3,3 giây, 9 trên 10 lượt dưới 7,1 giây, không lượt nào quá 12 giây; tiền 2,01 USD. Lượt bị chặn vì hết lượt không có trong sổ (máy chủ không ghi dòng); kịch bản đếm qua câu báo app ghi vào lịch sử nên chỉ thấy từ bản app mới.
- **Lịch tự chạy (Chủ Quán duyệt 19/11):** tác vụ `bao-cao-boom-tuan` của app Claude trên máy Mac, 08:05 sáng thứ Hai, chạy `tool/boom_tuan.sh 7` rồi báo 5 dòng; chỉ đọc, không đọc nội dung câu. Chỉ chạy khi app Claude đang mở (đóng thì chạy bù lúc mở lại).
- Chưa làm: đọc nội dung lượt bị chê — chờ Chủ Quán cho phép.


### 19/11 — Giai đoạn 4: số đo giá vốn và ghi chi; lần 258 (ĐÃ ÁP máy chủ 20/11 13:40)

**Số đo 30 ngày tới 19/11** (chỉ đọc; "có giá vốn" tính đúng như Boom: giá vốn trên dòng đơn lúc bán, không có thì giá vốn mới nhất, không có thì giá vốn nhập tay trên món):

| Quán | Đơn | Món có bán | Trong đó có giá vốn | 10 món doanh thu cao nhất có giá vốn | % doanh thu thuộc món có giá vốn | Phiếu chi ghi tay | Công thức gắn món bán |
|---|---|---|---|---|---|---|---|
| A | 2.201 | 161 | 0 | 0 / 10 | 0% | 0 | 0 (có 5 công thức chưa gắn món) |
| B | 2.034 | 11 | 0 | 0 / 10 | 0% | 0 | 0 |
| C | 680 | 2 | 0 | 0 / 2 | 0% | 14 (đều trong tháng 10) | 0 |
| D | 117 | 28 | 0 | 0 / 10 | 0% | 2 | 0 |
| E | 71 | 61 | 0 | 0 / 10 | 0% | 0 | 0 |
| T | 703 | 21 | 2 | 2 / 10 | 16% | 0 | 7 |

- Cả hệ thống có 7 quán thật từ 30 đơn trong 30 ngày: 3 quán có ít nhất một món đang bán có giá vốn, 2 quán có phiếu chi ghi tay, 2 quán có công thức gắn với món bán.
- Quán T: 5 món đang bán có công thức đủ nguyên liệu, nguyên liệu nào cũng có giá vốn, nhưng chính món bán thì chưa có giá vốn. 5 món này chiếm 31% doanh thu. App đã tính "giá vốn / phần" ở màn công thức (mô-đun Kho chuyên nghiệp) nhưng không ghi sang món bán, và Boom không đọc công thức để lấy giá vốn. Nếu dùng được giá vốn theo công thức thì quán T từ 16% lên 47% doanh thu có giá vốn mà chủ quán không phải nhập thêm gì.
- Phiếu chi tự động của quán A (436 phiếu cũ) đều 0đ, không phải khoản chi thật.

**Phần Boom (kiểm trước khi viết, như kế hoạch dặn).** Dòng "Món bán chạy CHƯA có giá vốn" đã có từ 05/11; dòng nhắc "chưa ghi phiếu chi nào → thu − chi không phải tiền lời" cũng đã có. Soi khối số 6 quán thật thấy hai chỗ cần sửa, đã sửa trong mã (lần 258, commit `b355463`):

| # | Lỗi | Sửa |
|---|---|---|
| B11 | Quán D (tiệm dịch vụ, chưa nhập giá vốn món nào) vẫn nhận dòng "các món chạy nhất nhóm … đều giá vốn trên 45% giá bán" ở 18 / 18 câu. Dòng này chạy khi không chọn được món chủ lực để ghép combo; ở tiệm dịch vụ thì không chọn là do loại quán, không do giá vốn | Chỉ ra dòng này khi quán không phải tiệm dịch vụ và nhóm chủ lực thật sự có món giá vốn trên 45% |
| — | Dòng "món bán chạy chưa có giá vốn" xếp theo số phần, lấy 5 món: topping vài nghìn đồng và món thêm đứng trước món chính (quán T, quán A), không cho biết nhập xong được gì | Xếp theo doanh thu, còn 3 món, ghi 3 món đó chiếm bao nhiêu % doanh thu và "nhập giá vốn các món này trước". Trên 6 quán thật: 20%, 29%, 40%, 52%, 79%, 100%. Món còn thiếu dưới 10% doanh thu thì chỉ kể tên như cũ |

- Giới hạn đã biết: dòng mới chỉ xét 3 món doanh thu cao nhất của mỗi nhóm, nên có thể sót món hạng 4 của nhóm lớn khi 3 món đầu đã có món có giá vốn (quán T: món thứ ba được nêu không phải món doanh thu cao thứ ba còn thiếu). Con số % vẫn đúng với các món được nêu.
- Bộ kiểm thêm K21 (khối ghi "chưa có giá vốn món" mà vẫn có dòng "giá vốn trên …% giá bán"): 18 cảnh báo ở quán D trước khi sửa, 0 trên 6 quán thật và quán Demo sau khi sửa. Test hàm 233 qua. `KHO=1` qua. Kịch bản áp: `db-fix/boom_l258_ap_dung.sh`. Chưa hỏi mô hình trên bản này.
- **ĐÃ ÁP máy chủ 20/11 13:40** (Chủ Quán bảo "Áp lên"), mốc hoàn tác `20261120_134013` (`ROLLBACK=1 bash db-fix/boom_l258_ap_dung.sh 20261120_134013`). Kiểm sau áp: `logic.ts` trên máy chủ khớp bản mới, hàm trả 401 khi không có vé, container không tự khởi động lại, log không lỗi, `boom_changelog` có dòng "lần 258". Chưa có lượt hỏi thật nào đi qua bản này lúc kiểm.

**Phần app — đề xuất, chờ Chủ Quán quyết** (đề xuất 2 và 3 phải phát hành app; đề xuất 1 hoá ra làm ở máy chủ, xem mục lần 259 bên dưới):

1. **Giá vốn theo công thức** (Chủ Quán bảo "Làm đi" 20/11 → lần 259): món bán có công thức đủ giá nguyên liệu thì dùng luôn "giá vốn / phần" của công thức làm giá vốn món. Chủ quán không phải làm gì thêm; lợi ngay cho 2 / 7 quán (quán T: 16% → 47% doanh thu có giá vốn).
2. **Màn nhập nhanh giá vốn**: một màn liệt kê các món doanh thu cao nhất còn thiếu giá vốn, mỗi món một ô, lưu một lần; mở được từ câu trả lời của Boom. Hiện phải vào Kho hàng → Thao tác trên món → Sửa thông tin món → ô Giá vốn, từng món một. Lợi cho 5 / 6 quán đã đo.
3. **Lời nhắc ghi chi**: 5 / 7 quán không ghi phiếu chi nào trong 30 ngày. Nhắc lúc đóng ca hoặc đầu tháng (tiền mặt bằng, lương, nguyên liệu). Lợi lớn nhất nhưng đòi chủ quán đổi thói quen, nên xếp sau.

### 20/11 — Lần 259: giá vốn theo công thức (ĐÃ ÁP máy chủ 20/11 14:13)

**Chỗ sửa.** Đọc mã thì thấy không cần phát hành app: từ 08/11 app và web đều hỏi qua máy chủ (`kBoomServerRoute = true`), giá vốn món cho Boom chỉ tính ở một chỗ là `ban_hang.ts` (`doMon`). App vốn đã hiện "Giá vốn/phần" ở màn công thức; thứ duy nhất chưa đọc số đó là Boom. Nên sửa ở mã Boom trên máy chủ (commit `b84a161`), không đổi cơ sở dữ liệu, không ghi gì vào món.

| Việc | Cách làm |
|---|---|
| Đọc công thức | `docBanHang` thêm một lượt đọc song song: `recipes` (chưa xoá, có món đích, đúng điều kiện lúc trừ kho) lồng `recipe_ingredients` theo khoá ngoại. Giá và đơn vị nguyên liệu lấy từ danh sách món đã đọc sẵn (thêm 3 cột `unit, conversion_rate, conversion_unit`). Đọc lỗi thì chỉ thiếu giá vốn công thức |
| Tính | `vonCongThuc`: mỗi dòng = lượng ÷ hệ số hao hụt, đổi sang đơn vị kho, nhân giá nhập gần nhất (không có thì giá vốn nhập tay) — như `RecipeModel.costPerServing` của app và như lượng trừ kho lúc bán. Làm tròn đồng |
| Khi nào dùng | Chỉ khi món không có giá vốn nào khác (dòng đơn lúc bán, giá nhập gần nhất, giá nhập tay đều 0). Số chủ quán nhập vẫn thắng |
| Khi nào bỏ | Một dòng bất kỳ không tính được: nguyên liệu chưa có giá, đã ẩn / xoá, dòng không gắn nguyên liệu, hoặc đơn vị không đổi được (`doiDonVi` trả null). App trong trường hợp cuối trả nguyên số lượng (coi 1 gram = 1 gói) và hiện cảnh báo vàng; Boom không dùng số đó |
| Nói rõ nguồn | Gói số thêm `von_ct` (tên món có bán lấy giá vốn công thức). Khối số thêm dòng "Giá vốn LẤY TỪ CÔNG THỨC … : tên món", chỉ kể món mà khối số có in giá vốn |

**Kiểm trên số thật (chỉ đọc, 20/11).**

- Soi 6 quán thật và quán Demo: 0 cảnh báo. Chỉ quán T có công thức dùng được; khối số 6 quán còn lại không đổi.
- Quán T: 7 công thức gắn món. 4 món được giá vốn theo công thức (30–47% giá bán), số từng món khớp cách tính bằng hàm `convert_recipe_ingredient_qty_v1` của cơ sở dữ liệu. 1 món đã có giá vốn nhập tay nên giữ số nhập tay. 1 công thức là cốt nấu theo mẻ, không phải món bán. 1 món bị bỏ vì một dòng ghi "gram" trong khi kho tính "gói" và chưa khai quy cách.
- Phần tiền món 30 ngày thuộc món có giá vốn ở quán T: 15% → 43% (món bị bỏ vì lệch đơn vị chiếm 3%; số 47% ước hôm 19/11 tính cả món này).
- Dịch vụ đọc dữ liệu thật nhận câu đọc lồng (thử với giới hạn 0 dòng, không vé: 200; câu đối chứng sai quan hệ: PGRST200).
- Test hàm 235 qua. `KHO=1 bash db-fix/boom_l259_ap_dung.sh` qua.

**Giới hạn đã biết.**

- Luật đổi đơn vị nay có ba bản chép (Dart, SQL, `ban_hang.ts`); đổi luật phải sửa cả ba. Muốn hết thì chuyển phần tính sang một hàm SQL gọi `convert_recipe_ingredient_qty_v1` (phải thêm migration).
- Báo cáo của app vẫn tính lãi gộp theo giá vốn ghi trên dòng đơn; giá vốn công thức chỉ đến Boom.
- Bản app cũ đi đường hỏi cũ (app tự gom số) không có giá vốn công thức.
- Chưa hỏi mô hình trên bản này; chưa đọc được bảng công thức bằng vé của người dùng thật (mới kiểm bằng kết nối nội bộ và lượt đọc 0 dòng).

**ĐÃ ÁP máy chủ 20/11 14:13** (Chủ Quán bảo "Áp lên"), mốc hoàn tác `20261120_141333` (`ROLLBACK=1 bash db-fix/boom_l259_ap_dung.sh 20261120_141333`, trả cả `ban_hang.ts` và `logic.ts` về bản 258). Kiểm sau áp: hai tệp trên máy chủ khớp bản mới, hàm trả 401 khi không có vé, container không tự khởi động lại, log không lỗi, `boom_changelog` có dòng "lần 259". Lúc kiểm chưa có lượt hỏi thật nào đi qua bản này, nên lượt đọc công thức bằng vé người dùng thật vẫn chưa được thấy chạy.

**Hỏi thử sau áp, 20/11 15:51** (quán T, bản web, 2 câu, 0,06 USD; Chủ Quán tự đăng nhập):

- Đường đọc công thức bằng tài khoản người dùng thật chạy: 2 lượt đọc `recipes` lồng `recipe_ingredients` qua cổng đều trả 200, log hàm không có lỗi.
- Câu "món nào lời nhất tháng này": đúng theo khối số — lãi gộp mỗi phần và tổng lãi gộp trong kỳ khớp phép tính tay (giá bán − giá vốn, nhân số phần); món lấy giá vốn công thức được ghi rõ "theo công thức"; có nhắc nhập giá vốn 3 món bán chạy còn thiếu.
- Câu "<món X> lời bao nhiêu một ly" (món X có giá vốn công thức, nhưng trong kỳ "tháng này" nằm giữa nhóm 9 món): Boom trả lời "số liệu hiện có không ghi giá bán và giá vốn của món này" và xin chủ quán tự cho số. Không bịa, nhưng vô ích vì app biết cả hai số.

**Lỗi lộ ra (có từ trước lần 259, nay dễ gặp hơn vì nhiều món có giá vốn hơn) — sửa ở lần 260 bên dưới:**

1. Khối số chỉ mang giá bán / giá vốn của 3 món chạy nhất + 3 món chậm nhất mỗi nhóm (`ban_hang.ts dungFacts`). Món ở giữa nhóm lớn không có số nào, kể cả khi câu hỏi nêu đích danh món đó.
2. Dòng "Tính sẵn lời theo nhóm: … có giá vốn X/Y món" (`logic.ts formatFacts`) lấy X từ 6 món được in, Y từ cả nhóm → đếm thiếu (quán T: in 4/9, thật là 6/9). Boom nhắc lại con số thiếu này ("trong 4 món đã có giá vốn").

Công cụ soi thêm tuỳ chọn `--cau "<câu>"` để dựng khối số đúng một câu vừa hỏi (0 đồng).

### 21/11 — Lần 260: khối số mang đủ món giữa nhóm (ĐÃ ÁP máy chủ 21/11 02:03)

Chủ Quán bảo "Sửa đi" sau lượt hỏi thử. Chỉ sửa mã máy chủ (`ban_hang.ts`, `logic.ts`), không thêm lượt đọc nào, không đụng cơ sở dữ liệu, không cần phát hành app.

| Chỗ | Trước | Nay |
|---|---|---|
| `ban_hang.ts dungFacts` | mỗi nhóm gửi 3 món chạy + 3 món chậm | gửi thêm `mid` (món có bán còn lại của nhóm) và `costed` (số món của nhóm có giá vốn, kể cả món chưa bán); gói vượt 12 KB thì chỉ giữ món giữa nhóm có giá vốn, vẫn vượt thì bỏ `mid` |
| `logic.ts` | 22 chỗ ghép `[...g.top, ...g.slow]` | một hàm `cacMon(g)` gồm cả `mid` → xếp món theo tiền lời, bài toán tiền, điểm cần chú ý, xếp theo số phần, combo đang bán, tìm món trong câu hỏi đều xét đủ món có bán |
| Dòng nhóm trong khối số | chỉ in 3 chạy / 3 chậm | in thêm "Món khác của nhóm" cho món giữa nhóm CÓ giá vốn hoặc được câu hỏi nhắc tới (không in hết: menu lớn sẽ dài thêm cả nghìn chữ mỗi câu); món chỉ trùng phần đầu tên với một món đã được nêu rõ thì không kể |
| "có giá vốn X/Y món" | X đếm trong 6 món được gửi | X = `costed` của cả nhóm |
| "Món bán chạy CHƯA có giá vốn" | chỉ xét 3 món đầu mỗi nhóm (ghi chú `shortcut` cũ) | xét mọi món có bán |
| `kichBanGia` — tên gọi tắt ứng 2 món cùng nằm trong khối số | không ra dòng nào (Boom tự chọn) | ra dòng "TÊN MÓN CHƯA RÕ … HỎI LẠI" như trường hợp B6 |

Dòng cuối là lỗi do chính thay đổi này lộ ra khi soi: khối số thấy thêm món giữa nhóm nên câu "tăng giá trà sữa" từ chỗ khớp 1 món (rồi đếm trên cả menu ra 2 món → hỏi lại) thành khớp 2 món → rơi vào nhánh im lặng có sẵn. Bộ kiểm thêm một ý vào K9: tên gọi tắt ứng ≥ 2 món mà khối số không có dòng hỏi lại lẫn dòng kịch bản thì báo.

**Kiểm trên số thật 21/11** (bản 259 lấy bằng `git worktree`, hai bản soi ở cùng một mốc giờ, 0 đồng): 0 cảnh báo trên 6 quán thật + Demo ở cả hai bản.

| Quán | Câu mẫu đổi khối số | Khối số dài thêm | Đổi gì |
|---|---|---|---|
| T | 18 / 19 | 7,2% | in 2 món giữa nhóm có giá vốn công thức; đếm 6/9 thay 4/9; xếp lời trên 6 món; món chưa có giá vốn thứ hai đổi sang món giữa nhóm doanh thu cao hơn (3 món cộng 45% thay 41%); thêm một điểm cần chú ý |
| D | 3 / 19 | 0,4% | "xếp theo số phần" nay đúng 5 món nhiều phần nhất (trước sót 2 món giữa nhóm 13 và 9 phần, kể 2 món 5 và 4 phần); danh sách combo đang bán đủ hơn 2 món; tên gọi tắt ứng 6 món → hỏi lại |
| E | 2 / 19 | 0,2% | "xếp theo số phần" đổi 1 món cho đúng; câu tên gọi tắt in các món giữa nhóm cùng tên |
| C | 1 / 19 | 0,2% | tên gọi tắt ứng 2 món cùng nằm trong khối số → hỏi lại (trước im lặng) |
| A, B, Demo | 0 | 0 | không đổi |

Hai câu đã hỏi thử ở quán T, dựng lại khối số bằng `--cau`: món được hỏi nay có giá bán và giá vốn công thức; hai món giữa nhóm khớp phép tính tay (giá bán − giá vốn, nhân số phần).

Test hàm 236 qua (thêm 1 test, sửa 1 chỗ mong đợi cũ: tên gọi tắt ứng 2 món nay ra dòng hỏi lại thay cho chuỗi rỗng).

**Giới hạn đã biết.** Món giữa nhóm chưa có giá vốn và không được nhắc tên thì vẫn không in (cố ý, để khối số không dài). Menu rất lớn (gói vượt 12 KB) thì mất món giữa nhóm chưa có giá vốn, trở về như bản 259 cho các món đó. Gói số từ app bản cũ (đường hỏi cũ) không có `mid`, `costed` → như trước. Chưa hỏi mô hình trên bản này, chưa chấm mù.

**ĐÃ ÁP máy chủ 21/11 02:03** (Chủ Quán bảo "Áp lên"), mốc hoàn tác `20261121_020327` (`ROLLBACK=1 bash db-fix/boom_l260_ap_dung.sh 20261121_020327`, trả cả `ban_hang.ts` và `logic.ts` về bản 259). Kiểm sau áp: hai tệp trên máy chủ khớp bản mới, có dấu bản 260; sao lưu đủ 2 tệp; container chạy, không tự khởi động lại, healthy; log không có dòng lỗi; `boom_changelog` có dòng "lần 260"; gọi hàm không vé trả 401. Lúc áp là 2 giờ sáng nên chưa có lượt hỏi thật nào của quán đi qua bản mới.

**Hỏi lại sau áp, 21/11 02:05** (quán T, bản web, 1 câu, 0,03 USD): đúng câu "<món X> lời bao nhiêu một ly" hôm trước Boom không trả lời được. Nay Boom nêu giá bán, giá vốn "theo công thức" và lãi gộp mỗi ly, cả ba khớp phép tính tay; có nói rõ chưa trừ mặt bằng, lương, điện nước và ghi kỳ số liệu. Log hàm không có lỗi. Mới hỏi 1 câu, chưa chấm rộng.

### 21/11 — Lần 261: ba lỗi nhỏ còn tồn từ giai đoạn 2 (ĐÃ ÁP máy chủ 21/11 02:40)

Chủ Quán bảo "Sửa đi". Chỉ sửa mã máy chủ, cả ba đều làm bằng mã, không thêm lời dặn chung.

| Lỗi | Nguyên nhân | Sửa |
|---|---|---|
| "món nào nên bỏ" chỉ nêu món ít phần của một nhóm, sót món cùng số phần ở nhóm khác | dòng "Món bán ÍT PHẦN NHẤT" chỉ ra khi câu có "chậm nhất / ít nhất / ế nhất…"; câu hỏi bỏ món không có dòng tính sẵn nên mô hình tự chọn; dòng cũ cắt đúng 3 món dù món thứ tư cùng số phần | `logic.ts formatFacts`: câu hỏi bỏ / cắt / ẩn / dẹp món cũng ra dòng này; món đồng số phần với món thứ ba được kể luôn (tối đa 6), còn nữa thì ghi "và N món khác cũng X phần (chưa kể tên)" |
| "gio nao quan e khach nhat" bị trả lời giờ ĐÔNG nhất | mô hình đọc "e" không dấu thành câu hỏi đông khách; mã không có luật nào | `logic.ts goTat`: các cụm không dấu "e khach / e am / e hang / e nhat / e qua / ban e / bi e" (và câu không có sẵn chữ "ế") → thêm "e = ế (vắng khách / bán chậm, KHÔNG phải đông khách)" vào dòng "CÁCH GÕ TẮT TRONG CÂU"; "e" = "em" ("e muon hoi", "quan e ban…") không dính |
| kỳ này chưa có đơn mà cùng kỳ trước cũng 0 đơn → khối số không có gì về kỳ trước | `ban_hang.ts docBanHang` chỉ dựng `prev_zero` khi kỳ này có đơn | kỳ này 0 đơn và cùng kỳ trước 0 đơn → vẫn dựng `prev_zero` và đọc trọn kỳ trước làm mốc; dòng trong khối số đổi đuôi thành "kỳ này chưa có đơn nên CHƯA so được, chỉ nêu làm mốc" |

Bộ kiểm: K8 nay xét cả khi kỳ này chưa có đơn; thêm K22 (câu hỏi bỏ món phải có dòng "Món bán ÍT PHẦN NHẤT").

**Kiểm trên số thật 21/11** (bản 260 lấy bằng `git worktree`, cùng mốc giờ, 0 đồng): bản 261 0 cảnh báo trên 6 quán thật + Demo; bản 260 bị K22 báo ở cả 7 quán. Mỗi quán đổi 1–5 trên 18–19 câu mẫu, khối số dài thêm 0,06%–0,72%. Ba quán có nhiều món chỉ bán 1 phần: dòng cũ kể 3 món bất kỳ trong số đó, dòng mới kể 6 món và ghi còn 1, 11, 22 món nữa cùng 1 phần. Dựng riêng bằng `--cau`: câu "gio nao quan e khach nhat" có dòng "e = ế"; câu "hôm nay so với hôm qua" lúc sáng chưa có đơn ở hai quán có dòng kỳ so sánh 0 đơn kèm số trọn hôm qua.

Test hàm 237 qua (thêm 1 test bỏ món, thêm ca cho `goTat` và cho kỳ so sánh 0 đơn).

**Thấy khi soi (đã sửa ở lần 262 bên dưới):** sáng Thứ 2 hỏi "tuần này so với tuần trước" (kỳ so sánh là trọn tuần trước, có đơn) thì khối số vừa dặn "KHÔNG nói giảm 100%" vừa in sẵn "GIẢM 100% theo trung bình mỗi ngày" và bảng "GIẢM Ở ĐÂU … −100%", và ghi "kỳ mới có 1 ngày có đơn" khi chưa có đơn nào. Lần 162 đã kiểm là mô hình theo lời dặn, nên để nguyên; muốn sạch thì bỏ các dòng tính % khi kỳ này 0 đơn.

**Giới hạn đã biết.** Chưa hỏi mô hình trên bản này: riêng lỗi chữ "e" chỉ chắc là khối số đã ghi chú, chưa chắc mô hình trả lời đúng. Cụm "ban e" không dấu cũng có thể là "bạn em" (mã có sẵn đã coi là "bán ế" từ trước).

**ĐÃ ÁP máy chủ 21/11 02:40** (Chủ Quán bảo "Áp lên"), mốc hoàn tác `20261121_024051` (`ROLLBACK=1 bash db-fix/boom_l261_ap_dung.sh 20261121_024051`, trả cả `ban_hang.ts` và `logic.ts` về bản 260). Kiểm sau áp: hai tệp trên máy chủ khớp bản mới, có đủ ba dấu của bản 261; sao lưu đủ 2 tệp; container chạy, không tự khởi động lại, healthy; log không có dòng lỗi; `boom_changelog` có dòng "lần 261"; gọi hàm không vé trả 401. Lúc áp chưa có lượt hỏi thật nào của quán đi qua bản mới.

**Hỏi thử sau áp, 21/11 03:24** (quán T, bản web, 1 câu, 0,058 USD vì lượt này có thêm bước kiểm số nên gọi mô hình hai lần): câu "gio nao quan e khach nhat" — hôm 18/11 Boom trả lời giờ ĐÔNG nhất. Nay Boom trả lời giờ VẮNG nhất trong giờ bán chính, đúng giờ mà khối số tính sẵn; doanh thu của giờ đó, của hai giờ đem ra so và tổng khung giờ bán chính đều khớp khối số. Log hàm không có lỗi. Hai lỗi còn lại (bỏ món, kỳ so sánh 0 đơn) chưa hỏi mô hình, mới kiểm ở khối số.

### 21/11 — Lần 262: kỳ chưa có đơn thì không in sẵn "giảm 100%" (ĐÃ ÁP máy chủ 21/11 04:00)

Chủ Quán bảo "Sửa đi". Chỉ sửa `logic.ts formatFacts`, không đụng `ban_hang.ts`, không thêm lượt đọc nào.

Trước: kỳ đang chạy (tuần này / tháng này) hoặc một ngày mà chưa có đơn nào, khối số có dòng dặn "KHÔNG nói giảm 100%" nhưng ngay dưới lại in sẵn "… → GIẢM 100% theo trung bình mỗi ngày", bảng "SO … — GIẢM Ở ĐÂU" với mọi nhóm −100%, và "Kỳ mới có N ngày có đơn" (N ≥ 1 dù chưa có đơn).

Nay: một cờ `chuaDon` (kỳ 0 đơn và là tuần này / tháng này / một ngày) → không tính % với kỳ trước, dòng kỳ trước kết bằng "Kỳ này chưa có đơn nào → chỉ nêu số kỳ trước làm mốc, KHÔNG tính % tăng giảm"; không in bảng "GIẢM Ở ĐÂU"; dòng kỳ ngắn ghi "Kỳ chưa có đơn nào"; câu dự báo "hôm nay" không so "thấp hơn 100%" với cùng giờ hôm qua. Kỳ ĐÃ QUA trọn mà 0 đơn (cả tháng trước không bán) giữ nguyên "GIẢM 100%" vì đó là số thật.

Bộ kiểm thêm K23: khối số ghi kỳ này chưa có đơn mà vẫn có "GIẢM 100%" / "−100%)" thì báo.

**Kiểm trên số thật 21/11** (bản 261 lấy bằng `git worktree`, cùng mốc giờ, 0 đồng): bản 262 0 cảnh báo trên 6 quán thật + Demo; bản 261 bị K23 báo ở 2 quán. Chỉ đúng 2 câu mẫu đổi khối số (một câu "tuần này so với tuần trước" ở quán chưa có đơn tuần này, một câu "hôm nay bán được bao nhiêu" lúc chưa có đơn), các câu khác giữ nguyên từng chữ. Dựng riêng tình huống sáng Thứ 2 ở quán T: hai dòng "giảm 100%" không còn.

Test hàm 237 qua (thêm ca vào test "tuần này chưa có đơn": không còn "GIẢM 100%", một ngày chưa có đơn, kỳ có đơn và kỳ đã qua trọn giữ như cũ).

**Thấy khi soi, CHƯA sửa:** dòng kỳ trước ghi "7 ngày mở bán" cho trọn tuần trước dù quán chỉ có đơn 5 ngày (khối số không có số từng ngày của kỳ trước ở nhánh này), nên trung bình mỗi ngày của kỳ trước bị thấp hơn trung bình ngày có đơn.

**ĐÃ ÁP máy chủ 21/11 04:00** (Chủ Quán bảo "Áp lên"), mốc hoàn tác `20261121_040057` (`ROLLBACK=1 bash db-fix/boom_l262_ap_dung.sh 20261121_040057`, trả `logic.ts` về bản 261). Kiểm sau áp: `logic.ts` trên máy chủ khớp bản mới và có dấu bản 262, `ban_hang.ts` vẫn là bản 261; sao lưu có `logic.ts`; container chạy, không tự khởi động lại, healthy; log không có dòng lỗi; `boom_changelog` có dòng "lần 262"; gọi hàm không vé trả 401. Chưa có lượt hỏi thật nào đi qua bản mới; chưa hỏi mô hình trên bản này.

### 21/11 — Đọc và chấm câu hỏi thật của khách (12/11–18/11)

Chủ Quán bảo kiểm các câu khách hỏi Boom, chấm điểm, xem có cần dạy lại. Đọc `boom_qa_log` + `boom_qa_full` (chỉ đọc), bỏ quán Demo và 31 lượt Claude hỏi thử ở quán T (18, 20, 21/11). Tệp này KHÔNG ghi nguyên văn câu hỏi, tên quán, số liệu quán; bản sao tạm nằm ngoài repo.

**Số đếm:** 110 lượt ghi sổ của 18 quán + 29 lượt app tự trả lời; 25 lượt lỗi (HTTP 401, khoá OpenAI hỏng 15–16/11, 13 câu hỏi khác nhau ở 4 quán), 6 lượt không ra câu trả lời. Chấm 99 lượt có câu trả lời (thang 0–10, Claude chấm; 8 lượt là thẻ hướng dẫn khách tự bấm, không chấm): trung bình 5,4; đạt (7–10) 48, tạm (4–6) 20, hỏng (0–3) 31. Một lượt bị chê (đã sửa ở lần 250).

| Loại câu | Lượt | Điểm TB | Hỏng |
|---|---|---|---|
| Cách dùng app | 50 | 5,6 | 15 |
| Số liệu quán | 18 | 6,3 | 4 |
| Trò chuyện, hỏi về app / dữ liệu | 14 | 5,1 | 6 |
| Thời tiết (câu gợi ý ở Trang chủ) | 13 | 4,5 | 5 |
| Tư vấn / lương | 4 | 4,5 | 1 |

Điều thấy rõ nhất: khách hỏi CÁCH DÙNG APP là chính (một nửa số lượt: máy in, chấm công, xoá bill, tài khoản nhân viên, sửa món, nhiều quán), không phải phân tích kinh doanh. Bộ đo tự soạn và các lần 250–262 gần như không chạm tới phần này.

**Nhóm cần làm (xếp theo mức hại):**

| # | Hiện tượng | Lượt / khách | Loại việc |
|---|---|---|---|
| 1 | Hỏi dữ liệu có an toàn không → Boom nói "chưa thấy thông tin, không dám khẳng định an toàn"; khách kết luận không dùng app; câu chốt của khách có chữ "cảm ơn" nên app đáp câu có sẵn "Dạ không có gì ạ!" | 4 / 1 | Thiếu bài hướng dẫn (cần Chủ Quán cho nội dung) + sửa app |
| 2 | Câu nối tiếp ngắn ("ở chỗ nào", "không thấy", "bước số 4") → Boom quên bài vừa dùng, bảo gọi Hotline, trái với câu trước | 4 / 3 | Sửa mã (giữ bài hướng dẫn của lượt trước) |
| 3 | Bài CÓ SẴN nhưng Boom nói "chưa thấy hướng dẫn": vào nhiều quán, nhân viên làm ở quán khác, cài chấm công (gõ sai chính tả), chủ quán xoá bill đã thu, thêm máy in từ điện thoại / iPhone, nhập món hàng loạt | 9 / 5 | Bổ sung cách hỏi / câu trả lời thẳng vào bài hướng dẫn |
| 4 | Lúc khoá OpenAI hỏng: khách bấm chính câu gợi ý thời tiết của app thì nhận "Bé Boom chưa hiểu rõ lắm, hãy hỏi doanh thu hôm nay…" | 5 / 5 (+25 lượt lỗi) | Sửa app: báo đúng là Boom đang trục trặc |
| 5 | Xin đổi cách xưng hô ("gọi tôi là …") → Boom trả lời vòng vo, không đổi; khách chê | 6 / 1 | Sửa mã (ghi nhớ cách gọi) |
| 6 | Hỏi theo ngày cụ thể ("thứ 6 tuần rồi bán bao nhiêu phần …"): app tự chặn kỳ dù máy chủ trả lời được; lượt sau Boom nói "không xem được báo cáo, gửi ảnh" | 3 / 1 | Sửa app (không chặn kỳ ở app) |
| 7 | "Mã quán" bị hiểu thành mã giảm giá | 1 / 1 | Sửa mã |
| 8 | Hỏi tính hoa hồng / lương theo % (tiệm dịch vụ), cho người góp vốn cùng xem: app chưa có hoặc chưa có bài → "chưa thấy hướng dẫn" | 4 / 2 | Thêm mục "app chưa có…" + cách làm thay |
| 9 | Câu thời tiết bị gắn đuôi "Số trên là của 30 ngày qua" (bản hiện tại vẫn còn) | 2 / 1 | Sửa mã máy chủ, nhỏ |
| 10 | Câu lặp lần ba không ra câu trả lời → app in số bán hàng không liên quan | 1 / 1 | Sửa app |

Đã sửa rồi, không cần làm: "món chưa bán" kể cả nguyên liệu (lượt bị chê, lần 250); kỳ so sánh, bỏ món, chữ "e" (lần 253–262). Kiểm 0 đồng trên bản hiện tại: máy chủ đọc đúng kỳ "thứ 6 tuần rồi" và có số món được hỏi (lỗi ở #6 nằm phía app); dòng kỳ thừa ở câu thời tiết vẫn còn.

### 22/11 — Lô 1 theo câu hỏi thật của khách: lần 263 (mã máy chủ) + 8 mục hướng dẫn mới (ĐÃ ÁP mã 22/11 05:18, ĐÃ ĐĂNG bài)

Chủ Quán bảo "Làm lô 1". Điều tìm ra trước khi sửa: bài hướng dẫn do APP tự tìm (chấm điểm theo chữ, tên mục nặng điểm nhất) rồi gửi mã bài lên máy chủ; máy chủ không tự tìm. Vì vậy nhóm "có bài mà Boom nói chưa thấy" là do app chọn nhầm bài, chữa bằng tên mục và nội dung bài; nhóm "câu nối tiếp ngắn" là do câu ngắn không tìm ra bài nào, chữa ở máy chủ.

**Phần 1, bài hướng dẫn (7 bài, thêm 8 mục, sửa tên 4 mục; chỉ ghi điều đã có trong bài cũ hoặc đã kiểm trong mã app):**

| Bài | Bổ sung |
|---|---|
| Bắt đầu dùng app | mục "đổi quán" thêm cách hỏi vào 2–3 quán, nhiều chi nhánh, nhân viên làm ở cửa hàng khác; mục "dữ liệu của quán" thêm lưu ở đâu, có an toàn, có bị lộ không; mục "app chưa có" thêm tính hoa hồng |
| Nhân viên | xem mã quán ở đâu (không phải mã giảm giá); cho cổ đông, kế toán, người nhà cùng xem quán; đổi cách Bé Boom xưng hô và tên hiển thị |
| Chấm công | chấm công ở đâu, mở ô Chấm công, thiết lập lần đầu |
| Bán hàng | xoá bill / hoá đơn đã thanh toán (Chủ quán cũng chưa xoá được); mã QR chuyển khoản |
| In Hoá Đơn | thêm máy in từ điện thoại iPhone / Android (máy in mạng; chưa có Bluetooth) |
| Kho hàng | thêm nhiều món một lúc, nhập từ Excel: chưa có |
| Tính Lương | hoa hồng, lương theo % doanh thu: chưa có, cách làm thay |

Thử 0 đồng bằng chính bộ tìm bài của app, trên 18 câu khách đã hỏi mà Boom không trả lời được: trước khi sửa bài đúng đứng đầu ở 1 / 18 câu, sau khi sửa 18 / 18. Soát chữ của bài: 0 lỗi. Bộ test của app 131 qua (gồm bộ câu hỏi kiểm tra tìm bài).

**Phần 2, lần 263 (mã máy chủ):**

- `logic.ts noiTiepHuongDan` + `index.ts`: câu nối tiếp ngắn kiểu "ở chỗ nào", "không thấy", "bước 4" mà app không gửi bài nào → máy chủ dùng lại các bài của lượt ngay trước (≤ 10 phút, đọc `boom_qa_log.chunk_ids`); nhãn loại câu thêm `+lai`. Để làm được, lượt hỏi "ask" có bài hướng dẫn nay ghi mã bài vào sổ (trước để trống; hàm giữ chỗ chỉ lưu, không tính hạn mức theo mã bài).
- `logic.ts ghiKy`: câu chỉ hỏi thời tiết không gắn "Số trên là của …".
- Test hàm 238 qua. Phần dùng lại bài chưa thử được trước khi áp (cần máy chủ thật) → sau áp phải hỏi thử hai lượt liên tiếp.

**Nhóm trong bảng 21/11 đã có lời giải:** #2 (mã), #3, #5, #7, #8 (bài), #9 (mã); #1 mới làm phần tìm đúng bài, nội dung về an toàn dữ liệu vẫn chờ Chủ Quán (lô 2); #4, #6, #10 ở app (lô 3).

**Lưu ý khi đăng bài:** `dang_huong_dan_boom.sh` đăng mọi bài đang có trong máy, gồm cả 3 bài một phiên khác đang sửa dở chưa lưu (màn Phiếu bếp mới, đã lên web, chưa có trong app cài máy). So với bản đang đăng (442 đoạn): thêm đúng 8 đoạn của lô này, không bớt đoạn nào.

**ĐÃ ÁP mã 22/11 05:18** (Chủ Quán bảo "Áp và đăng"), mốc hoàn tác `20261122_051844` (`ROLLBACK=1 bash db-fix/boom_l263_ap_dung.sh 20261122_051844`, trả `index.ts` và `logic.ts` về bản 262). Kiểm sau áp: hai tệp khớp bản mới, có dấu bản 263; sao lưu đủ 2 tệp; container chạy, không tự khởi động lại, healthy; log không có dòng lỗi; `boom_changelog` có dòng "lần 263"; gọi hàm không vé trả 401.

**ĐÃ ĐĂNG bài 22/11**, bản hướng dẫn `202611212224`, 450 đoạn (bản trước `202611190729`, 442 đoạn; muốn quay lại thì đăng lại bộ bài cũ thành một bản mới, không xoá dòng). Lần đăng đầu bị bộ câu hỏi kiểm tra của app CHẶN: 4 mục mới lấn câu trả lời của 4 câu trong bộ kiểm tra (cài lương theo giờ, đổi tên hiển thị, mở thêm chi nhánh, nhân viên vào ca bấm ở đâu) làm tỷ lệ trả lời sai của bộ độc lập lên 10,2% (ngưỡng 10%). Đã gọt chữ trong các mục đó (bỏ các chữ trùng với mục có sẵn) rồi mới đăng. So với bộ bài cũ trên cùng bộ kiểm tra: không thêm câu trả lời sai nào; top-1 giảm 1–2 câu ở hai bộ (81 → 80%, 75 → 73%), top-3 giữ nguyên; 2 câu mất bài đúng ở mép vị trí thứ 8, 1 câu được lại. Trên 18 câu khách thật: bài đúng đứng đầu 17 câu, câu còn lại (gõ sai chính tả) có bài đúng trong nhóm gửi kèm.

**Bài học:** thêm mục mới vào bài hướng dẫn phải chạy `boom_help_eval_test.dart` với bộ bài đã xuất lại (không chỉ `flutter test` trên bộ bài cũ): tên mục và chữ trong mục mới lấn điểm của mục có sẵn.

**Hỏi thử sau áp, 22/11 05:40–05:45** (quán T, bản web, 3 câu, 0,059 USD; Chủ Quán tự đăng nhập):

- Câu cách làm ("chấm công thế nào"): trả lời đúng các bước; sổ nay ghi 6 mã bài của lượt này (trước lần 263 để trống).
- Câu nối tiếp ngắn ("ở chỗ nào vậy"): nhãn có `+hd+lai`, máy chủ dùng lại đúng 6 bài của lượt trước → cơ chế chạy. NHƯNG câu trả lời vẫn là "chưa thấy đoạn hướng dẫn chỉ rõ chỗ mở mục này, gọi Hotline": 6 bài đó chỉ ghi các bước, không bài nào ghi mục nằm ở đâu. Lần 263 vì thế chưa đạt mục đích với người dùng.
- Câu về xoá bill đã thu: app gửi đúng mục mới (xác nhận app đã nhận bản hướng dẫn mới), Boom trả lời thẳng "không xoá, huỷ hay hoàn tiền được", chỉ chỗ đối chiếu. Trước đây câu này ra "chưa thấy hướng dẫn, gọi Hotline".

### 22/11 — Lần 264: câu nối tiếp chỉ đường từ ô ở Trang chủ (ĐÃ ÁP máy chủ 22/11 16:22)

Sửa chỗ hỏng thấy ở lượt hỏi thử trên. `logic.ts khoiHuongDan(chunks, noiTiep)`: khi các đoạn là bài dùng lại của lượt trước, thêm một dòng tính sẵn: đây là câu nối tiếp hỏi lại chỗ / báo không thấy; không trả lời "chưa thấy hướng dẫn", không bảo gọi Hotline; chỉ đường từ đầu là mở ô của mục đó ở Trang chủ (bảng `O_TRANG_CHU`: tên bài → tên ô, lấy theo bài "Bắt đầu dùng app" việc 22; chưa thấy ô thì Chủ quán bấm "Sửa", cuối trang bấm "Thêm"), rồi nêu lại bước và tên nút. Bài không có ô riêng thì chỉ nêu lại bước. `index.ts` truyền cờ `hdLai`. Test hàm 238 qua. 

**ĐÃ ÁP máy chủ 22/11 16:22** (Chủ Quán bảo "Áp và hỏi lại"), mốc hoàn tác `20261122_162207` (`ROLLBACK=1 bash db-fix/boom_l264_ap_dung.sh 20261122_162207`, trả `index.ts` và `logic.ts` về bản 263). Kiểm sau áp: có dấu bản 264; container chạy, không tự khởi động lại, healthy; log không có dòng lỗi; `boom_changelog` có dòng "lần 264"; hàm trả 401 khi không có vé.

**Hỏi lại sau áp, 22/11 16:24–16:26** (quán T, bản web, 2 câu liên tiếp): câu "chấm công thế nào" trả lời các bước như trước; câu nối tiếp "ở chỗ nào vậy" nay được trả lời: mở ô "Chấm công" ở Trang chủ, chưa thấy ô thì bấm "Sửa", cuộn xuống cuối bấm "Thêm", rồi nhắc lại bước vào ca. Không còn "chưa thấy hướng dẫn, gọi Hotline". Mới thử một bài (Chấm công); các bài khác dùng cùng cơ chế nhưng chưa hỏi thật.

