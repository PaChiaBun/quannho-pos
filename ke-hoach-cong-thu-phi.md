# Kế hoạch cổng thu phí Quán Nhỏ (quannho.lpm.vn) — 26/10/2026

> Trạng thái: **Đợt A ĐÃ LÀM (28/10, test + QC, CHƯA áp)** — xác nhận tiền vào bằng tay trên /admin; đợt B (SePay tự xác nhận) chưa làm.
> Ban đầu: Chủ Quán chốt hướng: thu phí MỘT cổng trên web, app App Store / CH Play không bán, không hiện giá.
> Đã chốt 26/10 (mục 11): giá 99k / 499k / 899k · hết hạn chỉ nhắc · SePay · nhận tiền bằng tài khoản công ty · từng chi nhánh trả riêng · nút "Gia hạn thêm 30 ngày" miễn phí chưa tắt (quyết sau).

## 1. Mục tiêu

- Chủ quán tự chọn gói → chuyển khoản bằng mã VietQR → máy chủ **tự nhận biết tiền vào** → gói tự gia hạn trong vài giây, không ai phải bấm tay.
- Một nơi thu tiền duy nhất (web), dùng chung cho mọi máy: Android, iPhone, Windows, Mac, web.
- App iOS / Android **không** hiện giá, nút mua, đường dẫn thanh toán (để không vi phạm quy định Apple 3.1.1 và Google Play Billing).
- Mọi khoản tiền có nhật ký, đối soát được trên trang `/admin`.

## 2. Bức tranh tổng thể

```
Chủ quán (web /pos hoặc bản máy tính)          Ngân hàng của Quán Nhỏ
   │ 1. Chọn gói → tạo "đơn thanh toán"                │
   │ 2. Hiện mã VietQR (số tiền + nội dung QNxxxxxx)    │
   │ 3. Quét mã bằng app ngân hàng, chuyển tiền ───────►│
   │                                                    │ 4. Dịch vụ đối soát (SePay / Casso / PayOS)
   │                                                    │    thấy tiền vào → gọi webhook* về máy chủ
   │                                  /api/billing/webhook (cổng Python sẵn có)
   │                                                    │ 5. Kiểm khoá bí mật, khớp mã + số tiền
   │                                                    │ 6. Gia hạn Pro + ghi nhật ký (1 giao dịch DB)
   │ 7. App thấy "Đã nhận tiền, gói đến dd/mm/yyyy" ◄───┘
```
*webhook = dịch vụ đối soát tự gửi tin báo "có tiền vào" tới địa chỉ của mình.

## 3. Bảng giá (ĐÃ CHỐT 26/10)

| Gói | Thời hạn | Giá (gợi ý — chưa chốt) | Ghi chú |
|---|---|---|---|
| Pro tháng | 1 tháng | **99.000đ** | |
| Pro 6 tháng | 6 tháng | **499.000đ** | ~83.000đ/tháng (rẻ hơn ~16%) |
| Pro năm | 12 tháng | **899.000đ** | ~75.000đ/tháng (rẻ hơn ~24%) |

- Giá để trong bảng `billing_plans` (đổi giá trên `/admin`, không cần phát hành app).
- Hiện bảng giá công khai trên trang chủ quannho.lpm.vn (dự án web `lpm-web`), đọc từ cùng bảng.
- **Hết hạn mà chưa trả: CHỈ NHẮC** (đã chốt) — app vẫn dùng đầy đủ, chỉ hiện dải nhắc; không khoá module, không khoá quán. Trả tiền lúc này là tự nguyện; muốn siết sau thì chỉ đổi luật nhắc / khoá, không đổi cổng thu.
- Mỗi chi nhánh trong chuỗi là một quán, trả riêng (đã chốt). Chủ chuỗi tạo nhiều đơn, mỗi đơn một mã chuyển khoản.
- Quán mới vẫn dùng thử 14 ngày như hiện nay.

## 4. Dữ liệu (migration mới)

| Bảng | Nội dung |
|---|---|
| `billing_plans` | mã gói, tên, số tháng, giá, đang bán / ngưng, thứ tự |
| `billing_orders` | quán, gói, số tiền, **mã chuyển khoản** (QN + 6 ký tự, không trùng), trạng thái (chờ / đã trả / hết hạn / huỷ), người tạo, hết hạn sau 24 giờ, thời điểm trả |
| `billing_bank_events` | **nguyên văn** mọi tin báo tiền vào từ dịch vụ đối soát (mã giao dịch ngân hàng = khoá không trùng), kết quả khớp |
| (có sẵn) `admin_store_actions` | thêm loại `payment` (tự gia hạn do trả tiền), ghi số tiền |

Khoá hẳn như các bảng quản trị: RLS bật, không chính sách; chỉ hàm SECURITY DEFINER đọc / ghi.

## 5. Luồng chi tiết

### 5.1 Chủ quán tạo đơn (app web / máy tính)
- Màn mới **"Gói & thanh toán"** (chỉ Chủ quán): gói hiện tại, ngày hết hạn, lịch sử đã trả, danh sách gói + giá.
- Bấm gói → hàm `billing_create_order_v1(p_store, p_plan)`: chỉ Chủ quán, mỗi quán tối đa 1 đơn "chờ" (tạo lại thì huỷ đơn cũ), giới hạn số đơn / giờ.
- App **tự vẽ mã QR** theo chuẩn VietQR (EMVCo) ngay trên máy — không tải ảnh từ bên ngoài: số tài khoản, ngân hàng, số tiền, nội dung = mã đơn. Kèm chữ to: số tiền, nội dung chuyển khoản, nút sao chép.
- App hỏi lại trạng thái đơn mỗi 5 giây (hoặc nhận realtime) → hiện "Đã nhận tiền".

### 5.2 Máy chủ nhận tiền (cổng Python `services/pos_gateway_server.py`, thêm đường `/api/billing/webhook`)
1. Kiểm **khoá bí mật** của dịch vụ đối soát (để trong `/root/quannho-secrets/`, như khoá OpenAI) — sai khoá → từ chối.
2. Ghi nguyên văn vào `billing_bank_events` (trùng mã giao dịch → bỏ qua: gửi lại nhiều lần không cộng 2 lần).
3. Tìm mã `QNxxxxxx` trong nội dung chuyển khoản → đơn "chờ" của quán đó.
4. Khớp khi **số tiền ≥ giá đơn**. Hàm `billing_apply_payment_v1` (chỉ service_role) trong MỘT giao dịch DB: đơn → "đã trả", gói Pro hết hạn mới = max(hạn cũ, bây giờ) + số tháng, quán đang khoá vì hết hạn thì mở, ghi `admin_store_actions` loại `payment`.
5. Không khớp (thiếu mã, sai mã, thiếu tiền, đơn đã hết hạn) → để vào hàng **"Tiền chưa khớp"** trên `/admin` cho Chủ Quán gán tay vào quán (cũng ghi nhật ký).

### 5.3 Trang /admin
- Tab Gói thêm: **"Tiền vào"** (mọi khoản, đã khớp / chưa khớp), nút gán tay khoản chưa khớp, sửa bảng giá, doanh thu theo tháng.
- Hồ sơ quán: lịch sử thanh toán.

### 5.4 Nhắc gia hạn
- Dải nhắc hiện có giữ nguyên cho dùng thử; thêm cho Pro sắp hết (7 ngày) / đã hết.
- Bản tin Telegram buổi sáng (đợt 3 đã chốt) thêm: tiền vào hôm qua, khoản chưa khớp, quán Pro sắp hết.

## 6. App iOS / Android không hiện giá (quy định cửa hàng)

| Nơi chạy | Hiện giá / nút trả tiền | Dải nhắc hết hạn |
|---|---|---|
| Web `/pos` | Có | "…Bấm để gia hạn" → màn Gói & thanh toán |
| Windows / Mac tải từ web | Có | như web |
| iOS / Android (cửa hàng) | **Không** | Chỉ báo trung tính: "Gói của quán hết hạn ngày dd/mm" — không nút, không đường dẫn, không "liên hệ để mua" |

- Một hàm duy nhất `billingAllowedHere()` (web hoặc bản máy tính tải ngoài cửa hàng → true; iOS / Android → false) — mọi chỗ hiện giá / nút trả đều đi qua hàm này; test khoá chặt.
- Mô tả app trên App Store / CH Play: không nhắc giá, không nhắc "mua trên web".
- Báo chủ quán cách trả tiền **bên ngoài app** (Zalo, SMS, email) — được phép.
- Nút "Gia hạn thêm 30 ngày" miễn phí hiện nay: **chưa tắt, quyết sau** (26/10). Khi muốn tắt chỉ cần đổi điều kiện trong `qn_store_can_self_extend` (máy chủ), không phải phát hành app.
- Thị trường Mỹ / châu Âu được nới — không áp dụng cho Việt Nam lúc này (Google dự kiến mở toàn cầu 9/2027 — xem lại khi đó).

## 7. Dịch vụ đối soát chuyển khoản — ĐÃ CHỐT: SePay

| Dịch vụ | Cách hoạt động | Cần kiểm |
|---|---|---|
| **SePay** | Liên kết tài khoản ngân hàng, gửi webhook khi tiền vào; phổ biến với shop nhỏ | giá gói tháng, ngân hàng hỗ trợ |
| **Casso** | Tương tự, đọc biến động số dư | giá, độ trễ |
| **PayOS** | Tạo link / QR thanh toán theo đơn, tự đối soát | yêu cầu đăng ký (có thể cần giấy phép kinh doanh) |

**Chốt SePay** (26/10), nhận tiền bằng **tài khoản ngân hàng công ty**. Cần làm khi bắt đầu đợt B: đăng ký SePay bằng thông tin công ty, liên kết tài khoản, tạo khoá webhook → Chủ Quán tự dán khoá vào `/root/quannho-secrets/` (agent không cầm khoá). Kiểm lại giá gói SePay + ngân hàng của công ty có được hỗ trợ không.
Lý do chọn: dịch vụ đọc biến động số dư (SePay / Casso) vì không đổi cách khách chuyển tiền; mã hoá phía mình chỉ phụ thuộc "tin báo có tiền vào", đổi dịch vụ sau chỉ thay phần đọc tin báo. Thẻ / ví (VNPay, MoMo) để sau — phí ~1–2% và cần giấy phép.

## 8. Giấy tờ (hỏi kế toán — chưa xác minh chi tiết)
- **Đã có công ty** (26/10) → nhận tiền bằng tài khoản công ty, xuất được hoá đơn; mở VNPay / MoMo / PayOS về sau được.
- Thông báo website bán hàng với Bộ Công Thương (online.gov.vn).
- Hoá đơn điện tử cho mỗi khoản thu (có thể nối sau: lưu thông tin xuất hoá đơn của quán trong màn thanh toán).
- Điều khoản dịch vụ + chính sách hoàn tiền đăng trên web.

## 9. Bảo mật & an toàn
- Webhook: khoá bí mật bắt buộc, chỉ nhận HTTPS, ghi nguyên văn, chống trùng theo mã giao dịch ngân hàng, giới hạn kích thước.
- Gia hạn chỉ qua hàm service_role; app không bao giờ tự đổi gói (trigger chốt cột đã có từ đợt 1).
- Số tiền / mã đơn luôn lấy từ máy chủ, không tin số app gửi.
- Không lưu số thẻ / mật khẩu ngân hàng ở đâu cả.
- Test: trả đúng, trả thiếu, trả thừa, sai mã, gửi tin trùng 2 lần, 2 tin cùng lúc, đơn hết hạn rồi mới trả, quán đang khoá, đổi giá khi đơn đang chờ.

## 10. Chia đợt

| Đợt | Nội dung | Cần trước |
|---|---|---|
| A | Bảng giá + đơn thanh toán + màn "Gói & thanh toán" (web / máy tính) + QR VietQR vẽ tại máy + chặn hiện giá trên iOS / Android | chốt giá, số tài khoản |
| B | Webhook tự xác nhận + gia hạn tự động + hàng "tiền chưa khớp" trên `/admin` | chọn dịch vụ đối soát, khoá bí mật |
| C | Bảng giá công khai trên trang chủ (`lpm-web`), nhắc Pro sắp hết, bản tin Telegram | — |
| D | Hoá đơn điện tử, thẻ / ví (tuỳ) | giấy tờ |

Mỗi đợt: test + QC độc lập + chạy thử trên bản sao database, **hỏi Chủ Quán trước khi áp production**.

## 11. Chủ Quán đã chốt (26/10/2026)
1. Giá: **Pro tháng 99.000đ · 6 tháng 499.000đ · năm 899.000đ**. Quán mới vẫn dùng thử 14 ngày.
2. Hết hạn chưa trả: **chỉ nhắc** — không khoá module, không khoá quán.
3. Dịch vụ đối soát: **SePay**.
4. Đã có **công ty** — nhận tiền bằng tài khoản công ty.
5. Chuỗi: **từng chi nhánh trả riêng**.
6. Nút "Gia hạn thêm 30 ngày" miễn phí: **chưa tắt, quyết sau**.

Còn cần khi bắt đầu làm: số tài khoản + ngân hàng của công ty (để vẽ mã VietQR), đăng ký SePay + khoá webhook (Chủ Quán tự đặt), thông tin xuất hoá đơn (đợt D).
