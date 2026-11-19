---
module: chain
ten: Báo Cáo Nhiều Cửa Hàng / Chuỗi
phien_ban: 1.0.5+20
cap_nhat: 2026-11-19
nguon:
  - lib/screens/chain_report_screen.dart, chain_manage_sheet.dart, chain_module_offer.dart
  - lib/core/repositories/chain_repository.dart (thông báo lỗi), lib/core/utils/chain_compare.dart, chain_insights.dart
  - .docs/Ai_Boom/cac-module/chuoi-cua-hang.md (tài liệu kỹ thuật đầy đủ: DB, RPC, quy tắc nhận xét, ngưỡng)
  - .docs/tinh-nang.md mục "Tạo thêm cửa hàng cho Chủ quán đã có quán"
  - lib/screens/settings_screen.dart (Đổi quán, nút / dòng chỉ dẫn tạo cửa hàng), lib/core/widgets/create_store_sheet.dart
---

# Báo Cáo Nhiều Cửa Hàng / Chuỗi

> Chủ quán có nhiều cửa hàng gộp chúng thành một chuỗi để xem tổng doanh thu và **so sánh các quán với nhau**: quán nào dẫn đầu, quán nào tụt, quán nào có vấn đề.

## Ai dùng được
- **Chỉ Chủ quán.** Quản lý và nhân viên không thấy, không cấp được qua vai trò; máy chủ cũng kiểm lại.
- Ô **"Báo Cáo Nhiều Cửa Hàng / Chuỗi"** (màu xanh chanh) **tự bật một lần** khi Chủ quán sở hữu từ 2 cửa hàng trở lên hoặc đã có chuỗi. Gỡ/thêm lại như mọi module; đã gỡ thì không tự hiện lại.
- Lối phụ: biểu tượng cửa hàng **"Báo cáo chuỗi cửa hàng"** trên đầu màn Báo cáo.

## Chuỗi là gì
- Chỉ là **lớp xem gộp**. Thực đơn, kho, nhân viên, bàn và doanh thu của mỗi cửa hàng **vẫn tách riêng**.
- Chưa dùng chung ví/điểm/khách giữa các quán trong chuỗi.
- Mỗi cửa hàng chỉ thuộc **một** chuỗi tại một thời điểm.

## Các việc thường làm

### 1. Thiết lập thêm cửa hàng (từ 1 quán lên nhiều quán)
Mở thêm chi nhánh / quán mới. **Chỉ tạo được trên web**; trên app (iPhone, iPad, Android, máy POS, máy tính) mục **"Đổi quán"** chỉ có dòng chữ chỉ đường lên web, không có nút tạo.
1. Mở trình duyệt (Chrome, Safari…) vào **quannho.lpm.vn/pos**, đăng nhập bằng **số điện thoại + mật khẩu của Chủ quán** (đúng tài khoản đang dùng trên app).
2. **Cài đặt** → thẻ quán → **"Đổi quán"** → **"Tạo cửa hàng mới"**.
3. Ở **"Tạo quán của bạn"**: nhập **"Tên quán"** → **"Tạo quán ngay"**.
4. Nếu hiện hộp **"Xác thực tạo <tên quán>"**: nhập **mật khẩu đăng nhập** → **"Xác nhận"**. Web tự chuyển sang quán mới.
5. Quán mới có sẵn 4 chức năng **Bán hàng, Báo cáo, Thu Chi, Kho hàng**, các nhóm thu chi và 3 vai trò Thu ngân / Nhân viên / Bếp. Muốn thêm chức năng khác: Trang chủ → **"Sửa"** → ô **"Thêm"**.
6. Quán mới **trống thực đơn, kho, bàn, nhân viên**: nhập lại riêng cho quán này (không tự chép từ quán cũ).
7. Trên app: **Cài đặt** → **"Đổi quán"** → chọn quán mới → nhập mật khẩu là làm việc được, không cần cài lại app.
8. Nhân viên: đưa **mã quán mới** (ở Cài đặt, dạng QN-xxxx) để họ vào bằng **"Kết nối quán"**. Một nhân viên làm được ở nhiều quán; vai trò, chấm công, lương tính riêng từng quán.
9. Quán mới **không tự vào chuỗi**: làm tiếp việc 2 bên dưới.

### 2. Tạo chuỗi và thêm cửa hàng
Có 2 quán trở lên, muốn gom lại xem tổng doanh thu chung: tạo chuỗi rồi thêm các quán vào chuỗi.
1. Mở **Báo cáo chuỗi**. Chưa có chuỗi: "Bạn có N cửa hàng. Tạo một chuỗi để so sánh số liệu các chi nhánh." → **"Tạo chuỗi"**.
2. Hoặc bấm **"Quản lý chuỗi"** → **"Quản lý chuỗi cửa hàng"**:
   - **"Tạo chuỗi mới"**: nhập **"Tên chuỗi"** → **"Tạo"**.
   - **"Thêm cửa hàng của bạn"**: bấm **"Thêm vào chuỗi"** ở từng quán.
   - **"Cửa hàng trong "<chuỗi>""**: **"Gỡ khỏi chuỗi"** → **"Gỡ khỏi chuỗi?"** → **"Gỡ"** (dữ liệu cửa hàng không bị xoá).
3. Có nhiều chuỗi: chọn ở **"Chọn chuỗi"** trên đầu.

### 3. Đọc báo cáo
- Chọn kỳ **Hôm nay / Tuần này / Tháng này**; **"Kỳ trước" / "Kỳ sau"** để xem kỳ cũ.
- Thẻ **"Doanh thu chuỗi"** (số cửa hàng) và **"Số đơn"** (đơn hoàn tất), kèm TB/đơn, tiền mặt, chuyển khoản, giảm giá.
- **"Nhận xét nhanh"**: cảnh báo/ghi nhận tự động (quán nghỉ ngày nào, quán huỷ nhiều, quán giảm giá nhiều, quán mới mở, quán dẫn đầu…), mỗi dòng có giải thích số liệu.
- **"Xếp hạng doanh thu"**: hạng, số đơn, TB/đơn, % chiếm của chuỗi.
- **"So sánh theo chỉ số"**: Doanh thu / Số đơn / TB/đơn / Giảm giá; vạch **"Trung bình chuỗi"**; nhãn **"Cao nhất"**, **"Thấp nhất"**, **"Mới mở"**.
- **"Cơ cấu thanh toán"**: tỷ lệ Tiền mặt / Chuyển khoản / Thẻ / Ví/khác từng quán.
- **"Xu hướng doanh thu theo ngày"**: mỗi quán một đường.

### 4. Hiểu chip tăng / giảm
- So với **cùng kỳ trước**: hôm nay so với **cùng thứ tuần trước** trong cùng khoảng giờ đã trôi qua; tuần/tháng đang chạy so với phần tương ứng của kỳ trước.
- **Xanh / đỏ** chỉ khi thay đổi **vượt mức dao động bình thường** (đã quy đổi theo số ngày có bán). Chip **màu xám**: trong mức bình thường.
- **"Ít dữ liệu"**: chưa đủ đơn mỗi bên để so. **"Quán mới"**: chưa đủ lịch sử. **"Chưa so sánh"** / **"Mới"**: kỳ trước không có số liệu.
- **Chạm vào chip** để đọc lý do.
- Tổng chuỗi **không tính quán mới** khi so sánh ("Chưa tính quán mới (chưa đủ lịch sử để so sánh): …"), nên mở quán mới không làm tổng tăng ảo.

## Lỗi thường gặp
| Thấy gì | Vì sao | Làm gì |
|---|---|---|
| "Bạn cần là Chủ của từ 2 cửa hàng trở lên để lập chuỗi và so sánh." | Mới có 1 cửa hàng | Tạo thêm cửa hàng (việc 1) |
| Trên app không thấy nút "Tạo cửa hàng mới" | Tạo cửa hàng chỉ làm trên web | Mở quannho.lpm.vn/pos trên trình duyệt, làm theo việc 1 |
| Quán mới tạo không thêm / bỏ được chức năng ở Trang chủ | Quán tạo trước bản sửa 19/11 bị thiếu thiết lập ban đầu | Báo hỗ trợ Quán Nhỏ để bổ sung |
| "Chuỗi chưa có cửa hàng nào…" | Chuỗi rỗng | "Quản lý chuỗi" → "Thêm vào chuỗi" |
| "Cửa hàng này đã thuộc một chuỗi khác." | Mỗi quán chỉ ở 1 chuỗi | Gỡ khỏi chuỗi cũ trước |
| "Bạn đã có chuỗi trùng tên này." / "Tên chuỗi phải từ 1 đến 80 ký tự." | Tên chuỗi | Đặt tên khác |
| "Không hiển thị: … (bạn không còn là Chủ của cửa hàng này)." | Đã chuyển chủ cửa hàng đó | — |
| "Chưa có đơn hoàn tất trong kỳ này" | Chưa bán | Đổi kỳ |
| Quán giảm mạnh mà chip xám | Quán nghỉ vài ngày; mỗi ngày bán vẫn bình thường | Đọc "Nhận xét nhanh" để biết ngày nghỉ |
| "Không tải được báo cáo. Thử lại sau." | Mạng / máy chủ | Bấm tải lại |
| "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại." | Hết phiên | Đăng nhập lại |

## Liên quan module khác
- **Báo cáo**: chi tiết từng cửa hàng (nhân viên, kho, huỷ…) — chuyển sang quán đó rồi mở Báo cáo. Báo cáo chuỗi **không** có số liệu từng nhân viên.
- **Cài đặt**: tạo cửa hàng mới, đổi quán.

## Ghi chú cho Chủ Quán (không đưa cho khách)
1. Web có module chuỗi từ 17/10; APK Android và Windows từ bản 1.0.5 build 14; iOS 1.0.5 đang chờ Apple duyệt (nhật ký 17/10) — kiểm tra lại trạng thái phát hành trước khi hướng dẫn khách.
2. Chưa làm: dùng chung ví/điểm/khách trong chuỗi. Nhân viên nhiều cửa hàng: vào được bằng mã quán, vai trò/chấm công/lương riêng từng quán; tên ở báo cáo quán thứ hai lấy theo tài khoản (sửa 19/11, commit 92aa20f).
6. Tạo cửa hàng chỉ trên web (Chủ Quán chốt 19/11); app hiện dòng chữ chỉ đường, cả iOS (không nút, không link). Quán thứ hai trở đi tạo trước bản 19/11 có thể thiếu cấu hình module; ba quán đã gieo bù trên máy chủ 19/11.
3. Số liệu chuỗi dựa trên đơn `completed` — cùng nguồn với tab Doanh thu của Báo cáo, không bị ảnh hưởng bởi lỗi Thu Chi.
4. Chi tiết quy tắc nhận xét và ngưỡng: `.docs/Ai_Boom/cac-module/chuoi-cua-hang.md`.
5. Rà lại 23/10/2026: không có lỗi cần sửa ở module này.
