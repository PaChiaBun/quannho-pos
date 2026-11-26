# Kế hoạch: Module Tính giờ và đặt trước (bi da, phòng karaoke, sân)

Lập 23/11/2026. Chủ Quán duyệt 23/11. Trạng thái: **giai đoạn 1 ĐÃ ÁP lên máy chủ thật 23/11 14:34** (chưa commit). Giai đoạn 2 trở đi chưa làm. Xem mục 8.

## 1. Mục tiêu

Quán bi da, karaoke, sân thể thao dùng được Quán Nhỏ: mở bàn / phòng / sân là đồng hồ chạy, khách gọi đồ ăn uống như quán thường, lúc tính tiền hoá đơn có thêm dòng tiền giờ.

Ràng buộc đã chốt với Chủ Quán: tiền giờ là **một dòng trong hoá đơn**, **không sửa báo cáo**.

Chủ Quán chốt thêm 23/11: **một module chung** cho các ngành, **tên và biểu tượng đổi theo ngành**, và **có đặt sân / đặt bàn hẹn giờ trước**.

## 2. Quyết định chính: module riêng "Tính giờ", bật / tắt như mọi module, chạy trên nền module Bàn

Chủ Quán chốt 23/11: **tách thành module riêng**, vì module là thứ quán bật và tắt. Quán cà phê không bật thì không thấy gì liên quan đến tính giờ.

Module mới mã `tinh_gio`, mặc định TẮT, cần module Bàn đang bật. Khi bật:

- Trang chủ có ô "Tính giờ". Ô này mở màn Bàn (cùng sơ đồ, cùng phiên bàn).
- Trong sửa bàn / sửa khu vực mới hiện ô "Tính tiền giờ theo".
- Thẻ bàn có gắn giá giờ mới hiện đồng hồ.

Khi tắt: ba thứ trên ẩn hết. Bàn đang gắn giá giờ vẫn giữ cấu hình, bật lại là dùng tiếp. Không tắt được khi còn bàn tính giờ đang mở (đang có khách).

Phần "tách" là ở chỗ bật / tắt và phân quyền. Phần dữ liệu và thanh toán vẫn dùng chung với Bàn, vì một bàn bi da, một phòng hát, một sân đều là "một chỗ có khách đang dùng, có đồ gọi kèm, cuối cùng tính tiền một lần". Làm bảng và màn thanh toán riêng nghĩa là viết lại sơ đồ, gọi món, gửi bếp, chuyển bàn, thanh toán, in bill thêm một lần, và báo cáo phải sửa để đọc thêm nguồn thứ hai.

### Tên và biểu tượng theo ngành

Khi bật module, Chủ Quán chọn **loại hình**: Bi da, Karaoke, Cầu lông, Tennis, Pickleball, Bóng bàn, Khác. Một lần chọn đổi ba thứ:

- tên và biểu tượng của ô module ở Trang chủ (ví dụ ô "Bi da" thay cho "Tính giờ");
- cách gọi trong màn hình: "bàn" / "phòng" / "sân";
- biểu tượng mặc định trên thẻ bàn có tính giờ.

Quán có hai loại hình (bi da kèm phòng hát): chọn loại hình chính cho ô module, còn từng khu vực đã có sẵn ô chọn biểu tượng (`_kZoneIconCodes` trong `ban_screen.dart`), chỉ cần thêm các biểu tượng ngành vào danh sách đó.

Loại hình lưu thành một dòng trong `app_settings` (như danh sách module), không cần cột mới.

App đang vẽ biểu tượng bằng bộ Material có sẵn. Bộ này có vợt tennis và micro; hình bi da và cầu lông nhiều khả năng không có, phải kiểm khi làm. Thiếu hình nào thì vẽ thêm hình đó vào `assets/icons/`, cùng nét với bộ đang dùng.

Bản thân việc thêm một module **không cần cột mới** trong cơ sở dữ liệu: danh sách module đang bật của quán là một mảng mã nằm trong một dòng có sẵn (`app_settings`, khoá `module_config_v2`), quyền theo vai trò cũng là mảng mã (`store_roles.modules`). Ba cột mới ở giai đoạn 1 là để lưu giá giờ và giờ vào / giờ ra, làm cách nào cũng phải có.

## 3. Những gì đã kiểm (23/11, mã hiện tại và máy chủ thật, chỉ đọc)

| Điều đã kiểm | Kết quả | Hệ quả cho thiết kế |
|---|---|---|
| Thanh toán bàn (`settle_ban_session_v5`) lấy tổng tiền từ đâu | Cộng các dòng món của phiên bàn trên máy chủ, bỏ dòng đã huỷ | Chỉ cần chèn dòng tiền giờ vào phiên trước khi thanh toán. **Không phải sửa hàm thanh toán.** |
| Tab Sản phẩm của báo cáo gom theo gì | Gom theo mã món; dòng **không có mã món bị bỏ qua** | Dòng tiền giờ phải gắn với một món thật trong Menu, nếu không sẽ không hiện ở tab Sản phẩm |
| Lọc theo danh mục ở tab Sản phẩm | Theo danh mục của món | Món giá giờ đặt vào danh mục "Tiền giờ" là tách được với đồ ăn uống, không cần mã mới |
| Số lượng trong hoá đơn | Có hai cột, một cột là số nguyên | Không ghi "1,5 giờ" làm số lượng. Ghi số lượng 1, đơn giá = tiền giờ đã tính |
| Trừ kho khi thanh toán | Món nào không có công thức cũng bị trừ tồn 1 mỗi lần bán | Món giá giờ sẽ có tồn âm dần, giống mọi món không công thức hiện nay. Không gây lỗi |
| Chốt chặn khi thêm món vào bàn | App chỉ được thêm món ở trạng thái "chưa gửi" / "đã gửi bếp" | Dòng tiền giờ do **hàm máy chủ** ghi với trạng thái "xong", nên không lên phiếu bếp |
| Chuyển bàn | App tự đổi mã bàn của phiên, máy chủ không kiểm | Phải thêm hàm máy chủ cho chuyển bàn có tính giờ (mục 5, giai đoạn 1) |
| Giờ mở bàn | Do máy của nhân viên ghi | Mốc tính giờ phải do máy chủ đặt, tránh máy sai giờ làm sai tiền |
| Doanh thu thuộc ngày nào | Ngày mở hoá đơn | Phòng mở 23 giờ, tính tiền 1 giờ sáng: tiền nằm ở ngày hôm trước. Giữ nguyên như bàn ăn |

## 4. Cách chạy, nhìn từ phía quán

1. **Cài một lần.** Chủ Quán vào Menu tạo món, ví dụ "Giờ bàn lỗ", giá bán = giá một giờ, danh mục "Tiền giờ". Rồi vào sửa bàn (hoặc sửa khu vực để áp cho cả khu), chọn "Tính tiền giờ theo: Giờ bàn lỗ".
2. **Mở bàn.** Nhân viên mở bàn như thường. Thẻ bàn trên sơ đồ hiện đồng hồ đang chạy và tiền giờ tạm tính.
3. **Gọi đồ.** Như quán thường, vẫn gửi bếp / quầy bar.
4. **Tính tiền.** Bấm Tính tiền: máy chủ chốt giờ, thêm dòng "Giờ bàn lỗ · Bàn 3 · 14:05–15:35" vào bàn, rồi mở màn thanh toán như cũ. Mã giảm giá, điểm, in bill, Thu Chi, báo cáo chạy như một hoá đơn bình thường.
5. **Khách chơi tiếp sau khi đã chốt.** Đóng màn thanh toán, lúc sau bấm Tính tiền lại: dòng tiền giờ được tính lại, không sinh dòng thứ hai.
6. **Chuyển bàn.** Giờ ở bàn cũ được chốt thành một dòng theo giá bàn cũ, đồng hồ chạy tiếp ở bàn mới theo giá bàn mới.
7. **Bỏ tiền giờ** (khách khiếu nại, máy tính sai): Quản lý huỷ dòng đó như huỷ món đã gửi bếp, có lý do và có nhật ký.

Cách tính bản đầu: **theo phút thực tế, một giá cho mỗi bàn, làm tròn lên 1.000đ.**

## 5. Các giai đoạn

### Giai đoạn 1 — Máy chủ (một migration, có tệp hoàn tác và test)

Thêm ba cột, đều cho phép để trống nên app đang chạy không bị ảnh hưởng:

| Bảng | Cột mới | Ý nghĩa |
|---|---|---|
| `ban_dining_tables` | `gia_gio_product_id` | Món giá giờ của bàn. Trống = bàn thường |
| `ban_sessions` | `gio_bat_dau` | Mốc bắt đầu đoạn đang tính. Máy chủ tự đặt khi mở phiên trên bàn tính giờ |
| `ban_session_items` | `gio_tu`, `gio_den` | Có giá trị = đây là dòng tiền giờ, kèm giờ vào và giờ ra |

Hai hàm máy chủ mới:

- **`ban_chot_gio_v1`** — kiểm người gọi là thành viên quán và có quyền thanh toán (cùng cách `settle_ban_session_v5` đang kiểm), khoá phiên, tính tiền từ `gio_bat_dau` tới lúc gọi, ghi (hoặc ghi đè) đúng một dòng tiền giờ cho đoạn đang chạy. Giá lấy từ món trên máy chủ, app không gửi giá.
- **`ban_chuyen_ban_tinh_gio_v1`** — chốt đoạn ở bàn cũ, đổi bàn, đặt mốc mới, tất cả trong một giao dịch. Bàn đích đang có khách thì thành gộp bàn: dời hết món (kể cả dòng tiền giờ vừa chốt) sang phiên đích rồi đóng phiên nguồn.

Năm chốt chặn (hai chốt cuối thêm lúc viết mã, 23/11):

- App không tự thêm / sửa tiền / xoá / dời được dòng tiền giờ; chỉ hai hàm trên ghi. Huỷ dòng đi qua đường huỷ có duyệt sẵn có (phục vụ cần Quản lý duyệt, có nhật ký).
- App không sửa được `gio_bat_dau`, và không tự đổi bàn của phiên đang tính giờ hoặc sang bàn tính giờ (phải gọi hàm chuyển bàn).
- Phiên có tính giờ mà chưa chốt giờ, hoặc chốt đã quá 15 phút, thì **không đóng được**, kể cả bằng hàm thanh toán. Lý do: máy còn chạy bản app cũ sẽ thanh toán bàn mà không biết có tiền giờ, quán mất tiền mà không ai hay. Thà báo lỗi còn hơn. Mốc 15 phút chặn kiểu chốt sớm rồi cho khách chơi tiếp.
- **Huỷ bàn tính giờ đã mở quá 5 phút phải chốt giờ trước.** Khi đã có dòng tiền giờ, luật huỷ bàn sẵn có đòi Quản lý duyệt. Không có chốt này, nhân viên huỷ một bàn chỉ chơi không gọi đồ là xong, không ai duyệt. Mở nhầm bàn thì huỷ ngay trong 5 phút vẫn được.
- **Chỉ Chủ quán / Quản lý gắn giá giờ cho bàn**; món giá giờ phải của đúng quán; không đổi giá giờ khi bàn đang có khách tính giờ.

Đổi giá bán của món giá giờ trong Menu lúc bàn đang chạy: giá mới áp cho cả đoạn đang tính (tiền tính lúc chốt, không tính dần).

Tệp: `supabase/migrations/2026MMDD_ban_tinh_gio_v1.sql` + bản `_ROLLBACK`, test `supabase/tests/ban_tinh_gio_v1_test.sql`, tệp áp `db-fix/ban_tinh_gio_ap_dung.sh`. Chạy thử trên bản sao bằng `db-fix/chuoi_stage_dryrun.sh` trước khi áp.

Test phải bác bỏ được: bấm chốt hai lần ra hai dòng; hai máy chốt cùng lúc; chốt phiên của quán khác; app tự chèn dòng tiền giờ; chuyển bàn làm mất hoặc tính trùng thời gian; thanh toán khi chưa chốt; phiên bàn thường bị ảnh hưởng.

### Giai đoạn 2 — App

| Việc | Nơi sửa |
|---|---|
| Đăng ký module `tinh_gio` đủ 8 bước trong `.docs/tinh-nang.md` (mục "Checklist khi thêm module mới"); mặc định tắt; chặn bật khi module Bàn đang tắt; chặn tắt khi còn bàn tính giờ đang mở | `main.dart`, `shared/widgets/module_tile.dart`, `core/database/app_database.dart`, `dashboard_screen.dart`, `role_manager_screen.dart` |
| Chọn loại hình khi bật module (đổi lại được trong chế độ Sửa module); ô module đọc tên + biểu tượng theo loại hình; thêm biểu tượng ngành vào ô chọn biểu tượng khu vực | `shared/widgets/module_tile.dart`, `dashboard_screen.dart`, `ban_screen.dart`, `assets/icons/` |
| Mọi phần tính giờ ở màn Bàn chỉ hiện khi module `tinh_gio` đang bật và người dùng có quyền module này | `lib/screens/ban_screen.dart` |
| Ô "Tính tiền giờ theo" trong sửa bàn; "Áp cho cả khu" trong sửa khu vực | `lib/screens/ban_screen.dart` (phần quản lý bàn) |
| Đọc ba cột mới | model bàn / phiên / món trong `lib/core/repositories/ban_repository.dart` |
| Đồng hồ + tiền tạm tính trên thẻ bàn. Một bộ đếm chung cho cả màn, không phải mỗi thẻ một bộ | `ban_screen.dart` |
| Nút Tính tiền: gọi chốt giờ rồi mới mở thanh toán; nút "Tính lại giờ" trong màn thanh toán | `ban_screen.dart` (`_checkout`) |
| Chuyển bàn, gộp bàn: phiên có tính giờ thì gọi hàm máy chủ mới | `BanRepository.transferSession`, `mergeSession` |
| Dòng tiền giờ trong danh sách món của bàn: không có nút sửa số lượng, không có nút gửi bếp | `ban_screen.dart` |

Phải kiểm khi làm, chưa kiểm lúc lập kế hoạch:

- Bill 58mm (Sunmi) in dòng tên dài có xuống dòng gọn không.
- Màn Bếp và dải "món xong" ở Bàn không báo nhầm dòng tiền giờ là món vừa làm xong.
- Thực đơn QR cho khách có đang hiện mọi món không. Nếu có, phải ẩn món giá giờ để khách không tự đặt "Giờ bàn lỗ".
- Bán tại quầy (`complete_pos_sale_v1`) đóng phiên bàn theo đường riêng: phiên có tính giờ phải bị chốt chặn ở giai đoạn 1 bắt lại.

Test Flutter: tiền tạm tính, luồng nút Tính tiền, chuyển bàn. Chụp ảnh thử có nạp phông biểu tượng trước khi gửi Chủ Quán duyệt giao diện.

### Giai đoạn 3 — Đặt trước (đặt sân, đặt bàn, đặt phòng hẹn giờ)

Làm sau giai đoạn 1 và 2 vì nó dựa trên bàn tính giờ. Đặt trước **không tạo ra doanh thu**: tiền chỉ vào báo cáo khi khách đến, chơi và thanh toán như một bàn tính giờ bình thường. Vì vậy báo cáo vẫn không phải sửa.

**Cách chạy phía quán**

1. Mở "Lịch đặt" trong module, chọn ngày. Máy tính bảng / PC: lưới có cột là từng sân, hàng là giờ (bước 30 phút). Điện thoại: danh sách theo từng sân.
2. Bấm ô trống để đặt: tên khách, số điện thoại, từ giờ nào đến giờ nào, ghi chú.
3. Khách đến: bấm lượt đặt, chọn "Nhận sân". App mở bàn và đồng hồ chạy.
4. Khách không đến: bấm "Không đến" hoặc "Huỷ", khung giờ trống lại.
5. Sơ đồ bàn: thẻ bàn hiện lượt đặt kế tiếp trong ngày ("Đặt 18:00 · Anh Nam"). Mở bàn cho khách vãng lai khi sắp tới giờ đã đặt thì app cảnh báo. Bàn đang chơi lấn sang giờ người khác đã đặt thì thẻ đổi màu.

**Nhắc trước 30 phút** (Chủ Quán chốt 23/11)

- Còn 30 phút tới giờ đặt, app bật một hộp nhắc kèm tiếng chuông: "Sắp tới giờ đặt · Sân 2 · 18:00–19:00 · Anh Nam · số điện thoại". Mục đích: quán gọi nhắc khách.
- Ba nút: **Gọi khách** (mở trình gọi điện trên điện thoại; trên máy tính và web thì hiện số để bấm sao chép), **Đã nhắc**, **Đóng**.
- Một người bấm "Đã nhắc" thì hộp nhắc trên các máy khác tự đóng, và lượt đặt trong Lịch đặt hiện dấu "Đã nhắc 17:32 · Lan". Không ai bấm thì mỗi máy chỉ hiện một lần.
- Ai thấy: người có quyền module này (Chủ quán, Quản lý, nhân viên được gán), vì chủ không phải lúc nào cũng ở quán. Xem câu 8 mục 7.
- Lượt vừa đặt khi còn dưới 30 phút thì không nhắc.
- **Giới hạn: chỉ hiện khi app đang mở.** App chưa có thông báo đẩy (loại hiện cả khi app đóng), nên điện thoại của chủ đang tắt app sẽ không nhận được. Máy bán hàng ở quầy mở suốt giờ bán nên vẫn nhắc được. Làm thông báo đẩy là dựng một hạ tầng mới, xem mục 6.

Cách làm: bộ canh giờ đặt ở Trang chủ (màn luôn mở với mọi người đã đăng nhập, cùng chỗ đang nghe đổi quyền), chỉ chạy khi module đang bật. Nó dùng luôn danh sách lượt đặt hôm nay đã tải sẵn, mỗi phút so giờ một lần trên máy, không hỏi thêm máy chủ. Chuông dùng lại bộ phát âm của đơn QR (`qr_sound_service.dart`), nút gọi dùng `url_launcher` đã có trong app. Bảng `ban_dat_truoc` thêm hai ô: nhắc lúc nào, ai nhắc; ghi qua một hàm máy chủ.

**Tính tiền cho lượt đặt** (mặc định, xem mục 7): tính theo khung đã đặt, kể cả khi khách đến trễ; chơi quá giờ thì tính thêm theo phút. Phần tính nằm trong `ban_chot_gio_v1`, app không đổi.

**Máy chủ** (migration thứ hai, có tệp hoàn tác và test)

- Bảng mới `ban_dat_truoc`: quán, bàn, tên khách, số điện thoại, giờ từ, giờ đến, ghi chú, trạng thái (đã đặt / đã nhận / huỷ / không đến), phiên bàn đã gắn, người tạo. Có `store_id`, chỉ thành viên quán đọc được.
- **Chống đặt trùng ở cơ sở dữ liệu**: một ràng buộc không cho hai lượt còn hiệu lực trùng giờ trên cùng một bàn. Hai nhân viên đặt cùng lúc thì một người nhận báo lỗi, không bao giờ có hai lượt chồng nhau.
- Ba hàm: tạo / sửa lượt đặt, huỷ hoặc đánh dấu không đến, nhận sân (gắn lượt đặt với phiên bàn và đặt mốc tính giờ, trong một giao dịch). App không ghi thẳng vào bảng.
- Số điện thoại khách là dữ liệu cá nhân: Boom không đọc bảng này.

**App**

| Việc | Nơi sửa |
|---|---|
| Màn "Lịch đặt" (lưới tự vẽ bằng thành phần có sẵn, không thêm thư viện lịch), bọc `ResponsiveLayout` | màn mới trong `lib/modules/tinh_gio/` |
| Hộp đặt / sửa / huỷ / nhận sân | cùng thư mục |
| Thẻ bàn hiện lượt đặt kế tiếp, cảnh báo khi mở bàn sát giờ đặt, đổi màu khi lấn giờ | `lib/screens/ban_screen.dart` |
| Bộ canh giờ + hộp nhắc trước 30 phút, chuông, nút gọi | `dashboard_screen.dart`, widget mới trong `lib/modules/tinh_gio/` |
| Đọc lượt đặt theo kiểu tải lại khi máy chủ báo đổi (`watchByRefetch`, như món của bàn) | kho dữ liệu mới cạnh `ban_repository.dart` |

Test phải bác bỏ được: hai lượt trùng giờ cùng sân; đặt cho sân của quán khác; nhận sân hai lần; huỷ lượt đã nhận; lượt đặt qua nửa đêm; tiền tính sai khi khách đến trễ hoặc chơi lố; hộp nhắc hiện hai lần trên một máy; nhắc lượt đã huỷ hoặc đã nhận sân; người không có quyền module vẫn thấy hộp nhắc (lộ số điện thoại khách).

### Giai đoạn 4 — Tài liệu

- Bài hướng dẫn trong `.docs/Huong_dan/` (bài Bàn): thêm mục bàn tính giờ và đặt trước, xuất lại cho Boom, đóng dấu. Đăng cho app đang chạy thì hỏi Chủ Quán trước.
- `.docs/kien-truc-data.md`, `.docs/tinh-nang.md`.
- `codegraph sync .`, `graphify update .`.

### Giai đoạn 5 — Thử và phát hành

1. Thử trọn vòng trên quán Demo: đặt trước, nhận sân, mở bàn vãng lai, gọi đồ, chuyển bàn, chốt, thanh toán, xem tab Doanh thu, tab Sản phẩm (lọc "Tiền giờ"), Thu Chi, bill in.
2. Áp migration lên máy chủ (hỏi Chủ Quán trước khi áp).
3. Phát hành: mặc định một bản có đủ tính giờ và đặt trước. Nếu có quán bi da hoặc karaoke cần sớm thì phát hành sau giai đoạn 2, đặt trước đi bản kế tiếp; hai phần tách được vì đặt trước nằm ở migration riêng.
4. Quán bật bàn tính giờ phải cập nhật **tất cả** máy lên bản mới. Máy còn bản cũ sẽ không thanh toán được bàn tính giờ (chốt chặn ở giai đoạn 1).

## 6. Chưa làm ở bản đầu

| Việc | Lý do để sau |
|---|---|
| Giá theo khung giờ (ngày / tối, giờ cao điểm, cuối tuần) | Karaoke và sân thường cần. Thêm sau bằng một bảng giá theo khung, chỉ đổi phần tính trong `ban_chot_gio_v1`, app và báo cáo không đổi |
| Lịch cố định lặp hàng tuần (khách đặt thứ 3-5-7 cả tháng) | Bản đầu đặt từng lượt. Sân cầu lông hay cần cái này, nên là việc làm ngay sau bản đầu |
| Khách tự đặt qua mạng | Cần trang cho khách, chống phá, xác nhận. Bản đầu nhân viên đặt hộ khi khách gọi điện |
| Nhắc lịch thẳng tới khách (tin nhắn, Zalo) | Cần dịch vụ gửi tin bên ngoài, có phí. Bản đầu app nhắc quán, quán gọi khách |
| Thông báo đẩy khi app đang đóng | App chưa có hạ tầng này: phải đăng ký dịch vụ đẩy cho Android và iOS, xin quyền thông báo, qua duyệt cửa hàng ứng dụng. Windows và web cần cách riêng |
| Chỉnh số phút nhắc trước | Bản đầu cố định 30 phút |
| Tiền cọc tự vào Thu Chi và tự trừ vào hoá đơn | Đụng tới tiền và hoàn tiền khi huỷ. Bản đầu chỉ ghi số tiền đã cọc lên lượt đặt để nhân viên biết |
| Tạm dừng đồng hồ, thời lượng tối thiểu, phụ thu ngày lễ | Chờ quán thật yêu cầu |
| Tab báo cáo công suất (bàn nào kín, khung giờ nào đông) | Giờ vào, giờ ra đã lưu trên từng dòng nên làm sau không phải nhập lại dữ liệu |
| Mỗi ngành một module riêng ("Bi da", "Karaoke", "Sân") | Bản đầu một module "Tính giờ" dùng chung. Tách tên theo ngành khi từng ngành có tính năng riêng (ví dụ đặt sân trước) |

## 7. Chờ Chủ Quán chốt

Nếu không có ý kiến khác, làm theo lựa chọn in đậm.

1. Cách làm tròn: **theo phút, làm tròn lên 1.000đ**, hay theo khối (ví dụ mỗi 15 phút)?
2. Giá theo khung giờ: **để sau bản đầu**, hay phải có ngay? Nếu quán đầu tiên là karaoke thì nên có ngay.
3. Mã giảm giá và điểm thưởng: **áp trên cả tiền giờ** (không phải sửa gì), hay chỉ áp trên đồ ăn uống (phải sửa hàm thanh toán)?
4. Quán nào thử đầu tiên?
5. Lượt đặt trước tính tiền thế nào: **theo khung đã đặt, đến trễ vẫn tính đủ, chơi lố tính thêm theo phút**, hay tính theo giờ chơi thực tế như khách vãng lai?
6. Tiền cọc: **bản đầu chỉ ghi số tiền lên lượt đặt**, hay phải vào Thu Chi và tự trừ vào hoá đơn ngay?
7. Lịch cố định hàng tuần: **làm ngay sau bản đầu**, hay phải có trong bản đầu?
8. Hộp nhắc trước 30 phút hiện cho ai: **mọi người có quyền module này**, hay chỉ tài khoản Chủ quán?

## 8. Nhật ký thực hiện

### 23/11 — Giai đoạn 1 (máy chủ): viết xong, ĐÃ ÁP production 14:34

Tệp:

- `supabase/migrations/20261123_ban_tinh_gio_v1.sql` và bản `_ROLLBACK`
- `supabase/tests/ban_tinh_gio_v1_test.sql` (50 mục, tự ROLLBACK)
- `../db-fix/ban_tinh_gio_ap_dung.sh` (backup → áp → test; `DRYRUN=1`, `ROLLBACK=1`)

Chạy thử trên bản sao của máy chủ thật (`chuoi_stage_dryrun.sh`, máy chủ thật chỉ bị đọc, bản sao đã xoá):

- Bộ test mới: 50/50 qua. Có gọi `settle_ban_session_v5` thật và `get_top_products_for_range_v1` thật: hoá đơn có dòng tiền giờ, báo cáo món bán chạy thấy đúng tiền mà không sửa hàm nào.
- Bộ test cũ về bàn chạy sau khi áp: `chan_dong_phien_ban_v1` 16/16, `ops_ban_giao_ca_v1` 16/16, `topping_ban_tru_kho_v1` qua.
- Áp lại lần hai không lỗi. Hoàn tác sạch (0 hàm, 0 trigger, 0 cột còn sót), áp lại sau hoàn tác vẫn 50/50.

Lỗi bắt được nhờ chạy thử: `qn_is_store_manager_v1` không cấp cho vai app, trigger gắn giá giờ gọi thẳng thì báo "permission denied". Đã dời phần kiểm quyền vào hàm phụ chạy bằng quyền máy chủ.

Chưa kiểm được trong một giao dịch test: hai máy bấm chốt đúng cùng một lúc. Hàm khoá phiên bàn trước khi ghi nên về lý thuyết xếp hàng; T6 chỉ chứng minh bấm lại không sinh dòng thứ hai.

Điều cần biết cho giai đoạn 2:

- Giờ in trên dòng bỏ phần giây, còn số phút tính tiền làm tròn lên, nên có thể lệch nhau 1 phút ("13:00–14:29 (1g30)").
- `settle_ban_session_v5` khi bàn chưa chốt giờ sẽ **văng lỗi** `CHUA_CHOT_GIO` / `CHOT_GIO_QUA_CU` (không trả `success:false`). App phải bắt hai mã này, gọi `ban_chot_gio_v1` rồi cho thu ngân xem lại tổng.
- Huỷ bàn tính giờ mở quá 5 phút: app gọi `ban_chot_gio_v1` trước rồi mới đi luồng huỷ bàn có duyệt.
- Chuyển / gộp bàn: khi phiên nguồn có `gio_bat_dau` hoặc bàn đích có `gia_gio_product_id` thì gọi `ban_chuyen_ban_tinh_gio_v1`, còn lại giữ đường cũ.
- Gộp bàn thường VÀO bàn tính giờ vẫn đi đường cũ của app (không có dòng tiền giờ nào phải dời).

**Áp production 23/11 14:34** (Chủ Quán bảo "Áp lên máy chủ"): `bash db-fix/ban_tinh_gio_ap_dung.sh`, mất 11 giây kể cả sao lưu. Mốc hoàn tác: `/root/quannho-backups/quannho_before_ban_tinh_gio_20261123_143355.dump`; nhật ký `db-fix/ban_tinh_gio_log_20261123_143355.txt`. Test chạy lại ngay trên máy chủ thật: 50/50, tự ROLLBACK. Kiểm sau khi áp: 9 hàm, 3 trigger, 4 cột; không sót dữ liệu test; chưa bàn nào gắn giá giờ nên chưa quán nào đổi hành vi.

Sau khi áp 5 phút: 2 hoá đơn bán quầy mới, 0 dòng lỗi trong `app_logs`. Không quán nào mở bàn trong 5 phút đó (và 30 phút trước khi áp), nên luồng bàn của khách thật chưa chạy qua trigger mới; cần xem lại sau giờ đông. Commit `a125c2d` (đã đẩy).

### 23/11 — Giai đoạn 2 (app): phần nền (xem tiếp mục dưới cho phần giao diện)

- `lib/modules/tinh_gio/tinh_gio.dart`: phép tính tạm tính ở app (số phút, tiền, thời lượng, đồng hồ), nhận ra lỗi `CHUA_CHOT_GIO` / `CHOT_GIO_QUA_CU`, luật "khi nào phải chuyển bàn bằng hàm máy chủ", luật "huỷ bàn phải chốt trước".
- `lib/core/repositories/ban_repository.dart`: ba lớp dữ liệu đọc cột mới (`giaGioProductId`, `gioBatDau`, `gioTu` / `gioDen`); `chotGio`, `chuyenBanTinhGio`, `datGiaGio`.
- `test/modules/tinh_gio/tinh_gio_test.dart`: 10 test, các số trùng với test máy chủ (T5, T7, T9, T12, T14).
- `flutter analyze` không thêm cảnh báo. `test/core test/screens test/docs`: 851 qua, 1 hỏng là `huong_dan_dong_bo_test` (bài `quan-ly-ban.md` phải rà lại vì `ban_repository.dart` đổi; bài `bat-dau.md` đã đỏ từ trước do thay đổi khác đang dở). Rà và đóng dấu bài Bàn khi làm xong giao diện.

Đã đọc và chốt cách đăng ký module (chưa viết):

- Ô module không cần chỉ số tab riêng: `_navigateTo('/tinh_gio')` mở tab Bàn (chỉ số 7), như `qr_order`, `chain` đang tự mở màn riêng. Vậy không phải đụng `main.dart`.
- Chỗ phải thêm mã: `_kAllModules` (`module_repository.dart`), `kModuleConfigs` (`module_tile.dart`), `permMap` và `_navigateTo` (`dashboard_screen.dart`). Quyền: ai có quyền Bàn (`ban`) thì thấy ô Tính giờ, không thêm ô chọn quyền riêng.
- Bộ biểu tượng Material của app **không có** bi da, cầu lông, bóng bàn, pickleball (`pool` là hồ bơi); chỉ có `sports_tennis` và `mic_external_on`. Ô module chỉ nhận `IconData`. Chờ Chủ Quán chọn: vẽ thêm hình riêng hay dùng emoji.

Điểm móc vào `lib/screens/ban_screen.dart` (13.458 dòng) cho phần giao diện: `_TableFormSheet` (ô chọn giá giờ), `_ZoneFormSheet` (áp cả khu), `_TableCard` (đồng hồ, tạm tính), `_TableSessionSheet` (dòng tiền giờ, nút Tính tiền gọi chốt trước), `_CheckoutSheet` (bắt lỗi cần chốt, nút Tính lại giờ), `_TransferTableSheet` (chuyển / gộp qua máy chủ), `runCancelSteps` (chốt trước khi huỷ).

### 23/11 — Giai đoạn 2 (app): đã viết giao diện chính (kết quả chạy thử ở mục dưới), CHƯA commit

Đã viết (tất cả theo dữ liệu: bàn có `gia_gio_product_id`, phiên có `gio_bat_dau`; cờ module chỉ gác phần cấu hình và ô ở Trang chủ):

| Việc | Ở đâu |
|---|---|
| Module `tinh_gio` "Tính giờ", mặc định tắt, biểu tượng tạm là đồng hồ; ô mở tab Bàn; bật thì bật kèm module Bàn nếu chưa bật; ai có quyền Bàn thì thấy | `module_repository.dart`, `module_tile.dart`, `dashboard_screen.dart`, `module_picker_screen.dart` |
| Giữ lâu vào bàn trống → "Tính tiền giờ" → hộp chọn món giá giờ, có "Áp cho cả khu", có gỡ | `ban_screen.dart` (`_TableOptionsSheet`), `lib/modules/tinh_gio/tinh_gio_widgets.dart` |
| Thẻ bàn: bàn trống ghi giá/giờ; bàn có khách ghi thời lượng + tiền giờ tạm tính, tổng đã gồm tiền giờ tới lúc xem; một nhịp 20 giây chung cho mọi thẻ | `ban_screen.dart` (`_TableCard`) |
| Màn chi tiết bàn: dải "Đang tính giờ … tạm tính … chốt khi bấm Thanh toán"; không sửa số lượng dòng tiền giờ | `ban_screen.dart` (`_TableSessionSheet`, `_updateItemQty`) |
| Bấm Thanh toán: gọi `ban_chot_gio_v1`, tải lại món rồi mới mở màn thanh toán; chốt lỗi thì không mở | `ban_screen.dart` (`_openCheckout`) |
| Máy chủ từ chối vì chưa chốt / chốt quá 15 phút: báo rõ "đóng màn thanh toán rồi bấm lại", không coi là lỗi mạng mơ hồ | `ban_repository.dart` (`_settleBanSessionV5`) |
| Chuyển bàn, gộp bàn: có tính giờ thì gọi `ban_chuyen_ban_tinh_gio_v1`; máy chưa biết bàn có tính giờ mà bị máy chủ chặn thì tự đi đường máy chủ | `ban_screen.dart` (`_chuyenHoacGop`) |
| Huỷ bàn tính giờ mở quá 5 phút: chốt giờ trước, rồi đi luồng huỷ có PIN Quản lý sẵn có | `ban_screen.dart` (`_cancelSession`) |

Kiểm đã làm: `flutter analyze lib` 0 lỗi, không thêm cảnh báo ở các tệp đã sửa; `flutter test` 1280 qua, 1 hỏng; test riêng `test/modules/tinh_gio` 15/15. Mục hỏng là `huong_dan_dong_bo_test`, đã đỏ từ trước vì nhiều tệp khác đang sửa dở; phần tôi thêm vào danh sách của nó: `quan-ly-ban.md`, `kho-hang.md`, `ho-tro-ky-thuat.md` (do `ban_screen.dart`, `ban_repository.dart`).

**Chưa làm / chưa kiểm:**

- Chưa chạy thử một vòng trong app thật trên quán Demo (cần đăng nhập). Mọi phần giao diện ở trên mới qua biên dịch và kiểm lỗi tĩnh.
- Chọn loại hình + biểu tượng theo ngành: chờ Chủ Quán chọn cách làm biểu tượng.
- Chưa chặn tắt module khi còn bàn đang tính giờ. Bỏ: tắt module không làm hỏng thanh toán vì phần chốt giờ đi theo dữ liệu.
- Ba mục "phải kiểm khi làm" ở giai đoạn 2 (bill 58mm, màn Bếp, thực đơn QR) chưa kiểm.
- Cột bên phải ("đang phục vụ") vẫn hiện tổng món, chưa cộng tiền giờ tạm tính.
- Lời trong hộp huỷ bàn vẫn nói "món đã nấu" khi dòng duy nhất là tiền giờ.

### 23/11 chiều — Chạy thử thật trên quán Demo (bản web chạy tại máy, số liệu đối chiếu trên máy chủ)

Đã chạy và khớp trên máy chủ (4 phiên bàn, 3 hoá đơn QN-20261123-001…003, 0 dòng lỗi trong `app_logs`):

| Việc thử | Kết quả |
|---|---|
| Bật module Tính giờ từ "Thêm Modules" | Ô hiện ở Trang chủ; bấm ô mở màn Bàn; cấu hình module của quán có thêm `tinh_gio` |
| Giữ lâu bàn A1 → "Tính tiền giờ" → chọn món | Hộp chọn hiện đủ (áp cả khu, tìm món, gỡ); thẻ bàn trống ghi "25.000 đ/giờ"; máy chủ lưu đúng |
| Mở bàn A1 | Máy chủ đặt mốc giờ (lệch 1 giây so với giờ máy) |
| Gọi 1 món rồi Thanh toán | Dải "Đang tính giờ 2p • tạm tính 1.000 đ"; màn Thu tiền 57.000 = món 55.000 + giờ 2.000; hoá đơn có dòng "Cà phê sữa đá · A 1 · 16:42–16:44 (3p)"; báo cáo món bán chạy thấy đúng |
| Bàn không gọi món → "Tính tiền giờ" | Ra màn Thu tiền 1.000đ, thanh toán được. Bấm Huỷ bỏ rồi vào lại: vẫn một dòng tiền giờ, chốt lại không sinh dòng thứ hai |
| Chuyển A1 (tính giờ) → A2 (bàn thường) | Dòng tiền giờ của đoạn ở A1 đi theo sang A2; A2 không chạy đồng hồ; thanh toán A2 được |
| Huỷ bàn A1 trong 5 phút đầu | Hộp huỷ bàn thường (chọn lý do), không đòi chốt giờ, không đòi PIN |
| Thẻ bàn đang chạy giờ trên sơ đồ | "1 khách • 0 món", "2p • giờ 1.000 đ", tổng 1.000đ |

Lỗi tìm ra khi thử và đã sửa:

- **Bàn tính giờ chưa gọi món không tính tiền được**: màn chi tiết chỉ hiện "Chưa có món nào", không có dải đồng hồ, không có nút thanh toán. Đã thêm dải và nút "Tính tiền giờ" (đã thử lại, chạy đúng).
- Dòng tiền giờ mang nhãn "Bếp xong". Đã đổi thành "Tiền giờ" (sửa sau lượt thử, chưa nhìn lại trên app).

Chưa thử: gộp bàn; chuyển bàn thường → bàn tính giờ và tính giờ → tính giờ; huỷ bàn sau 5 phút (cần PIN Quản lý, Claude không gõ PIN); chốt quá 15 phút; in bill; màn Bếp; app Android thật (mới thử trên web).

Còn lại sau lượt thử:

- Tên dòng do máy chủ ghi lấy giờ ra thật ("16:59–16:59 (1p)") nên lệch với số phút tính tiền. Nên in giờ ra = giờ vào + số phút tính tiền. Đây là sửa hàm máy chủ, cần áp lại.
- Ô ghi chú "cho nhà bếp" vẫn hiện trên dòng tiền giờ.
- Quán Demo đang để: module Tính giờ BẬT, bàn A1 gắn giá giờ "Cà phê sữa đá" 25.000/giờ, 3 hoá đơn thử. Chưa hoàn nguyên.

Về cách thử: bản web debug tại máy không lấy được vé vào quán vì `PosJwtAuthService.isConfigured` chỉ nhận `https` (cấu hình `pos-web` + lớp chuyển tiếp `http://localhost:8091` trong `.claude/launch.json` có từ trước khi có điều kiện này). Lượt này sửa tạm tại máy cho nhận `http://localhost` ở bản web debug, **đã gỡ, không commit**. Muốn thử web tại máy lần sau phải làm lại bước đó hoặc dựng lớp chuyển tiếp `https`.

### 24/11 — Loại hình và biểu tượng theo ngành: đã viết, chờ Chủ Quán duyệt hình, CHƯA commit

Chủ Quán chọn 23/11: vẽ hình riêng (không dùng emoji).

- `lib/modules/tinh_gio/nganh_icon.dart`: bốn hình bộ Material không có (bi da, cầu lông, bóng bàn, pickleball), vẽ bằng `CustomPainter` trên lưới 24×24, một màu. Không thêm thư viện, không thêm tệp phông. Karaoke, Tennis, "Tính giờ" dùng biểu tượng Material có sẵn.
- `lib/modules/tinh_gio/loai_hinh.dart`: 7 loại hình (Bi da, Karaoke, Cầu lông, Tennis, Pickleball, Bóng bàn, Tính giờ), mỗi loại có tên ô, dòng phụ, cách gọi (bàn / phòng / sân), mã biểu tượng khu vực. Lưu ở `app_settings`, khoá `tinh_gio_loai_hinh`.
- Ô module nhận hình tự vẽ (`ModuleTileData.iconBuilder`); Trang chủ đổi tên + biểu tượng ô Tính giờ theo loại hình.
- Hộp "Quán thuộc loại hình nào?" hiện ngay sau khi bật module, và mở lại được từ dòng "Loại hình: … • Đổi" trong hộp chọn giá giờ.
- Ô chọn biểu tượng khu vực có thêm 6 hình ngành (mã `0xF1A01`–`0xF1A06`, ngoài vùng mã MaterialIcons). App bản cũ gặp mã này sẽ hiện hình bàn mặc định.
- Ảnh để duyệt: `test/modules/tinh_gio/goldens/nganh_icon.png`, `chon_loai_hinh_360.png` (chụp lại: `flutter test test/modules/tinh_gio/nganh_icon_golden_test.dart --update-goldens`).

Chưa làm: cách gọi "bàn / phòng / sân" mới lưu trong loại hình, chưa thay vào chữ trên màn Bàn. Chưa chạy trong app thật (mới qua test và ảnh chụp).

### 24/11 — Giai đoạn 3 (đặt trước + nhắc 30 phút): máy chủ ĐÃ ÁP production 12:48, app đã viết, chưa chạy trong app thật

**Máy chủ** — `supabase/migrations/20261124_ban_dat_truoc_v1.sql` (+ `_ROLLBACK`), test `supabase/tests/ban_dat_truoc_v1_test.sql` (40 mục), tệp áp `../db-fix/ban_dat_truoc_ap_dung.sh`.

- Bảng `ban_dat_truoc`. App chỉ đọc (vai `authenticated`, đúng quán); vai `anon` không đọc được vì có số điện thoại khách.
- `ban_dat_truoc_luu_v1`, `ban_dat_truoc_doi_trang_thai_v1`, `ban_dat_truoc_nhan_v1`, `ban_dat_truoc_da_nhac_v1`.
- Chống đặt trùng: khoá theo bàn (`pg_advisory_xact_lock`) rồi kiểm trong hàm lưu. **Không dùng ràng buộc loại trừ** như kế hoạch ban đầu vì máy chủ chưa có extension `btree_gist`; app không ghi thẳng được vào bảng nên kiểm trong hàm là đủ.
- Tính tiền lượt đặt theo khung: lúc nhận, mốc giờ của phiên lùi về giờ đặt nếu khách đến trễ; lúc chốt để thanh toán, tính tới hết khung nếu khách về sớm. Chuyển bàn giữa chừng thì đoạn bàn cũ chỉ tính tới lúc chuyển.
- Kèm sửa tên dòng tiền giờ: giờ ra in = giờ vào + số phút tính tiền (hết cảnh "16:59–16:59 (1p)").
- Chạy thử trên bản sao: test đặt trước 40/40; test tính giờ 23/11 vẫn 50/50; chặn đóng phiên 16/16; bàn giao ca 16/16; áp lại lần hai không lỗi; hoàn tác trả đúng hàm cũ (test 23/11 qua sau hoàn tác), áp lại sau hoàn tác qua.

**App**

| Việc | Ở đâu |
|---|---|
| Dữ liệu, luật thuần (nhắc 30 phút, lượt kế tiếp, báo trùng), kho đọc ghi | `lib/modules/tinh_gio/dat_truoc.dart` |
| Màn "Lịch đặt" (mỗi bàn một thẻ, điện thoại 1 cột / máy tính bảng 2 / màn rộng 3), hộp đặt / sửa, hộp việc của lượt đặt (gọi, nhận, sửa, không đến, huỷ) | `lib/modules/tinh_gio/dat_truoc_ui.dart` |
| Nút "Lịch đặt" ở đầu màn Bàn; thẻ bàn hiện "Đặt 18:00 • tên khách" (trong 12 giờ tới); mở bàn có lượt đặt trong 60 phút tới thì hỏi "khách đặt đã đến" hay "khách khác" | `lib/screens/ban_screen.dart` |
| Hộp nhắc trước 30 phút: chuông, "Gọi khách", "Đã nhắc", "Đóng"; người khác bấm "Đã nhắc" thì hộp trên máy này tự đóng | `TinhGioNhacDatSan` trong `dat_truoc_ui.dart`, gắn ở khung chính `lib/main.dart` |

Lệch so với kế hoạch:

- Màn Lịch đặt là **danh sách theo bàn**, chưa phải lưới giờ × sân. Lưới giờ để sau nếu quán cần nhìn khoảng trống theo giờ.
- Bộ canh giờ nhắc gắn ở **khung chính** (`main.dart`), không phải Trang chủ: Trang chủ không còn được giữ mở khi sang màn khác (`ActiveModuleHost` chỉ dựng màn đang chọn).
- Nhắc mỗi 30 giây so giờ một lần (kế hoạch ghi mỗi phút).

Kiểm đã làm: `flutter analyze lib` 0 lỗi, không thêm cảnh báo; `flutter test` 1295 qua, 1 hỏng (test nhắc rà bài hướng dẫn, đỏ từ trước); test riêng `test/modules/tinh_gio` gồm 8 test luật đặt trước. Ảnh chụp: `goldens/lich_dat_360.png`, `lich_dat_1024.png`.

**Chưa kiểm:** chưa chạy trong app thật (bảng chưa có trên máy chủ thật). Hộp nhắc, hộp đặt, nhận sân mới qua biên dịch và test luật, chưa bấm thử. Chuông khi app đang ở màn khác và trên web chưa thử.

**Áp production 24/11 12:48** (Chủ Quán bảo "Áp lên máy chủ"): `bash db-fix/ban_dat_truoc_ap_dung.sh`, 13 giây kể cả sao lưu. Mốc hoàn tác `/root/quannho-backups/quannho_before_ban_dat_truoc_20261124_124822.dump`; nhật ký `db-fix/ban_dat_truoc_log_20261124_124822.txt`. Chạy lại ngay trên máy chủ thật: test đặt trước 40/40, test tính giờ 23/11 qua hết, đều tự ROLLBACK. Kiểm sau khi áp: 1 bảng, 4 hàm, hàm ghi dòng tiền giờ đã là bản 3 tham số, bảng có trong kênh realtime, vai `anon` không có quyền đọc, 0 dòng dữ liệu, không sót quán test.

### 24/11 chiều — Chạy thử đặt trước trên app Android thật (máy ảo, quán Demo), đối chiếu máy chủ

Bản release cài lên máy ảo Android, Chủ Quán tự đăng nhập quán Demo, Claude điều khiển qua adb.

| Việc thử | Kết quả |
|---|---|
| Mở Lịch đặt từ nút ở đầu màn Bàn | Hiện bàn A1 (bàn có giá giờ), đọc được bảng trên máy chủ |
| Đặt 13:30–14:00, tên + số điện thoại | Máy chủ ghi đúng, danh sách cập nhật ngay |
| Hộp nhắc trước 30 phút | Tự bật lúc 13:00 (đúng mốc), đủ bàn / giờ / tên / số điện thoại, 3 nút |
| Bấm "Đã nhắc" | Máy chủ ghi giờ và tên người nhắc; lịch hiện "đã nhắc 13:01" |
| "Khách đã đến: nhận A 1" (đến sớm 29 phút) | Lượt đặt "Đã nhận", bàn mở, mốc giờ = lúc đến |
| Thanh toán | 25.000đ: tính từ 13:01 tới hết khung 14:00; dòng "… · 13:01–14:00 (59p)"; hoá đơn QN-20261124-001 |
| Lượt thứ hai 14:00–14:30, nhận lúc 13:08 | Thẻ bàn "khung đặt 1g22 • giờ 35.000 đ"; thanh toán đúng 35.000đ, hoá đơn QN-20261124-002 |

Lỗi tìm ra khi thử, đã sửa và thử lại:

- Tiền tạm tính trên thẻ bàn và dải trong màn chi tiết tính theo giờ thực (1.000đ) trong khi máy chủ sẽ thu theo khung (25.000đ). Nay app tạm tính tới hết khung đã đặt, khớp máy chủ.
- Hộp chọn giờ ở kiểu gõ số không nhận "13" (đòi kiểu 12 giờ). Đã ép kiểu 24 giờ.
- Danh sách lượt đặt xếp ngược: `order('gio_tu')` của thư viện mặc định giảm dần. Đã ghi rõ tăng dần và xếp lại ở app.
- Nhãn ô tiền cọc bị cắt trên màn hẹp. Đã rút gọn.

Chưa thử: sửa lượt đặt, huỷ, "khách không đến", báo trùng giờ trên app (máy chủ đã có test); mở bàn từ sơ đồ khi có lượt đặt sắp tới; nút "Gọi khách"; hai máy cùng mở để xem hộp nhắc tự đóng; chuông (máy ảo không nghe được); in bill.

Điều cần biết: lượt "Đã nhận" vẫn giữ khung giờ của nó tới hết khung dù khách đã thanh toán và về sớm, nên chưa đặt người khác vào phần còn lại của khung đó được.

Quán Demo sau lượt thử: 2 lượt đặt "Đã nhận", 2 hoá đơn thử hôm 24/11 (cộng 3 hoá đơn hôm 23/11), module Tính giờ vẫn bật, bàn A1 vẫn gắn giá giờ.

### 24/11 — Rà bài hướng dẫn cho Boom

- Bài mới `.docs/Huong_dan/tinh-gio.md` (module `tinh_gio`): 19 việc thường làm + 12 dòng lỗi thường gặp, thành 31 đoạn cho Boom. Tên nút và câu báo lỗi chép từ mã. Thêm vào `MUC-LUC.md`; bài Bắt đầu và bài Bàn có thêm dòng trỏ sang.
- Trong lúc rà thấy app và bài cùng ghi "vào Menu tạo món" trong khi app không có mục tên Menu: món tạo ở **Kho hàng → "Thêm sản phẩm"**. Đã sửa cả chữ trong hộp chọn giá giờ lẫn bài.
- Đã xuất lại `assets/boom_help/huong_dan.json` (481 đoạn, bản 202611240617) và đóng dấu `tinh-gio.md`, `quan-ly-ban.md`, `kho-hang.md`. Test đồng bộ không còn báo ba bài này. `flutter test test/features/ai_assistant` 131/131.
- **CHƯA đăng cho Boom đang chạy** (`db-fix/dang_huong_dan_boom.sh`): tính năng chưa phát hành, đăng bây giờ Boom sẽ chỉ khách dùng thứ họ chưa có. Bài mới đi kèm trong bản app kế tiếp qua tệp `huong_dan.json`; đăng riêng khi bản đó tới tay quán.
- Chưa commit hai tệp sinh ra (`assets/boom_help/huong_dan.json`, `.docs/Huong_dan/nguon_hash.json`): chúng đang chứa cả ba chỗ sửa bài dở của việc trước (bài Bếp, Hỗ trợ kỹ thuật, Bàn, về nút Gửi bếp mờ) chưa được commit. Commit riêng phần của Tính giờ sẽ làm kho mã lệch với bài gốc.
- Test đồng bộ vẫn báo các bài sau, đều có tệp của việc khác chưa rà: `bao-cao`, `bat-dau`, `ho-tro-ky-thuat`, `in-hoa-don`, `khach-hang`, `luong`, `nhan-vien`, `nhat-ky-log`, `thu-chi`, `van-hanh`. Trong đó việc này có góp: `ban_screen.dart` (bài Hỗ trợ kỹ thuật), `main.dart` (bài Lương), `dashboard_screen.dart` và `MUC-LUC.md` (bài Bắt đầu). Ba bài này đã lệch từ trước nên chưa đóng dấu.


### 24/11 — Đổi tên module thành "Các hoạt động tính giờ", ô có cụm bốn hình

Chủ Quán yêu cầu: đổi tên module, và ô vuông ở Trang chủ có nhiều biểu tượng (bi da, cầu lông, sân banh…).

- Tên mới ở ô Trang chủ, danh sách thêm module và bài hướng dẫn: **Các hoạt động tính giờ** (hằng `kTenModuleTinhGio`). Mã module `tinh_gio` giữ nguyên, không đổi gì ở máy chủ.
- Ô mặc định vẽ cụm 2×2: bi số 8, quả cầu lông, quả bóng đá, micro karaoke (`NganhCumIcon`), tên hai dòng, dòng phụ "Bi da, sân, karaoke".
- Hộp chọn loại hình: thêm **Sân bóng**; mục cuối đổi thành **"Nhiều loại"** (hình cụm bốn). Quán chọn một loại hình thì ô vẫn đổi tên + hình theo ngành như trước; chọn "Nhiều loại" hoặc chưa chọn thì giữ ô chung.
- Sửa kèm: hình tự vẽ trong ô module thật bị kéo to kín khung biểu tượng (ảnh thử trước đây đặt trong khung canh giữa nên không lộ). Nay tự canh giữa.
- Biểu tượng khu vực thêm mã `0xF1A07` (sân bóng).
- Ảnh duyệt: `test/modules/tinh_gio/goldens/o_module_360.png`, `o_module_1024.png` (ô thật, lưới như Trang chủ), `chon_loai_hinh_360.png`, `nganh_icon.png`.
- Bài hướng dẫn đổi tên theo; xuất lại `huong_dan.json` (bản 202611240645), đóng dấu `tinh-gio.md`, `quan-ly-ban.md`, `kho-hang.md`. Lúc đầu câu tả hình "quả bóng" làm Boom trả lời câu lạc đề "kết quả bóng đá tối qua" → bỏ câu tả hình, test Boom xanh lại (133 đạt; chỉ còn test đồng bộ đỏ vì các bài của việc khác).
- Chưa xem trên máy thật / máy ảo, mới xem qua ảnh chụp từ test. Chưa commit, chờ Chủ Quán duyệt hình.
- 24/11 chiều: Chủ Quán duyệt hình, đã commit `d50c320`. Cài bản mới lên máy ảo Pixel 7 thì thấy tên ô ngắt thành "Các hoạt động tính / giờ" (ô máy này rộng hơn ảnh thử 360). Sửa: nối "tính giờ" bằng dấu cách không ngắt trong `kTenModuleTinhGio`; ô module dùng chung hằng này. Cài lại, máy ảo hiện "Các hoạt động / tính giờ".

### 25/11 — Hộp đặt giá giờ: gõ thẳng giá, không chọn trong thực đơn

Chủ Quán mở hộp "Tính tiền giờ" trên máy ảo, thấy cả thực đơn hiện thành giá giờ ("Bún bò Huế đặc biệt 55.000 đ / giờ").

- Nguyên nhân: hộp liệt kê mọi món của quán để chọn làm món giá giờ; quán chưa tạo món giá giờ thì chỉ toàn đồ ăn uống.
- Sửa: bỏ ô "Tìm món", thay bằng ô **"Giá một giờ"** + nút **"Lưu"**. Bấm Lưu thì app dùng lại món giá giờ cùng giá nếu đã có, không thì tự tạo món "Tiền giờ 60.000 đ" (danh mục "Tiền giờ", đơn vị giờ) qua `CoreProductRepository.create` rồi gắn cho bàn / cả khu. Máy chủ không đổi gì.
- Bên dưới chỉ còn mục "Hoặc chọn giá đã có": các món có chữ "giờ" trong tên hoặc danh mục (`laMonGiaGio`), cộng món bàn đang dùng.
- Thử thật trên máy ảo, quán Demo: bàn A 2 gõ 60000 → thẻ bàn ghi "4 chỗ • 60.000 đ/giờ"; mở hộp ở A 3 thấy "Tiền giờ 60.000 đ". Chưa thử "Áp cho cả khu", chưa thử lúc mất mạng, chưa thử tài khoản Quản lý (không phải Chủ quán) có tạo được món không.
- Quán Demo có thêm món "Tiền giờ 60.000 đ" và bàn A 2 gắn giá này.
- Bài hướng dẫn sửa mục đặt giá, đổi giá và bảng lỗi; xuất lại `huong_dan.json` (482 đoạn, bản 202611250344). Test module + Boom 167 đạt.

### 25/11 — Làm lại giao diện hộp đặt giá giờ

Chủ Quán yêu cầu tinh chỉnh UX/UI cho sang, đẹp hơn.

- Đầu hộp: huy hiệu ngành (nền xanh ngọc như ô module) + "Giá giờ · tên bàn" + nút đổi loại hình dạng viên thuốc ở góc phải.
- Thẻ trắng "Giá một giờ": số tiền cỡ lớn, tự chèn dấu chấm hàng nghìn khi gõ; bên dưới quy ra tiền cho 30 phút, 1 giờ 30, 2 giờ. Bàn đã có giá thì điền sẵn.
- Hàng "Chọn nhanh": giá quán đang dùng (có dấu tích) đứng trước, rồi các mức thường gặp 30.000–150.000. Bấm là điền vào ô, chưa lưu.
- Công tắc "Áp cho cả khu" đổi thành thanh hai lựa chọn "Chỉ <bàn>" / "Cả khu · N bàn".
- Một nút chính dưới cùng "Lưu · 60.000 đ / giờ" (quay vòng khi đang lưu); nút chữ đỏ "Không tính giờ (bàn thường)" khi bàn đang có giá.
- Ảnh thử cỡ 360×800: `goldens/gia_gio_trong.png`, `gia_gio_da_co.png`. Thử thật trên máy ảo, quán Demo: bấm chọn nhanh 60.000 + "Cả khu" + Lưu → A 1, A 2, A 3 đều "60.000 đ/giờ". Trên máy thật lộ khung ô nhập mặc định của theme quanh số tiền (ảnh thử không có theme nên không thấy) → đã tắt.
- Chưa thử: gõ tay bằng bàn phím trên bản cuối (bản trước đã thử), mất mạng, tài khoản Quản lý, máy Sunmi thật.
- Bài hướng dẫn sửa theo nút mới, xuất lại (bản 202611250412). Test module + Boom 169 đạt.

### 25/11 — Màn Lịch đặt không thấy nút quay lại

Chủ Quán báo màn Lịch đặt không có chỗ quay lại. Nút vẫn có nhưng theme của app đặt biểu tượng thanh trên màu trắng, màn này nền kem nên nút chìm mất (ảnh thử không dùng theme của app nên không lộ). Sửa: ghi rõ màu biểu tượng xanh đậm cho thanh trên của màn Lịch đặt. Thử trên máy ảo: thấy mũi tên, bấm về đúng màn Quản lý bàn.

### 25/11 — Hộp giữ lâu vào bàn: "Đặt giá giờ" thay "Tính tiền giờ", bỏ chữ "thông tin bàn"

Chủ Quán chụp hộp giữ lâu vào "Bàn 1" (khu bi da), bảo đừng để là "thông tin bàn", nhìn không hợp logic. Em hiểu là: hộp đang trình bày như mục sửa thông tin bàn, còn việc chính của quán tính giờ (đặt giá) nằm dưới, lại mang tên "Tính tiền giờ" trùng với nút thu tiền giờ trong bàn.

- Khi quán bật module: mục **"Đặt giá giờ"** đứng đầu, dòng phụ ghi "Chưa tính giờ" hoặc giá đang dùng ("60.000 đ / giờ"); mục sửa ghi **"Sửa tên, số chỗ"** (không chữ "bàn", vì sân và phòng hát cũng dùng hộp này).
- Quán không bật module: hộp y như cũ, vẫn "Sửa thông tin bàn".
- "Tính tiền giờ" giờ chỉ còn một nghĩa: nút thu tiền giờ trong bàn chưa gọi món.
- Thử trên máy ảo: giữ lâu "Bàn 1" khu bi da thấy đúng hai mục mới. Bài `tinh-gio.md`, `quan-ly-ban.md` sửa theo, xuất lại (bản 202611250456).

### 25/11 — Ô "Các hoạt động tính giờ" mở màn riêng

Chủ Quán báo bấm ô lại ra màn Bàn, vẫn còn tên "Quản lý bàn". Làm chế độ riêng `BanScreen(cheDoTinhGio: true)`, đẩy thành màn mới (có nút quay lại, không có thanh dưới) thay vì nhảy tab 7; tab Bàn giữ nguyên mọi bàn.

- Tên màn theo loại hình quán; chữ "bàn" ở nút Thêm và bộ lọc đổi theo ngành (sân, phòng). Các hộp con vẫn ghi "bàn".
- Hiện: bàn có giá giờ + mọi bàn của khu mang biểu tượng ngành (`locBanTinhGio`, `locKhuTinhGio`).
- Bàn chưa có giá ghi "Chưa đặt giá giờ", chạm vào mở hộp đặt giá (không mở bàn, kẻo đồng hồ không chạy).
- Thêm bàn ở khu đã có giá thì theo giá của khu; thêm khu chỉ cho chọn biểu tượng ngành. Không sắp xếp khu ở màn này.
- Thanh "Lịch đặt" ở đầu màn.
- Máy ảo, quán Demo: màn mang tên mới, khu bi da 3 bàn "Chưa đặt giá giờ"; đã bấm mở hộp giá, Lịch đặt, Thêm khu, Thêm bàn, quay lại (không lưu gì). Chưa thử: lưu thêm khu / thêm bàn, máy tính bảng, tài khoản nhân viên, hộp nhắc 30 phút khi đang ở màn này.

### 26/11 — Món giá giờ bị gọi như món thường (thu hai lần)

Chủ Quán chụp Bàn 2 quán Demo: có dòng "Tiền giờ 30.000 đ" ở trạng thái "Chưa gửi" cạnh dải "Đang tính giờ", tổng 30.000 trong khi tiền giờ tạm tính 1.000, hỏi "sao rối thế".

- Đọc máy chủ (chỉ đọc): dòng đó thêm lúc 05:22:30 UTC, 6 giây sau khi mở bàn, người thêm là tài khoản quán, không có `gio_tu`: gọi từ "Thêm món". Bàn 1 cũng có "Tiền giờ 60.000 đ" gọi như món. Nguyên nhân: món giá giờ app tự tạo (danh mục "Tiền giờ") hiện chung trong thực đơn; mở bàn xong app tự mở thực đơn nên dễ bấm. Thanh toán thì thu cả dòng món lẫn dòng tiền giờ máy chủ ghi.
- Sửa app: `posProductsProvider` (thực đơn màn Bán hàng và Thêm món của Bàn) bỏ món danh mục "Tiền giờ"; hộp đặt giá giờ đọc từ `allProductsProvider`; giá điền sẵn khi danh sách món tải xong. Ô tổng trong bàn tính giờ ghi "TỔNG TẠM TÍNH (gồm tiền giờ)" và dùng số tạm tính (thay dòng giờ đã chốt, không cộng trùng), khớp thẻ bàn.
- Thử máy ảo: thực đơn "Thêm món" không còn "Tiền giờ"; Bàn 2 ghi "TỔNG TẠM TÍNH (gồm tiền giờ) 33.000 đ". Hai dòng gọi nhầm ở Bàn 1, Bàn 2 Demo vẫn còn (dữ liệu, em không xoá).
- CHƯA sửa: thực đơn QR cho khách (`get_qr_menu_v4` trên máy chủ) vẫn trả món "Tiền giờ"; cần migration, chờ Chủ Quán cho áp.
- Ghi nhận thêm: A 2, A 3 Demo mở từ 25/11 trưa vẫn chạy, đã 24 giờ 47 (≈ 1.487.000 đ mỗi bàn); A 1 đã thanh toán 1.462.000 đ cho 24 giờ 22.

### 26/11 — Sửa thực đơn QR (ĐÃ ÁP production 26/11 13:00, mốc hoàn tác quannho_before_qr_tien_gio_20261126_130017.dump)

- `supabase/migrations/20261126_qr_an_mon_tien_gio.sql`: `get_qr_menu_v4` và `qr_price_items_v4` thêm điều kiện `category <> 'Tiền giờ'`. Bản gốc đọc từ production 26/11; tệp `_ROLLBACK` là nguyên bản đó. Gửi đơn (`submit_qr_order_v4`) và nhân viên sửa đơn (`update_qr_order_items_v4`) đều gọi `qr_price_items_v4` nên cùng được chặn.
- Test `supabase/tests/qr_an_mon_tien_gio_test.sql` (9 điểm): thực đơn còn món thường, không có "Tiền giờ", vẫn không có nguyên liệu; tính giá từ chối "Tiền giờ", món thường đúng tiền; quyền anon không đổi. Bản sao (`chuoi_stage_dryrun.sh`, TAG=qr_tien_gio): 9/9 PASS.
- Script áp: `db-fix/qr_an_mon_tien_gio_ap_dung.sh` (backup → áp → test). Chưa chạy, chờ Chủ Quán cho áp. Hiện production có 2 món "Tiền giờ" (đều ở quán Demo).
- Chưa thử: bài test chạy trên bản CHƯA áp để chắc nó bắt được lỗi.
- 26/11 13:00 Chủ Quán cho áp: `db-fix/qr_an_mon_tien_gio_ap_dung.sh` → backup, áp (2 hàm), test 9/9 PASS trên production (tự ROLLBACK). Kiểm lại chỉ đọc: cả 10 kênh QR đang mở vẫn trả thực đơn, quyền anon / authenticated không đổi, 0 đơn QR mới trong 10 phút quanh lúc áp. Hoàn tác: `ROLLBACK=1 bash db-fix/qr_an_mon_tien_gio_ap_dung.sh`.

### 27/11 — Hiện giờ chơi rõ hơn (A–D)

Chủ Quán thấy phần giờ và thanh toán "chưa rõ ràng"; đã đối chiếu cách các phần mềm bi da / karaoke khác hiện (mỗi bàn một đồng hồ, giờ vào, thời gian đã chơi, đơn giá, khối giờ tách khỏi đồ uống). Chủ Quán chọn làm cả bốn:

- A. Thẻ bàn: đồng hồ đã chơi "giờ:phút" chữ to, dòng dưới "Vào 13:07 • giờ 348.000 đ" (khác ngày thì kèm ngày "26/11 13:07"). Chạy quá 6 giờ (`kTinhGioCanhBaoLau`) thì đồng hồ nền trắng chữ đỏ có dấu cảnh báo.
- B. Màn chi tiết bàn: khối "Giờ chơi" đứng đầu danh sách món; theo ý Chủ Quán, "Vào lúc 26/11 13:07" nằm cùng dòng tiêu đề (bên phải), bên dưới hai ô nền màu tách riêng: Đã chơi "11 giờ 42 phút" (đỏ khi quá 6 giờ) và Tiền giờ (cam), dòng dưới đơn giá "30.000 đ/giờ • tính theo phút, chốt khi bấm Thanh toán"; quá 6 giờ thì viền đỏ và một dòng cảnh báo riêng. Thay dải xám "Đang tính giờ …" ở cuối.
- B (làm lại lần 2, Chủ Quán chê "chưa xuất sắc"; số Tiền giờ đổi cam → vàng ấm theo Chủ Quán chọn; commit 43cd95c): khối kiểu đồng hồ bấm giờ nền xanh đậm (cùng màu thẻ bàn có khách): chấm xanh / đỏ + "ĐANG TÍNH GIỜ", góc phải "Vào lúc 26/11 13:07"; hai số lớn "11 giờ 47 phút" (trắng, chữ giờ/phút nhỏ) | "354.000 đ" (cam sáng), ngăn bằng vạch mảnh; chân ghi đơn giá; quá 6 giờ thêm dải đỏ "Quá 6 giờ, xem khách còn chơi không." Số giờ giữ trắng vì đỏ cạnh cam khó tách.
- D. Món giá giờ app tự tạo tên "Giờ chơi 60.000 đ/giờ" (danh mục vẫn "Tiền giờ"). Món cũ giữ tên.
- C. Máy chủ: `supabase/migrations/20261127_tinh_gio_ten_dong.sql` chỉ đổi phần ghép tên dòng trong `qn_tinh_gio_ghi_dong_v1`: "Giờ chơi · A 1 · 14:05 – 15:35 · 1 giờ 30 phút × 60.000 đ/giờ"; khác ngày thì ghi "25/11 11:39 – 26/11 12:01". Số phút, số tiền không đổi. Không dùng tên món nữa (tên cũ đặt "60.000 đ" cạnh số tiền thật). `_ROLLBACK` là bản production lấy 27/11. Test `supabase/tests/tinh_gio_ten_dong_test.sql` (5 điểm); sửa điểm T5d (`ban_tinh_gio_v1_test.sql`) và D9f (`ban_dat_truoc_v1_test.sql`) theo tên mới. Bản sao 27/11 00:38: 5/5, bộ tính giờ và đặt trước đều TẤT CẢ PASS. Script `db-fix/tinh_gio_ten_dong_ap_dung.sh`. ĐÃ ÁP production 27/11 01:00 theo lời Chủ Quán "Áp lên máy chủ": chạy thử trong giao dịch trên máy chủ thật 5/5 rồi huỷ; backup `quannho_before_ten_dong_20261127_010020.dump`; áp (CREATE FUNCTION, REVOKE, COMMIT); test 5/5 PASS (tự ROLLBACK). Kiểm chỉ đọc: hàm có tên mới, chữ ký 3 tham số, quyền chỉ supabase_admin / postgres / service_role, `ban_chot_gio_v1` vẫn gọi nó; 3 phiên đang tính giờ đều của quán Demo. Hoàn tác: `ROLLBACK=1 bash db-fix/tinh_gio_ten_dong_ap_dung.sh`.
- Hướng dẫn `tinh-gio.md` sửa 4 chỗ theo cách hiện mới (đã xuất lại, chưa đăng lên Boom).
- Máy ảo, Demo: thẻ A 2, A 3 (mở 25/11), Bàn 1 (26/11) đều hiện đồng hồ đỏ; Bàn 1 mở ra thấy khối Giờ chơi. Chưa thử: bàn chạy dưới 6 giờ, khung đặt trước, bàn đã bỏ tiền giờ, máy tính bảng, Sunmi.
