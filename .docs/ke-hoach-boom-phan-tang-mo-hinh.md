# Kế hoạch: phân tầng mô hình cho Boom theo loại câu hỏi (15/11/2026, NHÁP — chưa làm gì)

Mục tiêu: câu nào mã đã lo được thì dùng mô hình rẻ (hoặc không gọi mô hình), chỉ câu phải lập luận mới dùng mô hình đắt.
Đo bằng hai con số cùng lúc: **điểm chấm mù** và **tiền mỗi câu**. Không chốt danh sách bằng cảm tính.

## 1. Hiện trạng (đọc từ mã ngày 15/11)

- Mọi lượt gọi dùng một mô hình: `gpt-6-luna`, không suy nghĩ (`BOOM_REASONING=none`). Giá đang ghi trong mã: 0,1 USD / triệu
  token vào, 0,5 USD / triệu token ra.
- **Câu tư vấn đang gọi HAI lượt song song** (lần 214, `index.ts` dòng 824): một lượt không suy nghĩ và một lượt suy nghĩ thấp, lượt
  thấp xong trong 9 giây thì dùng. Cả hai lượt đều tính tiền. Trên Demo 16 lượt chỉ 1 lượt dùng được bản suy nghĩ thấp → phần lớn
  tiền lượt thứ hai đang bỏ đi.
- Bị kiểm số bắt lỗi thì viết lại thêm 1 lượt, cùng mô hình.
- Đã có sẵn bộ phân loại bằng mã `loaiCau()` (`logic.ts` dòng 2458): `quyet_dinh`, `ke_hoach`, so sánh, dự báo, chẩn đoán
  (vì sao), `noi_tiep`, và `null` (viết nội dung, hỏi app, chào hỏi, câu còn lại). Dùng lại, không viết bộ mới.
- Đã đo: cho Boom tự gọi công cụ −1,19 (bỏ); thêm lời dặn ~0; suy nghĩ thấp +0,65 ± 0,45 nhưng quá giờ 16 giây.
- Chưa biết: token và tiền trung bình theo từng loại lượt trên sổ thật (xem bước 0).

## 2. Bản đồ câu hỏi → tầng (GIẢ THUYẾT, bước 2 mới quyết)

| Nhóm câu hỏi | Ví dụ | Ai làm phần khó | Tầng đề xuất |
|---|---|---|---|
| Số nhanh | "hôm nay bán bao nhiêu" | app tự tính | 0: không gọi mô hình |
| Câu đã có trong bộ đệm đã duyệt | câu lặp lại | bộ đệm | 0 |
| Lệnh nhớ / quên, "Boom nhớ gì" | "nhớ giúp quán nghỉ thứ Hai" | mã | 0 hoặc 1 |
| Quán chưa có đơn trong kỳ | bất kỳ | mã rút gọn | 1 |
| Cách dùng app | "in lại bill ở đâu" | bài hướng dẫn | 1: rẻ, không suy nghĩ |
| Viết nội dung | bài đăng, caption, tin nhắn | dòng tính sẵn món + giá + giờ | 1 |
| Nối tiếp ngắn | "cụ thể hơn" | câu trước | 1 |
| Chỉ hỏi thời tiết | "mai mưa không" | khối dự báo | 1 |
| Phép tính có dòng tính sẵn | hoà vốn, bán gấp mấy lần, nấu mấy phần, trả nợ, giá trên sàn | mã | 1 |
| Việc chạy nền | rút ghi nhớ, dọn bộ nhớ | — | 1 |
| Quyết định có đánh đổi | "có nên thuê thêm người" | mô hình | 2: đắt |
| Nguyên nhân | "vì sao tuần này giảm" | mô hình | 2 |
| Kế hoạch nhiều bước | "tháng tới làm gì để tăng đơn chiều" | mô hình | 2 |
| So sánh nhiều vế, dự báo | "nhóm nào chạy hơn tháng trước" | lẫn | đo mới biết |
| Câu lạ: dài, không dòng tính sẵn nào bật | — | mô hình | 2 |
| Viết lại sau khi kiểm số bắt lỗi | — | mô hình | 2 |

Phân loại **bằng mã, không gọi mô hình để phân loại** (gọi thêm một lượt để phân loại là tốn ngược). Tín hiệu, theo thứ tự:
1. chế độ lượt (`answer` hướng dẫn / `advice` tư vấn / chạy nền);
2. `loaiCau()`;
3. có dòng tính sẵn nào bật cho câu này không (mã biết sẵn lúc ghép lời nhắc);
4. lưới an toàn: câu xếp tầng 1 mà bị kiểm số bắt lỗi → lần viết lại lên tầng 2.

Xếp nhầm thì rơi về tầng rẻ (như hiện nay), không tệ hơn bây giờ.

## 3. Các bước

**Bước 0 — Đo nền tiền (chỉ đọc, chỉ số đếm).** Từ `boom_qa_log` 30 ngày: số lượt, token vào / ra trung bình, tiền, số giây, tỉ lệ
viết lại, tỉ lệ lượt `+low` — chia theo nhãn lượt. Không đọc nội dung câu hỏi. Cần Chủ Quán cho phép (lệnh đọc máy chủ đang bị chặn).

**Bước 1 — Gắn nhãn bộ câu hỏi.** Chạy `loaiCau()` + cờ "có dòng tính sẵn" trên các bộ kín đã có (de_kin12 → de_kin23, khoảng
500 câu) và, nếu Chủ Quán cho, trên câu hỏi thật. Ra bảng: mỗi nhóm ở mục 2 chiếm bao nhiêu % câu. Nhóm nào dưới 15 câu thì nhờ
trợ lý độc lập viết thêm (Claude không đọc đề, như các bộ kín trước).

**Bước 2 — Đo ba cấu hình trên từng nhóm.** (a) rẻ, không suy nghĩ; (b) rẻ, suy nghĩ thấp; (c) mô hình đắt. Cùng khối số, cùng
mã kiểm, chấm mù theo `THANG_CHAM.md`. Ghi cho mỗi nhóm × cấu hình: điểm, token, tiền, số giây, tỉ lệ viết lại.

**Bước 3 — Bảng quyết định.** Một nhóm lên tầng 2 khi cả ba đúng:
- hơn bản rẻ từ 1,0 điểm / 16, khoảng tin cậy không chạm 0;
- số giây ở mức 90% lượt nằm trong giới hạn chờ (hiện 16 giây; nếu vượt thì nhóm đó phải chờ việc hiện chữ dần);
- tiền mỗi câu nằm trong hạn mức quán / ngày đang đặt.
Không đạt thì ở tầng 1. Giữa (b) và (c): chọn bản rẻ hơn nếu điểm chênh dưới 0,5.

**Bước 4 — Viết mã.** Một hàm `chonTang(che_do, loai, co_tinh_san, da_bi_bat_loi)` trong `logic.ts` + kiểm thử trong
`logic_test.ts`; `callGpt` nhận mô hình theo tầng; **bỏ gọi song song lần 214** (tầng đã quyết trước khi gọi). Công tắc
`BOOM_TANG=1`, tắt thì chạy y như hiện nay. Sổ ghi thêm nhãn `+t2` để về sau đếm được.

**Bước 5 — Kiểm tổng.** Bộ kín MỚI 90 câu: bản phân tầng so bản đang chạy. Áp khi điểm tổng không giảm và tiền mỗi câu giảm,
hoặc điểm tăng rõ với tiền nằm trong hạn mức.

**Bước 6 — Áp.** Hỏi Chủ Quán, script `db-fix/boom_lNNN_ap_dung.sh` có `ROLLBACK=1`, thêm dòng `boom_changelog`, ghi `nhat_ky.md`.

## 4. Tiền dự kiến đổi thế nào

- Tiết kiệm chắc chắn: bỏ lượt song song → mỗi câu tư vấn tầng 1 từ 2 lượt còn 1 lượt.
- Tốn thêm: câu tầng 2 một lượt mô hình đắt. Tổng lên hay xuống tuỳ tỉ lệ câu tầng 2 (bước 1) và giá mô hình đắt (bước 2).
- Chưa có con số cho tới khi xong bước 0–2.

## 4b. Bảng giá các mô hình ứng viên (tra 15/11/2026, USD / triệu token)

| Mô hình | Vào | Ra | Gấp mấy lần Luna | Nguồn |
|---|---|---|---|---|
| GPT-6 Luna (đang dùng) | 0,10 | 0,50 | 1 | trang tổng hợp giá, khớp số trong `index.ts` |
| GPT-6 Sol / 6.1 Sol | 2 | 10 | 20 | trang tổng hợp giá |
| GPT-6 Astra | 10 | 50 (có trang ghi 5 / 25) | 100 (hoặc 50) | trang tổng hợp giá, hai nguồn lệch nhau |
| Claude Haiku 5.5 | 0,10 | 0,50 | 1 | bảng giá Anthropic (bản lưu 03/11) |
| Claude Sonnet 5.5 | 2 | 10 | 20 | như trên |
| Claude Opus 5.5 | 4 | 20 | 40 | như trên |

Giá OpenAI lấy từ trang tổng hợp, CHƯA đối chiếu trang giá chính thức của OpenAI — phải đối chiếu trước khi chốt.
Ví dụ một câu tư vấn 5.000 token vào + 400 token ra (GIẢ ĐỊNH, bước 0 mới có số thật): Luna 0,0007 USD; Sol / Sonnet 0,014;
Opus 0,028; Astra 0,07. Trần 0,5 USD / quán / ngày khi đó tương đương khoảng 700 / 35 / 17 / 7 câu. Mô hình có suy nghĩ còn tốn
thêm token ra cho phần suy nghĩ, nên số thật sẽ cao hơn.

## 4c. Đã làm 15/11 (bước 1, chưa gọi mô hình)

Công cụ `tool/boom_do/do_15_11/do_tang.ts` (không có khoá thì chỉ gắn nhãn và đếm chữ). Trên 270 câu kín de_kin16 / 18 / 21:

- Phân bố theo `loaiCau()`: khác 116 (43%), quyết định 65, chẩn đoán 41, so sánh 38, dự báo 10, kế hoạch 0. Nhóm "khác" quá
  rộng (gồm cả viết nội dung, kho, thu chi) → khi đo phải tách thêm theo lĩnh vực; bộ kín thiếu hẳn câu kế hoạch.
- **Lời nhắc gửi đi dài khoảng 34.000–37.000 chữ mỗi câu, gần như không đổi theo loại câu** (ước 12.000–15.000 token vào, chưa
  đo). Giả định 5.000 token ở mục 4b là thấp; tiền mỗi câu bậc giữa có thể khoảng 0,03 USD chứ không phải 0,014.
- Hệ quả: token vào chiếm gần hết tiền. Rút ngắn lời nhắc theo loại câu và dùng giá token đệm (phần đầu lời nhắc giống nhau
  giữa các câu) có thể tiết kiệm nhiều hơn cả việc chọn mô hình. Cần đo `cached_tokens` thật ở bước 2.

## 4d. Kết quả đo bậc giữa 15/11 (bước 2, cấu hình a và c; chưa đo "rẻ + suy nghĩ thấp")

180 câu kín (de_kin18 + de_kin21), mỗi câu một lượt qua Luna và `gpt-6-sol`, đều không suy nghĩ. Chấm mù 180 cặp, 9 người chấm
(trợ lý Claude Opus, mỗi cặp MỘT người chấm, có dò số trong khối). Kết quả thô: `supabase/functions/boom-chat/build/do_tang_kq.json`.

| | Luna | Sol |
|---|---|---|
| Điểm / 16 | 14,31 | 15,07 (**+0,76 ± 0,26**) |
| Câu dùng được | 151 / 180 | 171 / 180 |
| Câu hỏng | 5 | 0 |
| Câu có số sai (dung_so < 2) | 14 | 1 |
| Thắng theo cặp | 37 | 98 (ngang 45) |
| Bị kiểm số bắt, viết lại | 89 | 48 |
| Token vào / ra mỗi câu | 19.700 / 384 | 16.600 / 301 |
| Giây trung bình / mức 90% | 4,9 / 7,6 | 3,4 / 5,8 |
| USD mỗi câu | 0,0022 | 0,0363 (gấp ~17) |

Theo `loaiCau()`: chẩn đoán +0,85 ± 0,68; khác +0,82 ± 0,41; quyết định +0,77 ± 0,45; so sánh +0,54 ± 0,82; dự báo +0,33 ± 0,83
(n = 6). **Không nhóm nào đạt ngưỡng +1,0 → `loaiCau()` không phải thước chia tầng tốt: Sol hơn đều ở mọi nhóm.**
Theo lĩnh vực (12 câu mỗi lĩnh vực): thời tiết **+2,50 ± 0,66**, giờ / ngày +1,50 ± 1,24, thu chi +1,17 ± 0,72; ngang: sàn giao
±0,00, nhân sự +0,08, so sánh kỳ +0,08, món +0,33. Tiêu chí lên nhiều nhất: gọn 1,65 → 1,86, tìm vấn đề 1,59 → 1,76, lý lẽ
1,66 → 1,82; việc làm không đổi (1,73 → 1,72).

Lưu ý khi đọc: hai bộ kín này từng được dùng để sửa mã chạy với Luna (lô G, H) nên nếu lệch thì lệch có lợi cho Luna; điểm tuyệt
đối không so được với các lần kiểm toàn diện trước (khác người chấm, đề không có ý chính); lỗi chung cả hai mô hình còn lại là bỏ
sót điểm khối số đã đánh dấu (hàng hết, chi phí cố định) và việc làm chung chung — đổi mô hình không chữa được.

## 5. Việc cần Chủ Quán quyết

1. Mô hình đắt là mô hình nào: bậc trên cùng nhà cung cấp hiện tại (không cần khoá mới), hay Claude (cần khoá mới + khử thông tin
   riêng tư như quy định cloud fallback trong `qn.md`).
2. Cho phép chạy bước 0 (đọc số đếm trong sổ, không đọc nội dung).
3. Trần tiền mỗi quán / ngày có giữ 0,5 USD không.

## 6. Không làm trong kế hoạch này

Hiện chữ dần khi trả lời, lời khuyên tự gửi mỗi sáng, trả lời hai bước, câu mẫu, gợi ý giá vốn — mỗi việc một kế hoạch riêng.
