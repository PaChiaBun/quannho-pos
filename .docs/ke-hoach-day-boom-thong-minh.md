# Kế hoạch dạy Boom thông minh hơn khi tư vấn chủ quán (lập 28/10/2026)

Kế hoạch này **thay** `ke-hoach-day-boom-50-lan.md`. Các lần dạy về chọn đường trong kế hoạch cũ được gộp vào Giai đoạn 1.
Kế hoạch được lập sau **một lần kiểm** các phần sau:
- Hàm máy chủ `boom-chat`: lời nhắc tư vấn `ADVICE_PROMPT`, cách ghép tin nhắn `buildMessages`, mô hình, trí nhớ.
- Số liệu app gửi kèm: `ShopFacts`, `ModuleFacts`.
- Kết quả 16 đợt dạy trước.

---

## 1. Boom đang thông minh tới đâu

| Phần | Hiện có | Điểm yếu |
|---|---|---|
| **Hiểu câu hỏi** (chọn đường) | 16 đợt dạy; câu một lượt đúng khoảng 90%; hội thoại 2 lượt 65–80% | Câu số đầu tiên còn bị đưa nhầm sang hướng dẫn; câu nói tiếp xin phân tích chỉ đúng khoảng 60% |
| **Số gửi cho GPT** | Doanh thu, số đơn, so với kỳ trước, món bán chạy / bán chậm theo nhóm, theo giờ, theo thứ, theo khung giờ, combo tính sẵn; số theo mục (thu chi, kho, chấm công, khách, voucher) là khối riêng | Không có chuỗi theo tháng / tuần, không có cùng kỳ năm trước, chưa tính sẵn tỉ lệ ngành (giá vốn %, lương %, mặt bằng %); số bán và số theo mục **không đi chung** trong một câu; kỳ dài nhất 92 ngày |
| **Cách suy luận** (lời nhắc) | Đã có: trả lời thẳng, 3–5 ý, "Cần xem lại / Việc tuần này", luật khuyến mãi, ngày lễ, mốc giá vốn 25–35%, mặt bằng dưới 15% | Lời nhắc là **một danh sách luật rất dài**, dễ chồng chéo; không có khung suy luận theo loại câu hỏi (chẩn đoán / quyết định / kế hoạch); GPT tự làm phép tính; không hỏi lại khi thiếu dữ kiện |
| **Hiểu quán** | Ngày hôm nay, ngày lễ sắp tới, 4 lượt hỏi đáp gần đây | Không biết loại quán, giá trung bình, giờ mở cửa, mục tiêu của chủ; không nhớ đã khuyên gì và kết quả ra sao |
| **Mô hình** | gpt-4o-mini, độ ngẫu nhiên 0.2, câu tư vấn tối đa 600 token | Chưa thử mô hình mạnh hơn cho câu phân tích khó |
| **Thước đo** | Bộ giả lập chọn đường (GPT giả); công cụ chấm GPT thật cho câu hỏi cách làm | **Chưa từng chấm chất lượng câu tư vấn.** Mọi con số cải thiện trước nay chỉ đo việc chọn đường |

Kết luận: để Boom **thông minh hơn**, ưu tiên theo thứ tự:
1. Có thước đo cho câu tư vấn.
2. Gửi số đủ và tính sẵn.
3. Cho GPT khung suy luận rõ.
4. Cho Boom hiểu riêng từng quán.

Chọn đường đúng vẫn cần, nhưng chỉ là điều kiện nền.

---

## 2. Thước đo "thông minh" (làm trước tiên)

### 2.1 Bộ đề tư vấn chuẩn: 60 tình huống trên 3 quán mẫu

- **Ba quán giả**, mỗi quán một file số liệu cố định, giống dữ liệu thật:
  - A: cà phê mang đi.
  - B: trà sữa có topping.
  - C: quán bún / cơm có đồ uống.
- Mỗi quán có 3 tháng số bán, thu chi, kho, chấm công, khách và voucher, trong đó cài sẵn **vấn đề có đáp án**. Ví dụ:
  - Giá vốn một món 45%.
  - Thứ Ba doanh thu tụt.
  - Một combo đắt hơn mua lẻ.
  - Lương chiếm 38% doanh thu.
  - Topping ế.
  - Khách quay lại giảm.
- **60 câu hỏi** chia 6 loại, mỗi loại 10 câu:

| Loại | Ví dụ |
|---|---|
| Chẩn đoán | "sao tháng này lời ít vậy" |
| Quyết định | "có nên tăng giá bạc xỉu lên 30k không" |
| Kế hoạch | "lên kế hoạch tăng doanh thu tháng 11" |
| So sánh | "tuần này so tuần trước sao" |
| Dự báo | "ước cuối tháng được bao nhiêu" |
| Nói tiếp | 2 lượt: số → "sao vậy", "làm gì cho tăng" |

### 2.2 Thang chấm 8 tiêu chí (0–2 điểm mỗi tiêu chí, tối đa 16)

1. **Trả lời thẳng:** dòng đầu là kết luận hoặc con số.
2. **Đúng số:** mọi con số khớp với khối số liệu; không bịa.
3. **Tìm ra vấn đề cài sẵn:** chỉ ra đúng nguyên nhân hoặc điểm bất thường.
4. **Có lý lẽ:** nối số liệu với kết luận ("vì số đơn giảm 18%, giá trị mỗi đơn giữ nguyên").
5. **Việc làm cụ thể:** 2–3 việc có món / giờ / con số và thời hạn, làm được với quán nhỏ.
6. **Đúng quán:** chỉ nói món, nhóm quán đang có; không khuyên điều trái loại quán.
7. **Thận trọng đúng mức:** nói rõ còn thiếu số gì; không phán thay chủ ở quyết định lớn.
8. **Gọn và dễ đọc:** không sáo, không lặp, đúng cách xưng hô.

### 2.3 Cách chấm

- **Công cụ mới:** `cham_tu_van.ts`, cùng kiểu với `cham_gpt.ts` có sẵn.
  - Trả lời đúng như hàm `boom-chat` đang làm (cùng `buildMessages`, lời nhắc, mô hình).
  - Sau đó gpt-4o chấm theo thang 8 tiêu chí, kèm đáp án vấn đề cài sẵn.
  - Không ghi gì vào database.
- **Khoá OpenAI:** Chủ Quán tự dán khoá khi chạy. Claude không dò, không đọc, không in, không lưu khoá.
- **Chi phí ước tính mỗi lần chấm 60 câu:** khoảng 60 × (3.000 token trả lời bằng gpt-4o-mini + 4.000 token chấm bằng gpt-4o), tức khoảng **0,7–1 USD**.
- **Chủ Quán chấm tay 10 câu** ở lần đầu, để kiểm xem gpt-4o chấm có khớp ý mình không.
- **Mốc điểm:** chấm mốc gốc ngay. Sau mỗi giai đoạn chấm lại cùng bộ đề. Giữa chừng không chấm để tiết kiệm.

---

## 3. Lộ trình: 6 giai đoạn, 50 lần dạy

Mỗi lần dạy = sửa đúng một mục + bài kiểm đơn vị. Cuối mỗi giai đoạn: đo gộp một lần, QC một lần, chấm GPT thật (nếu giai đoạn đổi câu tư vấn), rồi hỏi duyệt áp + commit.
Cột "Áp lên đâu" cho biết việc cần duyệt:
- **app**: web /pos, các bản app sau.
- **máy chủ**: triển khai lại hàm boom-chat.
- **db**: thêm hàm đọc số, migration.

### Giai đoạn 0: Thước đo (lần 1–5)

| # | Việc | Áp lên đâu |
|---|---|---|
| 1 | Viết 3 file số liệu quán mẫu A / B / C có vấn đề cài sẵn | không |
| 2 | Viết 60 câu đề kèm đáp án vấn đề + thang chấm | không |
| 3 | Viết `cham_tu_van.ts` (trả lời + chấm, không ghi database); chạy thử 3 câu bằng GPT giả | không |
| 4 | **Chấm mốc gốc** 60 câu bằng GPT thật (cần duyệt + Chủ Quán dán khoá) | không |
| 5 | Chủ Quán chấm tay 10 câu; chỉnh thang chấm nếu lệch; ghi điểm mốc gốc từng tiêu chí, từng loại câu | không |

Kết quả giai đoạn 0 sẽ chỉ ra tiêu chí yếu nhất. Thứ tự các lần dạy trong Giai đoạn 2–3 có thể đảo theo kết quả này, không cần chẩn đoán thêm.

### Mốc gốc chấm GPT thật (28/10): 10,2/16

| Tiêu chí (0–2) | Điểm | | Loại câu (/16) | Điểm |
|---|---|---|---|---|
| Trả lời thẳng | **0,82** | | Chẩn đoán | 11,7 |
| Đúng số | 1,53 | | Quyết định | 9,7 |
| Tìm vấn đề | 1,52 | | Kế hoạch | 10,6 |
| Lý lẽ | **0,88** | | So sánh | 11,3 |
| Việc làm cụ thể | **0,90** | | Dự báo | **8,9** |
| Đúng quán | 1,88 | | Nói tiếp | **9,1** |
| Thận trọng | 1,38 | | | |
| Gọn | 1,30 | | | |

- **Chấm tay (lần 5):** Chủ Quán đồng ý cả 10/10 điểm gpt-4o chấm → tin được điểm chấm tự động, không cần chấm tay mỗi mốc.
- Vấn đề cài sẵn tìm ra 49/57. Câu mà app thiếu số: 9,8; câu đủ số: 11,1.
- Ba tiêu chí yếu nhất là **trả lời thẳng, lý lẽ, việc làm cụ thể**, đều là lỗi của cách suy luận. Nên **đưa lần 28–31 (khung 4 bước, khung theo loại câu, mẫu trả lời) lên trước**.
- Lỗi điển hình:
  - Câu mở đầu "Dạ Anh/Chị ơi, … có thể do nhiều nguyên nhân" thay vì nói kết luận.
  - Bạc xỉu giá vốn 45% mà Boom khuyên **không** tăng giá.
  - Dự báo tự tính sai, bịa mức dùng gạo mỗi ngày → cần lần 20 (dự báo tính sẵn) và 25 (số ngày còn đủ dùng).
- Câu nói tiếp "chi tiết hơn" thì bịa số → lần 36.

### Ghi chú từ Giai đoạn 0 (28/10, chưa chấm GPT thật)

- Lời nhắc tư vấn dài khoảng 18.000 ký tự (khoảng 6.000 token) mỗi câu → lần 28 rút gọn sẽ giảm cả chi phí.
- **Kỳ "tuần này" chưa hết tuần:** nếu app gửi số 0 cho những ngày chưa tới, máy chủ ghi "quán NGHỈ" cho các ngày đó. Cần kiểm phía app → sửa ở lần 21.
- **Phần trăm so kỳ trước ghi dấu chấm** ("GIẢM 14.2%"), chỗ khác dùng dấu phẩy → sửa ở lần 17.
- **Món giá ≤ 5.000đ** (trà đá 3.000đ) làm quán bún không có dòng "Combo tính sẵn" → xem ở lần 23.

### Giai đoạn 1: Hiểu đúng câu hỏi (lần 6–15). Nền cho mọi thứ sau

| # | Việc | Áp lên đâu |
|---|---|---|
| 6 | Xong đợt 16 (kỳ + con số + từ hỏi; "hết bao nhiêu tiền"; câu nói tiếp sau số theo mục) + hồi quy một lượt | app |
|  | ↳ Hồi quy 28/10: 7 câu tốt lên, 3 câu tụt cần sửa: "lương … bất thường … lỗi gì vậy" (phải đi hướng dẫn: "lỗi gì" là hỏi lỗi), "bao cao hom nay hien chua co giao dich" (thêm "chưa có / không có" vào chữ chặn của luật kỳ + con số), "tháng này nhập kho hết bao nhiêu tiền" (phải đọc số kho, không đọc số bán) | |
| 7 | Câu xem xu hướng không chủ đề ("nhìn số năm nay quán có đi lên không"), dự báo nhập hàng có chữ "nhập" | app |
| 8 | Hỏi so chi nhánh ngắn ("còn chi nhánh 2"), khung giờ / ca ("khung tối thì sao") | app |
| 9 | "sao giảm so với tuần trước", "tốt hay tệ so với quán bình thường" sau số nhanh → tư vấn kèm số | app |
| 10 | Mượn kỳ cho câu nói tiếp ở số theo mục; câu cải thiện ngắn không dấu ("giam kieu gi") | app |
| 11 | "nói lại ngắn gọn / mỗi con số tổng", "số lượng cụ thể bao nhiêu" sau tư vấn → nói tiếp | app |
| 12 | Câu mới tự đủ nghĩa không gửi kèm lượt trước; hỏi giá bán hợp lý là tư vấn chung | app |
| 13 | Câu lạc đề sau lượt số (bóng đá, "MU đá mấy giờ"), so app khác, khen / cảm ơn; lạc đề gõ không dấu | app |
| 14 | Lịch sử gửi GPT dùng **câu gốc** của người dùng | app |
| 15 | Tìm đúng bài hướng dẫn cho 10 việc hay hỏi (sơ đồ bàn, QR, nhật ký sửa giá, máy in, đổi món sau in, thu chi ghi sai, báo cáo lệch thu chi, sửa giá, tìm khách theo số điện thoại, gán quản lý) | app (bộ hướng dẫn) |

### Kết quả Giai đoạn 1 (28/10, chưa áp)

| Bộ | Trước | Sau |
|---|---|---|
| Q — hội thoại, **kín** | 42/80 | **48/80** |
| Q1 — một lượt, **kín**: đúng đường | 47/60 | **50/60** |
| Q1: tìm đúng bài | 23/30 | **24/30** |
| QC giai đoạn 1 (bẫy) | — | 19/30 |
| O / N / M / L / P / QC15 | 67 / 53 / 68 / 76 / 58 / 26 | 71 / 52 / 74 / 79 / 60 / 32 |

- Bộ một lượt cũ: không tụt; câu kho / ca làm vẫn trả số nhanh.
- Câu tụt còn lại:
  - "xem khách này đã chi tổng bao nhiêu chỗ nào" (đi tư vấn thay vì hướng dẫn).
  - "tháng này nhập kho hết bao nhiêu tiền" vẫn đọc số bán.
- 112 bài kiểm qua.
- Script áp chung: `db-fix/boom_ap_dung.sh <nhãn> "<dấu hiệu>"` (lần 46 làm sớm).

### Giai đoạn 2: Đủ số và số đã tính sẵn (lần 16–27)

Nguyên tắc: **app tính, GPT diễn giải**. GPT-4o-mini hay tính sai, nên mọi tỉ lệ, chênh lệch, dự báo đều do app tính sẵn rồi ghi thành chữ.

| # | Việc | Áp lên đâu |
|---|---|---|
| 16 | Gửi **số bán + số theo mục chung một câu** khi câu chạm cả hai ("lương có cao so với doanh thu", "chi phí / doanh thu") | app |
| 17 | Tính sẵn **tỉ lệ ngành**: giá vốn % doanh thu, lương %, mặt bằng %, điện nước %. Ghi rõ mốc kinh nghiệm (giá vốn 25–35%, lương 20–30%, mặt bằng dưới 15%) và "cao / vừa / thấp" | app + máy chủ (định dạng) |
| 18 | **Chuỗi theo tháng** (tới 12 tháng) và theo tuần (tới 12 tuần): chỉ tổng doanh thu / số đơn / giá trị đơn, đọc nhẹ | db (hàm đọc) + app |
| 19 | **Cùng kỳ năm trước** (tháng này năm ngoái, tuần này năm ngoái) | app (kỳ) + db |
| 20 | **Dự báo tính sẵn**: cuối tháng / cuối năm theo nhịp hiện tại, kèm cách tính một dòng | app |
| 21 | **Tự phát hiện bất thường tính sẵn**: ngày tụt hoặc tăng mạnh so trung bình cùng thứ, món tụt mạnh so kỳ trước, khoản chi tăng vọt. Gửi dạng "Bất thường: …" | app |
| 22 | **Phân rã thay đổi doanh thu**: do số đơn hay giá trị đơn, do món nào, do khung giờ nào (đã có một phần; làm đủ cho mọi kỳ) | app |
| 23 | Giá vốn từng món → **lãi gộp từng món** và món "bán nhiều mà lãi ít" (khi quán có nhập giá vốn) | app |
| 24 | Theo **thu ngân / nhân viên**: số đơn, doanh thu, huỷ món, giảm giá; không gửi tên khách | app + db |
| 25 | Khách: tỉ lệ quay lại, khách mới / cũ, giá trị trung bình khách quen; kho: **số ngày còn đủ dùng** theo tốc độ bán | app |
| 26 | Bỏ giới hạn 92 ngày cho số tổng (vẫn giữ 92 ngày cho số theo món để nhẹ) | app |
| 27 | Rà **riêng tư**: thêm số mới không gửi tên / số điện thoại khách cho OpenAI; lương chỉ gửi khi người hỏi có quyền; giữ luật "số theo mục không lưu vào sổ hỏi đáp" | app + máy chủ |

### Giai đoạn 3: Cách suy luận (lời nhắc) (lần 28–37)

| # | Việc | Áp lên đâu |
|---|---|---|
| 28 | Sắp xếp lại `ADVICE_PROMPT` thành **khung 4 bước** thay cho danh sách luật rời: kết luận → vì sao (số) → 2–3 việc làm (cụ thể, có số đo và thời hạn) → cần xem thêm gì. Gộp luật trùng, bỏ luật mâu thuẫn; giữ nguyên các luật an toàn | máy chủ |
| 29 | **Khung riêng theo loại câu**: chẩn đoán (tìm nguyên nhân từ phân rã), quyết định (lợi / rủi ro / con số hoà vốn), kế hoạch (theo tuần, có mốc đo), so sánh, dự báo. App gửi kèm "loại câu" đã đoán | app + máy chủ |
| 30 | **Hỏi lại một câu** khi thiếu dữ kiện then chốt (vd hỏi tăng giá mà chưa có giá vốn) thay vì khuyên chung chung | máy chủ |
| 31 | Mẫu suy luận: 6 ví dụ hỏi → trả lời mẫu tốt (ngắn) trong lời nhắc, chọn theo loại câu (chỉ gửi 1–2 mẫu đúng loại để tiết kiệm token) | máy chủ |
| 32 | **Con số hoà vốn / tác động** tính sẵn cho câu quyết định (tăng giá 3k thì mất bao nhiêu khách vẫn hoà) | app |
| 33 | Thử **gpt-4o** cho câu phân tích khó (chẩn đoán, kế hoạch); giữ gpt-4o-mini cho câu dễ. So điểm / chi phí trên bộ đề rồi Chủ Quán chọn | máy chủ (biến môi trường) |
| 34 | Độ dài theo loại câu (kế hoạch 900 token, câu nhanh 300) | máy chủ |
| 35 | Tự kiểm sau khi trả lời: con số trong câu trả lời phải có trong khối số; sai → bỏ con số đó (kiểm ở máy chủ, không gọi GPT thêm) | máy chủ |
| 36 | Câu nói tiếp đi sâu: "chi tiết hơn / sao vậy" → đi xuống một tầng phân rã (nhóm → món → giờ), không lặp lại | máy chủ |
| 37 | Chấm GPT thật lần 2 trên bộ đề; sửa 3 tiêu chí điểm thấp nhất | — |

### Giai đoạn 4: Hiểu riêng từng quán (lần 38–44)

| # | Việc | Áp lên đâu |
|---|---|---|
| 38 | **Hồ sơ quán tự suy**: loại quán (từ nhóm món), giá trung bình, giờ mở thật (từ giờ có bán), ngày nghỉ, số món, có giao hàng / QR không. Gửi 2–3 dòng đầu mỗi câu tư vấn | app |
| 39 | **Chủ quán tự khai một lần** (Boom hỏi khi phù hợp): mục tiêu (tăng khách / tăng lãi / giảm việc), khu vực (văn phòng / trường / dân cư), tiền mặt bằng | app + db |
| 40 | **Nhớ lời khuyên đã đưa**: lưu tóm tắt "đã đề xuất gì, ngày nào" (không lưu số) | máy chủ + db |
| 41 | **Theo dõi kết quả**: lần sau Boom so số trước / sau ("tuần trước đề xuất combo sáng: combo bán 34 phần, doanh thu sáng +12%") | app + máy chủ |
| 42 | Mùa vụ của quán: thứ / tháng mạnh yếu riêng của quán (từ chuỗi tháng), không chỉ ngày lễ chung | app |
| 43 | Cách xưng hô, độ dài, mức chi tiết theo người hỏi (chủ / quản lý / nhân viên) | máy chủ |
| 44 | Chấm GPT thật lần 3 (thêm 10 câu đòi hỏi hiểu quán) | — |

### Giai đoạn 5: Chủ động (lần 45–48). Tính năng mới, mỗi mục hỏi duyệt riêng

| # | Việc | Áp lên đâu |
|---|---|---|
| 45 | **Tóm tắt tuần**: sáng thứ Hai Boom gửi 5 dòng (doanh thu tuần, bất thường, 1 việc nên làm) khi chủ quán mở app | app + máy chủ |
| 46 | **Cảnh báo sớm**: hàng sắp hết theo tốc độ bán, ngày tụt mạnh, chi phí vượt mức thường | app |
| 47 | **Gợi ý câu hỏi tiếp theo** theo ngữ cảnh (nút sau câu tư vấn: "Món nào kéo giảm?", "Lên kế hoạch tuần sau") | app |
| 48 | Nút "Đã làm theo" cho việc Boom đề xuất, để lần 41 theo dõi | app + db |

### Giai đoạn 6: Học từ người dùng thật (lần 49–50, rồi lặp mãi)

| # | Việc | Áp lên đâu |
|---|---|---|
| 49 | Mỗi tuần một lần "duyệt Boom": câu bị 👎, câu chưa trả lời được, câu hỏi thật mới. Gom thành bài kiểm và câu đề mới; Chủ Quán duyệt mới áp (quy trình đã có) | tuỳ |
| 50 | Tổng kết: chấm lại toàn bộ đề, so mốc gốc từng tiêu chí; lập kế hoạch vòng sau | — |

---

## 4. Việc cần Chủ Quán duyệt

| Việc | Khi nào |
|---|---|
| Chấm bằng GPT thật (tốn khoảng 1 USD mỗi lần; Chủ Quán tự dán khoá) | Lần 4, 37, 44, 50 và khi so mô hình (33) |
| Triển khai lại hàm boom-chat (đổi lời nhắc / định dạng số) | Cuối Giai đoạn 2, 3, 4 |
| Thêm hàm đọc số / migration trên database | Lần 18, 19, 24, 39, 40, 48 |
| Đưa web /pos | Cuối mỗi giai đoạn |
| Tính năng mới (Giai đoạn 5) | Từng mục |
| Đổi mô hình sang gpt-4o (tăng chi phí) | Lần 33 |

## 5. Cách làm để nhanh và ít token

- Không chẩn đoán lại sau mỗi lần dạy. Kế hoạch đã ghi việc và câu mẫu.
- Đo gộp **một lệnh** cuối mỗi giai đoạn. Chấm GPT thật chỉ ở các mốc đã ghi.
- Mỗi giai đoạn có QC độc lập **một lần** và bộ kín mới viết trước khi sửa.
- Thứ tự trong giai đoạn có thể đổi theo điểm chấm mốc gốc, nhưng không thêm vòng chẩn đoán.

## 6. Rủi ro

- **Lời nhắc dài hơn → tốn token hơn mỗi câu.** Bù bằng cách chỉ gửi phần khung / mẫu đúng loại câu.
- **Thêm số → tăng dữ liệu gửi OpenAI.** Lần 27 rà riêng tư trước khi áp.
- **gpt-4o đắt hơn gpt-4o-mini nhiều lần.** Chỉ dùng cho câu khó, và Chủ Quán quyết sau khi xem điểm và chi phí.
- **Hồ sơ / trí nhớ dài hạn** (38–41) cần bảng mới trên database. Làm theo quy trình migration, hỏi trước khi áp.
