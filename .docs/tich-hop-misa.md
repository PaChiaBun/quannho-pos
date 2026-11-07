# Tích hợp MISA — Phân tích khả thi và kế hoạch

Cập nhật 16/10/2026. Nguồn: cổng developer.misa.vn (đọc khi đăng nhập tài khoản LPM), doc.meinvoice.vn, helpact.misa.vn, trang MISA và báo pháp luật. Mục "Chưa xác minh" phải được kiểm chứng trước khi viết code. Không ghi Client ID, Client Secret, access_code, mật khẩu vào file này hay nhật ký.

## 1. Kết luận

- Khách hàng chủ yếu là **hộ kinh doanh**, nên ưu tiên theo thứ tự: (1) hóa đơn điện tử từ máy tính tiền qua meInvoice, (2) sổ doanh thu/bảng kê tự xuất từ POS, (3) đẩy sang MISA eShop/mTax nếu MISA xác nhận có API, (4) AMIS Kế toán DN cho khách là doanh nghiệp.
- Quyền API MISA đã cấp cho app **Quán Nhỏ POS**: meInvoice (Hóa đơn điện tử) và Xử lý hóa đơn đầu vào. AMIS Kế toán DN đã gửi đăng ký, chưa kiểm tra trạng thái duyệt. MISA eShop và mTax **không có** trong danh sách sản phẩm Open API (AMIS Kế toán DN, Esign, WeSign, MISA ASP, AMIS CRM).
- Tab "Workflow" của cổng là công cụ biến Quán Nhỏ thành connector của MISA Flow (chiều MISA gọi vào mình). Không liên quan báo cáo thuế, bỏ qua ở giai đoạn này.

## 2. Pháp lý (cần đối chiếu văn bản gốc)

- NĐ 70/2025/NĐ-CP, hiệu lực 01/06/2025: hộ/cá nhân kinh doanh doanh thu từ 1 tỷ/năm trở lên bán trực tiếp cho người tiêu dùng (gồm F&B) phải dùng hóa đơn điện tử khởi tạo từ máy tính tiền, kết nối dữ liệu với cơ quan thuế. Hộ dưới 1 tỷ có thể đăng ký tự nguyện.
- TT 152/2025/TT-BTC, hiệu lực 01/01/2026, thay TT 88/2021: hộ kinh doanh ghi sổ theo mẫu mới. Nhóm nộp thuế theo tỷ lệ % trên doanh thu dùng sổ doanh thu S2a-HKD. Nhóm tính trên thu nhập dùng bộ sổ chi tiết hơn (S2b–S2e). Các nguồn không thống nhất về ngưỡng và cách chia nhóm.
- Workflow `/qn` và nhật ký còn ghi TT88 và thuế 4,5%. Cần cập nhật sau khi đối chiếu văn bản chính thức.

## 3. meInvoice Open API (đã đọc)

Base URL: `https://developer.misa.vn/apis/itg/meinvoice/`

| Việc | Endpoint |
|---|---|
| Lấy token | POST `/invoice/token`, header `ClientID` + `ClientSecret`, body `taxcode`, `username` (email/sđt), `password` |
| Danh sách mẫu hóa đơn | GET `/invoice/templates` |
| Xem trước | POST `/invoice/unpublishview` (link sống 5 phút) |
| Phát hành | POST `/invoice/publishing` (SignType 2 = HSM, 5 = hóa đơn MTT không hiển thị CKS) |
| Danh sách hóa đơn MTT | POST `/invoiceweb/paging/calculating?invoiceWithCode=true`, header `TaxCode`, tối đa 100/lần, lọc theo 1 ngày |
| Hóa đơn nháp lên web app | nhóm API WEB APP |

Quy tắc đáng chú ý:
- Header nghiệp vụ: `Authorization: Bearer <token>`, `ClientID`.
- Token sống 14 ngày (tài liệu cũ ghi 15), gọi `refreshtoken` khi lỗi `TokenExpiredCode`.
- Mỗi request tối đa 30 hóa đơn, mỗi hóa đơn tối đa 400 dòng, xử lý tuần tự theo ký hiệu.
- `RefID` bắt buộc duy nhất và dùng để chống trùng. MISA khuyên đặt theo từng đơn hàng. Đề xuất dùng id settlement của POS.
- `Success: true` chỉ nghĩa là request được nhận. Phải đọc `ErrorCode` trong `publishInvoiceResult[]` (null = thành công), và lưu `TransactionID`.
- Kết quả có `InvNo`, `InvSeries`, `InvTemplateNo`, và `InvCode` (mã cơ quan thuế cấp cho hóa đơn máy tính tiền).
- `PublishStatus` hóa đơn MTT: 0 chưa phát hành, 4 chờ cấp mã, 6 đã cấp mã, 7 từ chối cấp mã.
- Thuế suất theo dòng: KCT, KKKNT, 0%, 5%, 8%, 10%, KHAC:x%. Có `TaxRateInfo` tổng hợp theo thuế suất.
- Lỗi cần xử lý: `InvoiceDuplicated`, `InvoiceNumberNotCotinuous` (retry sau vài giây), `TemplateNotExist`, `LicenseInfo_NotBuy` (quán chưa mua tài nguyên hóa đơn), `SystemError` (retry backoff).
- Hóa đơn thay thế/điều chỉnh dùng `ReferenceType` 1/2 cùng nhóm trường `Org*`.

### Bổ sung sau khi đọc đủ tài liệu trên cổng developer (17/10/2026)

- **Hai luồng:** (A) phát hành thẳng lên đám mây: `/invoice/token` rồi `/invoice/publishing`, MISA ký số (SignType 2 = HSM có hiển thị chữ ký, 5 = hóa đơn máy tính tiền không hiển thị chữ ký). (B) đẩy hóa đơn **nháp** lên web meInvoice: `/invoiceweb/token`, `/invoiceweb/templates`, `/invoiceweb/insert`; người dùng vào web xem (có trang riêng cho hóa đơn máy tính tiền) rồi tự phát hành. B không tự động hoàn toàn, nhưng an toàn hơn khi còn chưa chắc.
- **Cả hai luồng lấy token đều cần mã số thuế, tên đăng nhập và mật khẩu meInvoice của quán** (cộng `ClientID` và `ClientSecret` của ứng dụng). Tài liệu không nêu cách lấy token khác.
- **Đọc ký hiệu hóa đơn:** ký tự 1: 1 hóa đơn GTGT, 2 hóa đơn bán hàng, 5 vé, 6 phiếu xuất kho. Ký tự 2: C có mã, K không mã. Ký tự 5: T thường, **M máy tính tiền**. Ví dụ `1C26MYY`. Lọc mẫu hóa đơn máy tính tiền bằng ký tự thứ 5 = M. Ký hiệu đổi theo năm, MISA tự xử lý theo `InvDate`.
- **Trạng thái gửi cơ quan thuế (hóa đơn có mã):** 0 chờ cấp mã, 1 gửi lỗi, 2 đã cấp mã, 3 từ chối cấp mã. Tra trạng thái: POST `/invoice/status` (`invoiceCalcu=true` cho máy tính tiền), nên hỏi lại sau 3–5 giây, tối đa 3 lần.
- **Bắt buộc xử lý tuần tự theo từng ký hiệu:** gửi, nhận kết quả, lưu lại rồi mới gửi tiếp. Gặp `InvoiceDuplicated` hoặc `InvoiceNumberNotCotinuous` thì thử lại.
- Thuế trên hóa đơn: `VATRate` -1 không chịu thuế, -3 không kê khai nộp thuế, 0/5/8/10. Các trường thuế chỉ bắt buộc với hóa đơn GTGT (suy ra: hóa đơn bán hàng của hộ kinh doanh có thể không cần tách thuế, **chưa xác nhận**).
- Giới hạn: 30 hóa đơn mỗi lần (luồng đám mây), khuyến nghị 30 mỗi lô (luồng nháp), 400 dòng mỗi hóa đơn. Không thấy tài liệu nói về giới hạn số lần gọi, thời gian chờ, môi trường thử.

## 4. AMIS Kế toán DN (đã đọc, để sau)

- Base `https://developer.misa.vn/apis`, header `ClientID`. Token: POST `/amiskt/v1/token` với `access_code` (kế toán khách tự tạo trong AMIS) và `org_company_code` (mình đặt), sống 12 giờ, gửi qua `X-MISA-AccessToken`.
- Đẩy chứng từ: POST `/amiskt/v1/save`, bất đồng bộ, tối đa 500 dòng/chứng từ, kết quả qua callback hoặc API lấy danh sách kết quả. Là "đề nghị sinh chứng từ": kế toán còn phải lập chứng từ trong AMIS.
- Chứng từ bán hàng (voucher_type 13) bắt buộc danh mục (vật tư, kho, đơn vị tính, chi nhánh) và tài khoản nợ/có. Cần ánh xạ theo từng quán, nên là việc nặng.
- Nếu làm: đẩy chứng từ bán hàng gộp theo ca/ngày và thuế suất để tránh đồng bộ cả thực đơn.

## 5. Chưa xác minh (phải hỏi MISA hoặc thử trên môi trường test)

1. **Lấy token cần mật khẩu tài khoản meInvoice của từng quán.** Phải hỏi MISA có cơ chế khác (ủy quyền, token theo app) không. Nếu bắt buộc, chỉ lưu phía server, mã hóa (Supabase Vault hoặc tương đương), có đồng ý rõ của Chủ quán và quyền thu hồi. Tuyệt đối không để ở client hay log.
2. Mẫu số/ký hiệu hóa đơn máy tính tiền của hộ kinh doanh, và API phát hành chính thức cho loại này là `/invoice/publishing` hay đường web app. Ví dụ trong tài liệu dùng mẫu GTGT, không phải mẫu MTT.
3. Hộ kinh doanh tính thuế theo tỷ lệ % thì hóa đơn ghi thuế suất thế nào.
4. Môi trường test/sandbox của meInvoice (doc cũ nêu `testapi.meinvoice.vn`) có áp dụng cho Client ID đã cấp không.
5. Chi phí: mua tài nguyên hóa đơn theo quán, phí tích hợp đối tác, ai trả.
6. MISA eShop/mTax có API cho đối tác POS không, và chiều ghi hay chỉ đọc. Bot chat chỉ nói eShop có cổng API lấy danh mục, khách hàng, hóa đơn (chiều đọc).
7. Trạng thái duyệt AMIS Kế toán DN.

## 6. Hiện trạng POS và khoảng trống

- Có `orders` (subtotal, discount, tax, total_amount, payment_method), `payment_settlements`, `ban_session_order_items`, `finance_records` với tách tiền mặt/tiền gửi, settlement v5 nguyên tử.
- Chưa có: thuế suất theo món, mã số thuế và thông tin đăng ký thuế của quán, cấu hình hóa đơn theo quán, thông tin người mua. `trien-khai-sap-toi.md:397` đang ghi tạm hoãn VAT/e-invoice, cần Chủ quán mở lại phạm vi.

## 7. Kiến trúc đề xuất (khi được mở phạm vi)

- Phía server, cô lập `store_id`, thông tin xác thực MISA lưu mã hóa, client chỉ bật/tắt và xem trạng thái.
- Bảng cấu hình tích hợp theo quán và bảng outbox: `store_id`, loại chứng từ, id nguồn (settlement), khóa idempotency, trạng thái, số lần thử, lỗi, `TransactionID`, `InvNo`, `InvCode`. Worker (Edge Function) xử lý hàng đợi, retry với backoff.
- **Lỗi hóa đơn không được chặn thanh toán.** Thanh toán xong settlement mới đưa vào hàng đợi. Có màn xử lý hóa đơn lỗi hoặc bị từ chối cấp mã, và đối soát số hóa đơn với số bill theo ngày.
- Bill hủy/hoàn sau khi phát hành dùng hóa đơn điều chỉnh/thay thế, không sửa đè.
- Sổ doanh thu và bảng kê tự xuất từ POS (Excel/PDF) đặt nhãn hỗ trợ tham khảo, chủ hộ/kế toán chịu trách nhiệm kê khai.
- Không dùng Graphify/CodeGraph tại bước này vì chưa có thay đổi code. Khi mở phạm vi thì lập bản đồ ảnh hưởng lên `payment_settlements`, `finance_records` và báo cáo hiện có.

## 8. Lộ trình

| Bước | Việc | Điều kiện |
|---|---|---|
| 0 | Chuyên viên MISA trả lời mục 5, tạo tài khoản thử meInvoice và test | Chờ MISA gọi lại |
| 1 | Xuất sổ doanh thu và bảng kê Excel/PDF theo mẫu TT152 | Đối chiếu văn bản gốc |
| 2 | Mở phạm vi VAT/hóa đơn: thuế suất theo món, hồ sơ thuế của quán | Chủ quán quyết định |
| 3 | Phát hành hóa đơn MTT qua meInvoice, bản chạy thử trên 1 quán (KAY nếu phù hợp) | Bước 0 và 2 xong |
| 4 | eShop/mTax hoặc AMIS Kế toán DN | Tùy xác nhận của MISA và nhu cầu khách |

## 9. Thiết kế công tắc hóa đơn điện tử và báo cáo hóa đơn (đã chốt phạm vi)

Phạm vi: chỉ một công tắc bật/tắt theo quán và một báo cáo số tiền đã xuất hóa đơn. Không làm bộ đếm doanh thu theo ngưỡng.

### Công tắc
- Cấu hình theo `store_id`: `einvoice_enabled` (mặc định tắt). Chỉ Chủ quán đổi được, cần PIN phê duyệt, ghi audit (ai, lúc nào, giá trị cũ → mới).
- Chỉ ảnh hưởng việc **đưa bill vào hàng đợi phát hành**. Mọi bill vẫn được ghi đầy đủ vào `orders`/`payment_settlements`/`finance_records` và tính vào doanh thu, bất kể bật hay tắt.
- Khi bật: mọi bill thanh toán xong đều vào hàng đợi, không có chế độ chọn từng bill. Khi tắt: không đưa bill mới vào hàng đợi, bill cũ không bị đụng tới. Không tự tạo hóa đơn bù cho bill phát sinh lúc tắt.
- Bật chỉ có hiệu lực khi quán đã cấu hình tài khoản meInvoice và có mẫu hóa đơn hợp lệ. Thiếu thì chặn bật và báo lý do.
- Mỗi bill lưu trạng thái hóa đơn: không áp dụng (lúc tắt), chờ phát hành, đã phát hành, chờ cấp mã, bị từ chối cấp mã, lỗi.

### Báo cáo hóa đơn điện tử
- Theo ngày/tháng/quý/năm và theo quán: tổng tiền đã xuất hóa đơn, số hóa đơn, tách theo thuế suất, tách theo trạng thái (đã cấp mã, chờ, từ chối, lỗi).
- Cột đối chiếu: tổng doanh thu bill cùng kỳ, phần doanh thu chưa có hóa đơn (do tắt công tắc hoặc đang lỗi). Chỉ hiển thị, không cho sửa.
- Danh sách hóa đơn lỗi/bị từ chối để xử lý lại. Xuất Excel/PDF.
- Quyền xem: Chủ quán và vai trò có module báo cáo.

## 10. Thuế theo món — cách MISA làm (tham khảo, nguồn là trang MISA, cần đối chiếu văn bản gốc)

- **Hộ kinh doanh (MISA eShop):** thuế tính theo **nhóm ngành nghề** với tỷ lệ % trên doanh thu, không theo thuế suất 8%/10% như doanh nghiệp. Bảng MISA dẫn (theo "Thông tư 40"): nhóm 3 gồm sản xuất, vận tải, **dịch vụ ăn uống** có GTGT 3% và TNCN 1,5%; nhóm 1 bán lẻ, phân phối hàng hóa 1% và 0,5%; nhóm 2 dịch vụ không gắn hàng hóa 5% và 2%; nhóm 4 khác 2% và 1%. MISA eShop có tính năng AI gợi ý thuế/nhóm khi thêm hàng hóa mới.
- **Doanh nghiệp (AMIS Kế toán):** thuế suất khai báo ở danh mục vật tư hàng hóa, có thể chọn lại ở từng dòng khi lập hóa đơn (0/5/8/10, KCT, KKKNT, khác). Có xem trước hóa đơn để kiểm tra thuế suất.
- **Mẫu 01/CNKD mới (TT 50/2026/TT-BTC, ký 13/5/2026, sửa TT 18/2026):** phải tách riêng doanh thu không chịu thuế và doanh thu thuế suất 0%.
- **Ngưỡng 1 tỷ (NĐ 141/2026 theo MISA):** doanh thu năm từ 1 tỷ trở xuống không phát sinh GTGT và TNCN nhưng phải thông báo doanh thu thực tế trước 31/01 năm sau. Trên 1 tỷ phải tự kê khai, dùng hóa đơn máy tính tiền, nộp 01/CNKD. Cách tính TNCN còn tùy khoảng doanh thu (1–3 tỷ có hai lựa chọn, trên 3 tỷ tính trên thu nhập). Đây là thông tin của bên bán phần mềm, phải đối chiếu văn bản.
- Các nguồn nêu nhiều văn bản khác nhau (TT 40, TT 152/2025, TT 18/2026, TT 50/2026, NĐ 141/2026): chưa xác định văn bản nào áp dụng cho từng nội dung.

### Hệ quả thiết kế cho Quán Nhỏ
- Mỗi sản phẩm cần một **nhóm thuế** (mặc định "dịch vụ ăn uống" cho F&B, có thể đổi sang "bán hàng hóa" cho hàng đóng gói bán nguyên) chứ không chỉ một con số thuế suất.
- Báo cáo doanh thu phải tách **theo nhóm thuế**, vì sổ doanh thu ghi theo nhóm cùng tỷ lệ. Cần có chỗ cho doanh thu không chịu thuế và 0%.
- Nhãn thuế trên dòng hóa đơn (`VATRateName` của meInvoice) có thể khác nhóm thuế. Hóa đơn của hộ tính thuế theo tỷ lệ ghi thế nào thì chưa rõ, phải hỏi MISA trước khi cố định ánh xạ.

### Trạng thái triển khai (16/10/2026)
Đã viết (chưa áp migration, chưa chạy trên thiết bị): `supabase/migrations/20261016_einvoice_foundation_v1.sql` (+ ROLLBACK), `lib/core/repositories/einvoice_repository.dart`, `lib/screens/einvoice_setting_tile.dart` (công tắc), `lib/screens/einvoice_report_tab.dart` (tab báo cáo), test `test/repositories/einvoice_report_test.dart`. Chưa làm: worker phát hành meInvoice, đưa bill vào hàng đợi khi bật, thuế suất/nhóm thuế, cấu hình tài khoản meInvoice theo quán.

### Việc cần làm khi triển khai
Migration thêm cấu hình và bảng hàng đợi, RPC bật/tắt có kiểm quyền và audit, worker phát hành, màn báo cáo. Phải rà RLS cho các bảng mới và cập nhật `kien-truc-data.md`, `tinh-nang.md`, CodeGraph/Graphify theo `/qn` bước G.
